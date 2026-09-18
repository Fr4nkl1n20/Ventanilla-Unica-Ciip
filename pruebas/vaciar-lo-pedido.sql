-- ═══════════════════════════════════════════════════════════════════════
--  VACIAR LO PEDIDO: LAS SOLICITUDES Y SUS RECAUDOS
--  Franklin Reyes, 18 de septiembre de 2026.
-- ═══════════════════════════════════════════════════════════════════════
--  ESTO BORRA Y NO SE DESHACE.
--
--  Deja la base sin ninguna solicitud y sin ningún papel en la bóveda. De
--  dónde sale: los expedientes que hay ahora en PRODUCCIÓN los hizo él
--  mismo probando el panel, y quiere empezar de cero antes de que entren
--  inversionistas de verdad (Franklin Reyes, 18-9-2026).
--
--  LO QUE **NO** TOCA, y es a propósito:
--    · las cuentas y los perfiles —quién eres y con qué rol— siguen ahí;
--    · el catálogo de trámites, los tipos de documento, los bancos, los
--      sectores, los activos, el horario de citas y los textos del panel;
--    · el pliego aceptado, que es un consentimiento y no una solicitud.
--  Después de correrlo se entra igual, con las mismas cuentas, a un panel
--  que no tiene nada pedido.
--
--  ═══ SE CORRE TANTAS VECES COMO QUIERAS ═════════════════════════════
--  Es la escoba de después de cada ensayo, no un arreglo de una vez: se
--  guarda y se vuelve a pegar el día que la base se haya llenado otra vez
--  de pruebas. Con la base ya limpia no rompe nada —borra cero y lo dice—,
--  y como las cuentas no se tocan, en cuanto termina puedes entrar y
--  volver a pedir un trámite desde el principio.
--
--  ═══ ESTO VALE PARA LAS DOS BASES, Y AHÍ ESTÁ EL PELIGRO ═════════════
--  Pruebas     ifhdzxetixhrzqixcfbe
--  Producción  fbxdwryppfctuwlnjjqr
--  El proyecto sale en la barra del navegador y arriba a la izquierda del
--  panel de Supabase. MÍRALO ANTES DE PULSAR RUN. En producción esto borra
--  las solicitudes de TODOS, no solo las tuyas: el día que haya un
--  inversionista de verdad, este archivo ya no se pega entero —se le pone
--  un `where inversionista = '<uuid>'` a cada delete, o no se corre—.
--
--  ═══ CÓMO SE CORRE ═══════════════════════════════════════════════════
--  Se pega ENTERO y se pulsa Run. Va dentro de una transacción abierta que
--  NO se cierra sola: al terminar verás lo que había, cuántas borró de cada
--  tabla y lo que queda, y nada estará guardado todavía. Entonces, en el
--  mismo editor y sin cerrar la pestaña, escribe una de las dos y Run:
--        commit;     lo guarda
--        rollback;   deja la base como estaba
--  Hasta entonces, lo borrado se puede devolver.
--
--  ═══ Y LOS ARCHIVOS DEL CUBO ═════════════════════════════════════════
--  Borrar la ficha de un documento apunta su archivo en archivos_huerfanos
--  —lo hace el disparador apuntar_el_huerfano—, y de recogerlos del cubo se
--  encarga el barrendero, avisos/barrendero.js, que es quien habla con la
--  API de Storage. Desde SQL no se puede borrar un archivo del cubo: esto
--  deja el trabajo apuntado y el barrendero lo termina. Mientras no corra,
--  los archivos siguen ocupando sitio en el cubo, pero ya no los alcanza
--  nadie desde el panel: sin ficha no hay dirección firmada que pedir.
--
--  ═══ POR QUÉ VA EN UN BLOQUE Y NO EN DELETES SUELTOS ═════════════════
--  Porque a una base le pueden faltar puntos de SQL —a la de pruebas le
--  faltan—, y un `delete from` de una tabla que todavía no existe tumba el
--  archivo entero y no borra nada. El bloque mira tabla por tabla si está,
--  y la que no está se la salta diciendo que se la saltó.
-- ═══════════════════════════════════════════════════════════════════════

begin;

-- ───────────────────────────────────────────────────────────────────────
-- 1. LO QUE HAY AHORA MISMO
-- ───────────────────────────────────────────────────────────────────────
--  Se mira antes de tocar nada. Si estos números no son los que esperabas
--  —más solicitudes de las que hiciste, o cuentas que no reconoces—
--  escribe rollback; y sal de aquí.
select 'solicitudes'            as que, count(*) as cuantas from public.tramites
union all select 'papeles en la bóveda',  count(*) from public.documentos
union all select 'cuentas (NO se tocan)', count(*) from public.perfiles
order by 1;

--  Y de quién son, por si alguna no es tuya. Aquí es donde se ve a tiempo
--  que en la base hay trabajo de alguien más.
select coalesce(p.nombre_completo, '(sin nombre)') as de_quien,
       count(*) as solicitudes
  from public.tramites t
  left join public.perfiles p on p.id = t.inversionista
 group by 1 order by 2 desc;


-- ───────────────────────────────────────────────────────────────────────
-- 2. BORRAR, EN ESTE ORDEN
-- ───────────────────────────────────────────────────────────────────────
--  Lo que cuelga de cada solicitud se va SOLO, por cascade: su historial,
--  su conversación, el enganche con sus papeles, sus órdenes de pago y los
--  avisos que hablan de ella. Nombrarlos aquí sería inventar un orden que
--  la base ya sabe.
--
--  El orden de los dos que sí se nombran se lee como lo que es: primero el
--  expediente, luego los papeles que llevaba dentro.
do $vaciar$
declare
  cual    text;
  cuantas bigint;
  lista   constant text[] := array[
    'tramites',    -- las solicitudes
    'documentos',  -- la bóveda entera: lo que subió él y lo que dejó el equipo
    --  Y la agenda y lo que se preguntó. Entraron el 18-9-2026, cuando en
    --  la barra del equipo quedaban «Consultas y citas 2» y «Documentos
    --  por revisar 1» después de vaciar lo demás: eran ensayos suyos, y
    --  una bandeja que dice 2 sobre cosas que ya no existen manda a mirar
    --  algo que no está. Sus mensajes se van por cascade.
    'citas',
    'consultas'
    --  Lo que NO entra de fábrica: 'empresas'. Los datos de «Mi empresa»
    --  se teclean una vez y valen para todos los trámites; si también los
    --  quieres fuera, añádelo aquí.
  ];
begin
  foreach cual in array lista loop
    if to_regclass('public.' || cual) is null then
      raise notice '  %: esa tabla no está en esta base, me la salto', cual;
      continue;
    end if;
    execute format('delete from public.%I', cual);
    get diagnostics cuantas = row_count;
    raise notice '  %: % borradas', cual, cuantas;
  end loop;
end
$vaciar$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. CÓMO QUEDÓ
-- ───────────────────────────────────────────────────────────────────────
select 'solicitudes'            as que, count(*) as quedan from public.tramites
union all select 'papeles en la bóveda',  count(*) from public.documentos
union all select 'cuentas (NO se tocan)', count(*) from public.perfiles
order by 1;

--  Y los archivos que el barrendero tiene que recoger del cubo: tantos
--  como papeles había.
select count(*) as archivos_por_barrer
  from public.archivos_huerfanos where estado = 'pendiente';

--  Si es lo que esperabas:
--        commit;
--  Y si no:
--        rollback;
