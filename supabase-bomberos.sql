-- El permiso de bomberos (c29), pedido del CIIP del 28-9-2026: su escalera
-- es «Revisión de recaudos → Permiso otorgado», y la escriben pasos.js. Los
-- tres recaudos nuevos -cédula o pasaporte y RIF del representante legal,
-- documento constitutivo- son tipos que ya existen (cedula, rif_personal,
-- acta_constitutiva): no hace falta crear ninguno.
-- Se puede correr más de una vez.

-- Los pasos viejos (cuatro) o un rótulo de estado escrito a mano para la
-- c29 desde «Editar textos» pisarían los nuevos: se van.
delete from public.textos_panel
 where clave like '\_p.pasos.c29.%'
    or clave like '\_p.circuito.c29.%';

-- Comprobación: ninguna fila.
select clave from public.textos_panel
 where clave like '\_p.pasos.c29.%' or clave like '\_p.circuito.c29.%';

-- ── 29-9-2026: dos recaudos y el importe de aranceles con su comprobante ──
-- Va DESPUÉS de supabase-importe-del-dia.sql y de supabase-marca.sql. Sin
-- esto el panel no se rompe: el plano de seguridad no se pide y la escalera
-- se queda en el importe.

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

-- El plano de seguridad es un papel nuevo. El contrato de arrendamiento o
-- título de propiedad (titulo_inmueble) ya existía.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('plano_seguridad', 'Plano a escala 1:50 demarcando los sistemas de seguridad', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- El importe de aranceles, con la solicitud ante los bomberos.
insert into public.importe_del_dia_pasos (tipo_tramite, estados)
values ('permiso_bomberos', array['ante_el_ente'])
on conflict (tipo_tramite) do update set estados = excluded.estados;

-- Al colgarse el importe o el comprobante, la base apunta su paso en
-- tramites.datos.pasos_ciip: importe_aranceles, pago_aranceles.
create or replace function public.bomberos_apunta_el_papel()
returns trigger
language plpgsql
security definer
set search_path = public
as $bomberos$
declare
  papel public.documentos;
  suTipo text;
  clave text;
begin
  select * into papel from public.documentos where id = new.documento;
  select tipo into suTipo from public.tramites where id = new.tramite;
  if suTipo is distinct from 'permiso_bomberos' or papel.id is null
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
$bomberos$;

drop trigger if exists tramite_documentos_bomberos_apunta on public.tramite_documentos;
create trigger tramite_documentos_bomberos_apunta
  after insert on public.tramite_documentos
  for each row execute function public.bomberos_apunta_el_papel();

-- Un comprobante rechazado deja de contar: su paso vuelve a estar por hacer.
create or replace function public.bomberos_borra_el_pago_rechazado()
returns trigger
language plpgsql
security definer
set search_path = public
as $bomberos$
begin
  if new.tipo <> 'pago_importe_dia' or new.paso_importe is null
     or new.estado <> 'rechazado' or old.estado = 'rechazado' then
    return new;
  end if;
  update public.tramites t
     set datos = jsonb_set(t.datos, '{pasos_ciip}',
                           (t.datos -> 'pasos_ciip') - ('pago_' || new.paso_importe))
   where t.tipo = 'permiso_bomberos'
     and (t.datos -> 'pasos_ciip') ? ('pago_' || new.paso_importe)
     and t.id in (select td.tramite from public.tramite_documentos td where td.documento = new.id);
  return new;
end
$bomberos$;

drop trigger if exists documentos_bomberos_pago_rechazado on public.documentos;
create trigger documentos_bomberos_pago_rechazado
  after update of estado on public.documentos
  for each row execute function public.bomberos_borra_el_pago_rechazado();

-- «Permiso otorgado» va detrás del comprobante: sin él no se resuelve.
create or replace function public.tramites_bomberos_con_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $bomberos$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'permiso_bomberos' then
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
       and d.paso_importe = 'aranceles'
       and d.estado <> 'rechazado'
  ) then
    raise exception 'El permiso de bomberos no se resuelve sin el comprobante de pago de aranceles'
      using errcode = 'check_violation';
  end if;
  return new;
end
$bomberos$;

drop trigger if exists tramites_bomberos_pago on public.tramites;
create trigger tramites_bomberos_pago
  before update on public.tramites
  for each row execute function public.tramites_bomberos_con_pago();

-- COMPROBACIÓN
--   select codigo from public.tipos_documento where codigo = 'plano_seguridad';     -- una fila
--   select * from public.importe_del_dia_pasos where tipo_tramite = 'permiso_bomberos';
--   select tgname from pg_trigger
--    where tgname in ('tramite_documentos_bomberos_apunta', 'documentos_bomberos_pago_rechazado',
--                     'tramites_bomberos_pago');                              -- tres filas
