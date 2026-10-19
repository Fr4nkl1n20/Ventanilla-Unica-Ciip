-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL PERMISO DEL MINEC LO SUBE EL INVERSIONISTA
--  Va DESPUÉS de supabase-permisos-ambientales.sql. Solo necesita
--  tipos_documento, tramites, documentos y tramite_documentos. Se puede
--  correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 19-10-2026, en los permisos ambientales (c30): «el
--  gestor estaría pendiente del trámite pero él no puede cerrar el caso,
--  porque no le llegará el documento a él, o sea tiene que estar informado
--  en el proceso, y el paso lo cierra cuando el inversionista suba el
--  permiso solicitado», y «el CIIP confirma el permiso y finaliza el
--  trámite».
--
--  Los pasos pasan a ser tres: «Solicita tu permiso en el sistema en línea
--  del MINEC» (la marca 'ambiental_solicitado'), «Sube el permiso que te
--  otorgó el MINEC» (este papel) y «Permiso confirmado por el CIIP», que
--  el gestor cierra al resolver sin subir nada.
--
--  LO QUE HACE
--  ─────────────────────────────────────────────────────────────────────
--  1. El tipo de documento 'permiso_ambiental', que no vence: cada permiso
--     del MINEC tiene su vigencia, y la dice el propio permiso.
--  2. La política que deja al inversionista colgarlo de SU solicitud de
--     permisos ambientales, ya enviada y con el paso 1 marcado. Como la de
--     la planilla firmada (supabase-planilla-firmada.sql), en su propia
--     política: las políticas se suman y no se reescribe la de otro. Y una
--     restrictiva que no lo deja colgar de ninguna otra manera.
--  3. El freno: no se resuelve un permiso ambiental sin un permiso del
--     MINEC colgado que no esté rechazado. Como el del sellado de libros
--     (supabase-libros.sql). El panel ya avisa antes de intentarlo; esto es
--     para quien llegue por otro camino.
--
--  El aviso al gestor no necesita nada aquí: la campana del panel ya lee
--  los papeles colgados de las solicitudes que lleva, y basta con que el
--  tipo esté en su lista.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL TIPO DE DOCUMENTO
-- ───────────────────────────────────────────────────────────────────────
insert into public.tipos_documento (codigo, nombre, vence) values
  ('permiso_ambiental', 'Permiso ambiental del MINEC', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. COLGARLO DESDE SU PASO
-- ───────────────────────────────────────────────────────────────────────
--  «adjuntos: adjuntar a lo propio» solo deja colgar papeles en borrador o
--  devuelta, y éste llega con la solicitud en marcha: recibida, en revisión
--  o ya presentada ante el MINEC, que es lo normal, porque el permiso lo
--  otorga el MINEC cuando quiere. Devuelta no, que es volver al principio.
--  Y solo con «Ya lo solicité» marcado: sin solicitud en el sistema del
--  MINEC no hay permiso que subir, y el paso 2 todavía no está en curso.
drop policy if exists "adjuntos: el permiso del MINEC, desde su paso" on public.tramite_documentos;
create policy "adjuntos: el permiso del MINEC, desde su paso" on public.tramite_documentos
  for insert
  with check (
    exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and t.inversionista = auth.uid()
         and d.inversionista = auth.uid()
         and d.tipo = 'permiso_ambiental'
         and t.tipo = 'permiso_ambiental'
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
         and coalesce(t.datos, '{}'::jsonb) ? 'ambiental_solicitado'
    )
  );

--  Y SOLO ASÍ. La de arriba suma; ésta resta. «adjuntos: adjuntar a lo
--  propio» deja colgar cualquier papel propio de una solicitud en borrador
--  o devuelta, y con ella el permiso entraba en un borrador, o en la
--  solicitud de otro trámite, antes de que el paso 2 estuviera en curso.
--  Restrictiva: un permiso del MINEC solo se cuelga de un permiso
--  ambiental en marcha y con «Ya lo solicité» marcado. A los demás papeles
--  no les toca.
drop policy if exists "adjuntos: el permiso del MINEC, solo desde su paso" on public.tramite_documentos;
create policy "adjuntos: el permiso del MINEC, solo desde su paso" on public.tramite_documentos
  as restrictive
  for insert
  with check (
    not exists (
      select 1
        from public.documentos d
       where d.id = tramite_documentos.documento
         and d.tipo = 'permiso_ambiental'
    )
    or exists (
      select 1
        from public.tramites t
       where t.id = tramite_documentos.tramite
         and t.tipo = 'permiso_ambiental'
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
         and coalesce(t.datos, '{}'::jsonb) ? 'ambiental_solicitado'
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- 3. EL FRENO: NO SE CONFIRMA SIN EL PERMISO
-- ───────────────────────────────────────────────────────────────────────
--  Sin sesión (auth.uid() nulo) pasa, como en el de los libros: es el
--  dueño de la base o una tarea del servidor, no alguien desde el panel.
create or replace function public.tramites_ambiental_con_permiso()
returns trigger
language plpgsql
security definer
set search_path = public
as $ambiental$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'permiso_ambiental' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;
  if not exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
     where td.tramite = new.id
       and d.tipo = 'permiso_ambiental'
       and d.estado <> 'rechazado'
  ) then
    raise exception 'Los permisos ambientales no se confirman sin el permiso del MINEC que sube el inversionista'
      using errcode = 'check_violation';
  end if;
  return new;
end
$ambiental$;

drop trigger if exists tramites_ambiental_permiso on public.tramites;
create trigger tramites_ambiental_permiso
  before update on public.tramites
  for each row execute function public.tramites_ambiental_con_permiso();


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
--   select codigo, nombre, vence from public.tipos_documento
--    where codigo = 'permiso_ambiental';                                   -- una fila
--   select polname from pg_policy
--    where polname in ('adjuntos: el permiso del MINEC, desde su paso',
--                      'adjuntos: el permiso del MINEC, solo desde su paso'); -- dos filas
--   select tgname from pg_trigger where tgname = 'tramites_ambiental_permiso'; -- una fila
