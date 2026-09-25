-- SQL Editor de Supabase. El SIDCAI en dos tramos (c39 y c40). Se puede correr más de una vez.

-- 1. Mirar: si ya hay algo. Lo normal la primera vez es que no salga nada.
select codigo, ref_panel, activo from public.tipos_tramite
 where codigo in ('aporte_locti', 'aporte_locti_pago');

-- 2. Los tres papeles: el certificado, la planilla del SIDCAI y el comprobante del pago.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('certificado_locti', 'Certificado de solvencia del aporte LOCTI (FONACIT)', true),
  ('planilla_locti',    'Planilla del SIDCAI para pagar el aporte LOCTI',      false),
  ('pago_locti',        'Comprobante del pago del aporte LOCTI',               false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- 3. Los dos tramos.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('aporte_locti',      'c39', 'Inscripción en el SIDCAI (aporte LOCTI)',    'FONACIT', 3, true),
  ('aporte_locti_pago', 'c40', 'Declaración y primer pago del aporte LOCTI', 'FONACIT', 3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite = null, plazo_dias = null, nivel = 'actividad', activo = true
 where codigo = 'aporte_locti';

update public.tipos_tramite
   set emite = 'certificado_locti', plazo_dias = null, nivel = 'actividad', activo = true
 where codigo = 'aporte_locti_pago';

-- 4. El equipo sube la planilla y la engancha al segundo tramo.
drop policy if exists "documentos: el equipo sube la planilla del SIDCAI" on public.documentos;
create policy "documentos: el equipo sube la planilla del SIDCAI" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_locti' and estado = 'validado');

drop policy if exists "adjuntos: el equipo engancha la planilla del SIDCAI" on public.tramite_documentos;
create policy "adjuntos: el equipo engancha la planilla del SIDCAI" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_locti'
         and t.tipo = 'aporte_locti_pago'
         and t.estado in ('enviado','en_revision','ante_el_ente')
    )
  );

-- 5. El inversionista engancha su comprobante con el tramo en marcha.
drop policy if exists "adjuntos: el pago del SIDCAI, con el tramite en marcha" on public.tramite_documentos;
create policy "adjuntos: el pago del SIDCAI, con el tramite en marcha" on public.tramite_documentos
  for insert
  with check (
    exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and t.inversionista = auth.uid()
         and d.inversionista = auth.uid()
         and t.tipo = 'aporte_locti_pago'
         and d.tipo = 'pago_locti'
         and t.estado in ('enviado','en_revision','ante_el_ente')
    )
  );

-- 6. Resuelta la inscripción, nace el segundo tramo con sus datos y su gestor.
create or replace function public.sidcai_abre_el_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  copia jsonb := '{}'::jsonb;
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'aporte_locti' then
    return new;
  end if;
  if not exists (
    select 1 from public.tipos_tramite
     where codigo = 'aporte_locti_pago' and coalesce(activo, true)
  ) then
    return new;
  end if;
  if exists (
    select 1 from public.tramites
     where inversionista = new.inversionista
       and tipo = 'aporte_locti_pago'
  ) then
    return new;
  end if;

  if coalesce(new.datos->>'razon_social', '') <> '' then
    copia := copia || jsonb_build_object('razon_social', new.datos->>'razon_social');
  end if;
  if coalesce(new.datos->>'rif_empresa', '') <> '' then
    copia := copia || jsonb_build_object('rif_empresa', new.datos->>'rif_empresa');
  end if;
  if coalesce(new.datos->>'ingresos_brutos', '') <> '' then
    copia := copia || jsonb_build_object('ingresos_brutos', new.datos->>'ingresos_brutos');
  end if;

  insert into public.tramites (inversionista, tipo, estado, datos, enviado_en, gestor)
  values (new.inversionista, 'aporte_locti_pago', 'enviado', copia, now(), new.gestor);

  return new;
end;
$$;

drop trigger if exists tramites_abre_pago_sidcai on public.tramites;
create trigger tramites_abre_pago_sidcai
  after update on public.tramites
  for each row execute function public.sidcai_abre_el_pago();

-- 7. El segundo tramo no se resuelve sin el comprobante del pago.
create or replace function public.tramites_sidcai_con_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'aporte_locti_pago' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;
  if not exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
     where td.tramite = new.id
       and d.tipo = 'pago_locti'
  ) then
    raise exception 'El primer pago del SIDCAI no se resuelve sin el comprobante del pago del aporte'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists tramites_sidcai_pago on public.tramites;
create trigger tramites_sidcai_pago
  before update on public.tramites
  for each row execute function public.tramites_sidcai_con_pago();

-- 8. Comprobar: dos filas encendidas, c39 sin emite y c40 con certificado_locti.
select ref_panel, codigo, nivel, emite, plazo_dias, activo
  from public.tipos_tramite
 where codigo in ('aporte_locti', 'aporte_locti_pago')
 order by ref_panel;

-- Y tienen que salir tres políticas y dos triggers.
select policyname from pg_policies
 where policyname like '%SIDCAI%' order by policyname;

select tgname from pg_trigger
 where tgname in ('tramites_abre_pago_sidcai', 'tramites_sidcai_pago') order by tgname;
