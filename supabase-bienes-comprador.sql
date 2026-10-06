-- CIIP · Ventanilla Única — los recaudos del comprador en la compraventa (c41)
-- Franklin Reyes, 5-10-2026. Se puede correr más de una vez.

insert into public.tipos_documento (codigo, nombre, vence) values
  ('acta_comprador',          'Acta constitutiva del comprador',                    false),
  ('rif_comprador',           'RIF del comprador',                                  false),
  ('identidad_rep_comprador', 'Cédula y RIF del representante legal del comprador', false),
  ('asamblea_comprador',      'Última acta de asamblea del comprador',              false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- COMPROBACIÓN
--   select codigo, nombre, vence from public.tipos_documento
--    where codigo in ('acta_comprador', 'rif_comprador',
--                     'identidad_rep_comprador', 'asamblea_comprador');   -- cuatro filas
