-- ═══════════════════════════════════════════════════════════════════════
--  CUÁNTO DEBERÍA TARDAR CADA TRÁMITE
--  Va DESPUÉS de supabase-tramites.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  El panel ya enseña las dos mitades del dato, una al lado de la otra, y
--  no las junta nunca:
--
--    · la tarjeta dice «Estimado: 2–3 semanas»
--    · el reloj dice «lleva 40 días esperando»
--
--  La resta la tiene que hacer la persona. Y esa resta es la mitad de por
--  qué alguien abre el panel: no «en qué va», sino «¿esto va tarde?».
--
--  De dónde salen los números: de la propia tarjeta, no de ningún sitio
--  nuevo. Aquí no se inventa un plazo legal —eso sale en Gaceta y lo sabe
--  el CIIP—: se pasa a número lo que el panel ya venía prometiendo en
--  seis idiomas.
--
--  SE TOMA EL TOPE, NO EL SUELO
--  ─────────────────────────────────────────────────────────────────────
--  De «2–3 semanas» se guarda 21 días, no 14. Avisar al llegar al suelo
--  del estimado sería avisar de casi todo casi siempre, y un aviso que
--  salta siempre se aprende a ignorar. Con el tope, que salte significa
--  algo.
--
--  OCHO SIN PLAZO, Y ESTÁ BIEN
--  ─────────────────────────────────────────────────────────────────────
--  Son los que no prometen ninguno: «Se pide en el consulado»,
--  «Disponible cuando quieras», «Se activan al operar». Un trámite sin
--  `plazo_dias` no se marca nunca, que es lo correcto: no se puede llegar
--  tarde a algo que no tenía hora.
--
--  Y DESDE CUÁNDO SE CUENTA
--  ─────────────────────────────────────────────────────────────────────
--  Eso NO se decide aquí, se decide en el panel, pero conviene dejarlo
--  escrito: desde que lo enviaste, no desde que empezaste el borrador. Un
--  borrador parado en tu bandeja no es la administración tardando. Y un
--  trámite devuelto tampoco cuenta: ahí la pelota la tienes tú.
-- ═══════════════════════════════════════════════════════════════════════


alter table public.tipos_tramite
  add column if not exists plazo_dias smallint;

comment on column public.tipos_tramite.plazo_dias is
  'Tope del estimado que promete la tarjeta, en días. null = no promete ninguno';

alter table public.tipos_tramite
  drop constraint if exists tipos_tramite_plazo_valido;
alter table public.tipos_tramite
  add  constraint tipos_tramite_plazo_valido
  check (plazo_dias is null or plazo_dias > 0);


-- ───────────────────────────────────────────────────────────────────────
-- LOS VEINTITRÉS QUE PROMETEN UN PLAZO
-- ───────────────────────────────────────────────────────────────────────
-- Sacados de lo que dice cada tarjeta hoy, en español, tomando el tope
-- del rango. El comentario de cada línea lleva el texto del que salió,
-- para poder comprobarlo sin abrir el panel.
--
-- Si mañana el CIIP tiene los plazos legales de verdad, se cambian estos
-- números y el panel deja de estimar y empieza a decir la ley. La forma
-- no cambia.

update public.tipos_tramite set plazo_dias =  28 where codigo = 'licencia_conducir';                 -- c4  Estimado: 3–4 semanas
update public.tipos_tramite set plazo_dias =  21 where codigo = 'constitucion';                      -- c5  Estimado: 2–3 semanas
update public.tipos_tramite set plazo_dias =  14 where codigo = 'cuenta_bancaria';                   -- c7  Estimado: 1–2 semanas
update public.tipos_tramite set plazo_dias = 240 where codigo = 'marca';                             -- c8  Estimado: 4–8 meses
update public.tipos_tramite set plazo_dias =  28 where codigo = 'registros_laborales';               -- c9  Estimado: 2–4 semanas
update public.tipos_tramite set plazo_dias =  42 where codigo = 'licencia_municipal';                -- c10  Estimado: 3–6 semanas
update public.tipos_tramite set plazo_dias =  90 where codigo = 'permiso_sanitario';                 -- c12  Estimado: 1–3 meses
update public.tipos_tramite set plazo_dias =  42 where codigo = 'antecedentes_penales';              -- c16  Estimado: 3–6 semanas
update public.tipos_tramite set plazo_dias =  28 where codigo = 'apostilla_documentos';              -- c17  Estimado: 2–4 semanas
update public.tipos_tramite set plazo_dias =  14 where codigo = 'constancia_domicilio';              -- c18  Estimado: 1–2 semanas
update public.tipos_tramite set plazo_dias =  21 where codigo = 'firma_electronica';                 -- c19  Estimado: 2–3 semanas
update public.tipos_tramite set plazo_dias =  70 where codigo = 'visa_dependientes';                 -- c20  Estimado: 6–10 semanas
update public.tipos_tramite set plazo_dias =   7 where codigo = 'cert_medico';                       -- c21  Estimado: 1 semana
update public.tipos_tramite set plazo_dias =  42 where codigo = 'protocolizacion_acta';              -- c22  Estimado: 2–6 semanas
update public.tipos_tramite set plazo_dias =  14 where codigo = 'publicacion_acta';                  -- c23  Estimado: 1–2 semanas
update public.tipos_tramite set plazo_dias =  28 where codigo = 'libros_contables';                  -- c24  Estimado: 2–4 semanas
update public.tipos_tramite set plazo_dias =  21 where codigo = 'faov_banavih';                      -- c25  Estimado: 2–3 semanas
update public.tipos_tramite set plazo_dias =  21 where codigo = 'inces';                             -- c26  Estimado: 2–3 semanas
update public.tipos_tramite set plazo_dias =  28 where codigo = 'rnet';                              -- c27  Estimado: 3–4 semanas
update public.tipos_tramite set plazo_dias =  60 where codigo = 'conformidad_uso';                   -- c28  Estimado: 1–2 meses
update public.tipos_tramite set plazo_dias =  42 where codigo = 'permiso_bomberos';                  -- c29  Estimado: 3–6 semanas
update public.tipos_tramite set plazo_dias = 180 where codigo = 'permiso_ambiental';                 -- c30  Estimado: 2–6 meses
update public.tipos_tramite set plazo_dias = 120 where codigo = 'registro_inversion';                -- c31  Estimado: 2–4 meses

