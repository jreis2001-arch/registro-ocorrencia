import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders = {
"Access-Control-Allow-Origin": "*",
"Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// Finds a user by e-mail without assuming everyone fits on page 1 — this
// project has 1000+ store accounts on top of staff/admin/viewer accounts.
async function findUserByEmail(supabaseAdmin, email) {
const perPage = 1000;
for (let page = 1; page <= 20; page++) {
const { data, error } = await supabaseAdmin.auth.admin.listUsers({ page, perPage });
if (error) throw error;
const found = data.users.find((u) => (u.email || "").toLowerCase() === email.toLowerCase());
if (found) return found;
if (data.users.length < perPage) break;
}
return null;
}

Deno.serve(async (req) => {
if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

try {
const authHeader = req.headers.get("Authorization");
if (!authHeader) {
return new Response(JSON.stringify({ error: "Nao autenticado." }), { status: 401, headers: corsHeaders });
}

let payload;
try {
const token = authHeader.replace("Bearer ", "");
payload = JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/")));
} catch (_e) {
return new Response(JSON.stringify({ error: "Token invalido." }), { status: 401, headers: corsHeaders });
}

const supabase = createClient(
Deno.env.get("SUPABASE_URL"),
Deno.env.get("SUPABASE_ANON_KEY"),
{ global: { headers: { Authorization: authHeader } } },
);
const { data: { user }, error: userError } = await supabase.auth.getUser();
if (userError || !user) {
return new Response(JSON.stringify({ error: "Nao autenticado." }), { status: 401, headers: corsHeaders });
}

// Owner-only, and only with a session that already confirmed its own
// second factor — resetting someone else's 2FA is itself a sensitive,
// step-up-gated action, same spirit as granting/removing administrador.
if ((user.email || "").toLowerCase() !== "jreis2001@gmail.com") {
return new Response(JSON.stringify({ error: "Apenas o dono do sistema pode resetar o segundo fator de outra pessoa." }), { status: 403, headers: corsHeaders });
}
if (payload.aal !== "aal2") {
return new Response(JSON.stringify({ error: "Confirme seu proprio codigo do autenticador antes de resetar o de outra pessoa." }), { status: 403, headers: corsHeaders });
}

const { targetEmail } = await req.json();
if (!targetEmail || typeof targetEmail !== "string") {
return new Response(JSON.stringify({ error: "Informe o e-mail da pessoa." }), { status: 400, headers: corsHeaders });
}

const supabaseAdmin = createClient(
Deno.env.get("SUPABASE_URL"),
Deno.env.get("SUPABASE_SERVICE_ROLE_KEY"),
);

const targetUser = await findUserByEmail(supabaseAdmin, targetEmail);
if (!targetUser) {
return new Response(JSON.stringify({ error: "Nenhum usuario encontrado com esse e-mail." }), { status: 404, headers: corsHeaders });
}

const factors = targetUser.factors || [];
let removed = 0;
for (const f of factors) {
const { error: delErr } = await supabaseAdmin.auth.admin.mfa.deleteFactor({ id: f.id, userId: targetUser.id });
if (!delErr) removed++;
}

return new Response(JSON.stringify({ ok: true, removed }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
} catch (e) {
console.error("RESETAR_MFA_ADMIN_FALHOU:", String(e), e && e.stack ? e.stack : "");
return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: corsHeaders });
}
});
