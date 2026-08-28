-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA BITÁCORA
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: después de supabase-tramites.sql, supabase-admin.sql y
--  supabase-catalogos.sql. Necesita public.es_gestor() y public.es_admin().
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ARREGLA
--  ─────────────────────────────────────────────────────────────────────
--  El Rastro se componía rebuscando en tres sitios que no se hicieron
--  para llevar un registro:
--
--    tramite_eventos            sí es un historial, pero solo de trámites.
--    perfiles.rol_cambiado_*    una columna en la ficha de la persona.
--    tipos_tramite.activo_*     una columna en la ficha del trámite.
--
--  Las dos columnas guardan el ÚLTIMO movimiento y pisan el anterior.
--  Apagar un trámite y volver a encenderlo dejaba UN apunte, no dos: el
--  segundo borraba al primero, y el registro decía que nunca se apagó.
--
--  Un registro que se sobrescribe no es un registro. Esto es una tabla
--  donde cada movimiento es UNA FILA NUEVA, y nada pisa a nada.
--
--  Y de paso entran los dos que no dejaban rastro de ninguna manera: los
--  papeles de las bóvedas y las citas.
--
--  POR QUÉ 'sobre' ES TEXTO Y NO UNA REFERENCIA
--  ─────────────────────────────────────────────────────────────────────
--  Se guarda el NOMBRE de la cosa tal como era en ese momento, no un
--  puntero a ella. Si mañana se renombra el trámite, o se borra el papel,
--  la bitácora tiene que seguir contando lo que pasó con las palabras de
--  entonces. Un registro que cambia cuando cambia el presente no sirve
--  para saber qué pasó en el pasado, que es su único trabajo.
--
--  NADIE PUEDE ESCRIBIR AQUÍ
--  ─────────────────────────────────────────────────────────────────────
--  No hay política de INSERT. Ninguna. Las filas las ponen los
--  disparadores, que corren como dueños de la tabla y se saltan RLS.
--
--  Eso quiere decir que desde el navegador —con sesión de admin, de
--  gestor o de quien sea— NO se puede añadir un apunte, ni cambiarlo, ni
--  borrarlo. Un registro que quien actúa puede editar no prueba nada.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'es_gestor'
  ) then
    raise exception 'Falta public.es_gestor(). Pasa antes supabase-gestor.sql.';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA TABLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.bitacora (
  id       bigint generated always as identity primary key,
  cuando   timestamptz not null default now(),
  -- Quién lo hizo. Null cuando no lo hizo nadie desde el panel: un update
  -- escrito aquí, en el editor, no tiene auth.uid(). La pantalla lo dice
  -- como "Desde la base" y no como "Alguien", que son cosas distintas.
  quien    uuid references auth.users(id) on delete set null,
  fuente   text not null,
  accion   text not null,
  -- El nombre de la cosa, congelado. Ver la cabecera.
  sobre    text not null default '',
  detalle  text not null default '',

  constraint bitacora_fuente_valida
    check (fuente in ('catalogo','roles','papeles','citas'))
);

comment on table  public.bitacora        is 'Quién hizo qué y cuándo. Una fila por movimiento; nada se sobrescribe';
comment on column public.bitacora.quien  is 'Null = no se hizo desde el panel (sin sesión)';
comment on column public.bitacora.sobre  is 'El nombre de la cosa EN ESE MOMENTO, no una referencia viva';

-- Se lee siempre de lo más nuevo a lo más viejo y con tope. El índice va
-- por 'cuando' descendente porque esa es la única consulta que existe.
create index if not exists bitacora_reciente on public.bitacora (cuando desc);

alter table public.bitacora enable row level security;

-- Leer: el equipo. Un inversionista no tiene por qué ver quién movió los
-- roles ni qué papeles subieron los demás.
drop policy if exists "bitacora: la lee el equipo" on public.bitacora;
create policy "bitacora: la lee el equipo" on public.bitacora
  for select to authenticated using (public.es_gestor());

-- Y NO hay política de insert, update ni delete. A propósito. Ver la
-- cabecera: si quien actúa pudiera escribir aquí, esto no probaría nada.


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIEN APUNTA
-- ───────────────────────────────────────────────────────────────────────
-- Una sola función para las cuatro tablas. security definer para que
-- pueda escribir donde nadie más puede.
create or replace function public.apunta(
  p_fuente text, p_accion text, p_sobre text, p_detalle text default ''
) returns void
language sql
security definer
set search_path = public
as $$
  insert into public.bitacora (quien, fuente, accion, sobre, detalle)
  values (auth.uid(), p_fuente, p_accion, coalesce(p_sobre, ''), coalesce(p_detalle, ''));
