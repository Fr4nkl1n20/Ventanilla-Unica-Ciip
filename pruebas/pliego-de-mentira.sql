-- ══════════════════════════════════════════════════════════════════════
--  UN PLIEGO DE MENTIRA, PARA VER LA PANTALLA
-- ══════════════════════════════════════════════════════════════════════
--  ESTO NO ES EL PLIEGO Y NO PUEDE LLEGAR A LA BASE REAL.
--
--  El texto de abajo lo escribió quien programó la pantalla, no un
--  abogado, y está lleno de frases de relleno a propósito para que no se
--  confunda con un documento de verdad. Su único trabajo es hacer que la
--  puerta se abra y que la vista tenga algo que enseñar.
--
--  DÓNDE SE EJECUTA: en el proyecto de PRUEBAS
--  (ifhdzxetixhrzqixcfbe), que es el que usa el panel cuando se abre
--  desde localhost. En la base real esto obligaría a todas las cuentas
--  a aceptar un texto que nadie ha aprobado.
--
--  El pliego de verdad se publica con la plantilla de la sección 5 de
--  supabase-pliego.sql, con el texto de PLIEGO-BORRADOR.md ya corregido
--  por el abogado del CIIP.
--
--  Al final del archivo está cómo deshacerlo.
-- ══════════════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════════════════════════════
--  ANTES QUE NADA: LA MAQUINARIA TIENE QUE ESTAR PUESTA
-- ══════════════════════════════════════════════════════════════════════
--  Si esto falla con
--
--    ERROR: 42P01: relation "public.pliegos" does not exist
--
--  no es un fallo del archivo: es que en este proyecto todavía no se ha
--  ejecutado supabase-pliego.sql. Primero se pone la maquinaria y después
--  se publica el pliego; este archivo es solo lo segundo.
--
--  Para saber qué falta, correr esto y mirar las cinco columnas:
--
--    select
--      to_regclass('public.perfiles')            is not null as tiene_perfiles,
--      to_regproc('public.es_gestor()')          is not null as tiene_es_gestor,
--      to_regproc('public.es_admin()')           is not null as tiene_es_admin,
--      to_regclass('public.pliegos')             is not null as tiene_pliegos,
--      to_regclass('public.pliego_aceptaciones') is not null as tiene_aceptaciones;
--
--  · Si es_gestor y es_admin salen true: basta con pegar
--    supabase-pliego.sql (388 líneas). El pliego se apoya en esas dos.
--
--  · Si alguna sale false: pegar TODO-EN-ORDEN.sql, que trae los 23
--    archivos en su orden y ya incluye el pliego. Sus 24 tablas son
--    'create table if not exists' y sus políticas van con 'drop policy
--    if exists', así que se puede correr sobre un proyecto a medias sin
--    deshacer lo que ya estuviera.
--
--  Y después, volver aquí.
-- ══════════════════════════════════════════════════════════════════════
--  Y SI FALLA CON ESTO OTRO:
--
--    ERROR: 23505: duplicate key value violates unique constraint
--    "pliegos_pkey"  DETAIL: Key (version)=(1) already exists.
--
--  entonces ya está publicado y no hay nada que hacer: el insert de abajo
--  ya entró en una pasada anterior. Recarga el panel y la puerta sale.
--  Para verlo desde la base:
--
--    select version, titulo, vigente, publicado_en from public.pliegos;
--
--  OJO con pliego_pendiente() desde el editor SQL: devuelve null SIEMPRE,
--  y no porque no falte aceptar. La función pide auth.uid() y en el editor
--  no hay sesión de nadie. Quién tiene qué pendiente solo se ve entrando
--  al panel, o mirando pliego_aceptaciones.
-- ══════════════════════════════════════════════════════════════════════

