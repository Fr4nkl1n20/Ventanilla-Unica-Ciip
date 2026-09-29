-- El sellado de libros (c24), pedido del CIIP del 29-9-2026: «Revisión de
-- recaudos → Consignación de libros en el CIIP → Solicitud introducida ante
-- el SAREN → Emisión de PUB por SAREN → Comprobante de pago de PUB → Libros
-- sellados». El PUB es un importe del día con nombre, 'pub', con su
-- comprobante, y no se resuelve sin él.
-- Va DESPUÉS de supabase-importe-del-dia.sql y de supabase-marca.sql. Se
-- puede correr más de una vez. Sin él el panel no se rompe: la escalera se
-- queda en el PUB.

-- Los pasos viejos (tres) escritos a mano desde «Editar textos» pisarían
-- los nuevos: se van.
delete from public.textos_panel
 where clave like '\_p.pasos.c24.%'
    or clave like '\_p.circuito.c24.%';

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


-- El PUB, con la solicitud ante el SAREN.
insert into public.importe_del_dia_pasos (tipo_tramite, estados)
values ('libros_contables', array['ante_el_ente'])
on conflict (tipo_tramite) do update set estados = excluded.estados;

-- Al colgarse el importe o el comprobante, la base apunta su paso en
-- tramites.datos.pasos_ciip: importe_pub, pago_pub.
create or replace function public.libros_apunta_el_papel()
returns trigger
language plpgsql
security definer
set search_path = public
as $libros$
declare
  papel public.documentos;
  suTipo text;
  clave text;
begin
  select * into papel from public.documentos where id = new.documento;
  select tipo into suTipo from public.tramites where id = new.tramite;
  if suTipo is distinct from 'libros_contables' or papel.id is null
     or papel.paso_importe is null then
    return new;
  end if;
  clave := case
    when papel.tipo = 'importe_dia'                                      then 'importe_' || papel.paso_importe
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
$libros$;

drop trigger if exists tramite_documentos_libros_apunta on public.tramite_documentos;
create trigger tramite_documentos_libros_apunta
  after insert on public.tramite_documentos
  for each row execute function public.libros_apunta_el_papel();

-- Un comprobante rechazado deja de contar: su paso vuelve a estar por hacer.
create or replace function public.libros_borra_el_pago_rechazado()
returns trigger
language plpgsql
security definer
set search_path = public
as $libros$
begin
  if new.tipo <> 'pago_importe_dia' or new.paso_importe is null
     or new.estado <> 'rechazado' or old.estado = 'rechazado' then
    return new;
  end if;
  update public.tramites t
     set datos = jsonb_set(t.datos, '{pasos_ciip}',
                           (t.datos -> 'pasos_ciip') - ('pago_' || new.paso_importe))
   where t.tipo = 'libros_contables'
     and (t.datos -> 'pasos_ciip') ? ('pago_' || new.paso_importe)
     and t.id in (select td.tramite from public.tramite_documentos td where td.documento = new.id);
  return new;
end
$libros$;

drop trigger if exists documentos_libros_pago_rechazado on public.documentos;
create trigger documentos_libros_pago_rechazado
  after update of estado on public.documentos
  for each row execute function public.libros_borra_el_pago_rechazado();

-- «Libros sellados» va detrás del comprobante del PUB: sin él no se resuelve.
create or replace function public.tramites_libros_con_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $libros$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'libros_contables' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;
  if not exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
     where td.tramite = new.id
       and d.tipo = 'pago_importe_dia'
       and d.paso_importe = 'pub'
       and d.estado <> 'rechazado'
  ) then
    raise exception 'El sellado de libros no se resuelve sin el comprobante de pago del PUB'
      using errcode = 'check_violation';
  end if;
  return new;
end
$libros$;

drop trigger if exists tramites_libros_pago on public.tramites;
create trigger tramites_libros_pago
  before update on public.tramites
  for each row execute function public.tramites_libros_con_pago();

-- COMPROBACIÓN
--   select * from public.importe_del_dia_pasos where tipo_tramite = 'libros_contables';
--   select tgname from pg_trigger
--    where tgname in ('tramite_documentos_libros_apunta', 'documentos_libros_pago_rechazado',
--                     'tramites_libros_pago');                              -- tres filas

-- ── El PUB no caduca (29-9-2026) ──
-- «Nosotros somos los que enviamos el PUB y él nos reenvía el comprobante,
-- como en constitución de empresa»: el PUB del SAREN no vence a medianoche
-- como el importe del día. Una columna en importe_del_dia_pasos lo dice por
-- trámite, y importe_del_dia_vigente la mira: con ella, vale el último
-- importe colgado aunque sea de otro día. Los demás trámites, igual.
alter table public.importe_del_dia_pasos
  add column if not exists sin_caducidad boolean not null default false;

update public.importe_del_dia_pasos set sin_caducidad = true
 where tipo_tramite = 'libros_contables';

create or replace function public.importe_del_dia_vigente(p_tramite uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
      join public.tramites t   on t.id = td.tramite
     where td.tramite = p_tramite
       and d.tipo = 'importe_dia'
       and d.estado = 'validado'
       and d.inversionista = t.inversionista
       and ((d.creado_en at time zone 'America/Caracas')::date = public.hoy_en_caracas()
            or exists (select 1 from public.importe_del_dia_pasos p
                        where p.tipo_tramite = t.tipo and p.sin_caducidad))
  )
$$;

create or replace function public.importe_del_dia_vigente(p_tramite uuid, p_paso text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
      join public.tramites t   on t.id = td.tramite
     where td.tramite = p_tramite
       and d.tipo = 'importe_dia'
       and d.estado = 'validado'
       and d.inversionista = t.inversionista
       and d.paso_importe is not distinct from p_paso
       and ((d.creado_en at time zone 'America/Caracas')::date = public.hoy_en_caracas()
            or exists (select 1 from public.importe_del_dia_pasos p
                        where p.tipo_tramite = t.tipo and p.sin_caducidad))
  )
$$;

-- COMPROBACIÓN
--   select tipo_tramite, sin_caducidad from public.importe_del_dia_pasos;   -- libros_contables: true
