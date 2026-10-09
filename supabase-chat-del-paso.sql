-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL CHAT DE UN PASO
--  Va DESPUÉS de supabase-hilo.sql (tramite_mensajes) y ANTES de
--  supabase-marca.sql, cuyo habilita_contestacion() escribe en el chat.
--  Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 9 de octubre de 2026: en el registro de marca, cuando
--  el SAPI devuelve el registro y el gestor habilita la contestación, el
--  inversionista habla con su gestor en un chat que vive SOLO en ese paso,
--  y el gestor le puede mandar documentos por ahí.
--
--  CÓMO QUEDA
--  ───────────────────────────────────────────────────────────────────────
--  · Es la misma conversación del expediente (tramite_mensajes), con una
--    columna más: paso. Null es la conversación de siempre; 'contestacion'
--    es el chat de la contestación de la marca. Así hereda todo lo que ya
--    tiene el hilo: la firma de la base, los adjuntos a la bóveda del
--    inversionista, la traducción y que un mensaje no se borra.
--  · Solo se escribe en él con la contestación habilitada, y se cierra
--    cuando la marca pasa a registro (o se resuelve o se cancela): lo dicho
--    se sigue leyendo, pero ya no se contesta ahí.
--  · El anuncio con el que el gestor habilita la contestación es su primer
--    mensaje (supabase-marca.sql).
-- ═══════════════════════════════════════════════════════════════════════

alter table public.tramite_mensajes add column if not exists paso text;

alter table public.tramite_mensajes drop constraint if exists mensaje_paso_valido;
alter table public.tramite_mensajes add constraint mensaje_paso_valido
  check (paso is null or paso in ('contestacion'));

comment on column public.tramite_mensajes.paso is
  'De qué chat es: null, la conversación del expediente; contestacion, el chat de la contestación de la marca';

create index if not exists mensajes_por_paso
  on public.tramite_mensajes (tramite, paso, creado_en);

-- Cuándo se puede escribir en el chat de un paso. Security definer para
-- leer el trámite tal como es, no como lo deja ver RLS.
create or replace function public.mensaje_del_paso()
returns trigger
language plpgsql
security definer
set search_path = public
as $chat$
declare
  t public.tramites;
begin
  if new.paso is null then
    return new;
  end if;
  select * into t from public.tramites where id = new.tramite;
  if new.paso = 'contestacion' then
    if t.tipo is distinct from 'marca'
       or not coalesce((t.datos -> 'pasos_ciip') ? 'contestacion', false) then
      raise exception 'El chat de la contestación no está abierto'
        using errcode = 'check_violation';
    end if;
    if coalesce((t.datos -> 'pasos_ciip') ? 'en_registro', false)
       or t.estado in ('resuelto', 'cancelado') then
      raise exception 'El chat de la contestación ya se cerró'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end
$chat$;

drop trigger if exists mensajes_del_paso on public.tramite_mensajes;
create trigger mensajes_del_paso
  before insert on public.tramite_mensajes
  for each row execute function public.mensaje_del_paso();

-- COMPROBACIÓN
--   select column_name from information_schema.columns
--    where table_name = 'tramite_mensajes' and column_name = 'paso';   -- una fila
--   select tgname from pg_trigger where tgname = 'mensajes_del_paso';  -- una fila
