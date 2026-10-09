-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL REGISTRO DE MARCA POR ETAPAS (c8)
--  Va DESPUÉS de supabase-importe-del-dia.sql. Se puede correr más de una
--  vez. Sin él el panel no se rompe: la escalera de la marca se queda
--  quieta en el paso en que esté.
-- ═══════════════════════════════════════════════════════════════════════

do $comprueba$
begin
  if to_regprocedure('public.importe_del_dia_vigente(uuid, text)') is null then
    raise exception 'Falta supabase-importe-del-dia.sql: va antes que éste';
  end if;
end
$comprueba$;

-- Los dos papeles que el CIIP le manda al inversionista por el camino.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('busqueda_antecedentes', 'Búsqueda de antecedentes de la marca', false),
  ('certificado_marca',     'Certificado de registro de marca',     false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- Cuál de los cuatro importes toca lo dice la escalera; aquí basta con el
-- estado, y el nombre de cada importe lo cuadra
-- importe_del_dia_vigente(tramite, paso). Desde el 8-10-2026 (Franklin
-- Reyes) el de la búsqueda de antecedentes se sube ANTES de presentarla,
-- con la solicitud recibida o en revisión, y la búsqueda empieza con su
-- comprobante: por eso valen los tres estados.
insert into public.importe_del_dia_pasos (tipo_tramite, estados)
values ('marca', array['enviado', 'en_revision', 'ante_el_ente'])
on conflict (tipo_tramite) do update set estados = excluded.estados;

-- El equipo sube los dos papeles, ya validados, a la bóveda del
-- inversionista, y los cuelga de SU solicitud de marca.
drop policy if exists "documentos: el equipo manda los papeles de la marca" on public.documentos;
create policy "documentos: el equipo manda los papeles de la marca" on public.documentos
  for insert
  with check (public.es_gestor()
              and tipo in ('busqueda_antecedentes', 'certificado_marca')
              and estado = 'validado');

drop policy if exists "adjuntos: el equipo cuelga los papeles de la marca" on public.tramite_documentos;
create policy "adjuntos: el equipo cuelga los papeles de la marca" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and t.tipo = 'marca'
         and d.tipo in ('busqueda_antecedentes', 'certificado_marca')
    )
  );

-- Esos dos los emite el CIIP: el inversionista no los crea ni convierte
-- otro papel en ellos. Y el nombre del importe al que paga un comprobante
-- no lo cambia después de colgarlo.
create or replace function public.marca_papeles_del_ciip()
returns trigger
language plpgsql
as $marca$
begin
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.tipo in ('busqueda_antecedentes', 'certificado_marca')
     or (tg_op = 'UPDATE' and old.tipo in ('busqueda_antecedentes', 'certificado_marca')) then
    raise exception 'Ese papel lo emite el CIIP'
      using errcode = 'check_violation';
  end if;
  if tg_op = 'UPDATE' then
    new.paso_importe := old.paso_importe;
  end if;
  return new;
end
$marca$;

drop trigger if exists documentos_marca_del_ciip on public.documentos;
create trigger documentos_marca_del_ciip
  before insert or update on public.documentos
  for each row execute function public.marca_papeles_del_ciip();

-- LOS PASOS APUNTADOS. Viven en tramites.datos: pasos_ciip (nombre →
-- fecha), anuncio y anuncio_en. Quien no es del equipo no los toca, ni
-- siquiera al reenviar el formulario de una devuelta, que reescribe datos
-- entero: se le devuelven los que había. Las funciones de abajo son
-- security definer y escriben como su dueño, no como 'authenticated'.
create or replace function public.pasos_del_ciip_se_quedan()
returns trigger
language plpgsql
as $marca$
declare
  guarda jsonb;
begin
  if auth.uid() is null
     or current_user <> 'authenticated'
     or public.es_gestor() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.datos := coalesce(new.datos, '{}'::jsonb) - 'pasos_ciip' - 'anuncio' - 'anuncio_en';
    return new;
  end if;
  guarda := jsonb_strip_nulls(jsonb_build_object(
    'pasos_ciip', old.datos -> 'pasos_ciip',
    'anuncio',    old.datos -> 'anuncio',
    'anuncio_en', old.datos -> 'anuncio_en'));
  new.datos := (coalesce(new.datos, '{}'::jsonb) - 'pasos_ciip' - 'anuncio' - 'anuncio_en') || guarda;
  return new;
