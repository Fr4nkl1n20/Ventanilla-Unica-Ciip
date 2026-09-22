-- ═══════════════════════════════════════════════════════════════════════
--  LO QUE FALTA CORRER EN LA BASE
--  Al dia del 22 de septiembre de 2026.
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega en el SQL Editor de Supabase, PUNTO A PUNTO y no todo de una
--  vez: el editor solo enseña el resultado de la ULTIMA consulta, asi que
--  pegar los puntos juntos es quedarse sin ver los de antes.
--
--  ═══ HAY DOS BASES, Y NO LES FALTA LO MISMO ══════════════════════════
--  Produccion  fbxdwryppfctuwlnjjqr  ← la de ventanilla-unica-2.vercel.app
--  Pruebas     ifhdzxetixhrzqixcfbe
--  El proyecto sale arriba a la izquierda del panel de Supabase. MIRALO
--  ANTES DE PULSAR RUN.
--
--  Medido el 22 de septiembre de 2026 contra la base de PRUEBAS -otra vez,
--  despues de arreglar el punto 1: la primera medida uso cuatro codigos que
--  no existen y conto de mas-. Y entrando con una cuenta, porque con la
--  clave anonima RLS tapa las tablas y TODO sale vacio, que se lee como
--  «no hay nada» sin serlo:
--
--                                        PRODUCCION      PRUEBAS
--    las tres columnas nuevas            sin medir       LE FALTAN LAS 3
--    las seis fichas nuevas              sin medir       le faltan CUATRO:
--                                                        parafiscales, zodi,
--                                                        rupdae y minero.
--                                                        El c22 y el c23 SI
--                                                        estan.
--    quitar las tres fichas del 21-9     hecha el 21     SIN HACER
--    quitar el IVSS (hoy)                SIN HACER       SIN HACER
--
--  La columna de PRODUCCION no esta medida: aqui no hay cuenta suya
--  guardada, asi que dice lo que Franklin recuerda haber corrido y nada
--  mas. Para saberlo de verdad, el punto 1 en su SQL Editor.
--
--  NO TE FIES DE ESTA TABLA: esta escrita a mano y envejece. El punto 1
--  lo PREGUNTA a la base que tengas abierta, y manda lo que diga el.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
--  PUNTO 1. QUE LE FALTA A ESTA BASE
--  No cambia nada: solo mira y lo dice. Pegalo SOLO y pulsa Run.
--
--  Lo que se comprueba va en las tres listas de abajo y en ningun otro
--  sitio: añadir una cosa que mirar es añadir UN renglon. Antes cada
--  comprobacion se escribia entera, y asi fue como cuatro de las seis
--  fichas quedaron apuntadas con un codigo que no existe -'zodi' por
--  'opinion_zodi', 'rum' por 'registro_minero', 'protocolizacion' y
--  'publicacion' sin su '_acta'- y una columna en la tabla equivocada
--  -'revisado_en' es de DOCUMENTOS, no de tramites-. Cinco de nueve
--  renglones decian «FALTA» de cosas que estaban, y mandaban a correr el
--  punto 4 sin ninguna falta que arreglar.
-- ───────────────────────────────────────────────────────────────────────
with columnas (orden, tabla, columna, para_que) as (values
  (1, 'textos_panel', 'original',    'el editor guarda el texto original para poder deshacer'),
  (2, 'documentos',   'revisado_en', 'cuando el CIIP reviso el documento'),
  (3, 'documentos',   'titular',     'de quien es la cedula o el RIF, con junta directiva')
),
-- Las fichas que tienen que ESTAR. El codigo es el de la base, no el
-- ref_panel: 'cXX' aqui es solo para leerlo.
fichas (orden, codigo, para_que) as (values
  (11, 'protocolizacion_acta',   'c22 · nace sola al resolver la constitucion'),
  (12, 'publicacion_acta',       'c23 · el tramo de la publicacion del acta'),
  (13, 'opinion_zodi',           'c34 · la opinion favorable de la ZODI'),
  (14, 'rupdae',                 'c35 · la inscripcion en el RUPDAE, ante la SUNDDE'),
  (15, 'registro_minero',        'c36 · el Registro Unico Minero'),
  (16, 'registros_parafiscales', 'c37 · las cinco inscripciones en una')
),
-- Y las que tienen que HABERSE IDO.
sobran (orden, codigo, punto, para_que) as (values
  (31, 'antecedentes_penales', 'punto 3', 'se quito el 21-9'),
  (32, 'constancia_domicilio', 'punto 3', 'se quito el 21-9'),
  (33, 'visa_dependientes',    'punto 3', 'se quito el 21-9'),
  (34, 'registros_laborales',  'punto 2', 'el IVSS, que se quita hoy')
)
select orden, que, cosa, como_esta, para_que
  from (
    select orden, 'columna' as que, tabla || '.' || columna as cosa,
           case when exists (select 1
                               from information_schema.columns ic
                              where ic.table_schema = 'public'
                                and ic.table_name   = columnas.tabla
                                and ic.column_name  = columnas.columna)
                then 'esta' else 'FALTA  → punto 4' end as como_esta,
           para_que
      from columnas
    union all
    select orden, 'ficha', codigo,
           case when exists (select 1 from public.tipos_tramite t
                              where t.codigo = fichas.codigo)
                then 'esta' else 'FALTA  → punto 4' end,
           para_que
      from fichas
    union all
    select orden, 'ficha de mas', codigo,
           case when not exists (select 1 from public.tipos_tramite t
                                  where t.codigo = sobran.codigo)
                then 'ya no esta' else 'SIGUE  → ' || punto end,
           para_que
      from sobran
  ) d
 order by orden;


