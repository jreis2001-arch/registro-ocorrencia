-- O Supabase acusou "user data exposed through a view" para as 3 views que
-- juntam auth.users pra pegar o e-mail (administrators_directory,
-- store_peers_directory, viewer_roles_directory). Cada uma já filtra
-- corretamente por dentro (staff vê zero linhas se não for staff, etc.) —
-- não havia vazamento de dado de verdade — mas "view" depende inteiramente
-- desse filtro interno, sem o reforço nativo de RLS por trás. O jeito
-- recomendado (e que já usamos em outros lugares, como grant_administrator)
-- é função com security definer, chamada via RPC em vez de select numa
-- tabela/view. Troca as 3 views por funções equivalentes.

drop view administrators_directory;

create function administrators_directory() returns table(user_id uuid, email text, created_at timestamptz) as $$
  select sr.user_id, u.email, sr.created_at
  from staff_roles sr
  join auth.users u on u.id = sr.user_id
  where sr.role = 'administrador' and is_staff();
$$ language sql stable security definer;

alter function administrators_directory() set search_path = public;
grant execute on function administrators_directory() to authenticated;

drop view store_peers_directory;

create function store_peers_directory() returns table(id uuid, store_id uuid, email text) as $$
  select su.id, su.store_id, u.email
  from store_users su
  join auth.users u on u.id = su.user_id
  where su.approved = true
    and su.active = true
    and su.store_id = auth_store_id()
    and su.user_id <> auth.uid();
$$ language sql stable security definer;

alter function store_peers_directory() set search_path = public;
grant execute on function store_peers_directory() to authenticated;

drop view viewer_roles_directory;

create function viewer_roles_directory() returns table(user_id uuid, email text, scope text, region text, created_at timestamptz) as $$
  select vr.user_id, u.email, vr.scope, vr.region, vr.created_at
  from viewer_roles vr
  join auth.users u on u.id = vr.user_id
  where is_staff();
$$ language sql stable security definer;

alter function viewer_roles_directory() set search_path = public;
grant execute on function viewer_roles_directory() to authenticated;
