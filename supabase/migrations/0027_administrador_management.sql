-- Gerenciamento de administradores dentro do app. Hoje staff_roles não tem
-- NENHUMA policy de insert/delete (só cadastrado via SQL Editor) — as
-- regras abaixo abrem só o suficiente pra gerenciar o papel 'administrador'
-- especificamente, sem virar uma brecha geral de auto-promoção pra
-- qualquer papel.
--
-- Proteção do dono: só jreis2001@gmail.com pode remover outro
-- administrador, e a própria linha dele nunca é removível pelo app (nem
-- por ele mesmo) — evita autoexclusão acidental.

create function is_owner() returns boolean as $$
  select exists (select 1 from auth.users where id = auth.uid() and lower(email) = lower('jreis2001@gmail.com'));
$$ language sql stable security definer;

alter function is_owner() set search_path = public;

-- Usado dentro da policy de delete abaixo: uma subconsulta em auth.users
-- escrita direto numa policy roda com a permissão de quem está chamando
-- (authenticated), que não tem select em auth.users — por isso precisa
-- ser uma função security definer própria, igual is_owner().
create function owner_user_id() returns uuid as $$
  select id from auth.users where lower(email) = lower('jreis2001@gmail.com');
$$ language sql stable security definer;

alter function owner_user_id() set search_path = public;

-- Qualquer staff pode adicionar um administrador, mas só esse papel
-- especificamente — não dá pra usar isso pra se autoconceder outro papel.
create policy staff_roles_insert_administrador on staff_roles for insert
  with check (is_staff() and role = 'administrador');

-- Só o dono remove administradores, e nunca a própria linha dele. Como não
-- existe NENHUMA outra policy de delete em staff_roles, todo o resto
-- (papéis de CCO/investigação/etc., inclusive a linha original do dono)
-- já fica protegido contra remoção pelo app só por omissão.
create policy staff_roles_delete_owner_only on staff_roles for delete
  using (
    is_owner()
    and role = 'administrador'
    and user_id <> owner_user_id()
  );

-- Resolve e-mail -> user_id por dentro (o cliente não consegue consultar
-- auth.users diretamente) e cria a linha de administrador.
create function grant_administrator(p_email text) returns void as $$
declare
  target_id uuid;
begin
  if not is_staff() then
    raise exception 'Apenas staff pode conceder acesso de administrador.';
  end if;

  select id into target_id from auth.users where lower(email) = lower(p_email);
  if target_id is null then
    raise exception 'Nenhum usuário encontrado com esse e-mail.';
  end if;

  insert into staff_roles (user_id, role) values (target_id, 'administrador')
  on conflict (user_id, role) do nothing;
end;
$$ language plpgsql security definer;

alter function grant_administrator(text) set search_path = public;

grant execute on function grant_administrator(text) to authenticated;

-- Lista de administradores pra tela — visão própria de e-mail (staff não
-- consegue ler auth.users direto); retorna vazio pra quem não é staff.
create view administrators_directory as
  select sr.user_id, u.email, sr.created_at
  from staff_roles sr
  join auth.users u on u.id = sr.user_id
  where sr.role = 'administrador' and is_staff();

grant select on administrators_directory to authenticated;
