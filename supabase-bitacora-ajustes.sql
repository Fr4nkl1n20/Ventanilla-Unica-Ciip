-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA BITÁCORA, CON LO QUE VINO DESPUÉS
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: el ÚLTIMO. Se engancha a tablas que crean archivos posteriores a
--  supabase-bitacora.sql: bloqueo (13), acompañamiento (14), plazos (21),
--  disponibilidad (28) y textos (29). Si en la base falta alguna de esas
--  tablas no se cae: se salta ese disparador y lo dice al final. Pasado el
--  archivo que falte, se vuelve a correr este.
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ARREGLA
--  ─────────────────────────────────────────────────────────────────────
--  La bitácora se hizo cuando el panel solo tocaba cuatro cosas: el
--  interruptor del catálogo, los roles, los papeles y las citas. Luego
--  llegaron el plazo de cada ficha, bloquear cuentas, los activos, el
--  horario de citas, el acompañamiento y «Editar textos», y ninguno dejaba
--  apunte. Trazabilidad seguía enseñando lo de hace cinco días como si
--  desde entonces nadie hubiera tocado nada.
--
--  Dónde sale cada uno en la pantalla:
--    · el plazo de una ficha          → Catálogo
--    · bloquear y desbloquear         → Roles (es quién puede qué)
--    · el horario y los días cerrados → Citas
--    · textos, activos, acompañamiento → una ficha nueva cada uno
--
--  Y UN AGUJERO QUE SE CIERRA DE PASO
--  ─────────────────────────────────────────────────────────────────────
--  supabase-bitacora.sql promete que nadie puede escribir en la bitácora.
--  Pero apunta() es security definer y no llevaba revoke, y Supabase da
--  EXECUTE sobre toda función nueva a anon y a authenticated. Desde el
--  navegador, sb.rpc('apunta', ...) escribía el apunte que uno quisiera.
--  Los disparadores la siguen llamando: corren como su dueño, que conserva
--  el permiso.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────
do $$
begin
  if to_regclass('public.bitacora') is null then
    raise exception 'Falta la tabla bitacora. Pasa antes supabase-bitacora.sql.';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LAS FUENTES NUEVAS, Y NADIE MÁS ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
alter table public.bitacora drop constraint if exists bitacora_fuente_valida;
alter table public.bitacora add constraint bitacora_fuente_valida
  check (fuente in ('catalogo','roles','papeles','citas',
                    'textos','activos','acompanamiento'));

revoke execute on function public.apunta(text, text, text, text)
  from public, anon, authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LAS FUNCIONES
-- ───────────────────────────────────────────────────────────────────────
-- Se crean aunque falte su tabla: plpgsql no mira las columnas hasta que
-- corre. Lo que depende de la tabla es el disparador, más abajo.

-- El plazo. Solo cuando CAMBIA: guardar el mismo número no es un apunte.
-- 'detalle' vacío es quitar el plazo.
create or replace function public.bit_catalogo_plazo()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.plazo_dias is distinct from old.plazo_dias then
    perform public.apunta('catalogo', 'plazo', new.nombre,
                          coalesce(new.plazo_dias::text, ''));
  end if;
  return null;
end $$;

create or replace function public.bit_bloqueo()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.bloqueado is distinct from old.bloqueado then
    perform public.apunta('roles',
      case when new.bloqueado then 'bloqueo' else 'desbloqueo' end,
      new.nombre_completo);
  end if;
  return null;
end $$;

-- Un activo. Guardar la ficha sin tocar nada no es editarla: se compara la
-- fila entera menos la marca de tiempo, que la pone otro disparador.
create or replace function public.bit_activos()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.apunta('activos', 'creo', new.titulo, new.estado);
  elsif tg_op = 'DELETE' then
    perform public.apunta('activos', 'borro', old.titulo, old.estado);
  elsif (to_jsonb(new) - 'actualizado_en') is distinct from
        (to_jsonb(old) - 'actualizado_en') then
    perform public.apunta('activos', 'edito', new.titulo, new.estado);
  end if;
  return null;
end $$;

