-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — BLOQUEAR UNA CUENTA
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: después de supabase-admin.sql. Necesita public.es_admin().
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ES Y QUÉ NO ES
--  ─────────────────────────────────────────────────────────────────────
--  Bloquear NO borra. Los trámites de esa persona, sus papeles y su
--  historial siguen donde estaban: el CIIP recibió esas solicitudes y
--  borrarlas sería reescribir lo que pasó. Lo que se cierra es la puerta.
--
--  Es lo que hace falta el día que alguien se va de la oficina, o cuando
--  hay que parar una cuenta mientras se aclara algo.
--
--  UN BLOQUEO QUE SOLO ESCONDE BOTONES NO ES UN BLOQUEO
--  ─────────────────────────────────────────────────────────────────────
--  Se podría haber hecho solo en la pantalla: que el panel eche a quien
--  esté bloqueado. Eso para a quien entra por la puerta, y a nadie más:
--  la clave anónima está en el código de la página, a la vista de
--  cualquiera, y con ella se puede hablar con la base sin pasar por el
--  panel.
--
--  Así que el bloqueo vive AQUÍ, en tres disparadores que rechazan
--  cualquier escritura de una cuenta bloqueada sobre lo suyo: trámites,
--  papeles y citas. El panel además le cierra la puerta, pero eso es
--  cortesía —para que vea un mensaje en vez de errores—, no la cerradura.
--
--  LO QUE SIGUE PUDIENDO HACER
--  ─────────────────────────────────────────────────────────────────────
--  Leer lo suyo. No se le quita el acceso a su propio expediente, porque
--  bloquear no es castigar: es impedir que siga metiendo cosas. Si algún
--  día hace falta que tampoco lea, eso se hace en las políticas de
--  lectura y es otra decisión.
--
--  NADIE SE BLOQUEA A SÍ MISMO
--  ─────────────────────────────────────────────────────────────────────
--  Igual que con los roles. Un admin que se bloquea deja al CIIP sin
--  quien desbloquee, y eso solo se arregla volviendo aquí.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'es_admin'
  ) then
    raise exception 'Falta public.es_admin(). Pasa antes supabase-admin.sql.';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA COLUMNA
-- ───────────────────────────────────────────────────────────────────────
alter table public.perfiles
  add column if not exists bloqueado      boolean not null default false,
  add column if not exists bloqueado_por  uuid references auth.users(id) on delete set null,
  add column if not exists bloqueado_en   timestamptz;

comment on column public.perfiles.bloqueado is
  'true = no puede escribir nada. Sigue pudiendo leer lo suyo';
comment on column public.perfiles.bloqueado_por is
  'Quién lo bloqueó. Lo pone el disparador, no el cliente';


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN PUEDE BLOQUEAR
-- ───────────────────────────────────────────────────────────────────────
-- Copiado del disparador de los roles: la comprobación vive en la BASE.
-- Esconder el interruptor nunca fue la cerradura.
create or replace function public.guarda_el_bloqueo()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.bloqueado is distinct from old.bloqueado then
    if not public.es_admin() then
      raise exception 'Solo un administrador puede bloquear cuentas';
    end if;
    if new.id = auth.uid() then
      raise exception 'Nadie se bloquea a sí mismo';
    end if;
    new.bloqueado_por := auth.uid();
    new.bloqueado_en  := now();
  end if;
  return new;
end $$;

drop trigger if exists perfiles_bloqueo on public.perfiles;
create trigger perfiles_bloqueo
  before update on public.perfiles
  for each row execute function public.guarda_el_bloqueo();


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA CERRADURA DE VERDAD
-- ───────────────────────────────────────────────────────────────────────
-- stable y no volatile: dentro de una misma sentencia se pregunta una vez
-- y se reusa, en vez de una consulta por fila.
create or replace function public.esta_bloqueado()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.bloqueado from public.perfiles p where p.id = auth.uid()),
    false);
$$;

-- Un disparador por tabla, y el mismo para las tres. Va en BEFORE: si
-- fuera AFTER, la fila ya estaría escrita cuando salta el error y habría
-- que confiar en que la transacción se deshaga.
create or replace function public.corta_si_bloqueado()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.esta_bloqueado() then
    raise exception 'Esta cuenta está bloqueada';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;

drop trigger if exists tramites_bloqueo   on public.tramites;
create trigger tramites_bloqueo
  before insert or update or delete on public.tramites
  for each row execute function public.corta_si_bloqueado();

drop trigger if exists documentos_bloqueo on public.documentos;
create trigger documentos_bloqueo
  before insert or update or delete on public.documentos
  for each row execute function public.corta_si_bloqueado();

drop trigger if exists citas_bloqueo      on public.citas;
create trigger citas_bloqueo
  before insert or update or delete on public.citas
  for each row execute function public.corta_si_bloqueado();


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE
-- ───────────────────────────────────────────────────────────────────────
-- · No cierra la sesión que ya esté abierta en ese momento. La próxima
--   escritura le fallará y el panel le echará al recargar, pero mientras
--   tanto sigue viendo lo que tenía en pantalla.
-- · No le impide LEER lo suyo. Ver la cabecera.
-- · No toca auth.users. Bloquear ahí -banned_until- solo se puede con la
--   clave de servicio, que no puede vivir en una página web.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. Los cuatro disparadores.
select tgrelid::regclass as tabla, tgname as disparador
from   pg_trigger
where  not tgisinternal and tgname like '%bloqueo%'
order  by tabla;

-- 2. Quién está bloqueado ahora mismo. Recién puesto esto, ninguno.
select p.nombre_completo, u.email, p.bloqueado, p.bloqueado_en
from   public.perfiles p join auth.users u on u.id = p.id
where  p.bloqueado
order  by p.bloqueado_en desc;
