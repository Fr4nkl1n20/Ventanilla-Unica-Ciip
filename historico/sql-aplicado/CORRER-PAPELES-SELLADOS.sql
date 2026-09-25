-- SQL Editor de Supabase. Revisión de seguridad del 25-09-2026, paso 1:
-- los papeles sellados y el cubo. Se puede correr más de una vez.
--
-- Es el mismo texto que supabase-papeles-sellados.sql, con una mirada
-- antes y otra después. NO pegues TODO-EN-ORDEN.sql entero para esto:
-- lleva además los cambios de los pendientes de Frank, que van aparte.

-- 1. MIRAR ANTES. Si el agujero se usó, aquí se ve. Lo normal es que
--    las tres salgan vacías. Si alguna trae filas, APÚNTALAS antes de
--    seguir: el arreglo no borra nada, pero conviene saber qué había.

-- 1a. Papeles validados que nadie del equipo firmó y que no están en
--     emitidos/: o los validó el propio inversionista, o son de antes de
--     que el panel firmara las revisiones.
select d.id, d.tipo, d.archivo, d.creado_en, p.nombre_completo
  from public.documentos d
  left join public.perfiles p on p.id = d.inversionista
 where d.estado = 'validado'
   and d.revisado_por is null
   and split_part(d.archivo, '/', 2) <> 'emitidos'
 order by d.creado_en desc;

-- 1b. Papeles que solo emite el CIIP y que no están en emitidos/.
select d.id, d.tipo, d.archivo, d.estado, d.creado_en
  from public.documentos d
 where d.tipo in ('resolucion', 'planilla_reserva_nombre', 'planilla_aranceles',
                  'planilla_publicacion', 'planilla_locti')
   and split_part(d.archivo, '/', 2) <> 'emitidos';

-- 1c. Fichas que apuntan a un archivo de otra carpeta.
select d.id, d.inversionista, d.archivo
  from public.documentos d
 where d.archivo not like d.inversionista::text || '/%'
    or position('..' in d.archivo) > 0;


-- 2. EL ARREGLO.

do $comprueba$
begin
  if to_regprocedure('public.verificar_documento(text)') is null then
    raise exception 'Falta verificar_documento(): corre antes supabase-huellas.sql';
  end if;
  if to_regprocedure('public.es_gestor()') is null then
    raise exception 'Falta es_gestor(): corre antes supabase-tramites.sql';
  end if;
  if to_regclass('public.archivos_huerfanos') is null then
    raise exception 'Falta archivos_huerfanos: corre antes supabase-tramites.sql';
  end if;
end
$comprueba$;

-- La pone supabase-revision-papeles.sql. Se repite aquí porque el
-- trigger de abajo la escribe, y en una base sin ella cada papel que se
-- subiera daría error.
alter table public.documentos add column if not exists revisado_en timestamptz;


-- ── 1 · La ficha del papel ────────────────────────────────────────────

create or replace function public.papel_lo_decide_el_equipo()
returns trigger
language plpgsql
as $sellados$
declare
  del_equipo boolean;
  carpeta    text;
begin
  if auth.uid() is null then
    return new;   -- la puerta de servicio
  end if;

  del_equipo := public.es_gestor();

  -- La ruta, para todos, cuando es nueva o cambia: en la carpeta del
  -- dueño de la ficha y sin subir de nivel.
  if tg_op = 'INSERT' or new.archivo is distinct from old.archivo then
    if new.archivo not like new.inversionista::text || '/%'
       or position('..' in new.archivo) > 0 then
      raise exception 'El archivo tiene que estar en la carpeta de su dueño'
        using errcode = 'check_violation';
    end if;
    carpeta := split_part(new.archivo, '/', 2);
    if carpeta = 'emitidos' and not del_equipo then
      raise exception 'Esa carpeta es del equipo del CIIP'
        using errcode = 'check_violation';
    end if;
  end if;

  if del_equipo then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.estado <> 'cargado'
       or new.revisado_por is not null
       or new.revisado_en is not null
       or new.nota_revision <> '' then
      raise exception 'Un papel nuevo entra como cargado: lo revisa el equipo'
        using errcode = 'check_violation';
    end if;
    if new.tipo in ('resolucion', 'planilla_reserva_nombre', 'planilla_aranceles',
                    'planilla_publicacion', 'planilla_locti') then
      raise exception 'Ese papel lo emite el CIIP'
        using errcode = 'check_violation';
    end if;
    return new;
  end if;

  -- UPDATE: lo que es de la revisión se queda como estaba.
  if new.estado        is distinct from old.estado
     or new.revisado_por  is distinct from old.revisado_por
     or new.revisado_en   is distinct from old.revisado_en
     or new.nota_revision is distinct from old.nota_revision then
    raise exception 'La revisión de un papel la hace el equipo'
      using errcode = 'check_violation';
  end if;
  if new.tipo is distinct from old.tipo
     and new.tipo in ('resolucion', 'planilla_reserva_nombre', 'planilla_aranceles',
                      'planilla_publicacion', 'planilla_locti') then
    raise exception 'Ese papel lo emite el CIIP'
      using errcode = 'check_violation';
  end if;
  return new;
