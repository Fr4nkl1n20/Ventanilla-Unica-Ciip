-- Los registros parafiscales sin código (pedido del CIIP, 28-9-2026): solo
-- el IVSS y el INCES le mandan algo al inversionista -usuario y contraseña-.
-- En los otros cuatro el CIIP inscribe y da la inscripción por lista, sin
-- código por medio. El equipo ya podía ir de 'pendiente' a 'listo' con su
-- política de siempre; lo que cambia es que el inversionista solo escribe
-- en las filas del IVSS y del INCES.
-- Va después de supabase-entes-parafiscales.sql. Se puede correr más de una vez.

drop policy if exists "entes: el inversionista manda su codigo" on public.tramite_entes;
create policy "entes: el inversionista manda su codigo" on public.tramite_entes
  for insert with check (
    estado = 'codigo_enviado'
    and ente in ('ivss', 'inces')
    and exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
         and t.tipo = 'registros_parafiscales'
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
    and (documento is null or exists (
      select 1 from public.documentos d
       where d.id = tramite_entes.documento and d.inversionista = auth.uid()
    ))
  );

drop policy if exists "entes: el inversionista corrige su codigo" on public.tramite_entes;
create policy "entes: el inversionista corrige su codigo" on public.tramite_entes
  for update
  using (
    estado in ('inscrito', 'codigo_enviado')
    and ente in ('ivss', 'inces')
    and exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
  )
  with check (
    estado = 'codigo_enviado'
    and ente in ('ivss', 'inces')
    and exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
    and (documento is null or exists (
      select 1 from public.documentos d
       where d.id = tramite_entes.documento and d.inversionista = auth.uid()
    ))
  );

-- Comprobación: las mismas cuatro políticas, y las dos del inversionista
-- nombrando al IVSS y al INCES.
select policyname, cmd,
       coalesce(qual, '') ilike '%ivss%' or coalesce(with_check, '') ilike '%ivss%' as solo_ivss_inces
  from pg_policies where tablename = 'tramite_entes' order by policyname;
