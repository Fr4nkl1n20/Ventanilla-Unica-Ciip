-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LAS CITAS
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable: todo va con "if not exists" o con "drop ... if exists",
--  así que volver a pasarlo no rompe lo que ya esté.
--
--  ORDEN: va DESPUÉS de supabase-setup.sql y de supabase-tramites.sql.
--  De ahí salen public.es_gestor() y public.tocar_actualizado_en(), que
--  este archivo usa y no vuelve a definir.
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ES UNA CITA AQUÍ
--  ─────────────────────────────────────────────────────────────────────
--  Una PETICIÓN, no una reserva. El inversionista dice de qué quiere
--  hablar, cómo prefiere verse y qué días le vienen bien; el CIIP pone la
--  fecha. No hay agenda con huecos libres, y por eso no hay tabla de
--  disponibilidad: publicar huecos que nadie mantiene es enseñar horas
--  que no existen, y la tarjeta del c7 ya promete lo contrario —"la cita
--  la coordina el CIIP"—.
--
--  Por eso la hora exacta (cuando) nace en null: no la sabe quien pide.
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.citas (
  id             uuid primary key default gen_random_uuid(),
  inversionista  uuid not null references auth.users(id) on delete cascade,

  -- De qué trámite se quiere hablar. Null = una consulta general, que es
  -- un caso legítimo y no un dato que falte: no toda cita es de un trámite.
  tipo_tramite   text references public.tipos_tramite(codigo),

  modo           text not null,
  -- La ventana que le viene bien a quien pide. Dos fechas y no una: pedir
  -- un día exacto obliga a acertar con la agenda del CIIP a ciegas, y la
  -- respuesta sería "ese no, dime otro" la mitad de las veces.
  desde          date not null,
  hasta          date not null,
  nota           text not null default '',

  estado         text not null default 'solicitada',
  gestor         uuid references auth.users(id) on delete set null,

  -- Lo que pone el CIIP al confirmar. Nacen vacíos a propósito.
  cuando         timestamptz,
  lugar          text not null default '',

  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),

  constraint citas_modo_valido
    check (modo in ('presencial','video','telefono')),

  constraint citas_estado_valido
    check (estado in ('solicitada','confirmada','hecha','cancelada')),

  -- Una ventana al revés no es un error del usuario que haya que tolerar:
  -- es una fila que ningún gestor podría atender.
  constraint citas_ventana_valida
    check (hasta >= desde),

  -- Una cita confirmada SIN fecha es una promesa vacía, y el panel la
  -- enseñaría como "confirmada para el —". La base no la deja existir.
  constraint citas_confirmada_con_fecha
    check (estado <> 'confirmada' or cuando is not null)
);

comment on table  public.citas               is 'Peticiones de cita del inversionista. El CIIP pone la fecha';
comment on column public.citas.tipo_tramite  is 'De qué trámite se quiere hablar. Null = consulta general';
comment on column public.citas.modo          is 'presencial, video o telefono. Lo elige quien pide';
comment on column public.citas.desde         is 'Primer día que le viene bien';
comment on column public.citas.hasta         is 'Último día que le viene bien';
comment on column public.citas.cuando        is 'Fecha y hora que fija el CIIP. Null mientras esté solicitada';
comment on column public.citas.lugar         is 'Dirección si es presencial, o el enlace si es por video';
comment on column public.citas.estado        is 'solicitada = pedida; confirmada = con fecha; hecha; cancelada';

-- La cola del gestor: lo que nadie ha atendido todavía, primero lo viejo.
create index if not exists citas_cola
  on public.citas (estado, creado_en) where estado = 'solicitada';

create index if not exists citas_por_inversionista
  on public.citas (inversionista, estado);


-- ───────────────────────────────────────────────────────────────────────
--  QUIÉN PUEDE QUÉ
-- ───────────────────────────────────────────────────────────────────────
alter table public.citas enable row level security;

drop policy if exists "citas: leer las propias" on public.citas;
create policy "citas: leer las propias" on public.citas
  for select using (inversionista = auth.uid() or public.es_gestor());

-- Se pide SIEMPRE en estado 'solicitada' y sin fecha. Sin esto, cualquiera
-- podría insertarse una cita ya "confirmada" para el martes a las nueve y
-- presentarse en la oficina con una captura de pantalla como prueba.
drop policy if exists "citas: pedir las propias" on public.citas;
create policy "citas: pedir las propias" on public.citas
  for insert with check (
    inversionista = auth.uid()
    and estado = 'solicitada'
    and cuando is null
    and gestor is null
    and lugar = ''
  );

-- El inversionista solo puede CANCELAR, y solo lo que aún no ha pasado.
-- Cambiar el asunto o las fechas de una cita ya confirmada dejaría al
-- gestor con una reunión que no es la que aceptó.
drop policy if exists "citas: cancelar las propias" on public.citas;
create policy "citas: cancelar las propias" on public.citas
  for update
  using      ((inversionista = auth.uid() and estado in ('solicitada','confirmada')) or public.es_gestor())
  with check ((inversionista = auth.uid() and estado in ('solicitada','confirmada','cancelada')) or public.es_gestor());

-- Que la política deje pasar el UPDATE no basta: dentro de esa fila el
-- inversionista podría cambiar el estado a 'hecha', ponerse fecha o
-- adjudicarse un gestor. Eso se corta aquí, campo por campo.
create or replace function public.citas_solo_cancelar()
returns trigger
language plpgsql
as $$
begin
  -- auth.uid() es null desde el SQL Editor o con la clave service_role:
  -- el equipo del CIIP sí puede confirmar, mover y cerrar citas.
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;

  if new.estado is distinct from old.estado and new.estado <> 'cancelada' then
    raise exception 'Una cita solo se puede cancelar desde el panel';
  end if;

  if new.cuando        is distinct from old.cuando
  or new.lugar         is distinct from old.lugar
  or new.gestor        is distinct from old.gestor
  or new.tipo_tramite  is distinct from old.tipo_tramite
  or new.desde         is distinct from old.desde
  or new.hasta         is distinct from old.hasta
  or new.inversionista is distinct from old.inversionista then
    raise exception 'Esos datos de la cita los fija el CIIP';
  end if;

  return new;
end;
$$;

drop trigger if exists citas_proteger on public.citas;
create trigger citas_proteger
  before update on public.citas
  for each row execute function public.citas_solo_cancelar();

drop trigger if exists citas_marca_tiempo on public.citas;
create trigger citas_marca_tiempo
  before update on public.citas
  for each row execute function public.tocar_actualizado_en();

-- Nadie borra una cita: cancelarla deja constancia de que se pidió, y
-- borrarla haría desaparecer esa conversación del expediente.
-- (No se crea ninguna política de DELETE, así que RLS lo impide.)
