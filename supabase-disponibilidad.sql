-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL HORARIO DE CITAS DEL CIIP
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable: todo va con "if not exists", "create or replace" o
--  "drop ... if exists".
--
--  ORDEN: va DESPUÉS de supabase-citas.sql (añade una columna a citas) y
--  de supabase-tramites.sql, de donde sale public.es_gestor().
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ CAMBIA, Y POR QUÉ
--  ─────────────────────────────────────────────────────────────────────
--  supabase-citas.sql dejó escrito que aquí no habría agenda con huecos:
--  «publicar huecos que nadie mantiene es enseñar horas que no existen».
--  El 11 de septiembre de 2026 el CIIP decidió lo contrario: es el CIIP
--  quien pone los días en que hay citas, y el inversionista elige uno.
--
--  Lo que aquel comentario temía sigue siendo verdad, y por eso esto no es
--  solo una tabla de huecos:
--
--    · El horario es SEMANAL (lunes de 9 a 12, cada 30 minutos...). Se
--      mantiene solo: no hay que acordarse de publicar la semana que viene.
--    · Los días que no se atiende -feriados, vacaciones- se CIERRAN aparte.
--      Sin eso el horario enseñaría el 24 de diciembre como un lunes más.
--    · Un hueco reservado lo es para todos a la vez: un índice único impide
--      que dos personas se queden con el mismo, aunque pulsen en el mismo
--      segundo.
--    · Reservar lo hace la BASE, no el navegador: comprueba que el hueco
--      existe en el horario, que no está cerrado, que está libre y que es
--      futuro. Desde el navegador se podría mandar cualquier hora.
--
--  Y lo que NO cambia: una cita pedida a la antigua -una ventana de días,
--  y el CIIP pone la hora- sigue siendo válida. Mientras el CIIP no
--  publique horario, el panel pide así, como hasta ahora.
--
--  LA HORA ES LA DE VENEZUELA. El horario se escribe en hora de Caracas
--  (America/Caracas, UTC-4) y la cita se guarda como timestamptz: quien la
--  mire desde Italia la verá traducida a su hora, pero el hueco es el del
--  CIIP.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL HORARIO SEMANAL
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.horario_citas (
  id        uuid primary key default gen_random_uuid(),

  -- 1 = lunes ... 7 = domingo, como isodow de Postgres. Así el mismo
  -- número vale en la base y en la pantalla, sin traducir domingos.
  dia       smallint not null,
  desde     time not null,
  hasta     time not null,
  -- Cada cuántos minutos empieza un hueco. Un hueco de 30 minutos que
  -- empieza a las 11:45 no cabe en un tramo que acaba a las 12:00, y no se
  -- ofrece.
  cada_min  smallint not null default 30,

  creado_en timestamptz not null default now(),

  -- De lunes a viernes. El CIIP no atiende fines de semana, y un tramo en
  -- sabado seria un hueco que el panel ofreceria a los inversionistas sin
  -- que nadie lo hubiera decidido. La numeracion sigue siendo la de
  -- isodow -1 lunes, 7 domingo- para no traducir dias entre la base y la
  -- pantalla; lo que cambia es cuales valen.
  constraint horario_dia_valido   check (dia between 1 and 5),
  constraint horario_tramo_valido check (hasta > desde),
  constraint horario_cada_valido  check (cada_min between 10 and 240)
);

comment on table  public.horario_citas          is 'Cuándo atiende el CIIP, semana a semana. Lo edita el equipo desde el panel';
comment on column public.horario_citas.dia      is '1 lunes ... 5 viernes (isodow). Sin fines de semana';
comment on column public.horario_citas.desde    is 'Hora de Caracas en que empieza el tramo';
comment on column public.horario_citas.hasta    is 'Hora de Caracas en que acaba: el último hueco tiene que caber antes';
comment on column public.horario_citas.cada_min is 'Duración de cada hueco, en minutos';


-- ───────────────────────────────────────────────────────────────────────
-- 2. LOS DÍAS QUE NO SE ATIENDE
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.cierres_citas (
  fecha     date primary key,
  motivo    text not null default '',
  creado_en timestamptz not null default now(),

  constraint cierre_motivo_cabe check (length(motivo) <= 200),
  -- Cerrar un sabado no significa nada: ese dia ya no hay citas. Dejarlo
  -- pasar llena la lista de cierres de dias que nunca estuvieron abiertos,
  -- y al mirarla ya no se distingue el feriado de verdad.
  constraint cierre_dia_laborable check (extract(isodow from fecha) between 1 and 5)
);

comment on table public.cierres_citas is 'Días sin citas aunque el horario diga lo contrario: feriados, vacaciones';


