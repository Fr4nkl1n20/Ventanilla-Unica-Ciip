-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — «YA SOLICITÉ UN PERMISO» EN MINERÍA Y TURISMO
--  (c55 y c56), Y EL RNC (c13) FUERA DE LAS INSCRIPCIONES, CON SU TARJETA
--  Va DESPUÉS de supabase-rupdae-rum.sql y de supabase-rtn.sql (las casillas
--  madre), de supabase-entes-parafiscales.sql y supabase-qa-tramites.sql (los
--  entes y el freno de resolver), de supabase-permisos-agricolas.sql (la
--  última confirma_paso) y de supabase-ya-solicite-permisos.sql (la última
--  estadisticas_control). Va al final para no mover el número de nadie. Se
--  puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 2 de noviembre de 2026, dos pedidos:
--
--  «Lo mismo con permisos mineros y permisos de turismo»: la pregunta del
--  SACS. La de primera vez es la de siempre (c36, c50); la de «ya solicité»
--  es un trámite nuevo de cada una, escondido detrás con data-tramo-de:
--    · minero_en_proceso    (c55), ante el ministerio minero;
--    · turistico_en_proceso (c56), ante el MINTUR.
--  Sin emite ni plazo, como el c49. Estadísticas cuenta sus motivos.
--
--  «Saca el RNC de ese grupo»: de las inscripciones (c37 y c44).
--    · El trámite 'rnc' (c13) YA EXISTÍA, apagado desde el 20-9-2026 por
--      supabase-parafiscales.sql, y con solicitudes viejas: no se crea otro,
--      se enciende. Lo que emite es nuevo, 'certificado_rnc'. Si alguien
--      corre supabase-parafiscales.sql SOLO, después de este, el c13 se
--      vuelve a apagar: hay que correr este otra vez.
--    · 'rnc_solicitado' entra en confirma_paso: el inversionista lo solicita
--      en RNC en línea y marca «Ya lo solicité».
--    · Las solicitudes nuevas de parafiscales nacen con CINCO entes y se
--      resuelven con esos cinco. El nombre parafiscales_con_los_seis se
--      queda: es el del disparador que ya está puesto en la base.
--    · LO VIEJO NO SE TOCA. 'snc' sigue en el check de tramite_entes, 'ente_snc'
--      en confirma_paso, y las filas de 'snc' que ya existan se quedan donde
--      están: el panel las sigue enseñando si alguien las movió.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Los dos trámites de «ya solicité», encendidos.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('minero_en_proceso',    'c55', 'Registro Único Minero ya solicitado',       'Ministerio de Desarrollo Minero', 3, true),
  ('turistico_en_proceso', 'c56', 'Registro Turístico Nacional ya solicitado', 'MINTUR',                          3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set ref_panel  = case codigo when 'minero_en_proceso' then 'c55' else 'c56' end,
       emite      = null,
       plazo_dias = null,
       nivel      = 'actividad',
       fase       = 3,
       activo     = true
 where codigo in ('minero_en_proceso', 'turistico_en_proceso');

-- 2. El RNC, con su tarjeta: lo que emite, y encendido.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('certificado_rnc', 'Certificado de inscripción en el Registro Nacional de Contratistas (RNC)', true)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

update public.tipos_tramite
   set emite  = 'certificado_rnc',
       nivel  = 'actividad',
       fase   = 3,
       activo = true
 where codigo = 'rnc';

-- 3. La marca del paso 1 del RNC: la confirma_paso de supabase-permisos-agricolas.sql con esa llave más.
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
                     'sacs_registrado', 'rtn_solicitado', 'ambiental_solicitado',
                     'agricola_solicitado', 'rnc_solicitado') then
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

-- 4. Las inscripciones nacen con cinco entes, sin el RNC.
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
      from unnest(array['banavih', 'inces', 'mpppst', 'sundde', 'ivss']) as e
    on conflict (tramite, ente) do nothing;
  end if;
  return new;
end $$;

-- 5. Y se resuelven con esos cinco. Una fila vieja de 'snc' no cuenta ni estorba.
create or replace function public.parafiscales_con_los_seis()
returns trigger
language plpgsql
security definer
set search_path = public
as $qa$
begin
  if auth.uid() is null
     or new.tipo is distinct from 'registros_parafiscales'
     or new.estado is distinct from 'resuelto'
     or old.estado = 'resuelto' then
    return new;
  end if;
  if (select count(*) from public.tramite_entes
       where tramite = new.id and estado = 'listo' and ente <> 'snc') < 5 then
    raise exception 'Hay inscripciones sin terminar en los registros parafiscales'
      using errcode = 'check_violation';
  end if;
  return new;
