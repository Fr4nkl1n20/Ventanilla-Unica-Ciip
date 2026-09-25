insert into public.tipos_documento (codigo, nombre, vence) values
  ('identidad_accionistas', 'Cédula o pasaporte de los accionistas de la empresa a constituir',          false),
  ('juridico_matriz',       'Información jurídica de la empresa matriz',                                 false),
  ('directores_accionista', 'Lista de directores del accionista jurídico, con copia de sus pasaportes',  false),
  ('beneficiarios_finales', 'Lista de accionistas hasta el beneficiario final, con copia de sus pasaportes', false)
on conflict (codigo) do update set nombre = excluded.nombre;

select codigo, nombre, vence from public.tipos_documento
where codigo in ('identidad_accionistas', 'juridico_matriz', 'directores_accionista',
                 'beneficiarios_finales', 'constitutivo_accionista', 'good_standing');
