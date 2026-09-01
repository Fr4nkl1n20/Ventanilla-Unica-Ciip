-- ═══════════════════════════════════════════════════════════════════════
--  EL HILO DEL EXPEDIENTE
--  Va DESPUÉS de supabase-tramites.sql y de supabase-gestor.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  Cuando el CIIP devuelve una solicitud escribe una nota: «El
--  comprobante del capital está ilegible: vuelve a subirlo escaneado».
--  Esa nota es de UNA SOLA DIRECCIÓN. El inversionista la lee y no tiene
--  dónde preguntar «¿el escaneado del banco vale, o tiene que ir
--  sellado?». Hoy la única salida es el correo o el teléfono, y lo que se
--  responda por ahí no queda en ningún expediente.
--
--  Esto es esa conversación, y va PEGADA al trámite. No es un chat del
--  panel: es el expediente hablando. Cada línea sabe de qué solicitud es,
--  y por eso «me dijeron que bastaba con el pasaporte» deja de ser una
--  frase suelta.
--
--  POR QUÉ UNA TABLA NUEVA Y NO tramite_eventos
--  ─────────────────────────────────────────────────────────────────────
--  El historial es un registro de CAMBIOS DE ESTADO: cada fila lleva
--  `a_estado`, y la escribe un trigger cuando el estado cambia. Meter ahí
--  los mensajes obligaría a inventarse un estado para cada frase, y el
--  historial —que hoy es exacto— empezaría a contar transiciones que no
--  ocurrieron. Son dos cosas distintas y se guardan aparte.
--
--  LOS ADJUNTOS VAN A LA BÓVEDA
--  ─────────────────────────────────────────────────────────────────────
--  Un mensaje puede llevar un documento, y ese documento es una fila de
--  `documentos` como cualquier otra, con tipo 'otro'. No hay un almacén
--  nuevo ni políticas nuevas: hereda el tope de 10 MB del cubo, la lista
--  de tipos permitidos, la huella SHA-256 y las cuatro políticas de
--  storage que ya existen.
--
--  Y de paso hace lo que hace una ventanilla única: la foto que mandas
--  para aclarar una duda queda en TU bóveda, y si mañana sirve de recaudo
--  no hay que volver a subirla.
-- ═══════════════════════════════════════════════════════════════════════


create table if not exists public.tramite_mensajes (
  id      uuid primary key default gen_random_uuid(),
  tramite uuid not null references public.tramites(id) on delete cascade,

  -- Lo pone el trigger con auth.uid(). Sobrevive a la cuenta borrada
  -- -on delete set null- porque un hilo con un hueco donde había una
  -- frase se lee peor que uno con una frase sin nombre.
  autor uuid references auth.users(id) on delete set null,

  -- Copiado al escribir, no releído del perfil. Quien escribió era del
  -- equipo ESE día; que mañana deje de serlo no cambia lo que dijo, y
  -- releerlo haría que el hilo se reescribiera solo al cambiar un rol.
  del_equipo boolean not null default false,

  texto     text not null default '',
  documento uuid references public.documentos(id) on delete set null,

  creado_en timestamptz not null default now(),

  -- Una de las dos cosas, al menos. Un mensaje vacío sin adjunto no dice
  -- nada y ensucia el hilo.
  constraint mensaje_dice_algo
    check (length(trim(texto)) > 0 or documento is not null),
  -- Límite generoso pero límite: sin él esto es un sitio donde pegar un
  -- libro, y el hilo deja de poder leerse.
  constraint mensaje_cabe check (length(texto) <= 4000)
);

comment on table  public.tramite_mensajes            is 'La conversación sobre una solicitud, entre el inversionista y el CIIP';
comment on column public.tramite_mensajes.del_equipo is 'Si lo escribió el CIIP. Copiado al escribir: el rol de mañana no cambia lo de ayer';
comment on column public.tramite_mensajes.documento  is 'Adjunto, que es una fila de la bóveda como cualquier otra';

create index if not exists mensajes_por_tramite
  on public.tramite_mensajes (tramite, creado_en);


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA FIRMA LA PONE LA BASE
-- ───────────────────────────────────────────────────────────────────────
-- Igual que en la constancia de identidad y por lo mismo: un mensaje que
-- se puede atribuir a otro es peor que no tener mensajes, porque parece
-- fiable. Una política podría comprobar `autor = auth.uid()`, pero
-- entonces habría que acordarse de mandarlo bien desde el panel. Así no
-- hay nada que acordarse: se ignora lo que venga y se pone lo que es.

create or replace function public.mensaje_lo_firma_la_base()
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

drop trigger if exists mensajes_firma on public.tramite_mensajes;
create trigger mensajes_firma
  before insert on public.tramite_mensajes
  for each row execute function public.mensaje_lo_firma_la_base();


-- ───────────────────────────────────────────────────────────────────────
-- 2. NI EL ADJUNTO SE PUEDE FALSEAR
-- ───────────────────────────────────────────────────────────────────────
-- Sin esto, se podría colgar de un mensaje el documento de OTRA persona,
-- y como el hilo enseña sus adjuntos, eso sería una forma de leer la
-- bóveda ajena: adjunta un id cualquiera y mira qué sale.
--
-- El adjunto tiene que pertenecer al dueño del trámite. Vale tanto si lo
-- subió él como si lo dejó el equipo en su carpeta —una resolución, por
-- ejemplo—, porque en los dos casos es SUYO.

