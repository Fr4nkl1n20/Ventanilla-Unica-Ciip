-- SQL Editor de Supabase. Los tres son independientes y reejecutables.


-- ── 1. EL COMPROBANTE DE LA PUBLICACION ──────────────────────────────

-- Cuantos hay enganchados hoy. Con publicaciones en marcha, un 0 es el fallo.
select count(*) as enganchados
  from public.tramite_documentos td
  join public.documentos d on d.id = td.documento
 where d.tipo = 'pago_publicacion';

-- La politica, con el caso de la publicacion añadido.
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

-- Comprobar: una fila.
select policyname, cmd
  from pg_policies
 where schemaname = 'public' and tablename = 'tramite_documentos'
   and policyname = 'adjuntos: papeles de un paso, con el tramite en marcha';

-- Los que se subieron y no llegaron a engancharse.
select d.id, d.inversionista, d.nombre_original, d.creado_en
  from public.documentos d
 where d.tipo = 'pago_publicacion'
   and not exists (select 1 from public.tramite_documentos td where td.documento = d.id)
 order by d.creado_en desc;


-- ── 2. LAS TRES FICHAS RETIRADAS ─────────────────────────────────────

-- Cuantas solicitudes hay de las tres. Vacio = ninguna.
select tipo, count(*) as solicitudes
  from public.tramites
 where tipo in ('antecedentes_penales', 'constancia_domicilio', 'visa_dependientes')
 group by tipo;

-- Se apagan siempre.
update public.tipos_tramite set activo = false
 where codigo in ('antecedentes_penales', 'constancia_domicilio', 'visa_dependientes');

-- Y se borran solo si nadie tiene una.
delete from public.tipos_tramite
 where codigo in ('antecedentes_penales', 'constancia_domicilio', 'visa_dependientes')
   and not exists (
     select 1 from public.tramites t where t.tipo = tipos_tramite.codigo
   );

-- Comprobar: lo que quede sale aqui, apagado.
select codigo, ref_panel, activo
  from public.tipos_tramite
 where codigo in ('antecedentes_penales', 'constancia_domicilio', 'visa_dependientes');


-- ── 3. LA PUBLICACION HEREDA LOS DATOS DEL ACTA ──────────────────────

create or replace function public.protocolizacion_abre_la_publicacion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  copia jsonb := '{}'::jsonb;
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'protocolizacion_acta' then
    return new;
  end if;

  if not exists (
    select 1 from public.tipos_tramite
     where codigo = 'publicacion_acta' and coalesce(activo, true)
  ) then
    return new;
  end if;

  if exists (
    select 1 from public.tramites
     where inversionista = new.inversionista
       and tipo = 'publicacion_acta'
  ) then
    return new;
  end if;

  if coalesce(new.datos->>'razon_social', '') <> '' then
    copia := copia || jsonb_build_object('razon_social', new.datos->>'razon_social');
  end if;

  if coalesce(new.datos->>'numero_registro', '') <> '' then
    copia := copia || jsonb_build_object('numero_registro', new.datos->>'numero_registro');
  end if;

  if coalesce(new.datos->>'fecha_protocolizacion', '') <> '' then
    copia := copia || jsonb_build_object('fecha_protocolizacion',
                                         new.datos->>'fecha_protocolizacion');
  end if;

  insert into public.tramites (inversionista, tipo, estado, datos, enviado_en, gestor)
  values (new.inversionista, 'publicacion_acta', 'enviado', copia, now(), new.gestor);

  return new;
end;
$$;

drop trigger if exists tramites_abre_publicacion on public.tramites;
create trigger tramites_abre_publicacion
  after update on public.tramites
  for each row execute function public.protocolizacion_abre_la_publicacion();

-- Comprobar: una fila.
select tgname from pg_trigger where tgname = 'tramites_abre_publicacion';
