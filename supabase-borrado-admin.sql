-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL ADMINISTRADOR BORRA LO DE LAS PRUEBAS
--  Va al FINAL: redefine tres cerrojos de archivos anteriores
--  (mensaje_no_se_toca de supabase-hilo.sql, papel_en_marcha_no_se_borra
--  de supabase-qa-tramites.sql y autorizacion_no_se_toca de
--  supabase-autorizaciones.sql) y la regla de fuentes de la bitácora
--  (la última, de supabase-seguridad-octubre.sql). Usa es_admin()
--  (supabase-qa-admin.sql), apunta() (supabase-bitacora.sql) y
--  archivos_huerfanos (supabase-setup.sql).
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 15-10-2026: «que desde administrador pueda borrar
--  trámites realizados y documentos», «trámites realizados por nosotros,
--  que estamos realizando pruebas: es para no tocar la base siempre».
--  Hasta hoy, limpiar una cuenta de pruebas era correr a mano un
--  BORRAR-*.sql en el SQL Editor. Decidido con él: las dos formas -una
--  solicitud o un papel sueltos, y vaciar una cuenta entera- y de
--  CUALQUIER cuenta, sin marca de «cuenta de prueba». La guarda contra el
--  error la pone el panel, con su confirmación.
--
--  LA PUERTA DEL BORRADO
--  ─────────────────────────────────────────────────────────────────────
--  Tres cerrojos dejan borrar solo con la puerta de servicio -auth.uid()
--  nulo, el SQL Editor-: los mensajes, que no se cambian ni se borran; las
--  autorizaciones aceptadas; y el papel de una solicitud en marcha. Desde
--  el panel hay un usuario, y el borrado en cascada de una solicitud se
--  topaba con los tres.
--
--  Las tres funciones de aquí abren otra puerta, la del borrado del
--  administrador: un ajuste de la transacción, 'ciip.borrado_admin', que
--  ponen con set_config(..., true) DESPUÉS de comprobar es_admin() y que
--  se apaga solo al terminar. Nadie más lo puede poner: PostgREST solo
--  deja fijar ajustes request.*, y set_config no está a la vista de la
--  API. Y la puerta es SOLO para borrar: un mensaje sigue sin poderse
--  cambiar, lo pida quien lo pida.
--
--  EL ARCHIVO DEL CUBO
--  ─────────────────────────────────────────────────────────────────────
--  Al borrar un papel, el trigger lo apunta en archivos_huerfanos para el
--  barrendero. Pero el barrendero no corre en producción: el archivo se
--  quedaría en el cubo para siempre. Así que las funciones devuelven las
--  rutas, el panel las quita con la API de Storage -el administrador
--  puede borrar en 'recaudos', política nueva- y marca_barridos() deja
--  constancia en archivos_huerfanos. Si el cubo no las acepta, siguen
--  'pendiente' y el barrendero las encuentra donde siempre.
--
--  QUÉ SE LLEVA CADA UNA
--  ─────────────────────────────────────────────────────────────────────
--  · borra_solicitud(id): la solicitud y lo que cuelga de ella por
--    cascade -eventos, enganches con papeles, cola, avisos, órdenes de
--    pago, mensajes, autorización, entes-. Los papeles de la bóveda se
--    quedan: son del inversionista, no de la solicitud.
--  · borra_documento(id): el papel. Devuelve su ruta en el cubo.
--  · vacia_cuenta(usuario): todas sus solicitudes y todos sus papeles. La
--    cuenta, su perfil, su empresa, sus citas y sus consultas se quedan.
--    Devuelve las rutas de los archivos.
--  Las tres dejan rastro en la bitácora: el papel, por el trigger de
--  siempre ('papeles', 'borro'), con el administrador como autor; la
--  solicitud y la cuenta, con la fuente nueva 'borrados'.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA PUERTA
-- ───────────────────────────────────────────────────────────────────────
create or replace function public.borrado_de_admin()
returns boolean
language sql
stable
as $$
  select coalesce(current_setting('ciip.borrado_admin', true), '') = 'si';
