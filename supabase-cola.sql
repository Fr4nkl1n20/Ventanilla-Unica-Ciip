-- ═══════════════════════════════════════════════════════════════════════
--  LA COLA DE ENVÍOS
--  Va DESPUÉS de supabase-tramites.sql y de supabase-gestor.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  Hasta aquí el panel entero ocurre en el navegador del inversionista.
--  Cuando cierra la pestaña, el sistema se para. Y una ventanilla única
--  es sobre todo trabajo que sucede MIENTRAS TANTO: presentar un
--  expediente, volver a preguntar por él, reintentar cuando el ente no
--  contesta. Eso lo hacía una persona del CIIP a mano, moviendo estados
--  desde la cola del gestor.
--
--  Esta tabla es la lista de lo que hay que hacer cuando nadie mira. No
--  la escribe nadie a mano: la llena un trigger cuando un trámite llega
--  al estado que toca, y la vacía el trabajador
--  (interoperabilidad/trabajador.js).
--
--  DÓNDE ENTRA LA MÁQUINA, Y POR QUÉ AHÍ
--  ─────────────────────────────────────────────────────────────────────
--  En 'en_revision', no en 'enviado'. Lo manda la escalera de estados de
--  supabase-tramites.sql, que sólo deja pasar a 'ante_el_ente' desde
--  'en_revision'. O sea: una persona mira el expediente y lo da por
--  bueno, y ENTONCES la máquina lo presenta. No es una limitación que
--  haya que rodear, es la política correcta escrita en un sitio: lo que
--  se manda a un organismo lo ha visto alguien antes.
--
--  QUÉ NO HACE
--  ─────────────────────────────────────────────────────────────────────
--  No decide nada. Guarda qué hay que hacer, cuándo se puede volver a
--  intentar y cuántas veces se ha intentado ya. Qué significa cada
--  respuesta del organismo lo decide el conector, que se prueba sin base
--  de datos; y qué hacer con esa decisión, el trabajador. Tres piezas y
--  cada una se prueba sola.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. QUÉ TRÁMITES SABE PRESENTAR LA MÁQUINA
-- ───────────────────────────────────────────────────────────────────────
-- Una columna en el catálogo y no una lista en el código: así añadir un
-- conector nuevo es un UPDATE, y un trámite sin conector sigue yendo a
-- mano sin que nada se rompa ni haya que acordarse de excluirlo.
--
-- null = no hay conector todavía. Son 30 de 31 hoy, y está bien que lo
-- sean: escribir el conector de un ente es lo caro, y hasta que exista
-- el trámite se atiende como se ha atendido siempre.

alter table public.tipos_tramite
  add column if not exists conector text;

comment on column public.tipos_tramite.conector is
  'Qué conector lo presenta. null = a mano, como hasta ahora';

-- El del RIF de empresa es el único escrito. Lo activa este UPDATE y no
-- el INSERT del catálogo, que lleva ON CONFLICT DO NOTHING y en una base
-- que ya existe no tocaría nada.
update public.tipos_tramite set conector = 'rif_empresa'
 where codigo = 'rif_empresa';


-- ───────────────────────────────────────────────────────────────────────
-- 2. EL NÚMERO QUE DA EL ORGANISMO
-- ───────────────────────────────────────────────────────────────────────
-- Sin esto no hay forma de volver a preguntar por un expediente: el ente
-- responde por SU número, no por el nuestro. Se guarda en el trámite y no
-- en la cola porque sobrevive a la cola: el trabajo se cierra y el número
-- sigue siendo la referencia del expediente para siempre.

alter table public.tramites
  add column if not exists expediente_ente text;

comment on column public.tramites.expediente_ente is
  'El número que dio el organismo al recibirlo. Es por el que se le pregunta después';


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA COLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.trabajos (
  id        uuid primary key default gen_random_uuid(),
  tramite   uuid not null references public.tramites(id) on delete cascade,

  tarea     text not null,
  estado    text not null default 'pendiente',

  -- No antes de esta hora. Es lo que convierte "reintentar dentro de un
  -- rato" en un dato en vez de en una espera dentro del trabajador: si el
  -- proceso se cae, la espera sigue escrita y la retoma el siguiente.
  cuando    timestamptz not null default now(),
  intentos  smallint not null default 0,

  -- La misma con la que se presentó. Reintentar con ella no abre un
  -- expediente nuevo: el ente devuelve el que ya tenía. Es el id del
  -- trámite, y se copia aquí para que el trabajador no tenga que
  -- deducirla y para que quede escrito con qué llave se mandó.
  llave     text not null,

  ultimo_error   text,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),

  constraint trabajos_tarea_valida
    check (tarea in ('presentar', 'consultar')),

  -- 'alertado' es distinto de 'fallido' a propósito: quiere decir que el
  -- problema es NUESTRO -credenciales, contrato incumplido- y que no lo
  -- arregla reintentar. Un trabajo alertado espera a una persona.
  constraint trabajos_estado_valido
    check (estado in ('pendiente', 'haciendose', 'hecho', 'alertado'))
);

