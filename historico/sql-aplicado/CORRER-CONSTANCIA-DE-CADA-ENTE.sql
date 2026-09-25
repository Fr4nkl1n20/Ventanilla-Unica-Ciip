insert into public.tipos_documento (codigo, nombre, vence) values
  ('constancia_ente', 'Constancia de inscripción ante el ente', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

drop policy if exists "documentos: el equipo entrega la constancia del ente" on public.documentos;
create policy "documentos: el equipo entrega la constancia del ente" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'constancia_ente' and estado = 'validado');

drop policy if exists "adjuntos: el equipo cuelga la constancia del ente" on public.tramite_documentos;
create policy "adjuntos: el equipo cuelga la constancia del ente" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1 from public.documentos d
       where d.id = documento and d.tipo = 'constancia_ente'
    )
  );

select codigo, nombre from public.tipos_documento where codigo = 'constancia_ente';

select policyname, cmd from pg_policies
 where policyname in ('documentos: el equipo entrega la constancia del ente',
                      'adjuntos: el equipo cuelga la constancia del ente');
