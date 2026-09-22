-- ═══════════════════════════════════════════════════════════════════════
--  LA VISA SE PARTE EN DOS: TR-N DE NEGOCIOS Y TR-I DE INVERSIONISTA
--  Franklin Reyes, 22 de septiembre de 2026.
-- ═══════════════════════════════════════════════════════════════════════
--  En el panel las dos se presentan en UNA casilla -«Visa para
--  Extranjeros»- y se elige dentro. Por debajo son DOS tramites, porque
--  piden recaudos distintos y dan cosas distintas: la TR-N es de
--  transeunte y dura un año; la TR-I dura tres, con multiples entradas y
--  sin limite de permanencia.
--
--  ═══ EL LIO DEL CODIGO, QUE ES LO QUE ARREGLA ESTE ARCHIVO ═══════════
--  La c1 nacio siendo la visa de inversionista, con el codigo
--  'visa_inversionista'. El 15 de septiembre paso a ser la de negocios
--  (TR-N) y se le cambio el NOMBRE, pero no el codigo: desde entonces la
--  base decia 'visa_inversionista' de una ficha que se llama «Visa de
--  negocios». Ahora que vuelve la TR-I de verdad, ese nombre lo necesita
--  ella.
--
--      ANTES                                    DESPUES
--      visa_inversionista → TR-N, c1            visa_negocios      → TR-N, c1
--                                               visa_inversionista → TR-I, c38
--
--  ═══ POR QUE NO ES UN UPDATE Y YA ═══════════════════════════════════
--  Cuatro tablas apuntan a tipos_tramite.codigo con clave foranea:
--  tramites.tipo, citas.tipo_tramite, consultas.tipo y aranceles.tramite.
--  Ninguna lleva ON UPDATE CASCADE, asi que cambiar el codigo con las
--  solicitudes colgando lo rechaza la base. Y tampoco vale insertar
--  primero la fila nueva: ref_panel es UNIQUE y 'c1' seguiria ocupado.
--
--  El camino que si funciona, y en este orden:
--    1. copiar la fila con el codigo nuevo y un ref_panel provisional,
--    2. mudar a ella lo que colgaba de la vieja,
--    3. borrar la vieja, que ya no tiene hijos,
--    4. devolverle el 'c1' de verdad,
--    5. y recien entonces dar de alta la TR-I con el nombre liberado.
--
--  La copia se hace con una tabla temporal y `select *`, no enumerando
--  columnas: tipos_tramite ha ido ganando columnas en otros archivos
--  -plazo_dias, emite, nivel- y una lista escrita a mano las perderia sin
--  decirlo.
--
--  ═══ SE PUEDE CORRER VARIAS VECES ═══════════════════════════════════
--  Todo va dentro de guardas: si ya esta hecho, no hace nada y lo dice.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL RECAUDO QUE SEPARA A LAS DOS
--    El Certificado de Inversionista, que se saca por la Ventanilla Unica
--    de Comercio Exterior. Tipo PROPIO y no el generico 'inversion': con
--    el mismo tipo la boveda daria el uno por el otro, que es el mismo
--    criterio que ya separa el certificado medico del pais de origen del
--    de aqui. No vence: acredita un hecho de una fecha dada, no una
--    situacion vigente.
-- ───────────────────────────────────────────────────────────────────────
insert into public.tipos_documento (codigo, nombre, vence) values
  ('certificado_inversionista', 'Certificado de Inversionista (VUCE)', false)
on conflict (codigo) do update
  set nombre = excluded.nombre,
      vence  = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LIBERAR EL NOMBRE Y DAR DE ALTA LA TR-I
-- ───────────────────────────────────────────────────────────────────────
do $visas$
declare
  mudadas  bigint := 0;
  cuantas  bigint;
