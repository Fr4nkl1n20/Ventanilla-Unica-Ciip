-- ═══════════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — BORRAR c35 «INSCRIPCIÓN EN EL RUPDAE»
--  Revisión de la etapa 3 (Valeria Ramos, CIIP, 4-11-2026): estaba apagada y
--  duplicada, porque el RUPDAE se pide en el c37. El c37 no usa esta fila: su
--  ente es 'sundde', en tramite_entes.
--  Solo se borra si nada la referencia. Si una solicitud, autorización, cita o
--  consulta la usa, se queda apagada: la consulta final dice 1 en ese caso.
--  Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════════

delete from public.tipos_tramite t
 where t.codigo = 'rupdae'
   and not exists (select 1 from public.tramites x where x.tipo = t.codigo)
   and not exists (select 1 from public.autorizaciones x where x.tipo = t.codigo)
   and not exists (select 1 from public.citas x where x.tipo_tramite = t.codigo)
   and not exists (select 1 from public.consultas x where x.tipo = t.codigo);
select count(*) as filas_de_c35_que_quedan from public.tipos_tramite where codigo = 'rupdae';
