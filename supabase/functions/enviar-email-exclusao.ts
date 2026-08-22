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

const { to, protocol, status, reason, message } = await req.json();
if (!to || typeof to !== "string") {
return new Response(JSON.stringify({ error: "Destinatario invalido." }), { status: 400, headers: corsHeaders });
}

const statusLabel = status === "aprovada" ? "APROVADA" : "REJEITADA";
const subject = "Solicitacao de exclusao " + statusLabel + " - " + protocol;
const html = "<div style=\"font-family: sans-serif; max-width: 560px;\">" +
"<h2 style=\"color:#1E3A5F;\">Solicitacao de exclusao " + statusLabel + "</h2>" +
"<p><strong>Protocolo:</strong> " + protocol + "</p>" +
"<p><strong>Status:</strong> " + statusLabel + "</p>" +
(reason ? "<p><strong>Motivo da solicitacao:</strong> " + reason + "</p>" : "") +
(message ? "<p><strong>Mensagem do CCO:</strong><br>" + message + "</p>" : "") +
"<hr><p style=\"color:#888; font-size:12px;\">Registro de Ocorrencia - mensagem automatica.</p></div>";

const client = new SMTPClient({
connection: {
hostname: "smtp.gmail.com",
port: 465,
tls: true,
auth: {
username: Deno.env.get("GMAIL_USER"),
password: Deno.env.get("GMAIL_APP_PASSWORD"),
},
},
});

await client.send({
from: Deno.env.get("GMAIL_USER"),
to,
subject,
content: "auto",
html,
});
await client.close();

return new Response(JSON.stringify({ ok: true }), { headers: { ...corsHeaders, "Content-Type": "application/json" } });
} catch (e) {
return new Response(JSON.stringify({ error: String(e) }), { status: 500, headers: corsHeaders });
}
});