begin
  -- ── 2.1  ¿Hay algo que hacer? ────────────────────────────────────────
  -- Si 'visa_inversionista' ya no ocupa el c1, este archivo ya corrio.
  if not exists (select 1 from public.tipos_tramite
                  where codigo = 'visa_inversionista' and ref_panel = 'c1') then
    raise notice 'El codigo ya estaba liberado: no hay nada que mudar.';
  else
    -- ── 2.2  La copia, con TODAS sus columnas ──────────────────────────
    drop table if exists pg_temp.visa_vieja;
    create temporary table visa_vieja as
      select * from public.tipos_tramite where codigo = 'visa_inversionista';
    update visa_vieja set codigo = 'visa_negocios', ref_panel = 'c1-provisional';
    insert into public.tipos_tramite select * from visa_vieja;

    -- ── 2.3  Lo que colgaba de la vieja, a la nueva ────────────────────
    -- Cada tabla se mira antes: en una base recien creada puede que
    -- todavia no existan, y el archivo tiene que correr igual.
    if to_regclass('public.tramites') is not null then
      update public.tramites set tipo = 'visa_negocios'
       where tipo = 'visa_inversionista';
      get diagnostics cuantas = row_count;  mudadas := mudadas + cuantas;
    end if;

    if to_regclass('public.citas') is not null then
      update public.citas set tipo_tramite = 'visa_negocios'
       where tipo_tramite = 'visa_inversionista';
      get diagnostics cuantas = row_count;  mudadas := mudadas + cuantas;
    end if;

    if to_regclass('public.consultas') is not null then
      update public.consultas set tipo = 'visa_negocios'
       where tipo = 'visa_inversionista';
      get diagnostics cuantas = row_count;  mudadas := mudadas + cuantas;
    end if;

    if to_regclass('public.aranceles') is not null then
      update public.aranceles set tramite = 'visa_negocios'
       where tramite = 'visa_inversionista';
      get diagnostics cuantas = row_count;  mudadas := mudadas + cuantas;
    end if;

    -- ── 2.4  Fuera la vieja, que ya no tiene a nadie colgando ──────────
    delete from public.tipos_tramite where codigo = 'visa_inversionista';

    -- ── 2.5  Y el c1 de verdad para la TR-N ────────────────────────────
    update public.tipos_tramite set ref_panel = 'c1'
     where codigo = 'visa_negocios';

    raise notice 'Codigo liberado. Filas mudadas a visa_negocios: %', mudadas;
  end if;

  -- ── 2.6  La TR-I, ya con su nombre ───────────────────────────────────
  -- Nace ENCENDIDA, y no apagada como nacieron otras. La diferencia es que
  -- esta no tiene casilla propia en la portada: se llega a ella desde la
  -- guia de la visa, y apagada NO SE PUEDE ABRIR. El panel saca del arbol
  -- las tarjetas de lo que esta apagado, asi que pulsar «Ver tramite» en la
  -- guia devolvia a la portada; y aunque no la sacara, sin 'activo' la
  -- ficha enseña la escalera de adorno en vez del formulario.
  --
  -- El 'activo' se pone tambien al actualizar, que es como hacen los demas
  -- archivos del catalogo -supabase-zodi.sql enciende el c34,
  -- supabase-parafiscales apaga el c35-: aqui el SQL manda sobre el estado.
  insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
    ('visa_inversionista', 'c38', 'Visa de inversionista (TR-I)', 'MPPRE', 1, true)
  on conflict (codigo) do update
    set ref_panel = excluded.ref_panel,
        nombre    = excluded.nombre,
        ente      = excluded.ente,
        fase      = excluded.fase,
        activo    = excluded.activo;
end
$visas$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. SU PLAZO
--    Los treinta dias son los que el catalogo del CIIP daba a la visa
--    cuando la c1 ERA la TR-I, asi que vuelven a estar donde nacieron.
--    Se pone aparte y con guarda porque la columna la crea
--    supabase-plazos.sql, que puede no haber corrido todavia.
-- ───────────────────────────────────────────────────────────────────────
do $plazo$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public'
                and table_name   = 'tipos_tramite'
                and column_name  = 'plazo_dias') then
    update public.tipos_tramite set plazo_dias = 30
     where codigo = 'visa_inversionista' and plazo_dias is null;
  end if;
end
$plazo$;


-- ───────────────────────────────────────────────────────────────────────
-- 4. COMO QUEDO
--    Lo esperado: dos filas, la TR-N en c1 y la TR-I en c38, y ninguna
--    solicitud con el codigo viejo.
-- ───────────────────────────────────────────────────────────────────────
select codigo, ref_panel, nombre, ente, fase, activo
  from public.tipos_tramite
 where codigo in ('visa_negocios', 'visa_inversionista')
 order by ref_panel;
