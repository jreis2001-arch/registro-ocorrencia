-- Estado (UF) de cada loja, para o painel de mapa do CCO.
-- Região (Norte/Nordeste/Centro-Oeste/Sudeste/Sul) é derivada do estado no
-- próprio painel, não fica guardada aqui — evita loja cadastrada com estado
-- e região que não batem entre si.

alter table stores add column state char(2);

alter table stores add constraint stores_state_valid check (
  state is null or state in (
    'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA',
    'PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
  )
);

create index stores_state_idx on stores(state);
