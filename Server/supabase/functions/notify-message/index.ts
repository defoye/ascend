// Sends an APNs push to the recipient of a newly-inserted `messages` row
// (see docs/BACKEND.md "Message push notifications"). Invoked by a Supabase
// Database Webhook on `public.messages` INSERT, type "Supabase Edge
// Functions" — that webhook is configured in the Supabase dashboard, not in
// SQL (there is deliberately no pg_net trigger in
// `Server/supabase/migrations/`), because webhook config is project-specific
// and can't be captured in a portable migration.
//
// Reviewed-only, like every other function in this schema (see
// delete-account/index.ts's header comment): this environment has no
// Docker/Postgres/Deno tooling, so this has not been run locally. The
// recipient-resolution rule (recipient.ts) is split out precisely so IT can
// still be verified with a plain `deno test`, independent of everything
// else here that needs a live project.
//
// OWNER ACTIONS before this does anything in production:
//   1. Create an APNs Auth Key (.p8) in the Apple Developer portal; note its
//      Key ID and your Team ID.
//   2. Enable the Push Notifications capability on the App ID + provisioning.
//   3. Set this function's secrets (`supabase secrets set`, from
//      Server/supabase/): APNS_KEY_ID, APNS_TEAM_ID, APNS_PRIVATE_KEY (the
//      full .p8 PEM contents), APNS_BUNDLE_ID=com.ascend.Ascend, and
//      SUPABASE_SERVICE_ROLE_KEY if not already auto-provided.
//   4. `supabase db push` to apply the device_tokens migration.
//   5. `supabase functions deploy notify-message`.
//   6. Configure a Database Webhook in the Supabase dashboard: table
//      public.messages, event INSERT, type "Supabase Edge Functions",
//      pointing at notify-message.

import { createClient } from "npm:@supabase/supabase-js@2";
import { recipientOf } from "./recipient.ts";

const APNS_HOST = Deno.env.get("APNS_HOST") ?? "api.push.apple.com";

Deno.serve(async (req) => {
  const body = await req.json();
  const m = body.record as {
    id: string;
    engagement_id: string;
    author_id: string;
    body: string;
    sent_at: string;
  };

  // Service-role client: this function never runs on behalf of a specific
  // caller (it's invoked by a Database Webhook, not the app), so there is no
  // caller JWT to scope an anon-key client to — service role is required to
  // read across every person's engagement/device-token rows.
  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: engagement, error: engagementError } = await adminClient
    .from("engagements")
    .select("client_id, professional_id")
    .eq("id", m.engagement_id)
    .single();
  if (engagementError || !engagement) {
    return new Response(JSON.stringify({ error: "engagement_not_found" }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const recipientId = recipientOf(engagement, m.author_id);

  const { data: sender } = await adminClient
    .from("people")
    .select("display_name")
    .eq("id", m.author_id)
    .single();
  const senderName = sender?.display_name ?? "Ascend";

  const { data: tokenRows } = await adminClient
    .from("device_tokens")
    .select("token")
    .eq("person_id", recipientId);
  if (!tokenRows || tokenRows.length === 0) {
    return new Response(JSON.stringify({ ok: true, sent: 0 }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  const jwt = await buildApnsJwt();
  const preview = m.body.length > 140 ? `${m.body.slice(0, 140)}…` : m.body;
  const payload = JSON.stringify({
    aps: { alert: { title: senderName, body: preview }, sound: "default" },
    engagement_id: m.engagement_id,
    message_id: m.id,
  });

  let sent = 0;
  for (const row of tokenRows) {
    const response = await fetch(`https://${APNS_HOST}/3/device/${row.token}`, {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": Deno.env.get("APNS_BUNDLE_ID")!,
        "apns-push-type": "alert",
      },
      body: payload,
    });
    if (response.status === 410) {
      // Apple reports this token as no longer registered — remove it so
      // future messages don't keep retrying a dead token.
      await adminClient.from("device_tokens").delete().eq("token", row.token);
      continue;
    }
    if (response.ok) sent += 1;
  }

  return new Response(JSON.stringify({ ok: true, sent }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});

// ===== APNs token-based (.p8) auth =====
//
// Builds a short-lived ES256-signed JWT per Apple's provider-token
// authentication scheme, using Web Crypto (no external npm APNs library —
// Deno's runtime has no compiled-addon support, so a native binding is a
// non-starter, and the JWT itself is small enough that hand-rolling it is
// simpler than pulling in a dependency for it).
async function buildApnsJwt(): Promise<string> {
  const teamId = Deno.env.get("APNS_TEAM_ID")!;
  const keyId = Deno.env.get("APNS_KEY_ID")!;
  const privateKeyPem = Deno.env.get("APNS_PRIVATE_KEY")!;

  const header = base64url(new TextEncoder().encode(JSON.stringify({ alg: "ES256", kid: keyId })));
  const claims = base64url(
    new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: Math.floor(Date.now() / 1000) }))
  );
  const signingInput = `${header}.${claims}`;

  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToDer(privateKeyPem),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  );
  // Web Crypto's ECDSA signature is the raw r||s concatenation, which is
  // exactly the format JWS ES256 expects — no DER re-encoding needed.
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(signingInput));

  return `${signingInput}.${base64url(new Uint8Array(signature))}`;
}

function pemToDer(pem: string): Uint8Array {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const raw = atob(base64);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes;
}

function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
