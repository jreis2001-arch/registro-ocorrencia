-- A 0011 liberou ver lojas sem dono pra tela de autocadastro conseguir
-- listar/buscar a loja certa — mas isso ficava valendo pra sempre, mesmo
-- depois do usuário já ter escolhido a loja dele. Resultado: qualquer
-- conta comum logada conseguia listar endereço, diretor e supervisor de
-- riscos de centenas de outras lojas (mesmo lojas que só ainda não tinham
-- login cadastrado), bastando um select("*") direto — não só pela tela do
-- app. Essa migração fecha isso: só quem AINDA não tem loja própria (ou
-- seja, está no meio do cadastro) continua vendo as não reivindicadas.
-- Depois de reivindicar, só a própria loja.

create function has_claimed_store() returns boolean as $$
  select exists (select 1 from stores where auth_user_id = auth.uid());
$$ language sql stable security definer;

alter function has_claimed_store() set search_path = public;

alter policy stores_select on stores
  using (
    auth_user_id = auth.uid()
    or is_staff()
    or (auth_user_id is null and auth.uid() is not null and not has_claimed_store())
  );
