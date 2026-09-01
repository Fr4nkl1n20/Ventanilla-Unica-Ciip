-- ══════════════════════════════════════════════════════════════════════
--  EL DOBLE DE SUPABASE, PARA UN POSTGRES DE ESCRITORIO
-- ══════════════════════════════════════════════════════════════════════
--  Los once archivos del proyecto dan por hecho que existen cosas que
--  pone Supabase y no Postgres: el esquema auth con sus usuarios, el
--  esquema storage con el cubo, y auth.uid(), que dice quien esta
--  entrando. En un Postgres recien instalado nada de eso existe, y sin
--  ello los once ni se ejecutan.
--
--  Aqui esta lo MINIMO para que corran: cinco objetos, ni uno mas. No es
--  un Supabase de mentira -eso ya existe, en supabase-mentira.js, y sirve
--  para otra cosa-: es el andamio que sostiene el SQL de verdad mientras
--  se comprueba que hace lo que dice.
--
--  LO QUE ESTE DOBLE SI IMITA BIEN
--  ─────────────────────────────────────────────────────────────────────
--  auth.uid() y storage.foldername() estan copiadas de como funcionan
--  alli, no aproximadas. La primera lee el 'sub' de una variable de
--  sesion, que es exactamente el mecanismo de Supabase: el JWT llega, el
--  servidor lo mete en request.jwt.claims y la funcion lo lee. La segunda
--  QUITA EL ULTIMO TROZO de la ruta -el nombre del archivo- y devuelve
--  solo las carpetas; si devolviera la ruta entera, las politicas del
--  cubo se estarian probando con otra logica que la de produccion, y el
--  verde no valdria nada.
--
--  LO QUE NO IMITA, Y NO PUEDE
--  ─────────────────────────────────────────────────────────────────────
--  El tope de tamano y la lista de tipos del cubo. Esos NO los aplica
--  Postgres: los aplica storage-api, que es un servicio aparte escrito en
--  Node. Aqui la fila de storage.buckets tendra sus valores puestos y se
--  puede comprobar que estan, pero nada impedira meter un objeto de 11 MB
--  en storage.objects. Eso solo se prueba contra un Supabase de verdad,
--  con PROBAR-CERRADURAS.bat.
-- ══════════════════════════════════════════════════════════════════════

create schema if not exists auth;
create schema if not exists storage;

-- Los dos roles que Supabase trae de fabrica. nologin porque aqui nadie
-- se conecta como ellos: se entra con "set local role", que es lo que
-- hace por dentro el servidor cuando llega una peticion con su JWT.
do $doble$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end
$doble$;

-- raw_user_meta_data no es un capricho: manejar_usuario_nuevo() saca de
-- ahi el nombre y el pais para crear el perfil. Sin esa columna el
-- trigger del alta no compila.
create table if not exists auth.users (
  id                  uuid primary key default gen_random_uuid(),
  email               text unique,
  raw_user_meta_data  jsonb
);

create or replace function auth.uid()
returns uuid
language sql
stable
as $doble$
  select nullif(
    current_setting('request.jwt.claims', true)::json ->> 'sub', ''
  )::uuid;
$doble$;

create table if not exists storage.buckets (
  id                 text primary key,
  name               text not null,
  public             boolean not null default false,
  file_size_limit    bigint,
  allowed_mime_types text[]
);

create table if not exists storage.objects (
  id         uuid primary key default gen_random_uuid(),
  bucket_id  text references storage.buckets(id),
  name       text not null,
  owner      uuid references auth.users(id) on delete set null,
  creado_en  timestamptz not null default now()
);
alter table storage.objects enable row level security;

-- Devuelve SOLO las carpetas, sin el nombre del archivo. Para
-- 'uid/emitidos/acta.pdf' da {uid,emitidos}, y por eso las politicas
-- pueden preguntar por [1] -el dueno- y por [2] -si viene del equipo-.
create or replace function storage.foldername(name text)
returns text[]
language plpgsql
immutable
as $doble$
declare
  trozos text[];
begin
  select string_to_array(name, '/') into trozos;
  return trozos[1 : array_length(trozos, 1) - 1];
end
$doble$;

grant usage on schema auth, storage, public to anon, authenticated;
grant select on auth.users to authenticated;

-- ── y la costumbre de Supabase que casi se nos escapa ──
-- Supabase deja puesto un `alter default privileges` que concede EXECUTE
-- sobre TODA funcion nueva de public a anon, authenticated y service_role.
-- Postgres a secas no hace eso.
--
-- Sin esta linea, este arnes daba verde a funciones que en el Supabase de
-- verdad estaban abiertas de par en par: aqui `revoke ... from public`
-- bastaba, y alli no quitaba nada porque el permiso no venia de PUBLIC
-- sino de cada rol por su nombre. Se descubrio corriendo las cerraduras
-- contra un proyecto real, no aqui.
--
-- Poniendolo, el doble se equivoca igual que el original, que es lo unico
-- que le pedimos a un doble.
alter default privileges in schema public
  grant execute on functions to anon, authenticated;
