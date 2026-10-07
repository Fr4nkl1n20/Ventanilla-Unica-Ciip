-- El ente del sellado de libros y dos nombres del catálogo (Franklin Reyes, 7-10-2026).
--
-- 1. El sellado de libros (c24) se presenta ante el SAREN, no ante el SENIAT. Lo dicen sus
--    pasos desde el 29-9-2026 («Solicitud introducida ante el SAREN», «Emisión de PUB por
--    SAREN») y la especificación («Pendientes FRANK.pdf», p. 13), pero el catálogo seguía con
--    el 'SENIAT' de supabase-tramites.sql, y el ente del catálogo es el que lee el gestor en
--    su botón: «Presentada ante SENIAT» para una solicitud que el CIIP lleva al SAREN.
--
-- 2. Los nombres de la cédula (c2) y de la traducción (c17), como los dice la especificación
--    y ya los enseña la tarjeta: «Cédula de identidad de extranjero» («Ventanilla unica
--    2.4.pdf», p. 1) y «Traducción de documentos» («Pendientes FRANK.pdf», p. 7; el CIIP ya
--    no apostilla desde el 28-9-2026). La tarjeta y la ficha leen el nombre del diccionario
--    (i18n.js); el del catálogo es el que sale en la pantalla del catálogo del administrador,
--    y no debe decir otra cosa. El ente del c17 no se toca: es una duda del cliente.
--
-- Solo necesita supabase-tramites.sql. Se puede correr más de una vez.

update public.tipos_tramite set ente = 'SAREN'
 where codigo = 'libros_contables' and ente is distinct from 'SAREN';

update public.tipos_tramite set nombre = 'Cédula de identidad de extranjero'
 where codigo = 'cedula_residencia' and nombre is distinct from 'Cédula de identidad de extranjero';

update public.tipos_tramite set nombre = 'Traducción de documentos'
 where codigo = 'apostilla_documentos' and nombre is distinct from 'Traducción de documentos';

-- Comprobar:
--   select codigo, ref_panel, nombre, ente from public.tipos_tramite
--    where codigo in ('libros_contables', 'cedula_residencia', 'apostilla_documentos');
--   -- c24 SAREN; c2 «Cédula de identidad de extranjero»; c17 «Traducción de documentos»
