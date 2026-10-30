-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS PERMISOS DE AGRICULTURA (c51)
--  Va DESPUÉS de supabase-permisos-ambientales.sql: redefine su
--  confirma_paso() con una llave más. Usa `nivel` (supabase-informe-
--  victor.sql). Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  Franklin Reyes, 30-10-2026: el equipo mandó «para Claude» lo que se hace
--  en los sistemas del INSAI (SIGESAI, RUNSAI y la plataforma de
--  certificados) y en el INTI. Primero fueron dos fichas (c51 insai y c52
--  inti), y el mismo día: «no es en casillas separadas, INSAI e INTI van
--  dentro de permisos de agricultura». Queda UNA, la c51:
--  · el inversionista elige dónde -un sistema del INSAI o la Oficina
--    Regional de Tierras del INTI- y lo que va a pedir;
--  · lo solicita allí y lo avisa con «Ya lo solicité» (agricola_solicitado).
--  Sin plazo publicado. Lo que entrega el ente se guarda como documento.
--  Si las dos de antes llegaron a la base, se apagan y sueltan la c51 y la
--  c52. No se borran: ref_panel es NOT NULL y UNIQUE, y tramites, citas,
--  consultas y autorizaciones las señalan sin cascada; una solicitud que
--  ya existiera haría fallar el borrado.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Lo que entrega el ente. No se sabe si vence: no vence.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('permiso_agricola', 'Registro, permiso o certificado del INSAI, o documento del INTI', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- 2. Las dos de antes, si están: apagadas y con un ref_panel que ninguna
-- tarjeta usa. Antes que el insert, que si no chocaría con la c51.
update public.tipos_tramite
   set activo    = false,
       ref_panel = 'retirado-' || codigo
 where codigo in ('insai', 'inti');

-- 3. El trámite, en la fase 3 con los demás registros sectoriales.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('permisos_agricolas', 'c51', 'Permisos de agricultura', 'MPPAPT', 3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set ref_panel = 'c51',
       emite     = 'permiso_agricola',
       nivel     = 'actividad',
       fase      = 3,
       activo    = true
 where codigo = 'permisos_agricolas';

-- 4. La marca del paso 1: la de supabase-permisos-ambientales.sql con
-- 'agricola_solicitado'.
create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                     'bomberos_solicitado', 'saime_confirmada', 'locti_inscrito',
                     'sacs_registrado', 'rtn_solicitado', 'ambiental_solicitado',
                     'agricola_solicitado') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;
