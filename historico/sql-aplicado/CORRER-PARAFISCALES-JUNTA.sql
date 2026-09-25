insert into public.tipos_documento (codigo, nombre, vence) values
  ('rif_inversionistas', 'RIF de los inversionistas',                      false),
  ('cedulas_junta',      'Cédula de los miembros de la junta directiva',   false),
  ('rifs_junta',         'RIF de los miembros de la junta directiva',      false)
on conflict (codigo) do update set nombre = excluded.nombre;

select codigo, nombre, vence from public.tipos_documento
where codigo in ('rif_inversionistas', 'cedulas_junta', 'rifs_junta');
