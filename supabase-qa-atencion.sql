-- Citas y consultas: lo que encontró la auditoría QA del 28-9-2026.
-- Va DETRÁS de supabase-citas, supabase-consultas y supabase-disponibilidad.

do $$
begin
  if to_regclass('public.citas') is null
     or to_regclass('public.consultas') is null
     or to_regclass('public.horario_citas') is null then
    raise exception using
      message = 'Faltan las citas, las consultas o el horario',
      hint    = 'Pasa antes supabase-citas.sql, supabase-consultas.sql y supabase-disponibilidad.sql.';
  end if;
end $$;


-- ── 1. LOS ESTADOS DE UNA CITA, Y POR QUÉ SE CANCELÓ ─────────────────────
-- «No asistió» es lo que le pasa a una cita que llegó y no vino nadie: sin
-- él, la única forma de sacarla de las vivas era decir que se hizo.
--
-- motivo lo escribe el CIIP al rechazar, cancelar o mover una cita, y es
-- lo que el buzón le enseña al inversionista. cancelada_por_ciip la pone la
-- base: la fila no guardaba quién la canceló, y por eso el buzón no podía
-- avisar de una cancelación sin arriesgarse a contarle a alguien lo que
-- acababa de hacer él mismo.
alter table public.citas drop constraint if exists citas_estado_valido;
alter table public.citas add  constraint citas_estado_valido
  check (estado in ('solicitada','confirmada','hecha','no_asistio','cancelada'));

alter table public.citas add column if not exists motivo text not null default '';
alter table public.citas add column if not exists cancelada_por_ciip boolean not null default false;

alter table public.citas drop constraint if exists citas_motivo_cabe;
alter table public.citas add  constraint citas_motivo_cabe check (length(motivo) <= 500);

comment on column public.citas.motivo is 'Por qué el CIIP la rechazó, la canceló o la movió. Lo lee el inversionista en su buzón';
comment on column public.citas.cancelada_por_ciip is 'true = la canceló o la rechazó el CIIP, no quien la pidió. La pone la base';


-- ── 2. EL INVERSIONISTA SOLO CANCELA ─────────────────────────────────────
-- Antes se miraba campo por campo y se escapaban modo y nota: por la API se
-- podía cambiar cómo y para qué era una cita ya confirmada. Ahora se
-- compara la fila entera menos el estado y lo que pone la propia base.
--
-- pg_trigger_depth() > 1 es la base cerrando sola las citas pasadas de
-- quien pide otra (apartado 4): viene de un disparador, no de nadie.
create or replace function public.citas_solo_cancelar()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() is null or public.es_gestor() or pg_trigger_depth() > 1 then
    return new;
  end if;

  if new.estado is distinct from old.estado and new.estado <> 'cancelada' then
    raise exception 'Una cita solo se puede cancelar desde el panel';
  end if;

  if (to_jsonb(new) - 'estado' - 'actualizado_en' - 'cancelada_por_ciip')
     is distinct from
     (to_jsonb(old) - 'estado' - 'actualizado_en' - 'cancelada_por_ciip') then
    raise exception 'Esos datos de la cita los fija el CIIP';
  end if;

  return new;
end;
$$;


-- ── 3. LO QUE HACE EL CIIP CON UNA CITA ──────────────────────────────────
-- Rechazar o cancelar pide motivo, y queda dicho que fue el CIIP. Cerrarla
-- -hecha o no asistió- solo cuando ya ha pasado: cerrar una del martes que
-- viene sería borrarla de la agenda sin avisar a nadie.
create or replace function public.citas_lo_que_hace_el_ciip()
returns trigger
language plpgsql
as $$
begin
  if new.estado = 'cancelada' and old.estado is distinct from 'cancelada' then
    new.cancelada_por_ciip := (auth.uid() is not null
                               and public.es_gestor()
                               and new.inversionista is distinct from auth.uid());
    if new.cancelada_por_ciip and length(trim(coalesce(new.motivo, ''))) = 0 then
      raise exception 'Hace falta decir por qué se cancela la cita'
        using errcode = 'check_violation';
    end if;
  end if;

  if new.estado in ('hecha','no_asistio') and old.estado is distinct from new.estado
     and auth.uid() is not null and pg_trigger_depth() = 1
     and (new.cuando is null or new.cuando > now()) then
    raise exception 'Una cita que todavía no ha pasado no se cierra'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists citas_quien_cancela on public.citas;
