insert into public.tipos_documento (codigo, nombre, vence) values
  ('constancia_ente', 'Constancia de inscripción ante el ente', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

drop policy if exists "documentos: el equipo entrega la constancia del ente" on public.documentos;
create policy "documentos: el equipo entrega la constancia del ente" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'constancia_ente' and estado = 'validado');

drop policy if exists "adjuntos: el equipo cuelga la constancia del ente" on public.tramite_documentos;
create policy "adjuntos: el equipo cuelga la constancia del ente" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1 from public.documentos d
       where d.id = documento and d.tipo = 'constancia_ente'
    )
  );

do $$
declare c text;
begin
  for c in select conname from pg_constraint
            where conrelid = 'public.tramite_entes'::regclass
              and contype = 'c'
              and pg_get_constraintdef(oid) ilike '%ente%'
              and pg_get_constraintdef(oid) not ilike '%estado%'
  loop
    execute format('alter table public.tramite_entes drop constraint %I', c);
  end loop;
end $$;

alter table public.tramite_entes add constraint tramite_entes_ente_check
  check (ente in ('banavih', 'inces', 'mpppst', 'sundde', 'ivss', 'snc'));

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
      from unnest(array['banavih', 'inces', 'mpppst', 'sundde', 'ivss', 'snc']) as e
    on conflict (tramite, ente) do nothing;
  end if;
  return new;
end $$;

insert into public.tramite_entes (tramite, ente, estado)
select t.id, e, 'pendiente'
  from public.tramites t
  cross join unnest(array['banavih', 'inces', 'mpppst', 'sundde', 'ivss', 'snc']) as e
 where t.tipo = 'registros_parafiscales'
   and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
on conflict (tramite, ente) do nothing;

alter table public.tramites drop constraint if exists tramites_estado_valido;
alter table public.tramites add constraint tramites_estado_valido
  check (estado in ('borrador', 'enviado', 'en_revision', 'devuelto',
                    'ante_el_ente', 'resuelto', 'cancelado'));

create or replace function public.tramites_solo_la_escalera()
returns trigger
language plpgsql
as $$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;

  if auth.uid() is null then
    return new;
  end if;

  if not (
       (old.estado = 'borrador'     and new.estado = 'enviado')
    or (old.estado = 'devuelto'     and new.estado = 'enviado')
    or (old.estado = 'enviado'      and new.estado in ('en_revision','devuelto'))
    or (old.estado = 'en_revision'  and new.estado in ('ante_el_ente','devuelto'))
    or (old.estado = 'ante_el_ente' and new.estado in ('resuelto','devuelto'))
    or (old.estado in ('borrador','enviado','en_revision','devuelto')
        and new.estado = 'cancelado')
  ) then
    raise exception 'Un trámite no pasa de "%" a "%"', old.estado, new.estado
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create or replace function public.cancela_tramite(p_tramite uuid)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  update public.tramites
     set estado = 'cancelado'
   where id = p_tramite
     and inversionista = auth.uid()
     and estado in ('borrador', 'enviado', 'en_revision', 'devuelto')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo cancelar';
  end if;

  return fila;
end $$;

revoke all on function public.cancela_tramite(uuid) from public;
grant execute on function public.cancela_tramite(uuid) to authenticated;

select codigo, nombre from public.tipos_documento where codigo = 'constancia_ente';

select pg_get_constraintdef(oid) as entes_permitidos
  from pg_constraint
 where conrelid = 'public.tramite_entes'::regclass
   and conname = 'tramite_entes_ente_check';

select pg_get_constraintdef(oid) as estados_permitidos
  from pg_constraint
 where conrelid = 'public.tramites'::regclass
   and conname = 'tramites_estado_valido';

select t.id, t.estado, count(e.ente) as entes
  from public.tramites t
  left join public.tramite_entes e on e.tramite = t.id
 where t.tipo = 'registros_parafiscales'
 group by t.id, t.estado
 order by t.id;
