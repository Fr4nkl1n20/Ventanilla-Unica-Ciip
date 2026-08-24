-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL SECTOR EN EL QUE SE VA A INVERTIR
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-admin.sql, de donde sale es_admin().
-- ═══════════════════════════════════════════════════════════════════════
--
--  LO QUE ESTO ES, Y LO QUE NO ES
--  ─────────────────────────────────────────────────────────────────────
--  Guarda UNA respuesta: en qué sector va a invertir cada inversionista.
--  El panel la pide una sola vez, antes de dejar entrar, y a partir de
--  ahí la lleva en el expediente.
--
--  NO decide qué trámites le tocan. Eso lo dice la normativa, y la
--  normativa la tiene el CIIP, no este archivo. El día que llegue esa
--  matriz —qué sector exige qué permisos ante qué organismo— se apoyará
--  en esta columna; hasta entonces el sector se guarda, se enseña y se
--  puede cambiar, y los treinta y un trámites se siguen viendo todos.
--
--  Decirlo importa: un filtro inventado que esconda un trámite que sí
--  hacía falta es peor que no filtrar nada. El inversionista no sabría
--  que le falta algo hasta que el organismo se lo diga.
--
--  EL CATÁLOGO VIVE EN LA BASE, NO EN EL CÓDIGO
--  ─────────────────────────────────────────────────────────────────────
--  Igual que tipos_tramite. Añadir, quitar o renombrar un sector es un
--  INSERT o un UPDATE que hace el CIIP, no una versión nueva del panel.
--  ref_panel ('s1', 's2'…) es el enganche para traducirlo a los seis
--  idiomas en pasos.js; mientras no haya traducción se enseña el nombre
--  en español que esté aquí, que es honesto y no deja el hueco vacío.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL CATÁLOGO
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.sectores (
  codigo    text        primary key,
  ref_panel text        not null unique,
  nombre    text        not null,
  orden     smallint    not null default 0,
  activo    boolean     not null default true,
  creado_en timestamptz not null default now(),

  constraint sectores_nombre_no_vacio check (length(trim(nombre)) > 0)
);

comment on table  public.sectores           is 'Los sectores económicos que puede elegir un inversionista';
comment on column public.sectores.ref_panel is 'Identificador para traducir el nombre en pasos.js (s1…sN)';
comment on column public.sectores.orden     is 'Orden en que se ofrecen; a igual orden, alfabético';
comment on column public.sectores.activo    is 'false = ya no se ofrece, pero quien lo eligió lo conserva';

alter table public.sectores enable row level security;

-- Lo lee cualquiera que haya entrado: es el catálogo que hay que elegir.
drop policy if exists "sectores: leerlos" on public.sectores;
create policy "sectores: leerlos"
  on public.sectores for select
  to authenticated
  using (true);

-- Y solo el equipo lo toca. Sin esto, un inversionista podría inventarse
-- un sector y el catálogo dejaría de ser un catálogo.
drop policy if exists "sectores: solo el admin escribe" on public.sectores;
create policy "sectores: solo el admin escribe"
  on public.sectores for all
  using      (public.es_admin())
  with check (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 2. LA RESPUESTA, EN EL PERFIL
-- ───────────────────────────────────────────────────────────────────────
-- on delete set null y no cascade: si el CIIP borra un sector del
-- catálogo, el inversionista se queda sin sector —y el panel se lo vuelve
-- a preguntar—, pero NO se borra su perfil con él.
alter table public.perfiles
  add column if not exists sector text
  references public.sectores(codigo) on delete set null;

alter table public.perfiles
  add column if not exists sector_elegido_en timestamptz;

comment on column public.perfiles.sector is 'Sector en el que declara que va a invertir; null = todavía no ha contestado';

-- La fecha la pone la base y no el navegador, por lo mismo de siempre: el
-- reloj del navegador lo mueve quien quiera.
create or replace function public.sellar_sector()
returns trigger
language plpgsql
as $$
begin
  if new.sector is distinct from old.sector then
    new.sector_elegido_en := case when new.sector is null then null else now() end;
  end if;
  return new;
end;
$$;

drop trigger if exists sellar_sector on public.perfiles;
create trigger sellar_sector
  before update on public.perfiles
  for each row execute function public.sellar_sector();

-- El equipo necesita verlo para atender: saber en qué sector está quien
-- escribe es la mitad del contexto. La política de lectura del gestor ya
-- existe en supabase-gestor.sql y alcanza a la fila entera.


-- ───────────────────────────────────────────────────────────────────────
-- 3. EL CATÁLOGO DEL CIIP
-- ───────────────────────────────────────────────────────────────────────
--  AQUÍ VA LA LISTA. Es lo único de este archivo que hay que rellenar, y
--  el único sitio donde se toca: ni el panel ni pasos.js llevan sectores
--  escritos dentro.
--
--  Mientras esté vacía el panel NO bloquea a nadie. Es a propósito: una
--  puerta cerrada con una lista vacía detrás es una puerta sin llave, y
--  dejaría fuera a todo el mundo hasta que alguien corriera este archivo.
--
--  Los ocho motores productivos, en el orden en que los presenta el CIIP.
--  El on conflict ACTUALIZA en vez de fallar, así que corregir un nombre
--  es cambiarlo aquí y volver a correr el archivo entero.
insert into public.sectores (codigo, ref_panel, nombre, orden) values
  ('hidrocarburos',      's1', 'Hidrocarburos',        10),
  ('mineria',            's2', 'Minería',              20),
  ('industrial',         's3', 'Industrial',           30),
  ('turismo',            's4', 'Turismo',              40),
  ('agroindustrial',     's5', 'Agroindustrial',       50),
  ('salud',              's6', 'Salud',                60),
  ('pesca_acuicultura',  's7', 'Pesca y acuicultura',  70),
  ('forestal',           's8', 'Forestal',             80)
on conflict (codigo) do update
  set ref_panel = excluded.ref_panel,
      nombre    = excluded.nombre,
      orden     = excluded.orden,
      activo    = true;

-- Para retirar uno NO lo borres: quien ya lo eligió perdería su respuesta,
-- y el panel se lo volvería a preguntar al entrar.
--
--   update public.sectores set activo = false where codigo = 'forestal';
--
-- Los nombres en los otros cinco idiomas están en pasos.js, colgados de
-- ref_panel. Si añades un sector nuevo aquí y no allí, se enseña este
-- nombre en español: se ve raro, pero se ve, que es mejor que un hueco.


-- ───────────────────────────────────────────────────────────────────────
-- 4. COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
do $$
declare n integer;
begin
  select count(*) into n from public.sectores where activo;
  if n = 0 then
    raise notice 'Sectores: la tabla está creada y VACÍA. El panel no pedirá el sector hasta que haya al menos uno (apartado 3 de este archivo).';
  else
    raise notice 'Sectores: % activos en el catálogo.', n;
  end if;
end $$;
