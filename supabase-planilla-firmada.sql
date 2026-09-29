-- La planilla firmada, de vuelta desde «Firme la planilla» (Franklin Reyes,
-- 29-9-2026): el inversionista la sube desde ese paso de su escalera, con
-- la solicitud ya enviada, en los dos RIF (c3, c6) y en la licencia (c10).
-- Solo necesita tipos_documento, tramites, documentos y tramite_documentos.
-- Se puede correr más de una vez. Sin él el panel no se rompe: la subida
-- falla y el paso lo dice.

insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_firmada', 'Planilla de solicitud firmada', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- «adjuntos: adjuntar a lo propio» solo deja colgar papeles en borrador o
-- devuelta; ésta llega con la solicitud en marcha. Va en su propia
-- política, como la del SIDCAI: las políticas se suman, y así no se
-- reescribe la de otro archivo.
drop policy if exists "adjuntos: la planilla firmada, desde su paso" on public.tramite_documentos;
create policy "adjuntos: la planilla firmada, desde su paso" on public.tramite_documentos
  for insert
  with check (
    exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and t.inversionista = auth.uid()
         and d.inversionista = auth.uid()
         and d.tipo = 'planilla_firmada'
         and t.tipo in ('rif_personal', 'rif_empresa', 'licencia_municipal')
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
  );

-- COMPROBACIÓN
--   select codigo, nombre from public.tipos_documento where codigo = 'planilla_firmada';  -- una fila
--   select polname from pg_policy
--    where polname = 'adjuntos: la planilla firmada, desde su paso';                     -- una fila
