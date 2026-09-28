-- La conformidad de uso (c28), pedido del CIIP del 28-9-2026: los recaudos
-- que pide el SIGAT de la alcaldía y su escalera propia, «Revisión de
-- recaudos → Inscripción ante el ente → Emitida certificación de
-- conformidad de uso». Se puede correr más de una vez.

-- Los tres papeles nuevos. El título o arrendamiento (titulo_inmueble) y el
-- plano (plano_local) ya existían. Sin estas filas el panel no los pide.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('cedula_catastral',     'Cédula catastral del inmueble',                     false),
  ('permiso_construccion', 'Permiso de construcción o conformidad ocupacional', false),
  ('fotos_local',          'Fotografías internas y externas del local',         false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- Los pasos viejos (cuatro) o un rótulo de estado escrito a mano para la
-- c28 desde «Editar textos» pisarían los nuevos: se van, y mandan los de
-- pasos.js.
delete from public.textos_panel
 where clave like '\_p.pasos.c28.%'
    or clave like '\_p.circuito.c28.%';

-- Comprobación: tres filas, y ningún texto de la c28.
select codigo, nombre from public.tipos_documento
 where codigo in ('cedula_catastral', 'permiso_construccion', 'fotos_local');
select clave from public.textos_panel
 where clave like '\_p.pasos.c28.%' or clave like '\_p.circuito.c28.%';
