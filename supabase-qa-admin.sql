-- Auditoría QA, administración y cuentas: QA-05, 06, 07, 26, 27, 40 y 43.
-- Idempotente. Va detrás de todos: necesita perfiles con bloqueado
-- (supabase-bloqueo.sql), la bitácora y el tope de la IA.

do $qa$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'perfiles'
                    and column_name = 'bloqueado') then
    raise exception 'Falta perfiles.bloqueado: pasa antes supabase-bloqueo.sql';
  end if;
  if to_regprocedure('public.esta_bloqueado()') is null
     or to_regprocedure('public.corta_si_bloqueado()') is null then
    raise exception 'Falta esta_bloqueado() o corta_si_bloqueado(): pasa antes supabase-bloqueo.sql';
  end if;
end
$qa$;


-- ── QA-05 · Bloquear a alguien del equipo le quita los permisos ────────
-- Misma firma y mismo cuerpo que en supabase-tramites.sql y
-- supabase-admin.sql, con una condición más. Decenas de políticas pasan
-- por aquí: no se toca nada más.
create or replace function public.es_gestor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles
    where id = auth.uid() and rol in ('gestor','admin')
      and not coalesce(bloqueado, false)
  );
$$;

create or replace function public.es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles p
    where p.id = auth.uid() and p.rol = 'admin'
      and not coalesce(p.bloqueado, false)
  );
$$;

-- Las tres tablas que el corte no cubría.
do $qa$
declare
  t text;
begin
  foreach t in array array['activos', 'horario_citas', 'identidad_comprobaciones'] loop
    if to_regclass('public.' || t) is null then
      raise notice 'No existe public.%: se salta', t;
      continue;
    end if;
    execute format('drop trigger if exists %I on public.%I', t || '_bloqueo', t);
    execute format('create trigger %I before insert or update or delete on public.%I '
                   'for each row execute function public.corta_si_bloqueado()',
                   t || '_bloqueo', t);
  end loop;
end
$qa$;

-- El asistente y el lector: una cuenta bloqueada no gasta IA. Devuelve
-- false y no un error, porque con un error las funciones de api/ vuelven
-- al contador de la memoria y dejarían pasar la pregunta.
do $qa$
begin
  if to_regclass('public.uso_ia') is null then
    raise notice 'Sin public.uso_ia: gasta_uso_ia() se queda como esté. Corre supabase-tope-ia.sql y vuelve a pasar este.';
    return;
  end if;

  execute $f$
create or replace function public.gasta_uso_ia(p_pieza text)
returns boolean
language plpgsql
security definer
set search_path = public
as $tope$
declare
  yo   uuid := auth.uid();
  tope integer;
  n    integer;
begin
  if yo is null then
    raise exception 'Hace falta haber entrado' using errcode = '42501';
  end if;

  if public.esta_bloqueado() then
    return false;
  end if;

  -- Las tres definiciones (tope-ia, qa-admin, traduccion-chat) son la
  -- misma desde el 8-10-2026: volver a correr una suelta no puede quitar
  -- el bloqueo ni dejar sin tope al traductor.
  tope := case p_pieza when 'asistente' then 40
                       when 'lector'    then 20
                       when 'traductor' then 60 end;
  if tope is null then
    raise exception 'pieza desconocida: %', p_pieza;
  end if;

  delete from public.uso_ia where usuario = yo and hora < now() - interval '2 days';

  insert into public.uso_ia as u (usuario, pieza, hora, usos)
  values (yo, p_pieza, date_trunc('hour', now()), 1)
  on conflict (usuario, pieza, hora)
  do update set usos = u.usos + 1 where u.usos < tope
  returning usos into n;

  return n is not null;
end
$tope$
  $f$;

  revoke all on function public.gasta_uso_ia(text) from public, anon;
  grant execute on function public.gasta_uso_ia(text) to authenticated;
end
$qa$;


-- ── QA-06 · Dar de baja en vez de borrar ───────────────────────────────
-- La baja deja la cuenta bloqueada y con fecha; los trámites, papeles,
-- citas y aceptaciones del pliego siguen donde estaban.
alter table public.perfiles
  add column if not exists dado_de_baja_en  timestamptz,
  add column if not exists dado_de_baja_por uuid references auth.users(id) on delete set null;

comment on column public.perfiles.dado_de_baja_en is
  'Baja lógica: la cuenta queda bloqueada y su historia se conserva. La pone un admin';

