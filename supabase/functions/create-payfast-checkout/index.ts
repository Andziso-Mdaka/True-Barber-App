// Generates a signed PayFast checkout URL for a customer subscribing to a
// shop. Called directly by the Flutter app (with the user's own JWT — this
// function DOES verify the caller's identity, unlike the webhook).
//
// Nothing is written to the `subscriptions` table here. The subscription
// only becomes real once PayFast's webhook confirms the payment actually
// succeeded — this function just builds the payment link.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import md5 from "npm:md5@2.3.0";

// PayFast requires this EXACT field order when generating the checkout
// signature — not alphabetical, not the order you happen to build the
// object in. Getting this wrong is the #1 cause of "signature mismatch"
// errors people run into with PayFast.
const CHECKOUT_SIGNATURE_FIELD_ORDER = [
  "merchant_id", "merchant_key", "return_url", "cancel_url", "notify_url",
  "name_first", "name_last", "email_address", "cell_number",
  "m_payment_id", "amount", "item_name", "item_description",
  "custom_int1", "custom_int2", "custom_int3", "custom_int4", "custom_int5",
  "custom_str1", "custom_str2", "custom_str3", "custom_str4", "custom_str5",
  "email_confirmation", "confirmation_address",
  "payment_method",
  "subscription_type", "billing_date", "recurring_amount", "frequency", "cycles",
];

// Matches PHP's urlencode() behaviour, which is what PayFast's own examples
// (and every reference implementation) are built against: spaces become
// '+', and encodeURIComponent's uppercase %XX escapes are correct as-is,
// but a handful of characters JS leaves unescaped (!'()*~) need encoding too.
function pfEncode(value: string): string {
  return encodeURIComponent(value.trim())
    .replace(/%20/g, "+")
    .replace(/[!'()*~]/g, (c) => "%" + c.charCodeAt(0).toString(16).toUpperCase());
}

function buildSignature(params: Record<string, string>, passphrase: string): string {
  const parts: string[] = [];
  for (const key of CHECKOUT_SIGNATURE_FIELD_ORDER) {
    const value = params[key];
    if (value !== undefined && value !== null && value !== "") {
      parts.push(`${key}=${pfEncode(String(value))}`);
    }
  }
  if (passphrase) parts.push(`passphrase=${pfEncode(passphrase)}`);
  return md5(parts.join("&"));
}

Deno.serve(async (req) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    // Client scoped to the caller's own JWT — respects RLS, and lets us
    // read back exactly who's making this request.
    const supabase = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData, error: userError } = await supabase.auth.getUser();
    if (userError || !userData.user) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });
    }
    const user = userData.user;

    const { shop_id, return_url, cancel_url } = await req.json();
    if (!shop_id || !return_url || !cancel_url) {
      return new Response(JSON.stringify({ error: "shop_id, return_url and cancel_url are required" }), { status: 400 });
    }

    const { data: shop, error: shopError } = await supabase
      .from("shops")
      .select("id, name, price")
      .eq("id", shop_id)
      .single();
    if (shopError || !shop) {
      return new Response(JSON.stringify({ error: "Shop not found" }), { status: 404 });
    }

    const { data: profile } = await supabase.from("profiles").select("full_name").eq("id", user.id).maybeSingle();
    const fullName = (profile?.full_name as string | undefined)?.trim() || "Customer";
    const [nameFirst, ...rest] = fullName.split(" ");
    const nameLast = rest.join(" ") || "Regular";

    const merchantId = Deno.env.get("PAYFAST_MERCHANT_ID")!;
    const merchantKey = Deno.env.get("PAYFAST_MERCHANT_KEY")!;
    const passphrase = Deno.env.get("PAYFAST_PASSPHRASE")!;
    const payfastUrl = Deno.env.get("PAYFAST_URL")!; // e.g. https://sandbox.payfast.co.za/eng/process
    const notifyUrl = `${supabaseUrl}/functions/v1/payfast-webhook`;

    const amount = Number(shop.price).toFixed(2);
    const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD

    const params: Record<string, string> = {
      merchant_id: merchantId,
      merchant_key: merchantKey,
      return_url,
      cancel_url,
      notify_url: notifyUrl,
      name_first: nameFirst,
      name_last: nameLast,
      email_address: user.email ?? "",
      m_payment_id: crypto.randomUUID(),
      amount,
      item_name: `${shop.name} subscription`,
      custom_str1: shop.id,
      custom_str2: user.id,
      subscription_type: "1",
      billing_date: today,
      recurring_amount: amount,
      frequency: "3", // monthly
      cycles: "0", // 0 = indefinite, until cancelled
    };

    const signature = buildSignature(params, passphrase);

    const query = CHECKOUT_SIGNATURE_FIELD_ORDER
      .filter((key) => params[key] !== undefined && params[key] !== "")
      .map((key) => `${key}=${encodeURIComponent(params[key])}`)
      .join("&");

    const checkoutUrl = `${payfastUrl}?${query}&signature=${signature}`;

    return new Response(JSON.stringify({ checkout_url: checkoutUrl }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error(e);
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});