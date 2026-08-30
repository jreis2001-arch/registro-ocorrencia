-- Duas correções de uma auditoria de segurança:
--
-- 1) staff_roles_insert_administrador (0027) deixava QUALQUER staff (até um
--    papel restrito como 'midia') conceder acesso de administrador pra
--    qualquer pessoa. Agora só o dono ou um administrador já existente
--    pode conceder — fecha uma escalada de privilégio indevida.
--
-- 2) deletion_requests_insert (0018) não conferia se a ocorrência
--    informada realmente pertence à loja que está pedindo a exclusão — uma
--    loja podia citar o protocolo/occurrence_id de OUTRA loja num pedido.
--    Agora exige que a ocorrência exista e seja da própria loja.

create function is_administrador() returns boolean as $$
  select exists (select 1 from staff_roles where user_id = auth.uid() and role = 'administrador');
$$ language sql stable security definer;

alter function is_administrador() set search_path = public;

drop policy staff_roles_insert_administrador on staff_roles;

create policy staff_roles_insert_administrador on staff_roles for insert
  with check (role = 'administrador' and (is_owner() or is_administrador()));

create or replace function grant_administrator(p_email text) returns void as $$
declare
  target_id uuid;
begin
  if not (is_owner() or is_administrador()) then
    raise exception 'Apenas o dono ou um administrador pode conceder esse acesso.';
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

drop policy deletion_requests_insert on occurrence_deletion_requests;

create policy deletion_requests_insert on occurrence_deletion_requests for insert
  with check (
    is_staff()
    or (
      store_id = auth_store_id()
      and exists (select 1 from occurrences o where o.id = occurrence_id and o.store_id = auth_store_id())
    )
  );
