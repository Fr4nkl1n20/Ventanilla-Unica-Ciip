-- Taquilla única, opción 2 (Franklin Reyes, 1-10-2026): el inversionista se registra él mismo en el
-- portal de cada ente y marca que lo hizo. Va detrás de supabase-qa-tramites.sql. Se puede correr más de una vez.

-- Las marcas que el inversionista puede poner con su botón.
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
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado') then
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

-- La visa ya no lleva planilla del CIIP ni firmada: fuera sus disparadores y las políticas de la planilla.
drop trigger if exists tramites_visa_con_planilla_firmada on public.tramites;
drop function if exists public.visa_con_planilla_firmada();
drop trigger if exists tramite_documentos_visa_apunta on public.tramite_documentos;
drop function if exists public.visa_apunta_la_planilla();
drop trigger if exists documentos_visa_firmada_rechazada on public.documentos;
drop function if exists public.visa_borra_la_firmada_rechazada();
drop policy if exists "documentos: el equipo manda la planilla de la visa" on public.documentos;
drop policy if exists "adjuntos: el equipo cuelga la planilla de la visa" on public.tramite_documentos;

-- La licencia ya no lleva importes de tasa y timbre: deja de exigir sus comprobantes para resolverse.
drop trigger if exists tramites_licencia_pagos on public.tramites;

-- Los pasos de estos cinco trámites escritos a mano desde «Editar textos» taparían los nuevos.
delete from public.textos_panel
 where clave like '\_p.pasos.c1.%'  or clave like '\_p.circuito.c1.%'
    or clave like '\_p.pasos.c38.%' or clave like '\_p.circuito.c38.%'
    or clave like '\_p.pasos.c10.%' or clave like '\_p.circuito.c10.%'
    or clave like '\_p.pasos.c28.%' or clave like '\_p.circuito.c28.%'
    or clave like '\_p.pasos.c36.%' or clave like '\_p.circuito.c36.%';

-- Comprobación: ninguna fila (los dos candados quitados).
select tgname from pg_trigger
 where tgname in ('tramites_visa_con_planilla_firmada', 'tramites_licencia_pagos');
