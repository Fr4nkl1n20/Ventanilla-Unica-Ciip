-- ═══════════════════════════════════════════════════════════════════════
--  LO QUE FALTA CORRER EN LA BASE
--  Al dia del 22 de septiembre de 2026.
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega en el SQL Editor de Supabase, POR PUNTOS y no de una vez: el
--  editor solo enseña el resultado de la ULTIMA consulta, asi que pegar
--  los cuatro puntos juntos es quedarse sin ver los tres primeros.
--
--  ═══ HAY DOS BASES, Y NO LES FALTA LO MISMO ══════════════════════════
--  Produccion  fbxdwryppfctuwlnjjqr  ← la de ventanilla-unica-2.vercel.app
--  Pruebas     ifhdzxetixhrzqixcfbe
--  El proyecto sale arriba a la izquierda del panel de Supabase. MIRALO
--  ANTES DE PULSAR RUN.
--
--  Medido el 22 de septiembre de 2026 contra la base de PRUEBAS, y en
--  produccion segun lo que Franklin confirmo que habia corrido:
--
--                                        PRODUCCION      PRUEBAS
--    columnas del panel (11, 12, 9/10)   hechas          LE FALTAN LAS 3
--    fichas nuevas (c35, c36, c34, c37,
--      protocolizacion, publicacion)     hechas          LE FALTAN LAS 6
--    quitar las tres fichas del 21-9     hecha           SIN HACER
--    quitar el IVSS (hoy)                SIN HACER       SIN HACER
--
--  O sea: en produccion solo falta el PUNTO 2. En pruebas falta todo, y
--  el camino corto esta en el punto 4.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
--  PUNTO 1. QUE LE FALTA A ESTA BASE
--  No cambia nada: solo mira y lo dice. Pegalo SOLO y pulsa Run.
-- ───────────────────────────────────────────────────────────────────────
select *
  from (
    --  Las tres columnas que trajeron los puntos 9, 10, 11 y 12.
    select 1 as orden, 'columna' as que, 'textos_panel.original' as cosa,
           case when exists (select 1 from information_schema.columns
                              where table_schema = 'public'
                                and table_name  = 'textos_panel'
                                and column_name = 'original')
                then 'esta'
                else 'FALTA  → punto 4' end as como_esta,
           'el editor guarda el texto original para poder deshacer' as para_que
    union all
    select 2, 'columna', 'tramites.revisado_en',
           case when exists (select 1 from information_schema.columns
                              where table_schema = 'public'
                                and table_name  = 'tramites'
                                and column_name = 'revisado_en')
                then 'esta' else 'FALTA  → punto 4' end,
           'cuando el CIIP reviso los documentos de la solicitud'
    union all
    select 3, 'columna', 'documentos.titular',
           case when exists (select 1 from information_schema.columns
                              where table_schema = 'public'
                                and table_name  = 'documentos'
                                and column_name = 'titular')
                then 'esta' else 'FALTA  → punto 4' end,
           'de quien es la cedula o el RIF, con junta directiva'

    --  Las fichas que tienen que ESTAR.
    union all
    select 10 + row_number() over (order by c.codigo), 'ficha', c.codigo,
           case when exists (select 1 from public.tipos_tramite t
                              where t.codigo = c.codigo)
                then 'esta' else 'FALTA  → punto 4' end,
           c.para_que
      from (values
        ('registros_parafiscales', 'c37 · las cinco inscripciones en una'),
        ('zodi',                   'c34 · la ficha de la ZODI'),
        ('rupdae',                 'c35 · Registro Unico de Personas del Estado'),
        ('rum',                    'c36 · Registro Unico Minero'),
        ('protocolizacion',        'c22 · nace sola al resolver la constitucion'),
        ('publicacion',            'c23 · el tramo de la publicacion del acta')
      ) as c(codigo, para_que)

    --  Y las que tienen que HABERSE IDO.
    union all
    select 30 + row_number() over (order by c.codigo), 'ficha de mas', c.codigo,
           case when not exists (select 1 from public.tipos_tramite t
                                  where t.codigo = c.codigo)
                then 'ya no esta'
                else 'SIGUE  → ' || c.punto end,
           c.para_que
      from (values
        ('antecedentes_penales', 'punto 3', 'se quito el 21-9'),
        ('constancia_domicilio', 'punto 3', 'se quito el 21-9'),
        ('visa_dependientes',    'punto 3', 'se quito el 21-9'),
        ('registros_laborales',  'punto 2', 'el IVSS, que se quita hoy')
      ) as c(codigo, punto, para_que)
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

delete from public.textos_panel where clave like 'c9.%';
delete from public.textos_panel where clave = 'g.parafiscal';

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
--  Eso es la base de PRUEBAS, que se quedo atras: le faltan las tres
--  columnas y las seis fichas de la lista. No hay que ir parcheandolas
--  una a una.
--
--  Se pega ENTERO el archivo TODO-EN-ORDEN.sql -los 41 supabase-*.sql en
--  el orden en que los prueba PROBAR-SQL.bat- y se pulsa Run UNA vez.
--  Todos son idempotentes -create if not exists, create or replace, drop
--  policy if exists-, asi que volver a correrlo sobre una base que ya
--  tiene la mitad no rompe nada: es justo para lo que se hizo.
--
--  Y DESPUES los puntos 2 y 3 otra vez, en ese orden: TODO-EN-ORDEN
--  vuelve a dar de alta las fichas del catalogo, incluidas las cuatro que
--  hay que quitar. Primero se pone al dia, luego se quita lo que sobra.
--
--  Si se regenera TODO-EN-ORDEN.sql:  node pruebas/juntar-sql.js
-- ───────────────────────────────────────────────────────────────────────
