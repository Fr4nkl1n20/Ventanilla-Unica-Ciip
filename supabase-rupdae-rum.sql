-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL RUPDAE (c35) Y EL REGISTRO ÚNICO MINERO (c36)
--  Va DESPUÉS de supabase-informe-victor.sql: usa las columnas `nivel`
--  (de aquel) y `emite` (de supabase-encadenado.sql).
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Del encargo del 15 de septiembre de 2026: incorporar a «Habilitación
--  operativa y cumplimiento» (la fase 3) el RUPDAE ante la SUNDDE y el
--  Registro Único Minero. Ninguno de los dos estaba.
--
--  EL RUPDAE (c35)
--  ─────────────────────────────────────────────────────────────────────
--  · Ley Orgánica de Precios Justos, Decreto 2.092, G.O. 6.202 Ext. del
--    8-11-2015, artículos 18 a 20: toda persona que fabrica, importa,
--    distribuye, comercializa o presta servicios se inscribe, y la
--    inscripción es «requisito indispensable» para operar. El artículo 46.4
--    sanciona no inscribirse con multa de 500 a 10.000 UT o cierre de 48 h.
--  · Se hace en línea, en rupdae.sundde.gob.ve. La SUNDDE da de cinco a
--    diez días hábiles para revisarlo: plazo_dias = 14.
--  · El certificado NO caduca desde el 2 de septiembre de 2026 (Ley de
--    Celeridad de Trámites, G.O. 7.018): sólo se actualiza si cambian la
--    razón social, la directiva o el domicilio fiscal. Por eso vence = false.
--    OJO: eso sale de prensa regional; falta verlo en la web de la SUNDDE.
--
--  POR QUÉ 'esencial' Y NO 'obligatorio'
--  La ley se lo pide a todas las empresas, así que por fondo sería
--  obligatorio. Pero los obligatorios son los diez del informe del 2 de
--  septiembre -cinco y cinco- y el número lo decidió el CIIP. 'esencial' es
--  el caso corriente: le toca a todos, no lleva distintivo y no se aparta.
--  Si el CIIP lo quiere obligatorio es cambiar esta palabra, y la prueba de
--  los diez obligatorios avisará.
--
--  EL REGISTRO ÚNICO MINERO (c36)
--  ─────────────────────────────────────────────────────────────────────
--  · Resolución 0010 del Ministerio de Desarrollo Minero Ecológico, G.O.
--    41.396 del 14-05-2018 (deroga la 0009 de marzo). Obligatorio para
--    quien ejerza o pretenda ejercer actividades primarias, conexas o
--    auxiliares a la minería, y requisito para cualquier trámite ante el
--    ministerio: autorizaciones, alianzas, empresas mixtas, contratos.
--  · Se hace en el SIGDME 2.0 (sigdme2-0.desarrollominero.gob.ve). Los
--    recaudos salen de su formulario de alta para «empresa conformada»:
--    cédula, RIF y acta constitutiva, y el acta de asamblea como opcional.
--  · El certificado electrónico dura TRES años (artículo 3): vence = true.
--  · 'actividad': sólo le toca al sector minero.
--  · Sin plazo: la resolución no da ninguno y aquí no se inventa.
--
--  LO QUE ESTÁ POR CONFIRMAR CON EL CIIP, Y POR ESO ESTÁ DICHO AQUÍ
--  ─────────────────────────────────────────────────────────────────────
--  1. El nivel del RUPDAE: 'esencial' u 'obligatorio' (ver arriba).
--  2. Si la patente municipal (c10) es recaudo del RUPDAE: la lista de la
--     SUNDDE de 2022 la pedía y el formulario de registro de hoy no.
--  3. El RUM para una empresa TODAVÍA NO CONSTITUIDA. El SIGDME la acepta
--     con el proyecto del acta y una carta explicativa, y ofrece una
--     «autorización del SAREN»: parece que para minería el ministerio va
--     antes del Registro Mercantil, como la ZODI. Aquí sólo está el caso de
--     la empresa ya constituida, que es el de la fase 3.
--  4. Qué pide el SIGDME DENTRO, después de crear la cuenta: sólo se ha
--     visto el formulario de alta.
--
--  Si alguien corre supabase-tramites.sql SOLO, después de este, el c35 y
--  el c36 se apagan: aquel deja encendidos exactamente los de su lista. Es
--  lo mismo que le pasa al c32, al c33 y al c34. TODO-EN-ORDEN.sql lo corre
--  detrás y los vuelve a encender.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LOS PAPELES NUEVOS
-- ───────────────────────────────────────────────────────────────────────
--  Sólo lo que sale de cada trámite: lo que piden -acta, RIF, cédula- ya
--  estaba en la bóveda.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('certificado_rupdae', 'Certificado de inscripción en el RUPDAE',          false),
  ('certificado_rum',    'Certificado electrónico del Registro Único Minero', true)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LOS TRÁMITES
-- ───────────────────────────────────────────────────────────────────────
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('rupdae',          'c35', 'Inscripción en el RUPDAE',     'SUNDDE',                           3, true),
  ('registro_minero', 'c36', 'Registro Único Minero (RUM)',  'Ministerio de Desarrollo Minero',  3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite      = 'certificado_rupdae',
       plazo_dias = 14,
       nivel      = 'esencial',
       activo     = true
 where codigo = 'rupdae';

update public.tipos_tramite
   set emite      = 'certificado_rum',
       plazo_dias = null,
       nivel      = 'actividad',
       activo     = true
 where codigo = 'registro_minero';


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Dos filas: c35 · SUNDDE · fase 3 · esencial · 14 días, y c36 ·
--    ministerio · fase 3 · actividad · sin plazo. Las dos encendidas.
--
--   select ref_panel, codigo, nombre, ente, fase, nivel, emite, plazo_dias, activo
--   from public.tipos_tramite where ref_panel in ('c35','c36');
--
-- 2) Los dos papeles nuevos, y sólo el del RUM caduca:
--
--   select codigo, nombre, vence from public.tipos_documento
--   where codigo in ('certificado_rupdae','certificado_rum');
--
-- 3) Los obligatorios siguen siendo DIEZ, cinco y cinco: ninguno suma.
--
--   select fase, count(*) from public.tipos_tramite
--   where nivel = 'obligatorio' group by fase;