-- ───────────────────────────────────────────────────────────────────────
-- 3. QUIÉN PUEDE QUÉ
-- ───────────────────────────────────────────────────────────────────────
-- Leerlos, cualquiera con sesión: el inversionista necesita el horario para
-- saber qué ofrecerse. Tocarlos, solo el equipo.
alter table public.horario_citas enable row level security;
alter table public.cierres_citas enable row level security;

drop policy if exists "horario: lo lee quien entra" on public.horario_citas;
create policy "horario: lo lee quien entra" on public.horario_citas
  for select using (auth.uid() is not null);

drop policy if exists "horario: lo edita el equipo" on public.horario_citas;
create policy "horario: lo edita el equipo" on public.horario_citas
  for all using (public.es_gestor()) with check (public.es_gestor());

drop policy if exists "cierres: los lee quien entra" on public.cierres_citas;
create policy "cierres: los lee quien entra" on public.cierres_citas
  for select using (auth.uid() is not null);

drop policy if exists "cierres: los edita el equipo" on public.cierres_citas;
create policy "cierres: los edita el equipo" on public.cierres_citas
  for all using (public.es_gestor()) with check (public.es_gestor());


-- ───────────────────────────────────────────────────────────────────────
-- 4. LA CITA RESERVADA DESDE EL HORARIO
-- ───────────────────────────────────────────────────────────────────────
-- hueco = true: nació de un hueco del horario, no de una petición. Es lo
-- que distingue las nuevas de las antiguas, y lo que acota el índice de
-- abajo: las citas confirmadas a mano antes de hoy pueden coincidir en la
-- hora -dos gestores, dos salas- y el índice no debe tropezar con ellas al
-- crearse, que haría fallar este archivo entero en la base real.
alter table public.citas add column if not exists hueco boolean not null default false;

comment on column public.citas.hueco is 'true = reservada desde el horario del CIIP; false = pedida con una ventana de días';

-- Un hueco, una cita. Solo cuentan las vivas: una cancelada lo libera.
create unique index if not exists citas_un_hueco_una_cita
  on public.citas (cuando)
  where hueco and estado in ('solicitada','confirmada');


