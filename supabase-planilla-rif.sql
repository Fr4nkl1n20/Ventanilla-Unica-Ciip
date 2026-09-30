-- La planilla del RIF que manda el CIIP para firmarla (Franklin Reyes,
-- 30-9-2026): el gestor la deja en «Planilla enviada por el CIIP» y el
-- inversionista la descarga en «Firme la planilla». Se puede correr más de
-- una vez. Sin él el panel no se rompe: la subida falla y lo dice.

insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_solicitud', 'Planilla de solicitud del RIF (la prepara el CIIP)', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

drop policy if exists "documentos: el equipo sube la planilla del RIF" on public.documentos;
create policy "documentos: el equipo sube la planilla del RIF" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_solicitud' and estado = 'validado');

drop policy if exists "adjuntos: el equipo engancha la planilla del RIF" on public.tramite_documentos;
create policy "adjuntos: el equipo engancha la planilla del RIF" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_solicitud'
         and t.tipo in ('rif_personal', 'rif_empresa')
         and t.estado in ('enviado', 'en_revision')
    )
  );

-- COMPROBACIÓN
--   select codigo from public.tipos_documento where codigo = 'planilla_solicitud';   -- una fila
--   select polname from pg_policy where polname like '%planilla del RIF%';           -- dos filas
