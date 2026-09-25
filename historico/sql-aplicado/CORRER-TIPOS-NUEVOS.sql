insert into public.tipos_documento (codigo, nombre, vence) values
  ('rif_inversionistas',    'RIF de los inversionistas',                                                 false),
  ('cedulas_junta',         'Cédula de los miembros de la junta directiva',                              false),
  ('rifs_junta',            'RIF de los miembros de la junta directiva',                                 false),
  ('identidad_accionistas', 'Cédula o pasaporte de los accionistas de la empresa a constituir',          false),
  ('juridico_matriz',       'Información jurídica de la empresa matriz',                                 false),
  ('directores_accionista', 'Lista de directores del accionista jurídico, con copia de sus pasaportes',  false),
  ('beneficiarios_finales', 'Lista de accionistas hasta el beneficiario final, con copia de sus pasaportes', false)
on conflict (codigo) do update set nombre = excluded.nombre;

select codigo, nombre from public.tipos_documento
where codigo in ('rif_inversionistas', 'cedulas_junta', 'rifs_junta',
                 'identidad_accionistas', 'juridico_matriz', 'directores_accionista',
                 'beneficiarios_finales', 'constitutivo_accionista', 'good_standing',
                 'recibo_servicio');