-- Borrar la cuenta en auth.users arrastra en cascada todo lo suyo, y con
-- ello la prueba de que aceptó el pliego. Mientras haya aceptaciones no se
-- borra; si de verdad hay que hacerlo (una cuenta de pruebas), desde el
-- editor de SQL y a sabiendas:
--   begin; set local ciip.borrado_fisico = 'si'; delete from auth.users where ...; commit;
create or replace function public.no_borrar_con_historia()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('ciip.borrado_fisico', true), '') = 'si' then
    return old;
  end if;
  if to_regclass('public.pliego_aceptaciones') is not null
     and exists (select 1 from public.pliego_aceptaciones a where a.persona = old.id) then
    raise exception 'Esta cuenta aceptó el pliego: no se borra, se da de baja desde el panel (Usuarios)';
  end if;
  return old;
end $$;

drop trigger if exists no_borrar_con_historia on auth.users;
create trigger no_borrar_con_historia
  before delete on auth.users
  for each row execute function public.no_borrar_con_historia();


-- ── QA-26 y QA-40 · Lo que cada cual puede cambiar de un perfil ────────
-- Corre ANTES que los demás disparadores de perfiles (van por orden
-- alfabético y este empieza por «aa»), así que ve solo lo que manda el
-- navegador:
--   · las columnas de rastro vuelven a su valor; las rellenan después los
--     disparadores de siempre (proteger_rol, perfiles_bloqueo,
--     sellar_sector). visto_en solo puede ser la hora del servidor.
--   · en un perfil AJENO solo se mueven el rol, el bloqueo y la baja.
--   · la baja la da un admin, nunca sobre sí mismo, y bloquea.
-- Se trabaja con jsonb para no nombrar columnas que a lo mejor aún no
-- existen (sector_elegido_en, visto_en...).
create or replace function public.perfiles_guarda_columnas()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  yo      uuid := auth.uid();
  viejo   jsonb := to_jsonb(old);
  nuevo   jsonb := to_jsonb(new);
  vuelve  jsonb := '{}'::jsonb;
  c       text;
  rastro  text[] := array['rol_cambiado_por', 'rol_cambiado_en', 'bloqueado_por',
                          'bloqueado_en', 'sector_elegido_en', 'dado_de_baja_por'];
  ajenas  text[] := array['rol', 'bloqueado', 'dado_de_baja_en', 'dado_de_baja_por',
                          'rol_cambiado_por', 'rol_cambiado_en', 'bloqueado_por',
                          'bloqueado_en', 'actualizado_en', 'visto_en', 'sector_elegido_en'];
begin
  if yo is not null then
    foreach c in array rastro loop
      if viejo ? c and (nuevo -> c) is distinct from (viejo -> c) then
        vuelve := vuelve || jsonb_build_object(c, viejo -> c);
      end if;
    end loop;
    if viejo ? 'visto_en' and (nuevo -> 'visto_en') is distinct from (viejo -> 'visto_en') then
      vuelve := vuelve || jsonb_build_object('visto_en', to_jsonb(now()));
    end if;
    if vuelve <> '{}'::jsonb then
      new := jsonb_populate_record(new, vuelve);
    end if;

    if new.id <> yo and (to_jsonb(new) - ajenas) is distinct from (viejo - ajenas) then
      raise exception 'De una cuenta ajena solo se cambian el rol, el bloqueo y la baja'
        using errcode = '42501';
    end if;
  end if;

  if new.dado_de_baja_en is distinct from old.dado_de_baja_en then
    if yo is not null then
      if not public.es_admin() then
        raise exception 'Solo un administrador da de baja una cuenta' using errcode = '42501';
      end if;
      if new.id = yo then
        raise exception 'Nadie se da de baja a sí mismo';
      end if;
    end if;
    if new.dado_de_baja_en is not null then
      new.dado_de_baja_en  := now();
      new.dado_de_baja_por := yo;
      new.bloqueado        := true;
    else
      new.dado_de_baja_por := null;
    end if;
  elsif old.dado_de_baja_en is not null and not new.bloqueado then
    raise exception 'La cuenta está dada de baja: deshaz la baja antes de desbloquearla';
  end if;

  return new;
end $$;

drop trigger if exists aa_perfiles_guarda_columnas on public.perfiles;
create trigger aa_perfiles_guarda_columnas
  before update on public.perfiles
  for each row execute function public.perfiles_guarda_columnas();