create or replace function public.adjunto_del_mismo_expediente()
returns trigger
language plpgsql
security definer
set search_path = public
as $hilo$
declare
  duenio uuid;
  deQuien uuid;
begin
  if new.documento is null then
    return new;
  end if;

  select inversionista into duenio  from public.tramites   where id = new.tramite;
  select inversionista into deQuien from public.documentos where id = new.documento;

  if deQuien is null or duenio is null or deQuien <> duenio then
    raise exception 'Ese documento no es de este expediente.'
      using errcode = 'check_violation';
  end if;

  return new;
end
$hilo$;

drop trigger if exists mensajes_adjunto on public.tramite_mensajes;
create trigger mensajes_adjunto
  before insert on public.tramite_mensajes
  for each row execute function public.adjunto_del_mismo_expediente();


-- ───────────────────────────────────────────────────────────────────────
-- 3. LO DICHO NO SE REESCRIBE
-- ───────────────────────────────────────────────────────────────────────
-- No hay política de UPDATE ni de DELETE, y esto lo cierra además por si
-- mañana alguien añade una. Con la puerta de servicio abierta —auth.uid()
-- nulo— para poder quitar a mano algo que no debería estar ahí: eso es
-- una decisión de persona, no de código.

create or replace function public.mensaje_no_se_toca()
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

drop trigger if exists mensajes_inmutable on public.tramite_mensajes;
create trigger mensajes_inmutable
  before update or delete on public.tramite_mensajes
  for each row execute function public.mensaje_no_se_toca();


-- ───────────────────────────────────────────────────────────────────────
-- 4. QUIÉN LEE Y QUIÉN ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
alter table public.tramite_mensajes enable row level security;

-- El dueño del expediente, y el equipo, que atiende a todos.
drop policy if exists "mensajes: los de mi expediente" on public.tramite_mensajes;
create policy "mensajes: los de mi expediente" on public.tramite_mensajes
  for select using (
    public.es_gestor() or exists (
      select 1 from public.tramites t
      where t.id = tramite and t.inversionista = auth.uid()
    )
  );

-- Escribir: los dos, en los dos sentidos. Eso es todo el punto.
--
-- Y en CUALQUIER estado, incluido un borrador o un trámite ya resuelto.
-- Se pensó en cerrarlo al resolverse y es peor: la pregunta más común
-- llega justo después —«me llegó el RIF, ¿ya puedo abrir la cuenta?»— y
-- mandarla por otro canal es exactamente lo que esto viene a quitar. Lo
-- que ata el hilo no es el estado, es el expediente.
drop policy if exists "mensajes: escribir en mi expediente" on public.tramite_mensajes;
create policy "mensajes: escribir en mi expediente" on public.tramite_mensajes
  for insert with check (
    public.es_gestor() or exists (
      select 1 from public.tramites t
      where t.id = tramite and t.inversionista = auth.uid()
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- 5. Y EL EQUIPO TAMBIÉN PUEDE ADJUNTAR
-- ───────────────────────────────────────────────────────────────────────
-- Un hilo donde sólo una parte puede mandar una foto no es una
-- conversación. Y el adjunto tiene que ser del DUEÑO del expediente —lo
-- exige el trigger de arriba, y con razón—, así que el equipo necesita
-- poder dejar un documento en la bóveda de otro.
--
-- Ya podía, pero sólo uno: `supabase-emision.sql` le deja meter el
-- documento que emitió el ente, con tipo 'resolucion' y estado
-- 'validado'. Una foto aclaratoria no es ninguna de las dos cosas.
--
-- Esta política añade el otro caso, y es deliberadamente estrecha:
--
--   · sólo tipo 'otro'. No puede dejar un pasaporte ni un RIF: si un
--     recaudo con nombre propio apareciera en tu bóveda sin haberlo
--     subido tú, el trámite que lo pide lo daría por presentado.
--   · sólo 'cargado', nunca 'validado'. Lo que manda el CIIP en una
--     conversación es una aclaración, no un papel dado por bueno.
--   · y en la subcarpeta 'emitidos', que es donde el cubo ya le deja
--     escribir dentro de la carpeta de otro.

drop policy if exists "documentos: el equipo adjunta en un hilo" on public.documentos;
create policy "documentos: el equipo adjunta en un hilo" on public.documentos
  for insert
  with check (
    public.es_gestor()
    and tipo = 'otro'
    and estado = 'cargado'
  );


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) El hilo de una solicitud, en orden y diciendo quién habla:
--
--   select creado_en, del_equipo, texto, documento
--   from public.tramite_mensajes where tramite = '…' order by creado_en;
--
-- 2) Que el autor no se puede falsear: manda uno con `autor` de otra
--    persona. Tiene que quedar guardado con el TUYO.
--
-- 3) Que el adjunto ajeno no entra: manda uno con el `documento` de otra
--    persona. La base lo rechaza con «Ese documento no es de este
--    expediente».
--
-- 4) Y que nadie ve el hilo de otro. Eso no se comprueba desde el SQL
--    Editor —ahí auth.uid() es null y RLS no aplica—: hay que entrar con
--    dos cuentas, y es lo que hace PROBAR-CERRADURAS.bat.
