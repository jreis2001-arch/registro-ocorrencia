-- Script de uma vez só (não é migração de schema, é carga de dados de teste):
-- Cria até 200 ocorrências variadas para popular o painel:
--   - 25 extrema / 45 alta / 60 media / 70 baixa
--   - espalhadas nas 5 regiões (Norte/Nordeste/Centro-Oeste/Sudeste/Sul),
--     ~40 por região, usando um pool de até 8 lojas de formatos variados
--     por região (não todas as lojas — só "algumas")
--   - espalhadas em madrugada/manhã/tarde/noite, ~50 de cada
--   - tipologia/categoria escolhidas de forma coerente com a criticidade
--
-- Marcada com reporter_name = 'Dados de teste (seed)' e prefixo
-- '[DADOS DE TESTE]' na narrativa, igual à carga anterior — assim dá pra
-- limpar depois com o mesmo filtro:
--   delete from occurrences where reporter_name = 'Dados de teste (seed)';
do $$
declare
  counter int := 1;
  new_protocol text;
  report text;
  r record;
  crit_val text;
  tipologia_val text;
  categoria_val text;
  periodo text;
  hour_val int;
  minute_val int;
  day_offset int;
  ts timestamptz;
  obito_flag text;
  fechada_flag text;
begin
  drop table if exists seed_pool;
  drop table if exists seed_tipologias;

  create temp table seed_pool as
  with store_region as (
    select s.id, s.name, s.state, s.cidade, s.type,
      case
        when s.state in ('AC','AP','AM','PA','RO','RR','TO') then 'Norte'
        when s.state in ('AL','BA','CE','MA','PB','PE','PI','RN','SE') then 'Nordeste'
        when s.state in ('DF','GO','MT','MS') then 'Centro-Oeste'
        when s.state in ('ES','MG','RJ','SP') then 'Sudeste'
        when s.state in ('PR','RS','SC') then 'Sul'
      end as region
    from stores s
    where s.state is not null
  ),
  ranked as (
    select *, row_number() over (partition by region order by random()) as rn
    from store_region
    where region is not null
  )
  select id, name, state, cidade, type, region
  from ranked
  where rn <= 8;

  create temp table seed_tipologias (crit text, tipologia text, categoria text);
  insert into seed_tipologias values
    ('extrema', 'Óbito sem causa confirmada', 'Acidentes'),
    ('extrema', 'Homicídio', 'Emergências Policiais'),
    ('extrema', 'Suicídio', 'Acidentes'),
    ('extrema', 'Sequestro', 'Emergências Policiais'),
    ('alta', 'Roubo', 'Segurança'),
    ('alta', 'Arrombamento', 'Segurança'),
    ('alta', 'Invasão', 'Segurança'),
    ('alta', 'Incêndio', 'Danos Patrimoniais'),
    ('alta', 'Violências', 'Violência Contra Pessoa'),
    ('alta', 'Atropelamento', 'Acidentes'),
    ('media', 'Desacordo/Discussão', 'Violência Contra Pessoa'),
    ('media', 'Vandalismo', 'Danos Patrimoniais'),
    ('media', 'Dano estrutural', 'Manutenção'),
    ('media', 'Contaminação alimentar', 'Operações'),
    ('media', 'Mendincância', 'Segurança'),
    ('media', 'Fratura', 'Acidentes'),
    ('baixa', 'Furto', 'Segurança'),
    ('baixa', 'Rotinas de loja', 'Operações'),
    ('baixa', 'Falta de produto', 'Operações'),
    ('baixa', 'Pragas', 'Operações'),
    ('baixa', 'Fiscalização', 'Administrativo'),
    ('baixa', 'Animais na Unidade', 'Ambiental');

  for i in 1..200 loop
    crit_val := case
      when i <= 25 then 'extrema'
      when i <= 70 then 'alta'
      when i <= 130 then 'media'
      else 'baixa'
    end;

    select sp.id, sp.name, sp.state, sp.cidade, sp.type
      into r
      from seed_pool sp
      where sp.region = (array['Norte','Nordeste','Centro-Oeste','Sudeste','Sul'])[1 + ((i - 1) % 5)]
      order by random()
      limit 1;

    if r.id is null then
      continue;
    end if;

    select t.tipologia, t.categoria into tipologia_val, categoria_val
      from seed_tipologias t
      where t.crit = crit_val
      order by random()
      limit 1;

    periodo := (array['madrugada', 'manhã', 'tarde', 'noite'])[1 + ((i - 1) % 4)];
    hour_val := case periodo
      when 'madrugada' then floor(random() * 6)::int
      when 'manhã' then 6 + floor(random() * 6)::int
      when 'tarde' then 12 + floor(random() * 6)::int
      else 18 + floor(random() * 6)::int
    end;
    minute_val := floor(random() * 60)::int;
    day_offset := floor(random() * 45)::int;
    ts := (current_date - day_offset)::timestamp + (hour_val || ' hours')::interval + (minute_val || ' minutes')::interval;

    obito_flag := case when crit_val = 'extrema' and tipologia_val in ('Óbito sem causa confirmada', 'Homicídio', 'Suicídio') then 'Sim' else 'Não' end;
    fechada_flag := case
      when crit_val = 'extrema' and tipologia_val = 'Sequestro' then 'Sim'
      when crit_val = 'alta' and random() < 0.2 then 'Sim'
      else 'Não'
    end;

    new_protocol := 'RO-2026-SEED-' || lpad(counter::text, 6, '0');
    counter := counter + 1;

    report := 'RELATO FORMAL DE OCORRÊNCIA' || E'\n\n' ||
      'Protocolo: ' || new_protocol || E'\n' ||
      'Criticidade: ' || initcap(crit_val) || E'\n\n' ||
      'DADOS DA LOJA' || E'\n' ||
      'Loja: ' || r.name || E'\n' ||
      'Estado: ' || coalesce(r.state, '—') || E'\n' ||
      'Cidade: ' || coalesce(r.cidade, '—') || E'\n\n' ||
      'DADOS DA OCORRÊNCIA' || E'\n' ||
      'Tipo de ocorrência: ' || tipologia_val || E'\n' ||
      'Categoria: ' || categoria_val || E'\n\n' ||
      'DESCRIÇÃO' || E'\n' ||
      '[DADOS DE TESTE] Ocorrência gerada para popular o painel com uma amostra variada de riscos, regiões e horários.';

    insert into occurrences (
      protocol, store_id, categoria, tipologia,
      reporter_name, reporter_relationship,
      incident_date, incident_time,
      narrative_raw, report_text,
      respostas_dinamicas, criticality, created_at
    ) values (
      new_protocol, r.id, categoria_val, tipologia_val,
      'Dados de teste (seed)', 'Colaborador',
      ts::date, ts::time,
      '[DADOS DE TESTE] Ocorrência gerada para popular o painel com uma amostra variada de riscos, regiões e horários.', report,
      jsonb_build_object('houve_obito', obito_flag, 'loja_fechada', fechada_flag), crit_val::criticality_level, ts
    );
  end loop;

  raise notice 'Ocorrências de teste variadas criadas: %', counter - 1;
end $$;
