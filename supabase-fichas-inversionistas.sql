-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA FICHA DE CADA INVERSIONISTA
--  Necesita public.es_admin() y public.es_gestor() (supabase-admin.sql y
--  supabase-tramites.sql). Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 27-10-2026: la ficha toma los permisos que le faltan al
--  inversionista al crear su usuario, «con el fin de hacer función del
--  expediente»; se genera en Administración → Ficha técnica; tiene la
--  forma de la ficha de Atlas (la del caso Tertoga); y es editable por el
--  administrador «antes de subirla al inversionista».
--
--  UNA FILA POR INVERSIONISTA
--  ─────────────────────────────────────────────────────────────────────
--  La hoja entera va en 'contenido' (jsonb): título, línea de debajo, las
--  seis cifras, la ruta legal por secciones, la nota y las fuentes. Es un
--  documento que el administrador reescribe a mano, no un registro que se
--  consulte por partes, y así cada cambio del formato no pide otro SQL.
--
--  QUIÉN HACE QUÉ
--  ─────────────────────────────────────────────────────────────────────
--  · El administrador la crea, la cambia, la envía y la borra.
--  · El resto del equipo del CIIP la lee.
--  · El inversionista lee la suya, y solo una vez enviada: el borrador es
--    trabajo del CIIP.
-- ═══════════════════════════════════════════════════════════════════════

do $$
begin
  if to_regprocedure('public.es_admin()') is null then
    raise exception 'Falta public.es_admin(): corre antes supabase-admin.sql';
  end if;
  if to_regprocedure('public.es_gestor()') is null then
    raise exception 'Falta public.es_gestor(): corre antes supabase-tramites.sql';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA TABLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.fichas_inversionistas (
  usuario_id      uuid        primary key references public.perfiles(id) on delete cascade,
  contenido       jsonb       not null default '{}'::jsonb,
  estado          text        not null default 'borrador',
  -- Cuándo se le envió por última vez. Volver a borrador no la borra:
  -- dice que ya la vio una vez.
  enviada_en      timestamptz,
  creado_en       timestamptz default now(),
  actualizado_en  timestamptz default now(),
  actualizado_por uuid references auth.users(id) on delete set null,

  constraint fichas_inversionistas_estado_valido
    check (estado in ('borrador', 'enviada')),
  constraint fichas_inversionistas_es_objeto
    check (jsonb_typeof(contenido) = 'object'),
  constraint fichas_inversionistas_cabe
    check (pg_column_size(contenido) <= 200000)
);

comment on table  public.fichas_inversionistas           is 'La ficha de cada inversionista (ruta legal de su proyecto). La escribe el administrador; el inversionista la ve una vez enviada';
comment on column public.fichas_inversionistas.contenido is 'La hoja entera: titulo, sub, kpis, ruta, nota y fuentes';
comment on column public.fichas_inversionistas.estado    is 'borrador (solo la ve el CIIP) o enviada (la ve también el inversionista)';

alter table public.fichas_inversionistas enable row level security;


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN LA LEE Y QUIÉN LA ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
drop policy if exists "fichas_inversionistas: la lee el equipo" on public.fichas_inversionistas;
create policy "fichas_inversionistas: la lee el equipo" on public.fichas_inversionistas
  for select to authenticated
  using (public.es_gestor());

drop policy if exists "fichas_inversionistas: el inversionista lee la suya enviada" on public.fichas_inversionistas;
create policy "fichas_inversionistas: el inversionista lee la suya enviada" on public.fichas_inversionistas
  for select to authenticated
  using (usuario_id = auth.uid() and estado = 'enviada');

drop policy if exists "fichas_inversionistas: el admin la crea" on public.fichas_inversionistas;
create policy "fichas_inversionistas: el admin la crea" on public.fichas_inversionistas
  for insert to authenticated
  with check (public.es_admin());

drop policy if exists "fichas_inversionistas: el admin la cambia" on public.fichas_inversionistas;
create policy "fichas_inversionistas: el admin la cambia" on public.fichas_inversionistas
  for update to authenticated
  using      (public.es_admin())
  with check (public.es_admin());

drop policy if exists "fichas_inversionistas: el admin la borra" on public.fichas_inversionistas;
create policy "fichas_inversionistas: el admin la borra" on public.fichas_inversionistas
  for delete to authenticated
  using (public.es_admin());

revoke all on public.fichas_inversionistas from anon;


-- ───────────────────────────────────────────────────────────────────────
-- 3. QUIÉN LA TOCÓ Y CUÁNDO SE ENVIÓ
-- ───────────────────────────────────────────────────────────────────────
-- Lo pone la base, no el navegador. La fecha del envío se sella al pasar
-- a 'enviada', y no se mueve mientras siga enviada.
create or replace function public.marca_fichas_inversionistas()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.actualizado_por := auth.uid();
  new.actualizado_en  := now();
  if tg_op = 'UPDATE' then
    new.creado_en := old.creado_en;
    new.enviada_en := case
      when new.estado = 'enviada' and old.estado is distinct from 'enviada' then now()
      else old.enviada_en end;
  else
    new.enviada_en := case when new.estado = 'enviada' then now() else null end;
  end if;
  return new;
end $$;

drop trigger if exists fichas_inversionistas_quien on public.fichas_inversionistas;
create trigger fichas_inversionistas_quien
  before insert or update on public.fichas_inversionistas
  for each row execute function public.marca_fichas_inversionistas();
