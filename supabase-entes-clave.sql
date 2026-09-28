-- El IVSS y el INCES no mandan un código: mandan usuario y contraseña. El
-- usuario va en tramite_entes.codigo, como el código de los demás, y la
-- contraseña en su propia columna. La leen las mismas políticas de la fila:
-- el inversionista dueño de la solicitud y el equipo, nadie más.
-- Se puede correr más de una vez. Va después de supabase-entes-parafiscales.sql.

alter table public.tramite_entes add column if not exists clave text;

alter table public.tramite_entes drop constraint if exists tramite_entes_clave_tope;
alter table public.tramite_entes add constraint tramite_entes_clave_tope
  check (clave is null or length(clave) <= 200);

-- Solo esos dos entes llevan contraseña.
alter table public.tramite_entes drop constraint if exists tramite_entes_clave_solo_ivss_inces;
alter table public.tramite_entes add constraint tramite_entes_clave_solo_ivss_inces
  check (clave is null or ente in ('ivss', 'inces'));

-- Sin sesión no hay fila que leer (las políticas son por dueño o equipo),
-- pero la columna tampoco tiene por qué estar a su alcance.
revoke all on public.tramite_entes from anon;

-- Comprobación: la columna, y las cuatro políticas de siempre.
select column_name, data_type from information_schema.columns
 where table_schema = 'public' and table_name = 'tramite_entes' and column_name = 'clave';
select policyname, cmd from pg_policies where tablename = 'tramite_entes' order by policyname;
