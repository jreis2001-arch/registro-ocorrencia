-- Corrige os 38 avisos (não erros) do Security Advisor: search_path fixo
-- em funções que ficaram sem, e remoção do acesso padrão que o Postgres dá
-- a QUALQUER função nova (inclusive pra quem nem logou, o papel "anon") —
-- nenhuma das funções abaixo deveria ser chamável por anon, e várias nem
-- deveriam ser chamadas diretamente por ninguém (só usadas por dentro de
-- outras regras/gatilhos).

-- ── search_path fixo ──────────────────────────────────────────────
alter function fn_store_users_flag_review() set search_path = public;
alter function region_of_state(text) set search_path = public;
alter function fn_occurrence_initial_status() set search_path = public;
alter function fn_touch_updated_at() set search_path = public;
alter function is_staff() set search_path = public;

-- ── Funções de gatilho/cron: ninguém chama isso direto, nem logado ──
revoke execute on function fn_occurrence_initial_status() from public;
revoke execute on function fn_store_users_flag_review() from public;
revoke execute on function cleanup_incomplete_signups() from public;

-- ── Funções internas de regra de acesso: authenticated precisa (são
-- usadas dentro das próprias regras de segurança), anon nunca precisa ──
revoke execute on function is_owner() from public;
grant execute on function is_owner() to authenticated;

revoke execute on function is_staff() from public;
grant execute on function is_staff() to authenticated;

revoke execute on function is_administrador() from public;
grant execute on function is_administrador() to authenticated;

revoke execute on function is_regional() from public;
grant execute on function is_regional() to authenticated;

revoke execute on function is_diretor() from public;
grant execute on function is_diretor() to authenticated;

revoke execute on function owner_user_id() from public;
grant execute on function owner_user_id() to authenticated;

revoke execute on function viewer_region() from public;
grant execute on function viewer_region() to authenticated;

revoke execute on function auth_store_id() from public;
grant execute on function auth_store_id() to authenticated;

-- ── Funções que o app chama direto (RPC): authenticated sim, anon não ──
revoke execute on function grant_administrator(text) from public;
grant execute on function grant_administrator(text) to authenticated;

revoke execute on function grant_viewer_role(text, text, text) from public;
grant execute on function grant_viewer_role(text, text, text) to authenticated;

revoke execute on function store_directory() from public;
grant execute on function store_directory() to authenticated;

revoke execute on function store_peers_directory() from public;
grant execute on function store_peers_directory() to authenticated;

revoke execute on function administrators_directory() from public;
grant execute on function administrators_directory() to authenticated;

revoke execute on function viewer_roles_directory() from public;
grant execute on function viewer_roles_directory() to authenticated;