-- ── QA-07 · El correo de cada cuenta, solo para el admin ───────────────
-- perfiles no guarda el correo y una cuenta nueva llega «Sin nombre». El
-- correo vive en auth.users, que el navegador no lee: esto lo da, y solo
-- a un admin.
create or replace function public.correos_de_las_cuentas()
returns table (id uuid, correo text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve los correos' using errcode = '42501';
  end if;
  return query select u.id, u.email::text from auth.users u order by u.id;
end $$;

revoke all on function public.correos_de_las_cuentas() from public;
revoke all on function public.correos_de_las_cuentas() from anon;
grant execute on function public.correos_de_las_cuentas() to authenticated;


-- ── QA-27 · La bitácora guarda el rol de antes, y la baja ──────────────
do $qa$
begin
  if to_regprocedure('public.apunta(text, text, text, text)') is null then
    raise notice 'Sin bitácora: el rol anterior y la baja no se apuntan. Corre supabase-bitacora.sql y vuelve a pasar este.';
    return;
  end if;

  -- El detalle pasa a ser {"rol": nuevo, "antes": viejo}. El panel lee
  -- los dos formatos: los apuntes viejos traen solo el rol nuevo.
  execute $f$
create or replace function public.bit_roles()
returns trigger language plpgsql security definer set search_path = public as $b$
begin
  if new.rol is distinct from old.rol then
    perform public.apunta('roles', 'rol', new.nombre_completo,
      json_build_object('rol', new.rol, 'antes', old.rol)::text);
  end if;
  return null;
end $b$
  $f$;

  execute $f$
create or replace function public.bit_baja()
returns trigger language plpgsql security definer set search_path = public as $b$
begin
  if new.dado_de_baja_en is distinct from old.dado_de_baja_en then
    perform public.apunta('roles',
      case when new.dado_de_baja_en is null then 'alta' else 'baja' end,
      new.nombre_completo);
  end if;
  return null;
end $b$
  $f$;

  drop trigger if exists bitacora_baja on public.perfiles;
  create trigger bitacora_baja
    after update of dado_de_baja_en on public.perfiles
    for each row execute function public.bit_baja();
end
$qa$;


-- ── QA-43 · Lo que no debe llamarse sin sesión, y el original del texto ─
-- «revoke from public» no basta en Supabase: anon tiene su propio grant.
do $qa$
begin
  if to_regprocedure('public.huecos_ocupados(date, date)') is not null then
    revoke execute on function public.huecos_ocupados(date, date) from anon;
  end if;
  if to_regprocedure('public.reserva_cita(timestamptz, text, text, text)') is not null then
    revoke execute on function public.reserva_cita(timestamptz, text, text, text) from anon;
  end if;
end
$qa$;

-- El «original» de un texto lo manda el panel al guardarlo por primera
-- vez: el diccionario vive en el panel, no aquí, y de eso no hay otra
-- fuente. Lo que sí se evita es que un guardado posterior lo reescriba:
-- una vez en la base, el original es el de la base.
do $qa$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'textos_panel'
                    and column_name = 'original') then
    raise notice 'Sin textos_panel.original: se salta. Corre supabase-textos-rastro.sql y vuelve a pasar este.';
    return;
  end if;

  execute $f$
create or replace function public.textos_original_fijo()
returns trigger language plpgsql as $b$
begin
  new.original := old.original;
  return new;
end $b$
  $f$;

  drop trigger if exists textos_original_fijo on public.textos_panel;
  create trigger textos_original_fijo
    before update on public.textos_panel
    for each row execute function public.textos_original_fijo();
end
$qa$;


-- ── Comprobación ───────────────────────────────────────────────────────
-- Que es_gestor() y es_admin() sigan dejando entrar a quien debe. Si no
-- queda ningún admin sin bloquear, se para aquí y no se aplica nada.
do $qa$
declare
  n_admin int;
begin
  if pg_get_functiondef('public.es_gestor()'::regprocedure) not like '%bloqueado%'
     or pg_get_functiondef('public.es_admin()'::regprocedure) not like '%bloqueado%' then
    raise exception 'es_gestor() o es_admin() no quedaron con el bloqueo';
  end if;
  select count(*) into n_admin from public.perfiles
   where rol = 'admin' and not coalesce(bloqueado, false);
  if n_admin = 0 and exists (select 1 from public.perfiles where rol = 'admin') then
    raise exception 'Todos los admin están bloqueados: nadie podría desbloquearlos. Revisa perfiles antes de correr esto.';
  end if;
end
$qa$;

-- Quién del equipo conserva los permisos después de esto.
select p.nombre_completo, p.rol, p.bloqueado, p.dado_de_baja_en
from   public.perfiles p
where  p.rol in ('gestor', 'admin')
order  by p.rol, p.nombre_completo;
