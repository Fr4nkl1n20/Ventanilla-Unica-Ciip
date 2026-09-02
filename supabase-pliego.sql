-- ═══════════════════════════════════════════════════════════════════════
--  EL PLIEGO DE DATOS, Y QUIÉN LO ACEPTÓ
--  Va DESPUÉS de supabase-admin.sql y de supabase-gestor.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Del punto 3 del informe del 2 de septiembre de 2026:
--
--    «Protocolo de Protección y Reserva de Datos (Habeas Data): siendo el
--     CIIP depositario de balances contables, composiciones accionarias y
--     transferencias de activos internacionales protegidos bajo el régimen
--     especial de la Ley Constitucional Antibloqueo, resulta mandatorio
--     redactar y vincular formalmente en la plataforma un pliego de
--     Términos, Condiciones y Políticas de Tratamiento de Datos Personales
--     y Confidenciales.»
--
--  LO QUE HABÍA, Y POR QUÉ NO BASTABA
--  ─────────────────────────────────────────────────────────────────────
--  La casilla existía desde el primer día, en acceso.html y en el login:
--
--    «Acepto el tratamiento de mis datos para la gestión de trámites.»
--
--  Y era una casilla, no un consentimiento. Tres agujeros, y ninguno se ve
--  mirando la pantalla:
--
--   1. NO ENLAZABA A NADA. Se aceptaba una frase de doce palabras; no había
--      documento que leer. Consentir requiere saber a qué.
--
--   2. NO QUEDABA REGISTRADO. Ni qué se aceptó, ni cuándo. A la pregunta
--      «¿este inversionista consintió el tratamiento de sus balances?» la
--      respuesta era «no se sabe», que es la peor de las tres posibles.
--
--   3. Y CASI NADIE LA VEÍA. El acceso del CIIP dejó de tener registro
--      propio: las cuentas las crea el equipo. Quien entra por ahí nunca
--      llegaba a marcar nada.
--
--  QUÉ HACE ESTE ARCHIVO, Y QUÉ NO
--  ─────────────────────────────────────────────────────────────────────
--  Hace la MAQUINARIA: versiones del pliego, constancia de quién aceptó
--  cuál y cuándo, y una función que dice si a alguien le falta aceptar.
--
--  NO trae el texto. La tabla nace VACÍA, igual que bancos_aliados y que
--  sectores, y por la misma razón llevada un paso más lejos: un pliego que
--  regula datos protegidos por la Ley Antibloqueo es un instrumento
--  jurídico, y uno redactado sin abogado que llegara a producción dejaría
--  al CIIP respaldado por un texto que no ha firmado nadie.
--
--  Hay un borrador en PLIEGO-BORRADOR.md para que el abogado del CIIP
--  corrija en vez de empezar en blanco. No es el pliego: es la materia
--  prima. Al final de este archivo está el INSERT para publicarlo cuando
--  esté aprobado.
--
--  Mientras la tabla esté vacía NO SE BLOQUEA A NADIE. Una puerta cerrada
--  con nada detrás deja fuera a todo el mundo, y eso ya estaba dicho en
--  supabase-sectores.sql antes de este informe.
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
-- 1. LAS VERSIONES DEL PLIEGO
-- ───────────────────────────────────────────────────────────────────────
-- Versiones y no un texto suelto, y esa es toda la decisión de diseño.
--
-- El pliego va a cambiar: cambia la ley, cambia lo que la ventanilla
-- recoge, entra un organismo nuevo. Si hubiera un solo texto que se
-- reescribe, una aceptación de marzo pasaría a decir que se aceptó lo que
-- el pliego dice HOY, que es exactamente lo que un consentimiento no puede
-- hacer. Es el mismo criterio de ordenes_pago con el monto y de avisos con
-- el destinatario: se guarda lo que valía ENTONCES.

