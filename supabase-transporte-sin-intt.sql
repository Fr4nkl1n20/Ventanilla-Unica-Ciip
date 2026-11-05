-- ═══════════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL PERMISO DE TRANSPORTE, SIN EL INTT EN SU NOMBRE
--  Franklin Reyes, 5 de noviembre de 2026: «INTT ya no va en transporte, porque
--  pasó al Ministerio de Interiores, Justicia y Paz, hay que quitarlo de ahí».
--  La ficha c67/c68 se quedó con el INAC y el INEA, y este nombre es lo único de
--  ella que vive en la base: sale en los avisos y en la verificación del papel.
--  No borra nada: los tipos de los recaudos del INTT se quedan en tipos_documento,
--  porque quien los subió los sigue teniendo en su bóveda.
--  Va DESPUÉS de supabase-agua-industria-transporte.sql, que escribe el nombre
--  viejo. Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════════

update public.tipos_documento
   set nombre = 'Permiso, registro o certificación del INAC o del INEA'
 where codigo = 'permiso_transporte';
