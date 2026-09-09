-- ═══════════════════════════════════════════════════════════════════════════
--  LA CONSULTA: HABLAR CON EL CIIP SIN PEDIR CITA
-- ═══════════════════════════════════════════════════════════════════════════
--
--  QUÉ PROBLEMA RESUELVE
--
--  Hasta ahora, un inversionista que quería que el CIIP le llevara un trámite
--  —o que simplemente tenía una duda— sólo tenía una puerta: agendar una cita.
--  Eso obliga a reservar una hora para preguntar algo que se contesta en dos
--  líneas, y deja al equipo sin enterarse de la petición hasta que llega el
--  día. La cita es cara para las dos partes y no debería ser la única entrada.
--
--  Esto abre la otra: una CONSULTA. El inversionista la abre, el equipo la ve
--  en su cola, y se habla por escrito. La cita se queda para cuando de verdad
--  haga falta hablar, que es lo que siempre debió ser.
--
--
--  POR QUÉ UNA TABLA NUEVA Y NO UN ESTADO MÁS EN 'tramites'
--
--  Se pensó en meterlo en tramites con un estado 'consulta'. No sirve, y la
--  razón es la misma que hace que esto funcione: una consulta puede NO tener
--  trámite. «¿Necesito visa para esto?» no es una solicitud de nada. Metida
--  en tramites obligaría a inventar un tipo falso y a que 'tipo' —que hoy
--  apunta al catálogo con una clave foránea de verdad— dejara de significar
--  lo que significa.
--
--  Y al revés: una consulta SÍ puede colgar de un trámite, y por eso está la
--  columna. El botón «que lo hagan ustedes» de una ficha abre la consulta con
--  ese trámite dentro; la burbuja la abre suelta. Son la misma cosa entrando
--  por dos sitios, y por eso comparten cola: si fueran dos tablas, el equipo
--  tendría que mirar en dos bandejas y una de las dos se quedaría sin mirar.
--
--
--  LO QUE ESTO NO ES
--
--  No es un chat en vivo, y la diferencia importa. Un chat promete que hay
--  alguien AHORA; el equipo del CIIP no está las veinticuatro horas, y un
--  inversionista en Italia escribiendo a medianoche se encontraría el silencio
--  y sacaría la conclusión de que la ventanilla no funciona. Esto es un
--  ticket con forma de conversación: se escribe cuando sea, se responde en
--  horario, y la respuesta llega por el aviso que ya existe.
--
--  Por eso NO hay aquí nada de Realtime. La pantalla relee mientras está
--  abierta y ya está. Si algún día el CIIP quiere el socket, esta tabla vale
--  igual: lo que cambia es quién avisa, no lo que se guarda.
-- ═══════════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────────
-- Las políticas de aquí abajo se apoyan en es_gestor(), y los disparadores en
-- funciones que crea la sección del hilo del expediente. Sin eso, esto se
-- crearía a medias y con las puertas abiertas: mejor que no pase nada.
do $$
begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'es_gestor'
  ) then
    raise exception 'Falta public.es_gestor(). Pasa antes las secciones de arriba.';
  end if;

  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'mensaje_lo_firma_la_base'
  ) then
    raise exception 'Falta public.mensaje_lo_firma_la_base(). Pasa antes la sección del hilo.';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────────
-- 1. LA CONSULTA
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.consultas (
  id            uuid primary key default gen_random_uuid(),
  inversionista uuid not null references auth.users(id) on delete cascade,

  -- De qué trámite habla, si habla de alguno. Nula a propósito: media razón
  -- de existir de esta tabla son las consultas que no cuelgan de nada.
  --
  -- 'set null' y no 'cascade': si el trámite se borra, la conversación no se
  -- va con él. Lo que se dijo se dijo, y el equipo puede necesitar releerlo
  -- justamente porque el expediente ya no está.
  tramite       uuid references public.tramites(id) on delete set null,

  -- De qué CLASE de trámite habla, que no es lo mismo. Cuando alguien pulsa
  -- «que lo hagan ustedes» en una ficha todavía no hay expediente: no ha
  -- rellenado nada, que es justamente por lo que pide ayuda. Lo único que
  -- hay es el código del catálogo, y sin esta columna se perdería —el equipo
  -- vería «Acreditación de representación legal» escrito en el asunto y no
  -- tendría forma de enlazarlo con el trámite de verdad—.
  tipo          text references public.tipos_tramite(codigo),

  -- De qué va, en una línea. Lo escribe el inversionista o lo pone el panel
  -- cuando nace desde una ficha ("Acreditación de representación legal").
  asunto        text not null default '',

  -- Los mismos tres momentos que tiene cualquier cola: nadie la ha cogido,
  -- alguien la lleva, se acabó. Deliberadamente NO se copian los seis estados
  -- de un trámite: una consulta no va a ningún organismo.
  estado        text not null default 'abierta',

  -- Quién del CIIP la lleva. Null = sin asignar, que es lo que la hace salir
  -- en la cola. Igual que en tramites.gestor.
  gestor        uuid references auth.users(id) on delete set null,

  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  resuelto_en    timestamptz,

  constraint consultas_estado_valido
    check (estado in ('abierta','en_curso','resuelta')),

  -- Un asunto de tres letras no dice nada, y uno de mil no cabe en la cola.
  constraint consultas_asunto_cabe
    check (length(asunto) <= 200)
);

