-- La planilla de inscripción del IVSS que el CIIP manda al inversionista (30-9-2026).
-- Va colgada de la fila del IVSS en tramite_entes, en la columna documento. Se puede correr más de una vez.

insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_ivss', 'Planilla de inscripción del IVSS (la prepara el CIIP)', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

drop policy if exists "documentos: el equipo manda la planilla del IVSS" on public.documentos;
create policy "documentos: el equipo manda la planilla del IVSS" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_ivss' and estado = 'validado');

drop policy if exists "adjuntos: el equipo cuelga la planilla del IVSS" on public.tramite_documentos;
create policy "adjuntos: el equipo cuelga la planilla del IVSS" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_ivss'
         and t.tipo = 'registros_parafiscales'
    )
  );

-- Solo la hace el equipo: un inversionista no puede subir una ni cambiar un papel a ese tipo.
create or replace function public.planilla_ivss_del_ciip()
returns trigger
language plpgsql
as $ivss$
begin
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.tipo = 'planilla_ivss'
     or (tg_op = 'UPDATE' and old.tipo = 'planilla_ivss') then
    raise exception 'Ese papel lo emite el CIIP'
      using errcode = 'check_violation';
  end if;
  return new;
end
$ivss$;

drop trigger if exists documentos_planilla_ivss_del_ciip on public.documentos;
create trigger documentos_planilla_ivss_del_ciip
  before insert or update on public.documentos
  for each row execute function public.planilla_ivss_del_ciip();

-- Comprobación: debe salir una fila con el tipo y dos políticas.
select codigo, nombre from public.tipos_documento where codigo = 'planilla_ivss';
select tablename, policyname from pg_policies where policyname ilike '%planilla del IVSS%';
