-- ═══════════════════════════════════════════════════════════════════════
--  AUDITORÍA DE SEGURIDAD, SEGUNDA PASADA (8-10-2026)
-- ═══════════════════════════════════════════════════════════════════════
--  Lo que salió al revisar lo que entró desde la primera (25-9-2026) y
--  que se arregla en la base. Va el último de juntar-sql.js porque toca
--  tablas y funciones de muchos archivos anteriores. Se puede correr las
--  veces que haga falta.
--
--  1 · Las contraseñas del IVSS y del INCES dejan de leerse en bloque.
--  2 · Dos papeles más que solo emite el CIIP.
--  3 · Dos funciones del equipo, cerradas también a anon.
--
--  Fuera de aquí, en sus archivos de siempre: es_gestor() y es_admin()
--  ya no se pisan al volver a correr supabase-tramites.sql o
--  supabase-admin.sql, las políticas del cubo de supabase-papeles-
--  sellados.sql llevan el bloqueo, gasta_uso_ia() es la misma en sus tres
--  archivos (traductor: 60 por hora) y el candado de la traducción no
--  acepta un comprobante rechazado.
-- ═══════════════════════════════════════════════════════════════════════


-- ── 1 · LAS CONTRASEÑAS DE LOS ENTES ──────────────────────────────────
-- tramite_entes.clave guarda en claro la contraseña que el inversionista
-- crea en el portal del IVSS o del INCES, para que el CIIP entre por él.
-- La política de lectura es la de la tabla entera: cualquiera del equipo
-- podía bajarse todas las contraseñas pendientes de una vez
-- (tramite_entes?select=clave&clave=not.is.null), o quien le robara la
-- sesión a uno.
--
-- Ahora la columna no la lee nadie con sesión (ni el propio inversionista,
-- que la escribió y no la necesita de vuelta). El equipo la pide de una en
-- una con clave_del_ente(), y cada vez queda en la bitácora quién la vio.
-- La cola compartida de «Códigos enviados» sigue igual: cualquiera del
-- equipo despacha cualquier expediente, solo que ahora deja rastro.
--
-- tiene_clave dice si hay contraseña sin enseñarla: es lo que la pantalla
-- necesita para poner el botón de verla.

alter table public.tramite_entes
  add column if not exists tiene_clave boolean
  generated always as (clave is not null) stored;

-- Permiso de lectura por columnas: todas menos la contraseña. OJO: una
-- columna que se añada a tramite_entes en el futuro NO tendrá permiso de
-- lectura hasta que se vuelva a correr este archivo.
do $cols$
declare
  c record;
begin
  revoke select on public.tramite_entes from authenticated;
  for c in select column_name from information_schema.columns
            where table_schema = 'public' and table_name = 'tramite_entes'
              and column_name <> 'clave'
  loop
    execute format('grant select (%I) on public.tramite_entes to authenticated', c.column_name);
  end loop;
end
$cols$;

-- La bitácora acepta la fuente nueva.
alter table public.bitacora drop constraint if exists bitacora_fuente_valida;
alter table public.bitacora add constraint bitacora_fuente_valida
  check (fuente in ('catalogo','roles','papeles','citas',
                    'textos','activos','acompanamiento','entes'));

create or replace function public.clave_del_ente(p_tramite uuid, p_ente text)
returns text
language plpgsql
security definer
set search_path = public
as $clave$
declare
  la_clave text;
  de_quien text;
begin
  if auth.uid() is null or not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP ve estas contraseñas'
      using errcode = 'insufficient_privilege';
  end if;

  select e.clave, coalesce(p.nombre_completo, '')
    into la_clave, de_quien
    from public.tramite_entes e
    join public.tramites t on t.id = e.tramite
    left join public.perfiles p on p.id = t.inversionista
   where e.tramite = p_tramite and e.ente = p_ente;

  -- Solo se apunta si había algo que ver.
  if la_clave is not null then
    perform public.apunta('entes', 'vio_clave', de_quien, p_ente);
  end if;
  return la_clave;
end
$clave$;

revoke all on function public.clave_del_ente(uuid, text) from public;
revoke execute on function public.clave_del_ente(uuid, text) from anon;
grant execute on function public.clave_del_ente(uuid, text) to authenticated;


-- ── 2 · PAPELES QUE SOLO EMITE EL CIIP ────────────────────────────────
-- La planilla de los RIF y la constancia de cada ente las sube el equipo
-- (supabase-planilla-rif.sql, supabase-entes-parafiscales.sql), pero nada
-- impedía que un inversionista subiera un papel suyo con ese tipo. Entraba
-- como cargado, sin validar, pero el panel lo encuentra por tipo y lo
-- enseñaba como si lo hubiera mandado el CIIP. Mismo cierre que la planilla
-- del IVSS (supabase-planilla-ivss.sql).
create or replace function public.papeles_que_emite_el_ciip()
returns trigger
language plpgsql
security definer
set search_path = public
as $emite$
begin
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.tipo in ('planilla_solicitud', 'constancia_ente')
     or (tg_op = 'UPDATE' and old.tipo in ('planilla_solicitud', 'constancia_ente')) then
    raise exception 'Ese papel lo emite el CIIP' using errcode = 'check_violation';
  end if;
  return new;
end
$emite$;

drop trigger if exists documentos_papeles_que_emite_el_ciip on public.documentos;
create trigger documentos_papeles_que_emite_el_ciip
  before insert or update on public.documentos
  for each row execute function public.papeles_que_emite_el_ciip();


-- ── 3 · ANON ──────────────────────────────────────────────────────────
-- En Supabase una función nueva nace ejecutable por anon, y «revoke … from
-- public» no lo quita. Las dos se negaban por dentro a quien no es del
-- equipo, así que no se podía sacar nada; esto es para que ni lleguen.
revoke execute on function public.confirma_cita(uuid, timestamptz, text, text) from anon;
revoke execute on function public.abre_consulta_para(uuid, text, text) from anon;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--   select has_column_privilege('authenticated', 'public.tramite_entes', 'clave', 'select');        -- false
--   select has_column_privilege('authenticated', 'public.tramite_entes', 'tiene_clave', 'select');  -- true
--   select has_function_privilege('anon', 'public.clave_del_ente(uuid,text)', 'execute');           -- false
--   select has_function_privilege('anon', 'public.confirma_cita(uuid,timestamptz,text,text)', 'execute'); -- false
--   select has_function_privilege('anon', 'public.abre_consulta_para(uuid,text,text)', 'execute');  -- false
--   select tgname from pg_trigger where tgname = 'documentos_papeles_que_emite_el_ciip';           -- una fila