comment on table  public.consultas         is 'Una conversación con el CIIP, con o sin trámite detrás. La alternativa a pedir cita';
comment on column public.consultas.tramite is 'De qué trámite habla. Null = consulta suelta, que es la mitad del motivo de esta tabla';
comment on column public.consultas.tipo    is 'De qué clase de trámite habla. Lo pone la ficha, que sabe el código pero todavía no tiene expediente';
comment on column public.consultas.gestor  is 'Quién del CIIP la lleva. Null = sin asignar, que es lo que la cola busca';

-- La cola del equipo: las que nadie lleva, las más viejas primero.
create index if not exists consultas_cola
  on public.consultas (estado, creado_en)
  where estado in ('abierta','en_curso');

create index if not exists consultas_por_inversionista
  on public.consultas (inversionista, creado_en);


-- ───────────────────────────────────────────────────────────────────────────
-- 2. LO QUE NO DECIDE QUIEN LA ABRE
-- ───────────────────────────────────────────────────────────────────────────
-- Igual que la firma de un mensaje: de quién es, en qué estado nace y quién
-- la lleva NO se mandan desde el navegador. Si se aceptaran, cualquiera con
-- la clave anon podría abrir una consulta a nombre de otro, o nacerla ya
-- 'resuelta' —que es la forma más limpia de que el equipo no la vea nunca—.
create or replace function public.consulta_la_firma_la_base()
returns trigger
language plpgsql
security definer
set search_path = public
as $con$
begin
  -- Desde el SQL Editor auth.uid() es null, y ahí se entra a propósito por la
  -- puerta de servicio: sembrar datos de ejemplo tiene que seguir siendo
  -- posible. Con sesión, manda la sesión.
  if auth.uid() is not null then
    new.inversionista := auth.uid();
    new.estado        := 'abierta';
    new.gestor        := null;
    new.resuelto_en   := null;
  end if;
  new.creado_en      := now();
  new.actualizado_en := now();
  return new;
end
$con$;

drop trigger if exists consultas_firma on public.consultas;
create trigger consultas_firma
  before insert on public.consultas
  for each row execute function public.consulta_la_firma_la_base();


-- Y al cambiarla: la hora se pone sola, y 'resuelto_en' cuadra con el estado.
-- Sin esto, una consulta puede quedar 'resuelta' sin fecha o con la fecha de
-- cuando se resolvió la vez anterior, y el informe de cuánto tarda el equipo
-- en contestar mide humo.
create or replace function public.consulta_al_cambiar()
returns trigger
language plpgsql
as $con$
begin
  new.actualizado_en := now();

  if new.estado = 'resuelta' and old.estado <> 'resuelta' then
    new.resuelto_en := now();
  elsif new.estado <> 'resuelta' then
    new.resuelto_en := null;
  end if;

  -- De quién es no se cambia nunca. Una consulta que cambia de dueño es una
  -- conversación privada que aparece en la pantalla de otro.
  new.inversionista := old.inversionista;
  return new;
end
$con$;

drop trigger if exists consultas_cambio on public.consultas;
create trigger consultas_cambio
  before update on public.consultas
  for each row execute function public.consulta_al_cambiar();


-- ───────────────────────────────────────────────────────────────────────────
-- 3. LA CONVERSACIÓN
-- ───────────────────────────────────────────────────────────────────────────
-- Calcada de tramite_mensajes, y a propósito: el panel pinta los hilos con
-- una sola función que recibe la tabla y la columna. Una forma distinta aquí
-- obligaría a una segunda función casi igual, que es de donde salen los dos
-- comportamientos que se separan sin que nadie lo note.
create table if not exists public.consulta_mensajes (
  id       uuid primary key default gen_random_uuid(),
  consulta uuid not null references public.consultas(id) on delete cascade,

  autor uuid references auth.users(id) on delete set null,

  del_equipo boolean not null default false,

  texto     text not null default '',
  documento uuid references public.documentos(id) on delete set null,

  creado_en timestamptz not null default now(),

  constraint consulta_mensaje_dice_algo
    check (length(trim(texto)) > 0 or documento is not null),
  constraint consulta_mensaje_cabe check (length(texto) <= 4000)
);

comment on table public.consulta_mensajes is 'La conversación de una consulta. Misma forma que la de un expediente, a propósito';

create index if not exists consulta_mensajes_por_consulta
  on public.consulta_mensajes (consulta, creado_en);

-- La firma la pone la base, con la MISMA función que el hilo del expediente:
-- pone autor, del_equipo y la hora, y no mira de qué tabla viene. Copiarla
-- habría sido dejar dos sitios donde arreglar el mismo fallo.
drop trigger if exists consulta_mensajes_firma on public.consulta_mensajes;
create trigger consulta_mensajes_firma
  before insert on public.consulta_mensajes
  for each row execute function public.mensaje_lo_firma_la_base();

