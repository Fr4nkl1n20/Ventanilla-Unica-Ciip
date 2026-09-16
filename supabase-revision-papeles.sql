-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA REVISIÓN DE LOS DOCUMENTOS
--  Va DESPUÉS de supabase-tramites.sql y de supabase-bitacora.sql. No mueve
--  el número de nadie: va al final.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 16 de septiembre de 2026: «¿cómo sería la opción para
--  que el CIIP pueda confirmar que el documento está bien?». Se eligió,
--  sobre una maqueta, una bandeja del equipo -«Documentos por revisar»- con
--  todos los papeles pendientes, y una columna en Documentos que le dice al
--  inversionista en qué punto está cada uno.
--
--  Para revisar no hacía falta nada: documentos ya tenía estado,
--  nota_revision y revisado_por, y es_gestor() ya deja cambiarlos. Esto
--  añade CUÁNDO, y que la bitácora apunte quién validó o rechazó.
--
--  NO TOCA PERMISOS NI BORRA NADA.
-- ═══════════════════════════════════════════════════════════════════════


do $comprueba$
begin
  if to_regclass('public.documentos') is null then
    raise exception 'Falta la tabla documentos: corre antes supabase-tramites.sql';
  end if;
end
$comprueba$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. CUÁNDO SE REVISÓ
-- ───────────────────────────────────────────────────────────────────────
--  Para poder decir «validado el 16 de septiembre». actualizado_en no
--  sirve: cambia con cualquier retoque del papel, no solo con la revisión.
--  Null en lo revisado antes de esto.
alter table public.documentos add column if not exists revisado_en timestamptz;

comment on column public.documentos.revisado_en is
  'Cuándo lo validó o rechazó el equipo del CIIP. Lo pone el panel al revisar.';


-- ───────────────────────────────────────────────────────────────────────
-- 2. LA BITÁCORA APUNTA CADA REVISIÓN
-- ───────────────────────────────────────────────────────────────────────
--  Hasta ahora apuntaba subir y borrar un papel, pero no validarlo ni
--  rechazarlo: en Trazabilidad no se sabía quién había dado un papel por
--  bueno. Solo cuando CAMBIA el estado a validado o rechazado.
--
--    sobre    el nombre del archivo, congelado
--    detalle  JSON con el tipo de papel, DE QUIÉN es y el motivo del rechazo
--
--  «De quién» se congela con el nombre de hoy: si mañana cambia su perfil,
--  el apunte sigue diciendo de quién era cuando se revisó.
create or replace function public.bit_papeles_revision()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  dueno text;
begin
  if new.estado is not distinct from old.estado
     or new.estado not in ('validado', 'rechazado') then
    return null;
  end if;
  select nombre_completo into dueno from public.perfiles where id = new.inversionista;
  perform public.apunta('papeles',
    case when new.estado = 'validado' then 'valido' else 'rechazo' end,
    new.nombre_original,
    json_build_object('tipo', new.tipo,
                      'de', coalesce(dueno, ''),
                      'motivo', case when new.estado = 'rechazado'
                                     then left(coalesce(new.nota_revision, ''), 200)
                                     else '' end)::text);
  return null;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. EL DISPARADOR
-- ───────────────────────────────────────────────────────────────────────
--  Sin bitácora no se cae: los papeles se revisan igual, sin apunte.
do $bitacora$
begin
  if to_regclass('public.bitacora') is null
     or to_regprocedure('public.apunta(text, text, text, text)') is null then
    raise notice 'Sin bitácora: los papeles se revisan pero no se apuntan. Corre supabase-bitacora.sql y vuelve a pasar este.';
    return;
  end if;
  drop trigger if exists bitacora_papeles_revision on public.documentos;
  create trigger bitacora_papeles_revision
    after update of estado on public.documentos
    for each row execute function public.bit_papeles_revision();
end
$bitacora$;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) La columna nueva:
--
--   select column_name from information_schema.columns
--   where table_schema = 'public' and table_name = 'documentos'
--     and column_name = 'revisado_en';
--
-- 2) El disparador puesto (una fila):
--
--   select tgname from pg_trigger where tgname = 'bitacora_papeles_revision';
--
-- 3) Valida o rechaza un papel desde «Documentos por revisar» y mira el
--    último apunte:
--
--   select cuando, accion, sobre, detalle from public.bitacora
--   where fuente = 'papeles' order by id desc limit 3;
