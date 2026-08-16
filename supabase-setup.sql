-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · Ventanilla Única del Inversionista
--  Esquema de base de datos para el acceso (acceso.html)
-- ═══════════════════════════════════════════════════════════════════════
--
--  CÓMO SUBIRLO:
--    Panel de Supabase → SQL Editor → New query → pega todo esto → Run
--
--  Es idempotente: puedes ejecutarlo varias veces sin romper nada.
--
--  QUÉ HACE:
--    1. Crea la tabla public.perfiles, ligada 1 a 1 con auth.users
--    2. Activa RLS para que cada usuario solo vea y edite SU perfil
--    3. Crea un trigger que rellena el perfil solo al registrarse
--    4. Mantiene actualizado_en al día
--
--  QUÉ **NO** HACE (y no debe hacer):
--    No guarda claves. Supabase ya las almacena cifradas en auth.users.
--    Nunca crees una columna de contraseña en tus propias tablas.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. TABLA DE PERFILES
-- ───────────────────────────────────────────────────────────────────────
-- auth.users la gestiona Supabase y no se debe tocar. Todo dato propio
-- del inversionista (nombre, país, rol…) vive aquí, enlazado por id.
-- Al borrar el usuario en auth.users, su perfil se borra en cascada.

create table if not exists public.perfiles (
  id               uuid        primary key references auth.users(id) on delete cascade,
  nombre_completo  text        not null default '',
  pais             text        not null default '',
  rol              text        not null default 'inversionista',
  creado_en        timestamptz not null default now(),
  actualizado_en   timestamptz not null default now(),

  constraint perfiles_rol_valido check (rol in ('inversionista','gestor','admin'))
);

comment on table  public.perfiles                 is 'Datos de perfil de cada usuario, 1 a 1 con auth.users';
comment on column public.perfiles.rol             is 'inversionista = usuario final; gestor = equipo CIIP; admin = total';
comment on column public.perfiles.nombre_completo is 'Se rellena solo desde el registro (acceso.html)';


-- ───────────────────────────────────────────────────────────────────────
-- 2. SEGURIDAD A NIVEL DE FILA (RLS)
-- ───────────────────────────────────────────────────────────────────────
-- ESTO ES LO QUE REALMENTE PROTEGE LOS DATOS.
-- La clave anon del navegador es pública; sin RLS, cualquiera podría leer
-- la tabla entera. Con RLS, Postgres filtra por el usuario autenticado.

alter table public.perfiles enable row level security;

-- Cada quien lee únicamente su propio perfil
drop policy if exists "perfiles: leer el propio" on public.perfiles;
create policy "perfiles: leer el propio"
  on public.perfiles for select
  using (auth.uid() = id);

-- Cada quien edita únicamente su propio perfil…
drop policy if exists "perfiles: actualizar el propio" on public.perfiles;
create policy "perfiles: actualizar el propio"
  on public.perfiles for update
  using      (auth.uid() = id)
  with check (auth.uid() = id);

-- …pero NO puede cambiarse el rol a sí mismo (evita autoascenso a admin).
-- auth.uid() es null cuando la conexión usa la clave service_role o se
-- ejecuta desde el SQL Editor, así que el equipo del CIIP sí puede
-- ascender a alguien a 'gestor'; el usuario desde el navegador, no.
create or replace function public.bloquear_cambio_de_rol()
returns trigger
language plpgsql
as $$
begin
  if new.rol is distinct from old.rol and auth.uid() is not null then
    raise exception 'El rol solo puede cambiarse desde el servidor';
  end if;
  return new;
end;
$$;

drop trigger if exists proteger_rol on public.perfiles;
create trigger proteger_rol
  before update on public.perfiles
  for each row execute function public.bloquear_cambio_de_rol();

-- Nota: no hay política de INSERT ni de DELETE a propósito.
-- El alta la hace el trigger de más abajo (security definer) y las bajas
-- se gestionan borrando el usuario en auth.users.


-- ───────────────────────────────────────────────────────────────────────
-- 3. ALTA AUTOMÁTICA DEL PERFIL AL REGISTRARSE
-- ───────────────────────────────────────────────────────────────────────
-- acceso.html envía nombre_completo y pais dentro de options.data al
-- llamar a signUp(). Supabase los guarda en auth.users.raw_user_meta_data
-- y este trigger los copia a public.perfiles.
--
-- security definer = corre con permisos del dueño, saltándose RLS, que es
-- justo lo que hace falta para poder insertar la fila del usuario nuevo.

create or replace function public.manejar_usuario_nuevo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfiles (id, nombre_completo, pais)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nombre_completo', ''),
    coalesce(new.raw_user_meta_data ->> 'pais', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists al_crear_usuario on auth.users;
create trigger al_crear_usuario
  after insert on auth.users
  for each row execute function public.manejar_usuario_nuevo();


-- ───────────────────────────────────────────────────────────────────────
-- 4. MARCA DE TIEMPO DE ACTUALIZACIÓN
-- ───────────────────────────────────────────────────────────────────────

create or replace function public.tocar_actualizado_en()
returns trigger
language plpgsql
as $$
begin
  new.actualizado_en = now();
  return new;
end;
$$;

drop trigger if exists actualizar_marca_tiempo on public.perfiles;
create trigger actualizar_marca_tiempo
  before update on public.perfiles
  for each row execute function public.tocar_actualizado_en();


-- ───────────────────────────────────────────────────────────────────────
-- 5. PERFILES PARA USUARIOS YA EXISTENTES
-- ───────────────────────────────────────────────────────────────────────
-- Si ya habías creado usuarios antes de instalar el trigger, esto les
-- genera el perfil que les falta. Inofensivo si no hay ninguno.

insert into public.perfiles (id, nombre_completo, pais)
select u.id,
       coalesce(u.raw_user_meta_data ->> 'nombre_completo', ''),
       coalesce(u.raw_user_meta_data ->> 'pais', '')
from auth.users u
left join public.perfiles p on p.id = u.id
where p.id is null;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
-- Ejecuta esto después para verificar que RLS quedó activo.
-- Debe devolver una fila con rowsecurity = true.
--
--   select relname, relrowsecurity as rowsecurity
--   from pg_class where relname = 'perfiles';
