-- Autocadastro de loja: até agora, toda conta de loja tinha que ser criada
-- na mão (SQL) vinculando auth_user_id à loja certa — não dá pra fazer isso
-- para 1246 lojas. Agora um funcionário pode criar a própria conta e
-- "reivindicar" a loja dele mesmo, sem precisar de um admin.
--
-- O admin (staff/CCO, ex.: cco@teste) continua sendo cadastrado manualmente
-- via staff_roles — isso não muda.

-- Ver lojas ainda não reivindicadas é necessário pra tela de cadastro poder
-- listar/buscar a loja certa. Continua sem expor a loja de ninguém: só
-- lojas sem dono (auth_user_id is null) ficam visíveis a mais gente, e só
-- pra quem já está autenticado (não a visitantes anônimos).
alter policy stores_select on stores
  using (auth_user_id = auth.uid() or is_staff() or (auth_user_id is null and auth.uid() is not null));

-- Reivindicar uma loja: só é permitido assumir uma loja que ainda não tem
-- dono, e só pra si mesmo — nunca em nome de outra pessoa nem tomando uma
-- loja que já foi reivindicada por outro funcionário.
create policy stores_claim on stores for update
  using (auth_user_id is null)
  with check (auth_user_id = auth.uid());
