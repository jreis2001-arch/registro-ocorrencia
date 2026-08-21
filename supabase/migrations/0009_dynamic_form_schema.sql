-- Suporte ao formulário real (63 tipologias / 13 categorias, da planilha
-- "Carrefour - Estrutura dos dados"). Substitui o modelo simplificado de
-- "Ocorrência Social/Discriminação" que tínhamos por um esquema flexível:
-- os campos fixos continuam como colunas normais, e as respostas
-- específicas de cada tipologia (que variam muito — de 3 a 37 perguntas
-- por categoria) ficam num campo só, flexível (jsonb).

-- 1) Dados da loja que faltavam (existem no Excel, não foram importados
--    na primeira leva).
alter table stores add column cidade text;
alter table stores add column endereco text;
alter table stores add column regional text;
alter table stores add column diretor text;
alter table stores add column supervisor_riscos text;

-- 2) Novos campos da ocorrência: dados do relator, data/hora do fato,
--    tipologia/categoria reais, e o balde flexível de respostas.
alter table occurrences add column incident_date date;
alter table occurrences add column incident_time time;
alter table occurrences add column reporter_name text;
alter table occurrences add column reporter_email text;
alter table occurrences add column reporter_relationship text;
alter table occurrences add column reporter_role text;
alter table occurrences add column reporter_phone text;
alter table occurrences add column tipologia text;
alter table occurrences add column categoria text;
alter table occurrences add column respostas_dinamicas jsonb not null default '{}'::jsonb;

-- 3) Remove o modelo antigo, específico só de discriminação — a tipologia
--    real "Preconceito ou discriminação" cobre isso, com perguntas
--    diferentes (e mais completas), guardadas em respostas_dinamicas.
alter table occurrences drop column discriminacao;
alter table occurrences drop column vitima;
alter table occurrences drop column conflito;
alter table occurrences drop column integridade;
alter table occurrences drop column impacto;
alter table occurrences drop column motivo;
alter table occurrences drop column category;

drop table occurrence_themes;

drop type discriminacao_opt;
drop type vitima_opt;
drop type conflito_opt;
drop type integridade_opt;
drop type impacto_opt;
drop type motivo_opt;
drop type theme_opt;
drop type occurrence_category;