insert into public.pliegos (version, titulo, texto, vigente, publicado_en)
values (
  1,
  'Términos, Condiciones y Políticas de Tratamiento de Datos (BORRADOR DE PRUEBA)',
  jsonb_build_object(
    'es', $texto$ESTE TEXTO ES DE PRUEBA Y NO OBLIGA A NADIE.

Está aquí para que la pantalla tenga algo que enseñar mientras el pliego
de verdad lo redacta el abogado del CIIP. No lo aceptes creyendo que
aceptas algo.

1. QUÉ SE RECOGE

La ventanilla guarda tu nombre, tu correo, tu país, el sector en que
inviertes, los datos de tu compañía y los documentos que subes a la
bóveda. Los detalles reales, tabla por tabla, están en
PLIEGO-BORRADOR.md, que es materia prima para el abogado y no un pliego.

2. QUIÉN LO VE

Tú, y el equipo del CIIP que atiende tu expediente. Las cerraduras de la
base están puestas para que nadie más pueda leerlo, y eso está probado.

3. CUÁNTO SE GUARDA

[DECIDE EL CIIP]. En el borrador hay diez sitios marcados así, y son
justo las decisiones que no puede tomar quien programa.

4. QUÉ PASA SI BORRAS LA CUENTA

Se va todo en cascada: el expediente, los documentos y esta misma
aceptación. Guardar la prueba del consentimiento de quien ya no está
sería guardar justo lo que se dijo que se borraba.

5. ESTE APARTADO ES LARGO A PROPÓSITO

Para comprobar que la caja del texto tiene barra propia y que se puede
recorrer con el teclado, hace falta que el documento no quepa de una
vez. Así que aquí van unas cuantas líneas más sin más oficio que ocupar
sitio, y confirmar de paso que los saltos de línea llegan enteros desde
la base hasta la pantalla en vez de convertirse en un ladrillo.

Si estás leyendo esto dentro de la puerta, con su barra de
desplazamiento, entonces esa parte funciona.

Y si has llegado hasta el final sin que la ventana crezca por encima de
la pantalla, también funciona la altura máxima.$texto$,

    'en', $texto$THIS IS TEST TEXT AND IT BINDS NO ONE.

It is here so the screen has something to show while the real terms are
drafted by CIIP's lawyer. Do not accept it thinking you are accepting
anything.

If you are reading this in English, the notice at the bottom should be
telling you that the binding text is the Spanish one. That notice is the
point of this translation: it must appear here and must NOT appear when
the panel is in Spanish.

1. WHAT IS COLLECTED

Your name, your email, your country, the sector you invest in, your
company details and the documents you upload to the vault.

2. WHO SEES IT

You, and the CIIP staff handling your file.

3. HOW LONG IT IS KEPT

[CIIP DECIDES]. There are ten such marks in the draft.$texto$
  ),
  true,
  now()
);


-- ══════════════════════════════════════════════════════════════════════
--  QUÉ MIRAR, UNA VEZ EJECUTADO
-- ══════════════════════════════════════════════════════════════════════
--  1. Recarga el panel. La puerta tapa TODO y no se cierra: prueba
--     Escape, prueba a pulsar fuera, prueba el aspa (no hay).
--  2. El botón de aceptar está apagado hasta que marques la casilla.
--  3. Cambia de idioma con las banderas de dentro. En inglés aparece el
--     aviso de "traducción de cortesía"; en castellano NO debe aparecer.
--     En portugués no hay traducción: cae al castellano y tampoco avisa.
--  4. Acepta. La puerta se va, y si tu cuenta no tenía sector todavía,
--     detrás aparece la del sector: ese es el orden que se buscaba.
--  5. En la barra lateral, bajo Acompañamiento, aparece el renglón nuevo.
--     Ábrelo: el pliego se relee, con la fecha en que lo aceptaste.
--  6. Recarga otra vez. La puerta ya no sale: se pide una vez por versión.
--
--  Para ver la constancia desde la base:
--    select version, cuando from public.pliego_aceptaciones;
--
--  Para comprobar que no se puede reescribir -tiene que fallar-:
--    update public.pliego_aceptaciones set cuando = now() - interval '1 year';


-- ══════════════════════════════════════════════════════════════════════
--  CÓMO DESHACERLO
-- ══════════════════════════════════════════════════════════════════════
--  El disparador impide borrar una aceptación desde el panel, pero desde
--  el editor SQL sí se puede: auth.uid() es nulo ahí y esa es la puerta de
--  servicio que el propio archivo dejó puesta a propósito.
--
--    delete from public.pliego_aceptaciones where version = 1;
--    delete from public.pliegos where version = 1;
--
--  Con las dos tablas vacías el panel vuelve a estar exactamente como
--  antes: sin puerta y sin renglón en la barra.
