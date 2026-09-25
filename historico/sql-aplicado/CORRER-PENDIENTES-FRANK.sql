-- SQL Editor de Supabase. Se puede correr mas de una vez.

-- 1. Los siete tipos de documento que piden los recaudos nuevos de
--    Pendientes FRANK.pdf. Ninguno caduca salvo la solvencia, que es una
--    constancia de trabajo y envejece.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('cedula_apoderado',        'Cédula de identidad del apoderado',            false),
  ('rif_apoderado',           'RIF del apoderado',                            false),
  ('carta_solicitud_empresa', 'Carta de solicitud de la empresa',             false),
  ('planilla_visa',           'Planilla de solicitud de la visa',             false),
  ('solvencia_economica',     'Solvencia económica (constancia de trabajo)',  true),
  ('carta_residencia',        'Carta de residencia',                          false),
  ('declaracion_fondos',      'Declaración jurada de origen de fondos',       false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- 2. Y el domicilio de la empresa pasa a pedir lo que de verdad se pide.
update public.tipos_documento
   set nombre = 'Contrato de servicios o constancia que acredite la dirección fiscal'
 where codigo = 'domicilio_empresa';

-- 3. Comprobar: tienen que salir las ocho filas.
select codigo, nombre, vence
  from public.tipos_documento
 where codigo in ('cedula_apoderado', 'rif_apoderado', 'carta_solicitud_empresa',
                  'planilla_visa', 'solvencia_economica', 'carta_residencia',
                  'declaracion_fondos', 'domicilio_empresa')
 order by codigo;