create table if not exists public.pliegos (
  version  integer primary key,
  titulo   text not null,

  -- El texto por idioma: {"es": "...", "en": "..."}.
  --
  -- El castellano es OBLIGATORIO y los demás no, y no es comodidad: el
  -- instrumento que obliga es el venezolano. Los otros idiomas son
  -- cortesía para que el inversionista entienda lo que firma, y la
  -- pantalla lo dice al pie. Un pliego que sólo existiera traducido
  -- dejaría sin saber cuál de las seis versiones es la que vale.
  texto    jsonb not null default '{}'::jsonb,

  vigente  boolean not null default false,

  publicado_en  timestamptz,
  publicado_por uuid references auth.users(id) on delete set null,
  creado_en     timestamptz not null default now(),

  constraint pliegos_texto_es_objeto check (jsonb_typeof(texto) = 'object'),
  -- Sin castellano no hay pliego. Ver arriba.
  constraint pliegos_con_castellano  check (texto ? 'es'),
  constraint pliegos_castellano_no_vacio
    check (length(trim(texto ->> 'es')) > 0),
  -- Uno vigente sin fecha de publicación es un pliego que nadie sabe desde
  -- cuándo obliga.
  constraint pliegos_vigente_con_fecha
    check (not vigente or publicado_en is not null)
);

comment on table  public.pliegos         is 'Las versiones del pliego de tratamiento de datos. Se añaden; no se reescriben';
comment on column public.pliegos.texto   is 'Por idioma. El castellano es el que obliga; los demás son cortesía';
comment on column public.pliegos.vigente is 'La que hay que aceptar hoy. Solo puede haber una';

-- UNA sola vigente. Con dos, la función de abajo devolvería una u otra
-- según le diera, y habría gente aceptando pliegos distintos el mismo día.
create unique index if not exists pliegos_uno_vigente
  on public.pliegos ((true)) where vigente;


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN ACEPTÓ QUÉ, Y CUÁNDO
-- ───────────────────────────────────────────────────────────────────────
-- Append-only, como la constancia de identidad y por lo mismo: un
-- consentimiento que quien lo pide puede reescribir después no prueba
-- nada. No hay política de update ni de delete, y además lo corta un
-- disparador por si mañana alguien añade una.

create table if not exists public.pliego_aceptaciones (
  id      bigint generated always as identity primary key,
  persona uuid    not null references auth.users(id) on delete cascade,
  version integer not null references public.pliegos(version),
  cuando  timestamptz not null default now(),

  -- Una vez por persona y versión. Volver a pulsar no escribe otra fila:
  -- la fecha que importa es la PRIMERA vez que se aceptó.
  constraint pliego_aceptaciones_una_vez unique (persona, version)
);

comment on table public.pliego_aceptaciones is
  'Constancia de que alguien aceptó una version concreta del pliego. Solo se inserta';

create index if not exists pliego_aceptaciones_por_persona
  on public.pliego_aceptaciones (persona, version);

-- La firma la pone la base, igual que en identidad_comprobaciones y en los
-- dos hilos: se ignora lo que venga y se escribe lo que es. Un
-- consentimiento que se puede atribuir a otro es peor que no tenerlo,
-- porque parece fiable.
create or replace function public.pliego_lo_firma_la_base()
returns trigger
language plpgsql
security definer
set search_path = public
as $pliego$
begin
  if auth.uid() is not null then
    new.persona := auth.uid();
    new.cuando  := now();
  end if;
  return new;
end
$pliego$;

drop trigger if exists pliego_aceptacion_firma on public.pliego_aceptaciones;
create trigger pliego_aceptacion_firma
  before insert on public.pliego_aceptaciones
  for each row execute function public.pliego_lo_firma_la_base();

create or replace function public.pliego_aceptacion_no_se_toca()
returns trigger
language plpgsql
as $pliego$
begin
  -- La puerta de servicio, como en las demás tablas: desde el SQL Editor
  -- se puede enderezar a mano lo que haga falta.
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  raise exception 'Un consentimiento no se cambia ni se borra.'
    using errcode = 'check_violation';
end
$pliego$;

drop trigger if exists pliego_aceptacion_inmutable on public.pliego_aceptaciones;
create trigger pliego_aceptacion_inmutable
  before update or delete on public.pliego_aceptaciones
  for each row execute function public.pliego_aceptacion_no_se_toca();


-- ───────────────────────────────────────────────────────────────────────
-- 3. ¿LE FALTA A ALGUIEN ACEPTAR?
-- ───────────────────────────────────────────────────────────────────────
-- Devuelve la versión vigente si quien pregunta no la ha aceptado, y null
-- si no hay nada que aceptar. Null significa las dos cosas —«ya aceptaste»
-- y «todavía no hay pliego»— y está bien que signifique las dos: en los
-- dos casos la respuesta del panel es la misma, dejar pasar.
--
-- Es la pieza que hace que la tabla vacía no bloquee a nadie.

