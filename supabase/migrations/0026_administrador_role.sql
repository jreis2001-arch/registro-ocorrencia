-- Novo papel de staff: "administrador" (mesmo poder total que qualquer
-- staff já tem hoje via is_staff() — sem hierarquia entre valores do
-- enum). Sozinha nesta migração de propósito: um valor novo de enum não
-- pode ser usado na mesma transação em que foi criado (mesma regra já
-- vista ao criar o nível "extrema" em 0020).
alter type staff_role add value 'administrador';
