-- ══════════════════════════════════════════════════════════════════════
--  CONFIRMA UN PASO: «ya me registré»
--  Se puede correr más de una vez.
-- ══════════════════════════════════════════════════════════════════════
--  Franklin Reyes, 25-9-2026: «el 2 se marca cuando el usuario confirma
--  que registró el usuario». La marca va en tramites.datos, pero no puede
--  ser un update a secas: con la visa en revisión el inversionista no toca
--  su trámite (la política solo le deja el borrador o el devuelto), el
--  update cambiaría cero filas y PostgREST contestaría que todo bien.
--
--  Así que va por esta función: comprueba que el trámite es tuyo y que está
--  en marcha, y levanta una excepción si no tocó ninguna fila. Acepta UNA
--  sola llave, a propósito: con el nombre libre, el inversionista podría
--  escribir lo que quisiera dentro de datos.
--
--  Vivía en CORRER-HOY-2026-09-25.sql; desde el mismo día está aquí, que
--  es de donde sale TODO-EN-ORDEN.sql.
-- ══════════════════════════════════════════════════════════════════════

create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
-- Supabase le da EXECUTE a anon en cada función nueva por su cuenta: el
-- revoke de PUBLIC no lo quita. Sin sesión no haría nada (auth.uid() es
-- nulo y no encuentra trámite), pero no tiene por qué poder llamarla.
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;