-- ───────────────────────────────────────────────────────────────────────
-- LAS DOS QUE FALTABAN
-- ───────────────────────────────────────────────────────────────────────
-- La c32 y la c33 SÍ prometían un plazo en su tarjeta y no tenían fila
-- aquí. Mientras el renglón del reloj salía del diccionario no se notaba;
-- desde que sale de esta columna, sin fila no hay reloj, y estas dos lo
-- perderían diciendo un tiempo que sí tienen.
--
-- Salen del mismo sitio y por el mismo método que las veintitrés de
-- arriba: el texto que llevaba su propia tarjeta, tomando el tope del
-- rango. Ese texto ya no está en el panel —las 33 claves cN.time se
-- retiraron al dejar una sola cifra—, así que queda escrito aquí, que es
-- ahora el único sitio donde vive el dato.
update public.tipos_tramite set plazo_dias =  14 where codigo = 'registro_extranjeros_saren';        -- c32  Estimado: 1–2 semanas
update public.tipos_tramite set plazo_dias =   7 where codigo = 'poder_representacion';              -- c33  Estimado: 1 semana

-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Veintitrés con plazo y ocho sin él:
--
--   select count(*) filter (where plazo_dias is not null) as con,
--          count(*) filter (where plazo_dias is null)     as sin
--   from public.tipos_tramite;
--
-- 2) Y lo que de verdad se quiere ver: qué está tardando más de lo que se
--    prometió. Esto es la consulta que el panel hace en pantalla, escrita
--    aquí para poder mirarla desde el SQL Editor.
--
--   select t.id, t.tipo, tt.plazo_dias,
--          (current_date - t.enviado_en::date) as lleva
--   from public.tramites t
--   join public.tipos_tramite tt on tt.codigo = t.tipo
--   where t.estado in ('enviado','en_revision','ante_el_ente')
--     and tt.plazo_dias is not null
--     and t.enviado_en is not null
--     and (current_date - t.enviado_en::date) > tt.plazo_dias
--   order by lleva desc;
--
--    Fíjate en los tres estados: un borrador o un devuelto NO salen, y no
--    es un olvido. Ahí la pelota la tiene el inversionista, y contar ese
--    tiempo como retraso del organismo sería echarle la culpa al de
--    enfrente de lo que uno no ha hecho.


-- ═══════════════════════════════════════════════════════════════════════
--  Y EL PLAZO LEGAL, QUE NO ES EL ESTIMADO
-- ═══════════════════════════════════════════════════════════════════════
--  Los veintitrés números de arriba salen del texto de las tarjetas: son
--  lo que se TARDA, o lo que el CIIP calcula que se tarda. Esto es otra
--  cosa: lo que dice la NORMA. Van aparte porque casi nunca coinciden y
--  porque enseñar uno en lugar del otro engaña de las dos maneras.
--
--  EL INFORME PEDÍA SUSTITUIR UNO POR OTRO, Y ES PEOR
--  ─────────────────────────────────────────────────────────────────────
--  «Se recomienda suprimir de la vista del usuario el plazo en la
--   práctica y conservar de manera exclusiva el plazo legal regulatorio.»
--
--  Al ir a buscarlos aparece por qué eso no se puede hacer así. De las
--  dos normas leídas hasta hoy, NINGUNA fija plazo de respuesta: regulan
--  lo que debe hacer el ciudadano y cuánto vale el documento, no cuánto
--  tarda el organismo. Si no hay plazo propio, lo que queda es el
--  supletorio de la LOPA -cuatro meses, artículo 60-, y entonces la
--  tarjeta del RIF pasaría de «2–3 semanas» a «4 meses». Cierto, y mucho
--  peor para quien lo lee.
--
--  Así que se guardan los DOS, cada uno con su nombre.
--
--  CÓMO SE LEEN ESTAS DOS COLUMNAS
--  ─────────────────────────────────────────────────────────────────────
--  plazo_legal_norma es la que manda, y sirve de marca de comprobado:
--
--    norma NULL                  nadie lo ha mirado todavía. El panel no
--                                dice nada. Es el caso de 31 de 33.
--    norma puesta, días NULL     mirado, y su norma NO fija plazo de
--                                respuesta. El panel lo dice con esas
--                                palabras, que es la verdad y es útil.
--    norma puesta, días puestos  la norma fija plazo. Los días son suyos.
--
--  La cita va en castellano y no se traduce: «Gaceta Oficial
--  Extraordinaria 5.427» se llama igual en los seis idiomas. Lo que sí se
--  traduce -el rótulo y la frase de «no fija plazo»- vive en pasos.js.
--
--  NO SE INVENTA NINGUNO
--  ─────────────────────────────────────────────────────────────────────
--  Sólo entran los que se han leído en su fuente. Poner aquí el supletorio
--  de la LOPA en los treinta y tres sería escribir treinta y tres veces
--  una interpretación jurídica que no ha hecho ningún abogado, y con la
--  cara de dato comprobado. Los que faltan se van añadiendo con un UPDATE
--  cada vez que se confirme uno.
-- ═══════════════════════════════════════════════════════════════════════

