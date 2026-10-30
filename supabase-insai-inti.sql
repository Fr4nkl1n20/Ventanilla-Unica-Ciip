-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL INSAI (c51) Y EL INTI (c52)
--  Va DESPUÉS de supabase-permisos-ambientales.sql: redefine su
--  confirma_paso() con dos llaves más. Usa `nivel` (supabase-informe-
--  victor.sql). Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  Franklin Reyes, 30-10-2026: el equipo mandó «para Claude» lo que se hace
--  en los sistemas del INSAI (SIGESAI, RUNSAI y la plataforma de
--  certificados) y en el INTI, y pidió dos fichas del catálogo en
--  «Registros sectoriales», como la del SACS:
--  · c51 (insai): el inversionista elige el sistema y lo que va a pedir,
--    se registra allí y lo avisa con «Ya lo solicité» (insai_solicitado).
--  · c52 (inti): elige la solicitud, la entrega en persona en la Oficina
--    Regional de Tierras y lo avisa con «Ya la solicité» (inti_solicitado).
--  Sin plazo publicado. Lo que entrega cada uno se guarda como documento.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Lo que entrega cada ente. No se sabe si vence: no vence.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('documento_insai', 'Registro, permiso o certificado del INSAI', false),
  ('documento_inti',  'Documento del INTI (adjudicación, certificación o carta agraria)', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- 2. Los dos trámites, en la fase 3 con los demás registros sectoriales.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('insai', 'c51', 'Registros y permisos del INSAI', 'INSAI', 3, true),
  ('inti',  'c52', 'Solicitudes ante el INTI',       'INTI',  3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite  = 'documento_insai',
       nivel  = 'actividad',
       fase   = 3,
       activo = true
 where codigo = 'insai';

update public.tipos_tramite
   set emite  = 'documento_inti',
       nivel  = 'actividad',
       fase   = 3,
       activo = true
 where codigo = 'inti';

-- 3. Las marcas del paso 1: la de supabase-permisos-ambientales.sql con
-- 'insai_solicitado' e 'inti_solicitado'.
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
                     'insai_solicitado', 'inti_solicitado') then
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
