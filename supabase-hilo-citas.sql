-- ═══════════════════════════════════════════════════════════════════════
--  EL HILO DE UNA CITA
--  Va DESPUÉS de supabase-citas.sql y de supabase-hilo.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  Quien acaba de entrar y no ha empezado ningún trámite no tiene dónde
--  preguntar. El hilo del expediente cuelga de una solicitud, y él no
--  tiene ninguna. Así que sus primeras preguntas —«¿por dónde empiezo?»,
--  «¿mi caso califica?»— salen por correo o por teléfono, y lo que se
--  responda ahí no queda en ninguna parte.
--
--  Es justo el momento en que una ventanilla única se gana o se pierde.
--
--  POR QUÉ AQUÍ Y NO EN UN CHAT SUELTO
--  ─────────────────────────────────────────────────────────────────────
--  Se pensó en un canal general, sin colgar de nada, y es peor por tres
--  razones:
--
--   1. En cuanto hay dos sitios donde escribir, la gente escribe en el que
--      tiene delante. Las preguntas de un trámite acabarían en el general
--      y el hilo del expediente perdería lo único que lo hace valioso: que
--      cada línea sabe de qué solicitud habla.
--   2. Una bandeja sin fondo no tiene cola, ni dueño, ni forma de saber
--      qué está sin contestar. El hilo del expediente funciona porque
--      cuelga de trabajo en marcha que alguien ya tiene abierto.
--   3. Con adjuntos, lo primero que llega en un primer contacto son
--      pasaportes. Sin nada detrás que los sostenga, son papeles sueltos.
--
--  Y no hacía falta inventar nada, porque el sitio ya estaba previsto.
--  supabase-citas.sql lo dice de su propia columna:
--
--    «tipo_tramite — Null = una consulta general, que es un caso legítimo
--     y no un dato que falte: no toda cita es de un trámite.»
--
--  O sea: una cita general YA ES la conversación general. Lo que le
--  faltaba era la vuelta. La cita tiene una nota de ida y ninguna de
--  regreso, así que la conversación se moría ahí y seguía por fuera.
--
--  Esto es esa vuelta. Y cada mensaje sigue colgando de algo que tiene
--  ESTADO y DUEÑO —solicitada, confirmada, hecha, cancelada—, que es lo
--  que convierte «un mensaje» en «algo que alguien tiene que atender».
--
--  LO QUE SE REPITE DE supabase-hilo.sql, Y POR QUÉ SE REPITE
--  ─────────────────────────────────────────────────────────────────────
--  La forma es la misma: la firma la pone la base, el adjunto tiene que
--  ser del dueño, y lo dicho no se reescribe. Son dos tablas y no una
--  porque las llaves foráneas apuntan a sitios distintos —una a tramites
--  y otra a citas— y meterlas juntas obligaría a una columna nula en cada
--  fila y a un check que vigile que exactamente una de las dos está
--  puesta. Más código para ahorrar una tabla.
--
--  Lo que NO se repite es la política que deja al equipo dejar un
--  documento en la bóveda de otro: la de supabase-hilo.sql no menciona
--  trámites, así que vale igual aquí.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────
do $$
begin
  if to_regclass('public.citas') is null then
    raise exception using
      message = 'Falta la tabla public.citas',
      hint    = 'Ejecuta antes supabase-citas.sql en este mismo proyecto.';
  end if;
end $$;


create table if not exists public.cita_mensajes (
  id   uuid primary key default gen_random_uuid(),
  cita uuid not null references public.citas(id) on delete cascade,

  -- Lo pone el trigger con auth.uid(). Sobrevive a la cuenta borrada
  -- -on delete set null- porque un hilo con un hueco donde había una
  -- frase se lee peor que uno con una frase sin nombre.
  autor uuid references auth.users(id) on delete set null,

  -- Copiado al escribir, no releído del perfil. Quien escribió era del
  -- equipo ESE día; que mañana deje de serlo no cambia lo que dijo.
  del_equipo boolean not null default false,

  texto     text not null default '',
  documento uuid references public.documentos(id) on delete set null,

  creado_en timestamptz not null default now(),

  constraint cita_mensaje_dice_algo
    check (length(trim(texto)) > 0 or documento is not null),
  constraint cita_mensaje_cabe check (length(texto) <= 4000)
);

comment on table  public.cita_mensajes            is 'La conversación sobre una cita. Con tipo_tramite null, es la consulta general de quien aún no ha empezado nada';
comment on column public.cita_mensajes.del_equipo is 'Si lo escribió el CIIP. Copiado al escribir: el rol de mañana no cambia lo de ayer';

