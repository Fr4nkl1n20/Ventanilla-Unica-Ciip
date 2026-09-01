-- ═══════════════════════════════════════════════════════════════════════
--  UNA SOLA SOLICITUD VIVA POR TRÁMITE
--  Va DESPUÉS de supabase-tramites.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  El panel ya lo comprueba antes de enviar, y su propio comentario dice
--  lo que le falta:
--
--    «Es una comprobación del panel, no una cerradura. La de verdad sería
--     un índice único en la base, y esa es otra decisión.»
--
--  Esto es esa cerradura. La regla vivía sólo en el navegador, así que
--  cualquiera que llamara a la API de frente —o el propio panel con una
--  carrera muy justa entre dos pestañas— podía crear dos en marcha y la
--  base no decía nada. Es el mismo agujero que tenía la escalera de
--  estados: el panel decía la regla y la base no la sabía.
--
--  Y ya se sabe cómo acaba, porque pasó: aparecieron cuatro solicitudes
--  de la misma visa, y esas cuatro las recibe el CIIP y alguien tiene que
--  revisarlas una por una.
--
--  LO QUE **SÍ** SE PUEDE SEGUIR HACIENDO
--  ─────────────────────────────────────────────────────────────────────
--  Dos solicitudes del mismo trámite, mientras no estén vivas a la vez.
--  El índice es PARCIAL a propósito, y eso es toda la decisión:
--
--    · una RESUELTA no estorba. Hay trámites que se piden otra vez de
--      verdad —una solvencia caduca al año—, y bloquearlos para siempre
--      sería impedir el trámite normal, no el duplicado.
--    · una DEVUELTA tampoco. Volver a mandarla es exactamente lo que se
--      le está pidiendo al inversionista.
--    · un BORRADOR tampoco: todavía no ha pedido nada.
--
--  Lo único que se impide es que el CIIP reciba dos veces lo mismo sin
--  haber contestado a la primera.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. PRIMERO MIRAR SI YA HAY ALGUNO
-- ───────────────────────────────────────────────────────────────────────
-- Un CREATE UNIQUE INDEX sobre datos que ya incumplen la regla falla con
-- un mensaje que no dice cuáles son. Mejor mirarlo antes y decirlo, que
-- es lo que hay que arreglar a mano de todas formas.

do $viva$
declare
  cuantos int;
  ejemplo text;
begin
  select count(*), min(inversionista::text || ' / ' || tipo)
    into cuantos, ejemplo
  from (
    select inversionista, tipo
    from public.tramites
    where estado in ('enviado', 'en_revision', 'ante_el_ente')
    group by inversionista, tipo
    having count(*) > 1
  ) repetidos;

  if cuantos > 0 then
    raise exception
      'Hay % pares (persona, trámite) con más de una solicitud viva. El primero: %. Resuélvelos o descártalos antes de poner la cerradura.',
      cuantos, ejemplo;
  end if;
end
$viva$;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LA CERRADURA
-- ───────────────────────────────────────────────────────────────────────
-- Por (inversionista, tipo) y no sólo por tipo: dos personas distintas
-- pidiendo la misma visa a la vez es lo normal, no un duplicado.

create unique index if not exists tramites_una_viva
  on public.tramites (inversionista, tipo)
  where estado in ('enviado', 'en_revision', 'ante_el_ente');

comment on index public.tramites_una_viva is
  'Una sola solicitud en manos del CIIP por persona y trámite. Las resueltas y las devueltas no cuentan';


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Que está puesto:
--
--   select indexname from pg_indexes
--    where tablename = 'tramites' and indexname = 'tramites_una_viva';
--
-- 2) Que muerde. Con una solicitud tuya ya enviada, manda otra del mismo
--    trámite desde el panel: la base la rechaza aunque el aviso del
--    navegador no llegue a salir.
--
-- 3) Y que NO muerde donde no debe. Con una resuelta del año pasado,
--    pedir la del año siguiente tiene que entrar sin queja. Si no entra,
--    el índice se puso sin el WHERE y hay que rehacerlo.
--
--   select estado, count(*) from public.tramites
--    where tipo = 'solvencias' group by estado;
