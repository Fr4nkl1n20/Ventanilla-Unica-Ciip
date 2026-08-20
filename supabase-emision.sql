-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — ENTREGAR LO EMITIDO
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-tramites.sql y de supabase-gestor.sql.
-- ═══════════════════════════════════════════════════════════════════════
--
--  LA MITAD QUE FALTABA
--  ─────────────────────────────────────────────────────────────────────
--  El circuito terminaba en el aire. El gestor pulsaba "Resuelta", el
--  estado cambiaba, el inversionista recibía un aviso… y nada más. El RIF,
--  la licencia, la solvencia —lo único que la persona vino a buscar— se
--  entregaban por fuera: un correo, un WhatsApp, una carpeta compartida.
--
--  Con esto, el documento que emitió el organismo entra por el panel:
--  queda en la bóveda del inversionista, colgado de su trámite, y se abre
--  con una URL firmada como todo lo demás.
--
--  LO QUE NO ES
--  ─────────────────────────────────────────────────────────────────────
--  Esto NO es emisión con validez legal. No hay firma electrónica
--  avanzada, ni sellado de tiempo, ni código de verificación. Es la
--  ENTREGA de un documento que emitió el ente por su cuenta. Un PDF que
--  llega por el canal correcto, no un certificado que este sistema expide.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
--  1 · UN TIPO DE DOCUMENTO PARA LO EMITIDO
-- ───────────────────────────────────────────────────────────────────────
-- No caduca por sí mismo: unos vencen y otros no, y eso lo pone el gestor
-- al entregarlo, que es quien tiene el papel delante.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('resolucion', 'Documento emitido por el organismo', false)
on conflict (codigo) do update set nombre = excluded.nombre;


-- ───────────────────────────────────────────────────────────────────────
--  2 · EL EQUIPO PUEDE DEJAR UN DOCUMENTO EN LA BÓVEDA DE OTRO
-- ───────────────────────────────────────────────────────────────────────
-- Y SOLO de este tipo. Un gestor no puede plantarle a nadie un pasaporte
-- ni un acta: solo lo que el organismo emitió y él está entregando.
--
-- Entra como 'validado' a propósito: lo emitió el ente, no hay nada que
-- revisar, y de paso la política "documentos: borrar los no validados"
-- impide que el inversionista lo borre sin querer.
drop policy if exists "documentos: el equipo entrega lo emitido" on public.documentos;
create policy "documentos: el equipo entrega lo emitido" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'resolucion' and estado = 'validado');

-- Y colgarlo del trámite. Sin esto el documento estaría en la bóveda pero
-- suelto, sin decir de qué solicitud salió.
drop policy if exists "adjuntos: el equipo cuelga lo emitido" on public.tramite_documentos;
create policy "adjuntos: el equipo cuelga lo emitido" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1 from public.documentos d
      where d.id = documento and d.tipo = 'resolucion'
    )
  );


-- ───────────────────────────────────────────────────────────────────────
--  3 · Y SUBIR EL ARCHIVO A LA CARPETA DEL INVERSIONISTA
-- ───────────────────────────────────────────────────────────────────────
-- El equipo ya podía LEER cualquier carpeta del cubo —para revisar los
-- recaudos—, pero solo escribir en la suya. Aquí necesita dejar el archivo
-- en la del inversionista, que es donde vive su expediente.
--
-- Se limita a la subcarpeta 'emitidos': así lo que el equipo deja queda
-- separado de lo que subió la persona, y una ruta lo dice sin consultar
-- nada.
drop policy if exists "recaudos: el equipo deja lo emitido" on storage.objects;
create policy "recaudos: el equipo deja lo emitido" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'recaudos'
    and public.es_gestor()
    and (storage.foldername(name))[2] = 'emitidos'
  );


-- ───────────────────────────────────────────────────────────────────────
--  COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
-- Las tres políticas nuevas tienen que aparecer:
--   select policyname from pg_policies
--    where policyname like '%emitido%' or policyname like '%entrega%';
--
-- Y el tipo de documento:
--   select * from public.tipos_documento where codigo = 'resolucion';
