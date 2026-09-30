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
    // 1. NEW: Extract all necessary fields sent from Flutter
    const { amount, serviceName, shopId, customerId, paymentType } = await req.json();

    // Yoco requires the amount in cents (e.g., R150 = 15000)
    const amountInCents = Math.round(amount * 100);
    
    // Safely grab the secret key we just stored
    const yocoSecretKey = Deno.env.get('YOCO_SECRET_KEY');

    if (!yocoSecretKey) {
      throw new Error('Yoco Secret Key is missing from environment variables');
    }

    // 2. Call the real Yoco Checkout API
    const yocoResponse = await fetch("https://payments.yoco.com/api/checkouts", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${yocoSecretKey}`
      },
      body: JSON.stringify({
        amount: amountInCents,
        currency: "ZAR",
        
        // 3. NEW: Native Deep Links. These tell the OS to snap back to the app and close the browser.
        successUrl: "truebarber://payment/success",
        cancelUrl: "truebarber://payment/cancel",
        failureUrl: "truebarber://payment/failure",
        
        // 4. NEW: Full Metadata. This is exactly what gets passed to your yoco-webhook.
        metadata: {
          shopId: shopId,
          serviceName: serviceName || 'General Walk-In',
          customerId: customerId,
          paymentType: paymentType 
        }
      }),
    });

    const data = await yocoResponse.json();

    if (!yocoResponse.ok) {
      console.error("Yoco Error:", data);
      throw new Error(data.message || "Failed to create checkout");
    }

    // Return the data (which contains Yoco's hosted 'redirectUrl') to Flutter
    return new Response(JSON.stringify(data), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });
    
  } catch (error: any) {
    console.error("Function Error:", error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    });
  }
});