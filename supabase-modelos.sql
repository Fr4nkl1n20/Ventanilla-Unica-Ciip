-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS MODELOS DE «AUTORIZACIONES Y NDA»
--  Va DESPUÉS de supabase-admin.sql (es_admin()). Va al final para no
--  mover el número de nadie.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 8 de octubre de 2026: una categoría «Autorizaciones y
--  NDA» donde el inversionista descarga los modelos del CIIP, y donde el
--  administrador los sube sin tocar el código.
--
--  CÓMO QUEDA
--  ───────────────────────────────────────────────────────────────────────
--  · Un cubo 'modelos' con dos archivos de nombre fijo:
--      nda-ciip.pdf            el NDA con el CIIP
--      autorizacion-ciip.pdf   la autorización al CIIP
--    Subir otro es reemplazar el que había: no hay historial que guardar,
--    el modelo vigente es uno.
--  · PRIVADO: lo lee quien tiene sesión, y el panel lo baja con una URL
--    firmada. No es un secreto, pero tampoco es para cualquiera que pase.
--  · Escribir, reemplazar y borrar, solo el admin.
--  · Solo PDF, hasta 10 MB: lo que se descarga tiene que abrirse igual en
--    cualquier equipo.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: el inversionista ve «El CIIP
--  todavía no ha publicado este modelo» y al administrador la subida le
--  dice que no se pudo.
-- ═══════════════════════════════════════════════════════════════════════


insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('modelos', 'modelos', false, 10485760, array['application/pdf'])
on conflict (id) do update set
  public             = excluded.public,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "modelos: se leen con sesion" on storage.objects;
create policy "modelos: se leen con sesion" on storage.objects
  for select to authenticated
  using (bucket_id = 'modelos');

drop policy if exists "modelos: el admin sube" on storage.objects;
create policy "modelos: el admin sube" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'modelos' and public.es_admin());

drop policy if exists "modelos: el admin reemplaza" on storage.objects;
create policy "modelos: el admin reemplaza" on storage.objects
  for update to authenticated
  using      (bucket_id = 'modelos' and public.es_admin())
  with check (bucket_id = 'modelos' and public.es_admin());

drop policy if exists "modelos: el admin borra" on storage.objects;
create policy "modelos: el admin borra" on storage.objects
  for delete to authenticated
  using (bucket_id = 'modelos' and public.es_admin());
