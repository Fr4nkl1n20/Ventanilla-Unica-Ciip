-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — USUARIOS Y ROLES
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-setup.sql y de supabase-gestor.sql.
-- ═══════════════════════════════════════════════════════════════════════
--
--  LO QUE CAMBIA, Y LO QUE NO
--  ─────────────────────────────────────────────────────────────────────
--  Hasta ahora NADIE podía cambiar un rol desde el navegador: el
--  disparador lo rechazaba en cuanto la petición traía sesión de usuario.
--  Para hacer gestor a alguien había que entrar a Supabase y escribir un
--  update a mano. Seguro, y también un cuello de botella de una persona.
--
--  Ahora puede hacerlo un admin desde el panel. Se afloja UNA cosa y se
--  mantienen las otras tres:
--
--    SE AFLOJA   un admin con sesión abierta puede cambiar roles.
--
--    SE MANTIENE que la comprobación vive en la BASE, no en la pantalla.
--                Esconder el botón nunca fue la cerradura.
--    SE MANTIENE que NADIE puede cambiar su propio rol. Un gestor no se
--                asciende a admin, y un admin no se degrada por error
--                dejando al CIIP sin ninguno.
--    SE MANTIENE que el primer admin solo se hace desde aquí. Sin eso,
--                una cuenta cualquiera podría empezar la cadena.
--
--  Y se añade rastro: quién lo cambió y cuándo. Lo escribe el disparador,
--  así que no se puede falsear desde el navegador.
--
--  EL RIESGO QUE ASUMES, DICHO CLARO
--  ─────────────────────────────────────────────────────────────────────
--  Antes, para repartir roles hacía falta ser admin Y tener acceso al
--  panel de Supabase. Ahora basta una sesión de admin. Si alguien roba esa
--  sesión, puede hacer gestor a una cuenta suya y leer todos los
--  expedientes.
--
--  A cambio, el CIIP deja de depender de una sola persona con la llave de
--  la base de datos. Es un intercambio razonable mientras los admin sean
--  pocos y conocidos; deja de serlo el día que haya diez.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
--  1 · ¿ES ADMIN?
-- ───────────────────────────────────────────────────────────────────────
-- Hermana de es_gestor(), pero solo admin. security definer para poder
-- leer perfiles sin entrar en el bucle de sus propias políticas.
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
  );
$$;


-- ───────────────────────────────────────────────────────────────────────
--  2 · RASTRO DE QUIÉN REPARTE LOS ROLES
-- ───────────────────────────────────────────────────────────────────────
alter table public.perfiles
  add column if not exists rol_cambiado_por uuid references auth.users(id) on delete set null,
  add column if not exists rol_cambiado_en  timestamptz;

comment on column public.perfiles.rol_cambiado_por is
  'Quién cambió el rol la última vez. Lo escribe el disparador: no llega del navegador';


-- ───────────────────────────────────────────────────────────────────────
--  3 · EL DISPARADOR, CON LA REGLA NUEVA
-- ───────────────────────────────────────────────────────────────────────
create or replace function public.bloquear_cambio_de_rol()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.rol is not distinct from old.rol then
    return new;
  end if;

  -- Sin sesión: viene del editor de SQL o de un proceso del servidor. Es
  -- como se hace el primer admin, y sigue permitido.
  if auth.uid() is null then
    return new;
  end if;

  if not public.es_admin() then
    raise exception 'Solo un administrador puede cambiar roles';
  end if;

  -- Ni el propio. Un gestor no se asciende, y un admin no se queda sin
  -- serlo por un descuido dejando al CIIP sin ninguno.
  if new.id = auth.uid() then
    raise exception 'Nadie puede cambiar su propio rol';
  end if;

  new.rol_cambiado_por := auth.uid();
  new.rol_cambiado_en  := now();
  return new;
end;
$$;

drop trigger if exists proteger_rol on public.perfiles;
create trigger proteger_rol
  before update on public.perfiles
  for each row execute function public.bloquear_cambio_de_rol();


-- ───────────────────────────────────────────────────────────────────────
--  4 · Y EL PERMISO PARA ESCRIBIR EN LA FILA DE OTRO
-- ───────────────────────────────────────────────────────────────────────
-- El disparador decide QUÉ se puede cambiar; la política decide QUIÉN
-- puede tocar la fila. Hacen falta las dos: sin política, el update no
-- llega a ejecutarse y el disparador no se entera de nada.
--
-- El admin solo puede tocar el rol de otro, no su nombre ni su país: eso
-- lo garantiza el disparador comparando el resto de columnas.
drop policy if exists "perfiles: el admin reparte roles" on public.perfiles;
create policy "perfiles: el admin reparte roles" on public.perfiles
  for update
  using      (public.es_admin())
  with check (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
--  EL PRIMER ADMIN
-- ───────────────────────────────────────────────────────────────────────
-- Sigue haciéndose aquí, sin sesión, y es a propósito: si se pudiera desde
-- el panel, una cuenta cualquiera podría empezar la cadena.
--
--   update public.perfiles set rol = 'admin'
--    where id = (select id from auth.users where email = 'tu@correo');
--
-- COMPROBACIÓN — las dos deben decir true:
--   select public.es_admin();
--   select relrowsecurity from pg_class where relname = 'perfiles';
