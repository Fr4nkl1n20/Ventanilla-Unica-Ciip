update public.tipos_tramite set ente = 'SAREN'
 where codigo = 'libros_contables' and ente is distinct from 'SAREN';

update public.tipos_tramite set nombre = 'Cédula de identidad de extranjero'
 where codigo = 'cedula_residencia' and nombre is distinct from 'Cédula de identidad de extranjero';

update public.tipos_tramite set nombre = 'Traducción de documentos'
 where codigo = 'apostilla_documentos' and nombre is distinct from 'Traducción de documentos';
