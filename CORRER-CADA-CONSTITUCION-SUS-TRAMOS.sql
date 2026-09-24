-- SQL Editor de Supabase. Se puede correr mas de una vez.

-- 1. La columna que ata cada tramo a la solicitud que lo abrio. Va la
--    primera: la consulta que la mira no puede ir antes de crearla.
alter table public.tramites
  add column if not exists viene_de uuid references public.tramites(id) on delete set null;

create index if not exists tramites_por_origen on public.tramites (viene_de)
  where viene_de is not null;

comment on column public.tramites.viene_de is 'La solicitud que abrio este tramo. Null = no viene de ninguna';

-- 2. Cuantos tramos hay y cuantos saben ya de donde salen. Recien creada
--    la columna, con_origen sale en 0.
select tipo, count(*) as cuantos, count(viene_de) as con_origen
  from public.tramites
 where tipo in ('protocolizacion_acta', 'publicacion_acta')
 group by tipo;


-- 3. Y los dos triggers, con la guarda por SOLICITUD y no por inversionista.
create or replace function public.constitucion_abre_la_protocolizacion()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  copia jsonb := '{}'::jsonb;
  junta text;
  quien text;
begin
  if new.estado is not distinct from old.estado then return new; end if;
  if new.estado <> 'resuelto' or new.tipo <> 'constitucion' then return new; end if;

  if not exists (
    select 1 from public.tipos_tramite
     where codigo = 'protocolizacion_acta' and coalesce(activo, true)
  ) then return new; end if;

  if exists (
    select 1 from public.tramites
     where viene_de = new.id and tipo = 'protocolizacion_acta'
  ) then return new; end if;

  if coalesce(new.datos->>'denominacion', '') <> '' then
    copia := copia || jsonb_build_object('razon_social', new.datos->>'denominacion');
  end if;
  if coalesce(new.datos->>'capital_social', '') <> '' then
    copia := copia || jsonb_build_object('capital_social', new.datos->>'capital_social');
  end if;
  if coalesce(new.datos->>'oficina_registro', '') <> '' then
    copia := copia || jsonb_build_object('registro_mercantil', new.datos->>'oficina_registro');
  end if;

  junta := coalesce(new.datos->>'junta_directiva', '');
  if junta <> '' then
    quien := btrim(split_part(split_part(junta, ';', 1), '(', 1));
    if quien <> '' then
      copia := copia || jsonb_build_object('representante', quien);
    end if;
  end if;

  insert into public.tramites (inversionista, tipo, estado, datos, enviado_en, gestor, viene_de)
  values (new.inversionista, 'protocolizacion_acta', 'enviado', copia, now(), new.gestor, new.id);

  return new;
end;
$$;

create or replace function public.protocolizacion_abre_la_publicacion()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  copia jsonb := '{}'::jsonb;
begin
  if new.estado is not distinct from old.estado then return new; end if;
  if new.estado <> 'resuelto' or new.tipo <> 'protocolizacion_acta' then return new; end if;

  if not exists (
    select 1 from public.tipos_tramite
     where codigo = 'publicacion_acta' and coalesce(activo, true)
  ) then return new; end if;

  if exists (
    select 1 from public.tramites
     where viene_de = new.id and tipo = 'publicacion_acta'
  ) then return new; end if;

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

  insert into public.tramites (inversionista, tipo, estado, datos, enviado_en, gestor, viene_de)
  values (new.inversionista, 'publicacion_acta', 'enviado', copia, now(), new.gestor, new.id);

  return new;
end;
$$;

-- 4. Y se atan hacia atras los que ya existen, SOLO cuando no hay duda:
--    una sola constitucion de esa persona y un solo tramo suelto. Con dos
--    se quedan sin atar, que es preferible a adivinar mal.
update public.tramites p
   set viene_de = c.id
  from public.tramites c
 where p.tipo = 'protocolizacion_acta'
   and p.viene_de is null
   and c.inversionista = p.inversionista
   and c.tipo = 'constitucion'
   and (select count(*) from public.tramites x
         where x.inversionista = p.inversionista and x.tipo = 'constitucion') = 1
   and (select count(*) from public.tramites x
         where x.inversionista = p.inversionista and x.tipo = 'protocolizacion_acta') = 1;

update public.tramites b
   set viene_de = p.id
  from public.tramites p
 where b.tipo = 'publicacion_acta'
   and b.viene_de is null
   and p.inversionista = b.inversionista
   and p.tipo = 'protocolizacion_acta'
   and (select count(*) from public.tramites x
         where x.inversionista = b.inversionista and x.tipo = 'protocolizacion_acta') = 1
   and (select count(*) from public.tramites x
         where x.inversionista = b.inversionista and x.tipo = 'publicacion_acta') = 1;

-- 5. Comprobar: cuantos quedan sin atar. Los que queden son de personas con
--    mas de una, y se atan a mano o se quedan asi.
select tipo, count(*) as cuantos, count(viene_de) as con_origen
  from public.tramites
 where tipo in ('protocolizacion_acta', 'publicacion_acta')
 group by tipo;
