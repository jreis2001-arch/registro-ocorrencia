-- Guarda quais passos de orientação o relator marcou como seguidos, no
-- momento em que a ocorrência foi registrada. É um retrato (texto + marcado
-- ou não) — não uma referência a occurrence_guidance — porque os passos
-- podem ser editados/apagados depois pelo CCO, e o histórico da ocorrência
-- não pode mudar retroativamente.
alter table occurrences add column guidance_checked jsonb;
