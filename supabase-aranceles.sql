-- ═══════════════════════════════════════════════════════════════════════
--  LOS ARANCELES Y LAS ÓRDENES DE PAGO
--  Va DESPUÉS de supabase-cola.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  No hay trámite real sin tasa. Hasta aquí el panel se comporta como si
--  todo fuera gratis: el inversionista rellena, manda, y en algún momento
--  alguien le dice por otro canal que hay que pagar algo. Eso es
--  exactamente lo que una ventanilla única viene a quitar.
--
--  LA TABLA NACE VACÍA, A PROPÓSITO
--  ─────────────────────────────────────────────────────────────────────
--  Igual que `bancos_aliados`. Aquí NO se inventan cifras: un arancel es
--  un monto oficial, publicado en Gaceta, que cambia. Escribir aquí una
--  cantidad plausible sería peor que no tener nada, porque parecería
--  buena y alguien la creería.
--
--  Mientras esté vacía todo funciona igual que hasta ahora: sin arancel
--  no se crea orden de pago, y sin orden de pago el trámite sigue su
--  camino sin que nada le estorbe. Se llena cuando el CIIP tenga los
--  montos, y desde ese momento el trámite los pide.
--
--  LO QUE ESTO NO ES
--  ─────────────────────────────────────────────────────────────────────
--  No es una pasarela de pago. Aquí se guarda QUÉ se debe, CUÁNTO y si
--  está pagado. Cobrarlo de verdad necesita convenio bancario, y eso no
--  depende de nosotros; lo que sí depende es que el modelo esté bien y
--  probado, que es lo que hay aquí.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL CATÁLOGO DE TASAS
-- ───────────────────────────────────────────────────────────────────────
-- Con vigencia, y no un monto suelto por trámite. Un arancel cambia por
-- Gaceta, y una orden de pago emitida en marzo tiene que seguir diciendo
-- lo que decía en marzo aunque en abril suba: si se guardara sólo el
-- monto actual, el historial de lo cobrado se reescribiría solo.

create table if not exists public.aranceles (
  id       uuid primary key default gen_random_uuid(),
  tramite  text not null references public.tipos_tramite(codigo) on delete cascade,

  concepto text not null,
  monto    numeric(14,2) not null,
  moneda   text not null default 'USD',

  -- Abierto por la derecha = el que rige hoy. Cerrarlo es poner la fecha
  -- en que dejó de valer, nunca borrar la fila: lo cobrado bajo el
  -- arancel viejo tiene que seguir explicándose.
  desde    date not null default current_date,
  hasta    date,

  creado_en timestamptz not null default now(),

  constraint aranceles_monto_positivo check (monto > 0),
  constraint aranceles_vigencia_valida check (hasta is null or hasta >= desde)
);

comment on table  public.aranceles       is 'Cuánto cuesta cada trámite, con la vigencia de cada monto';
comment on column public.aranceles.hasta is 'null = es el que rige hoy. Se cierra, no se borra';

-- Un solo arancel vigente por trámite. Sin esto, dos filas abiertas
-- hacen que la orden de pago dependa de cuál lea primero la consulta, y
-- eso es un cobro distinto según el día.
create unique index if not exists aranceles_uno_vigente
  on public.aranceles (tramite)
  where hasta is null;

-- NACE VACÍA. Para poner uno:
--
--   insert into public.aranceles (tramite, concepto, monto, moneda) values
--     ('rif_empresa', 'Tasa de inscripción', 0.00, 'USD');
--
-- Para cambiarlo cuando salga en Gaceta, NO se edita la fila: se cierra
-- la vieja y se abre una nueva, en la misma transacción.
--
--   update public.aranceles set hasta = current_date
--    where tramite = 'rif_empresa' and hasta is null;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LO QUE SE DEBE
-- ───────────────────────────────────────────────────────────────────────
-- El monto se COPIA aquí, no se lee del catálogo cada vez. Es la misma
-- razón que en los avisos: una orden de pago dice lo que se debía el día
-- que se emitió. Si leyera el catálogo, subir un arancel cambiaría
-- retroactivamente lo que debe alguien que solicitó hace un mes.