end
$sellados$;

drop trigger if exists documentos_lo_decide_el_equipo on public.documentos;
create trigger documentos_lo_decide_el_equipo
  before insert or update on public.documentos
  for each row execute function public.papel_lo_decide_el_equipo();

-- Y el que firma la revisión es quien la hace, cuando la hace: el panel
-- mandaba revisado_por y revisado_en desde el navegador, y un gestor
-- podía firmar a nombre de otro o con otra fecha.
create or replace function public.papel_firma_la_revision()
returns trigger
language plpgsql
as $sellados$
begin
  if auth.uid() is null then
    return new;
  end if;
  if new.estado is distinct from old.estado then
    new.revisado_por := auth.uid();
    new.revisado_en  := now();
  end if;
  return new;
end
$sellados$;

drop trigger if exists documentos_firma_la_revision on public.documentos;
create trigger documentos_firma_la_revision
  before update on public.documentos
  for each row execute function public.papel_firma_la_revision();

-- Lo que se anota como huérfano tiene que ser de la carpeta del dueño:
-- las fichas viejas, de antes de esta comprobación, podrían apuntar a
-- otra, y el barrendero borra con la clave de servidor.
create or replace function public.apuntar_el_huerfano()
returns trigger
language plpgsql
security definer
set search_path = public
as $sellados$
begin
  if old.archivo is null or old.archivo = ''
     or old.archivo not like old.inversionista::text || '/%'
     or position('..' in old.archivo) > 0 then
    return old;
  end if;

  insert into public.archivos_huerfanos (cubo, ruta, de_quien)
  values ('recaudos', old.archivo, old.inversionista)
  on conflict (cubo, ruta) do nothing;

  return old;
end
$sellados$;


-- ── 2 · El cubo ───────────────────────────────────────────────────────

drop policy if exists "recaudos: subir a su carpeta" on storage.objects;
create policy "recaudos: subir a su carpeta" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'recaudos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.foldername(name))[2] is distinct from 'emitidos'
  );

-- Reemplazar solo la foto: es el único upsert del panel. Todo lo demás
-- se sube con un nombre nuevo cada vez.
drop policy if exists "recaudos: reemplazar en su carpeta" on storage.objects;
create policy "recaudos: reemplazar en su carpeta" on storage.objects
  for update to authenticated
  using      (bucket_id = 'recaudos' and name = auth.uid()::text || '/perfil/foto')
  with check (bucket_id = 'recaudos' and name = auth.uid()::text || '/perfil/foto');

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
  );


-- ── 3 · La verificación ───────────────────────────────────────────────

create or replace function public.verificar_documento(huella_hex text)
returns table (
  consta       boolean,
  tipo         text,
  validado_el  timestamptz,
  vence_el     date,
  vigente      boolean
)
language sql
stable
security definer
set search_path = public
as $sellados$
  select
    true,
    coalesce(td.nombre, d.tipo),
    d.actualizado_en,
    d.vence_el,
    (d.vence_el is null or d.vence_el >= current_date)
  from public.documentos d
  left join public.tipos_documento td on td.codigo = d.tipo
  where d.huella = lower(trim(huella_hex))
    and d.estado = 'validado'
    and split_part(d.archivo, '/', 2) = 'emitidos'
  limit 1;
$sellados$;

comment on function public.verificar_documento(text) is
  'Dice si un documento que emitió el CIIP consta, sin revelar de quién es';

revoke all on function public.verificar_documento(text) from public;
grant execute on function public.verificar_documento(text) to anon, authenticated;


-- 3. COMPROBAR DESPUÉS. Tienen que salir los dos triggers y las tres
--    políticas del cubo con su texto nuevo.
select tgname from pg_trigger
 where tgrelid = 'public.documentos'::regclass
   and tgname in ('documentos_lo_decide_el_equipo', 'documentos_firma_la_revision');

select policyname, cmd, coalesce(qual, with_check) as condicion
  from pg_policies
 where schemaname = 'storage' and tablename = 'objects'
   and policyname like 'recaudos: %'
 order by policyname;
