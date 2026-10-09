-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — CONTROL Y ESTADÍSTICAS, CON EL DETALLE
--  Va DESPUÉS de supabase-control-estadisticas.sql (consultas.sector,
--  tramites_por_sector) y de supabase-sacs.sql, que es quien dejó escrita
--  la última estadisticas_control(). Va al final para no mover el número
--  de nadie. Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 9 de octubre de 2026, dos cosas de la misma pantalla:
--
--  1. «En control y seguimiento, en las estadísticas que se lleva por
--     sector, al lado debería de salir el tipo de trámite que más solicitan
--     por sector, o sea el trámite en específico que solicita apoyo cada
--     inversionista; en la forma en que aparece ahí pareciera que lo
--     tuvieras que escribir y seleccionar nosotros mismos.»
--
--     Hasta hoy el trámite que el inversionista pulsa en el chat de
--     sectores solo se escribía en la caja del asunto, delante de lo que
--     él añadiera y con el sector traducido delante de todo. Un texto libre
--     en ocho idiomas no se cuenta. Desde ahora va además, tal cual se
--     pulsó, en consultas.tramite_sector.
--
--     Es el NOMBRE y no el id de tramites_por_sector a propósito: esa lista
--     la cambia el administrador (renombra, quita, reordena) y una consulta
--     de hace tres meses tiene que seguir contando como lo que se pidió
--     entonces, no desaparecer porque alguien borró la fila.
--
--  2. «En ¿Por qué piden ayuda? debería de salir la respuesta completa que
--     pone el inversionista, no ..., porque si el trámite tiene alguna
--     incidencia no podremos saberlo ni tener un registro de ello.»
--
--     El motivo ya se guardaba (motivo_ya, motivo_ya_<ente>) y ya se
--     contaba. Lo que el equipo no podía leer era el CASO: quién, qué
--     solicitud, ante qué ente, cuándo, y lo que escribió al lado
--     (detalle_ya, detalle_ya_<ente>, opcional). La función lo devuelve
--     ahora en motivos_casos, del más reciente al más viejo.
--
--  POR QUÉ OTRA VEZ LA FUNCIÓN ENTERA
--  ───────────────────────────────────────────────────────────────────────
--  Las cifras de esa pantalla las cuenta la base, no el panel (lo explica
--  supabase-control-estadisticas.sql: una mediana no se rehace sumando
--  trozos, y lo que viaja son cifras y no filas). Las dos de hoy siguen la
--  misma regla, así que van dentro de estadisticas_control(), que aquí se
--  reescribe entera, como hizo supabase-sacs.sql. Lo de antes no cambia:
--  solo se añaden dos llaves, tramites_sector y motivos_casos.
--
--  Los casos llevan un tope de 500, los más recientes: la pantalla se
--  refresca cada minuto y no tiene sentido mandar el archivo entero de la
--  oficina en cada vuelta. Si algún día se pasa, se pagina aparte.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: el chat abre la consulta igual (si
--  la base rechaza la columna, el panel repite sin ella), la tarjeta de los
--  trámites por sector dice que aún no hay datos y cada motivo se despliega
--  diciendo que falta este archivo.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL TRÁMITE QUE ELIGIÓ EN EL CHAT DE SECTORES
-- ───────────────────────────────────────────────────────────────────────
alter table public.consultas
  add column if not exists tramite_sector text;

alter table public.consultas
  drop constraint if exists consultas_tramite_sector_cabe;
alter table public.consultas
  add constraint consultas_tramite_sector_cabe check (
    tramite_sector is null or length(trim(tramite_sector)) between 1 and 200);

comment on column public.consultas.tramite_sector is 'Nombre del trámite de tramites_por_sector que pulsó el inversionista en el chat de sectores, tal cual estaba al pulsarlo. Null = no eligió ninguno de la lista';

create index if not exists consultas_por_tramite_sector
  on public.consultas (sector, tramite_sector) where tramite_sector is not null;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LAS CIFRAS, CON LAS DOS LLAVES NUEVAS
-- ───────────────────────────────────────────────────────────────────────
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
--   select column_name from information_schema.columns
--    where table_schema = 'public' and table_name = 'consultas'
--      and column_name = 'tramite_sector';                                  -- una fila
--   select conname from pg_constraint where conname = 'consultas_tramite_sector_cabe';  -- una fila
--   select position('motivos_casos' in pg_get_functiondef('public.estadisticas_control()'::regprocedure)) > 0
--          and position('tramites_sector' in pg_get_functiondef('public.estadisticas_control()'::regprocedure)) > 0
--          as trae_el_detalle;                                              -- true
