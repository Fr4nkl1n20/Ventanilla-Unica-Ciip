insert into public.tipos_documento (codigo, nombre, vence) values
  ('apostilla_previa', 'Apostilla o legalización que ya tiene el documento', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

select codigo, nombre, vence
  from public.tipos_documento
 where codigo = 'apostilla_previa';
