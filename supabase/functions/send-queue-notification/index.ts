// Triggered by a Database Webhook whenever queue_entries is updated.
// If the update transitions a ticket's status into 'called', this looks up
// the customer's registered device(s) and sends them a push notification
// via Firebase Cloud Messaging's HTTP v1 API.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

Deno.serve(async (req) => {
  // Lightweight shared-secret check. Functions deployed with --no-verify-jwt
  // are otherwise reachable by anyone who finds the URL — this isn't full
  // auth, but it stops random internet traffic from triggering pushes.
  const expectedSecret = Deno.env.get("WEBHOOK_SECRET");
  if (expectedSecret && req.headers.get("x-webhook-secret") !== expectedSecret) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
  }

  try {
    const payload = await req.json();
    const record = payload.record;
    const oldRecord = payload.old_record;

    // Only act on a genuine transition INTO 'called' — not every update.
    if (!record || record.status !== "called" || oldRecord?.status === "called") {
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    const { data: shop } = await supabase
      .from("shops")
      .select("name")
      .eq("id", record.shop_id)
      .single();

    const { data: tokens } = await supabase
      .from("device_tokens")
      .select("token")
      .eq("user_id", record.customer_id);

    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ skipped: true, reason: "no device tokens" }), { status: 200 });
    }

    const serviceAccountRaw = Deno.env.get("FCM_SERVICE_ACCOUNT");
    if (!serviceAccountRaw) throw new Error("FCM_SERVICE_ACCOUNT secret is not set");
    const serviceAccount = JSON.parse(serviceAccountRaw);

    const accessToken = await getAccessToken(serviceAccount);
    const shopName = shop?.name ?? "your shop";

    const results = await Promise.all(
      tokens.map(async (row: { token: string }) => {
        const result = await sendPush(accessToken, serviceAccount.project_id, row.token, shopName, record.ticket_no);
        // Clean up tokens FCM says are no longer valid (uninstalled app, etc.)
        // so the table doesn't accumulate dead entries.
        const errorCode = result?.error?.details?.find(
          (d: { errorCode?: string }) => d.errorCode,
        )?.errorCode;
        if (errorCode === "UNREGISTERED" || errorCode === "INVALID_ARGUMENT") {
          await supabase.from("device_tokens").delete().eq("token", row.token);
        }
        return result;
      }),
    );

    return new Response(JSON.stringify({ sent: results.length }), { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});

async function getAccessToken(serviceAccount: { client_email: string; private_key: string }): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claim = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const encoder = new TextEncoder();
  const base64url = (bytes: Uint8Array) =>
    btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
  const base64urlFromString = (s: string) => base64url(encoder.encode(s));

  const unsigned = `${base64urlFromString(JSON.stringify(header))}.${base64urlFromString(JSON.stringify(claim))}`;

  const key = await importPrivateKey(serviceAccount.private_key);
  const signature = await crypto.subtle.sign({ name: "RSASSA-PKCS1-v1_5" }, key, encoder.encode(unsigned));
  const jwt = `${unsigned}.${base64url(new Uint8Array(signature))}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });

  const data = await res.json();
  if (!data.access_token) throw new Error(`Failed to get FCM access token: ${JSON.stringify(data)}`);
  return data.access_token;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const pemContents = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  const binaryDer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

async function sendPush(
  accessToken: string,
  projectId: string,
  token: string,
  shopName: string,
  ticketNo: number,
) {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      message: {
        token,
        notification: {
          title: "You're up!",
          body: `Ticket #${ticketNo} — head to ${shopName} now.`,
        },
        android: { priority: "high" },
        apns: { headers: { "apns-priority": "10" } },
      },
    }),
  });
  return res.json();
}