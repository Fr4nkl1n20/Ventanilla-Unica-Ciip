insert into public.tipos_documento (codigo, nombre, vence) values
  ('permiso_hidrocarburos', 'Permiso o autorización del Ministerio de Hidrocarburos', false),
  ('permiso_pesca', 'Permiso, registro o certificado de INSOPESCA', false),
  ('permiso_energia', 'Permiso, habilitación o registro del Ministerio de Energía Eléctrica o de CORPOELEC', false),
  ('comunicacion_insopesca', 'Comunicación a la Presidencia de INSOPESCA', false),
  ('inspeccion_artes_equipos', 'Inspección de artes y equipos', false),
  ('informe_capitania_puerto', 'Informe de la Capitanía de Puerto', false),
  ('certificado_arqueo_inea', 'Certificado de arqueo del INEA', false),
  ('fotos_plano_buque', 'Dos fotos y plano del buque', false),
  ('comprobante_posicionamiento', 'Comprobante del dispositivo de posicionamiento', false),
  ('tenencia_tierra', 'Tenencia de la tierra', false),
  ('coordenadas_proyecto', 'Coordenadas del proyecto', false),
  ('inspeccion_tecnica_acuicultura', 'Inspección técnica', false),
  ('aot_aarn_conformidad', 'AOT y AARN, o conformidad de uso', false),
  ('analisis_agua_suelo', 'Análisis de agua y suelo', false),
  ('deposito_tasa_acuicultura', 'Depósito de la tasa', false),
  ('planilla_solicitud_insopesca', 'Planilla de solicitud de INSOPESCA', false),
  ('registro_mercantil_empresa', 'Registro mercantil', false),
  ('pago_tasa_insopesca', 'Pago de la tasa de INSOPESCA', false),
  ('analisis_agua_producto', 'Análisis de agua o producto (plantas y laboratorios)', false),
  ('formulario_for_dgse', 'Formulario FOR-DGSE-001 y planilla del MPPEE', false),
  ('ubicacion_regven_utm', 'Ubicación en coordenadas REGVEN/UTM y poligonal', false),
  ('justificacion_autogeneracion', 'Justificación: procesos, carga total y régimen de uso', false),
  ('especificaciones_equipos', 'Especificaciones de los equipos, planos y combustible', false),
  ('proyecto_conexion_sen', 'Proyecto de conexión al SEN y cronograma (instalación nueva)', false),
  ('racda_emisiones', 'RACDA y constancia de emisiones', false),
  ('factibilidad_combustible', 'Factibilidad y autorización de compra del combustible', false),
  ('legales_autogeneracion', 'Acta, junta vigente, RIF, cédula y poder', false),
  ('propiedad_o_alquiler', 'Propiedad del terreno o contrato de alquiler', false),
  ('registro_mercantil_carta', 'Registro mercantil y carta explicativa', false),
  ('plano_utm_poste', 'Plano con coordenadas UTM y número de poste', false),
  ('memoria_descriptiva_ingeniero', 'Memoria descriptiva firmada por ingeniero colegiado', false),
  ('solvencia_colegio_ingenieros', 'Solvencia del Colegio de Ingenieros', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('permisos_hidrocarburos',   'c57', 'Permisos de hidrocarburos',             'MINHIDROCARBUROS', 3, true),
  ('hidrocarburos_en_proceso', 'c58', 'Permiso de hidrocarburos ya solicitado', 'MINHIDROCARBUROS', 3, true),
  ('permisos_pesca',           'c59', 'Permisos de pesca',                     'INSOPESCA',        3, true),
  ('pesca_en_proceso',         'c60', 'Permiso de pesca ya solicitado',        'INSOPESCA',        3, true),
  ('permisos_energia',         'c61', 'Permisos de energía',                   'MPPEE',            3, true),
  ('energia_en_proceso',       'c62', 'Permiso de energía ya solicitado',      'MPPEE',            3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite  = case codigo when 'permisos_hidrocarburos' then 'permiso_hidrocarburos'
                            when 'permisos_pesca'         then 'permiso_pesca'
                            else 'permiso_energia' end,
       nivel  = 'actividad',
       fase   = 3,
       activo = true
 where codigo in ('permisos_hidrocarburos', 'permisos_pesca', 'permisos_energia');

update public.tipos_tramite
   set emite      = null,
       plazo_dias = null,
       nivel      = 'actividad',
       fase       = 3,
       activo     = true
 where codigo in ('hidrocarburos_en_proceso', 'pesca_en_proceso', 'energia_en_proceso');

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
                     'agricola_solicitado', 'rnc_solicitado',
                     'hidrocarburos_solicitado', 'pesca_solicitado', 'energia_solicitado') then
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
           t.datos, t.inversionista,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
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
  por_tramite_sector as (
    select c.sector, lower(trim(c.tramite_sector)) as clave,
           mode() within group (order by trim(c.tramite_sector)) as tramite,
           count(*) as n
      from public.consultas c
     where c.sector is not null
       and coalesce(trim(c.tramite_sector), '') <> ''
     group by c.sector, lower(trim(c.tramite_sector))
  ),
  casos as (
    select m.*
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente,
               e.datos ->> 'detalle_ya' as detalle,
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social' as empresa
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso', 'ambiental_en_proceso', 'agricola_en_proceso',
                          'minero_en_proceso', 'turistico_en_proceso',
                          'hidrocarburos_en_proceso', 'pesca_en_proceso', 'energia_en_proceso')
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