end
$marca$;

drop trigger if exists tramites_pasos_del_ciip on public.tramites;
create trigger tramites_pasos_del_ciip
  before insert or update on public.tramites
  for each row execute function public.pasos_del_ciip_se_quedan();

-- La hora, escrita como la escribe confirma_paso().
create or replace function public.marca_ahora()
returns text
language sql
stable
as $$ select to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF') $$;

-- Al colgarse un papel de una marca, la base apunta su paso: el importe y
-- el comprobante de cada etapa por su nombre, y los dos papeles del CIIP.
-- Una vez: el primero que llega pone la fecha.
create or replace function public.marca_apunta_el_papel()
returns trigger
language plpgsql
security definer
set search_path = public
as $marca$
declare
  papel public.documentos;
  suTipo text;
  clave text;
begin
  select * into papel from public.documentos where id = new.documento;
  select tipo into suTipo from public.tramites where id = new.tramite;
  if suTipo is distinct from 'marca' or papel.id is null then
    return new;
  end if;
  clave := case
    when papel.tipo = 'importe_dia'      and papel.paso_importe is not null then 'importe_' || papel.paso_importe
    when papel.tipo = 'pago_importe_dia' and papel.paso_importe is not null
         and papel.estado <> 'rechazado'                                  then 'pago_' || papel.paso_importe
    when papel.tipo = 'busqueda_antecedentes'                             then 'busqueda'
    when papel.tipo = 'certificado_marca'                                 then 'certificado'
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
$marca$;

drop trigger if exists tramite_documentos_marca_apunta on public.tramite_documentos;
create trigger tramite_documentos_marca_apunta
  after insert on public.tramite_documentos
  for each row execute function public.marca_apunta_el_papel();

-- Un comprobante rechazado deja de contar: su paso vuelve a estar por
-- hacer, y el inversionista puede cargar otro.
create or replace function public.marca_borra_el_pago_rechazado()
returns trigger
language plpgsql
security definer
set search_path = public
as $marca$
begin
  if new.tipo <> 'pago_importe_dia' or new.paso_importe is null
     or new.estado <> 'rechazado' or old.estado = 'rechazado' then
    return new;
  end if;
  update public.tramites t
     set datos = jsonb_set(t.datos, '{pasos_ciip}',
                           (t.datos -> 'pasos_ciip') - ('pago_' || new.paso_importe))
   where t.tipo = 'marca'
     and (t.datos -> 'pasos_ciip') ? ('pago_' || new.paso_importe)
     and t.id in (select td.tramite from public.tramite_documentos td where td.documento = new.id);
  return new;
end
$marca$;

drop trigger if exists documentos_marca_pago_rechazado on public.documentos;
create trigger documentos_marca_pago_rechazado
  after update of estado on public.documentos
  for each row execute function public.marca_borra_el_pago_rechazado();

-- Los dos pasos que marca el gestor, cada uno en su sitio: «Solicitud en
-- proceso ante el SAPI» con la FM-02 pagada, y «Marca en proceso de
-- registro» con aquél cerrado y, si hubo contestación, pagada. Revienta si
-- no tocó ninguna fila: una política que falta no da error, cambia cero.
create or replace function public.marca_paso_ciip(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $marca$
declare
  fila public.tramites;
begin
  if not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP marca estos pasos';
  end if;
  if p_clave not in ('sapi', 'en_registro') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(p_clave, public.marca_ahora()))
   where id = p_tramite
     and tipo = 'marca'
     and estado = 'ante_el_ente'
     and not coalesce((datos -> 'pasos_ciip') ? p_clave, false)
     and (
          (p_clave = 'sapi' and coalesce((datos -> 'pasos_ciip') ? 'pago_fm02', false))
       or (p_clave = 'en_registro'
           and coalesce((datos -> 'pasos_ciip') ? 'sapi', false)
           and (not coalesce((datos -> 'pasos_ciip') ? 'contestacion', false)
                or coalesce((datos -> 'pasos_ciip') ? 'pago_contestacion', false)))
     )
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;
  return fila;
end
$marca$;

