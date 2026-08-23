-- Script de uma vez só (não é migração de schema, é manutenção de dados):
-- 1) Reclassifica pra "extrema" qualquer ocorrência existente que já tinha
--    "houve_obito: Sim" ou "loja_fechada: Sim" registrado nas respostas
--    (antes da 0020 essas caíam em "alta", teto que existia até então).
-- 2) Cria 1 ocorrência extrema nova por loja, para todas as lojas que NÃO
--    tiveram nenhuma ocorrência reclassificada no passo 1 (para não deixar
--    a mesma loja com duas ocorrências extremas de uma vez).
do $$
declare
  reclassified_stores uuid[];
  s record;
  counter int := 1;
  new_protocol text;
  report text;
  tipologia_val text := 'Óbito sem causa confirmada';
  categoria_val text := 'Acidentes';
begin
  with upd as (
    update occurrences
    set criticality = 'extrema'
    where criticality <> 'extrema'
      and (respostas_dinamicas->>'houve_obito' = 'Sim' or respostas_dinamicas->>'loja_fechada' = 'Sim')
    returning store_id
  )
  select coalesce(array_agg(distinct store_id), array[]::uuid[]) into reclassified_stores from upd;

  raise notice 'Lojas reclassificadas: %', coalesce(array_length(reclassified_stores, 1), 0);

  for s in
    select * from stores where id <> all(reclassified_stores)
  loop
    new_protocol := 'RO-2026-EXT-' || lpad(counter::text, 6, '0');
    counter := counter + 1;

    report := 'RELATO FORMAL DE OCORRÊNCIA' || E'\n\n' ||
      'Protocolo: ' || new_protocol || E'\n' ||
      'Criticidade: Extremo' || E'\n\n' ||
      'DADOS DA LOJA' || E'\n' ||
      'Loja: ' || s.name || E'\n' ||
      'Estado: ' || coalesce(s.state, '—') || E'\n' ||
      'Cidade: ' || coalesce(s.cidade, '—') || E'\n\n' ||
      'DADOS DA OCORRÊNCIA' || E'\n' ||
      'Tipo de ocorrência: ' || tipologia_val || E'\n' ||
      'Categoria: ' || categoria_val || E'\n\n' ||
      'DESCRIÇÃO' || E'\n' ||
      '[DADOS DE TESTE] Ocorrência extrema gerada para validação do painel de riscos.';

    insert into occurrences (
      protocol, store_id, categoria, tipologia,
      reporter_name, reporter_relationship,
      incident_date, incident_time,
      narrative_raw, report_text,
      respostas_dinamicas, criticality
    ) values (
      new_protocol, s.id, categoria_val, tipologia_val,
      'Dados de teste (seed)', 'Colaborador',
      current_date - (floor(random() * 30))::int, '12:00',
      '[DADOS DE TESTE] Ocorrência extrema gerada para validação do painel de riscos.', report,
      jsonb_build_object('houve_obito', 'Sim'), 'extrema'
    );
  end loop;

  raise notice 'Ocorrências extremas novas criadas: %', counter - 1;
end $$;