alter table public.tipos_tramite
  add column if not exists plazo_legal_dias  smallint,
  add column if not exists plazo_legal_norma text;

comment on column public.tipos_tramite.plazo_legal_dias is
  'Plazo que fija la norma, en dias. Null con norma puesta = la norma no fija plazo';
comment on column public.tipos_tramite.plazo_legal_norma is
  'La norma leida, citada. Null = todavia no lo ha mirado nadie';

alter table public.tipos_tramite
  drop constraint if exists tipos_tramite_plazo_legal_valido;
alter table public.tipos_tramite
  add  constraint tipos_tramite_plazo_legal_valido
  check (plazo_legal_dias is null or plazo_legal_dias > 0);

-- Un plazo sin norma que lo respalde es justo lo que este archivo viene a
-- evitar: un numero con cara de ley y sin ley detras.
alter table public.tipos_tramite
  drop constraint if exists tipos_tramite_plazo_legal_con_fuente;
alter table public.tipos_tramite
  add  constraint tipos_tramite_plazo_legal_con_fuente
  check (plazo_legal_dias is null or plazo_legal_norma is not null);


-- ───────────────────────────────────────────────────────────────────────
-- LOS COMPROBADOS. HOY, DOS DE TREINTA Y TRES.
-- ───────────────────────────────────────────────────────────────────────
-- c1 · Visa de inversionista (TR-I)
--   Normas de Procedimiento para la Expedicion de Visados, Gaceta Oficial
--   Extraordinaria 5.427 del 5 de enero de 2000. Leida entera. Sus
--   articulos 11 y 12 dicen a quien se otorga y cuanto VALE la visa
--   -tres años, prorrogables dos-, y no fijan plazo para decidirla. La
--   unica mencion al respecto es el articulo 1: los consulados «atenderan
--   y decidiran» las solicitudes, sin plazo.
update public.tipos_tramite
   set plazo_legal_norma = 'Normas de Procedimiento para la Expedición de Visados, Gaceta Oficial Extraordinaria 5.427 del 5-1-2000',
       plazo_legal_dias  = null
 where codigo = 'visa_inversionista';

-- c3 · RIF personal
--   Providencia SNAT/2026/00080, Gaceta Oficial 43.435 del 12 de agosto
--   de 2026, que deroga la SNAT/2013/0048. Es la vigente. No fija plazo
--   para que el SENIAT emita el RIF.
--
--   OJO CON EL DATO QUE CORRE POR AHI: los «30 dias habiles» que aparecen
--   en todas partes son el plazo que tiene el CONTRIBUYENTE para
--   inscribirse -articulo 5-, no el que tiene la administracion para
--   atenderle. Es la obligacion al reves, y meterla aqui seria mentir
--   con un dato verdadero.
update public.tipos_tramite
   set plazo_legal_norma = 'Providencia SNAT/2026/00080, Gaceta Oficial 43.435 del 12-8-2026',
       plazo_legal_dias  = null
 where codigo = 'rif_personal';


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Cuantos llevan norma leida. Hoy dos; que suba es el trabajo.
--
--   select count(*) filter (where plazo_legal_norma is not null) as mirados,
--          count(*)                                              as total
--   from public.tipos_tramite;
--
-- 2) Y cuales, con lo que se encontro:
--
--   select ref_panel, codigo, plazo_legal_dias, plazo_legal_norma
--   from public.tipos_tramite
--   where plazo_legal_norma is not null
--   order by ref_panel;
--
-- 3) Que no haya dias sin norma. Tiene que salir vacio; ademas lo impide
--    la restriccion de arriba, asi que esto es para leerlo:
--
--   select ref_panel from public.tipos_tramite
--   where plazo_legal_dias is not null and plazo_legal_norma is null;
