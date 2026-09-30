// @ts-ignore: Mutes VS Code warning. Deno resolves URL imports perfectly on Supabase.
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

declare const Deno: any;

Deno.serve(async (req: Request) => {
  try {
    const payload = await req.json();

    // 1. We only care if the payment was successful
    if (payload.type === 'payment.succeeded') {

      // Yoco sometimes nests metadata inside a payload object depending on the API version
      const metadata = payload.payload?.metadata || payload.metadata || {};
      const { shopId, customerId, paymentType, serviceName } = metadata;
      const amountRands = (payload.payload?.amount || 0) / 100; // cents -> Rands

      // 2. Init Supabase Admin client to bypass RLS and securely update the DB
      const supabaseAdmin = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
      );

      // SCENARIO A: 30-Day VIP Pass
      if (paymentType === 'subscription' && shopId && customerId) {

        // Calculate exactly 30 days from right now
        const expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + 30);

        // Upsert the VIP Pass into the database
        await supabaseAdmin
          .from('subscriptions')
          .upsert({
            shop_id: shopId,
            customer_id: customerId,
            expires_at: expiresAt.toISOString(),
          }, { onConflict: 'shop_id,customer_id' });
      }

      // SCENARIO B: Once-off Walk In Payment
      // This is the ONLY place a once-off payment actually joins the queue —
      // the Flutter app must never call join_queue client-side for this path.
      // Doing it here, gated on a genuinely confirmed payment.succeeded event,
      // is what stops someone getting a ticket without paying.
      else if (paymentType === 'once_off' && shopId && customerId) {

        if (!serviceName) {
          console.error(
            'once_off payment succeeded but no serviceName in metadata — ' +
            'cannot join queue without it. Check that yoco-checkout is forwarding serviceName.'
          );
        } else {
          const { error: queueError } = await supabaseAdmin.rpc('join_queue', {
            p_shop_id: shopId,
            p_payment_method: 'once_off',
            p_service_name: serviceName,
            p_price_charged: Math.round(amountRands),
            p_customer_id: customerId, // required here — no session under service role
          });

          if (queueError) {
            // Don't let a queue failure (e.g. no barbers available right now)
            // silently swallow a real payment — log it loudly so it's actually
            // investigated rather than a customer paying and getting nothing.
            console.error('join_queue failed after successful once_off payment:', queueError, {
              shopId,
              customerId,
              serviceName,
              amountRands,
            });
          }
        }

        // Log the payment regardless, for your own records / reconciliation.
        await supabaseAdmin.from('payments').insert({
          shop_id: shopId,
          customer_id: customerId,
          amount: amountRands,
          status: 'complete',
        });
      }
    }

    // Always return a 200 OK so Yoco knows we received the webhook and doesn't retry
    return new Response("Webhook processed", { status: 200 });

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 400 });
  }
});