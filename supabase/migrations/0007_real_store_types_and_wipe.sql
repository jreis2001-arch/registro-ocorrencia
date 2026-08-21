-- 1) Limpa toda a base de teste (mensagens, ocorrências e lojas) antes de
--    trocar os tipos de loja e importar a base oficial.
delete from messages;
delete from occurrences;  -- cascata: occurrence_themes, occurrence_evidence, occurrence_status_history
delete from stores;

-- 2) Os 8 tipos criados no início eram um chute baseado numa descrição
--    informal — a base oficial (BASE.xlsx) tem 16 formatos reais. Como a
--    tabela já está vazia (passo acima), dá pra recriar o enum do zero.
alter table stores drop column type;
drop type store_type;

create type store_type as enum (
  'atacadao',            -- Atacadão
  'express',             -- Express
  'hiper',               -- Hiper
  'drogaria',            -- Drogaria
  'posto',               -- Posto
  'super',               -- Super
  'sams_club',           -- Sam's Club
  'todo_dia',            -- Todo Dia
  'cd_atacadao',         -- CD - Atacadão
  'express_autonoma',    -- Express/Autônoma
  'cd',                  -- CD
  'escritorio',          -- Escritório
  'ecommerce',           -- Ecommerce
  'property',            -- Property (shoppings/imóveis)
  'banco',               -- Banco
  'residencia_executiva' -- Residência Executiva
);

alter table stores add column type store_type not null;
