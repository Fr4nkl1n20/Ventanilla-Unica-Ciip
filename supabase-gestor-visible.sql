-- El nombre del gestor que atiende cada solicitud, para el inversionista
-- que la pidió (Franklin Reyes, 30-9-2026: «aquí quiero ver el nombre del
-- gestor que me atiende», en la campana de avisos). El inversionista solo
-- lee su propio perfil, y abrirle perfiles ajenos le daría correos y
-- teléfonos del equipo. Esta función devuelve el nombre y nada más, y solo
-- de las solicitudes de quien pregunta. Se puede correr más de una vez.
-- Sin ella el panel no se rompe: los avisos salen sin el nombre.

create or replace function public.gestores_de_mis_tramites()
returns table (tramite uuid, nombre text)
language sql
stable
security definer
set search_path = public
as $$
  select t.id, nullif(trim(p.nombre_completo), '')
    from public.tramites t
    join public.perfiles p on p.id = t.gestor
   where t.inversionista = auth.uid()
     and t.gestor is not null
$$;

revoke all on function public.gestores_de_mis_tramites() from public;
revoke execute on function public.gestores_de_mis_tramites() from anon;
grant execute on function public.gestores_de_mis_tramites() to authenticated;

-- COMPROBACIÓN
--   select proname from pg_proc where proname = 'gestores_de_mis_tramites';   -- una fila
