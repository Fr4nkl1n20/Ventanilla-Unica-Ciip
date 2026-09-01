-- ═══════════════════════════════════════════════════════════════════════
--  CUÁNTO DEBERÍA TARDAR CADA TRÁMITE
--  Va DESPUÉS de supabase-tramites.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  El panel ya enseña las dos mitades del dato, una al lado de la otra, y
--  no las junta nunca:
--
--    · la tarjeta dice «Estimado: 2–3 semanas»
--    · el reloj dice «lleva 40 días esperando»
--
--  La resta la tiene que hacer la persona. Y esa resta es la mitad de por
--  qué alguien abre el panel: no «en qué va», sino «¿esto va tarde?».
--
--  De dónde salen los números: de la propia tarjeta, no de ningún sitio
--  nuevo. Aquí no se inventa un plazo legal —eso sale en Gaceta y lo sabe
--  el CIIP—: se pasa a número lo que el panel ya venía prometiendo en
--  seis idiomas.
--
--  SE TOMA EL TOPE, NO EL SUELO
--  ─────────────────────────────────────────────────────────────────────
--  De «2–3 semanas» se guarda 21 días, no 14. Avisar al llegar al suelo
--  del estimado sería avisar de casi todo casi siempre, y un aviso que
--  salta siempre se aprende a ignorar. Con el tope, que salte significa
--  algo.
--
--  OCHO SIN PLAZO, Y ESTÁ BIEN
--  ─────────────────────────────────────────────────────────────────────
--  Son los que no prometen ninguno: «Se pide en el consulado»,
--  «Disponible cuando quieras», «Se activan al operar». Un trámite sin
--  `plazo_dias` no se marca nunca, que es lo correcto: no se puede llegar
--  tarde a algo que no tenía hora.
--
--  Y DESDE CUÁNDO SE CUENTA
--  ─────────────────────────────────────────────────────────────────────
--  Eso NO se decide aquí, se decide en el panel, pero conviene dejarlo
--  escrito: desde que lo enviaste, no desde que empezaste el borrador. Un
--  borrador parado en tu bandeja no es la administración tardando. Y un
--  trámite devuelto tampoco cuenta: ahí la pelota la tienes tú.
-- ═══════════════════════════════════════════════════════════════════════


alter table public.tipos_tramite
  add column if not exists plazo_dias smallint;

comment on column public.tipos_tramite.plazo_dias is
  'Tope del estimado que promete la tarjeta, en días. null = no promete ninguno';

alter table public.tipos_tramite
  drop constraint if exists tipos_tramite_plazo_valido;
alter table public.tipos_tramite
  add  constraint tipos_tramite_plazo_valido
  check (plazo_dias is null or plazo_dias > 0);


-- ───────────────────────────────────────────────────────────────────────
-- LOS VEINTITRÉS QUE PROMETEN UN PLAZO
-- ───────────────────────────────────────────────────────────────────────
-- Sacados de lo que dice cada tarjeta hoy, en español, tomando el tope
-- del rango. El comentario de cada línea lleva el texto del que salió,
-- para poder comprobarlo sin abrir el panel.
--
-- Si mañana el CIIP tiene los plazos legales de verdad, se cambian estos
-- números y el panel deja de estimar y empieza a decir la ley. La forma
-- no cambia.

update public.tipos_tramite set plazo_dias =  28 where codigo = 'licencia_conducir';                 -- c4  Estimado: 3–4 semanas
update public.tipos_tramite set plazo_dias =  21 where codigo = 'constitucion';                      -- c5  Estimado: 2–3 semanas
update public.tipos_tramite set plazo_dias =  14 where codigo = 'cuenta_bancaria';                   -- c7  Estimado: 1–2 semanas
update public.tipos_tramite set plazo_dias = 240 where codigo = 'marca';                             -- c8  Estimado: 4–8 meses
update public.tipos_tramite set plazo_dias =  28 where codigo = 'registros_laborales';               -- c9  Estimado: 2–4 semanas
update public.tipos_tramite set plazo_dias =  42 where codigo = 'licencia_municipal';                -- c10  Estimado: 3–6 semanas
update public.tipos_tramite set plazo_dias =  90 where codigo = 'permiso_sanitario';                 -- c12  Estimado: 1–3 meses
update public.tipos_tramite set plazo_dias =  42 where codigo = 'antecedentes_penales';              -- c16  Estimado: 3–6 semanas
update public.tipos_tramite set plazo_dias =  28 where codigo = 'apostilla_documentos';              -- c17  Estimado: 2–4 semanas
update public.tipos_tramite set plazo_dias =  14 where codigo = 'constancia_domicilio';              -- c18  Estimado: 1–2 semanas
update public.tipos_tramite set plazo_dias =  21 where codigo = 'firma_electronica';                 -- c19  Estimado: 2–3 semanas
update public.tipos_tramite set plazo_dias =  70 where codigo = 'visa_dependientes';                 -- c20  Estimado: 6–10 semanas
update public.tipos_tramite set plazo_dias =   7 where codigo = 'cert_medico';                       -- c21  Estimado: 1 semana
update public.tipos_tramite set plazo_dias =  42 where codigo = 'protocolizacion_acta';              -- c22  Estimado: 2–6 semanas
update public.tipos_tramite set plazo_dias =  14 where codigo = 'publicacion_acta';                  -- c23  Estimado: 1–2 semanas
update public.tipos_tramite set plazo_dias =  28 where codigo = 'libros_contables';                  -- c24  Estimado: 2–4 semanas
update public.tipos_tramite set plazo_dias =  21 where codigo = 'faov_banavih';                      -- c25  Estimado: 2–3 semanas
update public.tipos_tramite set plazo_dias =  21 where codigo = 'inces';                             -- c26  Estimado: 2–3 semanas
update public.tipos_tramite set plazo_dias =  28 where codigo = 'rnet';                              -- c27  Estimado: 3–4 semanas
update public.tipos_tramite set plazo_dias =  60 where codigo = 'conformidad_uso';                   -- c28  Estimado: 1–2 meses
update public.tipos_tramite set plazo_dias =  42 where codigo = 'permiso_bomberos';                  -- c29  Estimado: 3–6 semanas
update public.tipos_tramite set plazo_dias = 180 where codigo = 'permiso_ambiental';                 -- c30  Estimado: 2–6 meses
update public.tipos_tramite set plazo_dias = 120 where codigo = 'registro_inversion';                -- c31  Estimado: 2–4 meses

-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Veintitrés con plazo y ocho sin él:
--
--   select count(*) filter (where plazo_dias is not null) as con,
--          count(*) filter (where plazo_dias is null)     as sin
--   from public.tipos_tramite;
--
-- 2) Y lo que de verdad se quiere ver: qué está tardando más de lo que se
--    prometió. Esto es la consulta que el panel hace en pantalla, escrita
--    aquí para poder mirarla desde el SQL Editor.
--
--   select t.id, t.tipo, tt.plazo_dias,
--          (current_date - t.enviado_en::date) as lleva
--   from public.tramites t
--   join public.tipos_tramite tt on tt.codigo = t.tipo
--   where t.estado in ('enviado','en_revision','ante_el_ente')
--     and tt.plazo_dias is not null
--     and t.enviado_en is not null
--     and (current_date - t.enviado_en::date) > tt.plazo_dias
--   order by lleva desc;
--
--    Fíjate en los tres estados: un borrador o un devuelto NO salen, y no
--    es un olvido. Ahí la pelota la tiene el inversionista, y contar ese
--    tiempo como retraso del organismo sería echarle la culpa al de
--    enfrente de lo que uno no ha hecho.
