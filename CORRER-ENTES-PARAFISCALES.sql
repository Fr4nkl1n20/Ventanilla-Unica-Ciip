insert into public.tipos_documento (codigo, nombre, vence) values
  ('codigo_ente', 'Código o constancia que envió un ente', false)
on conflict (codigo) do update set nombre = excluded.nombre;

create table if not exists public.tramite_entes (
  tramite        uuid not null references public.tramites(id) on delete cascade,
  ente           text not null check (ente in ('banavih', 'inces', 'mpppst', 'sundde', 'snc')),
  codigo         text check (codigo is null or length(codigo) <= 200),
  documento      uuid references public.documentos(id) on delete set null,
  estado         text not null default 'codigo_enviado' check (estado in ('codigo_enviado', 'listo')),
  actualizado_en timestamptz not null default now(),
  primary key (tramite, ente)
);

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
    estado <> 'listo'
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

select policyname, cmd from pg_policies where tablename = 'tramite_entes' order by policyname;
