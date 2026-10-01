-- Control y Estadísticas (Franklin Reyes, 1-10-2026): el sector de cada consulta, los trámites
-- específicos de cada sector y las cifras del administrador. Va detrás de supabase-admin.sql
-- (es_admin), supabase-consultas.sql y supabase-tramites.sql. Se puede correr más de una vez.

-- 1. EL SECTOR DE LA CONSULTA
-- Lo elige el inversionista en la consulta nueva que abre la franja del final del catálogo.
-- Hasta hoy solo iba escrito, traducido, en el asunto, y un texto en ocho idiomas no se cuenta.
-- Se guarda un código estable; los seis que ya existían en public.sectores se reutilizan tal
-- cual, y energetico, telecomunicaciones y construccion son nuevos. No es una clave foránea
-- a public.sectores porque ese catálogo es el del perfil y no tiene esos tres.
alter table public.consultas
  add column if not exists sector text;

alter table public.consultas
  drop constraint if exists consultas_sector_valido;
alter table public.consultas
  add constraint consultas_sector_valido check (sector is null or sector in (
    'hidrocarburos', 'mineria', 'industrial', 'agroindustrial', 'pesca_acuicultura',
    'energetico', 'telecomunicaciones', 'turismo', 'construccion'));

comment on column public.consultas.sector is 'Sector que eligió el inversionista al abrir la consulta desde la franja del catálogo. Null = no eligió ninguno';

create index if not exists consultas_por_sector
  on public.consultas (sector) where sector is not null;

-- 2. LOS TRÁMITES ESPECÍFICOS DE CADA SECTOR
-- La lista la escribe el administrador en «Control y Estadísticas»; el inversionista la ve en
-- el chat al elegir el sector. Leer, cualquiera con sesión; escribir, solo el administrador.
create table if not exists public.tramites_por_sector (
  id             uuid primary key default gen_random_uuid(),
  sector         text not null,
  nombre         text not null,
  organismo      text not null default '',
  orden          integer not null default 0,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),

  constraint tramites_por_sector_sector_valido check (sector in (
    'hidrocarburos', 'mineria', 'industrial', 'agroindustrial', 'pesca_acuicultura',
    'energetico', 'telecomunicaciones', 'turismo', 'construccion')),
  constraint tramites_por_sector_nombre_cabe check (length(trim(nombre)) between 1 and 200),
  constraint tramites_por_sector_organismo_cabe check (length(organismo) <= 200)
);

comment on table public.tramites_por_sector is 'Trámites específicos por los que pregunta el inversionista en cada sector; los carga el administrador';

create index if not exists tramites_por_sector_lista
  on public.tramites_por_sector (sector, orden);

create or replace function public.tramites_por_sector_al_cambiar()
returns trigger
language plpgsql
as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

drop trigger if exists tramites_por_sector_cambio on public.tramites_por_sector;
create trigger tramites_por_sector_cambio
  before update on public.tramites_por_sector
  for each row execute function public.tramites_por_sector_al_cambiar();

alter table public.tramites_por_sector enable row level security;

drop policy if exists "tramites_por_sector: leerlos" on public.tramites_por_sector;
create policy "tramites_por_sector: leerlos"
  on public.tramites_por_sector for select
  to authenticated
  using (true);

drop policy if exists "tramites_por_sector: solo el admin escribe" on public.tramites_por_sector;
create policy "tramites_por_sector: solo el admin escribe"
  on public.tramites_por_sector for all
  using      (public.es_admin())
  with check (public.es_admin());

grant select, insert, update, delete on public.tramites_por_sector to authenticated;

-- 3. LAS CIFRAS
-- Una sola función, security definer, que comprueba ella misma que quien llama es
-- administrador: así el conteo no depende de qué políticas de lectura haya corridas en
-- tramites, tramite_eventos y consultas, y lo que viaja son las cifras y no las filas.
-- Solicitado = enviado alguna vez (enviado_en, o un estado posterior al borrador); los
-- borradores y lo cancelado sin enviar no cuentan. El tiempo, solo de lo resuelto: de
-- enviado_en a resuelto_en, que pone el disparador registrar_evento_tramite(); y aparte, el
-- tramo «ante el ente», del primer evento ante_el_ente a resuelto_en.
create or replace function public.estadisticas_control()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r jsonb;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve las estadísticas' using errcode = '42501';
  end if;

  with enviados as (
    select t.id, t.tipo, coalesce(tt.ente, '') as ente, t.estado,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
  resueltos as (
    select e.tipo, e.ente,
           extract(epoch from (e.resuelto_en - e.desde)) / 3600.0 as horas,
           (select extract(epoch from (e.resuelto_en - min(ev.creado_en))) / 3600.0
              from public.tramite_eventos ev
             where ev.tramite = e.id and ev.a_estado = 'ante_el_ente'
            having min(ev.creado_en) <= e.resuelto_en) as horas_ente
      from enviados e
     where e.estado = 'resuelto'
       and e.resuelto_en is not null
       and e.resuelto_en >= e.desde
  ),
  por_tipo as (
    select tipo, max(ente) as ente, count(*) as solicitados
      from enviados
     group by tipo
  ),
  tiempo_tipo as (
    select tipo,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente
      from resueltos
     group by tipo
  ),
  tiempo_ente as (
    select ente,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente
      from resueltos
     group by ente
  ),
  por_sector as (
    select sector, count(*) as n
      from public.consultas
     where sector is not null
     group by sector
  )
  select jsonb_build_object(
    'tramites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', p.tipo, 'ente', p.ente, 'solicitados', p.solicitados,
               'resueltos', coalesce(x.n, 0),
               'mediana_h', round(x.mediana::numeric, 1),
               'promedio_h', round(x.promedio::numeric, 1),
               'n_ente', coalesce(x.n_ente, 0),
               'mediana_ente_h', round(x.mediana_ente::numeric, 1))
             order by p.solicitados desc, p.tipo)
        from por_tipo p
        left join tiempo_tipo x on x.tipo = p.tipo), '[]'::jsonb),
    'entes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ente', y.ente, 'resueltos', y.n,
               'mediana_h', round(y.mediana::numeric, 1),
               'promedio_h', round(y.promedio::numeric, 1),
               'n_ente', y.n_ente,
               'mediana_ente_h', round(y.mediana_ente::numeric, 1))
             order by y.n desc, y.ente)
        from tiempo_ente y), '[]'::jsonb),
    'sectores', coalesce((
      select jsonb_agg(jsonb_build_object('sector', s.sector, 'consultas', s.n)
             order by s.n desc, s.sector)
        from por_sector s), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;
