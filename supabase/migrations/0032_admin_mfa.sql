-- Exige segundo fator (TOTP) confirmado na sessão (aal2) para as duas ações
-- que hoje só um administrador consegue disparar: conceder e remover o
-- próprio papel de administrador. O resto do que um staff já faz (aprovar
-- cadastro, exclusão etc.) continua igual — is_staff() já é "achatado" hoje
-- e isso não muda aqui; é só onde o papel administrador é de fato exclusivo
-- que faz sentido reforçar com 2FA.

drop policy staff_roles_insert_administrador on staff_roles;

create policy staff_roles_insert_administrador on staff_roles for insert
  with check (role = 'administrador' and (is_owner() or is_administrador()) and (auth.jwt() ->> 'aal') = 'aal2');

drop policy staff_roles_delete_owner_only on staff_roles;

create policy staff_roles_delete_owner_only on staff_roles for delete
  using (
    is_owner()
    and role = 'administrador'
    and user_id <> owner_user_id()
    and (auth.jwt() ->> 'aal') = 'aal2'
  );

create or replace function grant_administrator(p_email text) returns void as $$
declare
  target_id uuid;
begin
  if not (is_owner() or is_administrador()) then
    raise exception 'Apenas o dono ou um administrador pode conceder esse acesso.';
  end if;
  if (auth.jwt() ->> 'aal') <> 'aal2' then
    raise exception 'Confirme o código do autenticador antes de conceder acesso de administrador.';
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
