-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL BANCO DE ACTIVOS Y OPORTUNIDADES
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-setup.sql y de supabase-tramites.sql.
--  De ahí sale public.es_gestor(), que este archivo usa.
-- ═══════════════════════════════════════════════════════════════════════
--
--  POR QUÉ NO ES UN TRÁMITE
--  ─────────────────────────────────────────────────────────────────────
--  Las otras treinta tarjetas del panel son solicitudes ante un organismo:
--  se piden, se revisan y se resuelven. Esta no. El banco de activos es el
--  catálogo del propio CIIP —lo que hay disponible para invertir— y lo que
--  el inversionista hace con él es MIRARLO.
--
--  Meterlo en el circuito de solicitudes le habría puesto estados que no
--  significan nada: "enviado", "ante el ente", "devuelto". Por eso es una
--  tabla aparte y una pantalla de listado, no un formulario.
--
--  Lo que sí es una solicitud es el INTERÉS en uno concreto, y eso ya
--  existe: se pide una cita sobre él.
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.activos (
  id          uuid primary key default gen_random_uuid(),

  titulo      text not null,
  sector      text not null default '',
  -- Dónde está. Sin normalizar a propósito: los activos del CIIP no caben
  -- en una lista cerrada de estados, y forzarla ahora obligaría a elegir
  -- entre "Zulia" y "Maracaibo, Zulia" sin saber cuál usa el catálogo.
  ubicacion   text not null default '',

  -- El monto es un rango, no una cifra: casi ninguna oportunidad se
  -- publica con precio cerrado, y poner uno exacto donde no lo hay
  -- ahuyenta a quien podría negociarlo.
  monto_desde numeric(14,2),
  monto_hasta numeric(14,2),
  moneda      text not null default 'USD',

  resumen     text not null default '',
  detalle     text not null default '',

  estado      text not null default 'disponible',
  -- Los que el CIIP quiere enseñar primero. Es lo unico que ordena el
  -- listado por encima de la fecha.
  destacado   boolean not null default false,

  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),

  constraint activos_estado_valido
    check (estado in ('disponible','reservado','cerrado')),

  -- Un rango al revés no es un dato que haya que tolerar: es una ficha que
  -- nadie podría leer.
  constraint activos_rango_valido
    check (monto_hasta is null or monto_desde is null or monto_hasta >= monto_desde)
);

comment on table  public.activos           is 'Catálogo del CIIP: activos y proyectos abiertos a inversión';
comment on column public.activos.estado    is 'disponible = abierto; reservado = con alguien en conversaciones; cerrado = ya no se ofrece';
comment on column public.activos.destacado is 'true = el CIIP lo quiere arriba del listado';

create index if not exists activos_visibles
  on public.activos (estado, destacado desc, creado_en desc);


-- ───────────────────────────────────────────────────────────────────────
--  QUIÉN PUEDE QUÉ
-- ───────────────────────────────────────────────────────────────────────
alter table public.activos enable row level security;

-- Lo ve cualquiera que haya entrado, sea inversionista o del equipo. Los
-- CERRADOS no: enseñar lo que ya no se ofrece es hacer perder el tiempo.
-- El equipo sí los ve, que para eso los administra.
drop policy if exists "activos: leer los abiertos" on public.activos;
create policy "activos: leer los abiertos" on public.activos
  for select to authenticated
  using (estado <> 'cerrado' or public.es_gestor());

-- Solo el equipo publica, corrige y retira. No hay política de insert ni de
-- update para el inversionista, así que RLS se las niega.
drop policy if exists "activos: el equipo los administra" on public.activos;
create policy "activos: el equipo los administra" on public.activos
  for all
  using      (public.es_gestor())
  with check (public.es_gestor());

drop trigger if exists activos_marca_tiempo on public.activos;
create trigger activos_marca_tiempo
  before update on public.activos
  for each row execute function public.tocar_actualizado_en();


-- ───────────────────────────────────────────────────────────────────────
--  CÓMO SE PUBLICA UNO
-- ───────────────────────────────────────────────────────────────────────
-- Desde el PANEL: quien tenga rol de gestor o admin ve un boton "Publicar un
-- activo" en la vista de Activos y proyectos, y otro de "Editar" en cada ficha.
-- Es la via normal, y evita que haya que entrar a la base de datos cada vez
-- que hay algo que ofrecer.
--
-- O desde aqui, si se van a cargar varios de golpe. Quita el comentario y
-- cambia lo que haga falta:

-- insert into public.activos (titulo, sector, ubicacion, monto_desde, monto_hasta, resumen, detalle, destacado)
-- values
--   ('Planta procesadora de cacao', 'Agroindustria', 'Miranda',
--    250000, 400000,
--    'Instalada y con permisos al día; busca socio para ampliar capacidad.',
--    'Capacidad actual de 12 t/mes con posibilidad de llegar a 30. Cuenta con licencia municipal, permiso sanitario y registro sanitario vigentes.',
--    true),
--   ('Desarrollo turístico costero', 'Turismo', 'Nueva Esparta',
--    800000, null,
--    'Terreno de 4 ha con vialidad y servicios, apto para hotelería.',
--    'Zonificado para uso turístico. Conformidad de uso obtenida.',
--    false);

-- Para retirar uno sin borrarlo -y sin perder de vista que existió-:
--   update public.activos set estado = 'cerrado' where id = '...';
-- Es lo que conviene casi siempre.
--
-- Borrarlo de verdad tambien se puede, y desde la propia ficha del panel:
-- editar el activo y pulsar Borrar dos veces. Entonces no queda rastro. La
-- politica de arriba -for all- ya deja el delete al equipo y a nadie mas,
-- asi que no hay nada que añadir aqui.
