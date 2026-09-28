-- La constitución (c5): tras revisar los recaudos, el inversionista viene al
-- CIIP a entregar la carta del comisario, la certificación del inventario o
-- del capital y el inventario, y firma. Lo marca el equipo, y queda en
-- tramites.datos -> 'firma_ciip' con la fecha.
-- Se puede correr más de una vez. Necesita supabase-tramites.sql (es_gestor).

create or replace function public.marca_firma_ciip(p_tramite uuid, p_hecha boolean default true)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if not public.es_gestor() then
    raise exception 'la firma en el CIIP la marca el equipo';
  end if;

  update public.tramites
     set datos = case when p_hecha
                      then coalesce(datos, '{}'::jsonb)
                           || jsonb_build_object('firma_ciip',
                                to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))
                      else coalesce(datos, '{}'::jsonb) - 'firma_ciip'
                 end
   where id = p_tramite
     and tipo = 'constitucion'
     and estado in ('enviado', 'en_revision')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar la firma';
  end if;

  return fila;
end $$;

revoke all on function public.marca_firma_ciip(uuid, boolean) from public;
revoke execute on function public.marca_firma_ciip(uuid, boolean) from anon;
grant execute on function public.marca_firma_ciip(uuid, boolean) to authenticated;

-- La marca es del equipo: el inversionista no la pone escribiendo en datos,
-- y al reenviar un devuelto -que reescribe datos entero- no la borra.
create or replace function public.tramite_firma_la_marca_el_ciip()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() is null
     or current_user <> 'authenticated'
     or public.es_gestor() then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.datos ? 'firma_ciip' then
    new.datos := coalesce(new.datos, '{}'::jsonb)
                 || jsonb_build_object('firma_ciip', old.datos -> 'firma_ciip');
  elsif new.datos ? 'firma_ciip' then
    new.datos := new.datos - 'firma_ciip';
  end if;

  return new;
end $$;

drop trigger if exists tramite_firma_ciip on public.tramites;
create trigger tramite_firma_ciip
  before insert or update on public.tramites
  for each row execute function public.tramite_firma_la_marca_el_ciip();

-- Comprobación: la función y el disparador.
select proname from pg_proc where proname in ('marca_firma_ciip', 'tramite_firma_la_marca_el_ciip');
select tgname from pg_trigger where tgname = 'tramite_firma_ciip';
