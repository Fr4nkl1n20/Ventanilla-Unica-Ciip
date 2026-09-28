-- El registro de importador y exportador (c11, VUCE) se va del catálogo
-- (pedido del CIIP, 28-9-2026: «Eliminar»). Se apaga y no se borra: las
-- solicitudes que ya existan son de este tipo y la fila es lo que las
-- nombra. Nadie puede pedir una nueva de un tipo apagado.
-- Se puede correr más de una vez.

update public.tipos_tramite
   set activo = false
 where codigo = 'comercio_exterior';

-- Comprobación: apagado, y cuántas solicitudes viejas hay.
select codigo, ref_panel, nombre, activo
  from public.tipos_tramite
 where codigo = 'comercio_exterior';

select estado, count(*)
  from public.tramites
 where tipo = 'comercio_exterior'
 group by estado;