end
$qa$;

-- 6. Las cifras de Control y Estadísticas: los motivos de «ya lo solicité» cuentan también los dos.
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
  -- PASO A PASO (15-10-2026): el historial de cada resuelto, cortado en tramos. Cada cambio
  -- de estado abre un tramo que dura hasta el cambio siguiente, o hasta resolverse. «abrio»
  -- es quien lo puso en ese estado y «cerro», quien lo sacó. El tramo de 'resuelto' no
  -- dura nada y no se cuenta, ni lo de antes del envío (el borrador).
  tramos as (
    select r.id, r.tipo, ev.id as ev, ev.a_estado as estado, ev.creado_en as desde_paso,
           coalesce(lead(ev.creado_en) over w, r.resuelto_en) as hasta_paso,
           lead(ev.autor) over w as cerro
      from resueltos r
      join public.tramite_eventos ev on ev.tramite = r.id
     where ev.creado_en >= r.desde - interval '1 second'
       and ev.creado_en <= r.resuelto_en
    window w as (partition by r.id order by ev.creado_en, ev.id)
  ),
  pasos as (
    select t.*, extract(epoch from (t.hasta_paso - t.desde_paso)) / 3600.0 as horas
      from tramos t
     where t.estado in ('enviado', 'en_revision', 'devuelto', 'ante_el_ente')
  ),
  -- Lo de cada caso en cada estado, sumado: una devuelta que vuelve a revisión pasa dos
  -- veces por 'en_revision'.
  paso_caso as (
    select id, tipo, estado, sum(horas) as horas, count(*) as veces
      from pasos
     group by id, tipo, estado
  ),
  paso_tipo as (
    select tipo, estado,
           count(*) as n,
           sum(veces) as veces,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo
      from paso_caso
     group by tipo, estado
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
  -- motivo_ya; y desde el 2-11-2026 (Franklin Reyes) también en los permisos ya solicitados ante el
  -- MINEC (c53) y ante el INSAI o el INTI (c54); en c44, uno por cada ente marcado, motivo_ya_<ente>. Se guardan en español
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
                          'sacs_en_proceso', 'ambiental_en_proceso', 'agricola_en_proceso',
                          'minero_en_proceso', 'turistico_en_proceso')
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
    'pasos_tipo', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', pt.tipo, 'estado', pt.estado, 'casos', pt.n, 'veces', pt.veces,
               'mediana_h', round(pt.mediana::numeric, 1),
               'promedio_h', round(pt.promedio::numeric, 1),
               'maximo_h', round(pt.maximo::numeric, 1))
             order by pt.tipo, pt.estado)
        from paso_tipo pt), '[]'::jsonb),
    'tiempos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tramite', ur.id, 'tipo', ur.tipo, 'ente', ur.ente,
               'inversionista', ur.quien, 'empresa', coalesce(ur.empresa, ''),
               'enviado', ur.desde, 'presentado', ur.presentado, 'resuelto', ur.resuelto_en,
               'horas', round(ur.horas::numeric, 1),
               'horas_ciip', round(ur.horas_ciip::numeric, 1),
               'horas_ente', round(ur.horas_ente::numeric, 1),
               'pasos', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'estado', pa.estado, 'desde', pa.desde_paso, 'hasta', pa.hasta_paso,
                          'horas', round(pa.horas::numeric, 1),
                          'quien', coalesce(pc.nombre_completo, ''))
                        order by pa.desde_paso, pa.ev)
                   from pasos pa
                   left join public.perfiles pc on pc.id = pa.cerro
                  where pa.id = ur.id), '[]'::jsonb))
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

-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
--   select ref_panel, codigo, ente, fase, nivel, emite, activo from public.tipos_tramite
--    where codigo in ('minero_en_proceso', 'turistico_en_proceso', 'rnc') order by ref_panel;  -- c13, c55 y c56, encendidos
--   select position('rnc_solicitado' in pg_get_functiondef('public.confirma_paso(uuid, text)'::regprocedure)) > 0;
--   select position('turistico_en_proceso' in pg_get_functiondef('public.estadisticas_control()'::regprocedure)) > 0;
