-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL TIEMPO DE RESPUESTA, EN SUS DOS TRAMOS
--  Va DESPUÉS de supabase-control-detalle.sql, que es quien dejó escrita
--  la última estadisticas_control(). Va al final para no mover el número
--  de nadie. Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 15 de octubre de 2026, sobre «Tiempo de respuesta» en
--  Control y estadísticas: «quiero más detalles en esta gráfica, cuántos
--  días tarda el CIIP, en cuántos días nos da respuesta el ente, más
--  detallada la información».
--
--  Hasta hoy la función daba la mediana del total y la del tramo ante el
--  ente, y el panel dibujaba el tramo del CIIP restando una de la otra.
--  Dos medianas no se restan: el resultado no es el caso típico de nada.
--  Desde aquí cada resuelto lleva sus dos tramos medidos, y de cada uno
--  salen su mediana, su promedio y su máximo:
--
--    horas_ciip   de que el inversionista envía a la primera vez que se
--                 presenta ante el ente (tramite_eventos, a 'ante_el_ente').
--                 Sin presentación, todo el tiempo es del CIIP.
--    horas_ente   de esa presentación a resuelto. Sin presentación, null:
--                 ese caso no cuenta para el ente.
--
--  Y llaves nuevas, sin tocar las de antes:
--    · en tramites y entes, mediana / promedio / maximo de cada tramo
--      (*_ciip_h, *_ente_h) y del total (maximo_h);
--    · tiempo_total, lo mismo para todos los resueltos juntos;
--    · tiempos_casos, cada resuelto con sus fechas y sus dos tramos, los
--      500 más recientes, como motivos_casos.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: la ficha enseña lo de antes y avisa
--  de que falta este archivo para ver el detalle.
-- ═══════════════════════════════════════════════════════════════════════

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
           t.datos, t.inversionista,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
  -- Cada resuelto con sus dos tramos (15-10-2026): el del CIIP, de que el inversionista
  -- envía a la primera vez que se presenta ante el ente, y el del ente, de ahí a resuelto.
  -- Sin presentación (lo resolvió el CIIP sin pasar por el ente) todo el tiempo es del CIIP
  -- y el ente no cuenta. Una presentación de antes del envío o de después de resolver no es
  -- de este caso.
  presentados as (
    select e.*,
           (select min(ev.creado_en)
              from public.tramite_eventos ev
             where ev.tramite = e.id and ev.a_estado = 'ante_el_ente'
               and ev.creado_en >= e.desde and ev.creado_en <= e.resuelto_en) as presentado
      from enviados e
     where e.estado = 'resuelto'
       and e.resuelto_en is not null
       and e.resuelto_en >= e.desde
  ),
  resueltos as (
    select p.id, p.tipo, p.ente, p.inversionista, p.desde, p.presentado, p.resuelto_en,
           p.datos ->> 'razon_social' as empresa,
           extract(epoch from (p.resuelto_en - p.desde)) / 3600.0 as horas,
           extract(epoch from (coalesce(p.presentado, p.resuelto_en) - p.desde)) / 3600.0 as horas_ciip,
           extract(epoch from (p.resuelto_en - p.presentado)) / 3600.0 as horas_ente
      from presentados p
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
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by tipo
  ),
  tiempo_ente as (
    select ente,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by ente
  ),
  -- Lo mismo para todos los resueltos juntos: las tres cifras de arriba de la ficha.
  tiempo_total as (
    select
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
  ),
  -- Y los casos uno por uno, los más recientes primero, con el mismo tope que motivos_casos.
  ultimos_resueltos as (
    select r.*, coalesce(pf.nombre_completo, '') as quien
      from resueltos r
      left join public.perfiles pf on pf.id = r.inversionista
     order by r.resuelto_en desc, r.id
     limit 500
  ),
  por_sector as (
    select sector, count(*) as n
      from public.consultas
     where sector is not null
     group by sector
  ),
  -- El trámite específico de cada sector (9-10-2026). Se agrupa sin mirar mayúsculas ni
  -- espacios de los lados, para que «Licencia ambiental» y «licencia ambiental » cuenten
  -- juntas; se enseña el nombre tal como lo escribió la mayoría.
  por_tramite_sector as (
    select c.sector, lower(trim(c.tramite_sector)) as clave,
           mode() within group (order by trim(c.tramite_sector)) as tramite,
           count(*) as n
      from public.consultas c
     where c.sector is not null
       and coalesce(trim(c.tramite_sector), '') <> ''
     group by c.sector, lower(trim(c.tramite_sector))
  ),
  -- Los motivos de «ya lo solicité» (6-10-2026): por qué pide ayuda el inversionista, ente por
  -- ente. En c45 a c47 y en el SACS ya solicitado (c49) hay un solo ente, el del catálogo, y un
  -- motivo_ya; en c44, uno por cada ente marcado, motivo_ya_<ente>. Se guardan en español
  -- (opcionesClave), así que se agrupan igual los haya escrito quien sea en el idioma que sea.
  -- Desde el 9-10-2026 cada caso lleva también su detalle (detalle_ya, detalle_ya_<ente>), la
  -- solicitud, quién y cuándo: de aquí salen a la vez las cifras y el registro de casos.
  casos as (
    select m.*
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente,
               e.datos ->> 'detalle_ya' as detalle,
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social' as empresa
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso')
        union all
        select e.datos ->> ('motivo_ya_' || x.clave), x.ente,
               e.datos ->> ('detalle_ya_' || x.clave),
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social'
          from enviados e
         cross join (values ('banavih', 'BANAVIH (FAOV)'), ('inces', 'INCES'),
                            ('rupdae', 'RUPDAE'), ('ivss', 'IVSS'),
                            ('rnet', 'RNET'), ('rnc', 'RNC')) as x(clave, ente)
         where e.tipo = 'parafiscales_en_proceso'
      ) m
     where coalesce(m.motivo, '') <> ''
  ),
  motivos as (
    select motivo, ente, count(*) as n
      from casos
     group by motivo, ente
  ),
  ultimos_casos as (
    select ca.*, coalesce(p.nombre_completo, '') as quien
      from casos ca
      left join public.perfiles p on p.id = ca.inversionista
     order by ca.desde desc, ca.id, ca.ente
     limit 500
  )
  select jsonb_build_object(
    'tramites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', p.tipo, 'ente', p.ente, 'solicitados', p.solicitados,
               'resueltos', coalesce(x.n, 0),
               'mediana_h', round(x.mediana::numeric, 1),
               'promedio_h', round(x.promedio::numeric, 1),
               'maximo_h', round(x.maximo::numeric, 1),
               'mediana_ciip_h', round(x.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(x.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(x.maximo_ciip::numeric, 1),
               'n_ente', coalesce(x.n_ente, 0),
               'mediana_ente_h', round(x.mediana_ente::numeric, 1),
               'promedio_ente_h', round(x.promedio_ente::numeric, 1),
               'maximo_ente_h', round(x.maximo_ente::numeric, 1))
             order by p.solicitados desc, p.tipo)
        from por_tipo p
        left join tiempo_tipo x on x.tipo = p.tipo), '[]'::jsonb),
    'entes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ente', y.ente, 'resueltos', y.n,
               'mediana_h', round(y.mediana::numeric, 1),
               'promedio_h', round(y.promedio::numeric, 1),
               'maximo_h', round(y.maximo::numeric, 1),
               'mediana_ciip_h', round(y.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(y.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(y.maximo_ciip::numeric, 1),
               'n_ente', y.n_ente,
               'mediana_ente_h', round(y.mediana_ente::numeric, 1),
               'promedio_ente_h', round(y.promedio_ente::numeric, 1),
               'maximo_ente_h', round(y.maximo_ente::numeric, 1))
             order by y.n desc, y.ente)
        from tiempo_ente y), '[]'::jsonb),
    'tiempo_total', (
      select jsonb_build_object('resueltos', z.n,
               'mediana_h', round(z.mediana::numeric, 1),
               'promedio_h', round(z.promedio::numeric, 1),
               'maximo_h', round(z.maximo::numeric, 1),
               'mediana_ciip_h', round(z.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(z.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(z.maximo_ciip::numeric, 1),
               'n_ente', z.n_ente,
               'mediana_ente_h', round(z.mediana_ente::numeric, 1),
               'promedio_ente_h', round(z.promedio_ente::numeric, 1),
               'maximo_ente_h', round(z.maximo_ente::numeric, 1))
        from tiempo_total z),
    'tiempos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tramite', ur.id, 'tipo', ur.tipo, 'ente', ur.ente,
               'inversionista', ur.quien, 'empresa', coalesce(ur.empresa, ''),
               'enviado', ur.desde, 'presentado', ur.presentado, 'resuelto', ur.resuelto_en,
               'horas', round(ur.horas::numeric, 1),
               'horas_ciip', round(ur.horas_ciip::numeric, 1),
               'horas_ente', round(ur.horas_ente::numeric, 1))
             order by ur.resuelto_en desc, ur.id)
        from ultimos_resueltos ur), '[]'::jsonb),
    'sectores', coalesce((
      select jsonb_agg(jsonb_build_object('sector', s.sector, 'consultas', s.n)
             order by s.n desc, s.sector)
        from por_sector s), '[]'::jsonb),
    'tramites_sector', coalesce((
      select jsonb_agg(jsonb_build_object('sector', ts.sector, 'tramite', ts.tramite, 'n', ts.n)
             order by ts.sector, ts.n desc, ts.tramite)
        from por_tramite_sector ts), '[]'::jsonb),
    'motivos', coalesce((
      select jsonb_agg(jsonb_build_object('motivo', mo.motivo, 'ente', mo.ente, 'n', mo.n)
             order by mo.n desc, mo.motivo, mo.ente)
        from motivos mo), '[]'::jsonb),
    'motivos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'motivo', uc.motivo, 'ente', uc.ente, 'detalle', coalesce(uc.detalle, ''),
               'tramite', uc.id, 'tipo', uc.tipo, 'inversionista', uc.quien,
               'empresa', coalesce(uc.empresa, ''), 'fecha', uc.desde)
             order by uc.desde desc, uc.id, uc.ente)
        from ultimos_casos uc), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;


-- COMPROBACIÓN
--   select position('tiempos_casos' in pg_get_functiondef('public.estadisticas_control()'::regprocedure)) > 0
--          and position('mediana_ciip_h' in pg_get_functiondef('public.estadisticas_control()'::regprocedure)) > 0
--          as trae_los_tramos;                                              -- true
