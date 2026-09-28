-- El tercer paso de la constitución se escribió encima del de todos los
-- trámites. Desde el 27-9-2026 la constitución lo trae en pasos.js
-- (circuito.c5), así que el cambio de la base sobra y se borra.

delete from public.textos_panel
 where clave = '_p.estados.2'
   and (texto ilike '%PUB%' or texto ilike '%reserva%');

-- Lo que quede cambiado en los pasos, para mirarlo.
select clave, idioma, texto, actualizado_en
  from public.textos_panel
 where clave like '\_p.estados.%' or clave like '\_p.circuito.%'
 order by clave, idioma;
