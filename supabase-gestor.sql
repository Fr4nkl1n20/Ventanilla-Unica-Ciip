-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL EQUIPO DEL CIIP
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va DESPUÉS de supabase-setup.sql, supabase-tramites.sql y
--  supabase-citas.sql.
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ARREGLA
--  ─────────────────────────────────────────────────────────────────────
--  La cola de citas del panel enseña QUIÉN pidió cada una. Hasta ahora no
--  podía: la única política de lectura sobre public.perfiles es "cada quien
--  lee únicamente su propio perfil", sin excepción para el equipo. Un
--  gestor veía la cita pero no el nombre de quien la pidió, así que la cola
--  habría sido una lista de peticiones anónimas.
-- ═══════════════════════════════════════════════════════════════════════

-- El equipo del CIIP lee los perfiles de todos. No los EDITA: la política
-- de actualización sigue siendo solo la propia, y el trigger proteger_rol
-- impide que nadie se ascienda desde el navegador.
--
-- es_gestor() es security definer y se salta RLS, así que no hay recursión
-- al consultar perfiles desde una política de perfiles.
drop policy if exists "perfiles: el equipo los lee todos" on public.perfiles;
create policy "perfiles: el equipo los lee todos"
  on public.perfiles for select
  using (public.es_gestor());


-- ───────────────────────────────────────────────────────────────────────
--  CÓMO SE NOMBRA UN GESTOR
-- ───────────────────────────────────────────────────────────────────────
-- Desde aquí y solo desde aquí. El trigger proteger_rol deja pasar el
-- cambio porque auth.uid() es null en el SQL Editor; desde el navegador,
-- con sesión, lo rechaza. Es lo que impide que alguien se ascienda solo.
--
-- Quita el comentario, pon el correo y ejecútalo:

-- update public.perfiles
--    set rol = 'gestor'
--  where id = (select id from auth.users where email = 'TU-CORREO');

-- Para volver atrás:

-- update public.perfiles
--    set rol = 'inversionista'
--  where id = (select id from auth.users where email = 'TU-CORREO');


-- ───────────────────────────────────────────────────────────────────────
--  COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
-- Quién es del equipo ahora mismo:

--   select u.email, p.nombre_completo, p.rol
--     from public.perfiles p
--     join auth.users u on u.id = p.id
--    where p.rol in ('gestor','admin');
