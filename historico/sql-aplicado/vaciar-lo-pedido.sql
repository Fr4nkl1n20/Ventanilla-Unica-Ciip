-- ═══════════════════════════════════════════════════════════════════════
--  VACIAR LO PEDIDO: LAS SOLICITUDES, SUS PAPELES, LAS CITAS Y LAS CONSULTAS
--  Franklin Reyes, 18 de septiembre de 2026.
-- ═══════════════════════════════════════════════════════════════════════
--  ESTO BORRA Y NO SE DESHACE.
--
--  Deja la base sin ninguna solicitud, sin ningún papel en la bóveda, sin
--  citas y sin consultas. De dónde sale: los expedientes que hay ahora en
--  PRODUCCIÓN los hizo él mismo probando el panel, y quiere empezar de cero
--  antes de que entren inversionistas de verdad.
--
--  LO QUE **NO** TOCA, y es a propósito:
--    · las cuentas y los perfiles —quién eres y con qué rol— siguen ahí;
--    · el catálogo de trámites, los tipos de documento, los bancos, los
--      sectores, los activos, el horario de citas y los textos del panel;
--    · el pliego aceptado, que es un consentimiento y no una solicitud;
--    · «Mi empresa»: esos datos se teclean una vez y valen para todos los
--      trámites. Si también los quieres fuera, añade 'empresas' a la lista.
--  Después de correrlo se entra igual, con las mismas cuentas, a un panel
--  que no tiene nada pedido.
--
--  ═══ POR QUÉ ESTA VERSIÓN NO LLEVA begin; NI commit; ═════════════════
--  La de antes abría una transacción y esperaba a que escribieras `commit;`
--  en un segundo Run. ESO NO BORRABA NADA, y por eso el panel seguía
--  enseñando lo de siempre: el editor SQL de Supabase no guarda la sesión
--  de un Run al siguiente —cada Run va por una conexión nueva—, así que al
--  terminar el primero la transacción abierta se deshacía sola, y el
--  `commit;` de después llegaba a una sesión sin nada abierto («there is no
--  transaction in progress»). Se borraba y se devolvía en el mismo segundo.
--
--  Lo que sí es verdad: TODO LO QUE SE PEGA EN UN MISMO RUN VA JUNTO. Si
--  algo falla a mitad, no queda nada a medias. El freno de mano, entonces,
--  ya no es un commit a mano: es el ensayo de aquí abajo.
--
--  ═══ EL FRENO DE MANO: SE CORRE DOS VECES ════════════════════════════
--  Tal como está, `mirar_primero` vale TRUE y NO BORRA NADA: te enseña lo
--  que se llevaría, tabla por tabla, y de quién son las solicitudes. Si los
--  números son los que esperabas, cambia esa sola palabra a FALSE —una
--  línea, la que está marcada con ⇦— y pulsa Run otra vez.
--
--  ═══ SE CORRE TANTAS VECES COMO QUIERAS ══════════════════════════════
--  Es la escoba de después de cada ensayo, no un arreglo de una vez. Sobre
--  una base ya limpia borra cero y lo dice.
--
--  ═══ ESTO VALE PARA LAS DOS BASES, Y AHÍ ESTÁ EL PELIGRO ═════════════
--  Pruebas     ifhdzxetixhrzqixcfbe
--  Producción  fbxdwryppfctuwlnjjqr  ← la que hay detrás de
--                                      ventanilla-unica-2.vercel.app
--  El proyecto sale en la barra del navegador y arriba a la izquierda del
--  panel de Supabase. MÍRALO ANTES DE PULSAR RUN. En producción esto borra
--  las solicitudes de TODOS, no solo las tuyas: el día que haya un
--  inversionista de verdad, este archivo ya no se pega entero —se le pone
--  un `where inversionista = '<uuid>'` a cada delete, o no se corre—. El
--  ensayo te avisa: enseña de quién es cada solicitud antes de tocarlas.
--
--  ═══ Y LOS ARCHIVOS DEL CUBO ═════════════════════════════════════════
--  Borrar la ficha de un documento apunta su archivo en archivos_huerfanos
--  —lo hace el disparador apuntar_el_huerfano—, y de recogerlos del cubo se
--  encarga el barrendero, avisos/barrendero.js. Desde SQL no se puede
--  borrar un archivo del cubo: esto deja el trabajo apuntado y el
--  barrendero lo termina. Mientras no corra, los archivos siguen ocupando
--  sitio, pero ya no los alcanza nadie desde el panel: sin ficha no hay
--  dirección firmada que pedir.
--
--  ═══ POR QUÉ VA EN UN BLOQUE Y NO EN DELETES SUELTOS ═════════════════
--  Porque a una base le pueden faltar puntos de SQL —a la de pruebas le
--  faltan—, y un `delete from` de una tabla que todavía no existe tumba el
--  Run entero y no borra nada. El bloque mira tabla por tabla si está, y la
--  que no está se la salta diciéndolo en el resultado.
--
--  ═══ CÓMO SE LEE LO QUE SALE ═════════════════════════════════════════
--  El editor de Supabase solo enseña el resultado de la ÚLTIMA consulta, y
--  no enseña los `raise notice`. Por eso todo termina en una sola tabla:
--  qué había, cuántas se borraron y cuántas quedan.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. DÓNDE SE VA APUNTANDO LO QUE PASA
-- ───────────────────────────────────────────────────────────────────────
--  Temporal: vive lo que dura la conexión y no deja nada en la base.
drop table if exists pg_temp.escoba;
create temporary table escoba (
  orden    int,
  que      text,
  habia    bigint,
  borradas bigint,
  quedan   bigint
);