$$;

revoke all on function public.borrado_de_admin() from public;
revoke execute on function public.borrado_de_admin() from anon;
grant execute on function public.borrado_de_admin() to authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LOS TRES CERROJOS, CON LA PUERTA DEL BORRADO
-- ───────────────────────────────────────────────────────────────────────
-- Iguales a los de sus archivos, más una línea: tg_op = 'DELETE' y la
-- puerta abierta.

create or replace function public.mensaje_no_se_toca()
returns trigger
language plpgsql
as $hilo$
begin
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' and public.borrado_de_admin() then
    return old;
  end if;
  raise exception 'Un mensaje no se cambia ni se borra. Escribe otro.'
    using errcode = 'check_violation';
end
$hilo$;

create or replace function public.papel_en_marcha_no_se_borra()
returns trigger
language plpgsql
security definer
set search_path = public
as $qa$
begin
  if auth.uid() is null or public.borrado_de_admin() then
    return old;   -- la puerta de servicio, o la del borrado del administrador
  end if;
  if exists (
    select 1
      from public.tramite_documentos td
      join public.tramites t on t.id = td.tramite
     where td.documento = old.id
       and t.estado not in ('borrador', 'devuelto', 'cancelado')
  ) then
    raise exception 'Ese documento va en una solicitud en marcha: no se borra'
      using errcode = 'check_violation';
  end if;
  return old;
end
$qa$;

create or replace function public.autorizacion_no_se_toca()
returns trigger
language plpgsql
as $aut$
begin
  -- La puerta de servicio (SQL Editor) y la revocación, que solo pone
  -- la fecha a una que no la tenía.
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' and public.borrado_de_admin() then
    return old;
  end if;
  if tg_op = 'UPDATE'
     and old.revocada_en is null and new.revocada_en is not null
     and (to_jsonb(new) - 'revocada_en') = (to_jsonb(old) - 'revocada_en') then
    return new;
  end if;
  raise exception 'Una autorización aceptada no se cambia ni se borra: se revoca.'
    using errcode = 'check_violation';
end
$aut$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA BITÁCORA ACEPTA 'borrados'
-- ───────────────────────────────────────────────────────────────────────
alter table public.bitacora drop constraint if exists bitacora_fuente_valida;
alter table public.bitacora add constraint bitacora_fuente_valida
  check (fuente in ('catalogo','roles','papeles','citas',
                    'textos','activos','acompanamiento','entes','borrados'));


