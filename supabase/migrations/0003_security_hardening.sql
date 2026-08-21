-- Fixa o search_path das funções que rodam com privilégio elevado
-- (security definer) ou como trigger. Sem isso, o Security Advisor do
-- Supabase acusa "Function Search Path Mutable": em teoria alguém poderia
-- criar um objeto com o mesmo nome em outro schema e a função passaria a
-- resolver para esse objeto forjado em vez do de "public".

alter function auth_store_id() set search_path = public;
alter function is_staff() set search_path = public;
alter function fn_occurrence_initial_status() set search_path = public;
alter function fn_touch_updated_at() set search_path = public;
