-- Registro de Ocorrência — schema inicial
-- Login por loja (uma conta compartilhada por loja) + papéis de staff (CCO/Investigação)
-- com acesso a todas as lojas, aplicado via Row Level Security.

-- ============================================================
-- ENUMS
-- ============================================================
create type store_type as enum (
  'deposito_atacado', 'deposito_hiper', 'loja_atacado', 'loja_hiper',
  'express', 'posto', 'farmacia', 'propriedade'
);

create type occurrence_category as enum (
  'social_discriminacao', 'furto', 'acidente', 'operacional', 'fraude', 'outro'
);

create type criticality_level as enum ('alta', 'media', 'baixa');

create type occurrence_status as enum (
  'registrada', 'recebida_cco', 'em_investigacao', 'concluida'
);

create type discriminacao_opt as enum ('sim', 'investigar', 'nao');
create type vitima_opt as enum ('cliente', 'colaborador', 'fornecedor', 'terceiros');
create type conflito_opt as enum ('fisica', 'verbal', 'sem');
create type integridade_opt as enum ('obito', 'ferimentos', 'sem');
create type impacto_opt as enum ('total', 'parcial', 'sem');
create type motivo_opt as enum ('protocolo', 'inconclusivo', 'terceiros');
create type theme_opt as enum ('racial', 'aparencia', 'deficiencia', 'socioeconomica', 'origem', 'genero');

create type staff_role as enum ('cco_central', 'cco_adm', 'investigacao_corp', 'etica', 'midia');

-- ============================================================
-- STORES  (login por loja: 1 auth.users <-> 1 loja)
-- ============================================================
create table stores (
  id            uuid primary key default gen_random_uuid(),
  code          text unique not null,
  name          text not null,
  type          store_type not null,
  region        text,
  active        boolean not null default true,
  auth_user_id  uuid unique references auth.users(id) on delete set null,
  created_at    timestamptz not null default now()
);

-- ============================================================
-- STAFF (CCO Central / CCO Adm / Investigação / Ética / Mídia)
-- login individual, com acesso a todas as lojas
-- ============================================================
create table staff_roles (
  user_id     uuid not null references auth.users(id) on delete cascade,
  role        staff_role not null,
  created_at  timestamptz not null default now(),
  primary key (user_id, role)
);

-- ============================================================
-- DIGITAL ALERTS (fluxo B — canal Mídia; ligação opcional com occurrences)
-- ============================================================
create table digital_alerts (
  id            uuid primary key default gen_random_uuid(),
  received_at   timestamptz not null default now(),
  description   text,
  created_at    timestamptz not null default now()
);

