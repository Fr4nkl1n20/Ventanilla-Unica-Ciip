-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — BIENES: COMPRAVENTA O ALQUILER DE UN INMUEBLE
--  (c41 y c42)
--  Necesita el catálogo con `nivel` y `emite` (supabase-informe-victor.sql
--  y supabase-encadenado.sql). Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  Franklin Reyes, 2 de octubre de 2026: un servicio nuevo del CIIP en la
--  estructura corporativa (fase 2). El inversionista elige la operación
--  -compraventa o alquiler- y después el servicio:
--
--    Redacción de contrato y acompañamiento: llena los datos y consigna los
--    recaudos, como en cualquier solicitud, y el CIIP redacta el contrato.
--    Es un trámite, con su escalera: recibida, revisión de recaudos,
--    redacción del contrato y contrato listo (el contrato lo sube el equipo
--    al resolver, y queda en la bóveda como cualquier documento emitido).
--
--    Asesoría legal: una consulta en el chat con el tema que escribe. No es
--    un trámite: es una fila de `consultas` con el código del trámite en
--    `tipo` -por eso tiene que existir aquí, por la llave foránea- y la
--    operación delante del tema en `asunto`. No necesita nada más.
--
--  Las dos operaciones son DOS tipos, como las dos visas (c1 y c38): cada
--  una con sus campos, sus recaudos y su solicitud viva (tramites_una_viva),
--  y la del alquiler escondida de la cuadrícula del panel.
--
--  Nivel 'actividad': hace falta según lo que haga la empresa -quien opera
--  desde casa o en un local que ya tiene no lo necesita-, y lo de
--  'actividad' no se aparta nunca de su fase. No emite ningún tipo del
--  catálogo: el contrato entra como 'resolucion', y no hay trámite que lo
--  pida como recaudo, así que no hay cadena que encender.
--
--  LOS RECAUDOS DE LA COMPRAVENTA, CON LAS DOS PARTES (Franklin Reyes,
--  2-10-2026, el mismo día): el documento de propiedad, la Forma 33, la
--  cédula de identidad y el RIF del vendedor y los del comprador, la cédula
--  catastral y la solvencia municipal de inmuebles urbanos. El contrato
--  lleva al que vende y al que compra, y «el propietario» era solo uno de
--  los dos: identidad_propietario se queda para el alquiler, que no cambia.
--
--  Y el vendedor puede ser una empresa. Lo pregunta la primera casilla del
--  formulario, «¿El vendedor es una persona jurídica?»: con «Sí», en lugar
--  de su cédula -una empresa no tiene- se piden el acta constitutiva y su
--  última actualización, la cédula y el RIF del representante legal, el
--  acta de asamblea que lo nombra y el RIF de la empresa. Qué se pide y
--  cuándo lo decide el panel (RECAUDOS.bienes_compraventa, en panel.js);
--  aquí solo nacen los siete tipos nuevos.
--
--  Si ya se corrió la versión anterior de este archivo, HAY QUE VOLVER A
--  CORRERLO: documentos.tipo apunta a tipos_documento, y sin los siete
--  tipos la base rechaza esos papeles al subirlos y la compraventa no se
--  puede enviar.
-- ═══════════════════════════════════════════════════════════════════════

-- Los recaudos de la redacción: los del alquiler, los de la compraventa y
-- los cuatro de la empresa vendedora. La cédula catastral ya la creó
-- supabase-conformidad-uso.sql; se repite abajo por si este va antes.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('propiedad_inmueble',     'Documento de propiedad del inmueble, registrado',                  false),
  ('identidad_propietario',  'Cédula o RIF del propietario del inmueble',                        false),
  ('solvencia_inmuebles',    'Solvencia municipal de inmuebles urbanos',                         true),
  ('forma_33',               'Forma 33',                                                         false),
  ('identidad_vendedor',     'Cédula de identidad y RIF del vendedor',                           false),
  ('identidad_comprador',    'Cédula de identidad y RIF del comprador',                          false),
  ('acta_vendedor',          'Acta constitutiva y última actualización de la empresa vendedora', false),
  ('identidad_rep_vendedor', 'Cédula y RIF del representante legal de la empresa vendedora',     false),
  ('asamblea_rep_vendedor',  'Acta de asamblea con el nombramiento del representante legal',     false),
  ('rif_vendedor',           'RIF de la empresa vendedora',                                      false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

insert into public.tipos_documento (codigo, nombre, vence) values
  ('cedula_catastral',      'Cédula catastral del inmueble',                   false)
on conflict (codigo) do nothing;

-- Los dos trámites, con el CIIP de ente: el servicio lo da el propio CIIP.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('bienes_compraventa', 'c41', 'Bienes: compraventa de un inmueble', 'CIIP', 2, true),
  ('bienes_alquiler',    'c42', 'Bienes: alquiler de un inmueble',    'CIIP', 2, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite      = null,
       plazo_dias = null,
       nivel      = 'actividad',
       activo     = true
 where codigo in ('bienes_compraventa', 'bienes_alquiler');

-- COMPROBACIÓN
--   select codigo, ref_panel, fase, nivel, activo from public.tipos_tramite
--    where codigo like 'bienes\_%';                                        -- dos filas
--   select codigo, vence from public.tipos_documento
--    where codigo in ('propiedad_inmueble', 'identidad_propietario',
--                     'solvencia_inmuebles', 'cedula_catastral',
--                     'forma_33', 'identidad_vendedor', 'identidad_comprador',
--                     'acta_vendedor', 'identidad_rep_vendedor',
--                     'asamblea_rep_vendedor', 'rif_vendedor');             -- once filas
--   Solo solvencia_inmuebles con vence = true.
