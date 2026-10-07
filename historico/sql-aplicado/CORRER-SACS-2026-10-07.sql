insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('permiso_sacs',    'c48', 'Servicio Autónomo de Contraloría Sanitaria',        'SACS', 3, true),
  ('sacs_en_proceso', 'c49', 'SACS: permiso ya solicitado',                       'SACS', 3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite t
   set nivel      = coalesce(s.nivel, l.nivel, 'actividad'),
       emite      = case when s.codigo is not null then s.emite else l.emite end,
       plazo_dias = coalesce(s.plazo_dias, l.plazo_dias),
       fase       = 3,
       activo     = true
  from (select 1) as uno
  left join public.tipos_tramite s on s.codigo = 'permiso_sanitario'
  left join public.tipos_tramite l on l.codigo = 'licencia_municipal'
 where t.codigo = 'permiso_sacs';

update public.tipos_tramite t
   set emite      = null,
       plazo_dias = null,
       nivel      = coalesce(m.nivel, 'actividad'),
       fase       = 3,
       activo     = true
  from (select 1) as uno
  left join public.tipos_tramite m on m.codigo = 'permiso_sacs'
 where t.codigo = 'sacs_en_proceso';

update public.tipos_tramite set activo = false where codigo = 'permiso_sanitario';

create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                     'bomberos_solicitado', 'saime_confirmada', 'locti_inscrito',
                     'sacs_registrado') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;

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
           t.datos,
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
  ),
  motivos as (
    select m.motivo, m.ente, count(*) as n
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso')
        union all
        select e.datos ->> ('motivo_ya_' || x.clave), x.ente
          from enviados e
         cross join (values ('banavih', 'BANAVIH (FAOV)'), ('inces', 'INCES'),
                            ('rupdae', 'RUPDAE'), ('ivss', 'IVSS'),
                            ('rnet', 'RNET'), ('rnc', 'RNC')) as x(clave, ente)
         where e.tipo = 'parafiscales_en_proceso'
      ) m
     where coalesce(m.motivo, '') <> ''
     group by m.motivo, m.ente
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
        from por_sector s), '[]'::jsonb),
    'motivos', coalesce((
      select jsonb_agg(jsonb_build_object('motivo', mo.motivo, 'ente', mo.ente, 'n', mo.n)
             order by mo.n desc, mo.motivo, mo.ente)
        from motivos mo), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;

select ref_panel, codigo, ente, fase, nivel, plazo_dias, activo from public.tipos_tramite
 where codigo in ('permiso_sanitario', 'permiso_sacs', 'sacs_en_proceso')
 order by ref_panel;
select position('sacs_registrado' in pg_get_functiondef('public.confirma_paso(uuid, text)'::regprocedure)) > 0
       as acepta_sacs_registrado;
