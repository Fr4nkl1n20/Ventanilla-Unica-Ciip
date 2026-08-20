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


-- ───────────────────────────────────────────────────────────────────────
--  LA NOTA DE UNA DEVOLUCIÓN
-- ───────────────────────────────────────────────────────────────────────
-- Cuando un gestor devuelve un trámite, el trigger de supabase-tramites.sql
-- escribe el evento solo, pero con la nota VACÍA. La nota es justo lo que
-- el inversionista necesita leer para corregir, y sin esta política no hay
-- forma de ponerla desde el panel: sobre tramite_eventos solo existe la de
-- lectura, así que un UPDATE desde el navegador no afecta a ninguna fila.
--
-- Solo el equipo, y solo la nota: lo segundo no lo puede decir una política
-- —RLS trabaja por filas, no por columnas— así que lo corta un trigger.
drop policy if exists "eventos: el equipo anota" on public.tramite_eventos;
create policy "eventos: el equipo anota" on public.tramite_eventos
  for update
  using      (public.es_gestor())
  with check (public.es_gestor());

create or replace function public.eventos_solo_la_nota()
returns trigger
language plpgsql
as $$
begin
  -- Desde el SQL Editor auth.uid() es null y se deja pasar todo: es la
  -- puerta de servicio del equipo, igual que en las demás tablas.
  if auth.uid() is null then
    return new;
  end if;

  if new.tramite   is distinct from old.tramite
  or new.de_estado is distinct from old.de_estado
  or new.a_estado  is distinct from old.a_estado
  or new.autor     is distinct from old.autor
  or new.creado_en is distinct from old.creado_en then
    raise exception 'De un evento solo se puede cambiar la nota';
  end if;

  return new;
end;
$$;

drop trigger if exists eventos_proteger on public.tramite_eventos;
create trigger eventos_proteger
  before update on public.tramite_eventos
  for each row execute function public.eventos_solo_la_nota();
