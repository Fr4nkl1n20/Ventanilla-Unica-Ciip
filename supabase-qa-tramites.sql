-- Lo que encontró la revisión de trámites y papeles (QA, 28-9-2026).
-- Se puede correr más de una vez. Va detrás de todo: toca trabajos
-- (supabase-cola), ordenes_pago (supabase-aranceles), tramite_entes
-- (supabase-entes-parafiscales) y redefine confirma_paso().

do $qa$
begin
  if to_regclass('public.trabajos') is null then
    raise exception 'Falta supabase-cola.sql: va antes que éste';
  end if;
  if to_regclass('public.ordenes_pago') is null then
    raise exception 'Falta supabase-aranceles.sql: va antes que éste';
  end if;
  if to_regclass('public.tramite_entes') is null then
    raise exception 'Falta supabase-entes-parafiscales.sql: va antes que éste';
  end if;
end
$qa$;


-- ── QA-09 y QA-15 · Lo pendiente de un trámite que sale del CIIP ──────
-- Un trabajo de 'presentar' encolado seguía ahí al cancelar o devolver el
-- trámite, y el trabajador lo presentaba igual. Y la orden de pago de un
-- cancelado se quedaba pendiente para siempre. Se anulan, no se borran:
-- que se viera que hubo algo y por qué dejó de haberlo.
--
-- Solo lo 'pendiente'. Lo que está 'haciendose' lo tiene el trabajador en
-- la mano, y lo cierra él; si lo que iba a hacer ya no cabe en la
-- escalera, la base se lo rechaza y lo alerta.
--
-- Devolver no anula la orden de pago: el trámite vuelve, y la orden viva
-- es la misma que se pagará cuando vuelva. Qué se hace con lo ya PAGADO
-- de un cancelado (devolverlo, guardarlo para otra solicitud) lo decide
-- el CIIP: aquí no se toca.

alter table public.trabajos drop constraint if exists trabajos_estado_valido;
alter table public.trabajos add constraint trabajos_estado_valido
  check (estado in ('pendiente', 'haciendose', 'hecho', 'alertado', 'anulado'));

create or replace function public.tramite_anula_lo_pendiente()
returns trigger
language plpgsql
security definer
set search_path = public
as $qa$
begin
  if new.estado is not distinct from old.estado
     or new.estado not in ('cancelado', 'devuelto') then
    return new;
  end if;

  update public.trabajos
     set estado = 'anulado',
         ultimo_error = 'Anulado: el trámite pasó a ' || new.estado
   where tramite = new.id
     and estado = 'pendiente';

  if new.estado = 'cancelado' then
    update public.ordenes_pago
       set estado = 'anulada'
     where tramite = new.id
       and estado = 'pendiente';
  end if;

  return new;
end
$qa$;

drop trigger if exists tramites_anula_lo_pendiente on public.tramites;
create trigger tramites_anula_lo_pendiente
  after update of estado on public.tramites
  for each row execute function public.tramite_anula_lo_pendiente();


-- ── QA-16 · Un papel en una solicitud en marcha no se borra ───────────
-- tramite_documentos va con 'on delete cascade': borrar el documento lo
-- quitaba en silencio del expediente que el CIIP ya estaba revisando. Lo
-- frenaba el panel, y por la API no lo frenaba nadie. En borrador y en
-- devuelto sí se puede: son de quien los rellena. Cancelada, también.
create or replace function public.papel_en_marcha_no_se_borra()
returns trigger
language plpgsql
security definer
set search_path = public
as $qa$
begin
  if auth.uid() is null then
    return old;   -- la puerta de servicio: borrar una cuenta entera
  end if;
  if exists (
    select 1
      from public.tramite_documentos td
      join public.tramites t on t.id = td.tramite
     where td.documento = old.id
       and t.estado not in ('borrador', 'devuelto', 'cancelado')
  ) then
    raise exception 'Ese documento va en una solicitud en marcha: no se borra'
      using errcode = 'check_violation';
  end if;
  return old;
end
$qa$;

drop trigger if exists documentos_en_marcha_no_se_borra on public.documentos;
create trigger documentos_en_marcha_no_se_borra
  before delete on public.documentos
  for each row execute function public.papel_en_marcha_no_se_borra();


