-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS CINCO ENTES DE LOS REGISTROS PARAFISCALES
--  Va DESPUÉS de supabase-tramites.sql y de supabase-parafiscales.sql.
--  Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  Franklin Reyes, 23-9-2026: los registros parafiscales (c37) son UNA
--  solicitud con un solo envío de recaudos, pero ante cinco entes, y cada
--  uno avanza por su cuenta: el ente le manda un código al inversionista,
--  el inversionista nos lo manda a nosotros y con eso el CIIP da ese ente
--  por listo.
--
--  Una fila por solicitud y ente, con cuatro estados: pendiente, inscrito,
--  codigo_enviado y listo. El ente no manda su código hasta que el CIIP
--  inscribe a la empresa ante él, así que la inscripción es el primer paso
--  y es tarea del gestor: 'pendiente' → 'inscrito'. Luego el inversionista
--  escribe el código -y si quiere, adjunta un archivo- y la fila queda en
--  'codigo_enviado'; solo el equipo la pone en 'listo'. Una vez lista, el
--  inversionista ya no la toca.
--
--  25-9-2026 (Franklin): las cinco filas NACEN SOLAS al enviarse la
--  solicitud, las crea un disparador de la base. «Una fila que solo existe
--  si alguien abrió una pantalla no es una fila, es una casualidad»: el
--  gestor tiene que verlas aunque el inversionista no haya entrado nunca.
--  Esto vivía solo en CORRER-HOY-2026-09-25.sql; desde el mismo día está
--  aquí, que es de donde sale TODO-EN-ORDEN.sql.
-- ═══════════════════════════════════════════════════════════════════════

insert into public.tipos_documento (codigo, nombre, vence) values
  ('codigo_ente', 'Código o constancia que envió un ente', false)
on conflict (codigo) do update set nombre = excluded.nombre;

create table if not exists public.tramite_entes (
  tramite        uuid not null references public.tramites(id) on delete cascade,
  ente           text not null check (ente in ('banavih', 'inces', 'mpppst', 'sundde', 'ivss', 'snc')),
  codigo         text check (codigo is null or length(codigo) <= 200),
  documento      uuid references public.documentos(id) on delete set null,
  estado         text not null default 'pendiente'
                 check (estado in ('pendiente', 'inscrito', 'codigo_enviado', 'listo')),
  actualizado_en timestamptz not null default now(),
  primary key (tramite, ente)
);

-- En una base donde la tabla ya existía con los dos estados de antes, el
-- create table de arriba no toca nada: se cambia aquí la regla y el valor
-- por defecto. Se busca por lo que dice y no por su nombre, que lo pone
-- Postgres.
do $entes$
declare c text;
begin
  for c in select conname from pg_constraint
            where conrelid = 'public.tramite_entes'::regclass
              and contype = 'c'
              and pg_get_constraintdef(oid) ilike '%estado%'
  loop
    execute format('alter table public.tramite_entes drop constraint %I', c);
  end loop;
end $entes$;
alter table public.tramite_entes add constraint tramite_entes_estado_check
  check (estado in ('pendiente', 'inscrito', 'codigo_enviado', 'listo'));
alter table public.tramite_entes alter column estado set default 'pendiente';

-- El IVSS, la sexta inscripción (Franklin Reyes, 25-9-2026; venía en
-- CORRER-PARAFISCALES-2026-09-25.sql). Igual que arriba: en una base con la
-- tabla ya creada con cinco entes, se cambia la regla.
do $entes$
declare c text;
begin
  for c in select conname from pg_constraint
            where conrelid = 'public.tramite_entes'::regclass
              and contype = 'c'
              and pg_get_constraintdef(oid) ilike '%ente%'
              and pg_get_constraintdef(oid) not ilike '%estado%'
  loop
    execute format('alter table public.tramite_entes drop constraint %I', c);
  end loop;
end $entes$;
alter table public.tramite_entes add constraint tramite_entes_ente_check
  check (ente in ('banavih', 'inces', 'mpppst', 'sundde', 'ivss', 'snc'));

alter table public.tramite_entes enable row level security;
grant select, insert, update, delete on public.tramite_entes to authenticated;

drop policy if exists "entes: leer los propios" on public.tramite_entes;
create policy "entes: leer los propios" on public.tramite_entes
  for select using (
    public.es_gestor() or exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
    )
  );

--  El inversionista, solo en su solicitud de parafiscales y con ella en
--  marcha: ni en borrador -todavía no la ha mandado- ni resuelta.
drop policy if exists "entes: el inversionista manda su codigo" on public.tramite_entes;
create policy "entes: el inversionista manda su codigo" on public.tramite_entes
  for insert with check (
    estado = 'codigo_enviado'
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
    -- El código solo se manda con el ente ya inscrito por el CIIP: que la
    -- pantalla esconda el botón no impide que alguien llame a la API.
    estado in ('inscrito', 'codigo_enviado')
    and exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
  )
  with check (
    estado = 'codigo_enviado'
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

drop policy if exists "entes: el equipo los lleva" on public.tramite_entes;
create policy "entes: el equipo los lleva" on public.tramite_entes
  for all using (public.es_gestor()) with check (public.es_gestor());

create or replace function public.tramite_entes_marca_tiempo()
returns trigger language plpgsql as $$
begin
  new.actualizado_en := now();
  return new;
end $$;

drop trigger if exists tramite_entes_marca_tiempo on public.tramite_entes;
create trigger tramite_entes_marca_tiempo
  before update on public.tramite_entes
  for each row execute function public.tramite_entes_marca_tiempo();

-- Las seis nacen solas al enviarse la solicitud de parafiscales.
create or replace function public.tramite_entes_nacen()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.tipo = 'registros_parafiscales'
     and new.estado in ('enviado', 'en_revision', 'ante_el_ente') then
    insert into public.tramite_entes (tramite, ente, estado)
    select new.id, e, 'pendiente'
      from unnest(array['banavih', 'inces', 'mpppst', 'sundde', 'ivss', 'snc']) as e
    on conflict (tramite, ente) do nothing;
  end if;
  return new;
end $$;

drop trigger if exists tramite_entes_nacen on public.tramites;
create trigger tramite_entes_nacen
  after insert or update of estado on public.tramites
  for each row execute function public.tramite_entes_nacen();

-- Y las solicitudes que ya estaban en marcha, rellenas. No toca las filas
-- que ya existen.
insert into public.tramite_entes (tramite, ente, estado)
select t.id, e, 'pendiente'
  from public.tramites t
  cross join unnest(array['banavih', 'inces', 'mpppst', 'sundde', 'ivss', 'snc']) as e
 where t.tipo = 'registros_parafiscales'
   and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
on conflict (tramite, ente) do nothing;

-- Cada ente con su propia constancia (Franklin Reyes, 25-9-2026; venía en
-- CORRER-CONSTANCIA-DE-CADA-ENTE.sql). El equipo la deja ya validada y la
-- cuelga del trámite.
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

-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--   select policyname, cmd from pg_policies where tablename = 'tramite_entes';
--   -- cuatro: leer, mandar, corregir y la del equipo
