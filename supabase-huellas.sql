-- ═══════════════════════════════════════════════════════════════════════
--  LA HUELLA DE CADA DOCUMENTO
--  Va DESPUÉS de supabase-tramites.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  Dos agujeros que se tapan con la misma columna.
--
--  EL PRIMERO, y el que lo hace urgente: el conector del RIF ya manda el
--  `sha256` de cada recaudo al organismo —está en `armaExpediente`, con
--  su comentario explicando que es lo que deja probar después que lo que
--  recibieron es lo que el inversionista subió—. Pero NADA lo produce. Se
--  manda vacío. Es una promesa escrita en el contrato que hoy no se
--  cumple, y no se nota hasta el día en que hay que probar algo.
--
--  EL SEGUNDO: un documento que emite un ente y entra en la bóveda no se
--  puede verificar. Si un banco o un registro quiere comprobar que el
--  papel que le enseñan salió de verdad de aquí, no hay forma. Con la
--  huella la hay, y sin enseñarle a nadie de quién es el documento.
--
--  QUÉ NO ES
--  ─────────────────────────────────────────────────────────────────────
--  No es una firma electrónica. Una firma dice QUIÉN lo firmó y tiene
--  valor legal; esto sólo dice que dos archivos son el mismo. La firma
--  con validez legal necesita a SUSCERTE, que además es el trámite c19 de
--  esta misma ventanilla. Esto es lo que sí se puede hacer sin depender
--  de nadie.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA COLUMNA
-- ───────────────────────────────────────────────────────────────────────
-- Nullable, y no `not null`, por dos razones que no se pueden rodear:
--
--   1. Los documentos que ya están subidos no la tienen. Ponerla
--      obligatoria haría fallar este archivo en cualquier base con datos.
--   2. La huella la calcula el NAVEGADOR, y crypto.subtle sólo existe en
--      contexto seguro. Con ABRIR-LOCAL.bat lo hay; con ABRIR-EN-RED.bat,
--      que sirve por IP y sin https, no. Exigirla dejaría el panel sin
--      poder subir nada desde la red de la oficina.
--
-- O sea: null significa "no se pudo calcular", no "no vale". Un documento
-- sin huella sigue sirviendo para todo menos para verificarse.

alter table public.documentos
  add column if not exists huella text;

comment on column public.documentos.huella is
  'SHA-256 del archivo en minúsculas. null = no se pudo calcular al subirlo';

-- 64 caracteres hexadecimales, o nada. Sin esto, cualquier cadena entra y
-- la verificación empieza a devolver resultados a preguntas que no son
-- huellas.
alter table public.documentos
  drop constraint if exists documentos_huella_valida;
alter table public.documentos
  add  constraint documentos_huella_valida
  check (huella is null or huella ~ '^[0-9a-f]{64}$');

-- Por donde busca la verificación. No es único a propósito: el mismo
-- archivo subido por dos personas distintas tiene la misma huella, y eso
-- es correcto —son el mismo documento—; impedirlo dejaría al segundo sin
-- poder subir su copia de un acta que comparten.
create index if not exists documentos_por_huella
  on public.documentos (huella)
  where huella is not null;


-- ───────────────────────────────────────────────────────────────────────
-- 2. VERIFICAR, SIN ENSEÑAR DE QUIÉN ES
-- ───────────────────────────────────────────────────────────────────────
-- Aquí está todo el cuidado de este archivo. Quien verifica —un banco, un
-- registro, el propio organismo— tiene el papel delante: ya sabe de quién
-- es. Lo que no puede es preguntar por una huella cualquiera y averiguar
-- a quién pertenece, porque entonces esto sería un buscador de personas
-- por documento.
--
-- Así que devuelve lo que hace falta para creerle al papel y NADA que
-- identifique a nadie: qué tipo de documento es, si el CIIP lo dio por
-- bueno, cuándo, y si sigue vigente. Ni nombre, ni correo, ni id, ni
-- cuántos hay iguales.
--
-- Y sólo lo VALIDADO. Un documento recién subido y sin revisar no es
-- verificable: decir que sí lo es sería avalar un papel que aquí no ha
-- mirado nadie.

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
as $huellas$
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
  -- Uno solo aunque haya varios iguales. Cuántas copias existen de un
  -- documento no es asunto de quien verifica, y decirlo sería contar algo
  -- de otras personas.
  limit 1;
$huellas$;

comment on function public.verificar_documento(text) is
  'Dice si un documento validado consta, sin revelar de quién es';

-- Abierta a cualquiera, incluso sin entrar. Es el punto: quien verifica
-- no es usuario de la ventanilla, es un tercero con un papel en la mano.
-- Una verificación que exija cuenta no la usa nadie.
revoke all on function public.verificar_documento(text) from public;
grant execute on function public.verificar_documento(text) to anon, authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA HUELLA NO SE REESCRIBE
-- ───────────────────────────────────────────────────────────────────────
-- Es lo único que hace que sirva de algo. Si el dueño de un documento
-- pudiera cambiarle la huella, podría hacer que un archivo cualquiera
-- pasara por uno validado: sube algo, espera a que se lo validen, y luego
-- le pone la huella de otro archivo distinto.
--
-- Se puede escribir una vez —de null a un valor, al subirlo— y ya no.
-- Cambiar el archivo es subir un documento nuevo, que es exactamente lo
-- que hace el botón de «cambiar» del panel.

create or replace function public.huella_de_una_vez()
returns trigger
language plpgsql
as $huellas$
begin
  if auth.uid() is null then
    return new;   -- la puerta de servicio, como en las demás tablas
  end if;

  if old.huella is not null and new.huella is distinct from old.huella then
    raise exception 'La huella de un documento no se cambia. Sube uno nuevo.'
      using errcode = 'check_violation';
  end if;

  return new;
end
$huellas$;

drop trigger if exists documentos_huella_fija on public.documentos;
create trigger documentos_huella_fija
  before update on public.documentos
  for each row execute function public.huella_de_una_vez();


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Cuántos documentos tienen huella y cuántos no. Los viejos no la
--    tienen y está bien; lo que no puede pasar es que los NUEVOS tampoco.
--
--   select count(*) filter (where huella is not null) as con,
--          count(*) filter (where huella is null)     as sin
--   from public.documentos;
--
-- 2) Verificar uno a mano, con la huella de un archivo validado:
--
--   select * from public.verificar_documento('...64 hex...');
--
--    Sin fila = no consta. Con fila = consta, y dice qué es y si vigente,
--    sin decir de quién.
--
-- 3) Y que una huella inventada no devuelve nada:
--
--   select count(*) from public.verificar_documento(repeat('a', 64));
