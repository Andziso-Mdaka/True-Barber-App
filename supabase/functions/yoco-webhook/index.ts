import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";
declare const Deno: any;

Deno.serve(async (req: Request) => {
  try {
    const payload = await req.json();

    // 1. We only care if the payment was successful
    if (payload.type === 'payment.succeeded') {
      
      // Yoco sometimes nests metadata inside a payload object depending on the API version
      const metadata = payload.payload?.metadata || payload.metadata || {};
      const { shopId, customerId, paymentType } = metadata;

      // 2. Check if this payment was for a 30-Day VIP Pass
      if (paymentType === 'subscription' && shopId && customerId) {
        
        // 3. Init Supabase Admin client to bypass RLS and securely update the DB
        const supabaseAdmin = createClient(
          Deno.env.get('SUPABASE_URL') ?? '',
          Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        );

        // 4. Calculate exactly 30 days from right now
        const expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + 30);

        // 5. Upsert the VIP Pass into the database!
        await supabaseAdmin
          .from('subscriptions')
          .upsert({
            shop_id: shopId,
            customer_id: customerId,
            expires_at: expiresAt.toISOString(),
          }, { onConflict: 'shop_id,customer_id' });
      }
    }

    // Always return a 200 OK so Yoco doesn't keep retrying
    return new Response("Webhook processed", { status: 200 });
    
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), { status: 400 });
  }
});