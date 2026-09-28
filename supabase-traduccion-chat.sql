-- ══════════════════════════════════════════════════════════════════════
--  LOS MENSAJES DEL CHAT, TRADUCIDOS
--  Pedido del CIIP, 28 de septiembre de 2026
-- ══════════════════════════════════════════════════════════════════════
--
--  QUÉ PIDIÓ EL CIIP
--  «Si el inversionista escribe en japonés, a nosotros nos llega en
--  español, y cuando le respondamos, a él le llega en su idioma.» En los
--  tres chats (trámites, consultas y citas), con «Ver original», y solo
--  desde que se active: lo que ya se dijo no se traduce.
--
--  CÓMO
--  El mensaje se guarda como siempre, en su tabla, y no cambia: esas
--  tablas no dejan tocar una fila escrita, y el original es lo que vale.
--  Al lado, en mensaje_traducciones, una fila por mensaje con el idioma en
--  que se escribió y el texto en el idioma de quien lo va a leer:
--
--    del inversionista  →  al español (lo lee el equipo)
--    del equipo         →  al idioma del inversionista, que es el de su
--                          último mensaje en ese hilo; si todavía no ha
--                          escrito, el de su país
--
--  Si ya está en ese idioma, la fila se guarda igual, con texto nulo: así
--  se sabe en qué idioma escribe cada cual sin volver a preguntárselo a la
--  IA.
--
--  QUIÉN LA ESCRIBE
--  api/traducir.js, con el token de quien mandó el mensaje, a través de
--  guarda_traduccion(). La función solo deja poner la traducción de un
--  mensaje propio, recién escrito y una sola vez. Quien la llame por su
--  cuenta podría poner otra traducción a SU mensaje, que es lo mismo que
--  escribir otro mensaje: el original sigue ahí y «Ver original» lo
--  enseña.
--
--  QUIÉN LA LEE
--  Quien puede leer el mensaje. La política mira la tabla del mensaje con
--  los permisos de quien pregunta, así que manda la RLS de siempre.
--
--  EL TOPE
--  gasta_uso_ia('traductor'): 200 mensajes por hora y persona, que es más
--  de lo que escribe nadie en un chat y corta una pestaña que se vuelve
--  loca. Redefine gasta_uso_ia() de supabase-qa-admin.sql añadiendo la
--  pieza, así que va detrás.
--
--  Se puede correr más de una vez.
-- ══════════════════════════════════════════════════════════════════════

create table if not exists public.mensaje_traducciones (
  tabla           text        not null,
  mensaje         uuid        not null,
  idioma_original text        not null,
  idioma          text        not null,
  texto           text,
  creado_en       timestamptz not null default now(),
  primary key (tabla, mensaje),
  constraint traduccion_de_un_chat check (tabla in ('tramite_mensajes', 'consulta_mensajes', 'cita_mensajes')),
  constraint traduccion_idiomas check (idioma_original ~ '^[a-z]{2,3}$' and idioma ~ '^[a-z]{2,3}$'),
  constraint traduccion_cabe check (texto is null or length(texto) <= 8000)
);

comment on table public.mensaje_traducciones is
  'La traducción automática de cada mensaje de chat al idioma de quien lo lee. texto nulo = no hacía falta. Solo la escribe guarda_traduccion()';

alter table public.mensaje_traducciones enable row level security;
revoke all on public.mensaje_traducciones from anon, authenticated;
grant select on public.mensaje_traducciones to authenticated;

drop policy if exists "traducciones: quien lee el mensaje" on public.mensaje_traducciones;
create policy "traducciones: quien lee el mensaje" on public.mensaje_traducciones
  for select to authenticated using (
    case tabla
      when 'tramite_mensajes'  then exists (select 1 from public.tramite_mensajes  m where m.id = mensaje)
      when 'consulta_mensajes' then exists (select 1 from public.consulta_mensajes m where m.id = mensaje)
      when 'cita_mensajes'     then exists (select 1 from public.cita_mensajes     m where m.id = mensaje)
      else false
    end
  );

create or replace function public.guarda_traduccion(
  p_tabla text, p_mensaje uuid, p_idioma_original text, p_idioma text, p_texto text)
returns boolean
language plpgsql
security definer
set search_path = public
as $tr$
declare
  yo    uuid := auth.uid();
  autor uuid;
  hecho timestamptz;
begin
  if yo is null then
    raise exception 'Hace falta haber entrado' using errcode = '42501';
  end if;
  if public.esta_bloqueado() then
    return false;
  end if;

  if p_tabla = 'tramite_mensajes' then
    select m.autor, m.creado_en into autor, hecho from public.tramite_mensajes m where m.id = p_mensaje;
  elsif p_tabla = 'consulta_mensajes' then
    select m.autor, m.creado_en into autor, hecho from public.consulta_mensajes m where m.id = p_mensaje;
  elsif p_tabla = 'cita_mensajes' then
    select m.autor, m.creado_en into autor, hecho from public.cita_mensajes m where m.id = p_mensaje;
  else
    raise exception 'tabla desconocida: %', p_tabla;
  end if;

  -- Solo lo propio y recién escrito: la traducción sale al enviar.
  if autor is distinct from yo or hecho < now() - interval '15 minutes' then
    raise exception 'Solo se traduce un mensaje propio, al enviarlo' using errcode = '42501';
  end if;

  insert into public.mensaje_traducciones (tabla, mensaje, idioma_original, idioma, texto)
  values (p_tabla, p_mensaje, lower(p_idioma_original), lower(p_idioma), nullif(btrim(p_texto), ''))
  on conflict (tabla, mensaje) do nothing;

  return found;
end
$tr$;

revoke all on function public.guarda_traduccion(text, uuid, text, text, text) from public, anon;
grant execute on function public.guarda_traduccion(text, uuid, text, text, text) to authenticated;

-- El tope: la pieza 'traductor' entra en uso_ia y en gasta_uso_ia().
do $tr$
begin
  if to_regclass('public.uso_ia') is null then
    raise notice 'Sin public.uso_ia: el traductor usa el contador de la memoria. Corre supabase-tope-ia.sql y vuelve a pasar este.';
    return;
  end if;

  alter table public.uso_ia drop constraint if exists uso_ia_pieza_valida;
  alter table public.uso_ia add constraint uso_ia_pieza_valida
    check (pieza in ('asistente', 'lector', 'traductor'));

  execute $f$
create or replace function public.gasta_uso_ia(p_pieza text)
returns boolean
language plpgsql
security definer
set search_path = public
as $tope$
declare
  yo   uuid := auth.uid();
  tope integer;
  n    integer;
begin
  if yo is null then
    raise exception 'Hace falta haber entrado' using errcode = '42501';
  end if;

  if public.esta_bloqueado() then
    return false;
  end if;

  tope := case p_pieza when 'asistente' then 40
                       when 'lector'    then 20
                       when 'traductor' then 200 end;
  if tope is null then
    raise exception 'pieza desconocida: %', p_pieza;
  end if;

  delete from public.uso_ia where usuario = yo and hora < now() - interval '2 days';

  insert into public.uso_ia as u (usuario, pieza, hora, usos)
  values (yo, p_pieza, date_trunc('hour', now()), 1)
  on conflict (usuario, pieza, hora)
  do update set usos = u.usos + 1 where u.usos < tope
  returning usos into n;

  return n is not null;
end
$tope$
  $f$;

  revoke all on function public.gasta_uso_ia(text) from public, anon;
  grant execute on function public.gasta_uso_ia(text) to authenticated;
end
$tr$;
