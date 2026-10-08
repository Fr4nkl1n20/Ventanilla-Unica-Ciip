-- ══════════════════════════════════════════════════════════════════════
--  EL TOPE DEL ASISTENTE Y DEL LECTOR, EN LA BASE
--  Revisión de seguridad del 25 de septiembre de 2026
-- ══════════════════════════════════════════════════════════════════════
--
--  QUÉ PASABA
--  api/asistente.js y api/leer-documento.js contaban las preguntas de cada
--  persona en la memoria de la función. Vercel tiene varias copias a la vez
--  y las apaga cuando no se usan: cada copia nueva empezaba en cero, y unas
--  cuantas peticiones en paralelo multiplicaban el tope. Lo decían ellos
--  mismos: «un tope de verdad va en una tabla de la base».
--
--  QUÉ HACE
--  gasta_uso_ia('asistente' | 'lector') apunta una pregunta de quien llama
--  en la hora en curso y contesta si todavía cabía. Los topes viven AQUÍ y
--  no los manda nadie de fuera: 40 preguntas por hora al asistente y 20
--  papeles por hora al lector, los mismos que había en los dos archivos.
--  Quien la llame por su cuenta solo gasta su propio cupo.
--
--  Las funciones de Vercel la llaman con el token del usuario. Si esta
--  función todavía no existe en la base, vuelven al contador en memoria de
--  antes: correr este archivo mejora el tope, no correrlo no rompe nada.
--
--  Se puede correr más de una vez.
-- ══════════════════════════════════════════════════════════════════════

create table if not exists public.uso_ia (
  usuario uuid        not null references auth.users(id) on delete cascade,
  pieza   text        not null,
  hora    timestamptz not null,
  usos    integer     not null default 1,
  primary key (usuario, pieza, hora),
  constraint uso_ia_pieza_valida check (pieza in ('asistente', 'lector', 'traductor'))
);

comment on table public.uso_ia is
  'Cuántas veces usó cada persona el asistente y el lector en cada hora. Solo la escribe gasta_uso_ia()';

-- Sin políticas: nadie la lee ni la escribe desde fuera. Solo la función.
-- Una tabla de antes del traductor tiene la regla de dos piezas.
alter table public.uso_ia drop constraint if exists uso_ia_pieza_valida;
alter table public.uso_ia add constraint uso_ia_pieza_valida
  check (pieza in ('asistente', 'lector', 'traductor'));

alter table public.uso_ia enable row level security;
revoke all on public.uso_ia from anon, authenticated;

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

  -- Las tres definiciones (tope-ia, qa-admin, traduccion-chat) son la
  -- misma desde el 8-10-2026: volver a correr una suelta no puede quitar
  -- el bloqueo ni dejar sin tope al traductor.
  tope := case p_pieza when 'asistente' then 40
                       when 'lector'    then 20
                       when 'traductor' then 60 end;
  if tope is null then
    raise exception 'pieza desconocida: %', p_pieza;
  end if;

  -- Lo de hace más de dos días ya no cuenta para nada.
  delete from public.uso_ia where usuario = yo and hora < now() - interval '2 days';

  -- Con el cupo lleno el UPDATE no se hace y no devuelve fila: n queda nulo.
  insert into public.uso_ia as u (usuario, pieza, hora, usos)
  values (yo, p_pieza, date_trunc('hour', now()), 1)
  on conflict (usuario, pieza, hora)
  do update set usos = u.usos + 1 where u.usos < tope
  returning usos into n;

  return n is not null;
end
$tope$;

revoke all on function public.gasta_uso_ia(text) from public, anon;
grant execute on function public.gasta_uso_ia(text) to authenticated;
