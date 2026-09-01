-- ═══════════════════════════════════════════════════════════════════════
--  QUÉ PAPEL SALE DE CADA TRÁMITE
--  Va DESPUÉS de supabase-tramites.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  La tarjeta del RIF de la empresa dice «Se habilita tras la firma». La
--  de la cédula de residencia dice «Después de la visa». Están traducidas
--  a los seis idiomas.
--
--  Y no son ciertas. Son texto: no hay una sola línea de código que mire
--  si la constitución está resuelta antes de dejarte empezar el RIF. La
--  ventanilla DICE el orden pero no lo SABE, así que un inversionista
--  puede pedir el RIF de una empresa que todavía no existe y enterarse
--  cuando el SENIAT se lo devuelva.
--
--  LA CADENA NO SE ESCRIBE: SE DEDUCE
--  ─────────────────────────────────────────────────────────────────────
--  Escribir a mano «el c7 depende del c6» sería una segunda lista que
--  mantener, y que envejecería en cuanto alguien cambiara los recaudos de
--  un trámite sin acordarse de tocarla.
--
--  No hace falta, porque el dato ya está, repartido en dos sitios:
--
--    · qué papeles PIDE cada trámite  → RECAUDOS, en el panel
--    · qué papel SALE de cada trámite → esta columna, que es lo único
--                                        que faltaba
--
--  Con las dos, la cadena se calcula sola: si el c7 pide el acta y el
--  acta sale del c5, el c7 viene después del c5. Cambia un recaudo y la
--  cadena se recoloca sin que nadie la toque.
--
--  Lo dice tu propio comentario en el panel, escrito antes que este
--  archivo: «La constitución NO pide el acta: el acta es lo que SALE de
--  aquí, y de ahí pasa a la bóveda para que el c6 la tome».
--
--  Y OJO CON QUÉ ES LO QUE BLOQUEA
--  ─────────────────────────────────────────────────────────────────────
--  No te bloquea el TRÁMITE anterior: te bloquea no tener el PAPEL. Si ya
--  traes el acta de tu país, o constituiste la compañía antes de llegar
--  al CIIP, el acta está en tu bóveda y no tienes que pedirle nada a
--  nadie. Esa distinción es la ventanilla única entera: se pide una vez,
--  y da igual por dónde llegó.
-- ═══════════════════════════════════════════════════════════════════════


alter table public.tipos_tramite
  add column if not exists emite text references public.tipos_documento(codigo);

comment on column public.tipos_tramite.emite is
  'Qué tipo de documento produce este trámite. null = todavía no se sabe';


-- ───────────────────────────────────────────────────────────────────────
-- LOS QUE SE SABEN DE CIERTO
-- ───────────────────────────────────────────────────────────────────────
-- Siete, y ninguno inventado: cinco porque el código del trámite y el del
-- documento son EL MISMO o el nombre no admite otra lectura, y el del
-- acta porque lo dice el comentario del panel.
--
-- Se activan con UPDATE y no en el INSERT del catálogo, que lleva ON
-- CONFLICT DO NOTHING y en una base que ya existe no tocaría nada.

update public.tipos_tramite set emite = 'visa'               where codigo = 'visa_inversionista';
update public.tipos_tramite set emite = 'cedula'             where codigo = 'cedula_residencia';
update public.tipos_tramite set emite = 'rif_personal'       where codigo = 'rif_personal';
update public.tipos_tramite set emite = 'acta_constitutiva'  where codigo = 'constitucion';
update public.tipos_tramite set emite = 'rif_empresa'        where codigo = 'rif_empresa';
update public.tipos_tramite set emite = 'acta_protocolizada' where codigo = 'protocolizacion_acta';
update public.tipos_tramite set emite = 'conformidad_uso'    where codigo = 'conformidad_uso';

-- ───────────────────────────────────────────────────────────────────────
-- LOS QUE HAY QUE MIRAR ANTES DE PONER
-- ───────────────────────────────────────────────────────────────────────
-- Estos PARECEN evidentes y por eso mismo no van puestos: cada uno es una
-- afirmación sobre qué papel entrega un organismo venezolano, y eso lo
-- sabe el CIIP, no este archivo. Cuando alguien los confirme, se
-- descomenta la línea que toque.
--
-- Un trámite sin `emite` no estorba: simplemente no encadena nada, y todo
-- sigue funcionando como hasta hoy.
--
--   update public.tipos_tramite set emite = 'certificado_medico' where codigo = 'cert_medico';
--   update public.tipos_tramite set emite = 'bomberos'           where codigo = 'permiso_bomberos';
--   update public.tipos_tramite set emite = 'registro_rnet'      where codigo = 'rnet';
--   update public.tipos_tramite set emite = 'inversion'          where codigo = 'registro_inversion';
--   update public.tipos_tramite set emite = 'antecedentes'       where codigo = 'antecedentes_penales';
--
-- El de antecedentes es el mejor ejemplo de por qué van comentados: hay
-- DOS tipos de documento que podrían ser -'antecedentes' y
-- 'antecedentes_origen'- y elegir mal encadenaría el trámite equivocado.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Qué trámites emiten algo, y qué:
--
--   select ref_panel, codigo, emite from public.tipos_tramite
--    where emite is not null order by ref_panel;
--
-- 2) Y que ningún `emite` apunte a un tipo de documento que no existe.
--    La clave foránea ya lo impide al escribir; esto es para leerlo:
--
--   select t.codigo, t.emite from public.tipos_tramite t
--    left join public.tipos_documento d on d.codigo = t.emite
--    where t.emite is not null and d.codigo is null;
--
--    Tiene que salir vacío.
--
-- 3) La cadena que sale de ahí NO se consulta aquí: la calcula el panel
--    cruzando esto con los recaudos de cada trámite. Se mira en pantalla,
--    en la tarjeta que diga «esperando a».