create table if not exists public.ordenes_pago (
  id            uuid primary key default gen_random_uuid(),
  tramite       uuid not null references public.tramites(id) on delete cascade,
  inversionista uuid not null references auth.users(id) on delete cascade,

  concepto text not null,
  monto    numeric(14,2) not null,
  moneda   text not null default 'USD',

  estado   text not null default 'pendiente',

  -- La que da el banco o la pasarela. Es por lo que se reclama si algo
  -- no cuadra, así que se guarda aunque el pago falle.
  referencia  text,
  comprobante uuid references public.documentos(id) on delete set null,

  creado_en   timestamptz not null default now(),
  pagado_en   timestamptz,
  actualizado_en timestamptz not null default now(),

  constraint ordenes_estado_valido
    check (estado in ('pendiente', 'pagada', 'anulada')),
  constraint ordenes_monto_positivo check (monto > 0),
  -- Una orden pagada sin fecha de pago es una orden que no se puede
  -- conciliar con el banco. O las dos cosas o ninguna.
  constraint ordenes_pagada_con_fecha
    check (estado <> 'pagada' or pagado_en is not null)
);

comment on table  public.ordenes_pago        is 'Lo que debe un inversionista por un trámite concreto';
comment on column public.ordenes_pago.monto  is 'Copiado del arancel el día que se emitió. No se relee del catálogo';

create index if not exists ordenes_por_inversionista
  on public.ordenes_pago (inversionista, estado);

-- Una orden viva por trámite. Dos serían cobrar dos veces lo mismo.
create unique index if not exists ordenes_una_viva
  on public.ordenes_pago (tramite)
  where estado = 'pendiente';

drop trigger if exists ordenes_marca_tiempo on public.ordenes_pago;
create trigger ordenes_marca_tiempo
  before update on public.ordenes_pago
  for each row execute function public.tocar_actualizado_en();


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA ORDEN SE EMITE SOLA
-- ───────────────────────────────────────────────────────────────────────
-- Al enviar la solicitud, no antes. Emitirla al abrir el borrador sería
-- cobrarle a quien todavía está mirando; emitirla más tarde le daría la
-- noticia cuando ya cree que ha terminado.

create or replace function public.emitir_orden_de_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $aran$
declare
  tasa record;
begin
  if new.estado is not distinct from old.estado or new.estado <> 'enviado' then
    return new;
  end if;

  select concepto, monto, moneda into tasa
    from public.aranceles
   where tramite = new.tipo and hasta is null;

  -- Sin arancel no hay nada que cobrar, y el trámite sigue su camino sin
  -- que nada le estorbe. Es el caso de los treinta y uno hoy.
  if tasa is null then
    return new;
  end if;

  insert into public.ordenes_pago (tramite, inversionista, concepto, monto, moneda)
  values (new.id, new.inversionista, tasa.concepto, tasa.monto, tasa.moneda)
  on conflict do nothing;

  return new;
end
$aran$;

drop trigger if exists tramites_cobrar on public.tramites;
create trigger tramites_cobrar
  after update on public.tramites
  for each row execute function public.emitir_orden_de_pago();


-- ───────────────────────────────────────────────────────────────────────
-- 4. NO SE PRESENTA LO QUE NO ESTÁ PAGADO
-- ───────────────────────────────────────────────────────────────────────
-- Aquí está lo que de verdad hace esto útil, y es una sola línea de
-- lógica: si hay una orden pendiente, el trabajo de 'presentar' no se
-- encola. Presentar un expediente sin la tasa pagada es que el organismo
-- lo devuelva por un motivo administrativo, después de que una persona
-- del CIIP lo haya revisado. Trabajo perdido de los dos lados.
--
-- Se hace envolviendo `encolar_trabajo` en vez de tocándolo: la cola no
-- tiene por qué saber que existen los aranceles, y si mañana se quita
-- este archivo, aquella sigue funcionando como antes.