create or replace function public.pliego_pendiente()
returns integer
language sql
stable
security definer
set search_path = public
as $pliego$
  select p.version
    from public.pliegos p
   where p.vigente
     and auth.uid() is not null
     and not exists (
       select 1 from public.pliego_aceptaciones a
        where a.persona = auth.uid() and a.version = p.version
     )
   limit 1;
$pliego$;

-- Y se le quita a anon POR SU NOMBRE.
--
-- Supabase tiene puesto un 'alter default privileges' que concede EXECUTE
-- sobre toda función nueva del esquema public a anon, authenticated y
-- service_role. Ese grant es NOMINAL a cada rol, así que revocárselo a
-- PUBLIC no se lo quita: anon se queda con el suyo. Se vio con
-- tocar_visto() al correr PROBAR-CERRADURAS.bat contra un Supabase de
-- verdad, y en un Postgres normal no pasa, así que ningún arnés local lo
-- veía.
--
-- Aquí anon no se llevaría gran cosa —con auth.uid() nulo devuelve null—
-- pero una puerta que acepta a quien no debería es una puerta abierta.
revoke all on function public.pliego_pendiente() from public;
revoke all on function public.pliego_pendiente() from anon;
grant execute on function public.pliego_pendiente() to authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- 4. QUIÉN LEE Y QUIÉN ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
alter table public.pliegos             enable row level security;
alter table public.pliego_aceptaciones enable row level security;

-- El pliego lo lee cualquiera que haya entrado, incluidas las versiones
-- viejas: quien aceptó la 1 tiene derecho a releer lo que aceptó, aunque
-- hoy rija la 3. Ese es medio habeas data.
drop policy if exists "pliegos: leerlos" on public.pliegos;
create policy "pliegos: leerlos" on public.pliegos
  for select to authenticated using (true);

-- Y solo el admin los publica. Ni el gestor: cambiar el pliego vigente es
-- cambiar a qué está consintiendo todo el mundo.
drop policy if exists "pliegos: solo el admin los publica" on public.pliegos;
create policy "pliegos: solo el admin los publica" on public.pliegos
  for all to authenticated
  using      (public.es_admin())
  with check (public.es_admin());

-- Cada quien ve lo que aceptó. El equipo también: atender un expediente
-- sin poder comprobar si esa persona consintió es atender a ciegas.
drop policy if exists "pliego: cada quien ve lo suyo" on public.pliego_aceptaciones;
create policy "pliego: cada quien ve lo suyo" on public.pliego_aceptaciones
  for select using (persona = auth.uid() or public.es_gestor());

-- Y solo se acepta lo VIGENTE, y solo por uno mismo. Sin lo primero se
-- podría aceptar una versión vieja y más floja que siguiera en la tabla;
-- sin lo segundo, aceptar en nombre de otro.
drop policy if exists "pliego: aceptar el propio" on public.pliego_aceptaciones;
create policy "pliego: aceptar el propio" on public.pliego_aceptaciones
  for insert with check (
    persona = auth.uid()
    -- pliego_aceptaciones.version, ENTERO y no «version» a secas.
    --
    -- Sin cualificar, dentro de la subconsulta «version» se resuelve a la
    -- columna de pliegos -que tambien se llama asi- y la condicion queda
    -- en p.version = p.version: cierta siempre. O sea que la politica
    -- decia comprobar que ESA version fuera la vigente y solo comprobaba
    -- que hubiera alguna vigente, que no es lo mismo.
    --
    -- Lo encontro el sabotaje: quitar esta linea entera no ponia ninguna
    -- prueba en rojo, porque no hacia nada.
    and exists (select 1 from public.pliegos p
                 where p.version = pliego_aceptaciones.version and p.vigente)
  );

-- No hay política de update ni de delete, a propósito. Ver el apartado 2.