-- ───────────────────────────────────────────────────────────────────────
-- 2. LA ESCOBA
-- ───────────────────────────────────────────────────────────────────────
do $vaciar$
declare
  --  ⇦ ESTA ES LA LÍNEA. true = ensayo, no borra nada. false = borra.
  mirar_primero constant boolean := true;

  cual     text;
  i        int := 0;
  antes    bigint;
  cuantas  bigint;
  despues  bigint;
  lista    constant text[] := array[
    'tramites',    -- las solicitudes
    'documentos',  -- la bóveda entera: lo que subió él y lo que dejó el equipo
    'citas',       -- la agenda
    'consultas'    -- lo que se preguntó; sus mensajes se van por cascade
  ];
begin
  --  Lo que cuelga de cada solicitud se va SOLO, por cascade: su historial,
  --  su conversación, el enganche con sus papeles, sus órdenes de pago y
  --  los avisos que hablan de ella. Nombrarlos aquí sería inventar un orden
  --  que la base ya sabe.
  --
  --  El orden de los que sí se nombran se lee como lo que es: primero el
  --  expediente, luego los papeles que llevaba dentro.

  insert into escoba values (
    0,
    case when mirar_primero
         then '◆ ENSAYO — no se ha borrado nada. Cambia mirar_primero a false y pulsa Run otra vez.'
         else '◆ BORRADO DE VERDAD — ya está hecho y no se deshace.'
    end, null, null, null);

  --  De quién son las solicitudes, antes de tocarlas. Aquí es donde se ve a
  --  tiempo que en la base hay trabajo de alguien más.
  if to_regclass('public.tramites') is not null then
    insert into escoba (orden, que, habia)
    select 1,
           '    · de ' || coalesce(p.nombre_completo, '(sin nombre)'),
           count(*)
      from public.tramites t
      left join public.perfiles p on p.id = t.inversionista
     group by 2;
  end if;

  foreach cual in array lista loop
    i := i + 1;

    if to_regclass('public.' || cual) is null then
      insert into escoba values (10 + i, cual || ' — esa tabla no está en esta base, me la salto',
                                 null, null, null);
      continue;
    end if;

    execute format('select count(*) from public.%I', cual) into antes;

    if mirar_primero then
      insert into escoba values (10 + i, cual, antes, 0, antes);
      continue;
    end if;

    execute format('delete from public.%I', cual);
    get diagnostics cuantas = row_count;
    execute format('select count(*) from public.%I', cual) into despues;
    insert into escoba values (10 + i, cual, antes, cuantas, despues);
  end loop;

  --  Las cuentas, para que se vea que siguen enteras.
  select count(*) into antes from public.perfiles;
  insert into escoba values (90, 'cuentas (NO se tocan)', antes, 0, antes);

  --  Y los archivos que el barrendero tiene que recoger del cubo.
  if to_regclass('public.archivos_huerfanos') is not null then
    select count(*) into antes
      from public.archivos_huerfanos where estado = 'pendiente';
    insert into escoba values (91, 'archivos por barrer (los recoge el barrendero)',
                               null, null, antes);
  end if;
end
$vaciar$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. CÓMO QUEDÓ
-- ───────────────────────────────────────────────────────────────────────
select que, habia, borradas, quedan from escoba order by orden, que;
