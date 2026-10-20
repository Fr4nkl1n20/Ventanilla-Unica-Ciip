-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA FICHA TÉCNICA DE LOS PERMISOS
--  Solo necesita public.es_admin() y public.es_gestor() (supabase-admin.sql
--  y supabase-tramites.sql). Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 20-10-2026: «En administrador necesito crear la ficha
--  técnica de permiso». Un renglón propio en Administración, «Ficha
--  técnica», con la lista de las fichas agrupadas por ente a la izquierda
--  y la ficha elegida a la derecha, editable ahí mismo (la forma 2 de
--  maquetas/ficha-tecnica-cuatro.html).
--
--  Una ficha es lo que el CIIP sabe de UN permiso de UN ente: su base
--  legal, a quién aplica, en qué momento de la inversión se pide, sus
--  recaudos, plazo, vigencia, tasa y cómo se tramita. No es un trámite de
--  la ventanilla, y por ahora no se relaciona con ninguno: «podemos crear
--  la ficha sin datos, mejor sin relacionarla aún con los permisos que ya
--  tenemos» (Franklin Reyes, 20-10-2026).
--
--  QUIÉN HACE QUÉ
--  ─────────────────────────────────────────────────────────────────────
--  · El administrador crea, cambia y borra.
--  · El resto del equipo del CIIP (gestor) la lee: le sirve para contestar
--    al inversionista, pero no la cambia.
--  · El inversionista no la ve. Son apuntes de trabajo del CIIP, con
--    fichas en borrador y notas internas.
--
--  NACE VACÍA
--  ─────────────────────────────────────────────────────────────────────
--  Sin datos: las fichas las escribe el administrador desde el panel. La
--  clave natural (ente_sigla, codigo_ente, nombre) evita dos fichas iguales
--  y deja la puerta abierta a una carga con «on conflict do nothing» el día
--  que haga falta.
--
--  'sectores' queda preparado para el cruce con el sector que traerá
--  Atlas (la matriz de permisos por sector, 16-10-2026): hoy se rellena a
--  mano, separado por comas en la pantalla.
-- ═══════════════════════════════════════════════════════════════════════

do $$
begin
  if to_regprocedure('public.es_admin()') is null then
    raise exception 'Falta public.es_admin(): corre antes supabase-admin.sql';
  end if;
  if to_regprocedure('public.es_gestor()') is null then
    raise exception 'Falta public.es_gestor(): corre antes supabase-tramites.sql';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA TABLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.fichas_tecnicas (
  id              uuid        primary key default gen_random_uuid(),
  -- El ente, por su sigla (MINTUR, MINEC) y por su nombre entero. La
  -- pantalla agrupa por la sigla.
  ente_sigla      text        not null,
  ente            text        not null default '',
  -- El código que el propio ente le da al permiso, si le da alguno.
  codigo_ente     text        not null default '',
  nombre          text        not null,
  base_legal      text        not null default '',
  -- A quién aplica: el supuesto en que hace falta el permiso.
  supuestos       text        not null default '',
  sectores        text[]      not null default '{}',
  -- En qué momento de la inversión se pide.
  momento         text        not null default 'por_clasificar',
  recaudos        text[]      not null default '{}',
  plazo           text        not null default '',
  vigencia        text        not null default '',
  tasa            text        not null default '',
  como_se_tramita text        not null default '',
  enlace          text        not null default '',
  categoria       text        not null default '',
  estado          text        not null default 'borrador',
  notas           text        not null default '',
  -- De dónde salió lo que dice (el documento del CIIP, la Gaceta...).
  fuente          text        not null default '',
  creado_en       timestamptz default now(),
  actualizado_en  timestamptz default now(),
  actualizado_por uuid references auth.users(id) on delete set null,

  constraint fichas_tecnicas_clave unique (ente_sigla, codigo_ente, nombre),
  -- Los cuatro momentos del panel, ni uno más: uno mal escrito dejaría la
  -- ficha fuera de todos los grupos y nadie sabría por qué.
  constraint fichas_tecnicas_momento_valido
    check (momento in ('previo', 'durante', 'operar', 'por_clasificar')),
  constraint fichas_tecnicas_estado_valido
    check (estado in ('borrador', 'confirmado')),
  -- Sin sigla ni nombre no hay ficha: no se sabría dónde ponerla ni cómo
  -- llamarla.
  constraint fichas_tecnicas_sigla_cabe
    check (char_length(btrim(ente_sigla)) between 1 and 60),
  constraint fichas_tecnicas_nombre_cabe
    check (char_length(btrim(nombre)) between 1 and 300),
  -- Topes generosos: cortan un pegado accidental, no una ficha larga.
  constraint fichas_tecnicas_cortos_caben check (
    char_length(ente) <= 300 and char_length(codigo_ente) <= 60 and
    char_length(plazo) <= 300 and char_length(vigencia) <= 300 and
    char_length(tasa) <= 300 and char_length(categoria) <= 120 and
    char_length(enlace) <= 500 and char_length(fuente) <= 500),
  constraint fichas_tecnicas_largos_caben check (
    char_length(base_legal) <= 4000 and char_length(supuestos) <= 4000 and
    char_length(como_se_tramita) <= 4000 and char_length(notas) <= 4000),
  constraint fichas_tecnicas_listas_caben check (
    cardinality(sectores) <= 60 and
    char_length(array_to_string(sectores, '')) <= 3000 and
    cardinality(recaudos) <= 80 and
    char_length(array_to_string(recaudos, '')) <= 16000)
);