create trigger citas_quien_cancela
  before update on public.citas
  for each row execute function public.citas_lo_que_hace_el_ciip();


-- ── 4. UNA CITA PASADA YA NO ESTÁ VIVA ───────────────────────────────────
-- Nadie ponía «hecha», así que una cita confirmada del mes pasado seguía
-- viva para siempre y reserva_cita contestaba «Ya tienes una cita en
-- marcha» a quien quería otra.
--
-- Viva es: pedida, o confirmada y por delante. Y como un índice parcial no
-- puede usar now(), la regla de una viva por persona (apartado 5) se
-- apoya en el ESTADO: cuando alguien pide otra, la base da por hechas sus
-- confirmadas que ya pasaron. «Hecha» y no «no asistió» porque es lo que
-- casi siempre ocurrió; si no fue así, el equipo tiene la lista de
-- pendientes de cerrar para decirlo antes, y es donde debería hacerse.
create or replace function public.citas_cierra_las_pasadas()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.citas
     set estado = 'hecha'
   where inversionista = new.inversionista
     and estado = 'confirmada'
     and cuando <= now();
  return new;
end;
$$;

drop trigger if exists citas_cierra_pasadas on public.citas;
create trigger citas_cierra_pasadas
  before insert on public.citas
  for each row execute function public.citas_cierra_las_pasadas();

create or replace function public.reserva_cita(
  p_cuando timestamptz,
  p_modo   text,
  p_tipo   text default null,
  p_nota   text default ''
)
returns public.citas
language plpgsql
security definer
set search_path = public
as $res$
declare
  yo     uuid := auth.uid();
  local  timestamp;
  dia_l  date;
  hora_l time;
  fila   public.citas;
begin
  if yo is null then
    raise exception 'Hace falta haber entrado para reservar'
      using errcode = 'insufficient_privilege';
  end if;

  if p_modo is null or p_modo not in ('presencial','video','telefono') then
    raise exception 'Modo de cita no válido'
      using errcode = 'check_violation';
  end if;

  if length(coalesce(p_nota, '')) > 500 then
    raise exception 'La nota es demasiado larga'
      using errcode = 'check_violation';
  end if;

  if p_cuando is null or p_cuando <= now() then
    raise exception 'Ese hueco ya pasó'
      using errcode = 'check_violation';
  end if;

  if p_cuando > now() + interval '92 days' then
    raise exception 'Ese hueco está demasiado lejos'
      using errcode = 'check_violation';
  end if;

  local  := p_cuando at time zone 'America/Caracas';
  dia_l  := local::date;
  hora_l := local::time;

  if exists (select 1 from public.cierres_citas where fecha = dia_l) then
    raise exception 'Ese día el CIIP no atiende'
      using errcode = 'check_violation';
  end if;

  if not exists (
    select 1
      from public.horario_citas h
     where h.dia = extract(isodow from local)::int
       and hora_l >= h.desde
       and hora_l + make_interval(mins => h.cada_min) <= h.hasta
       and (extract(epoch from (hora_l - h.desde))::int % (h.cada_min * 60)) = 0
  ) then
    raise exception 'Ese hueco no está en el horario del CIIP'
      using errcode = 'check_violation';
  end if;

  -- Una cita viva por persona. La que ya pasó no cuenta: la cierra el
  -- disparador del apartado 4 al entrar la nueva.
  if exists (
    select 1 from public.citas
     where inversionista = yo
       and (estado = 'solicitada' or (estado = 'confirmada' and cuando > now()))
  ) then
    raise exception 'Ya tienes una cita en marcha'
      using errcode = 'check_violation';
  end if;

  if exists (
    select 1 from public.citas
     where cuando = p_cuando and estado in ('solicitada','confirmada')
  ) then
    raise exception 'Ese hueco se acaba de ocupar'
      using errcode = 'unique_violation';
  end if;

  insert into public.citas
    (inversionista, tipo_tramite, modo, desde, hasta, nota, estado, cuando, hueco)
  values
    (yo, nullif(p_tipo, ''), p_modo, dia_l, dia_l, coalesce(trim(p_nota), ''),
     'confirmada', p_cuando, true)
  returning * into fila;

  return fila;

