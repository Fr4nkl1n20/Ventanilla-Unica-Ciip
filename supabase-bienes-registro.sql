-- CIIP · Ventanilla Única — la compraventa (c41) en dos fases: contrato y registro (Franklin Reyes, 5-10-2026).
-- Va DESPUÉS de supabase-importe-del-dia.sql, supabase-marca.sql, supabase-libros.sql y supabase-bienes.sql.
-- Se puede correr más de una vez.

do $comprueba$
begin
  if to_regprocedure('public.pasos_del_ciip_se_quedan()') is null then
    raise exception 'Falta supabase-marca.sql: va antes que éste';
  end if;
  if not exists (select 1 from information_schema.columns
                  where table_name = 'importe_del_dia_pasos' and column_name = 'sin_caducidad') then
    raise exception 'Falta supabase-libros.sql: va antes que éste';
  end if;
end
$comprueba$;

delete from public.textos_panel
 where clave like '\_p.pasos.c41.%'
    or clave like '\_p.circuito.c41.%';

insert into public.tipos_documento (codigo, nombre, vence) values
  ('contrato_compraventa', 'Contrato de compraventa', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- El contrato lo manda el equipo, ya validado, colgado de la compraventa.
drop policy if exists "documentos: el equipo manda el contrato de compraventa" on public.documentos;
create policy "documentos: el equipo manda el contrato de compraventa" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'contrato_compraventa' and estado = 'validado');

drop policy if exists "adjuntos: el equipo cuelga el contrato de compraventa" on public.tramite_documentos;
create policy "adjuntos: el equipo cuelga el contrato de compraventa" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and t.tipo = 'bienes_compraventa'
         and d.tipo = 'contrato_compraventa'
    )
  );

create or replace function public.compraventa_contrato_del_ciip()
returns trigger
language plpgsql
as $cv$
begin
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.tipo = 'contrato_compraventa'
     or (tg_op = 'UPDATE' and old.tipo = 'contrato_compraventa') then
    raise exception 'Ese papel lo emite el CIIP'
      using errcode = 'check_violation';
  end if;
  return new;
end
$cv$;

drop trigger if exists documentos_compraventa_del_ciip on public.documentos;
create trigger documentos_compraventa_del_ciip
  before insert or update on public.documentos
  for each row execute function public.compraventa_contrato_del_ciip();

-- Los dos importes, con la solicitud ante el ente. El PUB no caduca; el timbre fiscal sí.
alter table public.importe_del_dia_pasos
  add column if not exists pasos_sin_caducidad text[] not null default '{}';

insert into public.importe_del_dia_pasos (tipo_tramite, estados, sin_caducidad, pasos_sin_caducidad)
values ('bienes_compraventa', array['ante_el_ente'], false, array['pub'])
on conflict (tipo_tramite) do update
  set estados = excluded.estados,
      sin_caducidad = excluded.sin_caducidad,
      pasos_sin_caducidad = excluded.pasos_sin_caducidad;

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
                        where p.tipo_tramite = t.tipo
                          and (p.sin_caducidad or d.paso_importe = any(p.pasos_sin_caducidad))))
  )
$$;

-- Al colgarse el contrato, un importe o un comprobante, la base apunta su paso.
create or replace function public.compraventa_apunta_el_papel()
returns trigger
language plpgsql
security definer
set search_path = public
as $cv$
declare
  papel public.documentos;
  suTipo text;
  clave text;
begin
  select * into papel from public.documentos where id = new.documento;
  select tipo into suTipo from public.tramites where id = new.tramite;
  if suTipo is distinct from 'bienes_compraventa' or papel.id is null then
    return new;
  end if;
  clave := case
    when papel.tipo = 'importe_dia'      and papel.paso_importe is not null then 'importe_' || papel.paso_importe
    when papel.tipo = 'pago_importe_dia' and papel.paso_importe is not null
         and papel.estado <> 'rechazado'                                  then 'pago_' || papel.paso_importe
    when papel.tipo = 'contrato_compraventa'                              then 'contrato'
  end;
  if clave is null then
    return new;
  end if;
  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(clave, public.marca_ahora()))
   where id = new.tramite
     and not coalesce((datos -> 'pasos_ciip') ? clave, false);
  return new;
end
$cv$;

drop trigger if exists tramite_documentos_compraventa_apunta on public.tramite_documentos;
create trigger tramite_documentos_compraventa_apunta
  after insert on public.tramite_documentos
  for each row execute function public.compraventa_apunta_el_papel();

create or replace function public.compraventa_borra_el_pago_rechazado()
returns trigger
language plpgsql
security definer
set search_path = public
as $cv$
begin
  if new.tipo <> 'pago_importe_dia' or new.paso_importe is null
     or new.estado <> 'rechazado' or old.estado = 'rechazado' then
    return new;
  end if;
  update public.tramites t
     set datos = jsonb_set(t.datos, '{pasos_ciip}',
                           (t.datos -> 'pasos_ciip') - ('pago_' || new.paso_importe))
   where t.tipo = 'bienes_compraventa'
     and (t.datos -> 'pasos_ciip') ? ('pago_' || new.paso_importe)
     and t.id in (select td.tramite from public.tramite_documentos td where td.documento = new.id);
  return new;
end
$cv$;

drop trigger if exists documentos_compraventa_pago_rechazado on public.documentos;
create trigger documentos_compraventa_pago_rechazado
  after update of estado on public.documentos
  for each row execute function public.compraventa_borra_el_pago_rechazado();

