-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LAS CINCO INSCRIPCIONES, EN UNA CASILLA (c37)
--  Va DESPUÉS de supabase-rupdae-rum.sql: apaga el c35 que aquel encendió,
--  y usa las columnas `nivel` (supabase-informe-victor.sql) y `emite`
--  (supabase-encadenado.sql).
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Del encargo del 20 de septiembre de 2026:
--
--    «Vamos a agrupar los trámites de Banavih, Inces, Ministerio de
--     Trabajo, RNC y Rupdae en una sola casilla. Se va a llamar
--     Inscripciones: Registros Parafiscales y Regulatorios.»
--
--    «Ahora bien, con un solo paso vamos a recoger todos los recaudos, no
--     es necesario que creemos un proceso por cada inscripción, porque
--     todos requieren los mismos recaudos.»
--
--  Son las dos cosas, y la segunda es la que manda: no es una ficha madre
--  con cinco trámites dentro —eso es lo que ya hace la constitución con la
--  protocolización y la publicación, y son tres solicitudes—, es UN
--  trámite, UNA solicitud, UN juego de recaudos. El precedente de la casa
--  es el c14: cuatro solvencias, una sola solicitud.
--
--  EL IVSS (c9) NO ENTRA AQUÍ, Y DESDE EL 22-9-2026 NO ESTÁ EN NINGÚN SITIO
--  ─────────────────────────────────────────────────────────────────────
--  El 20 de septiembre no estaba en la lista del encargo, se preguntó, y
--  se quedó con casilla propia al lado de ésta.
--
--  El 22 de septiembre el CIIP la quitó: «elimina la casilla de IVSS», y
--  se confirmó que sale DEL CATÁLOGO, no que se hace dentro de esta. Así
--  que aquí no hay nada que absorber: el c9 no está entre los cinco de
--  abajo porque no está en el catálogo. Quien tenga la fila todavía la
--  apaga y la borra con QUITAR-IVSS.sql.
--
--  Y el rótulo «Obligaciones parafiscales y laborales» se fue con él: con
--  una sola ficha debajo repetía lo que la ficha ya dice en su nombre.
--
--  QUÉ PASA CON LOS CINCO QUE ABSORBE
--  ─────────────────────────────────────────────────────────────────────
--  Se APAGAN, no se borran. Es la diferencia que cuenta:
--
--   · Las solicitudes que ya estén en la base siguen donde están, con su
--     historial, sus recaudos y su sitio en la cola del equipo. Apagar un
--     trámite no toca un expediente; lo dice supabase-catalogos.sql.
--   · Lo que deja de pasar es que se ofrezcan a quien no los haya
--     empezado. En el panel sus fichas llevan data-tramo-de="c37" y ya no
--     se ven en la portada ni se cuentan en la etapa.
--   · Y se vuelven a encender con el mismo interruptor, desde el panel del
--     admin, si el CIIP se arrepiente.
--
--  EL PLAZO: 28 DÍAS, Y POR QUÉ ESTE
--  ─────────────────────────────────────────────────────────────────────
--  Los cinco se presentan a la vez con el mismo expediente, así que la
--  casilla no está resuelta hasta que vuelve el último. De los cinco, el
--  más largo de los que TIENEN plazo en el catálogo es el RNET: 28 días
--  (supabase-plazos.sql). El FAOV y el INCES van a 21, el RUPDAE a 14.
--
--  POR CONFIRMAR: el RNC no tiene plazo en el catálogo —nunca lo tuvo— y
--  es el que más podría tardar de los cinco. Si el CIIP mide que el
--  expediente del RNC se va más allá de las cuatro semanas, este número
--  se queda corto y la casilla promete algo que no cumple. Lo honesto
--  entonces es dejarlo en null: sin fila, la ficha no enseña reloj.
--
--  POR QUÉ 'esencial'
--  ─────────────────────────────────────────────────────────────────────
--  El RNET y el RUPDAE le tocan a toda empresa, así que la casilla le toca
--  a todos. Los cinco sueltos estaban en 'actividad' —menos el RUPDAE, que
--  ya era 'esencial'— y juntos no pueden decir «según tu actividad»: lo
--  que hay dentro es de todos. No suma a los diez obligatorios del informe
--  del 2 de septiembre, que los decidió el CIIP y no se tocan aquí.
--
--  POR QUÉ NO EMITE NADA
--  ─────────────────────────────────────────────────────────────────────
--  `emite` guarda UN tipo de documento y esta casilla devuelve CINCO
--  constancias. Poner una de las cinco sería decir que las otras cuatro no
--  salen de ningún sitio, y encadenaría mal: un trámite que pidiera la
--  constancia del RNET se quedaría esperando por un `emite` que dice
--  «certificado_rupdae». Se deja en null, que es lo que ya hacía el c27.
--  El día que la columna admita varios, esto es una línea.
--
--  Si alguien corre supabase-tramites.sql SOLO, después de este, los cinco
--  se vuelven a encender y el c37 se apaga: aquel deja encendidos
--  exactamente los de su lista. Es lo mismo que le pasa al c32, al c33, al
--  c34, al c35 y al c36. TODO-EN-ORDEN.sql lo corre detrás y lo arregla.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA CASILLA NUEVA
-- ───────────────────────────────────────────────────────────────────────
-- El ente va en plural y sin siglas: son cinco organismos y ninguno manda
-- sobre los otros. Es el mismo criterio del c14, «Entes varios».
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('registros_parafiscales', 'c37',
   'Inscripciones: Registros Parafiscales y Regulatorios',
   'Entes varios', 3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set nombre     = 'Inscripciones: Registros Parafiscales y Regulatorios',
       ente       = 'Entes varios',
       fase       = 3,
       emite      = null,
       plazo_dias = 28,
       nivel      = 'esencial',
       activo     = true
 where codigo = 'registros_parafiscales';


-- ───────────────────────────────────────────────────────────────────────
-- 2. Y LOS CINCO QUE AHORA SE HACEN DENTRO
-- ───────────────────────────────────────────────────────────────────────
-- Apagar, no borrar. Sus expedientes siguen vivos; lo que se retira es la
-- oferta. Ver la nota de arriba.
update public.tipos_tramite
   set activo = false
 where codigo in ('faov_banavih',   -- c25  BANAVIH · FAOV
                  'inces',          -- c26  INCES
                  'rnet',           -- c27  Ministerio del Trabajo · RNET
                  'rnc',            -- c13  Servicio Nacional de Contrataciones
                  'rupdae');        -- c35  SUNDDE

-- AQUÍ SE ENCENDÍA EL IVSS (c9) A PROPÓSITO, y se fue el 22-9-2026 con la
-- casilla. Se deja dicho para que nadie lo añada a la lista de arriba por
-- parecerse: no se apaga porque esté dentro de ésta, es que ya no está.


-- ───────────────────────────────────────────────────────────────────────
-- 3. LOS PAPELES DE LOS INVERSIONISTAS Y DE LA JUNTA (23-9-2026)
-- ───────────────────────────────────────────────────────────────────────
-- Un archivo por papel con todas las personas dentro. No vencen: con
-- varias personas en un archivo no hay una sola fecha que pedir.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('rif_inversionistas', 'RIF de los inversionistas',                      false),
  ('cedulas_junta',      'Cédula de los miembros de la junta directiva',   false),
  ('rifs_junta',         'RIF de los miembros de la junta directiva',      false)
on conflict (codigo) do update set nombre = excluded.nombre;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) La casilla nueva: c37 · Entes varios · fase 3 · esencial · 28 días ·
--    sin `emite` · encendida.
--
--   select ref_panel, codigo, nombre, ente, fase, nivel, emite, plazo_dias, activo
--   from public.tipos_tramite where ref_panel = 'c37';
--
-- 2) Los cinco apagados. Tienen que salir cinco filas y las cinco en
--    'false'; 'registros_laborales' va en la lista para comprobar que NO
--    sale ninguna, que es donde estaba el IVSS:
--
--   select ref_panel, codigo, activo from public.tipos_tramite
--   where codigo in ('faov_banavih','inces','rnet','rnc','rupdae','registros_laborales')
--   order by ref_panel;
--
-- 3) Que apagar no se llevó ningún expediente por delante. Si había
--    solicitudes de los cinco, siguen aquí:
--
--   select tipo, estado, count(*) from public.tramites
--   where tipo in ('faov_banavih','inces','rnet','rnc','rupdae')
--   group by tipo, estado order by tipo;
--
-- 4) Los obligatorios siguen siendo DIEZ, cinco y cinco: el c37 es
--    'esencial' y no suma.
--
--   select fase, count(*) from public.tipos_tramite
--   where nivel = 'obligatorio' group by fase;
