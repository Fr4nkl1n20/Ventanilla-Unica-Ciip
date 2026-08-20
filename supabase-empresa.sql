-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — MI EMPRESA
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-setup.sql y de supabase-tramites.sql.
--  De ahí salen public.es_gestor() y public.tocar_actualizado_en().
-- ═══════════════════════════════════════════════════════════════════════
--
--  POR QUÉ HACE FALTA
--  ─────────────────────────────────────────────────────────────────────
--  La razón social se escribe a mano en OCHO formularios distintos. El RIF
--  de la empresa en seis. La dirección fiscal en cinco. El teléfono, la
--  actividad económica y el representante en cuatro cada uno.
--
--  Es el mismo problema que ya resolvió la bóveda con los recaudos —subes
--  el acta una vez y el siguiente trámite te la ofrece cargada—, pero un
--  piso más arriba: con los DATOS en vez de con los archivos.
--
--  Y no es solo tiempo. Escribir ocho veces "Bianchi Agroindustrias, C.A."
--  es escribirla ocho veces distintas: una con punto, otra sin la coma,
--  otra en mayúsculas. El ente devuelve el trámite por eso.
--
--  UNA POR INVERSIONISTA
--  ─────────────────────────────────────────────────────────────────────
--  La llave primaria ES el inversionista, no un id aparte. Quien vaya a
--  constituir dos compañías tendrá que esperar: hacerlo genérico ahora
--  obligaría a elegir empresa en cada formulario, y hoy no hay nadie con
--  dos. Cuando lo haya, esto se convierte en tabla con id propio y los
--  formularios ganan un selector.
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.empresas (
  inversionista uuid primary key references auth.users(id) on delete cascade,

  -- Lo que piden los formularios, con los mismos nombres que usan ellos:
  -- así el panel rellena por coincidencia de nombre y no hay una tabla de
  -- equivalencias que mantener.
  razon_social        text not null default '',
  rif_empresa         text not null default '',
  numero_registro     text not null default '',
  fecha_constitucion  date,
  capital_social      text not null default '',
  actividad_economica text not null default '',
  direccion_fiscal    text not null default '',
  municipio           text not null default '',
  telefono            text not null default '',
  representante       text not null default '',
  inicio_actividades  date,
  -- Texto y no número: los formularios lo piden como texto y algunos
  -- inversionistas responden "12 fijos y 4 por temporada".
  num_trabajadores    text not null default '',

  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),

  -- Sin razón social no hay empresa que rellenar en ningún sitio.
  constraint empresas_con_nombre check (length(trim(razon_social)) > 0)
);

comment on table public.empresas is
  'Los datos de la compañía del inversionista, para no volver a escribirlos en cada formulario';


-- ───────────────────────────────────────────────────────────────────────
--  QUIÉN PUEDE QUÉ
-- ───────────────────────────────────────────────────────────────────────
alter table public.empresas enable row level security;

-- La tuya, y solo la tuya.
drop policy if exists "empresas: la mia" on public.empresas;
create policy "empresas: la mia" on public.empresas
  for all to authenticated
  using      (inversionista = auth.uid())
  with check (inversionista = auth.uid());

-- El equipo la lee para revisar un trámite: los datos que llegan en la
-- solicitud salen de aquí, y sin poder verlos la revisión es a ciegas.
-- LEER, no escribir: la empresa es del inversionista.
drop policy if exists "empresas: el equipo las lee" on public.empresas;
create policy "empresas: el equipo las lee" on public.empresas
  for select
  using (public.es_gestor());

drop trigger if exists empresas_marca_tiempo on public.empresas;
create trigger empresas_marca_tiempo
  before update on public.empresas
  for each row execute function public.tocar_actualizado_en();


-- ───────────────────────────────────────────────────────────────────────
--  COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
-- Que la protección quedó puesta. Tiene que decir true:
--   select relname, relrowsecurity from pg_class where relname = 'empresas';
