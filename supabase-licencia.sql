-- La licencia de actividades económicas (c10), pedido del CIIP del
-- 28-9-2026: dos importes del día con nombre -'tasa' (la tasa
-- administrativa) y 'timbre' (el timbre fiscal)-, cada uno con su
-- comprobante, y no se resuelve sin los dos comprobantes.
-- Va DESPUÉS de supabase-importe-del-dia.sql y de supabase-marca.sql, de
-- quien usa la guarda de los pasos apuntados. Se puede correr más de una
-- vez. Sin él el panel no se rompe: la escalera se queda en el importe.

do $comprueba$
begin
  if to_regprocedure('public.importe_del_dia_vigente(uuid, text)') is null then
    raise exception 'Falta supabase-importe-del-dia.sql: va antes que éste';
  end if;
  if to_regprocedure('public.pasos_del_ciip_se_quedan()') is null then
    raise exception 'Falta supabase-marca.sql: va antes que éste';
  end if;
end
$comprueba$;

-- Los dos importes van con la solicitud ante la alcaldía. Cuál es cuál lo
-- dice su nombre, y lo cuadra importe_del_dia_vigente(tramite, paso).
insert into public.importe_del_dia_pasos (tipo_tramite, estados)
values ('licencia_municipal', array['ante_el_ente'])
on conflict (tipo_tramite) do update set estados = excluded.estados;

-- Al colgarse un importe o un comprobante con nombre, la base apunta su
-- paso en tramites.datos.pasos_ciip, igual que en la marca: importe_tasa,
-- pago_tasa, importe_timbre, pago_timbre. El primero que llega pone la
-- fecha.
create or replace function public.licencia_apunta_el_papel()
returns trigger
language plpgsql
security definer
set search_path = public
as $licencia$
declare
  papel public.documentos;
  suTipo text;
  clave text;
begin
  select * into papel from public.documentos where id = new.documento;
  select tipo into suTipo from public.tramites where id = new.tramite;
  if suTipo is distinct from 'licencia_municipal' or papel.id is null
     or papel.paso_importe is null then
    return new;
  end if;
  clave := case
    when papel.tipo = 'importe_dia'                                   then 'importe_' || papel.paso_importe
    when papel.tipo = 'pago_importe_dia' and papel.estado <> 'rechazado' then 'pago_' || papel.paso_importe
  end;
  if clave is null then
    return new;
  end if;
  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF')))
   where id = new.tramite
     and not coalesce((datos -> 'pasos_ciip') ? clave, false);
  return new;
end
$licencia$;

drop trigger if exists tramite_documentos_licencia_apunta on public.tramite_documentos;
create trigger tramite_documentos_licencia_apunta
  after insert on public.tramite_documentos
  for each row execute function public.licencia_apunta_el_papel();

-- Un comprobante rechazado deja de contar: su paso vuelve a estar por
-- hacer y el inversionista carga otro.
create or replace function public.licencia_borra_el_pago_rechazado()
returns trigger
language plpgsql
security definer
set search_path = public
as $licencia$
begin
  if new.tipo <> 'pago_importe_dia' or new.paso_importe is null
     or new.estado <> 'rechazado' or old.estado = 'rechazado' then
    return new;
  end if;
  update public.tramites t
     set datos = jsonb_set(t.datos, '{pasos_ciip}',
                           (t.datos -> 'pasos_ciip') - ('pago_' || new.paso_importe))
   where t.tipo = 'licencia_municipal'
     and (t.datos -> 'pasos_ciip') ? ('pago_' || new.paso_importe)
     and t.id in (select td.tramite from public.tramite_documentos td where td.documento = new.id);
  return new;
end
$licencia$;

drop trigger if exists documentos_licencia_pago_rechazado on public.documentos;
create trigger documentos_licencia_pago_rechazado
  after update of estado on public.documentos
  for each row execute function public.licencia_borra_el_pago_rechazado();

-- «Licencia otorgada» va detrás de «Comprobante del pago»: sin los dos
-- comprobantes -tasa y timbre, no rechazados- no se resuelve.
create or replace function public.tramites_licencia_con_pagos()
returns trigger
language plpgsql
security definer
set search_path = public
as $licencia$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'licencia_municipal' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;
  if exists (
    select 1
      from unnest(array['tasa', 'timbre']) as p(paso)
     where not exists (
       select 1
         from public.tramite_documentos td
         join public.documentos d on d.id = td.documento
        where td.tramite = new.id
          and d.tipo = 'pago_importe_dia'
          and d.paso_importe = p.paso
          and d.estado <> 'rechazado'
     )
  ) then
    raise exception 'La licencia no se resuelve sin el comprobante del pago de la tasa administrativa y el del timbre fiscal'
      using errcode = 'check_violation';
  end if;
  return new;
end
$licencia$;

drop trigger if exists tramites_licencia_pagos on public.tramites;
create trigger tramites_licencia_pagos
  before update on public.tramites
  for each row execute function public.tramites_licencia_con_pagos();

-- Los pasos viejos de la c10 (cuatro) escritos desde «Editar textos» se
-- quedarían pisando los nuevos: se van, y mandan los de pasos.js.
delete from public.textos_panel
 where clave like '\_p.pasos.c10.%'
    or clave like '\_p.circuito.c10.%';

-- COMPROBACIÓN
--   select * from public.importe_del_dia_pasos where tipo_tramite = 'licencia_municipal';
--   select tgname from pg_trigger
--    where tgname in ('tramite_documentos_licencia_apunta', 'documentos_licencia_pago_rechazado',
--                     'tramites_licencia_pagos');                              -- tres filas
