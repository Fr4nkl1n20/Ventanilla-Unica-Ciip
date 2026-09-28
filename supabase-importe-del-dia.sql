-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL IMPORTE DEL DÍA
--  Va DESPUÉS de supabase-papeles-sellados.sql. Se puede correr más de una
--  vez. Sin correrlo el panel no se rompe: el gestor no puede dejar el
--  importe y el inversionista no puede enganchar su comprobante.
-- ═══════════════════════════════════════════════════════════════════════

-- Los dos papeles. Sirven para cualquier trámite: lo que cambia de uno a
-- otro es en qué paso se piden, y eso va en la tabla de abajo.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('importe_dia',      'Importe del día para pagar',                 false),
  ('pago_importe_dia', 'Comprobante del pago del importe del día',   false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- El monto, escrito por el gestor al subir el importe. Texto y no número:
-- lo que se copia es lo que dice el papel, con su moneda.
alter table public.documentos add column if not exists monto text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'documentos_monto_corto') then
    alter table public.documentos add constraint documentos_monto_corto
      check (monto is null or char_length(monto) <= 60);
  end if;
end $$;

-- QUÉ TRÁMITES LLEVAN IMPORTE DEL DÍA, Y EN QUÉ ESTADOS. Engancharlo a un
-- trámite nuevo es una fila aquí (y su entrada en IMPORTE_DEL_DIA de
-- panel.js); ninguna política hay que tocarla.
create table if not exists public.importe_del_dia_pasos (
  tipo_tramite text primary key references public.tipos_tramite(codigo) on delete cascade,
  estados      text[] not null default array['enviado','en_revision','ante_el_ente']
);
alter table public.importe_del_dia_pasos enable row level security;
drop policy if exists "importe del dia: lo lee quien entra" on public.importe_del_dia_pasos;
create policy "importe del dia: lo lee quien entra" on public.importe_del_dia_pasos
  for select to authenticated using (true);
drop policy if exists "importe del dia: lo cambia el admin" on public.importe_del_dia_pasos;
create policy "importe del dia: lo cambia el admin" on public.importe_del_dia_pasos
  for all using (public.es_admin()) with check (public.es_admin());

-- Hoy, en Caracas. La medianoche que manda es la de allí, no la del
-- servidor (UTC): a las 8 de la noche en Caracas el servidor ya va por
-- mañana.
create or replace function public.hoy_en_caracas()
returns date
language sql
stable
as $$ select (now() at time zone 'America/Caracas')::date $$;

-- Si este trámite, en este estado, lleva importe del día. security definer
-- para que las políticas la usen sin depender de la RLS de la tabla.
create or replace function public.importe_del_dia_abierto(p_tipo text, p_estado text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.importe_del_dia_pasos
     where tipo_tramite = p_tipo and p_estado = any(estados)
  )
$$;

-- Si el trámite tiene un importe de HOY. Es lo que decide la caducidad: el
-- de ayer sigue en la bóveda, pero ya no deja pagar contra él.
create or replace function public.importe_del_dia_vigente(p_tramite uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
      join public.tramites t   on t.id = td.tramite
     where td.tramite = p_tramite
       and d.tipo = 'importe_dia'
       and d.estado = 'validado'
       and d.inversionista = t.inversionista
       and (d.creado_en at time zone 'America/Caracas')::date = public.hoy_en_caracas()
  )
$$;

-- VARIOS IMPORTES EN UN TRÁMITE (28-9-2026). El registro de marca paga
-- tres o cuatro, uno por etapa. Cada importe y cada comprobante llevan el
-- nombre de su etapa en paso_importe, y el comprobante solo se engancha
-- contra un importe de hoy DEL MISMO nombre: el pago de la búsqueda de
-- antecedentes no sirve para el derecho de marca. Sin nombre (nulo en los
-- dos) es el caso de siempre, un importe por trámite.
alter table public.documentos add column if not exists paso_importe text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'documentos_paso_importe_corto') then
    alter table public.documentos add constraint documentos_paso_importe_corto
      check (paso_importe is null or char_length(paso_importe) <= 40);
  end if;
end $$;

create or replace function public.importe_del_dia_vigente(p_tramite uuid, p_paso text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
      join public.tramites t   on t.id = td.tramite
     where td.tramite = p_tramite
       and d.tipo = 'importe_dia'
       and d.estado = 'validado'
       and d.inversionista = t.inversionista
       and d.paso_importe is not distinct from p_paso
       and (d.creado_en at time zone 'America/Caracas')::date = public.hoy_en_caracas()
  )
