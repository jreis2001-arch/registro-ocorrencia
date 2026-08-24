-- Até agora, cada loja tinha uma única conta compartilhada
-- (stores.auth_user_id, 1:1). Agora uma loja pode ter até 5 "usuários
-- comuns" — cada um com seu próprio login, todos apontando pra mesma loja.
-- A partir do 6º cadastro, o app deve avisar a pessoa e mandar o cadastro
-- pra fila de aprovação do CCO marcado como "exceção".
--
-- Esta migração só ADICIONA coisas — não mexe na tabela stores nem tira o
-- acesso de ninguém que já usa o sistema hoje. A tabela stores.auth_user_id
-- e stores.approved ficam paradas ali (não usadas depois desta migração),
-- de propósito, como histórico/fallback — nada as apaga.
--
-- A migração 0024, que aperta o acesso à tabela stores, só deve rodar
-- depois que o app novo (que já não toca mais em stores.auth_user_id)
-- estiver publicado e testado.

create table store_users (
  id                   uuid primary key default gen_random_uuid(),
  store_id             uuid not null references stores(id) on delete cascade,
  user_id              uuid not null unique references auth.users(id) on delete cascade,
  approved             boolean not null default false,
  needs_special_review boolean not null default false,
  signup_ordinal       int not null default 1,
  created_at           timestamptz not null default now()
);

alter table store_users enable row level security;

-- Cada pessoa só vê a própria linha; CCO vê todas.
create policy store_users_select on store_users for select
  using (user_id = auth.uid() or is_staff());

-- Só pode inserir a própria linha, e nunca já aprovada de cara — aprovar é
-- só o CCO pode (with check trava isso mesmo se o payload do cliente tentar
-- mandar approved:true).
create policy store_users_insert_self on store_users for insert
  with check (user_id = auth.uid() and approved = false);

-- Aprovar/rejeitar (rejeitar = apagar a linha) é só CCO.
create policy store_users_staff_update on store_users for update
  using (is_staff()) with check (is_staff());

create policy store_users_staff_delete on store_users for delete
  using (is_staff());

-- Conta, dentro do próprio banco (não confiando no app), quantos usuários a
-- loja já tem no momento do cadastro, e marca como "exceção" a partir do 6º.
-- O travamento (pg_advisory_xact_lock) evita que duas pessoas se cadastrando
-- ao mesmo tempo "empatem" no 5º lugar e as duas passem sem aviso.
create function fn_store_users_flag_review() returns trigger as $$
declare
  existing_count int;
begin
  perform pg_advisory_xact_lock(hashtext(new.store_id::text));
  select count(*) into existing_count from store_users where store_id = new.store_id;
  new.signup_ordinal := existing_count + 1;
  new.needs_special_review := existing_count >= 5;
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_store_users_flag_review
  before insert on store_users
  for each row execute function fn_store_users_flag_review();

-- Todo o resto do banco (ocorrências, mensagens, evidências, pedidos de
-- exclusão) descobre "qual é a loja dessa pessoa" só chamando esta função —
-- trocando ela por dentro, nada mais no banco precisa mudar.
create or replace function auth_store_id() returns uuid as $$
  select store_id from store_users where user_id = auth.uid() and approved = true;
$$ language sql stable security definer;

alter function auth_store_id() set search_path = public;

-- Migra os logins que já existem hoje pra tabela nova, como usuário nº1 de
-- cada loja — ninguém perde acesso.
insert into store_users (store_id, user_id, approved, signup_ordinal)
select id, auth_user_id, approved, 1
from stores
where auth_user_id is not null;
