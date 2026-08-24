-- Limpeza automática de cadastros incompletos: alguém cria a conta (e-mail +
-- senha) mas nunca termina de escolher a loja (fecha a aba, desiste etc.) —
-- não tem como saber isso em tempo real, então uma rotina diária apaga essas
-- contas depois de 24h sem finalizar. Contas de staff (CCO) NUNCA são
-- tocadas mesmo sem loja vinculada — elas nunca têm store_users mesmo
-- estando completas, então precisam ficar de fora explicitamente.
create extension if not exists pg_cron;

create or replace function cleanup_incomplete_signups() returns void as $$
begin
  delete from auth.users u
  where u.created_at < now() - interval '24 hours'
    and not exists (select 1 from store_users su where su.user_id = u.id)
    and not exists (select 1 from staff_roles sr where sr.user_id = u.id);
end;
$$ language plpgsql security definer;

alter function cleanup_incomplete_signups() set search_path = public;

-- Roda todo dia às 03:00 (horário de Brasília = 06:00 UTC).
select cron.schedule('cleanup-incomplete-signups', '0 6 * * *', $$select cleanup_incomplete_signups();$$);