-- ───────────────────────────────────────────────────────────────────────
-- 5. CÓMO SE PUBLICA EL PLIEGO CUANDO EL ABOGADO LO APRUEBE
-- ───────────────────────────────────────────────────────────────────────
--  ESTO NO SE EJECUTA SOLO. Está comentado a propósito: mientras nadie lo
--  descomente, la tabla sigue vacía y el panel no le pide nada a nadie.
--
--  El texto sale de PLIEGO-BORRADOR.md, con las correcciones del abogado.
--  Se pega tal cual entre las comillas dobles del jsonb, escapando sólo
--  las comillas dobles que lleve dentro.
--
--    insert into public.pliegos (version, titulo, texto, vigente, publicado_en)
--    values (
--      1,
--      'Términos, Condiciones y Políticas de Tratamiento de Datos',
--      jsonb_build_object('es', $texto$
--    ... aquí el pliego entero, tal como lo aprobó el abogado ...
--    $texto$),
--      true,
--      now()
--    );
--
--  El $texto$ ... $texto$ evita tener que escapar nada: se pega el
--  documento con sus comillas, sus tildes y sus saltos de línea.
--
--  PARA PUBLICAR UNA VERSIÓN NUEVA, más adelante: se apaga la vieja y se
--  inserta la nueva EN LA MISMA transacción, o el índice de arriba rechaza
--  la segunda por haber dos vigentes a la vez.
--
--    begin;
--      update public.pliegos set vigente = false where vigente;
--      insert into public.pliegos (version, titulo, texto, vigente, publicado_en)
--      values (2, '...', jsonb_build_object('es', $texto$...$texto$), true, now());
--    commit;
--
--  La versión vieja NO se borra: quien la aceptó tiene derecho a releerla,
--  y su constancia apunta a ella.
--
--  PARA AÑADIR UNA TRADUCCIÓN a una versión ya publicada —eso sí se puede,
--  porque no cambia lo que obliga—:
--
--    update public.pliegos
--       set texto = texto || jsonb_build_object('en', $texto$...$texto$)
--     where version = 1;


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE, DICHO PARA QUE NO SE DÉ POR HECHO
-- ───────────────────────────────────────────────────────────────────────
-- · No redacta el pliego. Ver la cabecera.
-- · No guarda la IP ni el navegador desde donde se aceptó. Se pensó y se
--   dejó fuera: es un dato personal más que habría que justificar en el
--   propio pliego, y para acreditar el consentimiento bastan quién, qué
--   versión y cuándo. Si el abogado lo pide, se añade.
-- · No borra los datos de nadie. El derecho de supresión que el pliego
--   reconozca se ejerce borrando la cuenta, que ya arrastra en cascada el
--   expediente entero y apunta sus archivos para el barrendero. Que eso
--   funcione ya está probado; que el pliego lo prometa es cosa del texto.
-- · Y la aceptación se va con la cuenta -on delete cascade-, como la
--   constancia de identidad. Es coherente con borrar de verdad cuando a
--   alguien se le borra: guardar la prueba de un consentimiento de quien
--   ya no está sería guardar justo lo que se dijo que se borraba.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Recién puesto esto, la tabla sale VACÍA y no es un fallo: el panel no
--    le pide nada a nadie hasta que haya un pliego aprobado.
--
--   select version, titulo, vigente, publicado_en from public.pliegos;
--
-- 2) Que no quepan dos vigentes. Con uno ya publicado, esto TIENE que
--    fallar; si te deja, el índice no está puesto:
--
--   insert into public.pliegos (version, titulo, texto, vigente, publicado_en)
--   values (99, 'prueba', '{"es":"x"}'::jsonb, true, now());
--
-- 3) Quién ha aceptado y qué versión:
--
--   select u.email, a.version, a.cuando
--   from public.pliego_aceptaciones a join auth.users u on u.id = a.persona
--   order by a.cuando desc;
--
-- 4) Y a quién le falta. Ojo: esta consulta es del EQUIPO y mira a todos;
--    la función pliego_pendiente() mira solo a quien pregunta.
--
--   select u.email
--   from auth.users u
--   where exists (select 1 from public.pliegos p where p.vigente)
--     and not exists (
--       select 1 from public.pliego_aceptaciones a
--        join public.pliegos p on p.version = a.version and p.vigente
--       where a.persona = u.id);
--
-- 5) Que no se pueda reescribir un consentimiento. Desde el SQL Editor SÍ
--    pasa —ahí auth.uid() es null y la puerta de servicio está abierta a
--    propósito—, así que esto se prueba con sesión, y es lo que hace
--    PROBAR-CERRADURAS.bat.
