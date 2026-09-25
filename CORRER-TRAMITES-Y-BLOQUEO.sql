-- SQL Editor de Supabase. Revisión de seguridad del 25-09-2026, paso 2:
-- lo del CIIP en un trámite y el bloqueo entero. Se puede correr más de
-- una vez. Va DESPUÉS de CORRER-PAPELES-SELLADOS.sql (ya aplicado).
--
-- Es el mismo texto que supabase-tramites-y-bloqueo.sql, con una mirada
-- antes y otra después. NO pegues TODO-EN-ORDEN.sql entero para esto.

-- 1. MIRAR ANTES. Tiene que salir una fila con todo a 0 menos «tramites»
--    y «tiene_paso_1» (= 2). Si algún otro número no es 0, APÚNTALO y
--    avisa antes de seguir: es un trámite que alguien tocó por fuera.
select
  (select count(*) from public.tramites) as tramites,
  (select count(*) from pg_trigger where tgrelid = 'public.documentos'::regclass
      and tgname in ('documentos_lo_decide_el_equipo', 'documentos_firma_la_revision')) as tiene_paso_1,
  (select count(*) from public.tramites t where t.gestor is not null
      and not exists (select 1 from public.perfiles p where p.id = t.gestor
                       and p.rol in ('gestor', 'admin'))) as gestor_que_no_es_gestor,
  (select count(*) from public.tramites t where t.creado_en <
      (select min(e.creado_en) from public.tramite_eventos e where e.tramite = t.id)
      - interval '1 minute') as creado_en_antes_del_alta,
  (select count(*) from public.tramites t where t.enviado_en < t.creado_en) as enviado_antes_de_creado,
  (select count(*) from public.tramites t where t.enviado_en is not null
      and t.estado = 'borrador') as enviado_en_en_borrador,
  (select count(*) from public.tramites t where t.resuelto_en is not null
      and t.estado <> 'resuelto') as resuelto_en_sin_resolver,
  (select count(*) from public.tramites t join public.tramites o on o.id = t.viene_de
      where o.inversionista <> t.inversionista) as viene_de_ajeno;


-- 2. EL ARREGLO.

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


-- 3. COMPROBAR DESPUÉS.
-- 3a. El trigger de las columnas, y el corte del bloqueo en once tablas:
--     las tres de antes (citas, documentos, tramites) más las ocho nuevas.
--     perfiles sale aparte: ahí el bloqueo es otro trigger, el que guarda
--     que solo un admin bloquee.
select
  (select count(*) from pg_trigger where tgrelid = 'public.tramites'::regclass
      and tgname = 'tramite_columnas_del_ciip') as columnas_del_ciip,
  (select count(*) from pg_trigger where not tgisinternal
      and tgname like '%\_bloqueo' and tgrelid <> 'public.perfiles'::regclass) as tablas_con_bloqueo;

-- 3b. Las tres políticas del cubo, con «esta_bloqueado» en su texto.
select policyname, cmd, coalesce(qual, with_check) as condicion
  from pg_policies
 where schemaname = 'storage' and tablename = 'objects'
   and policyname like 'recaudos: %'
 order by policyname;
