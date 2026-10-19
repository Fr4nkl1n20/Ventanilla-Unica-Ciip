-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS PERMISOS AMBIENTALES (c30)
--  Va DESPUÉS de supabase-rtn.sql: redefine su confirma_paso() con una
--  llave más. Usa `nivel` (supabase-informe-victor.sql) y `plazo_legal_*`
--  (supabase-plazos.sql).
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 19-10-2026: «tengo que crear una nueva ficha que se
--  llama permisos ambientales», con el documento Permisos_MINEC (Valeria
--  Ramos, CIIP, 14-10-2026), y «solo debe trabajar con el recuadro de
--  Sistemas en línea del MINEC». A la pregunta de qué hacer con la c30
--  genérica: reemplazarla. A la de cómo: el inversionista elige el sistema
--  en línea y el paso 1 le lleva a él, como el SACS (c48). A la de para
--  quién: a todos.
--
--  LO QUE SE LEYÓ
--  ─────────────────────────────────────────────────────────────────────
--  · El cuadro «Sistemas en línea del MINEC y trámites que se presentan en
--    cada uno» del documento: Ventanilla Verde, SIGETRAT, SIFORTRAT, RACDA,
--    SIALAMB y RENMA, con lo que se tramita en cada uno. Los «sin sistema
--    indicado» no entran.
--  · www.minec.gob.ve (19-10-2026): los seis enlaces del cuadro siguen ahí.
--
--  POR QUÉ 'esencial' Y NO 'actividad'
--  Hasta hoy era 'actividad' (supabase-informe-victor.sql): sólo a quien
--  construye. Franklin Reyes pidió que se le muestre a todos, y 'esencial'
--  es el de por defecto.
--
--  SIN PLAZO Y SIN `emite`
--  Cada uno de los más de cien trámites del MINEC tiene su plazo, y los
--  180 días de supabase-plazos.sql eran un estimado del permiso genérico.
--  El gestor lo resuelve con la resolución, como el SACS.
--
--  LO QUE ESTÁ POR CONFIRMAR CON EL CIIP
--  ─────────────────────────────────────────────────────────────────────
--  1. Si hacen falta recaudos revisados por el CIIP antes de ir al
--     sistema, como en el SACS y el RTN. Hoy no pide ninguno.
--  2. Los trámites «sin sistema indicado» (27, más el 221 presencial).
--
--  Si alguien corre supabase-tramites.sql SOLO, después de este, el c30
--  vuelve a llamarse «Permiso ambiental». TODO-EN-ORDEN.sql lo corre detrás.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL TRÁMITE
-- ───────────────────────────────────────────────────────────────────────
update public.tipos_tramite
   set nombre            = 'Permisos ambientales',
       emite             = null,
       plazo_dias        = null,
       plazo_legal_dias  = null,
       plazo_legal_norma = null,
       nivel             = 'esencial',
       fase              = 3,
       activo            = true
 where codigo = 'permiso_ambiental';


-- ───────────────────────────────────────────────────────────────────────
-- 2. LA MARCA DEL PASO 1: «Ya lo solicité» en el sistema del MINEC
-- ───────────────────────────────────────────────────────────────────────
--  'ambiental_solicitado'. Es la confirma_paso de supabase-rtn.sql con esa
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
                     'sacs_registrado', 'rtn_solicitado', 'ambiental_solicitado') then
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
-- 1) Una fila: c30 · Permisos ambientales · MINEC · fase 3 · esencial ·
--    sin emite ni plazo · encendido.
--
--   select ref_panel, codigo, nombre, ente, fase, nivel, emite, plazo_dias,
--          plazo_legal_dias, activo
--   from public.tipos_tramite where ref_panel = 'c30';
