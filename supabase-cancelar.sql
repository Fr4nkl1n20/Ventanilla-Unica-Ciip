-- ══════════════════════════════════════════════════════════════════════
--  CANCELAR UNA SOLICITUD, MIENTRAS NO HAYA SALIDO DEL CIIP
--  Se puede correr más de una vez.
-- ══════════════════════════════════════════════════════════════════════
--  Franklin Reyes, 25-9-2026: «necesito que el inversionista pueda cancelar
--  un trámite si el trámite aún no ha pasado al ente». Mientras el
--  expediente está en el CIIP -recibido, en revisión, devuelto- cancelarlo
--  no le cuesta nada a nadie. Una vez ante el organismo hay un número de
--  entrada fuera, y decir aquí «cancelada» no lo retiraría de allí.
--
--  El inversionista no escribe 'cancelado' a mano: su política de edición
--  no lo deja. Va por cancela_tramite(), que comprueba que el trámite es
--  suyo y que está donde puede cancelarse, y revienta si no tocó ninguna
--  fila. Un expediente cancelado no se descancela: la escalera no deja
--  volver. Y no cuenta como «vivo»: supabase-una-viva.sql solo mira
--  enviado, en_revision y ante_el_ente, así que se puede volver a pedir.
--
--  Vivía en CORRER-CANCELAR-UN-TRAMITE.sql (9f3386b); desde el mismo día
--  está aquí, que es de donde sale TODO-EN-ORDEN.sql. Va al final: redefine
--  tramites_solo_la_escalera(), que nace en supabase-tramites.sql.
-- ══════════════════════════════════════════════════════════════════════

alter table public.tramites drop constraint if exists tramites_estado_valido;
alter table public.tramites add constraint tramites_estado_valido
  check (estado in ('borrador', 'enviado', 'en_revision', 'devuelto',
                    'ante_el_ente', 'resuelto', 'cancelado'));

create or replace function public.tramites_solo_la_escalera()
returns trigger
language plpgsql
as $$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;

  if auth.uid() is null then
    return new;
  end if;

  if not (
       (old.estado = 'borrador'     and new.estado = 'enviado')
    or (old.estado = 'devuelto'     and new.estado = 'enviado')
    or (old.estado = 'enviado'      and new.estado in ('en_revision','devuelto'))
    or (old.estado = 'en_revision'  and new.estado in ('ante_el_ente','devuelto'))
    or (old.estado = 'ante_el_ente' and new.estado in ('resuelto','devuelto'))
    or (old.estado in ('borrador','enviado','en_revision','devuelto')
        and new.estado = 'cancelado')
  ) then
    raise exception 'Un trámite no pasa de "%" a "%"', old.estado, new.estado
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create or replace function public.cancela_tramite(p_tramite uuid)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  update public.tramites
     set estado = 'cancelado'
   where id = p_tramite
     and inversionista = auth.uid()
     and estado in ('borrador', 'enviado', 'en_revision', 'devuelto')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo cancelar';
  end if;

  return fila;
end $$;

revoke all on function public.cancela_tramite(uuid) from public;
-- Supabase le da EXECUTE a anon a cada función nueva: el revoke de PUBLIC
-- no lo quita. Sin sesión no haría nada, pero no tiene por qué poder llamarla.
revoke execute on function public.cancela_tramite(uuid) from anon;
grant execute on function public.cancela_tramite(uuid) to authenticated;