-- La contestación: el gestor la habilita con un anuncio que explica qué
-- pasó, y abre los dos pasos del importe de la contestación. La marca SE
-- QUEDA en «Solicitud en proceso ante el SAPI» -si estaba marcado, se
-- reabre- mientras se resuelve la devolución o la oposición; el gestor lo
-- cierra con marca_paso_ciip('sapi') cuando queda resuelta, y solo
-- entonces sigue el importe (Franklin Reyes, 9-10-2026; antes se daba por
-- cerrado al habilitar). El anuncio entra además en el chat de la
-- contestación, que suena en la campana del inversionista, y en los
-- avisos por correo.
alter table public.avisos drop constraint if exists avisos_motivo_valido;
alter table public.avisos add constraint avisos_motivo_valido
  check (motivo in ('cambio_estado', 'documento_vence', 'anuncio'));

create or replace function public.habilita_contestacion(p_tramite uuid, p_anuncio text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $marca$
declare
  fila   public.tramites;
  texto  text := btrim(coalesce(p_anuncio, ''));
  ahora  text := public.marca_ahora();
  correo text;
  suPais text;
begin
  if not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP habilita la contestación';
  end if;
  if texto = '' or char_length(texto) > 2000 then
    raise exception 'El anuncio tiene que decir algo, y en menos de 2000 caracteres';
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(
                      'pasos_ciip', (coalesce(datos -> 'pasos_ciip', '{}'::jsonb) - 'sapi')
                                    || jsonb_build_object('contestacion', ahora),
                      'anuncio', texto,
                      'anuncio_en', ahora)
   where id = p_tramite
     and tipo = 'marca'
     and estado = 'ante_el_ente'
     and coalesce((datos -> 'pasos_ciip') ? 'pago_fm02', false)
     and not coalesce((datos -> 'pasos_ciip') ? 'en_registro', false)
     and not coalesce((datos -> 'pasos_ciip') ? 'contestacion', false)
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo habilitar la contestación';
  end if;

  -- El anuncio abre el chat de la contestación (supabase-chat-del-paso.sql,
  -- 9-10-2026): es su primer mensaje.
  insert into public.tramite_mensajes (tramite, texto, paso) values (p_tramite, texto, 'contestacion');

  select u.email into correo from auth.users u where u.id = fila.inversionista;
  select p.pais  into suPais from public.perfiles p where p.id = fila.inversionista;
  if correo is not null and correo <> '' then
    insert into public.avisos (tramite, destinatario, pais, motivo, nota)
    values (p_tramite, correo, coalesce(suPais, ''), 'anuncio', texto);
  end if;

  return fila;
end
$marca$;

revoke all on function public.marca_paso_ciip(uuid, text) from public;
revoke execute on function public.marca_paso_ciip(uuid, text) from anon;
grant execute on function public.marca_paso_ciip(uuid, text) to authenticated;
revoke all on function public.habilita_contestacion(uuid, text) from public;
revoke execute on function public.habilita_contestacion(uuid, text) from anon;
grant execute on function public.habilita_contestacion(uuid, text) to authenticated;

-- Y no se resuelve sin el certificado enviado: el último paso le dice al
-- inversionista que vaya a retirar los originales.
create or replace function public.marca_con_certificado()
returns trigger
language plpgsql
as $marca$
begin
  if auth.uid() is null
     or new.tipo is distinct from 'marca'
     or new.estado is distinct from 'resuelto'
     or old.estado = 'resuelto' then
    return new;
  end if;
  if not coalesce((new.datos -> 'pasos_ciip') ? 'certificado', false) then
    raise exception 'Falta el certificado de registro de la marca'
      using errcode = 'check_violation';
  end if;
  return new;
end
$marca$;

drop trigger if exists tramites_marca_con_certificado on public.tramites;
create trigger tramites_marca_con_certificado
  before update on public.tramites
  for each row execute function public.marca_con_certificado();

-- COMPROBACIÓN
--   select codigo from public.tipos_documento
--    where codigo in ('busqueda_antecedentes', 'certificado_marca');     -- dos filas
--   select estados from public.importe_del_dia_pasos where tipo_tramite = 'marca';
--   select proname from pg_proc
--    where proname in ('marca_paso_ciip', 'habilita_contestacion');     -- dos filas
