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
-- ═══════════════════════════════════════════════════════════════════════

-- Los recaudos de la redacción. La cédula catastral ya la creó
-- supabase-conformidad-uso.sql; se repite por si este va antes.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('propiedad_inmueble',    'Documento de propiedad del inmueble, registrado', false),
  ('identidad_propietario', 'Cédula o RIF del propietario del inmueble',       false),
  ('solvencia_inmuebles',   'Solvencia municipal de inmuebles urbanos',        true)
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
--   select codigo from public.tipos_documento
--    where codigo in ('propiedad_inmueble', 'identidad_propietario',
--                     'solvencia_inmuebles', 'cedula_catastral');           -- cuatro filas