comment on table  public.trabajos       is 'Lo que hay que hacer con los organismos cuando nadie mira';
comment on column public.trabajos.tarea is 'presentar = mandarlo; consultar = preguntar en qué quedó';

-- Sin esto, dos triggers seguidos -o dos trabajadores a la vez- dejaban
-- el mismo trámite dos veces en la cola y se presentaba dos veces. La
-- llave de idempotencia lo salvaría en el ente, pero no hay por qué
-- llegar hasta ahí: se impide aquí.
create unique index if not exists trabajos_sin_repetir
  on public.trabajos (tramite, tarea)
  where estado in ('pendiente', 'haciendose');

-- Por donde lee el trabajador: lo pendiente cuya hora ya pasó, lo más
-- viejo primero.
create index if not exists trabajos_por_hacer
  on public.trabajos (cuando)
  where estado = 'pendiente';

drop trigger if exists trabajos_marca_tiempo on public.trabajos;
create trigger trabajos_marca_tiempo
  before update on public.trabajos
  for each row execute function public.tocar_actualizado_en();


-- ───────────────────────────────────────────────────────────────────────
-- 4. LA COLA SE LLENA SOLA
-- ───────────────────────────────────────────────────────────────────────
-- Igual que el historial, y por la misma razón: si dependiera de que la
-- aplicación se acuerde de encolar, algún día se olvidaría y un trámite
-- se quedaría parado sin que nadie supiera por qué. Lo hace la base, en
-- el mismo sitio donde el estado cambia.

create or replace function public.encolar_trabajo()
returns trigger
language plpgsql
security definer
set search_path = public
as $cola$
declare
  quien text;
  cual  text;
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;

  select conector into quien from public.tipos_tramite where codigo = new.tipo;
  if quien is null then
    return new;   -- se atiende a mano, como siempre
  end if;

  if    new.estado = 'en_revision'  then cual := 'presentar';
  elsif new.estado = 'ante_el_ente' then cual := 'consultar';
  else  return new;
  end if;

  -- ON CONFLICT y no una comprobación previa: entre el select y el
  -- insert cabe otro trigger, y el índice de arriba es quien de verdad
  -- lo impide. Comprobar antes sería creerlo resuelto sin estarlo.
  insert into public.trabajos (tramite, tarea, llave)
  values (new.id, cual, new.id::text)
  on conflict do nothing;

  return new;
end
$cola$;

drop trigger if exists tramites_encolar on public.tramites;
create trigger tramites_encolar
  after update on public.tramites
  for each row execute function public.encolar_trabajo();


-- ───────────────────────────────────────────────────────────────────────
-- 5. QUIÉN LA VE
-- ───────────────────────────────────────────────────────────────────────
-- El trabajador entra con la clave de servidor, que se salta el RLS: no
-- necesita política ninguna. Estas son para las personas.
--
-- El inversionista NO la ve, y es a propósito. No le dice nada que no le
-- diga ya el historial de su trámite -y ese sí está en su idioma-, y en
-- cambio le enseñaría los reintentos y los errores de un organismo, que
-- es ruido nuestro y parece un problema suyo.

alter table public.trabajos enable row level security;

drop policy if exists "trabajos: el equipo los ve" on public.trabajos;
create policy "trabajos: el equipo los ve" on public.trabajos
  for select using (public.es_gestor());

-- Y nadie los escribe a mano, ni el equipo. Los pone el trigger -que es
-- security definer y se salta el RLS- y los mueve el trabajador con la
-- clave de servidor. Un trabajo escrito a mano es un expediente
-- presentado dos veces, o uno que nunca se presenta.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) El trámite con conector, y ningún otro:
--
--   select codigo, conector from public.tipos_tramite where conector is not null;
--
-- 2) La cola, con lo que espera y desde cuándo:
--
--   select tarea, estado, intentos, cuando, ultimo_error
--   from public.trabajos order by cuando;
--
-- 3) Que se llena sola: mueve un rif_empresa a 'en_revision' desde el
--    panel y mira que aparezca su 'presentar'. Si no aparece, el trámite
--    no tenía conector o el trigger no está.