-- ───────────────────────────────────────────────────────────────────────
--  PUNTO 2. QUITAR EL IVSS      ← lo de hoy. VA EN LAS DOS BASES.
--
--  Franklin Reyes, 22 de septiembre de 2026: «elimina la casilla de
--  IVSS». Y fuera del catalogo, no dentro de «Registros Parafiscales y
--  Regulatorios» (c37): se pregunto y esa fue la respuesta.
--
--  Es el c9, y su codigo en la base es 'registros_laborales' -el nombre
--  le quedo de cuando hacia de una vez el IVSS, el INCES y el FAOV-.
--
--  Es lo mismo que hay en QUITAR-IVSS.sql, que es el archivo de
--  referencia. Si los dos dijeran cosas distintas, manda aquel.
-- ───────────────────────────────────────────────────────────────────────

-- 2.1  Cuantas solicitudes hay. Si sale vacio, no hay ninguna.
select tipo, estado, count(*) as solicitudes
  from public.tramites
 where tipo = 'registros_laborales'
 group by tipo, estado;

-- 2.2  Se apaga siempre: sin tarjeta en el panel, activa no sirve de nada.
update public.tipos_tramite set activo = false
 where codigo = 'registros_laborales';

-- 2.3  Y se borra del catalogo SOLO si nadie tiene una. Con solicitudes de
--      por medio la fila se queda apagada y el expediente sigue legible:
--      de ella sale el nombre que enseñan «Mis tramites» y la cola.
delete from public.tipos_tramite
 where codigo = 'registros_laborales'
   and not exists (
     select 1 from public.tramites t where t.tipo = 'registros_laborales'
   );

-- 2.4  Los textos que el admin le hubiera cambiado desde «Editar textos».
--      MIRA ANTES: esto si borra de verdad. Se quedarian en la base sin
--      nadie que los pinte y sin forma de llegar a ellos, porque el
--      editor busca la clave del elemento que pulsas y ya no hay
--      elemento.
select clave, idioma, texto from public.textos_panel
 where clave like 'c9.%' or clave = 'g.parafiscal'
 order by clave, idioma;

delete from public.textos_panel
 where clave like 'c9.%' or clave = 'g.parafiscal';

-- 2.5  Comprobar. Lo normal es que no salga nada; si sale, es que habia
--      solicitudes y la fila se quedo apagada, que es lo correcto.
select codigo, ref_panel, activo
  from public.tipos_tramite
 where codigo = 'registros_laborales';


