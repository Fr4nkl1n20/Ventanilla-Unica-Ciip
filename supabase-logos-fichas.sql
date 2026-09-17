-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL LOGO DE CADA FICHA, DESDE EL PANEL
--  Va DESPUÉS de supabase-catalogos.sql (el admin ya puede escribir en
--  tipos_tramite) y de supabase-bitacora.sql (apunta()). Va al final para
--  no mover el número de nadie.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 17 de septiembre de 2026: que el administrador pueda
--  cambiar o poner el logo de las fichas del catálogo sin tocar el código.
--  Hasta hoy el icono iba escrito a mano en el HTML de cada tarjeta.
--
--  CÓMO QUEDA
--  ───────────────────────────────────────────────────────────────────────
--  · tipos_tramite.logo guarda la RUTA dentro del cubo 'logos-fichas'.
--    null = la ficha enseña el icono de siempre, el del código. Así quitar
--    un logo subido es volver atrás, no quedarse sin nada.
--  · El cubo es PÚBLICO de lectura: un logo no es un dato de nadie, lo ve
--    cualquiera que abra la portada, y una URL pública se cachea. Escribir
--    y borrar, solo el admin.
--  · Sin SVG, por lo mismo que en 'recaudos': un SVG puede llevar script.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: las fichas siguen con sus iconos
--  de siempre y la pantalla del catálogo no enseña el mando del logo.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA COLUMNA
-- ───────────────────────────────────────────────────────────────────────
alter table public.tipos_tramite
  add column if not exists logo text;

comment on column public.tipos_tramite.logo is
  'Ruta del logo subido por el admin en el cubo logos-fichas. null = el icono de siempre';


-- ───────────────────────────────────────────────────────────────────────
-- 2. EL CUBO
-- ───────────────────────────────────────────────────────────────────────
-- 1 MB sobra para un logo de 48 px de ancho, y deja fuera la foto de 8 MB
-- que alguien sube sin mirar.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('logos-fichas', 'logos-fichas', true, 1048576,
        array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update set
  public             = excluded.public,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- La lectura de un cubo público por su URL no pasa por estas políticas;
-- esta hace falta para que el admin pueda BORRAR, que Storage consulta la
-- fila antes de quitarla.
drop policy if exists "logos-fichas: se leen" on storage.objects;
create policy "logos-fichas: se leen" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'logos-fichas');

drop policy if exists "logos-fichas: el admin sube" on storage.objects;
create policy "logos-fichas: el admin sube" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'logos-fichas' and public.es_admin());

drop policy if exists "logos-fichas: el admin reemplaza" on storage.objects;
create policy "logos-fichas: el admin reemplaza" on storage.objects
  for update to authenticated
  using      (bucket_id = 'logos-fichas' and public.es_admin())
  with check (bucket_id = 'logos-fichas' and public.es_admin());

drop policy if exists "logos-fichas: el admin borra" on storage.objects;
create policy "logos-fichas: el admin borra" on storage.objects
  for delete to authenticated
  using (bucket_id = 'logos-fichas' and public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA BITÁCORA
-- ───────────────────────────────────────────────────────────────────────
-- Solo cuando CAMBIA. 'detalle' vacío es volver al icono de siempre.
create or replace function public.bit_catalogo_logo()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.logo is distinct from old.logo then
    perform public.apunta('catalogo', 'logo', new.nombre, coalesce(new.logo, ''));
  end if;
  return null;
end $$;

revoke execute on function public.bit_catalogo_logo() from public, anon, authenticated;

drop trigger if exists bitacora_catalogo_logo on public.tipos_tramite;
create trigger bitacora_catalogo_logo
  after update of logo on public.tipos_tramite
  for each row execute function public.bit_catalogo_logo();