$$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. EL CATÁLOGO
-- ───────────────────────────────────────────────────────────────────────
-- Solo cuando CAMBIA 'activo': renombrar un trámite no es encenderlo.
create or replace function public.bit_catalogo()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.activo is distinct from old.activo then
    perform public.apunta('catalogo',
      case when new.activo then 'encendio' else 'apago' end,
      new.nombre);
  end if;
  return null;
end $$;

drop trigger if exists bitacora_catalogo on public.tipos_tramite;
create trigger bitacora_catalogo
  after update on public.tipos_tramite
  for each row execute function public.bit_catalogo();


-- ───────────────────────────────────────────────────────────────────────
-- 4. LOS ROLES
-- ───────────────────────────────────────────────────────────────────────
create or replace function public.bit_roles()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.rol is distinct from old.rol then
    -- El nombre puede venir vacío; la pantalla lo dice como "Sin nombre".
    perform public.apunta('roles', 'rol', new.nombre_completo, new.rol);
  end if;
  return null;
end $$;

drop trigger if exists bitacora_roles on public.perfiles;
create trigger bitacora_roles
  after update on public.perfiles
  for each row execute function public.bit_roles();


-- ───────────────────────────────────────────────────────────────────────
-- 5. LOS PAPELES
-- ───────────────────────────────────────────────────────────────────────
-- Al borrar se apunta con OLD, que es lo último que se supo del papel. Es
-- el caso que más falta hace: de un papel que ya no está, la bitácora es
-- lo único que queda.
create or replace function public.bit_papeles()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.apunta('papeles', 'subio', new.nombre_original, new.tipo);
    return null;
  end if;
  perform public.apunta('papeles', 'borro', old.nombre_original, old.tipo);
  return null;
end $$;

drop trigger if exists bitacora_papeles_alta on public.documentos;
create trigger bitacora_papeles_alta
  after insert on public.documentos
  for each row execute function public.bit_papeles();

drop trigger if exists bitacora_papeles_baja on public.documentos;
create trigger bitacora_papeles_baja
  after delete on public.documentos
  for each row execute function public.bit_papeles();


-- ───────────────────────────────────────────────────────────────────────
-- 6. LAS CITAS
-- ───────────────────────────────────────────────────────────────────────
-- Se apunta el alta y cada cambio de estado. El estado va en 'detalle'
-- porque la pantalla lo traduce: guardar aquí "Confirmada" en castellano
-- dejaría la bitácora en un idioma para siempre.
create or replace function public.bit_citas()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.apunta('citas', 'pidio', coalesce(new.tipo_tramite, ''), new.estado);
    return null;
  end if;
  if new.estado is distinct from old.estado then
    perform public.apunta('citas', 'movio', coalesce(new.tipo_tramite, ''), new.estado);
  end if;
  return null;
end $$;

drop trigger if exists bitacora_citas_alta on public.citas;
create trigger bitacora_citas_alta
  after insert on public.citas
  for each row execute function public.bit_citas();

drop trigger if exists bitacora_citas_cambio on public.citas;
create trigger bitacora_citas_cambio
  after update on public.citas
  for each row execute function public.bit_citas();


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE, DICHO PARA QUE NO SE DÉ POR HECHO
-- ───────────────────────────────────────────────────────────────────────
-- · La bitácora empieza HOY. Lo que pasó antes de correr esto no está, y
--   no se puede reconstruir. Las dos columnas viejas —rol_cambiado_* y
--   activo_*— se quedan donde están: son lo único que queda de antes.
-- · Los cambios de estado de un trámite siguen en tramite_eventos, que ya
--   era un historial de verdad y no hacía falta duplicar. La pantalla lee
--   de los dos sitios.
-- · Nadie limpia esto. Con el tiempo crece; el día que estorbe, se borra
--   por fecha, y eso es una decisión que se toma entonces y no ahora.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. Los cinco disparadores.
select tgrelid::regclass as tabla, tgname as disparador
from   pg_trigger
where  not tgisinternal
  and  tgname like 'bitacora_%'
order  by tabla, disparador;

-- 2. Que solo se pueda LEER. Tiene que salir una fila, y con cmd SELECT.
--    Si aparece un INSERT, alguien podría inventarse apuntes.
select policyname, cmd from pg_policies
where  schemaname = 'public' and tablename = 'bitacora';

-- 3. Y la prueba de verdad: enciende y apaga un trámite desde el panel, y
--    mira que salgan DOS filas y no una.
select cuando, fuente, accion, sobre, detalle
from   public.bitacora
order  by cuando desc
limit  20;
