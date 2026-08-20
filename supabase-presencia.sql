-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — QUIÉN ESTÁ Y QUIÉN NO
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-setup.sql.
-- ═══════════════════════════════════════════════════════════════════════
--
--  LO QUE ESTO MIDE, Y LO QUE NO
--  ─────────────────────────────────────────────────────────────────────
--  No mide si alguien está conectado: eso no se puede saber. Un navegador
--  no avisa cuando se cierra, ni cuando se va la luz, ni cuando alguien
--  cierra la tapa del portátil.
--
--  Mide la ÚLTIMA VEZ QUE EL PANEL ESTUVO ABIERTO. El panel lo apunta al
--  entrar y cada dos minutos mientras la pestaña esté a la vista. De ahí
--  sale el "en línea": no es una conexión, es "hace menos de tres
--  minutos". Alguien con la pestaña abierta de fondo cuenta como presente,
--  y es correcto: el panel está abierto.
--
--  Lo que sí resuelve, y era lo que faltaba: saber quién del equipo lleva
--  un mes sin entrar, o si un inversionista abrió el panel alguna vez.
--
--  LA HORA LA PONE EL SERVIDOR
--  ─────────────────────────────────────────────────────────────────────
--  Y no el navegador. Si la escribiera el navegador, un reloj mal puesto
--  dejaría a alguien "en línea" desde mañana o desaparecido desde 2019, y
--  cualquiera podría escribir la hora que quisiera.
-- ═══════════════════════════════════════════════════════════════════════

alter table public.perfiles
  add column if not exists visto_en timestamptz;

comment on column public.perfiles.visto_en is
  'Ultima vez que el panel estuvo abierto. La escribe tocar_visto() con la hora del servidor';


-- ───────────────────────────────────────────────────────────────────────
--  APUNTAR QUE SIGO AQUÍ
-- ───────────────────────────────────────────────────────────────────────
-- security definer para poner la hora del SERVIDOR y para no depender de
-- que la política de update de perfiles cambie mañana. Solo toca tu propia
-- fila y solo esa columna: no hay forma de escribir la de otro.
create or replace function public.tocar_visto()
returns void
language sql
security definer
set search_path = public
as $$
  update public.perfiles set visto_en = now() where id = auth.uid();
$$;

revoke all on function public.tocar_visto() from public;
grant execute on function public.tocar_visto() to authenticated;


-- ───────────────────────────────────────────────────────────────────────
--  COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--   select public.tocar_visto();
--   select nombre_completo, visto_en from public.perfiles order by visto_en desc nulls last;