-- ───────────────────────────────────────────────────────────────────────
--  PUNTO 3. LAS TRES FICHAS DEL 21 DE SEPTIEMBRE
--  En produccion YA ESTA HECHO -lo corriste el 21-. Esto es para pruebas,
--  y solo si el punto 1 las saco como «SIGUE».
--  El archivo de referencia es QUITAR-TRES-FICHAS.sql.
-- ───────────────────────────────────────────────────────────────────────
update public.tipos_tramite set activo = false
 where codigo in ('antecedentes_penales', 'constancia_domicilio', 'visa_dependientes');

delete from public.tipos_tramite
 where codigo in ('antecedentes_penales', 'constancia_domicilio', 'visa_dependientes')
   and not exists (
     select 1 from public.tramites t where t.tipo = tipos_tramite.codigo
   );

select codigo, ref_panel, activo
  from public.tipos_tramite
 where codigo in ('antecedentes_penales', 'constancia_domicilio', 'visa_dependientes');


-- ───────────────────────────────────────────────────────────────────────
--  PUNTO 4. SI AL PUNTO 1 LE FALTABAN COLUMNAS O FICHAS
--
--  Eso es la base de PRUEBAS, que se quedo atras. No hay que ir
--  parcheandola columna a columna.
--
--  Se pega ENTERO el archivo TODO-EN-ORDEN.sql -los 41 supabase-*.sql en
--  el orden en que los prueba PROBAR-SQL.bat- y se pulsa Run UNA vez.
--  Todos son idempotentes -create if not exists, create or replace, drop
--  policy if exists-, asi que volver a correrlo sobre una base que ya
--  tiene la mitad no rompe nada: es justo para lo que se hizo.
--
--  Y DESPUES los puntos 2 y 3 otra vez, en ese orden, POR DOS RAZONES:
--
--    · TODO-EN-ORDEN vuelve a dar de alta las fichas del catalogo,
--      incluidas las cuatro que hay que quitar. Primero se pone al dia,
--      luego se quita lo que sobra.
--
--    · Y el 2.4 no puede correr antes. Borra de textos_panel, y el
--      disparador bit_textos lee la columna 'original' tanto al insertar
--      como al borrar: en una base que todavia no la tiene, esa tabla no
--      se deja ni escribir ni limpiar. O sea que en pruebas el orden no
--      es una preferencia, es la unica forma de que funcione.
--
--  Si se regenera TODO-EN-ORDEN.sql:  node pruebas/juntar-sql.js
-- ───────────────────────────────────────────────────────────────────────


-- ───────────────────────────────────────────────────────────────────────
--  PUNTO 5. EL PUB DEL SISREF      ← nuevo del 22 de septiembre. LAS DOS.
--
--  Franklin Reyes, mirando el portal del SAREN al lado del panel: «tenemos
--  que solicitar toda esa informacion». El c32 pasa de nueve casillas a
--  las dieciseis del portal, y de tres recaudos a cuatro. Las casillas no
--  tocan la base -viven en CAMPOS, dentro del panel- y el recaudo nuevo SI:
--  la boveda busca los papeles por su tipo, y un tipo que no este en
--  tipos_documento sale como fila muda que no deja subir nada.
--
--  El PUB es la Planilla Unica Bancaria con la que el SAREN cobra. Va
--  OPCIONAL en el panel, como en el portal.
--
--  Es lo mismo que hay en supabase-informe-victor.sql, que es el archivo
--  de referencia. Si los dos dijeran cosas distintas, manda aquel.
--
--  Sin correrlo la pagina NO se rompe: salen las dieciseis casillas y los
--  otros tres recaudos, y el del PUB se queda sin nombre.
-- ───────────────────────────────────────────────────────────────────────

-- 5.1  Que hay hoy. Tienen que salir dos filas; la tercera es la que falta.
select codigo, nombre
  from public.tipos_documento
 where codigo in ('constancia_sisref', 'documento_tramite_sisref', 'pub_saren')
 order by codigo;

-- 5.2  El tipo nuevo. Se puede correr las veces que haga falta.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('pub_saren', 'Planilla Única Bancaria (PUB) del pago al SAREN', false)
on conflict (codigo) do update set nombre = excluded.nombre;

-- 5.3  Comprobar: ahora tienen que salir las TRES.
select codigo, nombre, vence
  from public.tipos_documento
 where codigo in ('constancia_sisref', 'documento_tramite_sisref', 'pub_saren')
 order by codigo;
