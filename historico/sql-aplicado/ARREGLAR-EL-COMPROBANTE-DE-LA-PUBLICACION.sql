-- SQL Editor de Supabase. Se puede correr mas de una vez.

-- 1. Cuantos comprobantes de la publicacion hay enganchados hoy.
--    Si sale 0 teniendo publicaciones en marcha, es el fallo.
select count(*) as enganchados
  from public.tramite_documentos td
  join public.documentos d on d.id = td.documento
 where d.tipo = 'pago_publicacion';

-- 2. La politica, con el caso de la publicacion añadido.
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
           or (t.tipo = 'publicacion_acta'     and d.tipo = 'pago_publicacion'
                                               and t.estado in ('enviado','en_revision','ante_el_ente'))
         )
    )
  );

-- 3. Comprobar: tiene que salir una fila.
select policyname, cmd
  from pg_policies
 where schemaname = 'public' and tablename = 'tramite_documentos'
   and policyname = 'adjuntos: papeles de un paso, con el tramite en marcha';

-- 4. Los comprobantes que se subieron y no se engancharon. Son los que el
--    inversionista dio por subidos y no llegaron a su tramite.
select d.id, d.inversionista, d.nombre_original, d.creado_en
  from public.documentos d
 where d.tipo = 'pago_publicacion'
   and not exists (select 1 from public.tramite_documentos td where td.documento = d.id)
 order by d.creado_en desc;