-- ───────────────────────────────────────────────────────────────────────
-- 5. QUÉ HORAS ESTÁN YA TOMADAS
-- ───────────────────────────────────────────────────────────────────────
-- El inversionista solo ve SUS citas (RLS de citas), así que no puede saber
-- por su cuenta qué huecos están ocupados. Esto se lo dice sin decirle de
-- quién: solo la hora. security definer para poder mirar todas.
--
-- Cuentan todas las vivas con hora, también las confirmadas a mano: una
-- reunión ya puesta a las diez ocupa las diez aunque no naciera del horario.
create or replace function public.huecos_ocupados(p_desde date, p_hasta date)
returns table (cuando timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $hue$
begin
  if auth.uid() is null then
    return;
  end if;
  -- Un rango sin tope es una forma de pedir el calendario entero del CIIP.
  if p_hasta < p_desde or p_hasta - p_desde > 92 then
    raise exception 'Rango de fechas no válido'
      using errcode = 'check_violation';
  end if;

  return query
    select c.cuando
      from public.citas c
     where c.estado in ('solicitada','confirmada')
       and c.cuando is not null
       and c.cuando >= (p_desde::timestamp at time zone 'America/Caracas')
       and c.cuando <  ((p_hasta + 1)::timestamp at time zone 'America/Caracas')
     order by c.cuando;
end
$hue$;

revoke all on function public.huecos_ocupados(date, date) from public;
grant execute on function public.huecos_ocupados(date, date) to authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- 6. RESERVAR UN HUECO
-- ───────────────────────────────────────────────────────────────────────
-- La única puerta para una cita que nace confirmada. La política de citas
-- sigue exigiendo 'solicitada' y sin hora a quien inserte desde el
-- navegador -y hace bien-; esto entra por detrás, pero solo después de
-- comprobar todo lo que un navegador podría inventarse.
create or replace function public.reserva_cita(
  p_cuando timestamptz,
  p_modo   text,
  p_tipo   text default null,
  p_nota   text default ''
)
returns public.citas
language plpgsql
security definer
set search_path = public
as $res$
declare
  yo     uuid := auth.uid();
  local  timestamp;
  dia_l  date;
  hora_l time;
  fila   public.citas;
begin
  if yo is null then
    raise exception 'Hace falta haber entrado para reservar'
      using errcode = 'insufficient_privilege';
  end if;

  if p_modo is null or p_modo not in ('presencial','video','telefono') then
    raise exception 'Modo de cita no válido'
      using errcode = 'check_violation';
  end if;

  if length(coalesce(p_nota, '')) > 500 then
    raise exception 'La nota es demasiado larga'
      using errcode = 'check_violation';
  end if;

  if p_cuando is null or p_cuando <= now() then
    raise exception 'Ese hueco ya pasó'
      using errcode = 'check_violation';
  end if;

  if p_cuando > now() + interval '92 days' then
    raise exception 'Ese hueco está demasiado lejos'
      using errcode = 'check_violation';
  end if;

  local  := p_cuando at time zone 'America/Caracas';
  dia_l  := local::date;
  hora_l := local::time;

  if exists (select 1 from public.cierres_citas where fecha = dia_l) then
    raise exception 'Ese día el CIIP no atiende'
      using errcode = 'check_violation';
  end if;

  -- El hueco tiene que ESTAR en el horario: el día de la semana, dentro del
  -- tramo, cabiendo entero antes de que acabe y en punto con su intervalo.
  if not exists (
    select 1
      from public.horario_citas h
     where h.dia = extract(isodow from local)::int
       and hora_l >= h.desde
       and hora_l + make_interval(mins => h.cada_min) <= h.hasta
       and (extract(epoch from (hora_l - h.desde))::int % (h.cada_min * 60)) = 0
  ) then
    raise exception 'Ese hueco no está en el horario del CIIP'
      using errcode = 'check_violation';
  end if;

  -- Una cita viva por persona, como ya hace la pantalla: con una en marcha
  -- no se ofrece el formulario. Aquí se asegura también por detrás.
  if exists (
    select 1 from public.citas
     where inversionista = yo and estado in ('solicitada','confirmada')
  ) then
    raise exception 'Ya tienes una cita en marcha'
      using errcode = 'check_violation';
  end if;

  -- Libre de verdad, contando también las confirmadas a mano a esa hora.
  if exists (
    select 1 from public.citas
     where cuando = p_cuando and estado in ('solicitada','confirmada')
  ) then
    raise exception 'Ese hueco se acaba de ocupar'
      using errcode = 'unique_violation';
  end if;

  insert into public.citas
    (inversionista, tipo_tramite, modo, desde, hasta, nota, estado, cuando, hueco)
  values
    (yo, nullif(p_tipo, ''), p_modo, dia_l, dia_l, coalesce(trim(p_nota), ''),
     'confirmada', p_cuando, true)
  returning * into fila;

  return fila;

-- Dos que pulsan en el mismo segundo pasan las dos el "libre de verdad" de
-- arriba; el índice único deja entrar a uno y aquí el otro recibe la misma
-- frase que si hubiera llegado tarde.
exception when unique_violation then
  raise exception 'Ese hueco se acaba de ocupar'
    using errcode = 'unique_violation';
end
$res$;

revoke all on function public.reserva_cita(timestamptz, text, text, text) from public;
grant execute on function public.reserva_cita(timestamptz, text, text, text) to authenticated;

-- ───────────────────────────────────────────────────────────────────────
-- SIN FINES DE SEMANA, TAMBIEN EN UNA BASE QUE YA TENIA LAS TABLAS
-- ───────────────────────────────────────────────────────────────────────
-- Arriba la regla va dentro del create table, y eso solo sirve en una base
-- nueva: si la tabla ya existe, «create table if not exists» no la toca.
-- Asi que aqui se pone otra vez, por su nombre, para que tambien la tenga
-- la base donde este archivo ya se habia pasado.
--
-- Si hay tramos o cierres en fin de semana, se para y lo dice. No se
-- borran solos: son datos que alguien escribio, y decidir tirarlos no le
-- toca a un archivo de SQL.
do $$
begin
  if exists (select 1 from public.horario_citas where dia > 5) then
    raise exception using message =
      'Hay tramos en sabado o domingo en horario_citas. El CIIP no atiende ' ||
      'fines de semana: borralos desde el panel y vuelve a pasar este archivo.';
  end if;
  if exists (select 1 from public.cierres_citas
             where extract(isodow from fecha) > 5) then
    raise exception using message =
      'Hay dias cerrados que caen en sabado o domingo en cierres_citas. ' ||
      'Esos dias ya no tenian citas: borralos y vuelve a pasar este archivo.';
  end if;
end $$;

alter table public.horario_citas drop constraint if exists horario_dia_valido;
alter table public.horario_citas add  constraint horario_dia_valido
  check (dia between 1 and 5);

alter table public.cierres_citas drop constraint if exists cierre_dia_laborable;
alter table public.cierres_citas add  constraint cierre_dia_laborable
  check (extract(isodow from fecha) between 1 and 5);
