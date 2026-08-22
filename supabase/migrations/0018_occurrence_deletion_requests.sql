-- Exclusão de ocorrência em duas etapas: a loja pede (protocolo, data,
-- motivo), fica "pendente" até um staff aprovar. Só a aprovação exclui de
-- verdade — a loja nunca apaga a ocorrência sozinha.

create table occurrence_deletion_requests (
  id             uuid primary key default gen_random_uuid(),
  occurrence_id  uuid references occurrences(id) on delete set null,
  protocol       text not null,
  store_id       uuid not null references stores(id),
  incident_date  date not null,
  reason         text not null,
  status         text not null default 'pendente' check (status in ('pendente', 'aprovada', 'rejeitada')),
  requested_by   text,
  requested_at   timestamptz not null default now(),
  reviewed_at    timestamptz
);

create index occurrence_deletion_requests_status_idx on occurrence_deletion_requests(status);

alter table occurrence_deletion_requests enable row level security;

-- Loja vê os próprios pedidos; staff vê todos.
create policy deletion_requests_select on occurrence_deletion_requests for select
  using (store_id = auth_store_id() or is_staff());

-- Loja cria pedido pra si mesma; staff também pode criar em nome de uma loja
-- (mesmo padrão já usado para registrar ocorrência em nome de loja).
create policy deletion_requests_insert on occurrence_deletion_requests for insert
  with check (store_id = auth_store_id() or is_staff());

-- Só staff aprova/rejeita — "a exclusão deverá ser feita apenas pelo administrador".
create policy deletion_requests_update_staff on occurrence_deletion_requests for update
  using (is_staff()) with check (is_staff());

-- Não existia NENHUMA policy de delete em occurrences até agora (por isso
-- limpezas manuais sempre precisaram do SQL Editor, que ignora RLS). Essa é
-- necessária para o staff conseguir aprovar uma exclusão pelo próprio app.
create policy occurrences_delete_staff on occurrences for delete
  using (is_staff());
