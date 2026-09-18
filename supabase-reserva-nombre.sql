-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL COMPROBANTE DE LA RESERVA DEL NOMBRE (c5)
--  Va DESPUÉS de supabase-tramites.sql: toca tipos_documento y tres
--  políticas. Va al final para no mover el número de nadie.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 16 de septiembre de 2026: la constitución de la
--  compañía gana un paso entre «Reserva de nombre» y «Resuelta», donde va
--  el comprobante de la reserva del nombre.
--
--  CÓMO ES EL CIRCUITO (Franklin Reyes, 18 de septiembre de 2026)
--  ───────────────────────────────────────────────────────────────────────
--  El CIIP manda al inversionista el documento con los datos para pagar,
--  el inversionista paga, y DESPUÉS sube el comprobante. Así que el papel
--  llega tarde por definición, y no puede cerrarle el paso a nadie: el
--  trigger que impedía resolver sin él estuvo puesto dos días y se quitó
--  (apartado 3).
--
--  Y de paso lo mismo para el pago de los aranceles de la protocolización
--  (c22): ese papel se sube desde su paso, con el trámite ya en marcha, y
--  hasta hoy la base solo dejaba adjuntar a una solicitud en borrador o
--  devuelta.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE, pero el paso se queda cojo: el
--  inversionista ve el botón de subir y la subida falla al engancharla.
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
-- 3. AQUÍ HUBO UN CANDADO, Y SE QUITÓ
-- ───────────────────────────────────────────────────────────────────────
--  El 16 de septiembre esto era «sin comprobante no hay resuelta»: un
--  trigger que impedía marcar resuelta una constitución sin el comprobante
--  de la reserva del nombre.
--
--  Se quita el 18 de septiembre de 2026, con el circuito ya contado por el
--  CIIP: el equipo manda al inversionista el documento con los datos para
--  pagar, el inversionista paga, y SÓLO DESPUÉS sube el comprobante. Entre
--  una cosa y otra pasan días que no dependen del CIIP, y el candado dejaba
--  la constitución parada sin que nadie del equipo pudiera destrabarla.
--
--  El paso NO desaparece: sigue en la escalera del inversionista, con su
--  casilla para subir el comprobante, y las políticas de arriba siguen
--  dejando que lo adjunte con el trámite en marcha. Lo único que se va es
--  el cierre a quien todavía no tiene el papel en la mano.
--
--  Se borra aquí, y no en un archivo nuevo, para que una base que ya lo
--  tenía puesto se quede sin él al volver a pasar este archivo.
drop trigger if exists tramites_reserva_nombre on public.tramites;
drop function if exists public.tramites_constitucion_con_reserva();


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
--                                                          -- NINGUNA fila
