-- «Recaudos revisados» como botón aparte del gestor (Franklin Reyes, 5-10-2026: «Presentar» se parte
-- en dos). Apunta la fecha en datos.pasos_ciip.recaudos_revisados de una solicitud en revisión.
-- Usa es_gestor() (supabase-tramites.sql). Se puede correr más de una vez.

create or replace function public.marca_recaudos_revisados(p_tramite uuid)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP da los recaudos por revisados';
  end if;

  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object('recaudos_revisados', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF')))
   where id = p_tramite
     and estado = 'en_revision'
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar la revisión';
  end if;

  return fila;
end $$;

revoke all on function public.marca_recaudos_revisados(uuid) from public;
revoke execute on function public.marca_recaudos_revisados(uuid) from anon;
grant execute on function public.marca_recaudos_revisados(uuid) to authenticated;
