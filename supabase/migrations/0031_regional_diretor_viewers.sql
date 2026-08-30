-- Dois novos papéis de visualização (não são administradores — não aprovam
-- nem gerenciam nada, só enxergam o painel):
--   - regional: vê o painel com dados de todas as lojas da própria região.
--   - diretor:  vê o painel com dados de todas as regiões.
--
-- A pessoa precisa já ter uma conta (e-mail/senha) antes de virar
-- regional/diretor — um administrador concede depois, pelo e-mail. Mesmo
-- padrão de grant_administrator() (0027), só que para um papel bem mais
-- limitado.

-- Mesmo mapeamento estado -> região que o app já usa no JS
-- (REGION_BY_STATE), agora disponível para as regras do banco também.
create function region_of_state(p_state text) returns text as $$
  select case
    when p_state in ('AC','AP','AM','PA','RO','RR','TO') then 'Norte'
    when p_state in ('AL','BA','CE','MA','PB','PE','PI','RN','SE') then 'Nordeste'
    when p_state in ('DF','GO','MT','MS') then 'Centro-Oeste'
    when p_state in ('ES','MG','RJ','SP') then 'Sudeste'
    when p_state in ('PR','RS','SC') then 'Sul'
  end;
$$ language sql immutable;

create table viewer_roles (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null unique references auth.users(id) on delete cascade,
  scope      text not null check (scope in ('regional', 'diretor')),
  region     text check (region in ('Norte', 'Nordeste', 'Centro-Oeste', 'Sudeste', 'Sul')),
  created_at timestamptz not null default now(),
  constraint viewer_roles_region_matches_scope check (
    (scope = 'regional' and region is not null) or (scope = 'diretor' and region is null)
  )
);

alter table viewer_roles enable row level security;

create policy viewer_roles_select on viewer_roles for select
  using (user_id = auth.uid() or is_staff());

create policy viewer_roles_staff_manage on viewer_roles for all
  using (is_staff()) with check (is_staff());

create function is_regional() returns boolean as $$
  select exists (select 1 from viewer_roles where user_id = auth.uid() and scope = 'regional');
$$ language sql stable security definer;
alter function is_regional() set search_path = public;

create function is_diretor() returns boolean as $$
  select exists (select 1 from viewer_roles where user_id = auth.uid() and scope = 'diretor');
$$ language sql stable security definer;
alter function is_diretor() set search_path = public;

create function viewer_region() returns text as $$
  select region from viewer_roles where user_id = auth.uid();
$$ language sql stable security definer;
alter function viewer_region() set search_path = public;

-- Concede (ou atualiza) o papel — resolve o e-mail por dentro, valida a
-- região quando for regional.
create function grant_viewer_role(p_email text, p_scope text, p_region text default null) returns void as $$
declare
  target_id uuid;
begin
  if not is_staff() then
    raise exception 'Apenas staff pode conceder esse acesso.';
  end if;
  if p_scope not in ('regional', 'diretor') then
    raise exception 'Papel inválido — use regional ou diretor.';
  end if;
  if p_scope = 'regional' and p_region not in ('Norte', 'Nordeste', 'Centro-Oeste', 'Sudeste', 'Sul') then
    raise exception 'Região inválida.';
  end if;

  select id into target_id from auth.users where lower(email) = lower(p_email);
  if target_id is null then
    raise exception 'Nenhum usuário encontrado com esse e-mail.';
  end if;

  insert into viewer_roles (user_id, scope, region)
  values (target_id, p_scope, case when p_scope = 'diretor' then null else p_region end)
  on conflict (user_id) do update set scope = excluded.scope, region = excluded.region;
end;
$$ language plpgsql security definer;
alter function grant_viewer_role(text, text, text) set search_path = public;
grant execute on function grant_viewer_role(text, text, text) to authenticated;

-- Amplia a visibilidade de stores/occurrences para os dois papéis novos —
-- mesmas policies de 0024/0001, só acrescentando as cláusulas de escopo.
alter policy stores_select on stores
  using (
    is_staff()
    or exists (select 1 from store_users su where su.store_id = stores.id and su.user_id = auth.uid())
    or is_diretor()
    or (is_regional() and region_of_state(stores.state) = viewer_region())
  );

alter policy occurrences_select on occurrences
  using (
    store_id = auth_store_id()
    or is_staff()
    or is_diretor()
    or (is_regional() and exists (
      select 1 from stores s where s.id = occurrences.store_id and region_of_state(s.state) = viewer_region()
    ))
  );

-- Visão para a tela de gestão listar quem tem acesso hoje.
create view viewer_roles_directory as
  select vr.user_id, u.email, vr.scope, vr.region, vr.created_at
  from viewer_roles vr
  join auth.users u on u.id = vr.user_id
  where is_staff();

grant select on viewer_roles_directory to authenticated;
