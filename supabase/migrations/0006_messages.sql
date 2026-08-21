-- Chat entre CCO e cada loja. Um canal por loja (não por ocorrência) —
-- o CCO pode iniciar a qualquer momento (ex: viu algo pelo CFTV e já avisa
-- a loja para abrir uma ocorrência, antes mesmo dela existir). A loja só
-- consegue responder depois de ter pelo menos uma ocorrência registrada.

create table messages (
  id           uuid primary key default gen_random_uuid(),
  store_id     uuid not null references stores(id),
  sender_role  text not null check (sender_role in ('store', 'staff')),
  sender_name  text,
  body         text not null,
  created_at   timestamptz not null default now()
);

create index messages_store_id_idx on messages(store_id, created_at);

alter table messages enable row level security;

-- Loja só vê as mensagens do próprio canal; staff vê todos.
create policy messages_select on messages for select
  using (store_id = auth_store_id() or is_staff());

-- Staff manda mensagem pra qualquer loja, a qualquer momento. Loja só
-- manda pro próprio canal, e só depois de ter ao menos uma ocorrência.
create policy messages_insert on messages for insert
  with check (
    is_staff()
    or (
      store_id = auth_store_id()
      and exists (select 1 from occurrences o where o.store_id = auth_store_id())
    )
  );

-- Habilita tempo real nessa tabela (mensagens aparecem na hora nos dois lados).
alter publication supabase_realtime add table messages;
