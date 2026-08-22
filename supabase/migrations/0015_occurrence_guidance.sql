-- Orientações de segurança por tipo de ocorrência: o CCO cadastra até 10
-- passos ordenados por tipologia; a loja vê esses passos (se existirem)
-- antes de abrir o chamado daquele tipo.

create table occurrence_guidance (
  id          uuid primary key default gen_random_uuid(),
  tipologia   text not null,
  step_order  integer not null,
  text        text not null,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (tipologia, step_order)
);

create index occurrence_guidance_tipologia_idx on occurrence_guidance(tipologia, step_order);

-- Reaproveita o trigger genérico já usado em occurrences (0001_init.sql).
create trigger trg_guidance_touch
  before update on occurrence_guidance
  for each row execute function fn_touch_updated_at();

alter table occurrence_guidance enable row level security;

-- Qualquer usuário logado (loja ou staff) precisa ler — a tela de registrar
-- ocorrência mostra as orientações antes de abrir o chamado, para lojas
-- também, não só para staff.
create policy occurrence_guidance_select on occurrence_guidance for select
  using (auth.uid() is not null);

-- Só staff cadastra, edita, reordena ou remove.
create policy occurrence_guidance_write_staff on occurrence_guidance for all
  using (is_staff()) with check (is_staff());
