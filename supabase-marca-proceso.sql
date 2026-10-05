-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA MARCA EN PROCESO DE REGISTRO (c43)
--  Necesita el catálogo con `nivel` y `emite` (supabase-informe-victor.sql
--  y supabase-encadenado.sql). Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  Franklin Reyes, 5 de octubre de 2026 («Ventanilla única 2.5»): el
--  registro de marca se divide en dos opciones previas.
--
--    «¿Quieres registrar tu marca por primera vez?» es el registro de
--    siempre (marca, c8), y no cambia nada.
--
--    «¿Tienes una marca en proceso de registro?» es un trámite nuevo,
--    marca_en_proceso (c43): cuatro datos -el nombre de la marca, la fecha
--    de la solicitud, a nombre de quién se registra y, si la hubo, la
--    oposición, el recurso o la devolución del SAPI-, dos recaudos -la
--    planilla de solicitud y la cédula y el RIF de quien registra la
--    marca- y su escalera: revisión de estatus, solicitud de información
--    al SAPI y marca concedida. Va con los cuatro estados de siempre; no
--    usa nada de supabase-marca.sql, que es solo del registro nuevo.
--
--  Como las dos visas y «Bienes»: la casilla de la portada es la c8 y la
--  c43 va escondida con data-tramo-de, cada una con sus campos, sus
--  recaudos y su solicitud viva (tramites_una_viva). Nivel 'esencial', el
--  de la marca: la casilla es la misma, solo cambia en qué punto llega.
-- ═══════════════════════════════════════════════════════════════════════

insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_solicitud_marca', 'Planilla de solicitud de registro de marca',  false),
  ('identidad_titular_marca',  'Cédula y RIF de quien registra la marca',     false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('marca_en_proceso', 'c43', 'Registro de marca: marca en proceso de registro', 'SAPI', 2, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite      = null,
       plazo_dias = null,
       nivel      = 'esencial',
       activo     = true
 where codigo = 'marca_en_proceso';

-- COMPROBACIÓN
--   select codigo, ref_panel, fase, nivel, activo from public.tipos_tramite
--    where codigo in ('marca', 'marca_en_proceso');                        -- dos filas
--   select codigo from public.tipos_documento
--    where codigo in ('planilla_solicitud_marca', 'identidad_titular_marca'); -- dos filas
