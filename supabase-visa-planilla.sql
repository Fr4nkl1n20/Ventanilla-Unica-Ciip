-- Las dos visas (c1 y c38) con la planilla de solicitud (Franklin Reyes,
-- 30-9-2026): el CIIP la manda tras revisar los recaudos, el inversionista
-- la devuelve firmada y sin ella no se presenta ante la Cancillería.
-- Va detrás de supabase-marca.sql y supabase-planilla-firmada.sql. Se
-- puede correr más de una vez.

do $comprueba$
begin
  if to_regprocedure('public.marca_ahora()') is null then
    raise exception 'Falta supabase-marca.sql: va antes que éste';
  end if;
end
$comprueba$;

insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_visa',    'Planilla de solicitud de visa',  false),
  ('planilla_firmada', 'Planilla de solicitud firmada',  false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- La planilla la manda el equipo, validada, y la cuelga de la visa en
-- revisión o ante el ente.
drop policy if exists "documentos: el equipo manda la planilla de la visa" on public.documentos;
create policy "documentos: el equipo manda la planilla de la visa" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_visa' and estado = 'validado');

drop policy if exists "adjuntos: el equipo cuelga la planilla de la visa" on public.tramite_documentos;
create policy "adjuntos: el equipo cuelga la planilla de la visa" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_visa'
         and t.tipo in ('visa_negocios', 'visa_inversionista')
         and t.estado in ('en_revision', 'ante_el_ente')
    )
  );

-- La de supabase-planilla-firmada.sql, con las dos visas en la lista.
drop policy if exists "adjuntos: la planilla firmada, desde su paso" on public.tramite_documentos;
create policy "adjuntos: la planilla firmada, desde su paso" on public.tramite_documentos
  for insert
  with check (
    exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and t.inversionista = auth.uid()
         and d.inversionista = auth.uid()
         and d.tipo = 'planilla_firmada'
         and t.tipo in ('rif_personal', 'rif_empresa', 'licencia_municipal',
                        'visa_negocios', 'visa_inversionista')
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
  );

-- La planilla de la visa solo la hace el equipo.
create or replace function public.visa_planilla_del_ciip()
returns trigger
language plpgsql
as $visa$
begin
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.tipo = 'planilla_visa'
     or (tg_op = 'UPDATE' and old.tipo = 'planilla_visa') then
    raise exception 'Ese papel lo emite el CIIP'
      using errcode = 'check_violation';
  end if;
  return new;
end
$visa$;

drop trigger if exists documentos_visa_planilla_del_ciip on public.documentos;
create trigger documentos_visa_planilla_del_ciip
  before insert or update on public.documentos
  for each row execute function public.visa_planilla_del_ciip();

-- Colgada la planilla, su paso; colgada la firmada (no rechazada), el suyo.
create or replace function public.visa_apunta_la_planilla()
returns trigger
language plpgsql
security definer
set search_path = public
as $visa$
declare
  papel public.documentos;
  suTipo text;
  clave text;
begin
  select * into papel from public.documentos where id = new.documento;
  select tipo into suTipo from public.tramites where id = new.tramite;
  if suTipo is null or suTipo not in ('visa_negocios', 'visa_inversionista') or papel.id is null then
    return new;
  end if;
  clave := case
    when papel.tipo = 'planilla_visa'                                   then 'planilla'
    when papel.tipo = 'planilla_firmada' and papel.estado <> 'rechazado' then 'firmada'
  end;
  if clave is null then
    return new;
  end if;
  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(clave, public.marca_ahora()))
   where id = new.tramite
     and not coalesce((datos -> 'pasos_ciip') ? clave, false);
  return new;
end
$visa$;

drop trigger if exists tramite_documentos_visa_apunta on public.tramite_documentos;
create trigger tramite_documentos_visa_apunta
  after insert on public.tramite_documentos
  for each row execute function public.visa_apunta_la_planilla();

-- Rechazada la firmada, su paso vuelve a estar por hacer, salvo que haya
-- colgada otra que valga.
create or replace function public.visa_borra_la_firmada_rechazada()
returns trigger
language plpgsql
security definer
set search_path = public
as $visa$
begin
  if new.tipo <> 'planilla_firmada' or new.estado <> 'rechazado'
     or old.estado = 'rechazado' then
    return new;
  end if;
  update public.tramites t
     set datos = jsonb_set(t.datos, '{pasos_ciip}', (t.datos -> 'pasos_ciip') - 'firmada')
   where t.tipo in ('visa_negocios', 'visa_inversionista')
     and (t.datos -> 'pasos_ciip') ? 'firmada'
     and t.id in (select td.tramite from public.tramite_documentos td where td.documento = new.id)
     and not exists (
       select 1
         from public.tramite_documentos td2
         join public.documentos d2 on d2.id = td2.documento
        where td2.tramite = t.id
          and d2.id <> new.id
          and d2.tipo = 'planilla_firmada'
          and d2.estado <> 'rechazado');
  return new;
end
$visa$;

drop trigger if exists documentos_visa_firmada_rechazada on public.documentos;
create trigger documentos_visa_firmada_rechazada
  after update of estado on public.documentos
  for each row execute function public.visa_borra_la_firmada_rechazada();

-- Sin la planilla firmada, la visa no pasa a la Cancillería.
create or replace function public.visa_con_planilla_firmada()
returns trigger
language plpgsql
as $visa$
begin
  if auth.uid() is null
     or new.tipo not in ('visa_negocios', 'visa_inversionista')
     or new.estado is distinct from 'ante_el_ente'
     or old.estado = 'ante_el_ente' then
    return new;
  end if;
  if not coalesce((new.datos -> 'pasos_ciip') ? 'firmada', false) then
    raise exception 'Falta la planilla firmada del inversionista'
      using errcode = 'check_violation';
  end if;
  return new;
end
$visa$;

drop trigger if exists tramites_visa_con_planilla_firmada on public.tramites;
create trigger tramites_visa_con_planilla_firmada
  before update on public.tramites
  for each row execute function public.visa_con_planilla_firmada();

-- COMPROBACIÓN
--   select codigo from public.tipos_documento where codigo = 'planilla_visa';          -- una fila
--   select tgname from pg_trigger
--    where tgname in ('tramite_documentos_visa_apunta', 'documentos_visa_firmada_rechazada',
--                     'tramites_visa_con_planilla_firmada', 'documentos_visa_planilla_del_ciip');  -- cuatro