-- Un tramo del horario. 'sobre' lleva las horas y 'detalle' el día en
-- número (1 lunes): el nombre del día lo pone la pantalla en su idioma.
create or replace function public.bit_horario()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.apunta('citas', 'puso_tramo',
      to_char(new.desde, 'HH24:MI') || '-' || to_char(new.hasta, 'HH24:MI'), new.dia::text);
  else
    perform public.apunta('citas', 'quito_tramo',
      to_char(old.desde, 'HH24:MI') || '-' || to_char(old.hasta, 'HH24:MI'), old.dia::text);
  end if;
  return null;
end $$;

-- Un día cerrado. La fecha va como 2026-12-24, y la pantalla la escribe.
create or replace function public.bit_cierres()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.apunta('citas', 'cerro_dia', new.fecha::text, new.motivo);
  else
    perform public.apunta('citas', 'abrio_dia', old.fecha::text, old.motivo);
  end if;
  return null;
end $$;

-- Los textos. Se guarda el TEXTO y no la clave: «c33.name» no le dice nada
-- a quien lee la bitácora, y el texto sí. Al volver al original se apunta
-- el texto que se quitó, que es lo único que ya no está en ningún sitio.
create or replace function public.bit_textos()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    perform public.apunta('textos', 'original', left(old.texto, 160), old.idioma);
  elsif tg_op = 'INSERT' or new.texto is distinct from old.texto then
    perform public.apunta('textos', 'cambio', left(new.texto, 160), new.idioma);
  end if;
  return null;
end $$;

create or replace function public.bit_acompanamiento()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (to_jsonb(new) - 'actualizado_en' - 'actualizado_por') is distinct from
     (to_jsonb(old) - 'actualizado_en' - 'actualizado_por') then
    perform public.apunta('acompanamiento', 'ajusto', '', '');
  end if;
  return null;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. LOS DISPARADORES, SOLO DONDE HAY TABLA
-- ───────────────────────────────────────────────────────────────────────
do $$
declare
  d record;
begin
  for d in
    select * from (values
      ('bitacora_catalogo_plazo', 'tipos_tramite',  'plazo_dias', 'after update of plazo_dias',          'bit_catalogo_plazo'),
      ('bitacora_bloqueo',        'perfiles',       'bloqueado',  'after update of bloqueado',           'bit_bloqueo'),
      ('bitacora_activos',        'activos',        null,         'after insert or update or delete',    'bit_activos'),
      ('bitacora_horario',        'horario_citas',  null,         'after insert or delete',              'bit_horario'),
      ('bitacora_cierres',        'cierres_citas',  null,         'after insert or delete',              'bit_cierres'),
      ('bitacora_textos',         'textos_panel',   null,         'after insert or update or delete',    'bit_textos'),
      ('bitacora_acompanamiento', 'acompanamiento', null,         'after update',                        'bit_acompanamiento')
    ) as t(disparador, tabla, columna, cuando, funcion)
  loop
    if to_regclass('public.' || d.tabla) is null
       or (d.columna is not null and not exists (
             select 1 from information_schema.columns
             where table_schema = 'public' and table_name = d.tabla and column_name = d.columna))
    then
      raise notice 'Sin %: falta public.%', d.disparador,
        d.tabla || case when d.columna is null then '' else '.' || d.columna end;
      continue;
    end if;
    execute format('drop trigger if exists %I on public.%I', d.disparador, d.tabla);
    execute format('create trigger %I %s on public.%I for each row execute function public.%I()',
                   d.disparador, d.cuando, d.tabla, d.funcion);
  end loop;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE
-- ───────────────────────────────────────────────────────────────────────
-- · Lo de antes de correrlo sigue sin estar. Un plazo cambiado ayer no
--   aparece: la bitácora empieza a contar lo nuevo desde hoy.
-- · No apunta lo que hace el inversionista con lo suyo (su empresa, sus
--   consultas). Esto es el registro de lo que hace el equipo.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. Doce disparadores 'bitacora_%': los cinco de antes y los siete de
--    ahora. Si falta alguno de los nuevos, falta su tabla: ver arriba.
select tgrelid::regclass as tabla, tgname as disparador
from   pg_trigger
where  not tgisinternal
  and  tgname like 'bitacora_%'
order  by tabla, disparador;

-- 2. apunta() cerrada. Las dos columnas tienen que salir en false.
select has_function_privilege('anon', 'public.apunta(text,text,text,text)', 'execute')          as anon_puede,
       has_function_privilege('authenticated', 'public.apunta(text,text,text,text)', 'execute') as con_sesion_puede;
