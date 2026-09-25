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

do $$
declare c text;
begin
  for c in select conname from pg_constraint
            where conrelid = 'public.tramite_entes'::regclass
              and contype = 'c'
              and pg_get_constraintdef(oid) ilike '%estado%'
  loop
    execute format('alter table public.tramite_entes drop constraint %I', c);
  end loop;
end $$;

alter table public.tramite_entes add constraint tramite_entes_estado_check
  check (estado in ('pendiente', 'inscrito', 'codigo_enviado', 'listo'));

alter table public.tramite_entes alter column estado set default 'pendiente';

create or replace function public.tramite_entes_nacen()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.tipo = 'registros_parafiscales'
     and new.estado in ('enviado', 'en_revision', 'ante_el_ente') then
    insert into public.tramite_entes (tramite, ente, estado)
    select new.id, e, 'pendiente'
      from unnest(array['banavih', 'inces', 'mpppst', 'sundde', 'snc']) as e
    on conflict (tramite, ente) do nothing;
  end if;
  return new;
end $$;

drop trigger if exists tramite_entes_nacen on public.tramites;
create trigger tramite_entes_nacen
  after insert or update of estado on public.tramites
  for each row execute function public.tramite_entes_nacen();

drop policy if exists "entes: el inversionista corrige su codigo" on public.tramite_entes;
create policy "entes: el inversionista corrige su codigo" on public.tramite_entes
  for update
  using (
    estado in ('inscrito', 'codigo_enviado')
    and exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
  )
  with check (
    estado = 'codigo_enviado'
    and exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
    and (documento is null or exists (
      select 1 from public.documentos d
       where d.id = tramite_entes.documento and d.inversionista = auth.uid()
    ))
  );

insert into public.tramite_entes (tramite, ente, estado)
select t.id, e, 'pendiente'
  from public.tramites t
  cross join unnest(array['banavih', 'inces', 'mpppst', 'sundde', 'snc']) as e
 where t.tipo = 'registros_parafiscales'
   and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
on conflict (tramite, ente) do nothing;

select estado, count(*)
  from public.tramite_entes
 group by estado
 order by estado;

select t.id, t.estado, count(e.ente) as entes
  from public.tramites t
  left join public.tramite_entes e on e.tramite = t.id
 where t.tipo = 'registros_parafiscales'
 group by t.id, t.estado
 order by t.id;
