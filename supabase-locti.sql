-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL SIDCAI, EN DOS TRAMOS (c39 y c40)
--  Va DESPUÉS de supabase-visa-tri.sql. Necesita el catálogo con `nivel` y
--  `emite`, tramites, documentos y es_gestor(). Se puede correr más de una
--  vez.
-- ═══════════════════════════════════════════════════════════════════════
--  Del encargo del 23 de septiembre de 2026: la ficha del SIDCAI -el
--  sistema del FONACIT para declarar el aporte de la LOCTI- «en permisos
--  sectoriales», y que trabaje «parecido a como trabaja la constitución».
--  Se eligió el molde de la constitución con SOLO EL PRIMER PAGO:
--
--    c39  Inscripción en el SIDCAI. La pide el inversionista, con sus
--         recaudos. No emite nada.
--    c40  Declaración y primer pago. Nace sola al resolverse la c39, en
--         manos del mismo gestor y con la razón social, el RIF y los
--         ingresos copiados. El equipo deja la planilla que genera el
--         SIDCAI, el inversionista paga en el banco y sube el comprobante;
--         sin él no se resuelve. Emite el certificado de solvencia.
--
--  Los pagos de los meses siguientes -quince días tras cada mes,
--  Providencia 015-004-2024- NO pasan por la ventanilla. Por eso la c40 se
--  crea una sola vez por inversionista, como la protocolización.
--
--  'actividad' y no 'esencial': sólo le toca a quien ingresó el año
--  anterior más de 150.000 veces el tipo de cambio oficial del BCV (LOCTI,
--  G.O. Ext. 6.693 de 2022, arts. 30 a 32). Sin plazo: ninguno de los dos
--  tiene uno publicado.
--
--  La política del comprobante va aparte y no dentro de «adjuntos: papeles
--  de un paso, con el tramite en marcha» (supabase-reserva-nombre.sql):
--  las políticas se suman, y así este archivo no reescribe la de otro.
-- ═══════════════════════════════════════════════════════════════════════

insert into public.tipos_documento (codigo, nombre, vence) values
  ('certificado_locti', 'Certificado de solvencia del aporte LOCTI (FONACIT)', true),
  ('planilla_locti',    'Planilla del SIDCAI para pagar el aporte LOCTI',      false),
  ('pago_locti',        'Comprobante del pago del aporte LOCTI',               false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

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
