-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA AUTORIZACIÓN AL CIIP, TRÁMITE A TRÁMITE
--  Va DESPUÉS de supabase-tramites.sql (tramites, tipos_tramite,
--  es_gestor()). Va al final para no mover el número de nadie.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 8 de octubre de 2026: al solicitar un trámite, el
--  inversionista contesta «¿Autorizas al CIIP a gestionar este trámite en
--  tu nombre?». Si dice que sí, acepta en línea -sin firma- una
--  autorización con sus datos, y el CIIP puede presentar, consignar y
--  retirar documentos. Si dice que no, gestiona él y el CIIP solo verifica.
--  No se pregunta en la constitución (con sus tramos), en el sellado de
--  libros ni en la acreditación de representación legal, que es ante el
--  propio CIIP. El texto está en revisión con el abogado.
--
--  CÓMO QUEDA
--  ───────────────────────────────────────────────────────────────────────
--  · Lo que eligió vive en tramites.datos.gestion ('ciip' | 'directa'):
--    no hace falta columna, y la cola del equipo ya lee datos.
--  · Cada «sí» deja una fila en autorizaciones: la CONSTANCIA. Lleva el
--    texto exacto que se aceptó, para que un cambio posterior del modelo
--    no reescriba lo que alguien aceptó, y un código AUT-AAAA-NNNNNN que
--    pone la base.
--  · Append-only, como pliego_aceptaciones: no se edita ni se borra. Solo
--    se revoca, con revoca_autorizacion(), que pone la fecha y nada más.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: la pregunta sale igual y la
--  solicitud se envía; lo que no queda es la constancia.
-- ═══════════════════════════════════════════════════════════════════════


create sequence if not exists public.autorizaciones_numero;

create table if not exists public.autorizaciones (
  id           uuid primary key default gen_random_uuid(),
  codigo       text unique,
  inversionista uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tramite      uuid not null references public.tramites(id) on delete cascade,
  tipo         text not null references public.tipos_tramite(codigo),
  texto        text not null,
  datos        jsonb not null default '{}'::jsonb,
  aceptada_en  timestamptz not null default now(),
  revocada_en  timestamptz,
  -- Una por trámite: reenviar una devuelta no vuelve a pedir el sí.
  constraint autorizaciones_una_por_tramite unique (tramite)
);

comment on table public.autorizaciones is
  'Constancia de que el inversionista autorizo al CIIP en un tramite. Solo se inserta; se revoca con revoca_autorizacion()';

create index if not exists autorizaciones_por_inversionista
  on public.autorizaciones (inversionista, aceptada_en desc);


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA CONSTANCIA LA PONE LA BASE
-- ───────────────────────────────────────────────────────────────────────
-- Quién, cuándo y el código: se ignora lo que venga. Y el trámite tiene
-- que ser suyo, que la política de insert solo mira la columna.
create or replace function public.autorizacion_la_pone_la_base()
returns trigger
language plpgsql
security definer
set search_path = public
as $aut$
begin
  if auth.uid() is not null then
    new.inversionista := auth.uid();
    new.aceptada_en   := now();
    new.revocada_en   := null;
    if not exists (select 1 from public.tramites t
                    where t.id = new.tramite and t.inversionista = auth.uid()) then
      raise exception 'Ese trámite no es tuyo.' using errcode = 'check_violation';
    end if;
  end if;
  new.codigo := 'AUT-' || to_char(new.aceptada_en at time zone 'America/Caracas', 'YYYY') || '-' ||
                lpad(nextval('public.autorizaciones_numero')::text, 6, '0');
  return new;
end
$aut$;

drop trigger if exists autorizacion_constancia on public.autorizaciones;
create trigger autorizacion_constancia
  before insert on public.autorizaciones
  for each row execute function public.autorizacion_la_pone_la_base();

-- Desde el 15-10-2026 la redefine supabase-borrado-admin.sql: la misma, con
-- la puerta del borrado del administrador (solo para borrar).
create or replace function public.autorizacion_no_se_toca()
returns trigger
language plpgsql
as $aut$
begin
  -- La puerta de servicio (SQL Editor) y la revocación, que solo pone
  -- la fecha a una que no la tenía.
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  if tg_op = 'UPDATE'
     and old.revocada_en is null and new.revocada_en is not null
     and (to_jsonb(new) - 'revocada_en') = (to_jsonb(old) - 'revocada_en') then
    return new;
  end if;
  raise exception 'Una autorización aceptada no se cambia ni se borra: se revoca.'
    using errcode = 'check_violation';
end
$aut$;

drop trigger if exists autorizacion_inmutable on public.autorizaciones;
create trigger autorizacion_inmutable
  before update or delete on public.autorizaciones
  for each row execute function public.autorizacion_no_se_toca();


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN LA VE Y QUIÉN LA ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
alter table public.autorizaciones enable row level security;

drop policy if exists "autorizaciones: las propias y el equipo" on public.autorizaciones;
create policy "autorizaciones: las propias y el equipo" on public.autorizaciones
  for select to authenticated
  using (inversionista = auth.uid() or public.es_gestor());

drop policy if exists "autorizaciones: el inversionista acepta" on public.autorizaciones;
create policy "autorizaciones: el inversionista acepta" on public.autorizaciones
  for insert to authenticated
  with check (inversionista = auth.uid());

revoke all on public.autorizaciones from anon;
grant select, insert on public.autorizaciones to authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- 3. REVOCAR
-- ───────────────────────────────────────────────────────────────────────
-- Solo la propia y solo una vez. Devuelve la fecha, o null si no había
-- nada que revocar.
create or replace function public.revoca_autorizacion(p_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $aut$
declare
  cuando timestamptz;
begin
  update public.autorizaciones
     set revocada_en = now()
   where id = p_id
     and inversionista = auth.uid()
     and revocada_en is null
  returning revocada_en into cuando;
  return cuando;
end
$aut$;

revoke all on function public.revoca_autorizacion(uuid) from public;
revoke all on function public.revoca_autorizacion(uuid) from anon;
grant execute on function public.revoca_autorizacion(uuid) to authenticated;
