-- ═══════════════════════════════════════════════════════════════════════
--  Comprobación del esquema de trámites
--  Panel de Supabase → SQL Editor → pega esto → Run
--  Solo lee: no modifica nada.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Los conteos. Deben salir 15 trámites, 14 recaudos y 3 activos.
select
  (select count(*) from public.tipos_tramite)              as tramites_en_catalogo,
  (select count(*) from public.tipos_documento)            as recaudos_en_catalogo,
  (select count(*) from public.tipos_tramite where activo) as activos;


-- 2. Cuáles quedaron activos. Arriba deben salir estos tres:
--    rif_personal · rif_empresa · visa_inversionista
select ref_panel, codigo, ente, fase, activo
from public.tipos_tramite
order by activo desc, fase, ref_panel;


-- 3. Los recaudos de la visa. Los cuatro deben estar.
select codigo, nombre, vence
from public.tipos_documento
where codigo in ('pasaporte','foto','antecedentes','inversion')
order by codigo;


-- 4. RLS activo en las seis tablas. Las seis deben salir con true.
select relname, relrowsecurity
from pg_class
where relname in ('documentos','tramites','tramite_documentos',
                  'tramite_eventos','tipos_documento','tipos_tramite')
order by relname;


-- 5. El bucket privado de recaudos. public debe ser false.
select id, name, public
from storage.buckets
where id = 'recaudos';