-- ============================================================
-- OCCURRENCES
-- ============================================================
create table occurrences (
  id                 uuid primary key default gen_random_uuid(),
  protocol           text unique not null,
  store_id           uuid not null references stores(id),
  category           occurrence_category not null,
  reported_by_name   text,
  narrative_raw      text,
  report_text        text,

  discriminacao      discriminacao_opt,
  vitima             vitima_opt,
  conflito           conflito_opt,
  integridade        integridade_opt,
  impacto            impacto_opt,
  motivo             motivo_opt,

  criticality        criticality_level not null,
  status             occurrence_status not null default 'registrada',
  linked_alert_id    uuid references digital_alerts(id),

  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create index occurrences_store_id_idx on occurrences(store_id);
create index occurrences_status_idx on occurrences(status);
create index occurrences_criticality_idx on occurrences(criticality);
create index occurrences_created_at_idx on occurrences(created_at);

alter table digital_alerts
  add column linked_occurrence_id uuid references occurrences(id);

-- ============================================================
-- OCCURRENCE THEMES (multi-seleção)
-- ============================================================
create table occurrence_themes (
  occurrence_id  uuid not null references occurrences(id) on delete cascade,
  theme          theme_opt not null,
  primary key (occurrence_id, theme)
);

-- ============================================================
-- EVIDENCE (arquivos no Supabase Storage — bucket 'evidencias')
-- ============================================================
create table occurrence_evidence (
  id             uuid primary key default gen_random_uuid(),
  occurrence_id  uuid not null references occurrences(id) on delete cascade,
  file_path      text not null,   -- chave dentro do bucket
  file_name      text not null,
  file_type      text,
  file_size      bigint,
  uploaded_at    timestamptz not null default now()
);

create index occurrence_evidence_occurrence_id_idx on occurrence_evidence(occurrence_id);

-- ============================================================
-- STATUS HISTORY (linha do tempo — tela de acompanhamento)
-- ============================================================
create table occurrence_status_history (
  id             uuid primary key default gen_random_uuid(),
  occurrence_id  uuid not null references occurrences(id) on delete cascade,
  status         occurrence_status not null,
  note           text,
  changed_by     text,
  changed_at     timestamptz not null default now()
);

create index occurrence_status_history_occurrence_id_idx on occurrence_status_history(occurrence_id);

-- Cada ocorrência nasce com o primeiro evento da linha do tempo já registrado.
create function fn_occurrence_initial_status() returns trigger as $$
begin
  insert into occurrence_status_history (occurrence_id, status, changed_by)
  values (new.id, new.status, coalesce(new.reported_by_name, 'Loja'));
  return new;
end;
$$ language plpgsql security definer;

create trigger trg_occurrence_initial_status
  after insert on occurrences
  for each row execute function fn_occurrence_initial_status();

-- Mantém updated_at em dia.
create function fn_touch_updated_at() returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_occurrences_touch
  before update on occurrences
  for each row execute function fn_touch_updated_at();

-- ============================================================
-- HELPERS para as políticas de RLS
-- ============================================================
create function auth_store_id() returns uuid as $$
  select id from stores where auth_user_id = auth.uid();
$$ language sql stable security definer;

create function is_staff() returns boolean as $$
  select exists (select 1 from staff_roles where user_id = auth.uid());
$$ language sql stable security definer;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================
alter table stores enable row level security;
alter table occurrences enable row level security;
alter table occurrence_themes enable row level security;
alter table occurrence_evidence enable row level security;
alter table occurrence_status_history enable row level security;
alter table digital_alerts enable row level security;
alter table staff_roles enable row level security;

-- stores: cada loja só enxerga o próprio cadastro; staff enxerga todas.
create policy stores_select on stores for select
  using (auth_user_id = auth.uid() or is_staff());

-- occurrences: loja só cria/vê as próprias; staff vê e atualiza tudo.
create policy occurrences_select on occurrences for select
  using (store_id = auth_store_id() or is_staff());

create policy occurrences_insert on occurrences for insert
  with check (store_id = auth_store_id());

create policy occurrences_update_staff on occurrences for update
  using (is_staff());

-- themes / evidence / status_history: seguem a visibilidade da ocorrência-mãe.
create policy occurrence_themes_select on occurrence_themes for select
  using (exists (
    select 1 from occurrences o where o.id = occurrence_id
    and (o.store_id = auth_store_id() or is_staff())
  ));

create policy occurrence_themes_insert on occurrence_themes for insert
  with check (exists (
    select 1 from occurrences o where o.id = occurrence_id and o.store_id = auth_store_id()
  ));

create policy occurrence_evidence_select on occurrence_evidence for select
  using (exists (
    select 1 from occurrences o where o.id = occurrence_id
    and (o.store_id = auth_store_id() or is_staff())
  ));

create policy occurrence_evidence_insert on occurrence_evidence for insert
  with check (exists (
    select 1 from occurrences o where o.id = occurrence_id and o.store_id = auth_store_id()
  ));

create policy occurrence_status_history_select on occurrence_status_history for select
  using (exists (
    select 1 from occurrences o where o.id = occurrence_id
    and (o.store_id = auth_store_id() or is_staff())
  ));

create policy occurrence_status_history_insert_staff on occurrence_status_history for insert
  with check (is_staff());

-- digital_alerts e staff_roles: só staff acessa.
create policy digital_alerts_all_staff on digital_alerts for all
  using (is_staff()) with check (is_staff());

create policy staff_roles_select_self on staff_roles for select
  using (user_id = auth.uid() or is_staff());