create index if not exists cita_mensajes_por_cita
  on public.cita_mensajes (cita, creado_en);


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA FIRMA LA PONE LA BASE
-- ───────────────────────────────────────────────────────────────────────
-- Igual que en el hilo del expediente y por lo mismo: un mensaje que se
-- puede atribuir a otro es peor que no tener mensajes, porque parece
-- fiable. Se ignora lo que venga y se pone lo que es.
create or replace function public.cita_mensaje_lo_firma_la_base()
returns trigger
language plpgsql
security definer
set search_path = public
as $hilo$
begin
  new.autor      := auth.uid();
  new.del_equipo := public.es_gestor();
  new.creado_en  := now();
  return new;
end
$hilo$;

drop trigger if exists cita_mensajes_firma on public.cita_mensajes;
create trigger cita_mensajes_firma
  before insert on public.cita_mensajes
  for each row execute function public.cita_mensaje_lo_firma_la_base();


-- ───────────────────────────────────────────────────────────────────────
-- 2. NI EL ADJUNTO SE PUEDE FALSEAR
-- ───────────────────────────────────────────────────────────────────────
-- Sin esto se podría colgar de un mensaje el documento de OTRA persona, y
-- como el hilo enseña sus adjuntos, eso sería una forma de leer la bóveda
-- ajena: adjunta un id cualquiera y mira qué sale.
create or replace function public.adjunto_de_la_misma_cita()
returns trigger
language plpgsql
security definer
set search_path = public
as $hilo$
declare
  duenio  uuid;
  deQuien uuid;
begin
  if new.documento is null then
    return new;
  end if;

  select inversionista into duenio  from public.citas      where id = new.cita;
  select inversionista into deQuien from public.documentos where id = new.documento;

  if deQuien is null or duenio is null or deQuien <> duenio then
    raise exception 'Ese documento no es de esta cita.'
      using errcode = 'check_violation';
  end if;

  return new;
end
$hilo$;

drop trigger if exists cita_mensajes_adjunto on public.cita_mensajes;
create trigger cita_mensajes_adjunto
  before insert on public.cita_mensajes
  for each row execute function public.adjunto_de_la_misma_cita();


-- ───────────────────────────────────────────────────────────────────────
-- 3. LO DICHO NO SE REESCRIBE
-- ───────────────────────────────────────────────────────────────────────
-- No hay política de UPDATE ni de DELETE, y esto lo cierra además por si
-- mañana alguien añade una. Con la puerta de servicio abierta -auth.uid()
-- nulo- para poder quitar a mano algo que no debería estar ahí.
create or replace function public.cita_mensaje_no_se_toca()
returns trigger
language plpgsql
as $hilo$
begin
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  raise exception 'Un mensaje no se cambia ni se borra. Escribe otro.'
    using errcode = 'check_violation';
end
$hilo$;

drop trigger if exists cita_mensajes_inmutable on public.cita_mensajes;
create trigger cita_mensajes_inmutable
  before update or delete on public.cita_mensajes
  for each row execute function public.cita_mensaje_no_se_toca();


-- ───────────────────────────────────────────────────────────────────────
-- 4. QUIÉN LEE Y QUIÉN ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
alter table public.cita_mensajes enable row level security;

drop policy if exists "cita_mensajes: los de mi cita" on public.cita_mensajes;
create policy "cita_mensajes: los de mi cita" on public.cita_mensajes
  for select using (
    public.es_gestor() or exists (
      select 1 from public.citas c
      where c.id = cita and c.inversionista = auth.uid()
    )
  );

-- Escribir: los dos, en los dos sentidos. Eso es todo el punto.
--
-- Y en CUALQUIER estado, cancelada incluida. Se pensó en cerrarlo al
-- cancelar y es peor: «¿por qué se canceló?» y «¿la pedimos para otro
-- día?» son exactamente las dos preguntas que llegan justo después, y
-- mandarlas por otro canal es lo que esto viene a quitar. Lo que ata el
-- hilo no es el estado, es la cita.
drop policy if exists "cita_mensajes: escribir en mi cita" on public.cita_mensajes;
create policy "cita_mensajes: escribir en mi cita" on public.cita_mensajes
  for insert with check (
    public.es_gestor() or exists (
      select 1 from public.citas c
      where c.id = cita and c.inversionista = auth.uid()
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) El hilo de una cita, en orden y diciendo quién habla:
--
--   select creado_en, del_equipo, texto, documento
--   from public.cita_mensajes where cita = '…' order by creado_en;
--
-- 2) Las consultas GENERALES, que son la razón de este archivo: citas sin
--    trámite detrás, con cuántas veces se ha hablado en cada una.
--
--   select c.id, c.estado, c.creado_en,
--          (select count(*) from public.cita_mensajes m where m.cita = c.id) as mensajes
--   from public.citas c
--   where c.tipo_tramite is null
--   order by c.creado_en desc;
--
-- 3) Y que nadie ve el hilo de otro. Eso no se comprueba desde el SQL
--    Editor -ahí auth.uid() es null y RLS no aplica-: hay que entrar con
--    dos cuentas, y es lo que hace PROBAR-CERRADURAS.bat.
