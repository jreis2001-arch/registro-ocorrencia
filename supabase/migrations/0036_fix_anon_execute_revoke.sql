-- A 0035 revogou de "public", mas o Supabase concede EXECUTE direto pro
-- papel "anon" (separado do pseudo-papel "public") em toda função nova —
-- por isso a revogação anterior não teve efeito nenhum, confirmado
-- consultando has_function_privilege('anon', ...) = true em tudo. Revoga
-- do "anon" nomeadamente desta vez.

-- Funções de gatilho/cron: ninguém (nem anon, nem authenticated) deveria
-- conseguir chamar via API.
revoke execute on function fn_occurrence_initial_status() from anon, authenticated;
revoke execute on function fn_store_users_flag_review() from anon, authenticated;
revoke execute on function cleanup_incomplete_signups() from anon, authenticated;

-- Funções internas de regra de acesso e RPCs do app: authenticated
-- continua podendo (é necessário), anon não.
revoke execute on function is_owner() from anon;
revoke execute on function is_staff() from anon;
revoke execute on function is_administrador() from anon;
revoke execute on function is_regional() from anon;
revoke execute on function is_diretor() from anon;
revoke execute on function owner_user_id() from anon;
revoke execute on function viewer_region() from anon;
revoke execute on function auth_store_id() from anon;
revoke execute on function grant_administrator(text) from anon;
revoke execute on function grant_viewer_role(text, text, text) from anon;
revoke execute on function store_directory() from anon;
revoke execute on function store_peers_directory() from anon;
revoke execute on function administrators_directory() from anon;
revoke execute on function viewer_roles_directory() from anon;
