-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — QUIÉN CAMBIÓ QUÉ TEXTO, Y QUÉ DECÍA ANTES
--  Va DESPUÉS de supabase-textos.sql y de supabase-bitacora.sql. No mueve
--  el número de nadie: va al final.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 16 de septiembre de 2026, al pedir que el editor llegue
--  a todos los textos de la página: «y que en trazabilidad salga quien los
--  haya editado».
--
--  Quién ya salía: la bitácora apunta auth.uid() en cada cambio. Lo que no
--  salía era QUÉ texto -solo el nuevo y el idioma-, así que en Trazabilidad
--  se leía «cambió un texto (ES): Guardar» sin saber de qué pantalla era ni
--  qué ponía antes. Esto guarda la clave y lo de antes.
--
--  NO TOCA PERMISOS NI BORRA NADA. Los apuntes viejos se siguen leyendo.
-- ═══════════════════════════════════════════════════════════════════════


do $comprueba$
begin
  if to_regclass('public.textos_panel') is null then
    raise exception 'Falta la tabla textos_panel: corre antes supabase-textos.sql';
  end if;
end
$comprueba$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LO QUE DECÍA ANTES, AL LADO DEL CAMBIO
-- ───────────────────────────────────────────────────────────────────────
--  El texto original está en el panel -en su diccionario-, no en la base,
--  así que la base no podía decir qué se cambió. El panel lo manda al
--  guardar. Null en lo guardado antes de esto: de eso no se sabe.
alter table public.textos_panel add column if not exists original text;

comment on column public.textos_panel.original is
  'Lo que decía el texto antes del primer cambio, en ese idioma. Lo manda el panel; la bitácora lo apunta.';

do $tope$
begin
  if not exists (select 1 from pg_constraint where conname = 'textos_panel_original_tope') then
    alter table public.textos_panel add constraint textos_panel_original_tope
      check (original is null or length(original) <= 1000);
  end if;
end
$tope$;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LA BITÁCORA APUNTA QUÉ TEXTO ERA
-- ───────────────────────────────────────────────────────────────────────
--  Antes guardaba el texto nuevo y el idioma, y en Trazabilidad salía
--  «cambió un texto» sin decir cuál. Ahora el detalle es un JSON con el
--  idioma, la CLAVE y lo que decía ANTES; y «sobre» sigue siendo lo que
--  dice después. Los apuntes viejos -solo el idioma- se siguen leyendo.
--
--    · cambiar por primera vez   antes = el original que manda el panel
--    · volver a cambiarlo        antes = el cambio anterior
--    · volver al original        antes = el cambio; sobre = el original
create or replace function public.bit_textos()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    perform public.apunta('textos', 'original', left(coalesce(old.original, ''), 160),
      json_build_object('idioma', old.idioma, 'clave', old.clave,
                        'antes', left(old.texto, 160))::text);
  elsif tg_op = 'INSERT' then
    perform public.apunta('textos', 'cambio', left(new.texto, 160),
      json_build_object('idioma', new.idioma, 'clave', new.clave,
                        'antes', left(coalesce(new.original, ''), 160))::text);
  elsif new.texto is distinct from old.texto then
    perform public.apunta('textos', 'cambio', left(new.texto, 160),
      json_build_object('idioma', new.idioma, 'clave', new.clave,
                        'antes', left(old.texto, 160))::text);
  end if;
  return null;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. EL DISPARADOR, Y QUE LA BITÁCORA ADMITA LOS TEXTOS
-- ───────────────────────────────────────────────────────────────────────
--  Lo pone también supabase-bitacora-ajustes.sql; se repite aquí para que
--  este archivo baste solo. Y con cuidado con la regla de las fuentes: si
--  no admitiera 'textos', cada guardado del editor fallaría ENTERO -el
--  disparador corre dentro del mismo guardado-.
--
--  Sin bitácora no se cae: los textos se siguen guardando, sin apunte.
do $bitacora$
begin
  if to_regclass('public.bitacora') is null
     or to_regprocedure('public.apunta(text, text, text, text)') is null then
    raise notice 'Sin bitácora: los textos se guardan pero no se apuntan. Corre supabase-bitacora.sql y vuelve a pasar este.';
    return;
  end if;

  if not exists (select 1 from pg_constraint
                  where conname = 'bitacora_fuente_valida'
                    and pg_get_constraintdef(oid) like '%textos%') then
    alter table public.bitacora drop constraint if exists bitacora_fuente_valida;
    alter table public.bitacora add constraint bitacora_fuente_valida
      check (fuente in ('catalogo','roles','papeles','citas',
                        'textos','activos','acompanamiento'));
  end if;

  drop trigger if exists bitacora_textos on public.textos_panel;
  create trigger bitacora_textos
    after insert or update or delete on public.textos_panel
    for each row execute function public.bit_textos();
end
$bitacora$;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) La columna nueva:
--
--   select column_name from information_schema.columns
--   where table_schema = 'public' and table_name = 'textos_panel'
--     and column_name = 'original';
--
-- 2) El disparador puesto (una fila):
--
--   select tgname from pg_trigger where tgname = 'bitacora_textos';
--
-- 3) Cambia un texto desde el panel y mira el último apunte: el detalle
--    tiene que traer la clave y lo que decía antes.
--
--   select cuando, sobre, detalle from public.bitacora
--   where fuente = 'textos' order by id desc limit 3;
