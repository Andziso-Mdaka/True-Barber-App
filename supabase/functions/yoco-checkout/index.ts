const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

declare const Deno: any; // Mutes the VS Code warning
Deno.serve(async (req: Request) => {
  // Handle CORS preflight for Flutter
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { amount, serviceName, shopId } = await req.json();

    // 1. Yoco requires the amount in cents (e.g., R150 = 15000)
    const amountInCents = amount * 100;
    
    // 2. Safely grab the secret key we just stored
    const yocoSecretKey = Deno.env.get('YOCO_SECRET_KEY');

    if (!yocoSecretKey) {
      throw new Error('Yoco Secret Key is missing from environment variables');
    }

    // 3. Call the real Yoco Checkout API
    const yocoResponse = await fetch("https://payments.yoco.com/api/checkouts", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${yocoSecretKey}`
      },
      body: JSON.stringify({
        amount: amountInCents,
        currency: "ZAR",
        // Since we open this in an in-app browser, we'll route these to basic placeholders for now.
        // Later, we can replace these with custom Deep Links (e.g., truebarber://success)
        successUrl: "https://www.yoco.com/za/",
        cancelUrl: "https://www.yoco.com/za/",
        failureUrl: "https://www.yoco.com/za/",
        metadata: {
          shopId: shopId,
          serviceName: serviceName
        }
      }),
    });

    const data = await yocoResponse.json();

    // 4. Return the data (which contains Yoco's hosted 'redirectUrl') to Flutter
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
    
  } catch (error: any) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});