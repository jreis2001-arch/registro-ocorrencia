-- Fecha o buraco de segurança do autocadastro: hoje, reivindicar uma loja
-- já dava acesso imediato — qualquer pessoa na internet podia se cadastrar
-- como qualquer loja sem ninguém confirmar. Agora a loja fica "pendente"
-- até um staff aprovar manualmente.

alter table stores add column approved boolean not null default false;

-- Contas que já existiam antes desta migração (login já vinculado a uma
-- loja) continuam funcionando normalmente — só cadastros NOVOS a partir
-- daqui nascem pendentes.
update stores set approved = true where auth_user_id is not null;

-- auth_store_id() é usado por TODAS as políticas de RLS (ocorrências,
-- mensagens, evidências, histórico) como "esta é a loja de quem está
-- logado". Fazendo ele exigir approved=true, uma conta pendente fica
-- automaticamente travada em tudo — não só na tela do app, que dava pra
-- contornar chamando a API direto.
create or replace function auth_store_id() returns uuid as $$
  select id from stores where auth_user_id = auth.uid() and approved = true;
$$ language sql stable security definer;
alter function auth_store_id() set search_path = public;

-- Staff precisa poder aprovar (approved=true) ou rejeitar (solta a loja de
-- volta, auth_user_id=null) um cadastro pendente.
create policy stores_update_staff on stores for update
  using (is_staff())
  with check (is_staff());
