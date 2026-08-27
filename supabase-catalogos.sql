-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS CATÁLOGOS, EN MANOS DEL ADMIN
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable: se puede volver a lanzar sin romper nada.
--
--  ORDEN: va después de supabase-tramites.sql, supabase-admin.sql y
--  supabase-sectores.sql. Necesita que public.es_admin() ya exista.
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ARREGLA
--  ─────────────────────────────────────────────────────────────────────
--  Tres catálogos de la ventanilla eran de SOLO LECTURA desde el
--  navegador. Nadie podía tocarlos, tampoco un admin:
--
--    tipos_tramite     qué trámites están encendidos. 31 en el catálogo,
--                      y 'activo' decide si cada uno enseña su formulario
--                      de verdad o solo la escalera decorativa. Es el
--                      interruptor más importante del producto.
--    bancos_aliados    la red de bancos con los que se abren cuentas.
--    tipos_documento   qué recaudos sabe recibir la ventanilla, y cuáles
--                      caducan —de eso depende que el formulario pida la
--                      fecha de vencimiento—.
--
--  Para cambiar cualquiera de las tres había que entrar aquí, a Supabase,
--  y escribir un update a mano. Es decir: encender un trámite dependía de
--  que estuviera disponible quien supiera SQL.
--
--  (sectores ya tenía su política de admin desde supabase-sectores.sql;
--  aquí no se toca.)
--
--  POR QUÉ ESTO NO ES COSMÉTICO
--  ─────────────────────────────────────────────────────────────────────
--  RLS no da error cuando bloquea: un update sin política contesta que
--  todo fue bien y no cambia ni una fila. Si el panel enseñara un
--  interruptor sin esto puesto, se encendería en pantalla, no haría nada,
--  y no avisaría a nadie. Un botón que miente es peor que un botón que
--  falta.
--
--  Por eso el panel, además, comprueba que la fila vuelva: pide .select()
--  después de escribir y, si no vuelve nada, lo dice. Las dos mitades del
--  mismo cuidado.
--
--  EL RIESGO QUE ASUMES, DICHO CLARO
--  ─────────────────────────────────────────────────────────────────────
--  Un admin con la sesión abierta puede apagar un trámite que está en uso.
--  Los expedientes ya enviados NO se tocan —siguen en 'tramites' con su
--  historial— pero el trámite deja de ofrecerse a quien no lo haya
--  empezado, y quien lo tenga a medias deja de ver el formulario.
--
--  Apagar no borra. Es la diferencia que hace que esto se pueda dar a un
--  admin sin miedo: lo peor que puede hacer es esconder algo, y se
--  vuelve a encender con el mismo botón.
--
--  LO QUE NO SE AFLOJA
--  ─────────────────────────────────────────────────────────────────────
--  · Leer sigue abierto a cualquier sesión: el catálogo lo necesita el
--    panel de todo el mundo para pintar las tarjetas.
--  · Escribir es SOLO para admin. Ni el gestor ni el inversionista.
--  · La comprobación vive en la BASE. Esconder el botón nunca fue la
--    cerradura, y esta vez tampoco.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────
-- Sin es_admin() esto no se sostiene, y fallar aquí con un mensaje claro
-- es mejor que crear políticas que llaman a una función que no existe.
do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'es_admin'
  ) then
    raise exception 'Falta public.es_admin(). Pasa antes supabase-admin.sql.';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LOS TRÁMITES: EL INTERRUPTOR
-- ───────────────────────────────────────────────────────────────────────
-- Se permite UPDATE y no 'for all' a propósito. Un admin enciende y apaga
-- lo que hay; inventarse un trámite nuevo o borrar uno del catálogo es
-- otra cosa —arrastra su ref_panel, su tarjeta y sus recaudos— y esa sigue
-- pidiendo pasar por aquí, que es donde se ve el estropicio antes de
-- hacerlo.
alter table public.tipos_tramite enable row level security;

