-- ══════════════════════════════════════════════════════════════════════
--  LO DEL CIIP EN UN TRÁMITE, Y EL BLOQUEO ENTERO
--  Revisión de seguridad del 25 de septiembre de 2026, paso 2
-- ══════════════════════════════════════════════════════════════════════
--
--  QUÉ ESTABA ABIERTO
--
--  1. Un trámite tiene columnas que son del CIIP -el gestor, el banco, el
--     expediente del ente, las fechas- y la política de edición del
--     inversionista no las distinguía de las suyas. Con el borrador en la
--     mano, desde la consola:
--
--         sb.from('tramites').update({creado_en: '2020-01-01',
--           gestor: '<uuid>', banco: '<codigo>'}).eq('id', miId)
--
--     se colaba al principio de la cola (se ordena por creado_en), se
--     asignaba el gestor que quisiera o lo sacaba de «sin asignar», y
--     dejaba una fecha de envío falsa: registrar_evento_tramite() solo la
--     pone si está vacía. Al crear el trámite pasaba lo mismo, y además
--     podía colgarlo (viene_de) de la constitución de otra persona, con lo
--     que a esa persona ya no se le abría su protocolización.
--
--  2. El bloqueo de cuentas cortaba trámites, documentos y citas, pero no
--     el resto: una cuenta bloqueada seguía escribiendo en los hilos, las
--     consultas, su empresa, el pliego y el cubo de archivos.
--
--  QUÉ CAMBIA
--
--  · Cuando escribe el inversionista, las columnas del CIIP se quedan como
--    estaban (al crear: vacías, y creado_en la hora de la base). No da
--    error: las deja como estaban y sigue. Así el panel no cambia en nada
--    y la fecha de envío la sigue sellando registrar_evento_tramite().
--    El trigger se llama tramite_columnas_del_ciip para correr ANTES que
--    tramite_historial_update (Postgres los ordena por nombre): si fuera
--    después, borraría la fecha de envío que aquél acaba de poner.
--  · viene_de solo puede apuntar a un trámite de la misma persona.
--  · corta_si_bloqueado() en las ocho tablas que faltaban, y las políticas
--    del cubo piden además que la cuenta no esté bloqueada.
--
--  QUÉ NO SE TOCA
--  · perfiles: el panel llama a tocar_visto() al entrar, que escribe ahí,
--    y una cuenta bloqueada vería un error en cada carga. Lo que importa
--    de perfiles -el rol y el bloqueo- ya lo guardan sus triggers.
--  · Lo que hace el equipo, la puerta de servicio (auth.uid() nulo) y lo
--    que escriben las funciones security definer (los tramos que se abren
--    solos al resolver): ahí current_user no es 'authenticated'.
--
--  Va DESPUÉS de supabase-bloqueo.sql (corta_si_bloqueado) y de
--  supabase-papeles-sellados.sql (redefine sus políticas del cubo). Se
--  puede correr más de una vez.
-- ══════════════════════════════════════════════════════════════════════

do $comprueba$
begin
  if to_regprocedure('public.corta_si_bloqueado()') is null
     or to_regprocedure('public.esta_bloqueado()') is null then
    raise exception 'Falta el bloqueo: corre antes supabase-bloqueo.sql';
  end if;
  if to_regprocedure('public.papel_lo_decide_el_equipo()') is null then
    raise exception 'Falta supabase-papeles-sellados.sql: va antes que éste';
  end if;
end
$comprueba$;

-- Las columnas que añadieron otros archivos. Si alguna falta, el trigger
-- de abajo daría error en cada trámite.
alter table public.tramites add column if not exists banco text references public.bancos_aliados(codigo);
alter table public.tramites add column if not exists viene_de uuid references public.tramites(id) on delete set null;
alter table public.tramites add column if not exists expediente_ente text;


-- ── 1 · Las columnas del CIIP ─────────────────────────────────────────

create or replace function public.tramite_columnas_del_ciip()
returns trigger
language plpgsql
as $tyb$
begin
  if auth.uid() is null
     or current_user <> 'authenticated'
     or public.es_gestor() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.gestor          := null;
    new.banco           := null;
    new.expediente_ente := null;
    new.creado_en       := now();
    new.enviado_en      := null;
    new.resuelto_en     := null;
    if new.viene_de is not null and not exists (
         select 1 from public.tramites o
          where o.id = new.viene_de and o.inversionista = new.inversionista) then
      new.viene_de := null;
    end if;
    return new;
  end if;

  new.inversionista   := old.inversionista;
  new.tipo            := old.tipo;
  new.gestor          := old.gestor;
  new.banco           := old.banco;
  new.expediente_ente := old.expediente_ente;
  new.viene_de        := old.viene_de;
  new.creado_en       := old.creado_en;
  new.enviado_en      := old.enviado_en;
  new.resuelto_en     := old.resuelto_en;
  return new;
end
$tyb$;

drop trigger if exists tramite_columnas_del_ciip on public.tramites;
create trigger tramite_columnas_del_ciip
  before insert or update on public.tramites
  for each row execute function public.tramite_columnas_del_ciip();


-- ── 2 · El bloqueo, en todo lo que escribe el inversionista ───────────

do $tyb$
declare
  t text;
begin
  foreach t in array array['tramite_mensajes', 'cita_mensajes', 'consultas',
                           'consulta_mensajes', 'tramite_documentos', 'tramite_entes',
                           'empresas', 'pliego_aceptaciones'] loop
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
$tyb$;

-- El cubo: las tres de supabase-papeles-sellados.sql, con el bloqueo.
drop policy if exists "recaudos: subir a su carpeta" on storage.objects;
create policy "recaudos: subir a su carpeta" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'recaudos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.foldername(name))[2] is distinct from 'emitidos'
    and not public.esta_bloqueado()
  );

drop policy if exists "recaudos: reemplazar en su carpeta" on storage.objects;
create policy "recaudos: reemplazar en su carpeta" on storage.objects
  for update to authenticated
  using      (bucket_id = 'recaudos' and name = auth.uid()::text || '/perfil/foto'
              and not public.esta_bloqueado())
  with check (bucket_id = 'recaudos' and name = auth.uid()::text || '/perfil/foto'
              and not public.esta_bloqueado());

drop policy if exists "recaudos: borrar de su carpeta" on storage.objects;
create policy "recaudos: borrar de su carpeta" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'recaudos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.foldername(name))[2] is distinct from 'emitidos'
    and not exists (select 1 from public.documentos d
                     where d.archivo = storage.objects.name
                       and d.estado = 'validado')
    and not public.esta_bloqueado()
  );
