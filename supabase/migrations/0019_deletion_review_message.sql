-- Mensagem que o staff escreve ao aprovar/rejeitar uma solicitação de
-- exclusão, destinada a quem pediu (ainda sem envio de e-mail automático —
-- só o registro por enquanto).
alter table occurrence_deletion_requests add column review_message text;
