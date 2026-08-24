-- A tela de aprovação (staff) precisa mostrar qual usuário está sendo pedido
-- pra inativar — mas staff não consegue ler auth.users direto, e
-- store_peers_directory só é visível pra quem já é da própria loja. Mais
-- simples: guardar o e-mail já resolvido no momento do pedido (mesmo padrão
-- que occurrence_deletion_requests.requested_by já usa: texto solto, não
-- uma FK pra auth.users).
alter table user_deactivation_requests add column target_email text not null;
