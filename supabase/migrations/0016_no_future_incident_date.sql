-- A data do fato não pode ser no futuro (já bloqueado no app, mas trava
-- aqui também — qualquer inserção que tente burlar o app cai nessa regra).
alter table occurrences add constraint occurrences_incident_date_not_future
  check (incident_date is null or incident_date <= current_date);
