import { createClient } from "jsr:@supabase/supabase-js@2";
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

const corsHeaders = {
"Access-Control-Allow-Origin": "*",
"Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

try {
const authHeader = req.headers.get("Authorization");
if (!authHeader) {
return new Response(JSON.stringify({ error: "Nao autenticado." }), { status: 401, headers: corsHeaders });
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

const { data: staffRows } = await supabase.from("staff_roles").select("role").eq("user_id", user.id);
if (!staffRows || staffRows.length === 0) {
return new Response(JSON.stringify({ error: "Apenas staff pode enviar este e-mail." }), { status: 403, headers: corsHeaders });
}

const { to, targetEmail, status, reason } = await req.json();
if (!to || typeof to !== "string") {
return new Response(JSON.stringify({ error: "Destinatario invalido." }), { status: 400, headers: corsHeaders });
}

const statusLabel = status === "aprovada" ? "APROVADA" : "REJEITADA";
const subject = "Solicitacao de inativacao " + statusLabel;
const html = "<div style=\"font-family: sans-serif; max-width: 560px;\">" +
"<h2 style=\"color:#1E3A5F;\">Solicitacao de inativacao " + statusLabel + "</h2>" +
"<p><strong>Usuario:</strong> " + (targetEmail || "-") + "</p>" +
"<p><strong>Status:</strong> " + statusLabel + "</p>" +
(reason ? "<p><strong>Motivo da solicitacao:</strong> " + reason + "</p>" : "") +
"<hr><p style=\"color:#888; font-size:12px;\">Registro de Ocorrencia - mensagem automatica.</p></div>";

const gmailUser = Deno.env.get("GMAIL_USER");
const gmailPass = Deno.env.get("GMAIL_APP_PASSWORD");

const client = new SMTPClient({
connection: {
hostname: "smtp.gmail.com",
port: 465,
tls: true,
auth: {
username: gmailUser,
password: gmailPass,
},
},
});

await client.send({
from: gmailUser,
to,
subject,
content: "auto",
html,
});
await client.close();

return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
} catch (e) {
console.error("ENVIAR_EMAIL_INATIVACAO_FALHOU:", String(e), e && e.stack ? e.stack : "");
return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: corsHeaders });
}
});
