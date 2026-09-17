-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA PROTOCOLIZACIÓN NACE SOLA (c5 → c22)
--  Va DESPUÉS de supabase-reserva-nombre.sql: repite su patrón un piso
--  más abajo y usa sus mismas tablas.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 17 de septiembre de 2026: «al finalizar la fase de
--  constitución de la empresa, automáticamente se inicia esta solicitud,
--  porque hay que aplicar el mismo paso que la de arriba: el CIIP envía lo
--  que el inversionista debe pagar y después el inversionista sube el
--  comprobante».
--
--  Así que son tres cosas:
--
--   1. Resuelta la constitución, la protocolización del acta se crea sola,
--      ya enviada, con lo que la constitución ya decía.
--   2. El equipo deja en ella el DOCUMENTO PARA PAGAR los aranceles del
--      registro, igual que deja el de la reserva del nombre.
--   3. Sin el comprobante de ese pago, la protocolización no se resuelve.
--
--  Lo que este archivo NO toca: qué fichas se pueden pedir y cuáles no.
--  Se quedan como están, todas abiertas, por decisión suya del mismo día.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: la protocolización sigue naciendo
--  a mano —el inversionista la crea al subir su comprobante, como hasta
--  hoy— y la casilla del equipo falla al enganchar el documento.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL PAPEL QUE DEJA EL EQUIPO
-- ───────────────────────────────────────────────────────────────────────
--  No caduca: es la orden de pago de un expediente concreto, no una
--  constancia con fecha de vencimiento. El comprobante del pago
--  ('pago_aranceles') ya existe en supabase-tramites.sql y no se toca.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_aranceles', 'Documento para pagar los aranceles del registro', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. EL EQUIPO DEJA EL DOCUMENTO PARA PAGAR
-- ───────────────────────────────────────────────────────────────────────
--  Las dos políticas gemelas de las de la reserva del nombre. Entra
--  'validado', que es lo que impide al inversionista borrarlo sin querer,
--  y el archivo va a la carpeta 'emitidos', que el cubo ya le deja al
--  equipo.
drop policy if exists "documentos: el equipo sube el documento para pagar los aranceles" on public.documentos;
create policy "documentos: el equipo sube el documento para pagar los aranceles" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_aranceles' and estado = 'validado');

--  Y engancharlo: solo a una protocolización, y solo mientras está en
--  marcha, que es cuando el paso del pago se ofrece. El papel tiene que
--  ser de la bóveda del mismo inversionista del trámite, para no colgarle
--  a alguien el de otro.
drop policy if exists "adjuntos: el equipo engancha el documento para pagar los aranceles" on public.tramite_documentos;
create policy "adjuntos: el equipo engancha el documento para pagar los aranceles" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_aranceles'
         and t.tipo = 'protocolizacion_acta'
         and t.estado in ('enviado','en_revision','ante_el_ente')
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- 3. RESUELTA LA CONSTITUCIÓN, NACE LA PROTOCOLIZACIÓN
-- ───────────────────────────────────────────────────────────────────────
--  Aquí y no en el panel: el trámite tiene que nacer lo resuelva quien lo
--  resuelva y desde donde lo resuelva —la cola, «Lo que toca hoy» o este
--  mismo editor—. En el navegador, un cierre de pestaña a destiempo dejaba
--  la constitución resuelta y ninguna protocolización, y nadie se
--  enteraría hasta que el inversionista preguntara.
--
--  AFTER UPDATE y no BEFORE: lo que se inserta no depende de la fila que
--  se está escribiendo, y a estas alturas la escalera de estados y la
--  guarda de la reserva ya dijeron que sí.
--
--  security definer para poder insertar por encima del RLS: el gestor que
--  resuelve no tiene permiso para crear un trámite de otra persona, y es
--  justo lo que hay que hacer aquí.
--
--  QUÉ SE COPIA. La protocolización pregunta cinco cosas y la
--  constitución ya sabe cuatro:
--    · razón social        ← la denominación que se reservó
--    · capital social      ← el mismo
--    · registro mercantil  ← la oficina del SAREN donde se constituyó
--    · representante       ← el primero de la junta directiva, que se
--                            guarda como «Nombre (CARGO); Nombre (CARGO)»
--  La fecha de firma del acta NO se copia: no existía todavía. La rellena
--  quien la tenga delante.
--
--  Y si ya hay una protocolización de esa persona no se crea otra: ni
--  aunque esté resuelta. Volver a resolver la constitución de alguien
--  —enderezando un expediente a mano, por ejemplo— no tiene por qué
--  abrirle un trámite repetido, y el índice de «una sola solicitud viva»
--  rechazaría la fila de todas formas.
create or replace function public.constitucion_abre_la_protocolizacion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  copia     jsonb := '{}'::jsonb;
  junta     text;
  quien     text;
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'constitucion' then
    return new;
  end if;

  --  Sin el trámite en el catálogo —o apagado— no hay nada que crear: la
  --  llave foránea lo rechazaría y se llevaría por delante el «resuelto»
  --  que el gestor acaba de dar.
  if not exists (
    select 1 from public.tipos_tramite
     where codigo = 'protocolizacion_acta' and coalesce(activo, true)
  ) then
    return new;
  end if;

  if exists (
    select 1 from public.tramites
     where inversionista = new.inversionista
       and tipo = 'protocolizacion_acta'
  ) then
    return new;
  end if;

  if coalesce(new.datos->>'denominacion', '') <> '' then
    copia := copia || jsonb_build_object('razon_social', new.datos->>'denominacion');
  end if;
  if coalesce(new.datos->>'capital_social', '') <> '' then
    copia := copia || jsonb_build_object('capital_social', new.datos->>'capital_social');
  end if;
  if coalesce(new.datos->>'oficina_registro', '') <> '' then
    copia := copia || jsonb_build_object('registro_mercantil', new.datos->>'oficina_registro');
  end if;

  junta := coalesce(new.datos->>'junta_directiva', '');
  if junta <> '' then
    --  «Ana Pérez (PRESIDENTE); Luis Mora (TESORERO)» → «Ana Pérez»
    quien := btrim(split_part(split_part(junta, ';', 1), '(', 1));
    if quien <> '' then
      copia := copia || jsonb_build_object('representante', quien);
    end if;
  end if;

  insert into public.tramites (inversionista, tipo, estado, datos, enviado_en)
  values (new.inversionista, 'protocolizacion_acta', 'enviado', copia, now());

  return new;
