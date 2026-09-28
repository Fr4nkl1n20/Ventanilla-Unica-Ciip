-- El permiso de bomberos (c29), pedido del CIIP del 28-9-2026: su escalera
-- es «Revisión de recaudos → Permiso otorgado», y la escriben pasos.js. Los
-- tres recaudos nuevos -cédula o pasaporte y RIF del representante legal,
-- documento constitutivo- son tipos que ya existen (cedula, rif_personal,
-- acta_constitutiva): no hace falta crear ninguno.
-- Se puede correr más de una vez.

-- Los pasos viejos (cuatro) o un rótulo de estado escrito a mano para la
-- c29 desde «Editar textos» pisarían los nuevos: se van.
delete from public.textos_panel
 where clave like '\_p.pasos.c29.%'
    or clave like '\_p.circuito.c29.%';

-- Comprobación: ninguna fila.
select clave from public.textos_panel
 where clave like '\_p.pasos.c29.%' or clave like '\_p.circuito.c29.%';
