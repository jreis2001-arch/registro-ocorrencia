-- Staff (CCO) agora também registra ocorrências, em nome de qualquer loja
-- (não só a "sua", já que staff não tem loja própria). As políticas de
-- INSERT antigas só permitiam "store_id = a própria loja de quem está
-- logado" — precisam aceitar também "quem está logado é staff".

alter policy occurrences_insert on occurrences
  with check (store_id = auth_store_id() or is_staff());

alter policy occurrence_themes_insert on occurrence_themes
  with check (exists (
    select 1 from occurrences o where o.id = occurrence_id
    and (o.store_id = auth_store_id() or is_staff())
  ));

alter policy occurrence_evidence_insert on occurrence_evidence
  with check (exists (
    select 1 from occurrences o where o.id = occurrence_id
    and (o.store_id = auth_store_id() or is_staff())
  ));

-- Same fix for the Storage bucket policy from 0002 — staff uploading
-- evidence for an occurrence filed on behalf of a store.
alter policy evidencias_insert on storage.objects
  with check (
    bucket_id = 'evidencias'
    and exists (
      select 1 from occurrences o
      where o.id::text = (storage.foldername(name))[1]
      and (o.store_id = auth_store_id() or is_staff())
    )
  );
