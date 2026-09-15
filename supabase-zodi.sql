-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA OPINIÓN FAVORABLE DE LA ZODI (c34)
--  Va DESPUÉS de supabase-informe-victor.sql: usa las columnas `nivel`
--  (de aquel) y `emite` (de supabase-encadenado.sql).
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  De un mensaje de Milagros Torres (Tecnología), del 15 de septiembre de
--  2026: para constituir en Venezuela con accionistas que son empresas
--  extranjeras, la Zona Operativa de Defensa Integral de la región tiene
--  que dar su opinión favorable -o «no objeción»- ANTES del Registro
--  Mercantil, cuando la empresa se instala en zona fronteriza o de
--  seguridad, o su actividad toca la seguridad y la defensa.
--
--  No estaba: ni en tipos_tramite ni en pasos.js. Y pasa lo mismo que con
--  el SISREF (c32): sin él, el panel deja llegar al Registro Mercantil y
--  es allí donde se descubre que falta un papel de otro organismo.
--
--  POR QUÉ 'actividad' Y NO 'obligatorio'
--  ─────────────────────────────────────────────────────────────────────
--  El propio mensaje lo dice condicionado: «especialmente si la empresa
--  operará en zonas fronterizas, áreas estratégicas o sectores
--  regulados». A una tienda en Caracas no le toca. 'actividad' es lo que
--  el catálogo ya usa para «puede que a ti no te toque»: la tarjeta se
--  queda a la vista en la fase 2 -lo de 'actividad' no se aparta nunca- y
--  no se cuenta entre los obligatorios.
--
--  Y por lo mismo el c22 la pide como recaudo OPCIONAL: a quien le toca,
--  la protocolización le recuerda el papel; a quien no, no le cierra el
--  paso. Eso vive en el panel, en RECAUDOS.
--
--  ENCADENADO
--  ─────────────────────────────────────────────────────────────────────
--  EMITE la opinión favorable, que el c22 pide. Y PIDE el proyecto del
--  acta, que sale del c5, y el poder, que sale del c33: la cadena
--  c5 → c34 → c22 se deduce sola de los recaudos, sin escribirla.
--
--  LO QUE ESTÁ POR CONFIRMAR CON EL CIIP, Y POR ESO NO ESTÁ
--  ─────────────────────────────────────────────────────────────────────
--  1. EN QUÉ CASOS TOCA. Qué zonas y qué sectores. Mientras no se sepa, el
--     formulario deja elegir «No lo sé: que lo revise el CIIP».
--  2. EL PLAZO. El mensaje no da ninguno y aquí no se inventa: plazo_dias
--     se queda en null, como los ocho que no prometen ninguno. Sin plazo,
--     el panel no marca nunca la solicitud como tardía.
--  3. LA BASE LEGAL. El mensaje cita una «Ley Orgánica de las Zonas
--     Fronterizas» que no aparece con ese nombre; lo más cercano son la
--     Ley Orgánica de Fronteras y las zonas de seguridad de la Ley
--     Orgánica de Seguridad de la Nación. Ninguna de las dos se cita en
--     la ficha hasta que el CIIP lo diga.
--  4. SI CADUCA LA OPINIÓN. No se sabe, así que vence = false.
--
--  Si alguien corre supabase-tramites.sql SOLO, después de este, el c34
--  se apaga: aquel deja encendidos exactamente los de su lista. Es lo
--  mismo que le pasa al c32 y al c33. TODO-EN-ORDEN.sql lo corre detrás y
--  lo vuelve a encender.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LOS PAPELES NUEVOS
-- ───────────────────────────────────────────────────────────────────────
--  Tres son la cadena corporativa: sin ellos no se puede demostrar quién
--  está detrás de una empresa accionista extranjera. El cuarto es lo que
--  sale del trámite.
--
--  Que caduque o no sigue el criterio del resto del catálogo: caduca lo
--  que acredita una situación VIGENTE -el certificado de existencia legal,
--  como una solvencia- y no lo que acredita un hecho de una fecha -los
--  estatutos, la lista firmada-.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('estatutos_accionista',  'Documento constitutivo y estatutos de la empresa accionista y de su matriz', false),
  ('good_standing',         'Certificado de existencia legal (Good Standing)',                         true),
  ('beneficiarios_finales', 'Lista de accionistas y directores hasta los beneficiarios finales',         false),
  ('no_objecion_zodi',      'Opinión favorable (no objeción) de la ZODI',                                false)
on conflict (codigo) do update set nombre = excluded.nombre;


-- ───────────────────────────────────────────────────────────────────────
-- 2. EL TRÁMITE
-- ───────────────────────────────────────────────────────────────────────
--  Fase 2, entre la constitución (c5) y la protocolización (c22): necesita
--  el proyecto del acta y tiene que estar antes de protocolizar.
--
--  El ente va como 'ZODI' y no con la región: hay una por región, y cuál
--  es lo dice el estado que se escribe en el formulario.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('opinion_zodi', 'c34', 'Opinión favorable de la ZODI', 'ZODI', 2, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite      = 'no_objecion_zodi',
       plazo_dias = null,
       nivel      = 'actividad',
       activo     = true
 where codigo = 'opinion_zodi';


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Una fila: c34 · ZODI · fase 2 · actividad · emite la no objeción ·
--    sin plazo · encendido.
--
--   select ref_panel, codigo, nombre, ente, fase, nivel, emite, plazo_dias, activo
--   from public.tipos_tramite where ref_panel = 'c34';
--
-- 2) Los cuatro papeles nuevos:
--
--   select codigo, nombre, vence from public.tipos_documento
--   where codigo in ('estatutos_accionista','good_standing',
--                    'beneficiarios_finales','no_objecion_zodi');
--
-- 3) Los obligatorios siguen siendo DIEZ, cinco y cinco: el c34 no suma.
--
--   select fase, count(*) from public.tipos_tramite
--   where nivel = 'obligatorio' group by fase;