comment on table  public.fichas_tecnicas           is 'Ficha técnica de cada permiso, por ente. La escribe el administrador; la lee el equipo del CIIP';
comment on column public.fichas_tecnicas.momento   is 'previo, durante, operar o por_clasificar: en qué momento de la inversión se pide';
comment on column public.fichas_tecnicas.sectores  is 'Los sectores a que aplica, para el cruce con el sector de Atlas';

create index if not exists fichas_tecnicas_por_ente
  on public.fichas_tecnicas (ente_sigla);

alter table public.fichas_tecnicas enable row level security;


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN LA LEE Y QUIÉN LA ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
-- Leer: el equipo del CIIP (gestor y admin; es_gestor() cuenta a los dos
-- y deja fuera a quien esté bloqueado).
drop policy if exists "fichas_tecnicas: la lee el equipo" on public.fichas_tecnicas;
create policy "fichas_tecnicas: la lee el equipo" on public.fichas_tecnicas
  for select to authenticated
  using (public.es_gestor());

-- Escribir: solo el admin.
drop policy if exists "fichas_tecnicas: el admin la crea" on public.fichas_tecnicas;
create policy "fichas_tecnicas: el admin la crea" on public.fichas_tecnicas
  for insert to authenticated
  with check (public.es_admin());

drop policy if exists "fichas_tecnicas: el admin la cambia" on public.fichas_tecnicas;
create policy "fichas_tecnicas: el admin la cambia" on public.fichas_tecnicas
  for update to authenticated
  using      (public.es_admin())
  with check (public.es_admin());

drop policy if exists "fichas_tecnicas: el admin la borra" on public.fichas_tecnicas;
create policy "fichas_tecnicas: el admin la borra" on public.fichas_tecnicas
  for delete to authenticated
  using (public.es_admin());

-- Sin sesión, nada: ni la tabla.
revoke all on public.fichas_tecnicas from anon;


-- ───────────────────────────────────────────────────────────────────────
-- 3. QUIÉN LA TOCÓ
-- ───────────────────────────────────────────────────────────────────────
-- Lo escribe un disparador, como en textos_panel: un campo que rellena
-- quien escribe es un campo que quien escribe puede mentir. Y la fecha de
-- creación no se mueve al cambiarla.
create or replace function public.marca_fichas_tecnicas()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.actualizado_por := auth.uid();
  new.actualizado_en  := now();
  if tg_op = 'UPDATE' then
    new.creado_en := old.creado_en;
  end if;
  return new;
end $$;

drop trigger if exists fichas_tecnicas_quien on public.fichas_tecnicas;
create trigger fichas_tecnicas_quien
  before insert or update on public.fichas_tecnicas
  for each row execute function public.marca_fichas_tecnicas();


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE
-- ───────────────────────────────────────────────────────────────────────
-- · No entra en la bitácora. Su regla de fuentes es una lista cerrada
--   (supabase-borrado-admin.sql), y abrirla para esto es otro trabajo.
--   Quién la cambió por última vez queda en su propia fila.
-- · No trae fichas ni se relaciona con los trámites: ver la cabecera.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. Las cuatro políticas: leer, crear, cambiar y borrar.
select policyname, cmd from pg_policies
where  schemaname = 'public' and tablename = 'fichas_tecnicas'
order  by cmd;

-- 2. Lo que hay, por ente.
select ente_sigla, count(*) from public.fichas_tecnicas group by ente_sigla order by ente_sigla;
