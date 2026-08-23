-- Novo nível de criticidade, acima de "alta": óbito e/ou loja
-- fechada/interditada por causa da ocorrência passam a virar "extrema" em
-- vez de "alta" (computeCriticalityFromAnswers no app decide isso).
alter type criticality_level add value 'extrema';
