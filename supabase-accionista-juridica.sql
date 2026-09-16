-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA ACCIONISTA JURÍDICA (c5)
--  Va DESPUÉS de supabase-tramites.sql: solo toca tipos_documento. Va al
--  final para no mover el número de nadie.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 16 de septiembre de 2026: en la constitución, la opción
--  «Accionista jurídica», para cuando uno de los accionistas de la empresa
--  a constituir es a su vez otra empresa. Si se marca, se piden de esa
--  empresa su documento constitutivo con la última acta de asamblea, y el
--  documento de identidad de sus accionistas.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: solo no se puede enviar una
--  constitución con la casilla marcada, porque sus dos papeles no caben
--  en documentos.tipo.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- LOS DOS PAPELES DE LA EMPRESA ACCIONISTA
-- ───────────────────────────────────────────────────────────────────────
--  Tipos PROPIOS y no los de la ficha de la ZODI (estatutos_accionista…):
--  aquellos son de una empresa extranjera -estatutos de la matriz, Good
--  Standing- y estos de cualquier empresa accionista. Con el mismo tipo, la
--  bóveda daría el uno por el otro. Ninguno caduca: acreditan un hecho de
--  una fecha, como el acta constitutiva.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('constitutivo_accionista',     'Documento constitutivo y última acta de asamblea de la empresa accionista', false),
  ('identidad_socios_accionista', 'Documento de identidad de los accionistas de la empresa accionista',        false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN: dos filas, las dos con vence = false.
-- ───────────────────────────────────────────────────────────────────────
--   select codigo, nombre, vence from public.tipos_documento
--   where codigo in ('constitutivo_accionista', 'identidad_socios_accionista');