$$;

revoke all on function public.importe_del_dia_abierto(text, text) from public, anon;
revoke all on function public.importe_del_dia_vigente(uuid) from public, anon;
revoke all on function public.importe_del_dia_vigente(uuid, text) from public, anon;
grant execute on function public.importe_del_dia_abierto(text, text) to authenticated;
grant execute on function public.importe_del_dia_vigente(uuid) to authenticated;
grant execute on function public.importe_del_dia_vigente(uuid, text) to authenticated;

-- El importe lo sube el equipo, entra 'validado' y va a 'emitidos', como el
-- documento para pagar la reserva del nombre.
drop policy if exists "documentos: el equipo sube el importe del dia" on public.documentos;
create policy "documentos: el equipo sube el importe del dia" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'importe_dia' and estado = 'validado');

drop policy if exists "adjuntos: el equipo engancha el importe del dia" on public.tramite_documentos;
create policy "adjuntos: el equipo engancha el importe del dia" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'importe_dia'
         and public.importe_del_dia_abierto(t.tipo, t.estado)
    )
  );

-- El comprobante: solo en su trámite, en los estados del paso y con un
-- importe de hoy colgado, del mismo nombre que el comprobante. Una vez
-- enganchado se queda: la medianoche caduca el importe, no el pago hecho
-- contra él.
drop policy if exists "adjuntos: el pago del importe del dia, con importe de hoy" on public.tramite_documentos;
create policy "adjuntos: el pago del importe del dia, con importe de hoy" on public.tramite_documentos
  for insert
  with check (
    exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and t.inversionista = auth.uid()
         and d.inversionista = auth.uid()
         and d.tipo = 'pago_importe_dia'
         and public.importe_del_dia_abierto(t.tipo, t.estado)
         and public.importe_del_dia_vigente(t.id, d.paso_importe)
    )
  );

-- El importe es papel del CIIP: el inversionista no lo crea, no le cambia
-- el monto ni la fecha. Y la fecha la pone la base, que es la que manda en
-- la caducidad. Trigger propio para no reescribir el de
-- supabase-papeles-sellados.sql.
create or replace function public.importe_del_dia_lo_pone_el_equipo()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' and new.tipo = 'importe_dia' then
    new.creado_en := now();
  end if;
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.tipo = 'importe_dia' or (tg_op = 'UPDATE' and old.tipo = 'importe_dia') then
    raise exception 'Ese papel lo emite el CIIP'
      using errcode = 'check_violation';
  end if;
  return new;
end
$$;

drop trigger if exists documentos_importe_del_dia on public.documentos;
create trigger documentos_importe_del_dia
  before insert or update on public.documentos
  for each row execute function public.importe_del_dia_lo_pone_el_equipo();

-- OPCIONAL: LIMPIAR A LAS 12:00 AM CON pg_cron. No hace falta: lo vencido
-- ya se ve vencido y no deja pagar. Si se quiere además que desaparezca,
-- se activa pg_cron en Supabase (Database → Extensions) y se corre esto.
-- 04:00 UTC es la medianoche de Caracas. Solo se lleva los importes sin
-- pagar; borrar la ficha deja el archivo apuntado al barrendero.
--
-- select cron.schedule('importe-del-dia-caduca', '0 4 * * *', $cron$
--   delete from public.documentos d
--    where d.tipo = 'importe_dia'
--      and (d.creado_en at time zone 'America/Caracas')::date < public.hoy_en_caracas()
--      and not exists (
--        select 1
--          from public.tramite_documentos td
--          join public.tramite_documentos tp on tp.tramite = td.tramite
--          join public.documentos p on p.id = tp.documento
--         where td.documento = d.id
--           and p.tipo = 'pago_importe_dia'
--           and p.estado <> 'rechazado'
--           and (tp.creado_en at time zone 'America/Caracas')::date
--             = (d.creado_en at time zone 'America/Caracas')::date
--      )
-- $cron$);
--
-- Para quitarlo: select cron.unschedule('importe-del-dia-caduca');

-- COMPROBACIÓN
--   select codigo from public.tipos_documento
--    where codigo in ('importe_dia', 'pago_importe_dia');            -- dos filas
--   select public.hoy_en_caracas();                                  -- la fecha de Caracas
--   select polname from pg_policy where polname like '%importe del dia%';  -- cinco filas
