-- ══════════════════════════════════════════════════════════════════════
--  LOS PAPELES, SELLADOS
--  Lo que encontró la revisión de seguridad del 25 de septiembre de 2026
-- ══════════════════════════════════════════════════════════════════════
--
--  QUÉ ESTABA ABIERTO
--
--  1. Un inversionista podía darse de alta un papel YA VALIDADO.
--     La política "documentos: subir los propios" solo miraba que fuera
--     suyo, no con qué estado nacía. Con la consola del navegador bastaba:
--
--         sb.from('documentos').insert({inversionista: yo, tipo: 'resolucion',
--           archivo: yo + '/x.pdf', estado: 'validado', huella: <sha256>})
--
--     y verificar_documento(), que contesta a cualquiera sin entrar,
--     respondía «consta» para un PDF inventado. Las políticas del equipo
--     exigen estado = 'validado' dando por hecho que el inversionista no
--     podía ponerlo. Podía.
--
--  2. Validado el papel, el archivo seguía siendo suyo para cambiarlo.
--     Las políticas del cubo le dejaban reemplazar y borrar TODO lo que
--     hubiera en su carpeta, y lo que emite el CIIP vive dentro de esa
--     carpeta, en {uid}/emitidos/. La ficha decía «validado» y el archivo
--     ya era otro.
--
--  3. La ruta del archivo no se comprobaba. Una ficha podía apuntar a la
--     carpeta de otra persona; al borrarla, apuntar_el_huerfano() la
--     anotaba y el barrendero, con la clave de servidor, borraba el
--     archivo ajeno.
--
--  QUÉ CAMBIA
--
--  · Quien no es del equipo no decide el estado de un papel, ni quién lo
--    revisó, ni cuándo, ni la nota. Nace 'cargado' y así sigue hasta que
--    lo toque el equipo.
--  · Los tipos que solo emite el CIIP (la resolución y las planillas para
--    pagar) no los puede crear el inversionista.
--  · La ruta tiene que estar en la carpeta del dueño de la ficha, sin
--    «..», y la subcarpeta emitidos/ es solo del equipo.
--  · En el cubo, emitidos/ es de solo lectura para el inversionista; lo
--    validado no se reemplaza ni se borra; y reemplazar (upsert) solo vale
--    para la foto de perfil, que es lo único que el panel sobrescribe.
--  · verificar_documento() solo responde por lo que dejó el equipo en
--    emitidos/. La huella de un recaudo la calcula el navegador de quien
--    lo sube y la base nunca comprueba que corresponda al archivo: podía
--    subir A con la huella de B, que el gestor validara A, y que desde
--    entonces B «constara». Lo que verifica un banco es lo que emitió el
--    ente, y eso lo sube el equipo.
--
--  LO QUE NO CAMBIA PARA EL PANEL
--  Nada de lo que hace el panel choca con esto: sube() no manda estado,
--  entrega() lo manda como gestor, la foto usa {uid}/perfil/foto y
--  borraDeVerdad() solo borra papeles no validados. El lector de
--  documentos sube a {uid}/lector/ y lo borra: sigue pudiendo.
--
--  La puerta de servicio (auth.uid() nulo: SQL Editor, clave de
--  servidor) sigue abierta, como en las demás tablas.
--
--  Va DESPUÉS de supabase-huellas.sql (redefine verificar_documento) y
--  de supabase-emision.sql (la carpeta emitidos/). Se puede correr más
--  de una vez.
-- ══════════════════════════════════════════════════════════════════════

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