-- ───────────────────────────────────────────────────────────────────────
-- 4. EL ADMINISTRADOR PUEDE QUITAR ARCHIVOS DEL CUBO
-- ───────────────────────────────────────────────────────────────────────
-- Leer ya podía: «recaudos: leer su carpeta» deja al equipo. La API de
-- Storage pide las dos para borrar.
drop policy if exists "recaudos: el administrador borra" on storage.objects;
create policy "recaudos: el administrador borra" on storage.objects
  for delete to authenticated
  using (bucket_id = 'recaudos' and public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 5. LAS TRES FUNCIONES
-- ───────────────────────────────────────────────────────────────────────
create or replace function public.borra_solicitud(p_tramite uuid)
returns void
language plpgsql
security definer
set search_path = public
as $bo$
declare
  v_nombre text;
  v_correo text;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede borrar solicitudes'
      using errcode = 'insufficient_privilege';
  end if;

  select coalesce(tt.nombre, t.tipo), coalesce(u.email, '')
    into v_nombre, v_correo
    from public.tramites t
    left join public.tipos_tramite tt on tt.codigo = t.tipo
    left join auth.users u on u.id = t.inversionista
   where t.id = p_tramite;
  if not found then
    raise exception 'Esa solicitud ya no existe'
      using errcode = 'no_data_found';
  end if;

  perform set_config('ciip.borrado_admin', 'si', true);
  delete from public.tramites where id = p_tramite;
  perform public.apunta('borrados', 'solicitud', v_nombre, v_correo);
end
$bo$;

create or replace function public.borra_documento(p_documento uuid)
returns text
language plpgsql
security definer
set search_path = public
as $bo$
declare
  v_ruta text;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede borrar documentos'
      using errcode = 'insufficient_privilege';
  end if;

  perform set_config('ciip.borrado_admin', 'si', true);
  delete from public.documentos where id = p_documento
  returning archivo into v_ruta;
  if not found then
    raise exception 'Ese documento ya no existe'
      using errcode = 'no_data_found';
  end if;
  return v_ruta;
end
$bo$;

create or replace function public.vacia_cuenta(p_usuario uuid)
returns setof text
language plpgsql
security definer
set search_path = public
as $bo$
declare
  v_correo text;
  v_solicitudes int;
  v_papeles int;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede vaciar una cuenta'
      using errcode = 'insufficient_privilege';
  end if;

  select coalesce(email, '') into v_correo from auth.users where id = p_usuario;
  if not found then
    raise exception 'Esa cuenta no existe'
      using errcode = 'no_data_found';
  end if;

  perform set_config('ciip.borrado_admin', 'si', true);
  delete from public.tramites where inversionista = p_usuario;
  get diagnostics v_solicitudes = row_count;

  return query
    with fuera as (
      delete from public.documentos where inversionista = p_usuario
      returning archivo
    )
    select archivo from fuera where coalesce(archivo, '') <> '';
  get diagnostics v_papeles = row_count;

  -- Las cuentas, no una frase: el panel las dice en el idioma de quien mira.
  perform public.apunta('borrados', 'cuenta', v_correo,
                        json_build_object('solicitudes', v_solicitudes, 'papeles', v_papeles)::text);
end
$bo$;

-- Y la constancia de que el panel quitó los archivos del cubo. Solo las
-- rutas que el panel consiguió borrar; las demás siguen 'pendiente'.
create or replace function public.marca_barridos(p_rutas text[])
returns integer
language plpgsql
security definer
set search_path = public
as $bo$
declare
  n integer;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador'
      using errcode = 'insufficient_privilege';
  end if;
  update public.archivos_huerfanos
     set estado = 'barrido', barrido_en = now(), ultimo_error = null
   where cubo = 'recaudos'
     and ruta = any(coalesce(p_rutas, '{}'))
     and estado <> 'barrido';
  get diagnostics n = row_count;
  return n;
end
$bo$;

revoke all on function public.borra_solicitud(uuid) from public;
revoke execute on function public.borra_solicitud(uuid) from anon;
grant execute on function public.borra_solicitud(uuid) to authenticated;
revoke all on function public.borra_documento(uuid) from public;
revoke execute on function public.borra_documento(uuid) from anon;
grant execute on function public.borra_documento(uuid) to authenticated;
revoke all on function public.vacia_cuenta(uuid) from public;
revoke execute on function public.vacia_cuenta(uuid) from anon;
grant execute on function public.vacia_cuenta(uuid) to authenticated;
revoke all on function public.marca_barridos(text[]) from public;
revoke execute on function public.marca_barridos(text[]) from anon;
grant execute on function public.marca_barridos(text[]) to authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Las cuatro funciones están, y solo las ejecuta authenticated:
--
--   select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon,
--          has_function_privilege('authenticated', p.oid, 'execute') as auth
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public'
--     and p.proname in ('borra_solicitud','borra_documento','vacia_cuenta','marca_barridos');
--
-- 2) La política nueva del cubo:
--
--   select policyname from pg_policies
--   where schemaname = 'storage' and policyname = 'recaudos: el administrador borra';
--
-- 3) La bitácora acepta 'borrados':
--
--   select pg_get_constraintdef(oid) from pg_constraint
--   where conname = 'bitacora_fuente_valida';