create or replace function public.encolar_trabajo()
returns trigger
language plpgsql
security definer
set search_path = public
as $aran$
declare
  quien text;
  cual  text;
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;

  select conector into quien from public.tipos_tramite where codigo = new.tipo;
  if quien is null then
    return new;
  end if;

  if    new.estado = 'en_revision'  then cual := 'presentar';
  elsif new.estado = 'ante_el_ente' then cual := 'consultar';
  else  return new;
  end if;

  -- Lo único que este archivo añade a la versión de supabase-cola.sql.
  -- Sólo estorba a 'presentar': una consulta sobre algo YA presentado no
  -- tiene nada que ver con lo que se deba.
  if cual = 'presentar' and exists (
       select 1 from public.ordenes_pago
        where tramite = new.id and estado = 'pendiente') then
    return new;
  end if;

  insert into public.trabajos (tramite, tarea, llave)
  values (new.id, cual, new.id::text)
  on conflict do nothing;

  return new;
end
$aran$;


-- ───────────────────────────────────────────────────────────────────────
-- 5. Y AL PAGAR, SE SUELTA
-- ───────────────────────────────────────────────────────────────────────
-- Si no, un trámite pagado después de la revisión se quedaría esperando
-- para siempre: el momento de encolar ya pasó y nadie volvería a mirarlo.

create or replace function public.soltar_al_pagar()
returns trigger
language plpgsql
security definer
set search_path = public
as $aran$
declare
  t record;
begin
  if new.estado <> 'pagada' or old.estado = 'pagada' then
    return new;
  end if;

  select id, tipo, estado into t from public.tramites where id = new.tramite;
  if t is null or t.estado <> 'en_revision' then
    return new;   -- todavía no le toca, o ya pasó de ahí
  end if;

  if (select conector from public.tipos_tramite where codigo = t.tipo) is null then
    return new;
  end if;

  insert into public.trabajos (tramite, tarea, llave)
  values (t.id, 'presentar', t.id::text)
  on conflict do nothing;

  return new;
end
$aran$;

drop trigger if exists ordenes_soltar on public.ordenes_pago;
create trigger ordenes_soltar
  after update on public.ordenes_pago
  for each row execute function public.soltar_al_pagar();


-- ───────────────────────────────────────────────────────────────────────
-- 6. QUIÉN LO VE
-- ───────────────────────────────────────────────────────────────────────
alter table public.aranceles    enable row level security;
alter table public.ordenes_pago enable row level security;

-- El catálogo es público para quien haya entrado: saber cuánto cuesta un
-- trámite ANTES de empezarlo es la mitad de lo que se viene a buscar.
drop policy if exists "aranceles: leerlos" on public.aranceles;
create policy "aranceles: leerlos" on public.aranceles
  for select to authenticated using (true);

drop policy if exists "aranceles: solo el admin escribe" on public.aranceles;
create policy "aranceles: solo el admin escribe" on public.aranceles
  for all
  using      (public.es_admin())
  with check (public.es_admin());

drop policy if exists "ordenes: la mia" on public.ordenes_pago;
create policy "ordenes: la mia" on public.ordenes_pago
  for select using (inversionista = auth.uid() or public.es_gestor());

-- Y NADIE la marca pagada desde el navegador, ni el equipo. No hay
-- política de update a propósito: eso lo escribe el cobrador con la clave
-- de servidor, después de que la pasarela lo confirme. Una orden que se
-- pueda dar por pagada desde el cliente no es una orden de pago.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) El catálogo sale VACÍO hasta que el CIIP lo llene. No es un fallo:
--    sin arancel, el trámite funciona como siempre.
--
--   select tramite, concepto, monto, moneda, desde, hasta
--   from public.aranceles order by tramite;
--
-- 2) Lo que se debe hoy:
--
--   select o.estado, o.concepto, o.monto, o.moneda, t.tipo
--   from public.ordenes_pago o join public.tramites t on t.id = o.tramite
--   order by o.creado_en;
--
-- 3) Que la orden frena la presentación: pon un arancel a un trámite con
--    conector, envíalo y revísalo. NO tiene que aparecer su 'presentar'
--    en public.trabajos hasta que la orden quede 'pagada'.
