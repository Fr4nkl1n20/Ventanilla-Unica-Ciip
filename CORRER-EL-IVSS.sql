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
select t.id, 'ivss', 'pendiente'
  from public.tramites t
 where t.tipo = 'registros_parafiscales'
   and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
on conflict (tramite, ente) do nothing;

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