drop policy if exists "tipos_tramite: el admin enciende y apaga" on public.tipos_tramite;
create policy "tipos_tramite: el admin enciende y apaga"
  on public.tipos_tramite for update to authenticated
  using      (public.es_admin())
  with check (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 2. LOS BANCOS ALIADOS
-- ───────────────────────────────────────────────────────────────────────
-- Aquí sí va 'for all': la red de bancos cambia —entra uno, sale otro— y
-- eso es mantenimiento de lista, no cirugía. Un banco de más en el
-- desplegable no rompe ningún expediente.
alter table public.bancos_aliados enable row level security;

drop policy if exists "bancos_aliados: solo el admin escribe" on public.bancos_aliados;
create policy "bancos_aliados: solo el admin escribe"
  on public.bancos_aliados for all to authenticated
  using      (public.es_admin())
  with check (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 3. LOS RECAUDOS QUE SABE RECIBIR LA VENTANILLA
-- ───────────────────────────────────────────────────────────────────────
-- Solo UPDATE, y por la misma razón que en los trámites: el código de un
-- recaudo lo referencian los documentos ya subidos —documentos.tipo apunta
-- aquí— y borrar uno se llevaría por delante papeles de gente. Cambiar su
-- nombre, o si caduca, no le hace daño a nadie.
alter table public.tipos_documento enable row level security;

drop policy if exists "tipos_documento: el admin lo mantiene" on public.tipos_documento;
create policy "tipos_documento: el admin lo mantiene"
  on public.tipos_documento for update to authenticated
  using      (public.es_admin())
  with check (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. Las políticas. Esto es lo que de verdad dice si funcionó: tiene que
--    salir una línea por cada una de las nuevas —UPDATE en tipos_tramite,
--    ALL en bancos_aliados, UPDATE en tipos_documento— y las de leer
--    intactas al lado. Si falta alguna, el interruptor del panel se
--    encenderá sin cambiar nada.
select tablename, cmd, policyname
from   pg_policies
where  schemaname = 'public'
  and  tablename in ('tipos_tramite', 'bancos_aliados', 'tipos_documento', 'sectores')
order  by tablename, cmd, policyname;

-- 2. Quién es admin. Las políticas de arriba no sirven de nada si tu
--    cuenta no lo es: el panel te enseñaría la lista y cada botón diría
--    que la base no dejó.
--
--    Si aquí no sale tu cuenta, el primer admin se hace desde este mismo
--    editor —está explicado en supabase-admin.sql—; desde el navegador no
--    se puede empezar la cadena, y eso es a propósito.
select p.rol, p.nombre_completo, u.email
from   public.perfiles p
join   auth.users u on u.id = p.id
where  p.rol in ('admin', 'gestor')
order  by p.rol, u.email;

-- NO se pregunta aquí por public.es_admin(). Esa función mira auth.uid()
-- —quién tiene la sesión abierta— y este editor no corre como un usuario:
-- corre como postgres, sin sesión. Devolvería false siempre, también con
-- todo bien puesto, y una comprobación que solo sabe decir que no es peor
-- que ninguna. Donde sí vale es en el navegador, y ahí la hace la propia
-- política cada vez que el panel escribe.


-- ───────────────────────────────────────────────────────────────────────
-- 4. Y QUE EL INTERRUPTOR DEJE RASTRO
-- ───────────────────────────────────────────────────────────────────────
-- Encender o apagar un trámite es de las cosas más consecuentes que puede
-- hacer un admin —cambia lo que la ventanilla ofrece a todo el mundo— y
-- hasta ahora no quedaba constancia de quién lo hizo. La pantalla de
-- Rastro lo decía en voz alta, que es mejor que callarlo, pero decirlo no
-- es arreglarlo.
--
-- Se copia lo que ya hace supabase-admin.sql con los roles: lo escribe un
-- DISPARADOR y no el navegador. Un campo que rellena quien escribe es un
-- campo que quien escribe puede mentir.
alter table public.tipos_tramite
  add column if not exists activo_por uuid references auth.users(id) on delete set null,
  add column if not exists activo_en  timestamptz;

comment on column public.tipos_tramite.activo_por is
  'Quién encendió o apagó este trámite. Lo pone el disparador, no el cliente';
comment on column public.tipos_tramite.activo_en is
  'Cuándo se movió el interruptor por última vez';

-- Solo cuando CAMBIA 'activo'. Sin esta guarda, cualquier update sobre la
-- fila —renombrar el trámite, corregir el ente— reescribiría la fecha y el
-- rastro diría que alguien lo encendió cuando solo le arreglaron una tilde.
create or replace function public.marca_quien_movio_el_interruptor()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.activo is distinct from old.activo then
    new.activo_por := auth.uid();
    new.activo_en  := now();
  end if;
  return new;
end $$;

drop trigger if exists tipos_tramite_rastro on public.tipos_tramite;
create trigger tipos_tramite_rastro
  before update on public.tipos_tramite
  for each row execute function public.marca_quien_movio_el_interruptor();

-- Lo que ESTO no resuelve, dicho para que no se dé por resuelto: se guarda
-- el ÚLTIMO movimiento de cada trámite, no su historial. Igual que los
-- roles. Si algún día hace falta saber que se encendió y se apagó tres
-- veces en una semana, eso pide una tabla de bitácora, no una columna.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN DEL RASTRO
-- ───────────────────────────────────────────────────────────────────────
-- Tiene que salir el disparador. Si no está, el panel seguirá enseñando
-- los trámites sin autor y nadie sabrá por qué.
select tgname as disparador, tgrelid::regclass as tabla
from   pg_trigger
where  not tgisinternal and tgrelid = 'public.tipos_tramite'::regclass;
