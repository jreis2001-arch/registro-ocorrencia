-- Bucket privado para evidências (fotos/vídeos), com a mesma regra de acesso
-- das ocorrências: a loja só acessa o que é dela, staff acessa tudo.
-- O caminho de cada arquivo é sempre "<occurrence_id>/<nome>", então usamos
-- o primeiro segmento do caminho para achar a ocorrência dona do arquivo.

insert into storage.buckets (id, name, public)
values ('evidencias', 'evidencias', false)
on conflict (id) do nothing;

create policy evidencias_insert on storage.objects for insert
  with check (
    bucket_id = 'evidencias'
    and exists (
      select 1 from occurrences o
      where o.id::text = (storage.foldername(name))[1]
      and o.store_id = auth_store_id()
    )
  );

create policy evidencias_select on storage.objects for select
  using (
    bucket_id = 'evidencias'
    and exists (
      select 1 from occurrences o
      where o.id::text = (storage.foldername(name))[1]
      and (o.store_id = auth_store_id() or is_staff())
    )
  );
