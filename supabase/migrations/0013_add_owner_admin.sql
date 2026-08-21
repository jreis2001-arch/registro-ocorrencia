-- Concede papel de staff (admin/CCO) para jreis2001@gmail.com, dono do
-- sistema — mesmo mecanismo já usado para cco@teste (staff_roles é a
-- única fonte de verdade de quem é staff; is_staff() só checa se existe
-- uma linha aqui, sem hierarquia entre os valores do enum).
insert into staff_roles (user_id, role)
select id, 'cco_central'
from auth.users
where email = 'jreis2001@gmail.com'
on conflict (user_id, role) do nothing;
