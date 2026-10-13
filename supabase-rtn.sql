-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL REGISTRO TURÍSTICO NACIONAL (c50)
--  Va DESPUÉS de supabase-sacs.sql: redefine su confirma_paso() con una
--  llave más. Usa `nivel` (supabase-informe-victor.sql), `emite`
--  (supabase-encadenado.sql) y `plazo_legal_*` (supabase-plazos.sql).
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 13-10-2026: «https://www.mintur.gob.ve/rtn necesito
--  crear una ficha con este trámite». Y, a la pregunta de cómo: «Portal de
--  MINTUR», igual que el Registro Único Minero (c36). El inversionista se
--  inscribe en el RTN Digital (turismonac.mintur.gob.ve) y lo avisa con su
--  «Ya lo solicité»; el gestor del CIIP lo sigue y lo da por resuelto.
--
--  LO QUE SE LEYÓ
--  ─────────────────────────────────────────────────────────────────────
--  · mintur.gob.ve/rtn (13-10-2026): el RTN es el padrón «único, público,
--    permanente, personal, intransferible y obligatorio» de los prestadores
--    de servicios turísticos. Se hace en el RTN Digital. Revisión: máximo
--    15 días hábiles. Inscripción: 3 UT; actualización: 1 UT, a la cuenta
--    de INATUR en el Banco de Venezuela. Actualizar dentro de 30 días si
--    cambia la denominación, la directiva, los accionistas, el domicilio...
--  · Resolución 007 del MINTUR, 15-2-2016, Gaceta Oficial 40.883 del
--    12-4-2016 (leída en tugacetaoficial.com, no en la Gaceta). Recaudos de
--    la persona jurídica: acta constitutiva y estatutos, RIF vigente,
--    cédulas de todos los accionistas y pólizas de responsabilidad civil e
--    incendio. Credencial provisional de hasta 6 meses; la definitiva dura
--    DOS años y se renueva 30 días antes de vencer: vence = true.
--    Son los recaudos de la ficha (panel.js, RECAUDOS), como en el SACS:
--    el CIIP los revisa antes de que el inversionista los cargue en el RTN
--    Digital (Franklin Reyes, 13-10-2026: «los recaudos»).
--  · La planilla de MINTUR para persona jurídica (solicitud_rtn_juridico.pdf)
--    pide además el tipo de prestador, el registro mercantil, la patente
--    municipal y los empleados.
--
--  POR QUÉ 'actividad'
--  Sólo le toca al que presta servicios turísticos, como el RUM sólo a la
--  minería. Desde el 5-10-2026 'actividad' no lleva distintivo en la
--  tarjeta: lo dice la condición de la ficha.
--
--  EL PLAZO
--  La revisión de 15 días hábiles la dicen la página del MINTUR y la
--  Resolución 007. plazo_dias = 21: quince hábiles en días corridos, como
--  los 14 del RUPDAE para sus diez hábiles.
--
--  LO QUE ESTÁ POR CONFIRMAR CON EL CIIP
--  ─────────────────────────────────────────────────────────────────────
--  1. El artículo exacto de la Resolución 007 que fija los 15 días: no se
--     ha visto en la Gaceta.
--  2. El costo (3 UT) no se modela: lo paga el inversionista en el portal.
--  3. Si va antes o después de la licencia de actividades económicas: la
--     planilla pide el número de patente, así que aquí depende del c10.
--
--  Si alguien corre supabase-tramites.sql SOLO, después de este, el c50 se
--  apaga: aquel deja encendidos exactamente los de su lista. TODO-EN-ORDEN.sql
--  lo corre detrás y lo vuelve a encender.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LOS PAPELES NUEVOS
-- ───────────────────────────────────────────────────────────────────────
--  Lo que sale del trámite, la credencial, y las dos pólizas que pide la
--  Resolución 007. El acta, el RIF y las cédulas de los accionistas ya
--  estaban en la bóveda. Las pólizas caducan: se renuevan cada año.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('certificado_rtn',              'Credencial del Registro Turístico Nacional (RTN)', true),
  ('poliza_responsabilidad_civil', 'Póliza de responsabilidad civil',                  true),
  ('poliza_incendio',              'Póliza de incendio',                               true)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. EL TRÁMITE
-- ───────────────────────────────────────────────────────────────────────
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('registro_turistico', 'c50', 'Registro Turístico Nacional (RTN)', 'MINTUR', 3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite             = 'certificado_rtn',
       plazo_dias        = 21,
       plazo_legal_dias  = 15,
       plazo_legal_norma = 'Resolución 007 del Ministerio del Poder Popular para el Turismo, Gaceta Oficial 40.883 del 12-4-2016',
       nivel             = 'actividad',
       fase              = 3,
       activo            = true
 where codigo = 'registro_turistico';


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA MARCA DEL PASO 1: «Ya lo solicité» en el RTN Digital
-- ───────────────────────────────────────────────────────────────────────
--  'rtn_solicitado'. Es la confirma_paso de supabase-sacs.sql con esa
--  llave más.
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
                     'sacs_registrado', 'rtn_solicitado') then
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


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Una fila: c50 · MINTUR · fase 3 · actividad · emite la credencial ·
--    21 días · 15 por la Resolución 007 · encendido.
--
--   select ref_panel, codigo, nombre, ente, fase, nivel, emite, plazo_dias,
--          plazo_legal_dias, plazo_legal_norma, activo
--   from public.tipos_tramite where ref_panel = 'c50';
--
-- 2) Los tres papeles nuevos, y los tres caducan:
--
--   select codigo, nombre, vence from public.tipos_documento
--   where codigo in ('certificado_rtn','poliza_responsabilidad_civil','poliza_incendio');
--
-- 3) Los obligatorios siguen siendo DIEZ, cinco y cinco: el c50 no suma.
--
--   select fase, count(*) from public.tipos_tramite
--   where nivel = 'obligatorio' group by fase;
