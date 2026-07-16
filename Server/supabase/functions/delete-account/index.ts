// Destroys the caller's Supabase Auth identity. Invoked by
// `SupabaseBackend+AuthGateway.swift`'s `deleteAccount()` — see that file's
// doc comment. The `people` row is anonymized client-side beforehand by
// `AccountDeletionEffect` (never deleted — see its doc comment for the FK-
// cascade rationale); this function only removes the auth.users row, which
// is the one thing the client cannot do with the anon key.
//
// Reviewed-only: this environment has no Docker/Postgres tooling, so this
// function has not been run locally. Deploying it (`supabase functions
// deploy delete-account`, from `Server/supabase/`) is the project owner's
// action — see docs/BACKEND.md.

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    return new Response(JSON.stringify({ error: "missing_authorization" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Anon-key client, scoped to the caller's JWT — used only to resolve who
  // the caller is. Never used to perform the deletion itself.
  const callerClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: authHeader } } }
  );

  const { data: { user }, error: getUserError } = await callerClient.auth.getUser();
  if (getUserError || !user) {
    return new Response(JSON.stringify({ error: "invalid_session" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  // Service-role client — the only credential with `auth.admin` rights.
  // Never exposed to the app; read from Supabase's server-side secrets.
  const adminClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);
  if (deleteError) {
    return new Response(JSON.stringify({ error: deleteError.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