-- El índice de una viva por persona también salta como unique_violation, y
-- no es lo mismo que un hueco ocupado: se distingue por su nombre.
exception when unique_violation then
  if sqlerrm like '%citas_una_viva_por_persona%' then
    raise exception 'Ya tienes una cita en marcha'
      using errcode = 'check_violation';
  end if;
  raise exception 'Ese hueco se acaba de ocupar'
    using errcode = 'unique_violation';
end
$res$;

revoke all on function public.reserva_cita(timestamptz, text, text, text) from public;
grant execute on function public.reserva_cita(timestamptz, text, text, text) to authenticated;


-- ── 5. UNA VIVA POR PERSONA, TAMBIÉN POR DETRÁS ──────────────────────────
-- La pantalla y reserva_cita lo comprobaban, pero un insert directo a la
-- API no, y dos pestañas a la vez tampoco. El índice es la cerradura.
--
-- Si ya hay personas con dos vivas, crearlo haría fallar el archivo
-- entero. Entonces no se crea, se dice quiénes son, y se vuelve a pasar
-- este archivo cuando el equipo las haya cerrado o cancelado.
do $$
declare
  repetidas int;
begin
  if to_regclass('public.citas_una_viva_por_persona') is not null then
    return;
  end if;
  select count(*) into repetidas from (
    select inversionista from public.citas
     where estado in ('solicitada','confirmada')
     group by inversionista having count(*) > 1
  ) x;
  if repetidas > 0 then
    raise notice 'Hay % personas con más de una cita viva: el índice de una por persona no se crea. Ciérralas o cancélalas y vuelve a pasar este archivo.', repetidas;
    return;
  end if;
  execute 'create unique index citas_una_viva_por_persona
             on public.citas (inversionista)
             where estado in (''solicitada'',''confirmada'')';
end $$;


-- ── 6. CONFIRMAR O MOVER UNA CITA DESDE EL EQUIPO ────────────────────────
-- La confirmación a mano mandaba la hora en la zona del navegador del
-- gestor y no miraba nada: ni que fuera futura, ni el día cerrado, ni que
-- la hora estuviera libre. Aquí se mira lo mismo que en reserva_cita,
-- salvo el «en punto con su intervalo»: una cita pedida con una ventana de
-- días la pone el CIIP a la hora que acuerde, siempre que caiga dentro de
-- lo que atiende. Sin horario publicado no hay tramos que mirar.
--
-- Sirve también para MOVER una confirmada, y entonces el motivo es
-- obligatorio: es lo que le dice al inversionista por qué cambia su día.
create or replace function public.confirma_cita(
  p_cita   uuid,
  p_cuando timestamptz,
  p_lugar  text default null,
  p_motivo text default ''
)
returns public.citas
language plpgsql
security definer
set search_path = public
as $con$
declare
  vieja  public.citas;
  local  timestamp;
  hora_l time;
  fila   public.citas;
begin
  if auth.uid() is null or not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP confirma citas'
      using errcode = 'insufficient_privilege';
  end if;

  select * into vieja from public.citas where id = p_cita for update;
  if vieja.id is null or vieja.estado not in ('solicitada','confirmada') then
    raise exception 'Esa cita ya no está viva'
      using errcode = 'check_violation';
  end if;

  if vieja.estado = 'confirmada' and vieja.cuando is distinct from p_cuando
     and length(trim(coalesce(p_motivo, ''))) = 0 then
    raise exception 'Hace falta decir por qué se mueve la cita'
      using errcode = 'check_violation';
  end if;

  if p_cuando is null or p_cuando <= now() then
    raise exception 'Ese hueco ya pasó'
      using errcode = 'check_violation';
  end if;

  local  := p_cuando at time zone 'America/Caracas';
  hora_l := local::time;

  if exists (select 1 from public.cierres_citas where fecha = local::date) then
    raise exception 'Ese día el CIIP no atiende'
      using errcode = 'check_violation';
  end if;

  if exists (select 1 from public.horario_citas)
     and not exists (
       select 1 from public.horario_citas h
        where h.dia = extract(isodow from local)::int
          and hora_l >= h.desde and hora_l < h.hasta
     ) then
    raise exception 'Esa hora no está en el horario del CIIP'
      using errcode = 'check_violation';
  end if;

  -- Dos gestores confirmando a la vez la misma hora: el candado hace que el
  -- segundo espere al primero y vea su cita al comprobar.
  perform pg_advisory_xact_lock(hashtext('cita ' || p_cuando::text));
  if exists (
    select 1 from public.citas
     where cuando = p_cuando and id <> p_cita
       and estado in ('solicitada','confirmada')
  ) then
    raise exception 'Ese hueco se acaba de ocupar'
      using errcode = 'unique_violation';
  end if;

  update public.citas
     set estado = 'confirmada',
         cuando = p_cuando,
         lugar  = coalesce(nullif(trim(p_lugar), ''), lugar),
         motivo = coalesce(trim(p_motivo), ''),
         gestor = coalesce(gestor, auth.uid())
   where id = p_cita
  returning * into fila;

  return fila;
