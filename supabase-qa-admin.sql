-- Auditoría QA, administración y cuentas: QA-05, 06, 07, 26, 27, 40 y 43.
-- Idempotente. Va detrás de todos: necesita perfiles con bloqueado
-- (supabase-bloqueo.sql), la bitácora y el tope de la IA.

do $qa$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'perfiles'
                    and column_name = 'bloqueado') then
    raise exception 'Falta perfiles.bloqueado: pasa antes supabase-bloqueo.sql';
  end if;
  if to_regprocedure('public.esta_bloqueado()') is null
     or to_regprocedure('public.corta_si_bloqueado()') is null then
    raise exception 'Falta esta_bloqueado() o corta_si_bloqueado(): pasa antes supabase-bloqueo.sql';
  end if;
end
$qa$;


-- ── QA-05 · Bloquear a alguien del equipo le quita los permisos ────────
-- Misma firma y mismo cuerpo que en supabase-tramites.sql y
-- supabase-admin.sql, con una condición más. Decenas de políticas pasan
-- por aquí: no se toca nada más.
create or replace function public.es_gestor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles
    where id = auth.uid() and rol in ('gestor','admin')
      and not coalesce(bloqueado, false)
  );
$$;

create or replace function public.es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles p
    where p.id = auth.uid() and p.rol = 'admin'
      and not coalesce(p.bloqueado, false)
  );
$$;

-- Las tres tablas que el corte no cubría.
do $qa$
declare
  t text;
begin
  foreach t in array array['activos', 'horario_citas', 'identidad_comprobaciones'] loop
    if to_regclass('public.' || t) is null then
      raise notice 'No existe public.%: se salta', t;
      continue;
    end if;
    execute format('drop trigger if exists %I on public.%I', t || '_bloqueo', t);
    execute format('create trigger %I before insert or update or delete on public.%I '
                   'for each row execute function public.corta_si_bloqueado()',
                   t || '_bloqueo', t);
  end loop;
end
$qa$;

-- El asistente y el lector: una cuenta bloqueada no gasta IA. Devuelve
-- false y no un error, porque con un error las funciones de api/ vuelven
-- al contador de la memoria y dejarían pasar la pregunta.
do $qa$
begin
  if to_regclass('public.uso_ia') is null then
    raise notice 'Sin public.uso_ia: gasta_uso_ia() se queda como esté. Corre supabase-tope-ia.sql y vuelve a pasar este.';
    return;
  end if;

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
                       when 'lector'    then 20 end;
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
$qa$;


-- ── QA-06 · Dar de baja en vez de borrar ───────────────────────────────
-- La baja deja la cuenta bloqueada y con fecha; los trámites, papeles,
-- citas y aceptaciones del pliego siguen donde estaban.
alter table public.perfiles
  add column if not exists dado_de_baja_en  timestamptz,
  add column if not exists dado_de_baja_por uuid references auth.users(id) on delete set null;

comment on column public.perfiles.dado_de_baja_en is
  'Baja lógica: la cuenta queda bloqueada y su historia se conserva. La pone un admin';

-- Borrar la cuenta en auth.users arrastra en cascada todo lo suyo, y con
-- ello la prueba de que aceptó el pliego. Mientras haya aceptaciones no se
-- borra; si de verdad hay que hacerlo (una cuenta de pruebas), desde el
-- editor de SQL y a sabiendas:
--   begin; set local ciip.borrado_fisico = 'si'; delete from auth.users where ...; commit;
create or replace function public.no_borrar_con_historia()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('ciip.borrado_fisico', true), '') = 'si' then
    return old;
  end if;
  if to_regclass('public.pliego_aceptaciones') is not null
     and exists (select 1 from public.pliego_aceptaciones a where a.persona = old.id) then
    raise exception 'Esta cuenta aceptó el pliego: no se borra, se da de baja desde el panel (Usuarios)';
  end if;
  return old;
end $$;

drop trigger if exists no_borrar_con_historia on auth.users;
create trigger no_borrar_con_historia
  before delete on auth.users
  for each row execute function public.no_borrar_con_historia();


-- ── Comprobación ───────────────────────────────────────────────────────
-- Que es_gestor() y es_admin() sigan dejando entrar a quien debe. Si no
-- queda ningún admin sin bloquear, se para aquí y no se aplica nada.
do $qa$
declare
  n_admin int;
begin
  if pg_get_functiondef('public.es_gestor()'::regprocedure) not like '%bloqueado%'
     or pg_get_functiondef('public.es_admin()'::regprocedure) not like '%bloqueado%' then
    raise exception 'es_gestor() o es_admin() no quedaron con el bloqueo';
  end if;
  select count(*) into n_admin from public.perfiles
   where rol = 'admin' and not coalesce(bloqueado, false);
  if n_admin = 0 and exists (select 1 from public.perfiles where rol = 'admin') then
    raise exception 'Todos los admin están bloqueados: nadie podría desbloquearlos. Revisa perfiles antes de correr esto.';
  end if;
end
$qa$;

-- Quién del equipo conserva los permisos después de esto.
select p.nombre_completo, p.rol, p.bloqueado, p.dado_de_baja_en
from   public.perfiles p
where  p.rol in ('gestor', 'admin')
order  by p.rol, p.nombre_completo;
