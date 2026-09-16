-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS PAPELES DE LA JUNTA DIRECTIVA (c5)
--  Va DESPUÉS de supabase-tramites.sql: toca documentos y tipos_documento.
--  No usa nada de los demás, así que va al final para no mover el número
--  de ninguno.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 16 de septiembre de 2026: en la constitución de la
--  compañía, por cada miembro de la junta directiva que se registre, su
--  cédula o pasaporte y su RIF. Y además la certificación de inventario por
--  contador público, si aplica.
--
--  POR QUÉ UNA COLUMNA NUEVA, Y NO SÓLO DOS TIPOS
--  ───────────────────────────────────────────────────────────────────────
--  La bóveda guardaba un papel por TIPO: para reutilizarlo, el panel pide
--  «el más reciente de este tipo» y se queda con uno. Con cinco miembros de
--  la junta serían cinco cédulas del mismo tipo, y el panel enseñaría la
--  última a los cinco -y en el siguiente trámite ofrecería reutilizar la de
--  otra persona-. `titular` dice de quién es cada una.
--
--  NO TOCA LOS PERMISOS
--  ───────────────────────────────────────────────────────────────────────
--  Las políticas de documentos dicen «el papel es tuyo» -inversionista =
--  auth.uid()- sin enumerar columnas: la nueva queda cubierta tal cual. Un
--  papel de un miembro de tu junta lo subes TÚ y es TUYO; lo que dice el
--  titular es de quién es la cara que sale en él.
--
--  LA CERTIFICACIÓN DE INVENTARIO
--  ───────────────────────────────────────────────────────────────────────
--  El comprobante del capital ya decía «depósito o inventario»: eran
--  alternativas en un solo recaudo. Se pidió aparte y OPCIONAL, y convive
--  con él. El panel la pide en la hoja de recaudos del c5.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE
--  ───────────────────────────────────────────────────────────────────────
--  Todo lo que ya existe sigue igual. Lo único que no se puede es enviar
--  una constitución con miembros de la junta -sus papeles llevan titular- o
--  con la certificación de inventario.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. DE QUIÉN ES CADA PAPEL
-- ───────────────────────────────────────────────────────────────────────
--  Null para todo lo que ya está guardado: sigue siendo de quien lo subió,
--  como hasta hoy. Sólo lo lleva un papel que es de OTRA persona -un
--  miembro de la junta directiva-, y entonces lleva su nombre.
alter table public.documentos add column if not exists titular text;

comment on column public.documentos.titular is
  'De quién es el papel cuando no es del dueño de la cuenta (un miembro de la junta directiva). Null: de quien lo subió.';

--  Un nombre en blanco no es un titular: sería un papel de nadie, y en el
--  visor del equipo saldría como si fuera tuyo.
do $junta$
begin
  if not exists (select 1 from pg_constraint where conname = 'documentos_titular_no_vacio') then
    alter table public.documentos add constraint documentos_titular_no_vacio
      check (titular is null or length(btrim(titular)) > 0);
  end if;
end
$junta$;

--  La bóveda busca «el más reciente de este tipo» para reutilizarlo. Con
--  titular, busca «de este tipo y de esta persona».
create index if not exists documentos_por_titular
  on public.documentos (inversionista, tipo, titular);


-- ───────────────────────────────────────────────────────────────────────
-- 2. LOS PAPELES NUEVOS
-- ───────────────────────────────────────────────────────────────────────
--  Ninguno caduca en el catálogo. La cédula y el RIF de un miembro van en
--  UN solo papel, y cada uno vence en su fecha: pedir una sola fecha de
--  vencimiento para los dos no diría nada cierto. La certificación de
--  inventario acredita un hecho de una fecha, como el comprobante del
--  capital.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('cedula_rif_junta',         'Cédula o pasaporte y RIF de un miembro de la junta directiva', false),
  ('certificacion_inventario', 'Certificación de inventario por contador público',            false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) La columna existe y admite vacío (lo guardado antes no tiene titular):
--
--   select column_name, is_nullable from information_schema.columns
--   where table_schema = 'public' and table_name = 'documentos'
--     and column_name = 'titular';
--
-- 2) Los dos papeles nuevos, ninguno caduca:
--
--   select codigo, nombre, vence from public.tipos_documento
--   where codigo in ('cedula_rif_junta', 'certificacion_inventario');
--
-- 3) Nada de lo guardado cambió de dueño: tiene que salir 0.
--
--   select count(*) from public.documentos where titular is not null;