-- Los tres pasos que marca el gestor, cada uno detrás del anterior.
create or replace function public.compraventa_paso_ciip(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $cv$
declare
  fila public.tramites;
begin
  if not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP marca estos pasos';
  end if;
  if p_clave not in ('redaccion', 'introduccion', 'registrador') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(p_clave, public.marca_ahora()))
   where id = p_tramite
     and tipo = 'bienes_compraventa'
     and estado = 'ante_el_ente'
     and not coalesce((datos -> 'pasos_ciip') ? p_clave, false)
     and (
          p_clave = 'redaccion'
       or (p_clave = 'introduccion' and coalesce((datos -> 'pasos_ciip') ? 'contrato', false))
       or (p_clave = 'registrador'  and coalesce((datos -> 'pasos_ciip') ? 'introduccion', false))
     )
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;
  return fila;
end
$cv$;

-- La fecha de la firma, con el timbre pagado. Se puede cambiar hasta resolver.
create or replace function public.compraventa_fecha_firma(p_tramite uuid, p_dia date)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $cv$
declare
  fila public.tramites;
begin
  if not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP pone la fecha de la firma';
  end if;
  if p_dia is null then
    raise exception 'Falta la fecha de la firma';
  end if;

  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(
                                'firma', coalesce(datos -> 'pasos_ciip' ->> 'firma', public.marca_ahora()),
                                'firma_dia', to_char(p_dia, 'YYYY-MM-DD')))
   where id = p_tramite
     and tipo = 'bienes_compraventa'
     and estado = 'ante_el_ente'
     and coalesce((datos -> 'pasos_ciip') ? 'pago_timbre', false)
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo poner la fecha de la firma';
  end if;
  return fila;
end
$cv$;

-- Un aviso del CIIP en mitad del registro: lo que observe o pida el Registrador. Destacado en el trámite,
-- en la conversación y por correo, como la contestación de la marca. Se puede mandar más de uno.
create or replace function public.anuncio_del_ciip(p_tramite uuid, p_anuncio text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $cv$
declare
  fila   public.tramites;
  texto  text := btrim(coalesce(p_anuncio, ''));
  correo text;
  suPais text;
begin
  if not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP manda avisos';
  end if;
  if texto = '' or char_length(texto) > 2000 then
    raise exception 'El aviso tiene que decir algo, y en menos de 2000 caracteres';
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object('anuncio', texto, 'anuncio_en', public.marca_ahora())
   where id = p_tramite
     and tipo = 'bienes_compraventa'
     and estado = 'ante_el_ente'
     and coalesce((datos -> 'pasos_ciip') ? 'introduccion', false)
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo mandar el aviso';
  end if;

  insert into public.tramite_mensajes (tramite, texto) values (p_tramite, texto);

  select u.email into correo from auth.users u where u.id = fila.inversionista;
  select p.pais  into suPais from public.perfiles p where p.id = fila.inversionista;
  if correo is not null and correo <> '' then
    insert into public.avisos (tramite, destinatario, pais, motivo, nota)
    values (p_tramite, correo, coalesce(suPais, ''), 'anuncio', texto);
  end if;

  return fila;
end
$cv$;

revoke all on function public.compraventa_paso_ciip(uuid, text) from public;
revoke execute on function public.compraventa_paso_ciip(uuid, text) from anon;
grant execute on function public.compraventa_paso_ciip(uuid, text) to authenticated;
revoke all on function public.compraventa_fecha_firma(uuid, date) from public;
revoke execute on function public.compraventa_fecha_firma(uuid, date) from anon;
grant execute on function public.compraventa_fecha_firma(uuid, date) to authenticated;
revoke all on function public.anuncio_del_ciip(uuid, text) from public;
revoke execute on function public.anuncio_del_ciip(uuid, text) from anon;
grant execute on function public.anuncio_del_ciip(uuid, text) to authenticated;

-- «Documento protocolizado» va detrás de la fecha de la firma: sin ella no se resuelve.
create or replace function public.tramites_compraventa_con_firma()
returns trigger
language plpgsql
security definer
set search_path = public
as $cv$
begin
  if new.estado is not distinct from old.estado
     or new.estado <> 'resuelto' or new.tipo <> 'bienes_compraventa'
     or auth.uid() is null then
    return new;
  end if;
  if not coalesce((new.datos -> 'pasos_ciip') ? 'firma_dia', false) then
    raise exception 'La compraventa no se resuelve sin la fecha de la firma'
      using errcode = 'check_violation';
  end if;
  return new;
end
$cv$;

drop trigger if exists tramites_compraventa_firma on public.tramites;
create trigger tramites_compraventa_firma
  before update on public.tramites
  for each row execute function public.tramites_compraventa_con_firma();

-- COMPROBACIÓN
--   select tipo_tramite, sin_caducidad, pasos_sin_caducidad from public.importe_del_dia_pasos
--    where tipo_tramite = 'bienes_compraventa';                             -- {pub}
--   select proname from pg_proc
--    where proname in ('compraventa_paso_ciip', 'compraventa_fecha_firma', 'anuncio_del_ciip');  -- tres filas
--   select tgname from pg_trigger
--    where tgname in ('tramite_documentos_compraventa_apunta', 'documentos_compraventa_pago_rechazado',
--                     'tramites_compraventa_firma', 'documentos_compraventa_del_ciip');           -- cuatro filas
