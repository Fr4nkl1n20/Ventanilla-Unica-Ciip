update public.tipos_tramite
   set activo = false
 where codigo in ('licencia_conducir', 'cert_medico');

select codigo, ref_panel, nombre, activo
  from public.tipos_tramite
 where codigo in ('licencia_conducir', 'cert_medico');

select tipo, estado, count(*)
  from public.tramites
 where tipo in ('licencia_conducir', 'cert_medico')
 group by tipo, estado;
