-- SQL Editor de Supabase. Revisión de seguridad del 25-09-2026, último
-- paso de base de datos: el tope del asistente y del lector en la base, y
-- la firma de las observaciones sobre un papel. Se puede correr más de una
-- vez. Va DESPUÉS de CORRER-PAPELES-SELLADOS.sql (ya aplicado).
--
-- No borra ni cambia datos: crea una tabla vacía, una función, y redefine
-- el trigger que firma las revisiones. NO pegues TODO-EN-ORDEN.sql entero.

-- 1. EL TOPE DEL ASISTENTE Y DEL LECTOR (supabase-tope-ia.sql).
--    Mientras esto no esté, las funciones de Vercel siguen con el contador
--    en memoria de siempre: no se rompe nada por correrlo tarde.

create table if not exists public.uso_ia (
  usuario uuid        not null references auth.users(id) on delete cascade,
  pieza   text        not null,
  hora    timestamptz not null,
  usos    integer     not null default 1,
  primary key (usuario, pieza, hora),
  constraint uso_ia_pieza_valida check (pieza in ('asistente', 'lector'))
);

comment on table public.uso_ia is
  'Cuántas veces usó cada persona el asistente y el lector en cada hora. Solo la escribe gasta_uso_ia()';

-- Sin políticas: nadie la lee ni la escribe desde fuera. Solo la función.
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

  tope := case p_pieza when 'asistente' then 40
                       when 'lector'    then 20 end;
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


-- 2. LA OBSERVACIÓN TAMBIÉN SE FIRMA (supabase-papeles-sellados.sql).
--    El gestor puede dejar una nota sin tocar el estado; esa nota también
--    lleva su autor y su hora, puestos por la base y no por el navegador.

create or replace function public.papel_firma_la_revision()
returns trigger
language plpgsql
as $sellados$
begin
  if auth.uid() is null then
    return new;
  end if;
  if new.estado is distinct from old.estado
     or new.nota_revision is distinct from old.nota_revision then
    new.revisado_por := auth.uid();
    new.revisado_en  := now();
  end if;
  return new;
end
$sellados$;


-- 3. COMPROBAR. Tiene que salir: tabla = 1, funcion = 1, anon_no = true,
--    firma_observacion = 1.
select
  (select count(*) from pg_tables where schemaname = 'public' and tablename = 'uso_ia') as tabla,
  (select count(*) from pg_proc where proname = 'gasta_uso_ia') as funcion,
  not has_function_privilege('anon', 'public.gasta_uso_ia(text)', 'execute') as anon_no,
  (select count(*) from pg_proc where proname = 'papel_firma_la_revision'
      and prosrc like '%nota_revision%') as firma_observacion;