-- ── QA-17 · El papel que el CIIP revisa no cambia por debajo ──────────
-- La política deja al inversionista editar su papel mientras no esté
-- validado, y eso incluía cambiarle el archivo y el tipo a uno que el
-- gestor tenía abierto. El panel nunca lo hace: «Cambiar» sube uno nuevo.
-- Trigger propio, al lado de los de supabase-papeles-sellados,
-- supabase-importe-del-dia y supabase-marca, sin tocar ninguno.
create or replace function public.papel_en_marcha_no_cambia()
returns trigger
language plpgsql
security definer
set search_path = public
as $qa$
begin
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.archivo is not distinct from old.archivo
     and new.tipo is not distinct from old.tipo then
    return new;
  end if;
  if exists (
    select 1
      from public.tramite_documentos td
      join public.tramites t on t.id = td.tramite
     where td.documento = old.id
       and t.estado not in ('borrador', 'devuelto')
  ) then
    raise exception 'Ese documento va en una solicitud en marcha: sube uno nuevo'
      using errcode = 'check_violation';
  end if;
  return new;
end
$qa$;

drop trigger if exists documentos_en_marcha_no_cambia on public.documentos;
create trigger documentos_en_marcha_no_cambia
  before update on public.documentos
  for each row execute function public.papel_en_marcha_no_cambia();


-- ── QA-18 · Los registros parafiscales, con los seis entes listos ─────
-- Lo miraba solo el panel. Misma forma que tramites_marca_con_certificado.
create or replace function public.parafiscales_con_los_seis()
returns trigger
language plpgsql
security definer
set search_path = public
as $qa$
begin
  if auth.uid() is null
     or new.tipo is distinct from 'registros_parafiscales'
     or new.estado is distinct from 'resuelto'
     or old.estado = 'resuelto' then
    return new;
  end if;
  if (select count(*) from public.tramite_entes
       where tramite = new.id and estado = 'listo') < 6 then
    raise exception 'Hay inscripciones sin terminar en los registros parafiscales'
      using errcode = 'check_violation';
  end if;
  return new;
end
$qa$;

drop trigger if exists tramites_parafiscales_con_los_seis on public.tramites;
create trigger tramites_parafiscales_con_los_seis
  before update on public.tramites
  for each row execute function public.parafiscales_con_los_seis();


-- ── QA-34 · confirma_paso() no toca un cancelado ──────────────────────
-- La de supabase-confirma-paso.sql, con 'cancelado' entre lo excluido.
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
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;


-- ── QA-35 · La nota de un evento, solo quien lo hizo y ese mismo día ──
-- Cualquier gestor podía reescribir la nota de cualquier evento pasado,
-- también la de una devolución de hace un mes que el inversionista ya
-- leyó. El panel solo escribe la del evento que acaba de nacer de su
-- propio cambio, así que esto no le quita nada. El trigger
-- eventos_solo_la_nota (supabase-gestor.sql) sigue cortando lo demás.
drop policy if exists "eventos: el equipo anota" on public.tramite_eventos;
create policy "eventos: el equipo anota" on public.tramite_eventos
  for update
  using      (public.es_gestor() and autor = auth.uid()
              and creado_en > now() - interval '24 hours')
  with check (public.es_gestor() and autor = auth.uid());


-- ── QA-38 · Escribir una clave de datos sin pisar las demás ───────────
-- El gestor mandaba datos enteros sobre una copia leída hace un rato, y se
-- llevaba por delante lo que el inversionista hubiera marcado entretanto.
-- Esto mezcla en la base. Con los permisos de quien llama: la política y
-- los triggers de tramites deciden, como en un update a secas. Revienta si
-- no tocó ninguna fila.
create or replace function public.mezcla_datos_tramite(p_tramite uuid, p_datos jsonb)
returns public.tramites
language plpgsql
set search_path = public
as $qa$
declare
  fila public.tramites;
begin
  if p_datos is null or jsonb_typeof(p_datos) <> 'object' then
    raise exception 'datos tiene que ser un objeto';
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb) || p_datos
   where id = p_tramite
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo guardar';
  end if;
  return fila;
end
$qa$;

revoke all on function public.mezcla_datos_tramite(uuid, jsonb) from public;
revoke execute on function public.mezcla_datos_tramite(uuid, jsonb) from anon;
grant execute on function public.mezcla_datos_tramite(uuid, jsonb) to authenticated;


-- COMPROBACIÓN
--   select tgname from pg_trigger where tgname in
--     ('tramites_anula_lo_pendiente', 'documentos_en_marcha_no_se_borra',
--      'documentos_en_marcha_no_cambia', 'tramites_parafiscales_con_los_seis');   -- cuatro filas
--   select proname from pg_proc where proname = 'mezcla_datos_tramite';           -- una fila
