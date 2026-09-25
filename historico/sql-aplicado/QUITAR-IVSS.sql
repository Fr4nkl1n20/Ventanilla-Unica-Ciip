-- SQL Editor de Supabase. Mira antes de borrar.
--
-- Franklin Reyes, 22 de septiembre de 2026: "elimina la casilla de IVSS".
-- Y fuera del catalogo, no dentro de "Registros Parafiscales y
-- Regulatorios" (c37): se pregunto y esa fue la respuesta.
--
-- Es el c9, y su codigo en la base es 'registros_laborales' -el nombre le
-- quedo de cuando hacia de una vez el IVSS, el INCES y el FAOV-.

-- 1. Cuantas solicitudes hay. Si sale vacio, no hay ninguna.
select tipo, estado, count(*) as solicitudes
  from public.tramites
 where tipo = 'registros_laborales'
 group by tipo, estado;

-- 2. Se apaga siempre: sin tarjeta en el panel, activa no sirve de nada.
update public.tipos_tramite set activo = false
 where codigo = 'registros_laborales';

-- 3. Y se borra del catalogo SOLO si nadie tiene una. Con solicitudes de
--    por medio, la fila se queda apagada y el expediente sigue legible:
--    de ella sale el nombre que enseñan "Mis tramites" y la cola.
delete from public.tipos_tramite
 where codigo = 'registros_laborales'
   and not exists (
     select 1 from public.tramites t where t.tipo = 'registros_laborales'
   );

-- 4. Comprobar. Lo normal es que no salga nada; si sale, es que habia
--    solicitudes y la fila se quedo apagada, que es lo correcto.
select codigo, ref_panel, activo
  from public.tipos_tramite
 where codigo = 'registros_laborales';

-- 5. Y los textos que el admin le hubiera cambiado desde «Editar textos».
--    Se quedarian en la base sin nadie que los pinte y sin forma de
--    llegar a ellos: el editor busca la clave del elemento que pulsas, y
--    ya no hay elemento. Mira primero, que esto si borra de verdad.
select clave, idioma, texto from public.textos_panel
 where clave like 'c9.%' order by clave, idioma;

delete from public.textos_panel where clave like 'c9.%';

-- Y el rotulo del grupo, que se fue con la casilla: juntaba una sola
-- ficha y decia lo que esa ficha ya dice en su nombre.
select clave, idioma, texto from public.textos_panel
 where clave = 'g.parafiscal' order by idioma;

delete from public.textos_panel where clave = 'g.parafiscal';
