-- Mesmo motivo da 0033: o Supabase acusou "Security Definer View" pra
-- store_directory (usada na busca de loja do autocadastro). Views, por
-- padrão do Postgres, sempre rodam com a permissão de quem criou — aqui
-- isso é necessário mesmo (uma conta sem loja ainda precisa listar TODAS as
-- lojas ativas pra poder escolher uma), mas o jeito que o Supabase espera
-- ver essa intenção declarada explicitamente é como função, não como view.
drop view store_directory;

create function store_directory() returns table(id uuid, name text, code text, type store_type) as $$
  select id, name, code, type from stores where active;
$$ language sql stable security definer;

alter function store_directory() set search_path = public;
grant execute on function store_directory() to authenticated;
