-- Inscripción en el SIDCAI (c39) por el portal (Franklin Reyes, 1-10-2026, Ventanilla Única 2.3): el
-- inversionista se inscribe en el FONACIT y lo marca con «Ya me inscribí». Va detrás de
-- supabase-cedula-opcion2.sql. Se puede correr más de una vez.

-- Las marcas del botón: las de supabase-cedula-opcion2.sql (con 'saime_confirmada') y 'locti_inscrito'.
create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                     'bomberos_solicitado', 'saime_confirmada', 'locti_inscrito') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;

-- Los pasos del c39 escritos a mano desde «Editar textos» taparían los nuevos.
delete from public.textos_panel
 where clave like '\_p.pasos.c39.%' or clave like '\_p.circuito.c39.%';

-- Comprobación: una fila, true en las dos si confirma_paso ya acepta la cédula y el LOCTI.
select position('locti_inscrito' in pg_get_functiondef('public.confirma_paso(uuid, text)'::regprocedure)) > 0
       as acepta_locti_inscrito,
       position('saime_confirmada' in pg_get_functiondef('public.confirma_paso(uuid, text)'::regprocedure)) > 0
       as acepta_saime_confirmada;
