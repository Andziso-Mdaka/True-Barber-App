// Called directly by the Flutter app (with the user's own JWT) when a
// customer cancels their subscription. This actually tells PayFast to stop
// billing them — updating our own `subscriptions` table alone would leave
// PayFast still charging the customer every month, which is the whole
// reason this function exists rather than just doing a plain DB update.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import md5 from "npm:md5@2.3.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function pfEncode(value: string): string {
  return encodeURIComponent(value.trim())
    .replace(/%20/g, "+")
    .replace(/[!'()*~]/g, (c) => "%" + c.charCodeAt(0).toString(16).toUpperCase());
}

// PayFast's management API (as opposed to the checkout page) signs requests
// differently: ALL header + body params, sorted ALPHABETICALLY, plus the
// passphrase. This is genuinely different from the checkout signature's
// fixed field order — easy to mix up, so worth the explicit comment.
function buildApiSignature(params: Record<string, string>, passphrase: string): string {
  const allParams = { ...params, passphrase };
  const keys = Object.keys(allParams).sort();
  const parts = keys.map((k) => `${k}=${pfEncode(allParams[k])}`);
  return md5(parts.join("&"));
}

function payfastTimestamp(): string {
  // PayFast's docs show this format as YYYY-MM-DDTHH:MM:SS[+HH:MM] — but
  // their own worked example has no offset at all ("2020-03-23T09:46:06"),
  // meaning the offset is optional and best left off rather than guessed at.
  return new Date().toISOString().slice(0, 19);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { shop_id } = await req.json();
    if (!shop_id) {
      return new Response(JSON.stringify({ error: "shop_id is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // RLS ensures this only ever returns the CALLER's own subscription —
    // there's no way to cancel someone else's by passing a different shop_id.
    const { data: subscription, error: subError } = await supabase
      .from("subscriptions")
      .select("id, payfast_token")
      .eq("shop_id", shop_id)
      .eq("customer_id", userData.user.id)
      .eq("status", "active")
      .maybeSingle();

    if (subError || !subscription) {
      return new Response(JSON.stringify({ error: "No active subscription found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // A subscription created before payments existed (or one that somehow
    // never got a token back from PayFast) has nothing to cancel remotely —
    // just cancel it locally in that case.
    if (subscription.payfast_token) {
      const merchantId = Deno.env.get("PAYFAST_MERCHANT_ID")!;
      const passphrase = Deno.env.get("PAYFAST_PASSPHRASE")!;
      const payfastCheckoutUrl = Deno.env.get("PAYFAST_URL")!;
      const isSandbox = payfastCheckoutUrl.includes("sandbox");

      const timestamp = payfastTimestamp();
      const headerParams: Record<string, string> = {
        "merchant-id": merchantId,
        "version": "v1",
        "timestamp": timestamp,
      };
      const signature = buildApiSignature(headerParams, passphrase);

      const apiUrl = `https://api.payfast.co.za/subscriptions/${subscription.payfast_token}/cancel${isSandbox ? "?testing=true" : ""}`;

      const pfResponse = await fetch(apiUrl, {
        method: "PUT",
        headers: {
          "merchant-id": merchantId,
          "version": "v1",
          "timestamp": timestamp,
          "signature": signature,
        },
      });

      if (!pfResponse.ok) {
        const body = await pfResponse.text();
        console.error("PayFast cancel failed:", pfResponse.status, body);
        return new Response(JSON.stringify({ error: "PayFast cancellation failed", details: body }), {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    await supabase
      .from("subscriptions")
      .update({ status: "cancelled", cancelled_at: new Date().toISOString() })
      .eq("id", subscription.id);

    return new Response(JSON.stringify({ cancelled: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});