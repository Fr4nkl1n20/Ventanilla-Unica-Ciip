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

select pg_get_constraintdef(oid) as estados_permitidos
  from pg_constraint
 where conrelid = 'public.tramites'::regclass
   and conname = 'tramites_estado_valido';

select routine_name
  from information_schema.routines
 where routine_schema = 'public'
   and routine_name in ('cancela_tramite', 'tramites_solo_la_escalera')
 order by routine_name;
