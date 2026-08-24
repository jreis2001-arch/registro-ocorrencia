-- Inativação de usuário de loja: a loja pede, um administrador aprova, a
-- pessoa fica bloqueada de usar o sistema — mas a linha em store_users
-- (e tudo vinculado a ela, como ocorrências já registradas) NUNCA é
-- apagada. É bloqueio de acesso, não exclusão de histórico.
--
-- Maior risco desta migração: auth_store_id() é o único ponto que todo o
-- resto do banco usa pra saber "qual loja é essa pessoa" — mexer nela
-- afeta ocorrências, mensagens, evidências e pedidos de exclusão de uma
-- vez só. Testar login de uma loja real já aprovada logo depois de rodar.

alter table store_users add column active boolean not null default true;

create or replace function auth_store_id() returns uuid as $$
  select store_id from store_users where user_id = auth.uid() and approved = true and active = true;
$$ language sql stable security definer;

alter function auth_store_id() set search_path = public;

-- Pra tela de pedido conseguir listar "quem eu quero inativar": hoje
-- ninguém vê os colegas de loja (store_users_select só mostra a própria
-- linha). Auto-restrita: cada sessão só enxerga os pares da SUA PRÓPRIA
-- loja, resolvido via auth_store_id() por dentro da view.
create view store_peers_directory as
  select su.id, su.store_id, u.email
  from store_users su
  join auth.users u on u.id = su.user_id
  where su.approved = true
    and su.active = true
    and su.store_id = auth_store_id()
    and su.user_id <> auth.uid();

grant select on store_peers_directory to authenticated;

create table user_deactivation_requests (
  id            uuid primary key default gen_random_uuid(),
  store_user_id uuid not null references store_users(id) on delete cascade,
  store_id      uuid not null references stores(id),
  reason        text not null,
  status        text not null default 'pendente' check (status in ('pendente', 'aprovada', 'rejeitada')),
  requested_by  text,
  requested_at  timestamptz not null default now(),
  reviewed_at   timestamptz
);

create index user_deactivation_requests_status_idx on user_deactivation_requests(status);

alter table user_deactivation_requests enable row level security;

-- Loja vê os próprios pedidos; staff vê todos.
create policy user_deactivation_requests_select on user_deactivation_requests for select
  using (store_id = auth_store_id() or is_staff());

-- Loja cria pedido pra si mesma.
create policy user_deactivation_requests_insert on user_deactivation_requests for insert
  with check (store_id = auth_store_id());

-- Só staff aprova/rejeita.
create policy user_deactivation_requests_update_staff on user_deactivation_requests for update
  using (is_staff()) with check (is_staff());
