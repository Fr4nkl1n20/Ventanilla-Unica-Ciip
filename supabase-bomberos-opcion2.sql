-- Permiso de bomberos como la Taquilla única opción 2 (Franklin Reyes, 1-10-2026): el inversionista
-- lo solicita en el portal de los bomberos y marca dos pasos. Va detrás de supabase-opcion2.sql.
-- Se puede correr más de una vez.

-- Las marcas del botón: las de supabase-opcion2.sql y 'bomberos_solicitado'.
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
                     'bomberos_solicitado') then
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

-- Un paso que pide un dato: guarda lo escrito (no la fecha). Hoy solo la sede de bomberos.
create or replace function public.anota_paso(p_tramite uuid, p_clave text, p_valor text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
  valor text := btrim(coalesce(p_valor, ''));
begin
  if p_clave not in ('sede_bomberos') then
    raise exception 'paso desconocido: %', p_clave;
  end if;
  if valor = '' or char_length(valor) > 200 then
    raise exception 'el dato tiene que tener entre 1 y 200 caracteres';
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb) || jsonb_build_object(p_clave, valor)
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo anotar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.anota_paso(uuid, text, text) from public;
revoke execute on function public.anota_paso(uuid, text, text) from anon;
grant execute on function public.anota_paso(uuid, text, text) to authenticated;

-- Sin importe ni comprobante por el CIIP: deja de exigir el de aranceles para resolverse.
drop trigger if exists tramites_bomberos_pago on public.tramites;

-- Los pasos del c29 escritos a mano desde «Editar textos» taparían los nuevos.
delete from public.textos_panel
 where clave like '\_p.pasos.c29.%' or clave like '\_p.circuito.c29.%';

-- Comprobación: una fila (anota_paso) y ninguna del candado.
select proname from pg_proc where proname = 'anota_paso';
select tgname from pg_trigger where tgname = 'tramites_bomberos_pago';
