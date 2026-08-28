-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL ACOMPAÑAMIENTO, GOBERNADO DESDE EL PANEL
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: después de supabase-admin.sql. Necesita public.es_admin().
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ARREGLA
--  ─────────────────────────────────────────────────────────────────────
--  La burbuja de acompañamiento, su nube y los tres botones del panel
--  vivían enteros en el código: el marcado fijo, los tiempos en tres
--  constantes y las frases en el diccionario. Cambiar cualquiera de esas
--  cosas era editar el archivo y volver a publicarlo.
--
--  Ahora se gobiernan desde Administración.
--
--  UNA SOLA FILA, Y LA BASE LO GARANTIZA
--  ─────────────────────────────────────────────────────────────────────
--  Esto no es una lista: es LA configuración. Con una tabla normal, el
--  día que dos pestañas guarden a la vez habría dos filas y el panel
--  leería una de las dos según le diera.
--
--  El truco es la clave primaria: una columna booleana que solo admite
--  'true'. Una segunda fila chocaría con la clave primaria y Postgres la
--  rechaza. No hay que acordarse de nada al escribir.
--
--  LOS TEXTOS SON RETOQUES, NO SUSTITUTOS
--  ─────────────────────────────────────────────────────────────────────
--  Las frases siguen viviendo en el diccionario, en los seis idiomas, con
--  su vigilante comprobando que ninguna se quede coja. Lo que se guarda
--  aquí son RETOQUES: si hay uno para tu idioma, manda; si no, se usa el
--  del diccionario.
--
--  Eso contesta la pregunta incómoda —«¿y si alguien escribe la española
--  y deja las otras cinco?»—: las otras cinco siguen diciendo lo que
--  decían. Nunca puede quedar un rótulo en blanco, que es lo que pasaría
--  si esto sustituyera al diccionario en vez de retocarlo.
--
--  LOS TIEMPOS VAN EN MILISEGUNDOS
--  ─────────────────────────────────────────────────────────────────────
--  Como en el código, que es quien los usa. La pantalla los enseña en
--  segundos porque nadie piensa en milisegundos, y hace la cuenta al
--  guardar. Guardar segundos obligaría a multiplicar en cada lectura y
--  el primer olvido daría una nube que sale a los tres milisegundos.
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
-- 1. LA TABLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.acompanamiento (
  -- Ver la cabecera: esto garantiza que solo haya una fila.
  id            boolean primary key default true,

  -- Qué se enseña.
  burbuja       boolean not null default true,
  nube          boolean not null default true,
  b_ciip        boolean not null default true,
  b_invertir    boolean not null default true,
  b_cita        boolean not null default true,

  -- Los tiempos de la nube, en milisegundos.
  nube_espera   integer not null default 3200,
  nube_dura     integer not null default 8400,
  nube_vuelve   integer not null default 180000,

  -- Retoques de texto por idioma. {"es": {"nube": "...", "titulo": "..."}}
  -- Lo que no esté aquí lo pone el diccionario.
  textos        jsonb   not null default '{}'::jsonb,

  actualizado_en  timestamptz not null default now(),
  actualizado_por uuid references auth.users(id) on delete set null,

  constraint acompanamiento_una_fila check (id),
  -- Topes con sentido, no arbitrarios: una nube que asoma antes de medio
  -- segundo aparece encima de una pantalla que todavía se está pintando, y
  -- una que dura menos de dos segundos no da tiempo a leerla. El máximo de
  -- 'vuelve' es una hora: más que eso es no volver.
  constraint acompanamiento_espera_sensata check (nube_espera between 500 and 60000),
  constraint acompanamiento_dura_sensata   check (nube_dura   between 2000 and 60000),
  constraint acompanamiento_vuelve_sensata check (nube_vuelve between 30000 and 3600000),
  constraint acompanamiento_textos_objeto  check (jsonb_typeof(textos) = 'object')
);

comment on table  public.acompanamiento is 'LA configuración del acompañamiento. Una sola fila, garantizada por la clave primaria';
comment on column public.acompanamiento.textos is 'Retoques por idioma. Lo que falte lo pone el diccionario del panel';

-- La fila, si no está. Sin ella el panel no tiene qué leer y se queda con
-- sus valores de siempre, que es correcto pero deja la pantalla de
-- Administración sin nada que enseñar.
insert into public.acompanamiento (id) values (true)
on conflict (id) do nothing;

alter table public.acompanamiento enable row level security;

-- Leer: cualquiera con sesión. La burbuja la ve todo el mundo, así que
-- todo el mundo necesita saber si está encendida.
drop policy if exists "acompanamiento: lo lee cualquiera" on public.acompanamiento;
create policy "acompanamiento: lo lee cualquiera" on public.acompanamiento
  for select to authenticated using (true);

-- Escribir: solo admin, y solo UPDATE. No hay insert ni delete: la fila
-- ya existe y no debe haber otra ni ninguna.
drop policy if exists "acompanamiento: solo el admin lo cambia" on public.acompanamiento;
create policy "acompanamiento: solo el admin lo cambia" on public.acompanamiento
  for update to authenticated
  using      (public.es_admin())
  with check (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN LO TOCÓ
-- ───────────────────────────────────────────────────────────────────────
-- Lo escribe un disparador, como en los roles y en el catálogo: un campo
-- que rellena quien escribe es un campo que quien escribe puede mentir.
create or replace function public.marca_acompanamiento()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.actualizado_por := auth.uid();
  new.actualizado_en  := now();
  return new;
end $$;

drop trigger if exists acompanamiento_quien on public.acompanamiento;
create trigger acompanamiento_quien
  before update on public.acompanamiento
  for each row execute function public.marca_acompanamiento();


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE
-- ───────────────────────────────────────────────────────────────────────
-- · No entra en la bitácora. Cambiar un tiempo de la nube no es un acto
--   que haya que auditar, y llenaría el Rastro de ruido. Quién lo tocó
--   por última vez queda en la propia fila, que para esto basta.
-- · No valida los textos. Si alguien escribe una frase de trescientas
--   letras, la nube se hará grande. La base comprueba tipos y rangos, no
--   buen gusto.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. La fila, con sus valores de fábrica.
select burbuja, nube, b_ciip, b_invertir, b_cita,
       nube_espera, nube_dura, nube_vuelve, textos
from   public.acompanamiento;

-- 2. Las dos políticas: una de leer y una de cambiar. Si falta la de
--    cambiar, la pantalla guardará sin guardar y no dirá nada.
select policyname, cmd from pg_policies
where  schemaname = 'public' and tablename = 'acompanamiento';

-- 3. Y que de verdad no quepa una segunda fila. Esto TIENE que fallar:
--    si te deja insertarla, la garantía de una sola fila no está puesta.
--    Descomenta para probarlo.
-- insert into public.acompanamiento (id) values (true);