end;
$$;

drop trigger if exists tramites_abre_protocolizacion on public.tramites;
create trigger tramites_abre_protocolizacion
  after update on public.tramites
  for each row execute function public.constitucion_abre_la_protocolizacion();


-- ───────────────────────────────────────────────────────────────────────
-- 4. SIN EL COMPROBANTE DEL PAGO, NO HAY «RESUELTA»
-- ───────────────────────────────────────────────────────────────────────
--  La misma regla que protege a la constitución, en la protocolización:
--  el registro no protocoliza nada sin arancel pagado, así que un
--  expediente resuelto sin ese papel estaría mintiendo.
--
--  Los BEFORE UPDATE corren por orden alfabético, y 'tramites_proteger'
--  va antes que 'tramites_protocolizacion_pago': un salto que la escalera
--  no deja no llega aquí. Desde el SQL Editor (auth.uid() nulo) no
--  estorba, para poder enderezar a mano un expediente atascado.
create or replace function public.tramites_protocolizacion_con_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'protocolizacion_acta' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;

  if not exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
     where td.tramite = new.id
       and d.tipo = 'pago_aranceles'
  ) then
    raise exception 'La protocolización no se resuelve sin el comprobante del pago de los aranceles'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists tramites_protocolizacion_pago on public.tramites;
create trigger tramites_protocolizacion_pago
  before update on public.tramites
  for each row execute function public.tramites_protocolizacion_con_pago();


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--   select codigo, nombre, vence from public.tipos_documento
--    where codigo = 'planilla_aranceles';                      -- una fila
--
--   select polname from pg_policy
--    where polname in ('documentos: el equipo sube el documento para pagar los aranceles',
--                      'adjuntos: el equipo engancha el documento para pagar los aranceles');
--                                                              -- dos filas
--
--   select tgname from pg_trigger
--    where tgname in ('tramites_abre_protocolizacion', 'tramites_protocolizacion_pago');
--                                                              -- dos filas
--
--  Y el camino entero, con una cuenta del equipo (no desde el SQL Editor,
--  que no estorba):
--    · resolver una constitución que tenga su comprobante de la reserva
--      tiene que dejar una protocolización nueva, en 'enviado', con la
--      razón social ya puesta:
--        select tipo, estado, datos from public.tramites
--         where inversionista = '<uuid>' order by creado_en desc limit 2;
--    · y marcarla resuelta sin el comprobante del pago tiene que responder
--        La protocolización no se resuelve sin el comprobante del pago de
--        los aranceles
