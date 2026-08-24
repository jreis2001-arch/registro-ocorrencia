-- NÃO RODAR ainda — só depois que o index.html novo (que já não toca mais em
-- stores.auth_user_id) estiver publicado e testado. Ver 0023 para contexto.
--
-- A 0011/0012 abriram a tabela stores pra contas logadas verem lojas "sem
-- dono" (auth_user_id is null), pra tela de autocadastro poder buscar. No
-- modelo novo (0023) não existe mais "sem dono" — toda loja aceita cadastro
-- sempre — então reabrir essa mesma regra deixaria QUALQUER conta que ainda
-- não entrou em nenhuma loja enxergar endereço/diretor/supervisor de todas
-- as ~1246 lojas, pra sempre (não só enquanto a loja está sem dono, como
-- era antes). Por isso a tela de busca passa a usar uma view separada, só
-- com colunas seguras, e a tabela stores volta a ficar restrita.

-- View só com o necessário pra tela "Qual é a sua loja?" buscar/listar.
create view store_directory as
  select id, name, code, type
  from stores
  where active;

grant select on store_directory to authenticated;

-- Fecha a tabela stores de volta pra "só a própria loja, ou CCO" — sem a
-- brecha de "lojas sem dono visíveis a qualquer logado".
alter policy stores_select on stores
  using (
    is_staff()
    or exists (select 1 from store_users su where su.store_id = stores.id and su.user_id = auth.uid())
  );

-- "Reivindicar" via update direto em stores não existe mais (agora é
-- inserir em store_users) — essa policy antiga ficaria como uma porta de
-- escrita aberta e inútil, então remove.
drop policy if exists stores_claim on stores;
drop function if exists has_claimed_store();
