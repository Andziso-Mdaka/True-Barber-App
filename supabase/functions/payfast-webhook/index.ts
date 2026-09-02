// PayFast calls this directly (server-to-server) every time a payment
// succeeds or fails — the very first payment AND every recurring monthly
// charge after that. This is the ONLY place a subscription actually
// becomes active; the app never activates one directly.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import md5 from "npm:md5@2.3.0";

function pfEncode(value: string): string {
  return encodeURIComponent(value.trim())
    .replace(/%20/g, "+")
    .replace(/[!'()*~]/g, (c) => "%" + c.charCodeAt(0).toString(16).toUpperCase());
}

// Unlike the checkout signature (fixed field order), verifying an INCOMING
// ITN re-hashes the fields in the order PayFast actually sent them — not a
// fixed schema. We rebuild the query string from the raw body, preserving
// order, with the signature field removed.
function verifyItnSignature(rawBody: string, passphrase: string, receivedSignature: string): boolean {
  const pairs = rawBody.split("&").filter((p) => !p.startsWith("signature="));
  const decoded = pairs.map((pair) => {
    const idx = pair.indexOf("=");
    const key = pair.slice(0, idx);
    const rawValue = pair.slice(idx + 1);
    // Re-encode using PayFast's rules rather than trusting the raw bytes
    // as-is, since the original request already came URL-encoded.
    return `${key}=${pfEncode(decodeURIComponent(rawValue.replace(/\+/g, " ")))}`;
  });
  if (passphrase) decoded.push(`passphrase=${pfEncode(passphrase)}`);
  const expected = md5(decoded.join("&"));
  return expected === receivedSignature;
}

Deno.serve(async (req) => {
  try {
    const rawBody = await req.text();
    const fields = new URLSearchParams(rawBody);
    const receivedSignature = fields.get("signature") ?? "";

    const passphrase = Deno.env.get("PAYFAST_PASSPHRASE")!;
    const isValid = verifyItnSignature(rawBody, passphrase, receivedSignature);
    if (!isValid) {
      console.error("PayFast ITN signature mismatch — rejecting.");
      return new Response("invalid signature", { status: 400 });
    }

    const paymentStatus = fields.get("payment_status");
    const shopId = fields.get("custom_str1");
    const customerId = fields.get("custom_str2");
    const mPaymentId = fields.get("m_payment_id");
    const pfPaymentId = fields.get("pf_payment_id");
    const token = fields.get("token");
    const amountGross = fields.get("amount_gross");

    if (!shopId || !customerId) {
      console.error("ITN missing shop_id/customer_id in custom fields.");
      return new Response("missing custom fields", { status: 400 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, serviceRoleKey);

    if (paymentStatus === "COMPLETE") {
      // Is there already an active subscription for this shop+customer?
      // If so, this ITN is a recurring monthly charge, not the first payment.
      const { data: existing } = await supabase
        .from("subscriptions")
        .select("id")
        .eq("shop_id", shopId)
        .eq("customer_id", customerId)
        .eq("status", "active")
        .maybeSingle();

      let subscriptionId = existing?.id as string | undefined;

      if (!subscriptionId) {
        const { data: inserted, error: insertError } = await supabase
          .from("subscriptions")
          .insert({
            shop_id: shopId,
            customer_id: customerId,
            status: "active",
            payfast_token: token,
            m_payment_id: mPaymentId,
          })
          .select("id")
          .single();
        if (insertError) {
          console.error("Failed to create subscription from ITN:", insertError);
          return new Response("db error", { status: 500 });
        }
        subscriptionId = inserted.id;
      }

      await supabase.from("payments").insert({
        subscription_id: subscriptionId,
        shop_id: shopId,
        customer_id: customerId,
        amount: amountGross ? Number(amountGross) : 0,
        status: "complete",
        pf_payment_id: pfPaymentId,
      });
    } else {
      // Failed payment — log it, but don't touch the subscription's status.
      // PayFast automatically retries failed recurring charges a few times
      // before locking the subscription, so we let their retry cycle run
      // rather than cancelling on the first failure.
      await supabase.from("payments").insert({
        shop_id: shopId,
        customer_id: customerId,
        amount: amountGross ? Number(amountGross) : 0,
        status: "failed",
        pf_payment_id: pfPaymentId,
      });
    }

    return new Response("ok", { status: 200 });
  } catch (e) {
    console.error(e);
    return new Response(String(e), { status: 500 });
  }
});