-- Y lo dicho no se reescribe, también con la de allí.
drop trigger if exists consulta_mensajes_inmutable on public.consulta_mensajes;
create trigger consulta_mensajes_inmutable
  before update or delete on public.consulta_mensajes
  for each row execute function public.mensaje_no_se_toca();


-- El adjunto tiene que ser de la bóveda del dueño de la consulta. La función
-- del expediente mira public.tramites y aquí no vale: ésta mira consultas.
create or replace function public.adjunto_de_la_misma_consulta()
returns trigger
language plpgsql
security definer
set search_path = public
as $con$
declare
  duenio  uuid;
  deQuien uuid;
begin
  if new.documento is null then
    return new;
  end if;

  select inversionista into duenio  from public.consultas  where id = new.consulta;
  select inversionista into deQuien from public.documentos where id = new.documento;

  if deQuien is null or duenio is null or deQuien <> duenio then
    raise exception 'Ese documento no es de esta consulta.'
      using errcode = 'check_violation';
  end if;

  return new;
end
$con$;

drop trigger if exists consulta_mensajes_adjunto on public.consulta_mensajes;
create trigger consulta_mensajes_adjunto
  before insert on public.consulta_mensajes
  for each row execute function public.adjunto_de_la_misma_consulta();


-- ───────────────────────────────────────────────────────────────────────────
-- 4. QUIÉN LEE Y QUIÉN ESCRIBE
-- ───────────────────────────────────────────────────────────────────────────
alter table public.consultas         enable row level security;
alter table public.consulta_mensajes enable row level security;

-- LAS CONSULTAS ────────────────────────────────────────────────────────────
drop policy if exists "consultas: las mias" on public.consultas;
create policy "consultas: las mias" on public.consultas
  for select using (
    public.es_gestor() or inversionista = auth.uid()
  );

-- Abrir una es de cualquiera con sesión, y sólo a su nombre. El 'with check'
-- parece redundante con el disparador que ya pone auth.uid(); no lo es: el
-- disparador se salta cuando auth.uid() es null —la puerta de servicio— y la
-- política es la que se queda cerrada de todas formas.
drop policy if exists "consultas: abrir la mia" on public.consultas;
create policy "consultas: abrir la mia" on public.consultas
  for insert with check (
    inversionista = auth.uid()
  );

-- Cambiarla es del equipo: tomarla, ponerla en curso, cerrarla. El
-- inversionista no la cierra —cerrarla es decir «esto ya está contestado», y
-- eso lo dice quien contesta—; lo que puede hacer siempre es escribir otro
-- mensaje, que es lo que la reabre en la práctica.
drop policy if exists "consultas: las lleva el equipo" on public.consultas;
create policy "consultas: las lleva el equipo" on public.consultas
  for update using (public.es_gestor()) with check (public.es_gestor());

-- Nadie borra una consulta. La conversación con un inversionista es registro.
-- No hay política de delete, y sin política no se borra.

-- LOS MENSAJES ─────────────────────────────────────────────────────────────
drop policy if exists "consulta_mensajes: los de mi consulta" on public.consulta_mensajes;
create policy "consulta_mensajes: los de mi consulta" on public.consulta_mensajes
  for select using (
    public.es_gestor() or exists (
      select 1 from public.consultas c
      where c.id = consulta and c.inversionista = auth.uid()
    )
  );

drop policy if exists "consulta_mensajes: escribir en mi consulta" on public.consulta_mensajes;
create policy "consulta_mensajes: escribir en mi consulta" on public.consulta_mensajes
  for insert with check (
    public.es_gestor() or exists (
      select 1 from public.consultas c
      where c.id = consulta and c.inversionista = auth.uid()
    )
  );


-- ───────────────────────────────────────────────────────────────────────────
-- 5. CÓMO COMPROBAR QUE QUEDÓ BIEN
-- ───────────────────────────────────────────────────────────────────────────
-- Desde el SQL Editor NO sirve para probar las cerraduras: ahí auth.uid() es
-- null y la puerta de servicio está abierta a propósito. Estas dos sí valen
-- desde aquí, porque miran la forma y no el permiso:
--
--   1) Que las dos tablas están cerradas:
--
--      select relname, relrowsecurity
--        from pg_class
--       where relname in ('consultas','consulta_mensajes');
--      -- las dos tienen que decir 't'
--
--   2) Que ningún estado se coló:
--
--      select estado, count(*) from public.consultas group by estado;
--
-- Lo que hay que probar CON SESIÓN, y es lo que de verdad importa:
--
--   3) Que un inversionista no ve la consulta de otro. Entrando con la cuenta
--      de prueba A, 'select * from consultas' tiene que devolver sólo las
--      suyas —cero filas de B, no un error—.
--
--   4) Que no puede cerrarse una consulta él mismo: un update poniendo
--      estado='resuelta' tiene que no cambiar nada.
--
--   5) Que no puede abrir una a nombre de otro: un insert con
--      inversionista = <el id de B> tiene que ser rechazado.
