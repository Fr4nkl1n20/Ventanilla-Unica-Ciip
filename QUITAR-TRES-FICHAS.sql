-- SQL Editor de Supabase. Mira antes de borrar.

-- 1. Cuantas solicitudes hay de las tres. Si sale vacio, no hay ninguna.
select tipo, count(*) as solicitudes
  from public.tramites
 where tipo in ('antecedentes_penales', 'constancia_domicilio', 'visa_dependientes')
 group by tipo;

-- 2. Se apagan siempre: sin tarjeta en el panel, activas no sirven de nada.
update public.tipos_tramite set activo = false
 where codigo in ('antecedentes_penales', 'constancia_domicilio', 'visa_dependientes');

-- 3. Y se borran del catalogo SOLO si nadie tiene una. Con solicitudes de
--    por medio, la fila se queda apagada y el expediente sigue legible.
delete from public.tipos_tramite
 where codigo in ('antecedentes_penales', 'constancia_domicilio', 'visa_dependientes')
   and not exists (
     select 1 from public.tramites t where t.tipo = tipos_tramite.codigo
   );

-- 4. Comprobar: las que queden salen aqui, con su activo.
select codigo, ref_panel, activo
  from public.tipos_tramite
 where codigo in ('antecedentes_penales', 'constancia_domicilio', 'visa_dependientes');
