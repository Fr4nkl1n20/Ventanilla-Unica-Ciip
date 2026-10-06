-- «Ya lo solicité» (Franklin Reyes, 5-10-2026, Ventanilla única 2.6): inscripciones (c44), licencia (c45),
-- conformidad de uso (c46) y bomberos (c47). Sus recaudos son tipos que ya existen. Con el nivel y la fase
-- de su casilla madre. Necesita supabase-informe-victor.sql. Se puede correr más de una vez.

insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('parafiscales_en_proceso', 'c44', 'Inscripciones: empresa ya inscrita',                 'Entes varios', 3, true),
  ('licencia_en_proceso',     'c45', 'Licencia de actividades económicas: ya solicitada',  'Alcaldía',     3, true),
  ('conformidad_en_proceso',  'c46', 'Conformidad de uso: ya solicitada',                  'Alcaldía',     3, true),
  ('bomberos_en_proceso',     'c47', 'Permiso de bomberos: ya solicitado',                 'Bomberos',     3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite t
   set emite      = null,
       plazo_dias = null,
       nivel      = coalesce(m.nivel, 'actividad'),
       fase       = coalesce(m.fase, 3),
       activo     = true
  from (values ('parafiscales_en_proceso', 'registros_parafiscales'),
               ('licencia_en_proceso',     'licencia_municipal'),
               ('conformidad_en_proceso',  'conformidad_uso'),
               ('bomberos_en_proceso',     'permiso_bomberos')) as p(nuevo, madre)
  left join public.tipos_tramite m on m.codigo = p.madre
 where t.codigo = p.nuevo;

select codigo, ref_panel, fase, nivel, activo from public.tipos_tramite
 where codigo in ('parafiscales_en_proceso', 'licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso')
 order by ref_panel;