end
$con$;

revoke all on function public.confirma_cita(uuid, timestamptz, text, text) from public;
grant execute on function public.confirma_cita(uuid, timestamptz, text, text) to authenticated;


-- ── 7. UNA CONSULTA RESUELTA SE REABRE SI EL INVERSIONISTA ESCRIBE ───────
-- Era un callejón: lo que escribía en una resuelta no salía en ninguna
-- cola. Vuelve a la del equipo; en curso si ya la llevaba alguien, que es
-- quien sabe de qué va, y abierta si no.
create or replace function public.consulta_se_reabre()
returns trigger
language plpgsql
security definer
set search_path = public
as $con$
begin
  if not new.del_equipo then
    update public.consultas
       set estado = case when gestor is null then 'abierta' else 'en_curso' end
     where id = new.consulta and estado = 'resuelta';
  end if;
  return null;
end
$con$;

-- Desde el 5-10-2026 ya no: en una consulta resuelta no se puede escribir
-- (política «consulta_mensajes: escribir en mi consulta», en
-- supabase-consultas.sql) y reabrirla es cosa del equipo, con «Reabrir».
-- La función se queda, pero el disparador se quita.
drop trigger if exists consulta_mensajes_reabre on public.consulta_mensajes;


-- ── 8. EL EQUIPO ABRE UNA CONSULTA CON ALGUIEN ───────────────────────────
-- Lo que el gestor escribía en el hilo de una cita no le llegaba al
-- inversionista: desde el 8-9-2026 su lado de la cita no tiene hilo. En
-- vez de volver a ponérselo, el equipo le escribe por una consulta, que es
-- el sitio donde ya se conversa y que su buzón sí mira.
--
-- La firma de la consulta pone siempre como dueño a quien la abre. Aquí
-- se le avisa, con una marca que dura lo que la transacción, de que esta
-- la abre el equipo a nombre de otro.
create or replace function public.consulta_la_firma_la_base()
returns trigger
language plpgsql
security definer
set search_path = public
as $con$
begin
  if auth.uid() is not null then
    if not (coalesce(current_setting('ciip.consulta_para', true), '') = 'si'
            and public.es_gestor()) then
      new.inversionista := auth.uid();
    end if;
    new.estado      := 'abierta';
    new.gestor      := null;
    new.resuelto_en := null;
  end if;
  new.creado_en      := now();
  new.actualizado_en := now();
  return new;
end
$con$;

create or replace function public.abre_consulta_para(
  p_inversionista uuid,
  p_asunto        text,
  p_tipo          text default null
)
returns public.consultas
language plpgsql
security definer
set search_path = public
as $con$
declare
  fila public.consultas;
begin
  if auth.uid() is null or not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP abre consultas a nombre de otro'
      using errcode = 'insufficient_privilege';
  end if;

  perform set_config('ciip.consulta_para', 'si', true);
  insert into public.consultas (inversionista, asunto, tipo)
  values (p_inversionista, left(coalesce(trim(p_asunto), ''), 200), nullif(p_tipo, ''))
  returning * into fila;
  perform set_config('ciip.consulta_para', '', true);

  update public.consultas
     set estado = 'en_curso', gestor = auth.uid()
   where id = fila.id
  returning * into fila;

  return fila;
end
$con$;

revoke all on function public.abre_consulta_para(uuid, text, text) from public;
grant execute on function public.abre_consulta_para(uuid, text, text) to authenticated;
