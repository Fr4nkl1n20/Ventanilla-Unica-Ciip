insert into public.tipos_documento (codigo, nombre, vence) values
  ('cedula_apoderado',        'Cédula de identidad del apoderado',                   false),
  ('rif_apoderado',           'RIF del apoderado',                                   false),
  ('carta_solicitud_empresa', 'Carta de solicitud de la empresa',                    false),
  ('planilla_visa',           'Planilla de solicitud de la visa',                    false),
  ('solvencia_economica',     'Solvencia económica (constancia de trabajo)',         true),
  ('carta_residencia',        'Carta de residencia',                                 false),
  ('declaracion_fondos',      'Declaración jurada de origen de fondos',              false),
  ('apostilla_previa',        'Apostilla o legalización que ya tiene el documento',  false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

update public.tipos_documento
   set nombre = 'Contrato de servicios o constancia que acredite la dirección fiscal'
 where codigo = 'domicilio_empresa';

update public.tipos_tramite
   set activo = false
 where codigo in ('licencia_conducir', 'cert_medico');

create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
grant execute on function public.confirma_paso(uuid, text) to authenticated;

select codigo, nombre, vence
  from public.tipos_documento
 where codigo in ('cedula_apoderado', 'rif_apoderado', 'carta_solicitud_empresa',
                  'planilla_visa', 'solvencia_economica', 'carta_residencia',
                  'declaracion_fondos', 'apostilla_previa', 'domicilio_empresa')
 order by codigo;

select codigo, ref_panel, nombre, activo
  from public.tipos_tramite
 where codigo in ('licencia_conducir', 'cert_medico');

select routine_name, security_type
  from information_schema.routines
 where routine_schema = 'public' and routine_name = 'confirma_paso';
