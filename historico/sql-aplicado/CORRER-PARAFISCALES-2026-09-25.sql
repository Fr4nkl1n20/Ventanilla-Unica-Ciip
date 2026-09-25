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

select codigo, nombre from public.tipos_documento where codigo = 'constancia_ente';

select policyname, cmd from pg_policies
 where policyname in ('documentos: el equipo entrega la constancia del ente',
                      'adjuntos: el equipo cuelga la constancia del ente');

select pg_get_constraintdef(oid) as entes_permitidos
  from pg_constraint
 where conrelid = 'public.tramite_entes'::regclass
   and conname = 'tramite_entes_ente_check';

select t.id, t.estado, count(e.ente) as entes
  from public.tramites t
  left join public.tramite_entes e on e.tramite = t.id
 where t.tipo = 'registros_parafiscales'
 group by t.id, t.estado
 order by t.id;
