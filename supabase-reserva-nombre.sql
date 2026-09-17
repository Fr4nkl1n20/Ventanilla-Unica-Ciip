-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA RESERVA DEL NOMBRE, ANTES DE RESOLVER (c5)
--  Va DESPUÉS de supabase-tramites.sql: toca tipos_documento, una política
--  de tramite_documentos y un trigger de tramites. Va al final para no
--  mover el número de nadie.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 16 de septiembre de 2026: la constitución de la
--  compañía gana un paso entre «Reserva de nombre» y «Resuelta». En él, el
--  inversionista sube el comprobante de la reserva del nombre, y SIN ESE
--  COMPROBANTE LA CONSTITUCIÓN NO SE PUEDE RESOLVER. Ni desde la pantalla
--  ni desde la base: la pantalla avisa antes, y esto es lo que lo hace
--  cierto aunque alguien se salte la pantalla.
--
--  Y de paso lo mismo para el pago de los aranceles de la protocolización
--  (c22): ese papel se sube desde su paso, con el trámite ya en marcha, y
--  hasta hoy la base solo dejaba adjuntar a una solicitud en borrador o
--  devuelta.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE, pero el paso se queda cojo: el
--  inversionista ve el botón de subir y la subida falla al engancharla, y
--  el gestor puede resolver una constitución sin comprobante.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL PAPEL
-- ───────────────────────────────────────────────────────────────────────
--  No caduca: acredita que el nombre quedó reservado en una fecha, como el
--  acta constitutiva acredita un acto. El pago de aranceles ya existe en el
--  catálogo (supabase-tramites.sql) y no se toca.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('reserva_nombre',          'Comprobante de la reserva del nombre',       false),
  ('planilla_reserva_nombre', 'Documento para pagar la reserva del nombre', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. ADJUNTARLO CON EL TRÁMITE EN MARCHA
-- ───────────────────────────────────────────────────────────────────────
--  «adjuntos: adjuntar a lo propio» deja adjuntar solo a una solicitud en
--  borrador o devuelta, y está bien: lo que se envió no se toca por debajo.
--  Estos dos papeles son la excepción porque NO EXISTEN cuando se envía:
--  el comprobante de la reserva sale cuando el nombre se reserva, y el del
--  pago cuando se paga.
--
--  Se abre lo justo, y por eso va en su propia política en vez de ensanchar
--  la de arriba: cada papel, solo en SU trámite y solo en los estados en
--  los que el paso se ofrece. Las políticas se suman: basta con que una
--  deje pasar la fila.
drop policy if exists "adjuntos: papeles de un paso, con el tramite en marcha" on public.tramite_documentos;
create policy "adjuntos: papeles de un paso, con el tramite en marcha" on public.tramite_documentos
  for insert with check (
    exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and t.inversionista = auth.uid()
         and d.inversionista = auth.uid()
         and (
              (t.tipo = 'constitucion'         and d.tipo = 'reserva_nombre'
                                               and t.estado = 'ante_el_ente')
           or (t.tipo = 'protocolizacion_acta' and d.tipo = 'pago_aranceles'
                                               and t.estado in ('enviado','en_revision','ante_el_ente'))
         )
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- 2b. EL EQUIPO DEJA EL DOCUMENTO PARA PAGARLA
-- ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 17 de septiembre de 2026, por la tarde: el CIIP no
--  sube el comprobante de la reserva. Envía un documento para que el
--  inversionista pague, y el comprobante lo sube él. Subido, el requisito
--  queda cumplido.
--
--  Por la mañana esta sección dejaba al equipo subir el propio comprobante
--  (reserva_nombre). Esas dos políticas se quitan: con ellas puestas el
--  equipo podría seguir haciéndolo desde fuera de la pantalla.
drop policy if exists "documentos: el equipo sube la reserva del nombre" on public.documentos;
drop policy if exists "adjuntos: el equipo engancha la reserva del nombre" on public.tramite_documentos;

--  «documentos: el equipo entrega lo emitido» (supabase-emision.sql) solo
--  deja al gestor dejar papeles de tipo 'resolucion'. Se abre este otro al
--  lado, con su propia política, y con el mismo cerrojo que aquella: entra
--  'validado', que es lo que impide al inversionista borrarlo sin querer.
--  El archivo va a la carpeta 'emitidos', que el cubo ya le deja al equipo.
drop policy if exists "documentos: el equipo sube el documento para pagar la reserva" on public.documentos;
create policy "documentos: el equipo sube el documento para pagar la reserva" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_reserva_nombre' and estado = 'validado');

--  Y engancharlo: solo a una constitución, y solo ante el ente, que es
--  cuando el paso se ofrece. El papel tiene que ser de la bóveda del mismo
--  inversionista del trámite, para no colgarle a alguien el de otro.
drop policy if exists "adjuntos: el equipo engancha el documento para pagar la reserva" on public.tramite_documentos;
create policy "adjuntos: el equipo engancha el documento para pagar la reserva" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_reserva_nombre'
         and t.tipo = 'constitucion'
         and t.estado = 'ante_el_ente'
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- 3. SIN COMPROBANTE, NO HAY «RESUELTA»
-- ───────────────────────────────────────────────────────────────────────
--  Va en su propio trigger y no dentro de tramites_solo_la_escalera: aquel
--  dice en qué ORDEN se pasa de un estado a otro, para todos los trámites;
--  esto dice qué hace falta para UN paso de UN trámite. Juntos se leerían
--  como una sola regla, y el día que haya otra condición así se añade otro
--  trigger al lado en vez de un if más dentro de la escalera.
--
--  Los BEFORE UPDATE corren por orden alfabético de nombre, así que este
--  (tramites_reserva_nombre) va detrás de la escalera (tramites_proteger):
--  un salto que la escalera no deja ya no llega aquí.
--
--  security definer para mirar los papeles sin depender del RLS de quien
--  resuelve: la regla es la misma la resuelva quien la resuelva.
--
--  Desde el SQL Editor (auth.uid() nulo) no estorba, igual que la escalera:
--  hace falta poder enderezar a mano un expediente atascado.
create or replace function public.tramites_constitucion_con_reserva()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'constitucion' then
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
       and d.tipo = 'reserva_nombre'
  ) then
    raise exception 'La constitución no se resuelve sin el comprobante de la reserva del nombre'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists tramites_reserva_nombre on public.tramites;
create trigger tramites_reserva_nombre
  before update on public.tramites
  for each row execute function public.tramites_constitucion_con_reserva();


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--   select codigo, nombre, vence from public.tipos_documento
--    where codigo in ('reserva_nombre', 'planilla_reserva_nombre');  -- dos filas
--
--   select polname from pg_policy
--    where polname in ('adjuntos: papeles de un paso, con el tramite en marcha',
--                      'documentos: el equipo sube el documento para pagar la reserva',
--                      'adjuntos: el equipo engancha el documento para pagar la reserva');
--                                                          -- tres filas
--
--   select polname from pg_policy
--    where polname in ('documentos: el equipo sube la reserva del nombre',
--                      'adjuntos: el equipo engancha la reserva del nombre');
--                                                          -- ninguna
--
--   select tgname from pg_trigger where tgname = 'tramites_reserva_nombre';
--
--  Y la regla, con una cuenta del equipo (no desde el SQL Editor, que no
--  estorba): marcar resuelta una constitución en 'ante_el_ente' sin el
--  papel tiene que responder
--    La constitución no se resuelve sin el comprobante de la reserva del nombre
