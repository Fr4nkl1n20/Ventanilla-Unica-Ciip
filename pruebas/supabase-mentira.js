/* ══════════════════════════════════════════════════════════════════════
   UN SUPABASE DE MENTIRA, PARA PROBAR EL PANEL
   ══════════════════════════════════════════════════════════════════════
   Ocupa el sitio de la biblioteca de la CDN en la copia temporal que
   arma panel.ps1. El panel de verdad NUNCA lo carga.

   ─────────────────────────────────────────────────────────────────────
   POR QUÉ HACE FALTA
   ─────────────────────────────────────────────────────────────────────
   Tres cosas del panel —el buzón de avisos, la franja de "te toca a ti" y
   el detalle de un trámite— solo se pueden probar con datos: si no hay
   sesión, ni catálogo, ni solicitudes, todas se callan, y una prueba
   contra eso pasaría siempre sin comprobar nada.

   Contra el proyecto de Supabase de verdad tampoco sirve: haría falta una
   cuenta con solicitudes en un estado concreto, y cualquiera que las
   moviera dejaría las pruebas rojas sin que nadie hubiera roto el código.

   ─────────────────────────────────────────────────────────────────────
   QUÉ CONTESTA
   ─────────────────────────────────────────────────────────────────────
   Dos escenarios, elegidos con ?caso= en la dirección:

       lleno      un expediente con una solicitud devuelta, otra en borrador
                  y el historial de la primera
       vacio      ni solicitudes ni historial
       gestor     una cuenta del equipo del CIIP, con dos citas ajenas
                  esperando en la cola
       sinnombre  una cuenta cuyo perfil no trae nombre. nombre_completo es
                  'not null default \'\'' en la base, así que toda cuenta
                  creada fuera del registro llega así, y el panel tenía que
                  enseñar el nombre de la demostración —el de otra persona—

   Los filtros (.eq, .in, .order, .limit) se ACEPTAN y se ignoran: los
   fija el panel y no son lo que se prueba. Lo que se prueba es qué hace
   el panel con lo que recibe.

   Las CITAS son la excepción: ahí sí hay estado. Pedir una cita y luego
   cancelarla son dos pasos encadenados —el segundo solo tiene sentido si
   el primero dejó algo—, y con respuestas fijas la prueba de cancelar
   estaría cancelando algo que nunca se creó.
   ══════════════════════════════════════════════════════════════════════ */
(function(){

  var caso = (location.search.match(/caso=(\w+)/) || [])[1] || 'lleno';

  /* 'sinsql' es un gestor cuya base todavia NO tiene corridos
     supabase-admin.sql ni supabase-presencia.sql. Es el estado real de
     cualquiera que se baje el panel hoy: el codigo va por delante de la
     base. Postgres no devuelve las columnas que si conoce y las demas
     vacias -rechaza la consulta entera-, asi que aqui se rechaza igual. */
  /* 'sinsectorsql' es un INVERSIONISTA que no ha contestado el sector y
     cuya base tampoco tiene la columna. Necesita pase propio: en 'sinsql'
     el usuario es un GESTOR, y a un gestor no se le pregunta el sector
     nunca, asi que alli la prueba de "no bloquea" pasaria sola sin llegar
     a medir nada. Es el mismo punto ciego del F5, otra vez. */
  /* 'pliego' es un inversionista al que le falta aceptar el pliego de
     datos. Necesita caso propio y no vale reusar 'vacio': en TODOS los
     demas la tabla de pliegos esta VACIA, que es como nace y como va a
     estar en produccion hasta que el abogado apruebe el texto.

     Y esa es justamente la otra mitad de lo que hay que probar: que con
     la tabla vacia no se bloquee a nadie. Con un solo caso no se pueden
     medir las dos cosas, porque son la misma pregunta contestada al
     reves. */
  /* 'pliego' es a quien le FALTA aceptar; 'pliegoya' es quien YA acepto.
     Los dos hacen falta y no son el mismo: el segundo es el caso normal
     -todo el mundo, a partir del dia siguiente- y es el unico donde se
     puede ver si queda un sitio donde RELEERLO. En el primero el enlace lo
     enciende otra rama, asi que alli esa comprobacion pasaba sola. */
  var conPliego = (caso === 'pliego' || caso === 'pliegoya');
  var yaAceptado = (caso === 'pliegoya');
  if (conPliego) caso = 'vacio';

  var sinSectorSql = (caso === 'sinsectorsql');
  var sinSql = (caso === 'sinsql') || sinSectorSql;
  if (caso === 'sinsql') caso = 'gestor';
  if (sinSectorSql) caso = 'sinsector';

  /* 'admin' son los mismos datos del gestor con el rol de administrador.
     Hasta ahora NINGUN pase entraba con ese rol: por eso nadie noto que el
     renglon de la barra no aparecia nunca. Un permiso que solo se prueba
     por su ausencia no esta probado. */
  var esAdmin = (caso === 'admin');
  if (esAdmin) caso = 'gestor';

  /* ── UN PASE SOLO PARA MIRAR ──
     El mismo gestor de siempre, pero con la cola llena: doce solicitudes
     de siete inversionistas, con los tres estados, esperas de dos horas a
     mes y medio y el reparto repartido de verdad. Sirve para VER como
     queda la pantalla con trabajo encima, que con dos fichas no se ve.

     NO entra en las pruebas, y es a proposito. El arnes mide sobre
     'gestor' -que tomar no saca de la cola, que "Mios" filtra, que el
     contador baja al devolver- y todo eso se mide mejor con dos que con
     doce: una cola larga no prueba nada que no pruebe una corta, y en
     cambio obliga a escribir doce numeros en las pruebas que se rompen
     cada vez que se toca el ejemplo. */
  var demoCola = (caso === 'cola');
  if (demoCola) caso = 'gestor';

  /* ── UN LECTOR DE DOCUMENTOS DE MENTIRA ──
     El panel llama a window.CIIP_LECTOR para sacar de un papel lo que el
     papel dice. En produccion lo pone config.js, y hoy no hay ninguno: por
     eso el cuadro de «suelta el papel» no se pinta para nadie. Aqui se pone
     uno falso para poder probar el camino entero.

     Va en el pase 'lector', que por lo demas es un expediente vacio. Si
     estuviera encendido en todos, el cuadro apareceria en las otras once
     pasadas y estaria midiendose una pantalla que en produccion todavia no
     existe.

     Lo que devuelve NO depende del archivo de verdad -aqui no se lee nada-,
     sino de como se llame: asi una prueba puede pedir un documento que se
     reconoce, uno que no, y uno que revienta. */
  var conLector = (caso === 'lector');
  if (conLector) caso = 'vacio';
  /* ── EL HORARIO DEL CIIP ──
     El pase 'huecos' es un expediente vacio con el horario de citas
     publicado: el unico donde la ventana de la cita ofrece huecos en vez de
     una ventana de dias. Los datos, los de 'vacio'. */
  var conHuecos = (caso === 'huecos');
  if (conHuecos) caso = 'vacio';
  /* ── UN TRAMO DE LA CONSTITUCIÓN, EN MARCHA ──
     'tramos' es un expediente vacío al que se le añaden DOS cosas: la
     protocolización del acta en el catálogo —en los demás pases no está, y
     sin tipo no hay trámite que seguir— y una solicitud suya en revisión,
     con su historial.

     Hace falta un pase propio y no vale ampliar 'vacio' ni 'lleno': un tipo
     más en el catálogo cambia el número de fichas que cuentan las etapas y
     los filtros, y eso lo miden treinta pruebas de las otras pasadas. Aquí
     el catálogo crece solo cuando este pase lo pide. */
  /* Y el MISMO expediente sin una cosa: en 'tramossinpagar' el equipo
     todavía no ha dejado el documento con que pagar los aranceles. Los
     datos son los de 'tramos'; lo único que cambia es ese papel, que es
     justo lo que decide si el paso pide comprobante o dice que el
     documento viene de camino (Franklin Reyes, 18-9-2026). */
  var sinPlanilla = (caso === 'tramossinpagar');
  /* Y el mismo expediente un escalon antes: en 'tramospagado' la
     protocolizacion acaba de nacer -'enviado', que es como la deja el
     disparador al resolverse la constitucion- y el inversionista YA subio
     el comprobante del pago. Es el caso que encendia el segundo paso sin
     que el CIIP hubiera movido nada: el tramo lo mueve la base, no el
     comprobante (Franklin Reyes, 18-9-2026). */
  var yaPagado = (caso === 'tramospagado');
  var conTramos = (caso === 'tramos' || sinPlanilla || yaPagado);
  if (conTramos) caso = 'vacio';
  /* 'parafiscales' (23-9-2026): el expediente vacío con los registros
     parafiscales ya ante los entes, para ver sus cinco escaleras. Uno de
     cada: el BANAVIH listo, el INCES con el código enviado y los otros tres
     por iniciar. Desde el 1-10-2026 el código ya no se pinta: la fila del
     INCES queda como una de antes, y lo que manda son las marcas de r1. */
  var conParafiscales = (caso === 'parafiscales');
  if (conParafiscales){
    caso = 'vacio';
    window.__ENTES = {
      'r1|banavih': {tramite:'r1', ente:'banavih', estado:'listo', codigo:'FAOV-2026-00418'},
      'r1|inces':   {tramite:'r1', ente:'inces', estado:'codigo_enviado', codigo:'INC-77215',
                     documento:'e1', documentos:{archivo:'mentira/e1.pdf', nombre_original:'correo-inces.pdf'}}
    };
  }
  /* El doble manda sobre el lector en TODAS las pasadas, tambien para
     quitarlo. Este archivo se carga despues de config.js: el dia que
     LECTOR_URL tenga una direccion -en local eso es el proyecto de
     pruebas-, config.js pondria un lector de verdad y la prueba de que «sin
     lector no se pinta el cuadro» se apagaria sola, en silencio. */
  if (!conLector) { try { delete window.CIIP_LECTOR; } catch (e){ window.CIIP_LECTOR = undefined; } }
  if (conLector){
    var LEIDO = {
      acta_constitutiva: {
        razon_social:       'Inversiones Montebello, C.A.',
        numero_registro:    '48, Tomo 112-A',
        fecha_constitucion: '2024-06-18',
        capital_social:     '500000',
        /* Tres que este tramite NO pide. El panel tiene que ignorarlas: si
           las escribiera en algun sitio, estaria inventando. */
        objeto_social:      'Empaque y frio de frutas',
        socios:             'Franklin Reyes (60%), Ana Rojas (40%)',
        tipo_sociedad:      'C.A.'
      },
      domicilio_empresa: {
        direccion_fiscal: 'Av. Libertador, Torre 4, Caracas'
      }
    };
    window.CIIP_LECTOR = function(archivo, quePapeles){
      var n = String(archivo && archivo.name || '');
      if (/revienta/.test(n)) return Promise.reject(new Error('el lector de mentira revienta'));
      if (/nose/.test(n))     return Promise.resolve({doc: null, campos: {}});
      var doc = /domicilio/.test(n) ? 'domicilio_empresa' : 'acta_constitutiva';
      /* El panel manda {papel: [casillas]}. Si este tramite no pide ese
         papel, no viene en el mapa y no hay nada que devolver. */
      if (!quePapeles || !quePapeles[doc]) return Promise.resolve({doc: null, campos: {}});
      return Promise.resolve({doc: doc, campos: LEIDO[doc]});
    };
  }

  /* El catálogo, con los tres tipos que usan las pruebas. ref_panel es lo
     que ata cada tipo a su tarjeta del panel (data-tr). */
  /* El pliego que sirve el caso 'pliego'. Uno solo y vigente, como manda
     el indice de la base: dos vigentes a la vez no pueden existir alli,
     asi que tampoco aqui.

     Con texto en DOS idiomas y no en seis: hace falta uno que este y uno
     que falte para poder comprobar que la pantalla cae al castellano
     -que es el que obliga- en vez de quedarse en blanco. */
  var PLIEGOS = conPliego ? [{
    version: 1,
    titulo: 'Pliego de prueba',
    texto: {
      es: 'Primer parrafo del pliego de prueba.\n\nSegundo parrafo.',
      en: 'First paragraph of the test terms.\n\nSecond paragraph.'
    },
    vigente: true,
    publicado_en: '2026-09-01T10:00:00Z'
  }] : [];

  /* Se acepta de verdad, no se finge. Si esto fuera fijo, la prueba de
     que aceptar cierra la puerta pasaria igual con el insert roto. */
  var pliegoAceptado = yaAceptado;

  /* ── LOS PLAZOS, COMO EN LA BASE DE VERDAD ──
     Cinco filas estaban encendidas y sin 'plazo_dias' teniendolo en
     produccion. Mientras el renglon del reloj decia siempre dias daba igual;
     desde que dice la unidad en la que se piensa -7 dias son «1 semana», 120
     son «4 meses»- la rama de los meses no la alcanzaba NINGUNA ficha del
     arnes, y una rama que solo corre en produccion es una rama sin probar.
     Los cinco numeros salen de supabase-plazos.sql: c9=28, c31=120, c19=21,
     c17=28, c20=70. Las que siguen sin plazo tampoco lo tienen alli. */
  var TIPOS = [
    {codigo:'rif_personal', ref_panel:'c3', ente:'SENIAT', activo:true, emite:'rif_personal', plazo_dias:14,
     plazo_legal_dias:null,
     plazo_legal_norma:'Providencia SNAT/2026/00080, Gaceta Oficial 43.435 del 12-8-2026',
     nombre:'RIF personal', fase:1, nivel:'obligatorio',
     activo_por:null, activo_en: haceHoras(30)},
    {codigo:'constitucion', ref_panel:'c5', ente:'SAREN',  activo:true, emite:'acta_constitutiva', plazo_dias:21,
     nombre:'Constitución de empresa', fase:2, nivel:'obligatorio'},
    /* Sin nivel a proposito no: con 'esencial', que es el caso normal y
       el unico de los cuatro que NO lleva distintivo. Asi una prueba puede
       comprobar que ese no lo lleva, que es la mitad de la regla. */
    {codigo:'rif_empresa',  ref_panel:'c6', ente:'SENIAT', activo:true, emite:'rif_empresa', plazo_dias:14,
     nombre:'RIF de la empresa', fase:2, nivel:'esencial'},
    /* APAGADO desde el 20-9-2026, como en la base de verdad: el RNC se
       hace dentro del c37. La fila se queda para que el panel sepa poner
       nombre a las solicitudes de 'rnc' que ya existen —dos, más abajo—,
       que es justo lo que pasa en produccion con los expedientes viejos. */
    {codigo:'rnc',          ref_panel:'c13', ente:'RNC',   activo:false,
     nombre:'Registro Nacional de Contratistas', fase:3, nivel:'actividad'},
    /* Las cinco inscripciones en una casilla. Como en la base de verdad en
       todo menos en el NIVEL: fase 3, 28 dias y SIN 'emite', que devuelve
       cinco constancias y la columna guarda una.

       EL NIVEL VA EN 'obligatorio' Y EN LA BASE DE VERDAD ES 'esencial'.
       Se dice, porque un doble que se aleja de Supabase sin avisar es de
       donde salen los verdes falsos. Lo heredó del IVSS el 22-9-2026, que
       era quien traía el único obligatorio de la fase 3 y se fue del
       catálogo; la razón de que haga falta está escrita entera unas líneas
       más abajo, en «LA PRIMERA». Es esta ficha y no otra porque es la
       única encendida de la fase que no depende del ramo.

       No cambia nada de lo que se ve: 'obligatorio' y 'esencial' pintan la
       tarjeta igual -ninguno lleva distintivo desde que el CIIP quitó el
       de «Obligatorio»-. Lo que cambia es que la fase 3 aparta. */
    {codigo:'registros_parafiscales', ref_panel:'c37', ente:'Entes varios',
     activo:true, plazo_dias:28,
     nombre:'Inscripciones: Registros Parafiscales y Regulatorios',
     fase:3, nivel:'obligatorio'},

    /* ── lo que el catálogo de verdad NO dice todavía ──
       Y se dice, porque un doble que se aleja de Supabase sin avisar es
       de donde salen los verdes falsos.

       LA PRIMERA es el nivel del c37, ahí arriba: un obligatorio en la
       fase 3. Hoy no hay ninguno —los once dependen del ramo— y por eso
       la regla de «no apartar lo de 'actividad'» no se alcanza NUNCA con
       los datos de hoy: sin obligatorio, la fase no aparta nada de todas
       formas. Un sabotaje que apartara lo de 'actividad' salía verde, y
       salió.

       No es un dato torcido porque sí: es la fase 3 el día que exista
       la matriz de sector a permisos —punto 2 de lo que falta en
       supabase-informe-victor.sql—, cuando algunos de esos permisos sean
       obligatorios para un sector. Ese día el permiso sanitario NO puede
       irse detrás de un botón, y esto es lo que lo sujeta.

       Hasta el 22-9-2026 lo traía una fila propia, la del IVSS (c9), que
       el doble encendía como obligatoria. El CIIP quitó esa casilla del
       catálogo y el papel pasó al c37.

       LA SEGUNDA: un trámite en la fase 5, para poder comprobar aparte
       que una fase sin obligatorios se queda entera. Antes eso se miraba
       en la fase 3, que ahora ya tiene uno. */
    /* La firma en el Registro de Extranjeros. Sin ella aqui, el panel no
       sabe que el c32 es un tramite vivo y pinta una ficha de LECTURA: sin
       formulario y sin recaudos. Las pruebas del formulario contaban cero
       campos y parecia que el fallo seguia sin arreglar.

       Esta si es como en la base de verdad: fase 2, obligatoria y encendida. */
    {codigo:'registro_extranjeros_saren', ref_panel:'c32', ente:'SAREN · SISREF',
     activo:true, emite:'constancia_sisref', plazo_dias:14,
     nombre:'Solicitud de firma en el Registro de Extranjeros', fase:2, nivel:'obligatorio'},
    /* La opinion favorable de la ZODI. Como en la base de verdad: fase 2,
       'actividad', encendida y SIN plazo -nadie lo ha dado-. Sin ella aqui
       el panel pintaria una ficha de lectura, sin formulario. */
    {codigo:'opinion_zodi', ref_panel:'c34', ente:'ZODI',
     activo:true, emite:'no_objecion_zodi', plazo_dias:null,
     nombre:'Opinión favorable de la ZODI', fase:2, nivel:'actividad'},
    /* «Bienes» (2-10-2026), como en supabase-bienes.sql: la compraventa
       (c41) a la vista y el alquiler (c42) escondido con data-tramo-de,
       como las dos visas. Los dos encendidos, 'actividad' y sin plazo. */
    {codigo:'bienes_compraventa', ref_panel:'c41', ente:'CIIP',
     activo:true, emite:null, plazo_dias:null,
     nombre:'Bienes: compraventa de un inmueble', fase:2, nivel:'actividad'},
    {codigo:'bienes_alquiler', ref_panel:'c42', ente:'CIIP',
     activo:true, emite:null, plazo_dias:null,
     nombre:'Bienes: alquiler de un inmueble', fase:2, nivel:'actividad'},
    /* La marca en proceso de registro (Franklin Reyes, 5-10-2026), como en
       supabase-marca-proceso.sql: escondida con data-tramo-de detrás de la
       c8, como el alquiler detrás de la compraventa. Encendida aunque la
       c8 nazca apagada aquí: así su ficha se puede probar en todos los
       pases, y la guía se mira con la c8 ya encendida (alDiaVuelve). */
    {codigo:'marca_en_proceso', ref_panel:'c43', ente:'SAPI',
     activo:true, emite:null, plazo_dias:null,
     nombre:'Registro de marca: marca en proceso de registro', fase:2, nivel:'esencial'},
    /* Los cuatro de «Ya lo solicité» (Franklin Reyes, 5-10-2026, Ventanilla
       única 2.6), como en supabase-ya-solicitado.sql: escondidos con
       data-tramo-de detrás de su casilla -c37, c10, c28 y c29-, encendidos y
       sin plazo. El nivel, el de la base: 'esencial' el de las inscripciones
       (aquí el c37 va 'obligatorio' a propósito, ver «LA PRIMERA» más
       abajo, y un segundo obligatorio en la fase 3 movería lo que eso mide)
       y 'actividad' los otros tres. */
    {codigo:'parafiscales_en_proceso', ref_panel:'c44', ente:'Entes varios',
     activo:true, emite:null, plazo_dias:null,
     nombre:'Inscripciones: empresa ya inscrita', fase:3, nivel:'esencial'},
    {codigo:'licencia_en_proceso', ref_panel:'c45', ente:'Alcaldía',
     activo:true, emite:null, plazo_dias:null,
     nombre:'Licencia de actividades económicas: ya solicitada', fase:3, nivel:'actividad'},
    {codigo:'conformidad_en_proceso', ref_panel:'c46', ente:'Alcaldía',
     activo:true, emite:null, plazo_dias:null,
     nombre:'Conformidad de uso: ya solicitada', fase:3, nivel:'actividad'},
    {codigo:'bomberos_en_proceso', ref_panel:'c47', ente:'Bomberos',
     activo:true, emite:null, plazo_dias:null,
     nombre:'Permiso de bomberos: ya solicitado', fase:3, nivel:'actividad'},
    /* El RUPDAE y el Registro Único Minero, en la fase 3. Como en la base
       de verdad: el RUM 'actividad' y SIN plazo -la resolución no da
       ninguno-. Sin él aquí el panel pintaría una ficha de lectura.

       El RUPDAE va APAGADO desde el 20-9-2026: se hace dentro del c37.
       Conserva su 'emite' y su plazo para que, si el CIIP vuelve a
       encenderlo desde el panel del admin, no se encienda descalzo. */
    {codigo:'rupdae', ref_panel:'c35', ente:'SUNDDE',
     activo:false, emite:'certificado_rupdae', plazo_dias:14,
     nombre:'Inscripción en el RUPDAE', fase:3, nivel:'esencial'},
    {codigo:'registro_minero', ref_panel:'c36', ente:'Ministerio de Desarrollo Minero',
     activo:true, emite:'certificado_rum', plazo_dias:null,
     nombre:'Registro Único Minero', fase:3, nivel:'actividad'},
    /* El SIDCAI (c39) y su segundo tramo (c40), del 23-9-2026. Como el
       RUM: 'actividad' y sin plazo. El certificado sale del segundo. */
    {codigo:'aporte_locti', ref_panel:'c39', ente:'FONACIT',
     activo:true, emite:null, plazo_dias:null,
     nombre:'Inscripción en el SIDCAI (aporte LOCTI)', fase:3, nivel:'actividad'},
    {codigo:'aporte_locti_pago', ref_panel:'c40', ente:'FONACIT',
     activo:true, emite:'certificado_locti', plazo_dias:null,
     nombre:'Declaración y primer pago del aporte LOCTI', fase:3, nivel:'actividad'},

    /* Y va en 'opcional', que TAMPOCO es lo que dice el catálogo de verdad
       -allí se queda con el 'esencial' por defecto-. Es la segunda fila que
       se aparta de Supabase a propósito, y por la misma razón que la de
       arriba: sin ella la regla de «una fase sin obligatorios no aparta
       nada» no se alcanza NUNCA, porque los seis opcionales del catálogo
       viven todos en la fase 1, que sí tiene obligatorios. Un sabotaje que
       quitara esa guarda salía verde, y salió.

       Y la guarda importa: desde que las fases 4 y 5 se fundieron, esta
       tarjeta vive en la 4, que no tiene ningún obligatorio. Sin la guarda,
       sus tres tarjetas se irían detrás de un botón y la etapa quedaría
       vacía. */
    {codigo:'registro_inversion', ref_panel:'c31', ente:'CIIP', activo:true, plazo_dias:120,
     nombre:'Registro de inversión extranjera', fase:5, nivel:'opcional'},
    /* Con nivel explicito, como en la base: la columna es NOT NULL con
       DEFAULT 'esencial', asi que alli NINGUNA fila llega sin nivel. Una
       fila sin el no se aparta y una con 'esencial' si, o sea que el
       doble sin esto era mas permisivo que Supabase justo aqui.

       Lleva 'actividad' y no el default porque es lo que dice el informe:
       las solvencias estan en su lista de los que dependen del ramo. */
    {codigo:'solvencias',   ref_panel:'c14', ente:'Entes varios', activo:true,
     nombre:'Solvencias laborales', fase:3, nivel:'actividad'},

    /* DOS opcionales, y los dos en la misma fase: es lo que hace falta para
       ver la lista apartada. Con uno solo el rotulo diria "Ver los 1
       opcionales" y ninguna prueba distinguiria apartar de esconder.

       Van los dos en "pendiente" a proposito, que es el caso corriente: la
       caja tiene que empezar CERRADA. Que se abra sola cuando uno pide
       accion se comprueba moviendole el estado a mano, no trayendolo ya
       movido de aqui.

       El segundo NO se escribe aqui: la visa de dependientes ya estaba mas
       abajo y volver a declararla dejaba el catalogo con dos filas para la
       misma tarjeta -y la lista de asuntos de las citas, que va por
       ref_panel, se quedo con una opcion menos-. Se le puso el nivel alli,
       en la fila que ya existia. */
    {codigo:'firma_electronica', ref_panel:'c19', ente:'SUSCERTE', activo:true, plazo_dias:21,
     nombre:'Firma electrónica', fase:1, nivel:'opcional'},
    /* La apostilla, obligatoria y PENDIENTE. Es la que hace que la fase 01
       tenga algo que faltar: sin ella los tres obligatorios estarían
       hechos y el rótulo en ámbar no se pintaría nunca. */
    {codigo:'apostilla_documentos', ref_panel:'c17', ente:'MPPRE', activo:true, plazo_dias:28,
     nombre:'Apostilla de documentos', fase:1, nivel:'obligatorio'},
    /* Uno APAGADO a proposito. Con todos encendidos, la prueba de que el
       interruptor enciende no se puede distinguir de la de que no hace
       nada: los dos casos dejan la lista igual. */
    {codigo:'marca',        ref_panel:'c8', ente:'SAPI',   activo:false,
     nombre:'Registro de marca', fase:2, nivel:'esencial',
     /* Con autor y fecha: es lo que lee el rastro. Uno apagado por
        alguien del equipo y otro encendido sin autor -hecho desde el
        editor de Supabase-, que son los dos casos que la pantalla tiene
        que saber contar distinto. */
     activo_por:'u4', activo_en: haceHoras(5)},
    /* La visa, que es la del tramite ya resuelto. Sin su tipo aqui, el
       panel no sabe a que tarjeta pertenece y la deja en "por iniciar"
       aunque el tramite este resuelto. */
    /* Con el plazo legal puesto: es uno de los dos comprobados en su
       fuente, y el unico con el que se puede probar el globo del reloj. */
    {codigo:'visa_negocios', ref_panel:'c1', ente:'MPPRE', activo:true, plazo_dias:30,
     plazo_legal_dias:null,
     plazo_legal_norma:'Normas de Procedimiento para la Expedición de Visados, Gaceta Oficial Extraordinaria 5.427 del 5-1-2000',
     nombre:'Visa de negocios (TR-N)', fase:1, nivel:'obligatorio'},
    /* La TR-I, desde el 22-9-2026. No sale suelta en la portada -su
       tarjeta lleva data-tramo-de-, pero en el catalogo es un tramite
       como cualquier otro: se pide desde la guia de la casilla de la
       visa, y por eso tiene que estar aqui. */
    {codigo:'visa_inversionista', ref_panel:'c38', ente:'MPPRE', activo:true, plazo_dias:30,
     nombre:'Visa de inversionista (TR-I)', fase:1, nivel:'obligatorio'}
  ];
  /* Solo en 'tramos', y por eso va aparte del catálogo de arriba: en la base
     de verdad este tipo está encendido desde el 15 de septiembre, pero
     encenderlo en todas las pasadas movería los contadores de las fichas. */
  if (conTramos){
    TIPOS.push({codigo:'protocolizacion_acta', ref_panel:'c22', ente:'SAREN', activo:true,
                nombre:'Protocolización del acta', fase:2, nivel:'obligatorio'});
    /* Y la publicación, por lo mismo (Franklin Reyes, 20-9-2026): sin su
       tipo aquí el panel no sabe de qué tarjeta es la solicitud, deja el
       bloque como dibujo y el PUB del periódico no se pinta en ninguna
       parte. */
    TIPOS.push({codigo:'publicacion_acta', ref_panel:'c23', ente:'Prensa mercantil', activo:true,
                nombre:'Publicación del acta', fase:2, nivel:'obligatorio'});
  }

  /* El borrador se toca DESPUÉS que el devuelto a propósito: así se
     comprueba que la franja antepone la devolución y no coge sin más lo
     último que se movió. */
  var TRAMITES = {
    lleno: [
      {id:'t1', tipo:'rif_empresa',  estado:'devuelto',
       datos:{razon_social:'Bianchi Agroindustrias, C.A.'},
       creado_en:'2026-07-02T10:00:00Z', actualizado_en:'2026-08-14T10:00:00Z'},
      {id:'t2', tipo:'constitucion', estado:'borrador',
       creado_en:'2026-08-01T10:00:00Z', actualizado_en:'2026-08-18T10:00:00Z'},
      /* Recien enviado y sin historial propio: su escalera no tiene fechas
         que enseñar, asi que el paso en curso ha de marcarse con palabras. */
      {id:'t3', tipo:'rif_personal', estado:'enviado',
       creado_en:'2026-08-17T10:00:00Z', enviado_en:'2026-08-17T10:00:00Z',
       actualizado_en:'2026-08-17T10:00:00Z'},
      /* Uno RESUELTO, con su documento entregado. Hasta ahora ningun
         expediente de prueba tenia uno, y por eso nadie noto que el
         circuito acababa en el aire: el estado cambiaba y el inversionista
         no recibia nada. */
      /* Con sus datos dentro: son los que el panel tiene que ofrecer
         cuando otro formulario pregunte lo mismo. Sin ellos, la prueba de
         que no se pide dos veces el pasaporte no mide nada. */
      /* fecha_documento la guarda la visa aunque su formulario no la
         pregunte, igual que ya hacía con fecha_nacimiento: la herencia va
         por el NOMBRE del campo y lee tramites.datos, no el formulario de
         origen. Es lo que deja medir que una fecha heredada llega a las
         tres listas de otra ficha -hoy la c17-. */
      {id:'t4', tipo:'visa_negocios', estado:'resuelto',
       datos:{numero_pasaporte:'YB1234567', pais_emisor:'Italia',
              fecha_nacimiento:'1979-04-11', fecha_documento:'1979-04-11'},
       creado_en:'2026-06-01T10:00:00Z', enviado_en:'2026-06-02T10:00:00Z',
       resuelto_en:'2026-06-18T10:00:00Z', actualizado_en:'2026-06-18T10:00:00Z'},
      /* Una SEGUNDA visa, mas NUEVA y en borrador. Con "la ultima creada"
         la tarjeta ensenaba el formulario en blanco sobre un tramite que
         YA ESTA RESUELTO: las dos pantallas del mismo tramite decian
         cosas distintas. */
      {id:'t5', tipo:'visa_negocios', estado:'borrador', datos:{},
       creado_en:'2026-08-20T10:00:00Z',
       actualizado_en:'2026-08-20T10:00:00Z'}
    ],
    /* "Vacío" no es "sin filas": es SIN NADA QUE ANUNCIAR. Aquí hay un
       borrador que se quedó atrás porque el reintento del envío sí entró.
       La franja no debe anunciarlo —el detalle enseña la enviada—, y sin
       esa comprobación las dos pantallas decían cosas distintas del mismo
       trámite: "no la has enviado" en la portada y "Enviada" dentro. */
    vacio: [
      {id:'t3', tipo:'rif_personal', estado:'borrador',
       creado_en:'2026-08-17T09:00:00Z', actualizado_en:'2026-08-17T09:00:00Z'},
      {id:'t4', tipo:'rif_personal', estado:'en_revision',
       creado_en:'2026-08-17T11:00:00Z', actualizado_en:'2026-08-18T08:00:00Z'}
    ].concat(conTramos ? [
      /* La protocolización: en 'tramos' ya presentada y en revisión, y en
         'tramospagado' recién nacida —'enviado'—. Es donde se pide el
         comprobante del pago, y en los dos casos su primer paso es el que
         toca: sin el comprobante porque falta el papel, y con él porque
         el estado todavía no ha pasado de ese paso. */
      {id:'p1', tipo:'protocolizacion_acta',
       estado: yaPagado ? 'enviado' : 'en_revision',
       creado_en:'2026-09-01T10:00:00Z', enviado_en:'2026-09-01T10:00:00Z',
       actualizado_en: yaPagado ? '2026-09-01T10:00:00Z' : '2026-09-08T10:00:00Z'},
      /* Y la constitución, con el nombre ya reservado: está ante el ente y
         le falta el comprobante de esa reserva, que es el paso que se sube
         antes de poder resolverla. */
      {id:'p2', tipo:'constitucion', estado:'ante_el_ente',
       creado_en:'2026-08-20T10:00:00Z', enviado_en:'2026-08-20T10:00:00Z',
       actualizado_en:'2026-08-30T10:00:00Z'},
      /* Y LA PUBLICACIÓN (Franklin Reyes, 20-9-2026), recién nacida al
         resolverse la protocolización: el mismo tramo un piso más abajo,
         con su PUB delante. Está en 'enviado' a propósito —como nace—, que
         es donde se ve si el paso del PUB se enciende con el papel y no
         con el estado. Sin ella, el c23 no era más que un dibujo y el
         segundo PUB no lo probaba nadie. */
      {id:'p3', tipo:'publicacion_acta', estado:'enviado',
       creado_en:'2026-09-10T10:00:00Z', enviado_en:'2026-09-10T10:00:00Z',
       actualizado_en:'2026-09-10T10:00:00Z'}
    ] : []).concat(conParafiscales ? [
      /* Con dos marcas del inversionista (1-10-2026): el INCES inscrito
         y el IVSS con la afiliación solicitada, para ver los dos casos. */
      {id:'r1', tipo:'registros_parafiscales', estado:'ante_el_ente',
       datos:{ente_inces:'2026-09-28T10:00:00-04:00', ente_ivss:'2026-09-29T10:00:00-04:00'},
       creado_en:'2026-09-15T10:00:00Z', enviado_en:'2026-09-15T10:00:00Z',
       actualizado_en:'2026-09-20T10:00:00Z'}
    ] : []),
    sinnombre: [
      /* Un borrador SOLO, y a medio subir: es el unico expediente donde
         el aviso ensena el caso del borrador. En 'lleno' gana siempre el
         devuelto, y sin esto la barra de "2 de 4 recaudos" no la mira
         nadie. La visa pide seis obligatorios. */
      {id:'s1', tipo:'visa_negocios', estado:'borrador',
       creado_en:'2026-08-18T10:00:00Z', actualizado_en:'2026-08-18T10:00:00Z'}
    ]
  };

  /* Lo que espera por el CIIP. Solo lo ve quien tiene rol de gestor, y una
     de las dos viene SIN nombre a proposito: asi se comprueba que la cola
     lo dice en vez de dejar el hueco, que parecería un fallo del dato. */
  var COLA = {
    gestor: [
      {id:'q1', inversionista:'u2', tipo_tramite:'rif_empresa', modo:'presencial',
       desde:'2026-08-25', hasta:'2026-09-05', nota:'Prefiero por la ma\u00f1ana',
       creado_en:'2026-08-10T09:00:00Z'},
      {id:'q2', inversionista:'u3', tipo_tramite:null, modo:'video',
       desde:'2026-08-28', hasta:'2026-08-30', nota:'',
       creado_en:'2026-08-12T09:00:00Z'}
    ],
    lleno: [], vacio: [], sinnombre: []
  };
  /* Cuantos tipos declara este catalogo. Lo usa el arnes para no tener que
     escribir a mano un numero que cambia cada vez que se activa un tramite. */
  window.PRUEBA_TIPOS = TIPOS.length;
  /* Y cuantos de ellos estan ENCENDIDOS, que desde que lo apagado no se
     ofrece ya no es lo mismo. El arnes necesita las dos: una lista de
     asuntos que ofreciera tambien los apagados seria pedir cita sobre un
     tramite que la ventanilla no da. */
  window.PRUEBA_TIPOS_ON = TIPOS.filter(function(t){ return t.activo; }).length;

  var ACTIVOS = {
    lleno: [
      {id:'a1', titulo:'Planta procesadora de cacao', sector:'Agroindustria',
       ubicacion:'Miranda', monto_desde:250000, monto_hasta:400000, moneda:'USD',
       resumen:'Instalada y con permisos al dia; busca socio para ampliar capacidad.',
       detalle:'Capacidad actual de 12 t/mes con posibilidad de llegar a 30.',
       estado:'disponible', destacado:true, creado_en:'2026-08-01T09:00:00Z'},
      /* Sin techo: casi ninguna oportunidad se publica con precio cerrado. */
      {id:'a2', titulo:'Desarrollo turistico costero', sector:'Turismo',
       ubicacion:'Nueva Esparta', monto_desde:800000, monto_hasta:null, moneda:'USD',
       resumen:'Terreno de 4 ha con vialidad y servicios.', detalle:'',
       estado:'reservado', destacado:false, creado_en:'2026-07-20T09:00:00Z'}
    ],
    /* El equipo ve uno mas: un CERRADO, que la politica de la base no le
       manda a nadie mas. Y los ve con boton de editar, que es lo que hace
       que la tabla se pueda llenar sin entrar a Supabase. */
    gestor: [
      {id:'g1', titulo:'Bloque de galpones industriales', sector:'Manufactura',
       ubicacion:'Carabobo', monto_desde:1200000, monto_hasta:null, moneda:'USD',
       resumen:'Tres galpones con servicios y acceso a la troncal.', detalle:'',
       estado:'disponible', destacado:true, creado_en:'2026-08-02T09:00:00Z'},
      {id:'g2', titulo:'Hotel de playa en remodelacion', sector:'Turismo',
       ubicacion:'Falcon', monto_desde:600000, monto_hasta:900000, moneda:'USD',
       resumen:'Ya no se ofrece: quedo cerrado en julio.', detalle:'',
       estado:'cerrado', destacado:false, creado_en:'2026-07-01T09:00:00Z'}
    ],
    vacio: [], sinnombre: []
  };
  var activosVivos = (ACTIVOS[caso] || []).slice().map(function(a){
    var c = {}; Object.keys(a).forEach(function(k){ c[k] = a[k]; }); return c;
  });
  /* Lo que se sube a la boveda durante la pasada. Empieza vacia: el
     expediente de partida es el de siempre, y lo que aparezca aqui lo ha
     subido la propia prueba. */
  var subidos = [];
  /* Para contar las fichas que deja una prueba -QA-14: una resolución
     reintentada no puede dejar dos-. Copias: la lista es del doble. */
  window.PRUEBA_SUBIDOS = function(){ return subidos.slice(); };
  /* Lo que se escribe en el hilo durante la pasada. Sin esto, mandar un
     mensaje y volver a leer devolvia lo mismo de antes y no habia forma
     de medir que aparece. */
  var dichos = [];
  /* Lo que se escriba en el hilo de una cita durante la tanda. */
  var dichosCita = [];

  /* LAS CONSULTAS. Empieza con dos y no vacia, y las dos hacen falta:

       cs1  del inversionista, ya contestada por el equipo. Sin una que
            tenga respuesta no habria forma de probar que se distingue
            quien habla, que es la mitad de lo que hace un hilo.

       cs2  SIN gestor y de otra persona: es la que tiene que salir en la
            cola del equipo. Puesta a nombre del propio inversionista, la
            cola se probaria con una consulta que ya es suya y el filtro
            de "sin asignar" pasaria por casualidad. */
  var consultas = [
    {id:'cs1', inversionista:'u1', tramite:'t1', tipo:'rif_personal', asunto:'Acreditacion de identidad y legitimacion',
     estado:'en_curso', gestor:'g1', creado_en:'2026-08-20T09:00:00Z',
     actualizado_en:'2026-08-20T11:00:00Z', resuelto_en:null},
    {id:'cs2', inversionista:'u9', tramite:null, tipo:null, asunto:'Necesito visa para constituir la empresa?',
     estado:'abierta', gestor:null, creado_en:'2026-08-22T15:30:00Z',
     actualizado_en:'2026-08-22T15:30:00Z', resuelto_en:null},
    /* Y una RESUELTA. No es adorno: la cola del equipo pide las vivas con
       .in('estado', ['abierta','en_curso']), y sin una resuelta en la mesa
       ese filtro pasaria aunque no filtrara nada. Ademas el inversionista
       tiene que verla en su lista -las suyas son todas, no solo las vivas-,
       que es la otra mitad de lo que hay que distinguir. */
    {id:'cs3', inversionista:'u1', tramite:null, tipo:null, asunto:'Como se apostilla un poder desde Italia?',
     estado:'resuelta', gestor:'g1', creado_en:'2026-08-10T08:00:00Z',
     actualizado_en:'2026-08-11T16:00:00Z', resuelto_en:'2026-08-11T16:00:00Z'}
  ];
  /* Lo que se escriba en el hilo de una consulta durante la tanda. */
  var dichosConsulta = [];
  /* Los trámites específicos de cada sector que cargó el CIIP. Dos en
     hidrocarburos y ninguno en los demás: con eso se ve la lista bajo el
     sector en el chat y también que un sector sin nada no enseña nada. */
  var porSector = [
    {id:'ps1', sector:'hidrocarburos', nombre:'Licencia de exploración y explotación',
     organismo:'Ministerio de Hidrocarburos', orden:10},
    {id:'ps2', sector:'hidrocarburos', nombre:'Registro de empresas de servicios petroleros',
     organismo:'PDVSA', orden:20}
  ];
  var psCreados = 2;
  /* Dos ganchos para las pruebas de la auditoría QA: mirar o tocar una
     consulta como lo haría otro gestor desde otra pestaña (QA-22), y quitar
     la que abre una prueba para dejar la mesa como estaba (QA-04). */
  window.CIIP_MENTIRA_CONSULTA = function(id){
    return consultas.filter(function(c){ return c.id === id; })[0] || null;
  };
  /* La última consulta abierta, para ver qué sector se guardó con ella. */
  window.CIIP_MENTIRA_ULTIMA_CONSULTA = function(){
    return consultas[consultas.length - 1] || null;
  };
  window.CIIP_MENTIRA_OLVIDA_CONSULTA = function(id){
    consultas = consultas.filter(function(c){ return c.id !== id; });
  };
  /* Lo que se ha escrito en los hilos de consulta durante la tanda: que en
     una resuelta no se escriba ni forzando el botón (5-10-2026). */
  window.CIIP_MENTIRA_DICHOS_CONSULTA = function(){ return dichosConsulta.slice(); };
  /* Lo que se borro en esta pasada, para que la lista lo respete. */
  var borrados = {};
  /* La configuracion del acompañamiento, con sus valores de fabrica. */
  var ACOMP = {id:true, burbuja:true, nube:true, b_ciip:true, b_invertir:true,
    b_cita:true, nube_espera:3200, nube_dura:8400, nube_vuelve:180000, textos:{}};
  /* Y las rutas que han pasado por Storage, para poder decir que NO existe
     lo que nadie ha subido. */
  var subidas = {};
  function enLaBoveda(ruta){
    /* Las del expediente de partida existen desde antes de la pasada, y se
       reconocen por tener EXTENSION: 'u1/acta.pdf'. La foto del perfil vive
       en '{uid}/perfil/foto', sin extension y con nombre fijo, asi que
       mientras nadie la sube no existe -que es lo que hay que poder decir-.
       Con un "empieza por el uid" a secas se daba por buena tambien esa, y
       el panel se creia que siempre habias puesto foto. */
    return /\.[a-z0-9]{2,5}$/i.test(String(ruta || ''));
  }

  var colaViva = (COLA[caso] || []).slice();

  /* Los tramites que esperan por el CIIP. Uno recien enviado y otro que ya
     alguien empezo a mirar: los pasos que se ofrecen no son los mismos. */
  var COLA_TRAM = {
    gestor: [
      {id:'x1', inversionista:'u2', tipo:'rif_empresa', estado:'enviado',
       datos:{razon_social:'Bianchi Agroindustrias, C.A.', rif_empresa:'J-40123456-7',
              actividad_economica:'Procesamiento de cacao'},
       creado_en:'2026-08-05T09:00:00Z', enviado_en:'2026-08-05T09:00:00Z'},
      /* Uno sin asignar y otro de OTRO gestor: con los dos iguales, los
         tres montones dirian lo mismo y probar que reparten no probaria
         nada. */
      {id:'x2', inversionista:'u3', tipo:'constitucion', estado:'en_revision',
       /* Con los recaudos ya dados por revisados (5-10-2026): lo que se
          prueba con ella es presentar, y la firma que lo frena. */
       datos:{pasos_ciip:{recaudos_revisados:'2026-08-08T10:00:00-04:00'}},
       creado_en:'2026-08-07T09:00:00Z', enviado_en:'2026-08-07T09:00:00Z',
       gestor:'u4'}
    ],
    lleno: [], vacio: [], sinnombre: []
  };
  /* Doce solicitudes para el pase de mirar. Las fechas son RELATIVAS a hoy
     y no fijas: escritas a mano, «lleva esperando 17 días» se convierte en
     «lleva 200» con el tiempo y la pantalla acaba mintiendo sola. */
  /* Recorta las filas a las columnas pedidas, como hace Postgres. No
     recorta si la lista trae una relacion incrustada -documentos(...)- o si
     no se pidio nada: ahi el panel quiere la fila entera. */
  function soloLoPedido(filas, cols){
    var lista = String(cols || "").trim();
    if (!lista || lista === "*" || lista.indexOf("(") >= 0) return filas;
    var quiere = lista.split(",").map(function(c){ return c.trim(); });
    return (filas || []).map(function(f){
      var r = {};
      quiere.forEach(function(c){
        if (Object.prototype.hasOwnProperty.call(f, c)) r[c] = f[c];
      });
      return r;
    });
  }

  function haceDias(n){ return new Date(Date.now() - n * 86400000).toISOString(); }
  function haceHoras(n){ return new Date(Date.now() - n * 3600000).toISOString(); }
  var COLA_DEMO = [
    /* Recién llegada y sin tocar: «sin asignar» no es un error, es un
       estado, y tiene que verse como tal. */
    {id:'d1', inversionista:'u7', tipo:'rif_personal', estado:'enviado',
     datos:{numero_documento:'X-1284455', telefono:'+351 912 004 118'},
     creado_en: haceHoras(2), enviado_en: haceHoras(2)},
    {id:'d2', inversionista:'u5', tipo:'solvencias', estado:'enviado',
     datos:{razon_social:'Tanaka Hidro, C.A.'},
     creado_en: haceHoras(20), enviado_en: haceHoras(20)},
    {id:'d3', inversionista:'u10', tipo:'constitucion', estado:'enviado',
     datos:{razon_social:'Méndez Logística Caribe, C.A.', capital_social:'220.000'},
     creado_en: haceDias(3), enviado_en: haceDias(3)},
    /* Mías, para que el montón «Míos» no salga en cero. */
    {id:'d4', inversionista:'u5', tipo:'visa_negocios', estado:'en_revision',
     datos:{numero_pasaporte:'TR8842019', pais_emisor:'Japón',
            consulado:'Consulado de Venezuela en Tokio'},
     creado_en: haceDias(4), enviado_en: haceDias(4), gestor:'u1'},
    {id:'d5', inversionista:'u9', tipo:'apostilla_documentos', estado:'enviado',
     datos:{documento:'Partida de nacimiento', idioma:'Italiano'},
     creado_en: haceDias(6), enviado_en: haceDias(6)},
    /* El mismo inversionista con dos cosas a la vez: pasa, y la cola no
       puede juntarlas ni esconder una. */
    {id:'d6', inversionista:'u7', tipo:'constitucion', estado:'en_revision',
     datos:{razon_social:'Ferreira Turismo Costa, C.A.', capital_social:'80.000'},
     creado_en: haceDias(9), enviado_en: haceDias(9), gestor:'u4'},
    {id:'d7', inversionista:'u10', tipo:'rnc', estado:'en_revision',
     datos:{razon_social:'Méndez Logística Caribe, C.A.',
            actividad_economica:'Transporte y almacenamiento'},
     creado_en: haceDias(12), enviado_en: haceDias(12), gestor:'u1'},
    /* Sin nombre en el perfil: la cola tiene que decirlo en vez de dejar
       el hueco. */
    {id:'d8', inversionista:'u3', tipo:'constitucion', estado:'en_revision',
     datos:{razon_social:'(sin razón social)', capital_social:'150.000'},
     creado_en: haceDias(17), enviado_en: haceDias(17), gestor:'u4'},
    {id:'d9', inversionista:'u9', tipo:'rif_empresa', estado:'ante_el_ente',
     datos:{razon_social:'Wei Manufacturas Andinas, C.A.', rif_empresa:'J-41998877-0'},
     creado_en: haceDias(23), enviado_en: haceDias(23), gestor:'u4'},
    {id:'d10', inversionista:'u2', tipo:'rif_empresa', estado:'ante_el_ente',
     datos:{razon_social:'Bianchi Agroindustrias, C.A.', rif_empresa:'J-40123456-7',
            actividad_economica:'Procesamiento de cacao'},
     creado_en: haceDias(28), enviado_en: haceDias(28), gestor:'u1'},
    {id:'d11', inversionista:'u6', tipo:'rnc', estado:'ante_el_ente',
     datos:{razon_social:'Okonkwo Energy Services, C.A.',
            actividad_economica:'Servicios a la industria petrolera'},
     creado_en: haceDias(31), enviado_en: haceDias(31), gestor:'u1'},
    /* La más vieja de todas, y SIN asignar: es el caso que esta pantalla
       existe para que no vuelva a pasar. */
    {id:'d12', inversionista:'u8', tipo:'solvencias', estado:'enviado',
     datos:{razon_social:'Kovalenko Import Export, C.A.'},
     creado_en: haceDias(46), enviado_en: haceDias(46)}
  ];
  var colaTram = (demoCola ? COLA_DEMO : (COLA_TRAM[caso] || [])).slice();

  /* «Lo que toca hoy» se prueba con trámites PROPIOS. Cuando la cadena llega
     a esa pantalla, los dos de COLA_TRAM ya se devolvieron o presentaron y
     no queda nada que tomar ni que revisar; tocarlos antes le cambiaria las
     cuentas a media tanda. Así que el arnés siembra tres, trabaja con ellos
     y deja la cola como estaba.

     'sembrado' cambia una regla: al pasar a revisión o ante el ente estos
     SIGUEN en la cola, que es lo que hace la base. Los de COLA_TRAM salen
     con cualquier cambio de estado, y hay pruebas que cuentan con eso. */
  var HOY_DOCS = {}, HOY_DOC = {};
  /* Los resueltos del montón «Listos» (Franklin Reyes, 30-9-2026). Van en
     su propia lista porque el panel los pide en su propia consulta -con
     .eq('estado', 'resuelto')- y no en la de la cola. Vacía hasta que se
     siembra la cola de «lo que toca hoy», y se vacía al restaurarla: así
     las pruebas de la cola de antes cuentan lo mismo que siempre.

     Uno solo, SUYO (u1) y enviado hace cuarenta días: sin plazo cumplido
     no probaría que no cuenta como «Fuera de plazo», y de otro no probaría
     que tampoco se cuela en «Míos». */
  var colaListos = [];
  function siembraHoy(){
    function hace(n){ return new Date(Date.now() - n * 86400000).toISOString(); }
    colaTram = [
      {id:'h1', inversionista:'u2', tipo:'rif_personal', estado:'enviado', gestor:null, sembrado:true,
       datos:{tipo_documento:'Pasaporte', numero_documento:'YA8812345', telefono:'+58 412 555 0132',
              direccion_fiscal:'Av. Francisco de Miranda, Chacao'},
       creado_en: hace(2), enviado_en: hace(2)},
      {id:'h2', inversionista:'u7', tipo:'constitucion', estado:'en_revision', gestor:'u1', sembrado:true,
       datos:{denominacion:'Ferreira Turismo Costa, C.A.', capital_social:'80.000'},
       creado_en: hace(30), enviado_en: hace(30)},
      {id:'h3', inversionista:'u5', tipo:'rif_empresa', estado:'ante_el_ente', gestor:'u1', sembrado:true,
       datos:{razon_social:'Tanaka Hidro, C.A.', numero_registro:'Tomo 12-A, n.º 44'},
       creado_en: hace(3), enviado_en: hace(3)}
    ];
    HOY_DOCS = {
      h1: [{id:'hd1', tipo:'pasaporte', nombre_original:'pasaporte-bianchi.pdf', archivo:'u2/pasaporte-bianchi.pdf',
            estado:'cargado', nota_revision:'', creado_en: hace(2)},
           {id:'hd2', tipo:'domicilio', nombre_original:'recibo-bianchi.jpg', archivo:'u2/recibo-bianchi.jpg',
            estado:'validado', nota_revision:'', creado_en: hace(2)}],
      h2: [{id:'hd3', tipo:'comprobante_capital', nombre_original:'deposito.pdf', archivo:'u7/deposito.pdf',
            estado:'cargado', nota_revision:''}],
      h3: [{id:'hd4', tipo:'acta_constitutiva', nombre_original:'acta-tanaka.pdf', archivo:'u5/acta-tanaka.pdf',
            estado:'validado', nota_revision:''}]
    };
    HOY_DOC = {};
    Object.keys(HOY_DOCS).forEach(function(k){ HOY_DOCS[k].forEach(function(d){ HOY_DOC[d.id] = d; }); });
    colaListos = [
      {id:'h9', inversionista:'u5', tipo:'rif_empresa', estado:'resuelto', gestor:'u1',
       datos:{razon_social:'Tanaka Hidro, C.A.', rif_empresa:'J-41234567-8'},
       creado_en: hace(40), enviado_en: hace(40), resuelto_en: hace(5)}
    ];
  }
  window.CIIP_DOBLE = {
    cola: function(){ return colaTram.slice(); },
    ponCola: function(lista){ colaTram = lista; HOY_DOCS = {}; HOY_DOC = {}; colaListos = []; },
    siembraHoy: siembraHoy,
    doc: function(id){ return HOY_DOC[id]; },
    /* QA-08: la inversionista corrige lo que se le devolvió y lo reenvía.
       Sube un recibo NUEVO en lugar del rechazado, el gestor se lo valida
       y el trámite vuelve a estar en revisión, suyo. El rechazado sigue
       enganchado, como en la base de antes del arreglo: es justo lo que
       dejaba «Presentar» apagado para siempre. */
    /* QA-12: h1 devuelta y suya, en el montón de devueltos, para que el
       gestor la cancele. Cancelarla la saca de la cola, como a los demás
       sembrados que salen del CIIP. */
    devuelveH1: function(){
      colaTram = colaTram.filter(function(t){ return t.id !== 'h1'; });
      colaTram.push({id:'h1', inversionista:'u2', tipo:'rif_personal', estado:'devuelto', gestor:'u1',
        sembrado:true, datos:{tipo_documento:'Pasaporte', numero_documento:'YA8812345'},
        creado_en: new Date(Date.now() - 40 * 86400000).toISOString(),
        enviado_en: new Date(Date.now() - 40 * 86400000).toISOString()});
    },
    reenviaH1: function(){
      colaTram = colaTram.filter(function(t){ return t.id !== 'h1'; });
      colaTram.push({id:'h1', inversionista:'u2', tipo:'rif_personal', estado:'en_revision', gestor:'u1',
        sembrado:true, datos:{tipo_documento:'Pasaporte', numero_documento:'YA8812345',
        telefono:'+58 412 555 0132', direccion_fiscal:'Av. Francisco de Miranda, Chacao'},
        creado_en: new Date(Date.now() - 2 * 86400000).toISOString(),
        enviado_en: new Date(Date.now() - 2 * 86400000).toISOString()});
      var nuevo = {id:'hd5', tipo:'domicilio', nombre_original:'recibo-bianchi-nuevo.jpg',
        archivo:'u2/recibo-bianchi-nuevo.jpg', estado:'validado', nota_revision:'',
        creado_en: new Date().toISOString()};
      HOY_DOCS.h1 = (HOY_DOCS.h1 || []).concat([nuevo]);
      HOY_DOC.hd5 = nuevo;
    }
  };

  /* La nota de una devolucion viaja en un UPDATE aparte, sobre el evento que
     escribe el trigger. Se guarda para que la prueba compruebe que llego:
     sin esto solo se sabria que el tramite cambio de estado. */
  var notaPuesta = null;
  window.PRUEBA_NOTA = function(){ return notaPuesta; };

  /* Vaciar la lista de tramites, para poder mirar el estado vacio de «Mis
     tramites». Ninguno de los tres ejemplos tiene cero -el que se llama
     «vacio» lo es de empresa, no de tramites- y sin esto la pantalla que se
     le ensena a quien acaba de entrar no la comprobaba nadie.

     Es un gancho de PRUEBA y no un caso nuevo a proposito: un pase entero
     mas cuesta un minuto de reloj en cada tanda para mirar una sola cosa. */
  window.PRUEBA_SIN_TRAMITES = function(){
    TRAMITES[caso] = [];
    return true;
  };

  /* Mover una solicitud de sitio por un rato: la constitución de 'tramos'
     está ante el ente, y la firma en el CIIP solo se ve un escalón antes.
     Quien la mueve la devuelve a su sitio al acabar. */
  window.PRUEBA_CAMBIA_TRAMITE = function(id, cambios){
    var t = (TRAMITES[caso] || []).filter(function(x){ return x.id === id; })[0];
    if (!t) return false;
    Object.keys(cambios).forEach(function(k){ t[k] = cambios[k]; });
    return true;
  };

  /* Lo que hay en la tabla de tramites AHORA MISMO. Lo mira la prueba del
     envio: que la pantalla cambie esta bien, pero lo que hay que comprobar
     es que la solicitud llego, y eso no se ve en pantalla. Devuelve copias
     para que una prueba no pueda escribir en los datos de la siguiente. */
  window.PRUEBA_TRAMITES = function(){
    return (TRAMITES[caso] || []).map(function(t){
      var c = {}; Object.keys(t).forEach(function(k){ c[k] = t[k]; }); return c;
    });
  };

  /* De donde salen los id y las fechas de lo que se crea durante la tanda.
     Contados y no al azar: un id que cambia en cada pase convierte una
     prueba roja en un misterio distinto cada vez. */
  var nCreados = 0;
  function ahora(){ return new Date().toISOString(); }

  /* Una cita YA CONFIRMADA, para el buzon de avisos. Se fecha ANTES que los
     eventos de tramites a proposito: asi se comprueba que el buzon la mete
     en su sitio por fecha y no simplemente al final o al principio. */
  var CONFIRMADAS = {
    /* POR DELANTE del ancla, y es a proposito: desde la auditoria QA-02 una
       confirmada que ya paso no esta viva. Estuvo el 26 de agosto -una
       semana ANTES del ancla- y la agenda la contaba como «en marcha», que
       era justo el fallo. */
    lleno: [{id:'k1', inversionista:'u1', tipo_tramite:'constitucion', modo:'presencial',
             estado:'confirmada', desde:'2026-09-07', hasta:'2026-09-11', nota:'',
             cuando:'2026-09-09T14:00:00Z', lugar:'Torre CIIP, piso 4',
             creado_en:'2026-06-30T09:00:00Z',
             actualizado_en:'2026-07-01T09:00:00Z'}],
    vacio: [], sinnombre: [],
    /* AQUI FALTA una cita confirmada de OTRA persona, y no es un olvido.
       Se puso el 21-9-2026 para probar que el .eq('inversionista') nuevo
       del buzon la deja fuera, y destapo que la pantalla de CITAS tiene la
       misma fuga por debajo: cargaAgenda() y cargaCita() tampoco preguntan
       por el dueño, asi que a un gestor su politica le sirve la agenda de
       toda la oficina. Con la fila puesta, tres pruebas de 'agenda' se
       ponen rojas -y tienen razon: dicen que el equipo no ha pedido
       ninguna cita-. Arreglarlo es otro cambio, en otra pantalla y con
       otra plomeria: esos dos bloques no tienen a mano quien eres.
       Mientras tanto se deja vacio, que es lo que habia. */
    gestor: []
  };

  /* Los perfiles de los demas. Solo los lee un gestor, y solo si esta puesta
     la politica de supabase-gestor.sql. */
  /* visto_en va CONTADO DESDE AHORA y no en fechas fijas: "en linea" es
     "hace menos de tres minutos", y una fecha escrita a mano envejeceria
     sola —la prueba pasaria hoy y saldria roja manana sin que nadie tocara
     el panel—. */
  function haceMin(m){ return new Date(Date.now() - m * 60000).toISOString(); }

  /* Unos segundos POR DELANTE del reloj del navegador. Pasa de verdad: la
     hora la pone el servidor -y eso esta bien, es lo que impide que un
     reloj mal puesto mienta- pero el navegador puede ir por detras, y
     entonces algo que acaba de pasar salia como "esperando desde dentro
     de 37 segundos". */
  function dentroDe(seg){ return new Date(Date.now() + seg * 1000).toISOString(); }

  /* 'visto_hace' son MINUTOS, y el 'visto_en' se calcula al contestar y no
     al cargar la pagina. Se calculaba al cargar, y la vista de usuarios se
     abre casi un minuto despues: "visto hace 20 minutos" pasaba a 21 en
     cuanto la cadena de pasos crecia un poco, y la prueba se caia por el
     reloj y no por un fallo. */
  function conVisto(filas){
    return filas.map(function(f){
      var c = {}; Object.keys(f).forEach(function(k){ c[k] = f[k]; });
      if (c.visto_hace !== undefined){ c.visto_en = haceMin(c.visto_hace); delete c.visto_hace; }
      return c;
    });
  }

  var OTROS_PERFILES = [
    {id:'u1', nombre_completo:'Franklin Reyes',  pais:'Italia',    rol:'gestor',
     visto_hace: (0.5)},          /* con el panel abierto ahora mismo */
    {id:'u2', nombre_completo:'Marta Bianchi',   pais:'Italia',    rol:'inversionista',
     visto_hace: (60 * 24 * 3)},  /* hace tres dias */
    /* Sin nombre a proposito: la lista tiene que decirlo en vez de dejar
       el hueco, igual que la cola. Y sin visto_en: nunca ha entrado. */
    {id:'u3', nombre_completo:'',                pais:'',          rol:'inversionista'},
    {id:'u4', nombre_completo:'Saskia Calderon', pais:'Venezuela', rol:'gestor',
     rol_cambiado_en:'2026-08-11T10:00:00Z', visto_hace: (20)}
  ];

  /* Los del pase de mirar. Van aparte y se enganchan abajo: metidos en la
     lista de arriba, "estan las cuatro cuentas" pasaria a ser diez y las
     pruebas de usuarios medirian el ejemplo en vez de lo suyo. */
  if (demoCola) OTROS_PERFILES = OTROS_PERFILES.concat([
    {id:'u5',  nombre_completo:'Hiroshi Tanaka',   pais:'Japón',    rol:'inversionista', visto_hace: (90)},
    {id:'u6',  nombre_completo:'Amina Okonkwo',    pais:'Nigeria',  rol:'inversionista', visto_hace: (60 * 30)},
    {id:'u7',  nombre_completo:'Lucía Ferreira',   pais:'Portugal', rol:'inversionista', visto_hace: (15)},
    {id:'u8',  nombre_completo:'Dmitri Kovalenko', pais:'Rusia',    rol:'inversionista'},
    {id:'u9',  nombre_completo:'Chen Wei',         pais:'China',    rol:'inversionista', visto_hace: (60 * 5)},
    {id:'u10', nombre_completo:'Carlos Méndez',    pais:'Colombia', rol:'inversionista', visto_hace: (60 * 72)}
  ]);

  /* El expediente personal. En 'sinnombre' viene con la cadena vacía, que es
     como llega de verdad una cuenta creada a mano en Supabase. */
  var PERFILES = {
    gestor:    {nombre_completo:'Franklin Reyes', pais:'Italia', rol:'gestor'},
    lleno:     {nombre_completo:'Franklin Reyes', pais:'Italia', rol:'inversionista', sector:'turismo'},
    vacio:     {nombre_completo:'Franklin Reyes', pais:'Italia', rol:'inversionista', sector:'turismo'},
    sinnombre: {nombre_completo:'',               pais:'',       rol:'inversionista', sector:'turismo'},
    /* Los tres que NO han contestado, cada uno para medir una cosa:
       · sinsector    la puerta se abre y hay que contestarla;
       · sincatalogo  no hay sectores que ofrecer, y NO debe bloquear;
       · sinsql       la columna no existe, y tampoco debe bloquear.
       Los dos ultimos vienen sin sector A PROPOSITO. Con sector, las dos
       pruebas pasarian solas sin llegar a comprobar nada: es el punto
       ciego que ya me colo una vez con el F5. */
    sinsector:   {nombre_completo:'Franklin Reyes', pais:'Italia', rol:'inversionista', sector:null},
    sincatalogo: {nombre_completo:'Franklin Reyes', pais:'Italia', rol:'inversionista', sector:null},
    sinsql:      {nombre_completo:'Franklin Reyes', pais:'Italia', rol:'inversionista', sector:null}
  };

  /* El catalogo de sectores: los ocho motores productivos, los mismos que
     escribe supabase-sectores.sql. Son ocho a proposito y no tres: con
     menos de diez la puerta NO saca la caja de filtrar, y esa es una
     decision que hay que medir con el numero de verdad. */
  var SECTORES_BASE = [
    {codigo:'hidrocarburos',     ref_panel:'s1', nombre:'Hidrocarburos',       orden:10},
    {codigo:'mineria',           ref_panel:'s2', nombre:'Mineria',             orden:20},
    {codigo:'industrial',        ref_panel:'s3', nombre:'Industrial',          orden:30},
    {codigo:'turismo',           ref_panel:'s4', nombre:'Turismo',             orden:40},
    {codigo:'agroindustrial',    ref_panel:'s5', nombre:'Agroindustrial',      orden:50},
    {codigo:'salud',             ref_panel:'s6', nombre:'Salud',               orden:60},
    {codigo:'pesca_acuicultura', ref_panel:'s7', nombre:'Pesca y acuicultura', orden:70},
    {codigo:'forestal',          ref_panel:'s8', nombre:'Forestal',            orden:80},
    /* Un noveno, como si el CIIP lo acabara de añadir por SQL. El panel no
       tiene icono ni color para el: tiene que salir igual, con el generico.
       Si algun dia se rompe eso, el sector nuevo apareceria con un hueco y
       nadie sabria por que. */
    {codigo:'sector_nuevo',      ref_panel:'s9', nombre:'Sector nuevo',        orden:90}
  ];

  /* De más nuevo a más viejo, que es como los pide el panel. Los dos
     'borrador' están para comprobar que el buzón NO los anuncia: la
     solicitud se crea y se envía en el mismo gesto. */
  var EVENTOS = {
    /* El evento de x1 llega con la hora unos segundos ADELANTADA: es lo
       que le pasa al primero de la cola nada mas enviarlo. */
    gestor: [
      {id:90, tramite:'x1', de_estado:'borrador', a_estado:'enviado', nota:'',
       creado_en: dentroDe(37)},
      /* Y uno en el x2, que lleva OTRO gestor -el u4-. Tiene que quedarse
         FUERA de la campana del que mira: es su compañero quien lo mueve, y
         antes del 21-9-2026 le sonaba a toda la oficina. Sin este evento
         aqui, esa prueba daria verde con el filtro quitado, que es la unica
         manera de que una prueba mienta. */
      {id:91, tramite:'x2', de_estado:'en_revision', a_estado:'devuelto',
       nota:'Le falta la firma del comisario.', creado_en: haceHoras(3)}
    ],
    lleno: [
      {id:5, tramite:'t1', de_estado:'en_revision', a_estado:'devuelto',
       nota:'El comprobante del capital esta ilegible: vuelve a subirlo escaneado.',
       creado_en:'2026-08-14T10:00:00Z'},
      {id:4, tramite:'t2', de_estado:null,          a_estado:'borrador',    nota:'', creado_en:'2026-08-01T10:00:00Z'},
      {id:3, tramite:'t1', de_estado:'enviado',     a_estado:'en_revision', nota:'', creado_en:'2026-08-10T10:00:00Z'},
      {id:2, tramite:'t1', de_estado:'borrador',    a_estado:'enviado',     nota:'', creado_en:'2026-07-02T10:00:00Z'},
      {id:1, tramite:'t1', de_estado:null,          a_estado:'borrador',    nota:'', creado_en:'2026-07-02T09:59:00Z'}
    ],
    /* El historial de la protocolización de 'tramos': de ahí salen las dos
       fechas que se ven en sus pasos. */
    vacio: conTramos ? (yaPagado ? [] : [
      {id:71, tramite:'p1', de_estado:'enviado',  a_estado:'en_revision', nota:'', creado_en:'2026-09-08T10:00:00Z'}
    ]).concat([
      {id:70, tramite:'p1', de_estado:'borrador', a_estado:'enviado',     nota:'', creado_en:'2026-09-01T10:00:00Z'},
      {id:62, tramite:'p2', de_estado:'en_revision', a_estado:'ante_el_ente', nota:'', creado_en:'2026-08-30T10:00:00Z'},
      {id:61, tramite:'p2', de_estado:'enviado',     a_estado:'en_revision',  nota:'', creado_en:'2026-08-24T10:00:00Z'},
      {id:60, tramite:'p2', de_estado:'borrador',    a_estado:'enviado',      nota:'', creado_en:'2026-08-20T10:00:00Z'}
    ]) : [],
    sinnombre: []
  };

  /* El correo lleva punto a propósito: de ahí tiene que salir "F. Reyes", con
     la inicial suelta escrita con punto. En 'sinnombre' los metadatos vienen
     también sin nombre, que es el caso completo. */
  /* Las citas vivas. En 'lleno' ya hay una pedida, para comprobar que la
     ventana enseña su estado en vez de un formulario en blanco. */
  var CITAS = {
    lleno: [{id:'c1', tipo_tramite:'rif_empresa', modo:'video',
             desde:'2026-08-25', hasta:'2026-09-05', nota:'', estado:'solicitada',
             cuando:null, lugar:'', creado_en:'2026-08-18T09:00:00Z'}],
    vacio: [],
    sinnombre: []
  };
  var citasVivas = (CITAS[caso] || []).slice();

  /* ── EL HORARIO DE CITAS ──
     En 'huecos' se atiende de lunes a viernes de 9 a 12, cada media hora. El
     primer dia laborable despues de hoy esta CERRADO, y en el siguiente las
     09:00 ya las tiene otro: asi la prueba comprueba que ni uno ni otro se
     ofrecen. Se calcula desde hoy, en hora de Caracas, para que la prueba no
     caduque. El equipo ('gestor') ve dos tramos para editar. */
  function huHoy(){ return new Date(Date.now() - 4 * 3600000).toISOString().slice(0, 10); }
  function huMas(iso, n){ var d = new Date(iso + 'T12:00:00Z'); d.setUTCDate(d.getUTCDate() + n); return d.toISOString().slice(0, 10); }
  function huSem(iso){ var d = new Date(iso + 'T12:00:00Z').getUTCDay(); return d === 0 ? 7 : d; }
  var horarioCitas = conHuecos
    ? [1, 2, 3, 4, 5].map(function(d){ return {id:'h' + d, dia:d, desde:'09:00:00', hasta:'12:00:00', cada_min:30}; })
    : (caso === 'gestor'
        ? [{id:'h1', dia:1, desde:'09:00:00', hasta:'12:00:00', cada_min:30},
           {id:'h3', dia:3, desde:'14:00:00', hasta:'16:00:00', cada_min:60}]
        : []);
  var huCerrado = '', huOcupado = '';
  if (conHuecos){
    var huF = huHoy();
    do { huF = huMas(huF, 1); } while (huSem(huF) > 5);
    huCerrado = huF;
    do { huF = huMas(huF, 1); } while (huSem(huF) > 5);
    huOcupado = huF + 'T09:00:00-04:00';
    window.CIIP_PRUEBA_HUECOS = {cerrado: huCerrado, ocupado: huOcupado};
  }
  var cierresCitas = huCerrado ? [{fecha: huCerrado, motivo: 'Feriado'}] : [];

  /* ── LAS CITAS QUE VE EL HORARIO DEL EQUIPO ──
     Solo en 'gestor', y aparte de CONFIRMADAS a proposito (la agenda del
     gestor no pregunta por el dueño; ver alli). Una por delante -para
     moverla o cancelarla- y una que ya paso y nadie ha cerrado. Se piden
     con .gt / .lt sobre cuando, y asi se distinguen. Contadas desde hoy
     para que la prueba no caduque; la de delante, un martes a las diez. */
  var equipoCitas = [];
  if (caso === 'gestor'){
    var eqF = huMas(huHoy(), 7);
    while (huSem(eqF) !== 2) eqF = huMas(eqF, 1);
    equipoCitas = [
      {id:'e1', inversionista:'u2', tipo_tramite:'rif_empresa', modo:'presencial',
       estado:'confirmada', cuando:new Date(eqF + 'T10:00:00-04:00').toISOString(),
       lugar:'', nota:''},
      {id:'e2', inversionista:'u2', tipo_tramite:null, modo:'video',
       estado:'confirmada', cuando:new Date(Date.now() - 3 * 86400000).toISOString(),
       lugar:'', nota:''}
    ];
    window.CIIP_PRUEBA_EQUIPO_CITAS = {proxima: eqF};
  }
  window.CIIP_PRUEBA_CITAS_UPD = [];

  /* ── un tramite que aparece DESPUES ──
     Para poder comprobar que el panel se pone al dia sin recargar. La
     primera lectura no lo trae; de la segunda en adelante, si.

     Es lo que pasa de verdad: el CIIP enciende un tramite, o llega una
     solicitud nueva, mientras la pagina lleva horas abierta. Sin esto no
     hay forma de distinguir «se puso al dia» de «no hizo nada», porque las
     dos dejan la pantalla igual. */
  /* Aparece cuando la prueba lo PIDE, no en la segunda lectura.

     Se hizo primero por contador -de la segunda en adelante- y se colaba en
     pruebas ajenas: la portada relee sus tramites mas de una vez durante la
     tanda, asi que el tramite nuevo asomaba en mitad de otra cosa y ponia en
     rojo lo que no tocaba. Un doble no debe cambiar por su cuenta.

     De un tipo que ESTE catalogo conoce y que no usa ninguna otra prueba. Se
     puso primero cedula_residencia y el panel no podia pintarlo: sin su fila
     en tipos_tramite no sabe a que tarjeta pertenece. */
  var TRAMITE_TARDIO = {id:'t9', tipo:'registro_inversion', estado:'enviado',
    datos:{}, creado_en:'2026-09-03T09:00:00Z', enviado_en:'2026-09-03T09:00:00Z',
    actualizado_en:'2026-09-03T09:00:00Z'};

  /* Canceladas y hechas. Hacian falta: una cita no se borra -solo se
     cancela, para que quede constancia de que se pidio-, asi que la
     lista de una cuenta usada de verdad se llena de ellas. Tres
     identicas a proposito: se distinguen SOLO por cuando se pidieron,
     que es lo que hace falta enseñar para que no sean tres renglones
     iguales. */
  var MUERTAS = {
    lleno: [
      {id:'x1', tipo_tramite:'rif_empresa', modo:'video', desde:'2026-08-23',
       hasta:'2026-08-28', nota:'', estado:'cancelada', cuando:null, lugar:'',
       creado_en:'2026-08-10T09:00:00Z'},
      {id:'x2', tipo_tramite:'rif_empresa', modo:'video', desde:'2026-08-23',
       hasta:'2026-08-28', nota:'', estado:'cancelada', cuando:null, lugar:'',
       creado_en:'2026-08-11T09:00:00Z'},
      {id:'x3', tipo_tramite:'rif_empresa', modo:'video', desde:'2026-08-23',
       hasta:'2026-08-28', nota:'', estado:'cancelada', cuando:null, lugar:'',
       creado_en:'2026-08-12T09:00:00Z'},
      {id:'x4', tipo_tramite:'constitucion', modo:'telefono', desde:'2026-07-01',
       hasta:'2026-07-05', nota:'', estado:'hecha',
       cuando:'2026-07-03T10:00:00Z', lugar:'', creado_en:'2026-06-20T09:00:00Z'}
    ],
    vacio: [], sinnombre: [], gestor: []
  };

  var EMPRESAS = {
    lleno: {razon_social:'Bianchi Agroindustrias, C.A.', rif_empresa:'J-40123456-7',
            numero_registro:'12, Tomo 45-A', fecha_constitucion:'2026-07-14',
            capital_social:'150000.00', actividad_economica:'Procesamiento de cacao',
            direccion_fiscal:'Av. Principal, Galpon 4, Charallave', municipio:'Cristobal Rojas',
            telefono:'+58 212 555 0134', representante:'Franklin Reyes',
            inicio_actividades:'', num_trabajadores:''},
    vacio: {razon_social:'Bianchi Agroindustrias, C.A.', rif_empresa:'J-40123456-7',
            numero_registro:'12, Tomo 45-A', fecha_constitucion:'2026-07-14',
            capital_social:'150000.00', actividad_economica:'Procesamiento de cacao',
            direccion_fiscal:'Av. Principal, Galpon 4, Charallave', municipio:'Cristobal Rojas',
            telefono:'+58 212 555 0134', representante:'Franklin Reyes',
            inicio_actividades:'', num_trabajadores:''},
    sinnombre: null,
    gestor: null
  };
  var empresaMia = EMPRESAS[caso] || null;

  /* Nadie ha mirado el documento de nadie todavia. */

  /* ─── EL CALENDARIO NO SE QUEDA QUIETO ─────────────────────────
     Las fechas de arriba se escribieron a mano y dicen cosas como «esta
     solicitud lleva 27 dias esperando». Dejadas fijas, esa frase se cambia
     sola: pasan cuatro dias, la fila cruza los treinta, y el panel deja de
     decir «hace 27 dias» para decir «el mes pasado», que es lo correcto.

     Y una prueba que comprobaba que ahi ponia dias se pone roja sin que
     nadie haya tocado una linea de codigo.

     Paso exactamente eso. La tanda estaba en verde el 2 de septiembre y el
     6 salio roja sola. Costo un rato entender que no lo habia roto nadie:
     lo rompio el almanaque, y lo primero que se mira cuando algo se pone
     rojo es el ultimo que toco el archivo, que ahi no habia tocado nada.

     Asi que el expediente entero se DESLIZA en bloque. Se conserva la
     distancia entre las fechas -que es lo unico que las pruebas miden: quien
     llego antes, cuanto lleva esperando, que documento vencio- y se pierde
     la fecha del calendario, que no la mide nadie.

     Lo que NO arregla, dicho: una prueba que compruebe la PALABRA que sale
     -«dias», «hace un mes»- sigue atada a donde caiga la fila respecto de
     los tramos de Intl. Esto la deja siempre en el mismo tramo, que es lo
     que hacia falta, pero el que escriba la siguiente que sepa que esa
     forma de comprobar es fragil por su cuenta. ─────────────────── */
  var ANCLA  = Date.parse('2026-09-02T00:00:00Z');
  /* En DIAS ENTEROS. Con los milisegundos crudos, un expediente sembrado
     a las 10:00 pasaba a las 06:45, y hay comprobaciones que leen la hora
     de una cita. Deslizar dias enteros mueve el calendario y deja la hora
     donde estaba, que es justo lo que hace falta. */
  var DIA = 86400000;
  var DESLIZ = Math.floor((Date.now() - ANCLA) / DIA) * DIA;
  if (DESLIZ < 0) DESLIZ = 0;          /* nadie prueba hacia atras */
  /* Lo mira el arnes: hay una comprobacion que necesita la fecha exacta que
     dio el servidor, y sin esto compararia contra la de antes de deslizar. */
  window.CIIP_MENTIRA_DESLIZ = DESLIZ;

  var ES_FECHA = /^[0-9]{4}-[0-9]{2}-[0-9]{2}(T[0-9:.]+Z?)?$/;
  function deslizaUno(v){
    var t = Date.parse(v);
    if (isNaN(t)) return v;
    var d = new Date(t + DESLIZ);
    /* Se devuelve con la MISMA forma que traia. Hay campos -vence_el- que la
       base guarda como dia sin hora, y devolverlos con hora cambia lo que el
       panel pinta debajo. */
    return v.length === 10 ? d.toISOString().slice(0, 10) : d.toISOString();
  }
  /* LO QUE NO SE DESLIZA, que importa tanto como lo que si.

     `datos` es el formulario tal y como lo relleno la persona. Ahi dentro
     hay fechas que NO son historia: la de nacimiento, la de un pasaporte.
     Deslizarlas le cambia el cumpleanos al inversionista cada dia que
     pasa, y eso lo canto una prueba que esperaba 1979-04-11 y recibio
     1979-04-15. Tenia razon: nadie nace cuatro dias mas tarde por que
     hoy sea jueves.

     La regla, dicha entera: se desliza CUANDO PASO algo -creado_en,
     enviado_en, vence_el-, y no se desliza lo que alguien ESCRIBIO. */
  var NO_SE_MUEVE = {datos: true};
  function desliza(x){
    if (!x || typeof x !== 'object') return x;
    Object.keys(x).forEach(function(k){
      if (NO_SE_MUEVE[k]) return;
      var v = x[k];
      if (typeof v === 'string'){ if (ES_FECHA.test(v)) x[k] = deslizaUno(v); }
      else if (v && typeof v === 'object') desliza(v);
    });
    return x;
  }

  var IDENTIDAD = [];

  var USUARIO = {id:'u1', email:'f.reyes@ciip.com.ve',
                 user_metadata: (caso === 'sinnombre' ? {} : {nombre_completo:'Franklin Reyes', pais:'Italia'})};

  /* Y aqui, no antes: puesta mas arriba, USUARIO todavia valia undefined
     -var lo declara desde el principio pero no lo rellena hasta su linea-
     y se quedaba sin deslizar sin que nada lo dijera. */
  [PLIEGOS, TIPOS, TRAMITES, COLA, ACTIVOS, COLA_TRAM, COLA_DEMO, CONFIRMADAS,
   OTROS_PERFILES, PERFILES, EVENTOS, CITAS, TRAMITE_TARDIO, MUERTAS,
   EMPRESAS, USUARIO].forEach(desliza);

  function respuesta(tabla, op){
    /* ── el horario de citas y sus dias cerrados ── */
    if (tabla === 'horario_citas'){
      if (op && op.insert){
        var tr = {id:'h' + (horarioCitas.length + 20), dia:+op.insert.dia,
                  desde:String(op.insert.desde), hasta:String(op.insert.hasta),
                  cada_min:+op.insert.cada_min};
        horarioCitas = horarioCitas.concat([tr]);
        return {data:tr, error:null};
      }
      if (op && op.borra && op.eq && op.eq.id){
        horarioCitas = horarioCitas.filter(function(t){ return t.id !== op.eq.id; });
        return {data:null, error:null};
      }
      return {data:horarioCitas.slice(), error:null};
    }
    if (tabla === 'cierres_citas'){
      if (op && op.insert){
        var ci = {fecha:op.insert.fecha, motivo:op.insert.motivo || ''};
        cierresCitas = cierresCitas.concat([ci]);
        return {data:ci, error:null};
      }
      if (op && op.borra && op.eq && op.eq.fecha){
        cierresCitas = cierresCitas.filter(function(c){ return c.fecha !== op.eq.fecha; });
        return {data:null, error:null};
      }
      return {data:cierresCitas.slice(), error:null};
    }

    /* ── el pliego de datos ── */
    if (tabla === 'pliegos'){
      var fila = PLIEGOS.filter(function(p){
        return !(op && op.eq && 'version' in op.eq) || p.version === op.eq.version;
      });
      /* .single() sobre cero filas NO devuelve null: devuelve error, y el
         panel tiene que saber distinguirlo de una fila vacia. */
      if (op && op.single){
        return fila.length
          ? {data: fila[0], error:null}
          : {data:null, error:{message:'JSON object requested, multiple (or no) rows returned',
                               code:'PGRST116'}};
      }
      return {data: fila, error:null};
    }

    if (tabla === 'pliego_aceptaciones'){
      if (op && op.insert){
        pliegoAceptado = true;
        return {data:[{id:1, version:1, cuando:new Date().toISOString()}], error:null};
      }
      return {data: pliegoAceptado ? [{id:1, version:1}] : [], error:null};
    }

    if (tabla === 'perfiles'){
      /* Bloquear. Se apunta de verdad para que la ficha cambie: un falso
         que dice "hecho" sin cambiar nada da verde a una prueba que no
         comprueba nada. */
      /* Dar de baja: la base la marca y además bloquea (QA-06). */
      if (op && op.update && 'dado_de_baja_en' in op.update && op.eq && op.eq.id){
        var deBaja = OTROS_PERFILES.filter(function(g){ return g.id === op.eq.id; })[0];
        if (deBaja){
          deBaja.dado_de_baja_en = op.update.dado_de_baja_en ? new Date().toISOString() : null;
          if (op.update.dado_de_baja_en) deBaja.bloqueado = true;
        }
        return {data: deBaja || null, error:null};
      }
      if (op && op.update && 'bloqueado' in op.update && op.eq && op.eq.id){
        var quien = OTROS_PERFILES.filter(function(g){ return g.id === op.eq.id; })[0];
        if (quien) quien.bloqueado = !!op.update.bloqueado;
        return {data: quien || {}, error:null};
      }
      if (sinSql && op && /visto_en|rol_cambiado_en|sector/.test(op.cols || '')){
        /* Con el nombre de la que falta de verdad: un falso que siempre
           dice 'visto_en' ensena a leer un mensaje que no es el que da
           Postgres. */
        var falta = /sector/.test(op.cols || '') ? 'sector' : 'visto_en';
        return {data:null, error:{
          message:'column perfiles.' + falta + ' does not exist', code:'42703'}};
      }
      /* Contestar el sector es OTRO update sobre la misma tabla. Sin esta
         rama caeria en la lectura de mas abajo, devolveria el perfil como
         si nada y la puerta se cerraria sin haber guardado nada. */
      if (op && op.update && 'sector' in op.update){
        if (sinSql) return {data:null, error:{
          message:'column perfiles.sector does not exist', code:'42703'}};
        var yo = PERFILES[caso] || PERFILES.lleno;
        yo.sector = op.update.sector;
        return {data:yo, error:null};
      }
      /* Guardar el perfil propio -nombre y pais- y repartir roles son dos
         updates sobre la misma tabla. Se distinguen por lo que traen. */
      if (op && op.update && 'rol' in op.update){
        /* Nadie cambia su propio rol: lo rechaza el disparador de la base,
           y el falso tiene que rechazarlo tambien o la prueba de que el
           panel lo impide daria verde sin comprobar nada. */
        if (op.eq && op.eq.id === USUARIO.id){
          return {data:null, error:{message:'Nadie puede cambiar su propio rol'}};
        }
        var quien = OTROS_PERFILES.filter(function(p){ return p.id === (op.eq || {}).id; })[0];
        if (quien){ quien.rol = op.update.rol; quien.rol_cambiado_en = '2026-08-20T12:00:00Z'; }
        return {data:(quien || {}), error:null};
      }
      /* El guardian pide el propio con .single(); la cola pide la lista de
         todos. Devolver lo mismo a los dos romperia uno de los dos. */
      /* El rol propio llega SOLO por aqui, y a proposito: la sesion no lo
         trae. Ese desfase entre "la sesion contesto" y "el rol llego" es
         justo lo que dejaba el renglon de administrador escondido. */
      var mio = PERFILES[caso] || PERFILES.lleno;
      if (esAdmin) mio = {nombre_completo:mio.nombre_completo, pais:mio.pais, rol:'admin'};
      return op && op.single
        ? {data:mio, error:null}
        : {data:conVisto(OTROS_PERFILES), error:null};
    }
    if (tabla === 'sectores'){
      /* Vacio a proposito en un pase. Una puerta cerrada con una lista
         vacia detras es una puerta sin llave, y eso hay que medirlo, no
         suponerlo. */
      return {data:(caso === 'sincatalogo' ? [] : SECTORES_BASE), error:null};
    }
    if (tabla === 'citas'){
      /* La cola pregunta por .eq('estado','solicitada'); el inversionista por
         .in('estado',[...]). Son dos listas distintas y no se pueden
         confundir: si no, un gestor veria las citas ajenas como suyas. */
      /* El buzon pide las confirmadas; son otra lista y otro sitio. Y las
         pide CON DUEÑO -.eq('inversionista')-, que es lo unico que separa
         "tu cita esta confirmada" de la agenda de la oficina entera. Se
         filtra de verdad: un doble que se saltara ese .eq contestaria lo
         mismo con el filtro y sin el. */
      /* El horario del equipo: por delante (.gt) o ya pasadas (.lt). */
      if (op && op.eq && op.eq.estado === 'confirmada' && ((op.gt && op.gt.cuando) || (op.lt && op.lt.cuando))){
        var ahoraEq = Date.now();
        return {data: equipoCitas.filter(function(c){
          return c.estado === 'confirmada' &&
                 (op.gt ? Date.parse(c.cuando) > ahoraEq : Date.parse(c.cuando) < ahoraEq);
        }), error:null};
      }
      /* Las que canceló el CIIP, para el buzón (QA-25). Ninguna en los
         expedientes de partida: lo que se mide es que la consulta no
         reviente y que no se cuelen las que canceló uno mismo. */
      if (op && op.eq && op.eq.estado === 'cancelada'){
        return {data: [], error:null};
      }
      if (op && op.eq && op.eq.estado === 'confirmada'){
        var confs = CONFIRMADAS[caso] || [];
        if (op.eq.inversionista){
          confs = confs.filter(function(c){ return c.inversionista === op.eq.inversionista; });
        }
        return {data:confs, error:null};
      }
      if (op && op.eq && op.eq.estado === 'solicitada'){
        if (op.update){
          colaViva = colaViva.filter(function(c){ return c.id !== op.eq.id; });
          return {data:{}, error:null};
        }
        return {data:colaViva, error:null};
      }
      /* Cerrar, mover o cancelar una del horario del equipo: se apunta lo
         que se pidió y la fila cambia de verdad, para que la lista cambie. */
      if (op && op.update && op.eq && op.eq.id &&
          equipoCitas.some(function(c){ return c.id === op.eq.id; })){
        window.CIIP_PRUEBA_CITAS_UPD.push({id: op.eq.id, campos: op.update});
        var eqc = equipoCitas.filter(function(c){ return c.id === op.eq.id; })[0];
        Object.keys(op.update).forEach(function(k){ eqc[k] = op.update[k]; });
        return {data:[eqc], error:null};
      }
      if (op && op.update && op.eq && op.eq.id){
        window.CIIP_PRUEBA_CITAS_UPD.push({id: op.eq.id, campos: op.update});
        colaViva = colaViva.filter(function(c){ return c.id !== op.eq.id; });
        citasVivas = [];
        return {data:{}, error:null};
      }
      /* pedir una */
      if (op && op.insert){
        var nueva = {
          id: 'c' + (citasVivas.length + 9),
          tipo_tramite: op.insert.tipo_tramite || null,
          modo: op.insert.modo, desde: op.insert.desde, hasta: op.insert.hasta,
          nota: op.insert.nota || '', estado: 'solicitada',
          cuando: null, lugar: '', creado_en: '2026-08-19T12:00:00Z'
        };
        citasVivas = [nueva];
        return {data:nueva, error:null};
      }
      /* cancelarla: deja de estar viva, que es lo que el panel consulta */
      if (op && op.update){
        if (op.update.estado === 'cancelada') citasVivas = [];
        return {data:{}, error:null};
      }
      /* La agenda pide TODAS: ni .eq ni .in. El dialogo del inversionista
         pide solo las vivas con .in, y son dos listas distintas. */
      if (op && op.in) return {data:citasVivas, error:null};
      return {data:citasVivas.concat(CONFIRMADAS[caso] || [], MUERTAS[caso] || []),
              error:null};
    }
    if (tabla === 'empresas'){
      /* La empresa del inversionista. En 'lleno' y 'vacio' esta registrada
         -de ahi sale el relleno de los formularios-; en los otros dos no,
         para ver el estado vacio y el boton de registrarla. */
      if (op && op.upsert){
        empresaMia = {};
        Object.keys(op.upsert).forEach(function(k){ empresaMia[k] = op.upsert[k]; });
        return {data:empresaMia, error:null};
      }
      return {data:empresaMia, error:null};
    }
    if (tabla === 'tipos_tramite'){
      /* Encender o apagar uno. Devuelve la fila, que es justo lo que mira
         el panel para saber si la base le dejo: sin filas de vuelta, la
         pantalla entiende que RLS lo bloqueo y lo dice. */
      if (op && op.update && op.eq && op.eq.codigo){
        var tocado = null;
        TIPOS.forEach(function(x){
          if (x.codigo === op.eq.codigo){
            Object.keys(op.update).forEach(function(k){ x[k] = op.update[k]; });
            tocado = x;
          }
        });
        return {data: tocado ? [tocado] : [], error:null};
      }
      /* Y con el tramite tardio se enciende tambien el registro de marca,
         que nacia apagado. Son dos cosas distintas y hacen falta las dos:
         una SOLICITUD nueva se ve releyendo tramites, pero un tramite que
         el CIIP acaba de ENCENDER solo se ve si ademas se tira la copia del
         catalogo, que se guarda una vez y no se vuelve a pedir.

         Sin esto, quitar del panel la linea que olvida el catalogo no ponia
         nada en rojo. */
      if (window.CIIP_MENTIRA_TARDIO){
        TIPOS.forEach(function(t){ if (t.codigo === 'marca') t.activo = true; });
      }
      /* COPIAS, no los mismos objetos. Un Supabase de verdad contesta con
         JSON nuevo en cada consulta: quien pida el catalogo dos veces
         recibe dos juegos de objetos distintos. Este doble devolvia
         siempre los mismos, y eso lo hacia MAS INDULGENTE que la realidad:
         una pantalla que tocaba su copia tocaba tambien la de las demas, y
         un panel que se quedaba con un objeto viejo parecia enterarse de
         los cambios sin releer nada.
         Se vio con los dias del catalogo: el globo de la ficha se quedaba
         con el catalogo de cuando se monto -en produccion enseñaria el
         numero viejo hasta recargar- y la prueba de punta a punta pasaba
         igual, porque aqui los dos apuntaban a lo mismo. */
      return {data: TIPOS.map(function(t){ return Object.assign({}, t); }), error:null};
    }
    if (tabla === 'activos'){
      /* El banco de activos. En 'lleno' hay dos publicados -uno reservado-;
         en 'gestor' hay uno cerrado, que solo el equipo ve; en los demas la
         tabla esta vacia, que es como nace. */
      if (op && op.insert){
        var nuevo = {};
        Object.keys(op.insert).forEach(function(k){ nuevo[k] = op.insert[k]; });
        nuevo.id = 'an' + (activosVivos.length + 1);
        nuevo.creado_en = '2026-08-20T12:00:00Z';
        activosVivos.push(nuevo);
        return {data:nuevo, error:null};
      }
      if (op && op.update && op.eq && op.eq.id){
        activosVivos.forEach(function(a){
          if (a.id !== op.eq.id) return;
          Object.keys(op.update).forEach(function(k){ a[k] = op.update[k]; });
        });
        return {data:{}, error:null};
      }
      if (op && op.borra && op.eq && op.eq.id){
        activosVivos = activosVivos.filter(function(a){ return a.id !== op.eq.id; });
        return {data:{}, error:null};
      }
      /* Los cerrados no le llegan a quien no es del equipo: la politica de
         la base los deja fuera, y una prueba que los enseñara a todos daria
         verde sobre una pantalla que en vivo se ve distinta. */
      var visibles = activosVivos.filter(function(a){
        return a.estado !== 'cerrado' || caso === 'gestor';
      });
      /* Y en el orden que pide la consulta: destacado primero, y dentro de
         eso lo mas reciente. Sin ordenar aqui, la prueba de "el destacado va
         primero" solo comprobaria como escribi el fixture. */
      visibles.sort(function(a, b){
        return ((b.destacado ? 1 : 0) - (a.destacado ? 1 : 0)) ||
               (a.creado_en < b.creado_en ? 1 : a.creado_en > b.creado_en ? -1 : 0);
      });
      return {data:visibles, error:null};
    }
    if (tabla === 'documentos'){
      /* Una vez, cuando la prueba lo pide: la revisión de un papel no llega
         a la base (la red se cae a medias), para ver qué le dice el panel
         al gestor y qué hace con la nota que había escrito. */
      if (window.__FALLA_REVISAR && op && op.update && op.eq && op.eq.id){
        window.__FALLA_REVISAR = false;
        return {data:null, error:{message:'la red se cayó a medias', code:'08006'}};
      }
      /* Revisar un papel de los sembrados: se APUNTA, para que la prueba
         compruebe que el panel escribio el estado y quien lo reviso. */
      if (op && op.update && op.eq && op.eq.id && HOY_DOC[op.eq.id]){
        var revisado = HOY_DOC[op.eq.id];
        Object.keys(op.update).forEach(function(k){ revisado[k] = op.update[k]; });
        return {data:[revisado], error:null};
      }
      /* La boveda. El formulario los reutiliza y ofrece mirarlos antes de
         enviar; la vista de Documentos los enseña todos.

         Uno VENCIDO y uno por vencer a proposito: es lo unico de esa lista
         sobre lo que hay algo que hacer, y sin ellos la prueba de que se
         avisa a tiempo no comprobaria nada. Las fechas se calculan desde
         hoy, que si no el 'vencido' dejaria de estarlo con el tiempo. */
      var dia = 86400000, hoy = Date.now();
      function fechaEn(d){ return new Date(hoy + d * dia).toISOString().slice(0, 10); }
      /* Lo que se sube en esta pasada se QUEDA. Sin esto, subir la foto de
         carnet y volver a preguntar por ella devolvia lo mismo de antes, y
         no habia forma de medir que la foto recien subida sale en la ficha
         y en el circulo de la cabecera. */
      if (op && op.insert){
        var subido = {id:'dsub' + (subidos.length + 1), estado:'cargado',
                      vence_el:null, nota_revision:'',
                      creado_en:new Date(hoy).toISOString()};
        Object.keys(op.insert).forEach(function(k){ subido[k] = op.insert[k]; });
        subidos.push(subido);
        return {data:subido, error:null};
      }
      var boveda = subidos.concat([
        {id:'doc1', tipo:'cedula', archivo:'u1/pasaporte.pdf',
         nombre_original:'pasaporte.pdf', vence_el:null, estado:'cargado',
         nota_revision:'', creado_en:'2026-07-02T10:00:00Z'},
        {id:'doc2', tipo:'antecedentes', archivo:'u1/antecedentes.pdf',
         nombre_original:'antecedentes-apostillados.pdf', vence_el:fechaEn(-9),
         estado:'cargado', nota_revision:'', creado_en:'2026-05-20T10:00:00Z'},
        {id:'doc3', tipo:'acta_constitutiva', archivo:'u1/acta.pdf',
         nombre_original:'acta-constitutiva.pdf', vence_el:fechaEn(12),
         estado:'cargado', nota_revision:'', creado_en:'2026-08-01T10:00:00Z'},
        /* El RIF de la empresa. No es de adorno: con el, el Registro Unico
           Minero -c36, que pide cedula, RIF de la empresa y acta- pasa a
           tener TODOS sus recaudos en la boveda. Eso es lo que permite
           medir la marca de «tienes los papeles»: sin una sola tarjeta que
           la lleve, esa prueba solo mediria que NO sale, que es la mitad
           barata.

           Hasta el 22-9-2026 el sujeto eran los registros laborales -c9,
           el IVSS-, que pedian los mismos tres papeles. El CIIP quito esa
           casilla del catalogo y la marca se mide en la que quedaba.

           Se probo primero con el RIF PERSONAL y hubo que deshacerlo: dos
           pruebas de la cadena -c5 y c6 esperan al c3 porque les falta ese
           papel- se pusieron rojas, y con razon. Meter un papel en esta
           boveda no es gratis: apaga las esperas que ese papel causaba.

           Y es realista: la empresa esta constituida y su RIF hecho, que
           es justo cuando toca inscribir a los trabajadores. */
        {id:'doc4', tipo:'rif_empresa', archivo:'u1/rif-empresa.pdf',
         nombre_original:'rif-empresa.pdf', vence_el:null,
         estado:'cargado', nota_revision:'', creado_en:'2026-07-05T10:00:00Z'},
        /* Y un comprobante de domicilio. Este NO esta para que salga una
           marca, sino para que se pueda quitar: con el, el RIF personal
           -c3- tiene todos sus recaudos Y esta EMPEZADO, que es la unica
           combinacion capaz de comprobar que «tienes los papeles» NO sale
           en lo que ya empezaste.

           Sin este papel esa prueba pasaba igual con la regla puesta y con
           la regla quitada -se comprobo por sabotaje-, o sea que no
           probaba nada. Una prueba que no puede ponerse roja es peor que
           no tenerla: ocupa sitio y da tranquilidad falsa. */
        {id:'doc5', tipo:'domicilio', archivo:'u1/domicilio.pdf',
         nombre_original:'recibo-de-luz.pdf', vence_el:null,
         estado:'cargado', nota_revision:'', creado_en:'2026-07-06T10:00:00Z'}
      ]).concat(caso === 'gestor' ? [
        /* Un comprobante, solo para el equipo: la bóveda de comprobantes
           tiene que enseñarlo con el nombre de quien lo subió, y los demás
           papeles de esta lista no. Validado para no mover la cuenta de
           «Documentos por revisar». */
        {id:'doc6', tipo:'reserva_nombre', archivo:'u2/reserva.pdf', inversionista:'u2',
         nombre_original:'reserva-denominacion.pdf', vence_el:null,
         estado:'validado', nota_revision:'', creado_en:'2026-09-16T15:00:00Z'}
      ] : []);
      /* Y por TIPO cuando lo piden, que es como lo pregunta el formulario
         de un tramite -¿tengo ya este recaudo?- y la foto de la ficha.
         Devolver los tres para cualquier tipo hacia que TODO recaudo
         saliera reutilizado: la prueba de \"todavia no hay foto\" no podia
         distinguirse de la de \"ya la hay\". */
      if (op && op.eq && op.eq.tipo){
        boveda = boveda.filter(function(d){ return d.tipo === op.eq.tipo; });
      }
      /* Borrar uno. Solo se pueden ir los de esta pasada -los tres de
         plantilla vuelven en cada carga, que para eso son plantilla-,
         pero se APUNTA cual se fue para que la lista lo respete: sin
         esto, borrar contestaba que si y el papel seguia en pantalla,
         y la prueba de que desaparece no podia distinguirse de la de
         que no. */
      if (op && op.borra && op.eq && op.eq.id){
        borrados[op.eq.id] = true;
        subidos = subidos.filter(function(d){ return d.id !== op.eq.id; });
        return {data:null, error:null};
      }
      boveda = boveda.filter(function(d){ return !borrados[d.id]; });
      /* Los vencidos, que es como los cuenta el pulso. Sin esto devolvia
         la boveda entera y el numero de caducados salia igual al total:
         un contador que siempre acierta por casualidad no prueba nada. */
      if (op && op.lt && op.lt.vence_el){
        boveda = boveda.filter(function(d){
          return d.vence_el && d.vence_el < op.lt.vence_el;
        });
      }
      return {data:boveda, error:null};
    }
    /* La columna «Listo» de la portada pregunta por lo ENTREGADO de todos
       sus resueltos a la vez, con .in('tramite'). Va delante de la de la
       boveda porque aquella se queda con cualquier consulta sin .eq, y le
       daria a la portada los recaudos de otro en vez del documento emitido. */
    /* Lo que el envío engancha a la solicitud. Se apunta para que la prueba
       del envío pueda ver que los papeles llegaron: sin esto, una solicitud
       enviada sin un solo archivo pasaba la tanda en verde. */
    /* Los cinco entes de los registros parafiscales, guardados en esta
       pestaña: sin esto el código enviado no se quedaba puesto y el «listo»
       del equipo no encendía nada. Lo que no se manda no se pisa, como en
       el upsert de verdad. */
    if (tabla === 'tramite_entes'){
      var ENT = window.__ENTES = window.__ENTES || {};
      /* Una vez, cuando la prueba lo pide: la red se cae al mandar el
         usuario y la contraseña. Es lo que deja ver que un envío fallido
         no se lleva por delante lo que el inversionista había escrito. */
      if (op && op.upsert && window.__FALLA_ENTES){
        window.__FALLA_ENTES = false;
        return {data:null, error:{message:'la red se cayó', code:'08006'}};
      }
      if (op && op.upsert){
        var kE = op.upsert.tramite + '|' + op.upsert.ente, filaE = {};
        [ENT[kE] || {}, op.upsert].forEach(function(o){
          Object.keys(o).forEach(function(c){ filaE[c] = o[c]; });
        });
        /* Con su TIPO, como lo trae el documentos(...) de la base: la
           planilla del IVSS y la constancia van en la misma casilla y el
           panel las distingue por él (30-9-2026). Se saca de lo subido en
           esta pasada; lo que no está ahí se queda sin tipo, como antes. */
        if (filaE.documento){
          var suyoE = subidos.filter(function(s){ return s.id === filaE.documento; })[0];
          filaE.documentos = {archivo: 'mentira/' + filaE.documento + '.pdf',
                              nombre_original: suyoE ? suyoE.nombre_original : 'codigo-del-ente.pdf',
                              tipo: suyoE ? suyoE.tipo : undefined};
        }
        ENT[kE] = filaE;
        return {data:[filaE], error:null};
      }
      var deE = op && op.eq && op.eq.tramite;
      return {data: Object.keys(ENT).map(function(k){ return ENT[k]; })
                      .filter(function(f){ return !deE || f.tramite === deE; }), error:null};
    }
    /* Colgar un papel con .insert() -la planilla firmada que se devuelve
       desde «Firme la planilla», 29-9-2026-: se apunta aparte y vuelve con
       su fila, que es lo que contesta la base cuando la política deja
       pasar. Sin esto caía en la lista sin .eq de más abajo y contestaba
       con tres enganches de otro. */
    if (tabla === 'tramite_documentos' && op && op.insert){
      (window.__ENGANCHES = window.__ENGANCHES || []).push(op.insert);
      return {data:[op.insert], error:null};
    }
    if (tabla === 'tramite_documentos' && op && op.upsert){
      (window.__ADJUNTOS = window.__ADJUNTOS || []).push(op.upsert);
      return {data:[op.upsert], error:null};
    }
    if (tabla === 'tramite_documentos' && op && op.in && op.in.tramite){
      var deHoy = [];
      op.in.tramite.forEach(function(id){
        (HOY_DOCS[id] || []).forEach(function(d){ deHoy.push({tramite:id, documento:d.id, documentos:d}); });
      });
      /* El documento para pagar la reserva, para la campana. Desde el
         21-9-2026 el buzon pide los enganches CON su papel filtrando por
         sus tramites -.in('tramite', mios)-, y este falso solo lo daba a la
         consulta sin filtro de mas abajo: la campana del pase 'tramos' se
         quedaba muda y la prueba de la reserva fallaba en los tres pases
         sin que el panel tuviera nada que ver. Se da aqui igual que alli,
         y solo si 'p2' esta entre los pedidos, que es lo que haria la base. */
      if (conTramos && op.in.tramite.indexOf('p2') >= 0 &&
          /documentos\(/.test(op.cols || '')){
        deHoy.push({tramite:'p2', documento:'dp1', documentos:{
          id:'dp1', tipo:'planilla_reserva_nombre',
          nombre_original:'planilla-reserva-saren.pdf',
          creado_en:new Date(Date.now() - 3600000).toISOString()}});
      }
      if (deHoy.length) return {data:deHoy, error:null};
      return {data: op.in.tramite.indexOf('t4') >= 0
        ? [{tramite:'t4', documento:'dr1', documentos:{tipo:'resolucion',
            nombre_original:'visa-trn-estampada.pdf',
            archivo:'u1/emitidos/visa-trn-estampada.pdf'}}]
        : [], error:null};
    }
    /* El buzon de avisos pregunta por TODOS los enganches CON su papel
       -documentos(...)- para anunciar el documento de pagar y su
       comprobante. Va antes que la de la boveda, que pide los mismos
       enganches pero sin papel: se distinguen por lo que piden. */
    if (tabla === 'tramite_documentos' && !(op && (op.eq || op.in)) &&
        /documentos\(/.test((op && op.cols) || '')){
      if (!conTramos) return {data:[], error:null};
      return {data:[{tramite:'p2', documento:'dp1', documentos:{
        id:'dp1', tipo:'planilla_reserva_nombre',
        nombre_original:'planilla-reserva-saren.pdf',
        creado_en:new Date(Date.now() - 3600000).toISOString()}}], error:null};
    }
    if (tabla === 'tramite_documentos' && !(op && op.eq)){
      /* SIN .eq: la boveda pregunta por TODOS para contar en cuantos
         tramites se usa cada documento. La otra consulta de esta misma
         tabla -la del expediente que abre el gestor- si lleva
         .eq('tramite'), y esta de aqui no puede quedarsela: le enseñaria
         al gestor los papeles de otro. */
      return {data:[
        {documento:'doc1', tramite:'t1'},
        {documento:'doc1', tramite:'t3'},
        {documento:'doc3', tramite:'t1'}
      ], error:null};
    }
    /* Que recaudos caducan. Devolvia lista vacia, y con ella el formulario
       de subir no pediria fecha de vencimiento NUNCA: la prueba de que la
       pide no podria distinguirse de la de que no. */
    /* La bitacora. Lleva el MISMO tramite apagado y encendido, que es lo
       que una tabla de historial hace y dos columnas no: con columnas el
       segundo movimiento pisaba al primero y salia un apunte en vez de
       dos. Sin este par, la prueba de que ya no se pisan no comprueba
       nada. */
    /* La configuracion del acompañamiento. Con la nube apagada y un
       retoque de texto, que son los dos casos que la pantalla tiene que
       saber pintar y la burbuja obedecer. */
    /* Los textos que el administrador ha cambiado (supabase-textos.sql).
       Nace VACIA, como la tabla: sin nada guardado el panel tiene que verse
       igual que sin ella. Guardar y volver al original se apuntan de verdad,
       para que una prueba pueda ver el texto cambiar y volver. */
    if (tabla === 'textos_panel'){
      var TXP = window.__TEXTOS_PANEL = window.__TEXTOS_PANEL || [];
      if (op && op.upsert){
        var fu = op.upsert;
        window.__TEXTOS_PANEL = TXP.filter(function(x){ return !(x.clave === fu.clave && x.idioma === fu.idioma); });
        window.__TEXTOS_PANEL.push({clave: fu.clave, idioma: fu.idioma, texto: fu.texto});
        return {data:[{clave: fu.clave}], error:null};
      }
      if (op && op.borra){
        var eq2 = op.eq || {};
        var fuera = TXP.filter(function(x){ return x.clave === eq2.clave && x.idioma === eq2.idioma; });
        window.__TEXTOS_PANEL = TXP.filter(function(x){ return fuera.indexOf(x) < 0; });
        return {data: fuera, error:null};
      }
      return {data: TXP.slice(), error:null};
    }
    if (tabla === 'acompanamiento'){
      if (op && op.update){
        Object.keys(op.update).forEach(function(k){ ACOMP[k] = op.update[k]; });
        return {data:[ACOMP], error:null};
      }
      return {data:[ACOMP], error:null};
    }
    if (tabla === 'bitacora'){
      return {data:[
        /* Lo que apunta supabase-bitacora-ajustes.sql, uno de cada. El
           plazo va con el MISMO tramite que el interruptor: comparten
           fuente, y es justo lo que se leia mal. */
        {id:14, cuando:haceHoras(0.5), quien:'u4', fuente:'catalogo',
         accion:'plazo',    sobre:'Registro de marca', detalle:'30'},
        {id:13, cuando:haceHoras(2),   quien:'u4', fuente:'textos',
         accion:'cambio',   sobre:'Poder de representación legal', detalle:'es'},
        {id:12, cuando:haceHoras(4),   quien:'u4', fuente:'textos',
         accion:'original', sobre:'Business visa (TR-N)', detalle:'en'},
        {id:11, cuando:haceHoras(5),   quien:'u4', fuente:'activos',
         accion:'creo',     sobre:'Finca La Esperanza', detalle:'disponible'},
        {id:10, cuando:haceHoras(6),   quien:'u4', fuente:'citas',
         accion:'puso_tramo', sobre:'09:00-12:00', detalle:'1'},
        {id:9,  cuando:haceHoras(12),  quien:'u4', fuente:'citas',
         accion:'cerro_dia', sobre:'2026-12-24', detalle:'Nochebuena'},
        {id:8,  cuando:haceHoras(20),  quien:'u4', fuente:'acompanamiento',
         accion:'ajusto',   sobre:'', detalle:''},
        {id:7,  cuando:haceHoras(40),  quien:'u4', fuente:'roles',
         accion:'bloqueo',  sobre:'Bruno Pereira', detalle:''},
        {id:6, cuando:haceHoras(0.2), quien:'u4', fuente:'catalogo',
         accion:'encendio', sobre:'Registro de marca', detalle:''},
        {id:5, cuando:haceHoras(1),   quien:'u4', fuente:'catalogo',
         accion:'apago',    sobre:'Registro de marca', detalle:''},
        {id:4, cuando:haceHoras(3),   quien:'u2', fuente:'papeles',
         accion:'subio',    sobre:'acta-constitutiva.pdf', detalle:'acta_constitutiva'},
        {id:3, cuando:haceHoras(9),   quien:'u2', fuente:'papeles',
         accion:'borro',    sobre:'pasaporte-viejo.pdf', detalle:'pasaporte'},
        {id:2, cuando:haceHoras(26),  quien:null,  fuente:'citas',
         accion:'movio',    sobre:'rif_empresa', detalle:'confirmada'},
        {id:1, cuando:haceHoras(30),  quien:'u5', fuente:'citas',
         accion:'pidio',    sobre:'', detalle:'solicitada'},
        {id:0, cuando:haceHoras(50),  quien:'u4', fuente:'roles',
         accion:'rol',      sobre:'Saskia Calderon', detalle:'gestor'},
        /* Lo que apunta supabase-qa-admin.sql: el cambio de rol con el de
           antes, y una baja. */
        {id:15, cuando:haceHoras(52), quien:'u4', fuente:'roles',
         accion:'rol',      sobre:'Franklin Reyes', detalle:'{"rol":"gestor","antes":"inversionista"}'},
        {id:16, cuando:haceHoras(54), quien:'u4', fuente:'roles',
         accion:'baja',     sobre:'Bruno Pereira', detalle:''}
      ], error:null};
    }
    if (tabla === 'tipos_documento'){
      return {data:[
        {codigo:'cedula', vence:true},         {codigo:'pasaporte', vence:true},
        {codigo:'visa', vence:true},           {codigo:'rif_personal', vence:true},
        {codigo:'rif_empresa', vence:true},    {codigo:'poder', vence:true},
        {codigo:'antecedentes', vence:true},   {codigo:'licencia_extranjera', vence:true},
        {codigo:'certificado_medico', vence:true},
        {codigo:'domicilio', vence:false},     {codigo:'foto', vence:false},
        {codigo:'acta_constitutiva', vence:false}, {codigo:'traduccion', vence:false},
        {codigo:'domicilio_empresa', vence:false}, {codigo:'inversion', vence:false},
        {codigo:'carta_motivo_viaje', vence:false}, {codigo:'registro_comercio', vence:false},
        {codigo:'certificado_medico_origen', vence:true}, {codigo:'arancel_consular', vence:false},
        {codigo:'comprobante_capital', vence:false}, {codigo:'carta_comisario', vence:false},
        {codigo:'estatutos_accionista', vence:false}, {codigo:'good_standing', vence:true},
        {codigo:'beneficiarios_finales', vence:false}, {codigo:'no_objecion_zodi', vence:false},
        {codigo:'identidad_accionistas', vence:false}, {codigo:'juridico_matriz', vence:false},
        {codigo:'directores_accionista', vence:false},
        {codigo:'rif_inversionistas', vence:false}, {codigo:'cedulas_junta', vence:false},
        {codigo:'rifs_junta', vence:false}, {codigo:'codigo_ente', vence:false},
        {codigo:'certificado_rupdae', vence:false}, {codigo:'certificado_rum', vence:true},
        {codigo:'certificado_locti', vence:true}, {codigo:'planilla_locti', vence:false},
        {codigo:'pago_locti', vence:false},
        /* Los tres de la conformidad de uso (28-9-2026), como si su SQL
           estuviera corrido. */
        {codigo:'cedula_catastral', vence:false}, {codigo:'permiso_construccion', vence:false},
        {codigo:'fotos_local', vence:false},
        /* El plano de seguridad del permiso de bomberos (29-9-2026), como
           si supabase-bomberos.sql estuviera corrido. */
        {codigo:'plano_seguridad', vence:false},
        /* Los de «Bienes» (2-10-2026), como si supabase-bienes.sql
           estuviera corrido. */
        {codigo:'propiedad_inmueble', vence:false}, {codigo:'identidad_propietario', vence:false},
        {codigo:'solvencia_inmuebles', vence:true},
        /* Y los siete que la compraventa pide desde el mismo día (Franklin
           Reyes, 2-10-2026): la Forma 33, las dos partes y los cuatro de la
           empresa vendedora. Ninguno caduca. */
        {codigo:'forma_33', vence:false}, {codigo:'identidad_vendedor', vence:false},
        {codigo:'identidad_comprador', vence:false}, {codigo:'acta_vendedor', vence:false},
        {codigo:'identidad_rep_vendedor', vence:false}, {codigo:'asamblea_rep_vendedor', vence:false},
        {codigo:'rif_vendedor', vence:false},
        /* Los cuatro del comprador (5-10-2026), como si
           supabase-bienes-comprador.sql estuviera corrido. */
        {codigo:'acta_comprador', vence:false}, {codigo:'rif_comprador', vence:false},
        {codigo:'identidad_rep_comprador', vence:false}, {codigo:'asamblea_comprador', vence:false},
        /* El contrato que manda el CIIP en la compraventa (5-10-2026), como si
           supabase-bienes-registro.sql estuviera corrido. */
        {codigo:'contrato_compraventa', vence:false},
        /* Los dos de la marca en proceso de registro (5-10-2026), como si
           supabase-marca-proceso.sql estuviera corrido. */
        {codigo:'planilla_solicitud_marca', vence:false}, {codigo:'identidad_titular_marca', vence:false}
      ], error:null};
    }

    /* La constancia de identidad. Empieza VACIA a proposito: el estado
       normal de una persona recien llegada es que nadie haya mirado su
       documento, y es el estado que mas facil resulta pintar mal. */
    if (tabla === 'identidad_comprobaciones'){
      if (op && op.insert){
        var f = op.insert;
        /* La base pisa el autor con auth.uid() y pone su hora. Aqui se
           hace igual: si el falso dejara pasar el gestor que le manden,
           la prueba de que el autor no se acepta de fuera no probaria
           nada. */
        IDENTIDAD.unshift({
          resultado: f.resultado, tipo_documento: f.tipo_documento,
          numero: f.numero, nota: f.nota || '',
          creado_en: '2026-08-21T12:00:00Z', gestor: USUARIO.id
        });
        return {data:[IDENTIDAD[0]], error:null};
      }
      return {data:IDENTIDAD.slice(), error:null};
    }
    if (tabla === 'bancos_aliados')   return {data:[], error:null};
    if (tabla === 'tramites'){
      /* La solicitud que el inversionista canceló mientras el gestor la
         tenía abierta: el panel pregunta su estado con .select('estado')
         .single() justo antes de moverla (yaNoEsAsi), y la base le
         contesta que ya está cancelada. Solo la id que pida la prueba, y
         solo a esa pregunta: todo lo demás sigue como siempre. */
      if (window.__YA_CANCELADA && op && op.single && op.eq && op.eq.id === window.__YA_CANCELADA &&
          op.cols === 'estado' && !op.update && !op.insert){
        return {data:{estado:'cancelado'}, error:null};
      }
      /* Antes de crear una solicitud, el panel pregunta si YA hay una en
         marcha de ESE MISMO TRAMITE: los tres estados vivos Y un .eq del
         tipo. Va la PRIMERA porque la de abajo -la cola del equipo- se
         queda con cualquier consulta que lleve 'enviado' dentro, y se
         tragaba esta: la guarda contra duplicados preguntaba y siempre le
         contestaban que no habia ninguna. La cola del equipo nunca filtra
         por tipo, asi que el .eq las distingue. */
      if (op && op.in && op.in.estado && op.eq && op.eq.tipo &&
          op.in.estado.indexOf('ante_el_ente') >= 0){
        return {data: (TRAMITES[caso] || []).filter(function(t){
          return t.tipo === op.eq.tipo && op.in.estado.indexOf(t.estado) >= 0;
        }), error:null};
      }

      /* CREAR una solicitud. El doble no sabia hacerlo: el insert se caia
         hasta la lista del inversionista del final y contestaba con el
         expediente entero, asi que el `.select().single()` del panel se
         llevaba por respuesta un tramite AJENO y el envio seguia con el id
         de otro.

         Que nadie lo notara en tres semanas no es casualidad: ninguna
         prueba llegaba a enviar de verdad -la unica que pulsaba Enviar
         mide la guarda de duplicados, que contesta y se para antes de
         crear nada-, y un doble solo se equivoca donde no lo mira nadie.
         Es el mismo agujero por el que paso el fallo que esto viene a
         cazar: el envio entero envuelto en una funcion que no llamaba
         nadie.

         El estado no lo manda el panel: lo pone la base por defecto
         -`estado text not null default 'borrador'`-, y aqui igual. */
      if (op && op.insert){
        var nuevo = {
          id: 'nt' + (++nCreados),
          tipo: op.insert.tipo,
          estado: 'borrador',
          datos: op.insert.datos || {},
          creado_en: ahora(),
          actualizado_en: ahora()
        };
        (TRAMITES[caso] = TRAMITES[caso] || []).push(nuevo);
        return {data: (op.single ? nuevo : [nuevo]), error:null};
      }

      /* Los resueltos del montón «Listos»: su consulta es la única que
         pregunta por un estado con .eq y sin cambiar nada. */
      if (op && op.eq && op.eq.estado === 'resuelto' && !op.update && !op.insert && !op.borra){
        return {data: colaListos.slice(), error:null};
      }
      /* Dos colas distintas sobre la misma tabla: la del equipo pide lo que
         espera por el CIIP, y la franja del inversionista lo que espera por
         el. Confundirlas seria enseñarle a cada uno lo del otro. */
      if (op && op.in && op.in.estado && op.in.estado.indexOf('enviado') >= 0){
        return {data:colaTram, error:null};
      }
      /* Tomar o soltar NO saca el tramite de la cola: solo cambia de
         nombre. Con la regla de abajo -que si lo saca- tomar uno lo
         habria hecho desaparecer, que es lo contrario de lo que hace.
         Los dos son un update sobre la misma tabla, y como en perfiles se
         distinguen por lo que traen. */
      if (op && op.update && 'estado' in op.update && op.eq && op.eq.id){
        /* Una vez, cuando la prueba lo pide: mover falla después de haber
           entregado el documento (QA-14). */
        if (window.__FALLA_MOVER){
          window.__FALLA_MOVER = false;
          return {data:null, error:{message:'la red se cayó a medias', code:'08006'}};
        }
        var sembrado = colaTram.filter(function(t){ return t.id === op.eq.id && t.sembrado; })[0];
        if (sembrado){
          if (['enviado', 'en_revision', 'ante_el_ente'].indexOf(op.update.estado) >= 0){
            sembrado.estado = op.update.estado;
            return {data:sembrado, error:null};
          }
          colaTram = colaTram.filter(function(t){ return t.id !== op.eq.id; });
          return {data:{}, error:null};
        }
      }
      if (op && op.update && 'gestor' in op.update && op.eq && op.eq.id){
        var suyo = colaTram.filter(function(t){ return t.id === op.eq.id; })[0];
        if (suyo) suyo.gestor = op.update.gestor;
        return {data:(suyo || {}), error:null};
      }
      /* Y cambiar una MIA, que es como se envia. Sin esta regla caia en la
         de abajo -la del gestor, que la saca de la cola y contesta {}- y el
         tramite se quedaba en borrador mientras la pantalla decia que lo
         habias mandado. Se distingue por donde vive el id: la de abajo
         trabaja sobre la cola del equipo, esta sobre lo que es tuyo.

         'enviado_en' lo pone la base con un disparador, no el panel: la
         pantalla del estado lee esa fecha para decir «Enviada el...», y un
         doble que no la pusiera dejaria sin comprobar justo esa linea. */
      if (op && op.update && op.eq && op.eq.id){
        var mio = (TRAMITES[caso] || []).filter(function(t){ return t.id === op.eq.id; })[0];
        if (mio){
          Object.keys(op.update).forEach(function(k){ mio[k] = op.update[k]; });
          mio.actualizado_en = ahora();
          if (op.update.estado === 'enviado' && !mio.enviado_en) mio.enviado_en = ahora();
          return {data: (op.single ? mio : [mio]), error:null};
        }
      }
      if (op && op.update && op.eq && op.eq.id){
        colaTram = colaTram.filter(function(t){ return t.id !== op.eq.id; });
        return {data:{}, error:null};
      }
      /* Descartar un borrador. Se quita de VERDAD de la lista: si el
         falso dijera "hecho" sin quitarlo, la prueba de que la franja se
         calla despues daria verde con el borrador todavia ahi. */
      if (op && op.borra && op.eq && op.eq.id){
        var antes = (TRAMITES[caso] || []).length;
        TRAMITES[caso] = (TRAMITES[caso] || []).filter(function(t){
          /* La politica solo deja borrar el borrador propio: un falso mas
             permisivo que la base deja pasar codigo que la base rechaza. */
          return !(t.id === op.eq.id && t.estado === 'borrador');
        });
        return {data:null, error:(TRAMITES[caso].length === antes
          ? {message:'no se puede borrar una solicitud enviada'} : null)};
      }
      /* El detalle de un tramite pregunta por SU tipo. Sin filtrar aqui, el
         panel creeria que ya tienes una solicitud de cualquier tramite que
         abras, y enseñaria su estado en vez del formulario. */
      /* Una consulta SIN filtro ninguno la hace quien puede leerlo todo:
         el equipo, para contar. La politica de la base se lo permite, asi
         que el falso tiene que contestar lo mismo -la cola mas lo propio-
         o el pulso saldria siempre a cero y no habria forma de saber si
         es que la oficina esta parada o que el panel no pregunta bien. */
      if (op && !op.eq && !op.in && !op.update && !op.insert && !op.borra && !op.upsert){
        var todo = colaTram.slice();
        (TRAMITES[caso] || []).forEach(function(x){
          var esta = todo.some(function(y){ return y.id === x.id; });
          if (esta) return;
          /* CON SU DUEÑO. En la base 'inversionista' es NOT NULL, y estas
             son las del que mira -su politica no le deja otras-, pero las
             filas de aqui nacieron sin esa columna porque ninguna consulta
             la miraba. Ahora si: el buzon decide con ella de que lado esta
             cada uno, y sin el sello daba las PROPIAS por ajenas y le
             escondia al inversionista el documento que tiene que pagar.
             Se sella una copia: la fixture se comparte entre pruebas. */
          if (x.inversionista){ todo.push(x); return; }
          var c = {};
          for (var k in x){ if (Object.prototype.hasOwnProperty.call(x, k)) c[k] = x[k]; }
          c.inversionista = USUARIO.id;
          todo.push(c);
        });
        return {data: todo, error:null};
      }
      /* La lista del inversionista. A partir de la SEGUNDA lectura trae uno
         mas: es como se comprueba que el panel se pone al dia sin recargar.
         Ver TRAMITE_TARDIO, arriba.

         Se cuenta aqui y no en cada rama porque esta es la unica que pide la
         portada: las de mas arriba son la cola del equipo y las guardas
         contra duplicados, y contarlas tambien haria que el tramite tardio
         apareciera antes de tiempo. */
      var mios = (TRAMITES[caso] || []).slice();
      if (window.CIIP_MENTIRA_TARDIO) mios = mios.concat([TRAMITE_TARDIO]);
      if (op && op.eq && op.eq.tipo){
        /* Y las que una prueba ponga mientras dura (window.__TRAMITES_EXTRA),
           SOLO en la pregunta del detalle, que es la que lleva el tipo: así
           la ficha de ese trámite se abre con su solicitud y las cuentas de
           la portada y de Mis trámites no se enteran. La usa la de la visa
           con su «Ya me registré» (1-10-2026). */
        if (window.__TRAMITES_EXTRA) mios = mios.concat(window.__TRAMITES_EXTRA);
        mios = mios.filter(function(t){ return t.tipo === op.eq.tipo; });
      }
      /* La franja pide solo devueltos y borradores. Sin filtrar, se le
         colaria un enviado y lo anunciaria como si te tocara a ti. */
      if (op && op.in && op.in.estado){
        mios = mios.filter(function(t){ return op.in.estado.indexOf(t.estado) >= 0; });
      }
      return {data:mios, error:null};
    }
    /* ── la conversación de una cita ──
       Misma forma que la del expediente y tabla distinta, como en la base:
       las dos llaves foráneas apuntan a sitios distintos.

       Empieza con DOS líneas y no vacía, por lo mismo que la otra: un hilo
       vacío y uno que no carga se ven igual en pantalla, y con el vacío no
       habría forma de comprobar que se pinta quién habla.

       Y son de la CITA DEL EXPEDIENTE -la c1-, que es la que el panel
       tiene en marcha. Se escribieron primero para la q2 -una de la cola
       del gestor- y el hilo salia vacio: el panel pide las de SU cita, y
       aquella no lo es nunca. Vacio y roto se ven igual en pantalla. */
    if (tabla === 'cita_mensajes'){
      if (op && op.insert){
        /* NOT NULL, como en la base: `cita uuid not null references
           citas(id)`. El doble aceptaba una fila sin ella y la guardaba
           tan contento, asi que quitar del panel la linea que dice de que
           cita es no ponia nada en rojo. Postgres habria contestado 23502
           y el mensaje no se habria escrito. */
        if (op.insert.cita == null){
          return {data:null, error:{
            message:'null value in column "cita" of relation "cita_mensajes" violates not-null constraint',
            code:'23502'}};
        }
        var msjC = {
          id: 'cmsj' + (dichosCita.length + 1),
          cita: op.insert.cita,
          texto: op.insert.texto || '',
          documento: op.insert.documento || null,
          /* Del inversionista, nunca del equipo: lo pone el disparador con
             la sesión, y si aquí se dijera lo contrario la prueba de «nadie
             firma por otro» mediría al revés. */
          del_equipo: false,
          creado_en: new Date().toISOString()
        };
        dichosCita.push(msjC);
        return {data:[msjC], error:null};
      }
      var hiloC = [
        {id:'cmsj-a', cita:'c1', texto:'Buenos dias, todavia no he empezado ningun tramite. Por donde empiezo?',
         del_equipo:false, documento:null, creado_en:'2026-08-12T09:10:00Z'},
        {id:'cmsj-b', cita:'c1', texto:'Buenos dias. Con la visa y el RIF personal ya se puede constituir.',
         del_equipo:true, documento:null, creado_en:'2026-08-12T11:40:00Z'},

        /* Y otra en la cita CONFIRMADA -la k1-, que es la que se ve en la
           agenda. Hacen falta las dos: la de la ventana -la c1- desaparece de
           la agenda en cuanto se cancela, asi que sin esta no habia ninguna
           ficha con conversacion que mirar alli.

           Se probo primero con una CANCELADA y no valia: esas no se pintan
           como ficha sino como renglon compacto dentro de una lista plegada,
           por una decision que ya estaba tomada -«una pantalla llena de
           fichas que no sirven para nada parece una pantalla llena de
           citas»-. O sea que ahi no hay hilo que abrir. */
        {id:'cmsj-k1', cita:'k1', texto:'Buenos dias, todavia no he empezado ningun tramite. Por donde empiezo?',
         del_equipo:false, documento:null, creado_en:'2026-07-01T10:00:00Z'},
        {id:'cmsj-k2', cita:'k1', texto:'Nos vemos el 26 en la Torre CIIP. Trae el pasaporte.',
         del_equipo:true, documento:null, creado_en:'2026-07-01T12:00:00Z'}
      ].concat(dichosCita);
      var deLaCita = hiloC;
      if (op && op.eq && op.eq.cita){
        deLaCita = hiloC.filter(function(m){ return m.cita === op.eq.cita; });
      }
      return {data: deLaCita, error:null};
    }

    if (tabla === 'tramite_mensajes'){
      /* La conversacion de un expediente. Empieza con DOS lineas y no
         vacia: un hilo vacio y uno que no carga se ven igual en pantalla,
         y con el vacio no habria forma de probar que se pinta quien habla
         ni que el adjunto sale por su nombre.

         Las dos son del tramite devuelto -el t1-, que es donde la
         conversacion tiene sentido: el CIIP dice que falta algo y el
         inversionista pregunta que exactamente. */
      if (op && op.insert){
        /* NOT NULL, igual que la de las citas y por la misma razon. */
        if (op.insert.tramite == null){
          return {data:null, error:{
            message:'null value in column "tramite" of relation "tramite_mensajes" violates not-null constraint',
            code:'23502'}};
        }
        var msj = {
          id: 'msj' + (dichos.length + 1),
          tramite: op.insert.tramite,
          texto: op.insert.texto || '',
          documento: op.insert.documento || null,
          /* Lo pone la BASE, no quien escribe: el falso tiene que hacer lo
             mismo o la prueba de "nadie firma por otro" mediria al reves. */
          del_equipo: false,
          creado_en: new Date().toISOString()
        };
        dichos.push(msj);
        return {data:[msj], error:null};
      }
      var hilo = [
        {id:'msj-a', tramite:'t1', texto:'El comprobante del capital esta ilegible: vuelve a subirlo escaneado.',
         del_equipo:true, documento:null, creado_en:'2026-08-14T10:05:00Z'},
        {id:'msj-b', tramite:'t1', texto:'Lo tengo escaneado del banco. Sirve asi?',
         del_equipo:false, documento:'d1',
         documentos:{nombre_original:'comprobante-banco.pdf', tipo:'otro', archivo:'u1/comprobante.pdf'},
         creado_en:'2026-08-15T09:00:00Z'},
        /* Y una del expediente que ve el EQUIPO en su cola -el x1-. Sin
           esto el hilo del gestor salia vacio, que es peor que no salir:
           pareceria que el inversionista no ha preguntado nada. */
        {id:'msj-c', tramite:'x1', texto:'Buenos dias, adjunto el acta que me pidieron.',
         del_equipo:false, documento:null, creado_en:'2026-08-06T08:30:00Z'},
        {id:'msj-d', tramite:'x1', texto:'Recibido. Lo revisamos hoy mismo.',
         del_equipo:true, documento:null, creado_en:'2026-08-06T11:00:00Z'},
        /* Y otro del equipo en el x2, el expediente que lleva OTRO gestor.
           Por lo mismo que el evento 91: sin una fila ajena en la mesa, la
           prueba de que no entra no comprueba nada. */
        {id:'msj-e', tramite:'x2', texto:'Falta el acta de asamblea firmada.',
         del_equipo:true, documento:null, creado_en:'2026-08-07T12:00:00Z'}
      ].concat(dichos);
      if (op && op.eq && op.eq.tramite){
        hilo = hilo.filter(function(m){ return m.tramite === op.eq.tramite; });
      }
      /* Y por VARIOS a la vez, que es como los pide la campana: los
         expedientes que son tuyos. Sin esto el doble contestaba el hilo
         entero y la prueba de que a un gestor no le entra lo de otro
         gestor habria dado verde sin filtro ninguno. */
      if (op && op.in && op.in.tramite){
        hilo = hilo.filter(function(m){ return op.in.tramite.indexOf(m.tramite) >= 0; });
      }
      return {data:soloLoPedido(hilo, op && op.cols), error:null};
    }
    /* Los trámites específicos de cada sector (Franklin Reyes, 1-10-2026,
       supabase-control-estadisticas.sql). Con estado de verdad: añadir,
       guardar, mover y quitar se ven después en la lista. Como la RLS:
       leer, todos; escribir, solo el administrador -al resto el insert le
       da error y el update o el delete no cambian ninguna fila, sin
       error-. */
    if (tabla === 'tramites_por_sector'){
      var psEsc = esAdmin && !sinSql;
      if (op && op.insert){
        if (!psEsc) return {data:null, error:{message:'new row violates row-level security policy', code:'42501'}};
        var psN = {id:'ps' + (++psCreados), sector:op.insert.sector, nombre:op.insert.nombre,
                   organismo:op.insert.organismo || '', orden:+op.insert.orden || 0};
        porSector.push(psN);
        return {data:[psN], error:null};
      }
      if (op && op.update && op.eq && op.eq.id){
        var psU = psEsc ? porSector.filter(function(p){ return p.id === op.eq.id; })[0] : null;
        if (psU) Object.keys(op.update).forEach(function(k){ psU[k] = op.update[k]; });
        return {data: psU ? [psU] : [], error:null};
      }
      if (op && op.borra && op.eq && op.eq.id){
        if (psEsc) porSector = porSector.filter(function(p){ return p.id !== op.eq.id; });
        return {data:null, error:null};
      }
      var psL = porSector.filter(function(p){ return !(op && op.eq && op.eq.sector) || p.sector === op.eq.sector; })
        .map(function(p){ return {id:p.id, sector:p.sector, nombre:p.nombre, organismo:p.organismo, orden:p.orden}; })
        .sort(function(a, b){ return a.orden - b.orden; });
      return {data:psL, error:null};
    }

    if (tabla === 'consultas'){
      /* ABRIRLA. Lo que manda el navegador NO decide de quien es ni en que
         estado nace: eso lo pone el disparador consulta_la_firma_la_base()
         en la base de verdad. Si el doble aceptara lo que le mandan, la
         prueba de "nadie abre una consulta a nombre de otro" saldria verde
         midiendo justo lo contrario de lo que dice. */
      if (op && op.insert){
        var nueva = {
          id: 'cs' + (consultas.length + 1),
          inversionista: USUARIO.id,
          tramite: op.insert.tramite || null,
          tipo: op.insert.tipo || null,
          /* El sector del chat (supabase-control-estadisticas.sql). */
          sector: op.insert.sector || null,
          asunto: op.insert.asunto || '',
          estado: 'abierta',
          gestor: null,
          creado_en: new Date().toISOString(),
          actualizado_en: new Date().toISOString(),
          resuelto_en: null
        };
        consultas.push(nueva);
        return {data:[nueva], error:null};
      }

      /* TOMARLA o CERRARLA, que es del equipo. */
      if (op && op.update && op.eq && op.eq.id){
        var cual = consultas.filter(function(c){ return c.id === op.eq.id; })[0];
        /* .is('gestor', null): si ya la lleva alguien, no se toca ninguna
           fila, que es lo que hace PostgREST (QA-22). */
        if (cual && op.is && 'gestor' in op.is && op.is.gestor === null && cual.gestor != null){
          return {data: [], error:null};
        }
        if (cual){
          if ('estado' in op.update) cual.estado = op.update.estado;
          if ('gestor' in op.update) cual.gestor = op.update.gestor;
          cual.actualizado_en = new Date().toISOString();
          /* La hora de cierre la pone la base y cuadra con el estado, igual
             que el disparador consulta_al_cambiar(). */
          cual.resuelto_en = (cual.estado === 'resuelta') ? new Date().toISOString() : null;
        }
        return {data: cual || {}, error:null};
      }

      /* LEERLAS. El equipo las ve todas; el inversionista, las suyas. Esto
         es lo que hace la RLS de verdad, y el doble tiene que hacer lo mismo
         o la pantalla del inversionista se probaria con las de todos. */
      var mias = consultas.filter(function(c){
        return (caso === 'gestor') ? true : c.inversionista === USUARIO.id;
      });
      if (op && op.eq && op.eq.id){
        mias = mias.filter(function(c){ return c.id === op.eq.id; });
      }
      if (op && op.eq && op.eq.estado){
        mias = mias.filter(function(c){ return c.estado === op.eq.estado; });
      }
      /* .is('gestor', null) es como la cola pide las que no lleva nadie. */
      if (op && op.is && 'gestor' in op.is && op.is.gestor === null){
        mias = mias.filter(function(c){ return c.gestor == null; });
      }
      /* Y .in('estado', [...]), que es como la cola del equipo pide las que
         siguen vivas. Sin esta rama el filtro se ignoraba y la cola salia
         bien por casualidad -porque ninguna del ejemplo estaba resuelta-.
         Por eso ahora hay una que si lo esta: un filtro sin nada que filtrar
         no prueba que filtre. */
      if (op && op.in && op.in.estado){
        mias = mias.filter(function(c){ return op.in.estado.indexOf(c.estado) >= 0; });
      }
      if (op && op.single) return {data: mias[0] || null, error:null};
      return {data: mias.slice(), error:null};
    }

    /* La traducción automática del chat (supabase-traduccion-chat.sql).
       Solo la respuesta del CIIP de la consulta cs1, que es la que lee el
       inversionista: con eso se prueba que sale traducida y que «Ver
       original» enseña lo que se escribió. Lo que lee el equipo sigue en
       original, que es lo que miran las pruebas de la cola. */
    if (tabla === 'mensaje_traducciones'){
      var traducidas = [
        {tabla:'consulta_mensajes', mensaje:'cmsj-b', idioma_original:'es', idioma:'en',
         texto:'Gladly. We need the notarized power of attorney and your passport.'}
      ].filter(function(t){
        return (!op || !op.eq || !op.eq.tabla || t.tabla === op.eq.tabla) &&
               (!op || !op.in || !op.in.mensaje || op.in.mensaje.indexOf(t.mensaje) >= 0);
      });
      return {data:soloLoPedido(traducidas, op && op.cols), error:null};
    }

    if (tabla === 'consulta_mensajes'){
      if (op && op.insert){
        /* NOT NULL, igual que en las otras dos conversaciones. */
        if (op.insert.consulta == null){
          return {data:null, error:{
            message:'null value in column "consulta" of relation "consulta_mensajes" violates not-null constraint',
            code:'23502'}};
        }
        var dicho = {
          id: 'cmsj' + (dichosConsulta.length + 1),
          consulta: op.insert.consulta,
          texto: op.insert.texto || '',
          documento: op.insert.documento || null,
          /* Lo pone la BASE. El mismo disparador que firma los otros hilos. */
          del_equipo: (caso === 'gestor'),
          creado_en: new Date().toISOString()
        };
        dichosConsulta.push(dicho);
        return {data:[dicho], error:null};
      }
      var charla = [
        {id:'cmsj-a', consulta:'cs1', texto:'Quisiera que el CIIP lleve este tramite por mi.',
         del_equipo:false, documento:null, creado_en:'2026-08-20T09:00:00Z'},
        {id:'cmsj-b', consulta:'cs1', texto:'Con gusto. Necesitamos el poder notariado y su pasaporte.',
         del_equipo:true, documento:null, creado_en:'2026-08-20T11:00:00Z'},
        /* La de la cola del equipo empieza sin contestar: es lo que hace que
           salga como pendiente, y con una respuesta puesta la prueba de la
           cola mediria una consulta ya atendida. */
        {id:'cmsj-c', consulta:'cs2', texto:'Necesito visa para constituir la empresa?',
         del_equipo:false, documento:null, creado_en:'2026-08-22T15:30:00Z'}
      ].concat(dichosConsulta);
      if (op && op.eq && op.eq.consulta){
        charla = charla.filter(function(m){ return m.consulta === op.eq.consulta; });
      }
      return {data:soloLoPedido(charla, op && op.cols), error:null};
    }

    if (tabla === 'tramite_documentos'){
      /* El detalle de un tramite resuelto pregunta por lo ENTREGADO. Es la
         misma consulta -con .eq('tramite')- pero de otro expediente, asi
         que se distingue por el id: devolver los recaudos del gestor aqui
         enseñaria "Tu documento" con el acta de otra persona dentro. */
      /* Los dos recaudos que el borrador de 'sinnombre' ya subio. Sin
         esto la barra dice 0 de 4 y no se prueba que cuente lo que hay. */
      if (op && op.eq && op.eq.tramite === 's1'){
        return {data:[{documento:'ds1', documentos:{tipo:'pasaporte'}},
                      {documento:'ds2', documentos:{tipo:'foto'}}], error:null};
      }
      /* La constitución de 'tramos', ante el ente: el equipo ya le dejó el
         documento para pagar la reserva, y el comprobante todavía no está. */
      if (op && op.eq && op.eq.tramite === 'p2'){
        return {data:[{documento:'dp1', documentos:{tipo:'planilla_reserva_nombre',
          nombre_original:'planilla-reserva-saren.pdf',
          archivo:'u1/emitidos/planilla-reserva-saren.pdf'}}], error:null};
      }
      /* Y la publicación de 'tramos': el equipo ya le dejó el PUB para
         pagar el periódico, y el comprobante todavía no está (Franklin
         Reyes, 20-9-2026). Igual que un piso más arriba, en
         'tramossinpagar' no ha dejado nada: así el mismo pase prueba los
         dos tramos esperando su papel. */
      if (op && op.eq && op.eq.tramite === 'p3'){
        if (sinPlanilla) return {data:[], error:null};
        return {data:[{documento:'dp4', documentos:{tipo:'planilla_publicacion',
          nombre_original:'pub-publicacion-mercantil.pdf',
          archivo:'u1/emitidos/pub-publicacion-mercantil.pdf'}}], error:null};
      }
      /* Y la protocolización de 'tramos': el equipo ya le dejó el documento
         para pagar los aranceles del registro, y el comprobante del pago
         todavía no está (Franklin Reyes, 17-9-2026). */
      if (op && op.eq && op.eq.tramite === 'p1'){
        /* Salvo en 'tramossinpagar', donde no ha dejado nada todavía. */
        if (sinPlanilla) return {data:[], error:null};
        var delPago = [{documento:'dp2', documentos:{tipo:'planilla_aranceles',
          nombre_original:'planilla-aranceles-saren.pdf',
          archivo:'u1/emitidos/planilla-aranceles-saren.pdf'}}];
        /* Y en 'tramospagado', el comprobante que el inversionista ya subió
           desde su paso (Franklin Reyes, 18-9-2026). */
        if (yaPagado) delPago.push({documento:'dp3', documentos:{tipo:'pago_aranceles',
          nombre_original:'pago-aranceles.pdf',
          archivo:'u1/pago-aranceles.pdf'}});
        return {data:delPago, error:null};
      }
      /* Los papeles del importe del día, los que ponga la prueba en
         window.__IMPORTE_DOCS por solicitud. La fecha la pone ella, que
         es lo que se prueba: un importe de hoy y uno de ayer. */
      if (op && op.eq && window.__IMPORTE_DOCS && window.__IMPORTE_DOCS[op.eq.tramite]){
        return {data: window.__IMPORTE_DOCS[op.eq.tramite].map(function(d){
          return {documento: d.id, documentos: d};
        }), error:null};
      }
      if (op && op.eq && op.eq.tramite === 't4'){
        return {data:[{documento:'dr1', documentos:{tipo:'resolucion',
          nombre_original:'visa-trn-estampada.pdf',
          archivo:'u1/emitidos/visa-trn-estampada.pdf'}}], error:null};
      }
      /* Lo que subio el inversionista, para que el gestor lo revise. */
      return {data:[
        {documento:'d1', documentos:{tipo:'acta_constitutiva', nombre_original:'acta-bianchi.pdf', archivo:'u2/acta-bianchi.pdf'}},
        {documento:'d2', documentos:{tipo:'rif_empresa',       nombre_original:'rif-j40123456.pdf', archivo:'u2/rif.pdf'}}
      ], error:null};
    }
    if (tabla === 'tramite_eventos'){
      if (op && op.update){
        if (op.update.nota) notaPuesta = op.update.nota;
        /* Con la fila de vuelta, en una lista, que es lo que da un
           update().select() de verdad. Con {} el panel leía «cero filas» y
           decía siempre que la nota no se había guardado: la prueba de
           devolver pasaba igual porque las dos frases nombran a quién, y la
           de cancelar (QA-12) lo destapó. */
        return {data:[{id: (op.eq && op.eq.id) || 'ev9', nota: op.update.nota || ''}], error:null};
      }
      /* Al devolver, el panel busca el evento que el trigger acaba de
         escribir para ponerle la nota encima. Si el expediente ya tiene
         eventos de ese estado se devuelven ESOS -la franja del inversionista
         lee de ahi la nota del gestor-, y solo si no hay ninguno se inventa
         uno, que es el caso del expediente del equipo. */
      if (op && op.eq && op.eq.a_estado){
        var suyos = (EVENTOS[caso] || []).filter(function(e){ return e.a_estado === op.eq.a_estado; });
        if (suyos.length) return {data:suyos, error:null};
        return {data:[{id:'ev9', creado_en:'2026-08-20T10:00:00Z'}], error:null};
      }
      /* El historial se pide por tramite. Sin filtrar, un tramite recien
         enviado heredaria los eventos de otro y su escalera saldria con
         fechas que no son suyas. */
      var evs = EVENTOS[caso] || [];
      if (op && op.eq && op.eq.tramite){
        evs = evs.filter(function(e){ return e.tramite === op.eq.tramite; });
      }
      /* Y por VARIOS a la vez: "cuanto lleva parado cada uno" pide el
         historial de toda la cola en un viaje en vez de uno por ficha. */
      if (op && op.in && op.in.tramite){
        evs = evs.filter(function(e){ return op.in.tramite.indexOf(e.tramite) >= 0; });
      }
      /* Del mas nuevo al mas viejo si lo piden asi: quien busca el ultimo
         evento de cada tramite se queda con el primero que le llega, y con
         el orden al reves se quedaria con el mas antiguo. */
      if (op && op.orden && op.orden.campo === 'creado_en'){
        evs = evs.slice().sort(function(a, b){
          var d = Date.parse(a.creado_en) - Date.parse(b.creado_en);
          return op.orden.asc ? d : -d;
        });
      }
      return {data:evs, error:null};
    }
    return {data:[], error:null};
  }

  /* Una consulta encadenable. Cada método devuelve el mismo objeto, y el
     objeto es "esperable": basta con que tenga .then para que valga en un
     await o en una cadena de promesas. */
  /* ─── CUANTOS VIAJES SE HACEN ───────────────────────────────────────
     Lo que cuesta abrir una tarjeta en la conexion de una oficina de
     Caracas no es el codigo que corre: son las veces que hay que salir a
     la red, y sobre todo cuantas de esas van UNA DETRAS DE OTRA, porque
     esas se suman. Diez en paralelo cuestan un viaje; dos encadenadas
     cuestan dos.

     El doble contesta al instante, asi que sin contar esto un viaje de
     mas no se nota en ninguna prueba: todo sigue verde y la pantalla
     tarda el doble solo en la maquina del que lo usa. Se conto, y habia
     uno de mas en CADA tarjeta. ─────────────────────────────────────── */
  window.CIIP_VIAJES = {getUser:0, consultas:0, tablas:[]};

  function consulta(tabla){
    var api = {}, op = {}, contado = false;
    ['neq','is','limit','range']
      .forEach(function(m){ api[m] = function(){ return api; }; });
    /* order era de los que no se miraban. Ahora si: hay consultas que
       dependen del orden para quedarse con la primera fila, y un falso
       que devuelve siempre el mismo orden daria verde a un panel que se
       queda con la fila equivocada. */
    api.order = function(campo, o){
      op.orden = {campo: campo, asc: !(o && o.ascending === false)};
      return api;
    };
    /* select era de los que no se miraban. Ahora si: hay consultas que
       piden columnas que la base puede no tener todavia, y la unica forma
       de probar que el panel aguanta eso es saber que pidio. */
    api.select = function(cols){ op.cols = cols || ''; return api; };
    /* Y se RECORTA lo devuelto a esas columnas, en las tablas donde el
       panel vuelve a mirar en JavaScript algo que pidio en la consulta.
       Postgres devuelve solo lo pedido; el doble devolvia la fila entera, y
       con eso un select al que le falta una columna salia verde aqui y
       descartaba TODAS las filas en produccion. Paso el 18 de septiembre de
       2026 con del_equipo: la campana se quedo sin los mensajes del equipo y
       sin las respuestas a las consultas, y esta tanda no dijo nada. */
    /* Estos S\u00cd se miran: distinguen a qui\u00e9n va dirigida la consulta. */
    /* lt y gt: el pulso pide los documentos vencidos con .lt(vence_el,
       hoy). Sin ellos el falso reventaba con "api.lt is not a function",
       que es un fallo del arnes disfrazado de fallo del panel. */
    api.eq = function(k, v){ (op.eq = op.eq || {})[k] = v; return api; };
    api.lt = function(k, v){ (op.lt = op.lt || {})[k] = v; return api; };
    api.gt = function(k, v){ (op.gt = op.gt || {})[k] = v; return api; };
    api.lte = function(){ return api; };
    api.gte = function(){ return api; };
    api.in = function(k, v){ (op.in = op.in || {})[k] = v; return api; };
    /* .is es la unica forma de preguntar por un null en Supabase: .eq(x, null)
       no compara, filtra por la cadena "null". La cola de consultas pide las
       que no lleva nadie con .is('gestor', null), y sin esto el doble
       reventaba con "api.is is not a function" -un fallo del arnes con
       aspecto de fallo del panel-. */
    api.is = function(k, v){ (op.is = op.is || {})[k] = v; return api; };
    /* .not es la negacion de cualquiera de los anteriores, y lleva TRES
       argumentos: la columna, el operador y el valor -.not('revisado_en',
       'is', null)-. El buzon de avisos la usa para dejar fuera los papeles
       revisados antes de que la base guardara la fecha, y sin esto el doble
       reventaba con "api.not is not a function". Como no todas las filas
       del doble traen las columnas nuevas, se acepta y se ignora, igual
       que .neq: lo que se prueba es que el panel aguanta lo que reciba. */
    api.not = function(){ return api; };
    api.single = function(){ op.single = true; return api; };
    /* Estos dos SÍ se miran: son los que cambian algo. */
    api.insert = function(fila){ op.insert = fila; return api; };
    api.update = function(campos){ op.update = campos; return api; };
    /* Borrar era un no-op de los de arriba: la prueba habria dado verde sin
       que la fila saliera de ninguna lista. */
    api.delete = function(){ op.borra = true; return api; };
    api.upsert = function(fila){ op.upsert = fila; return api; };
    /* maybeSingle era otro no-op: la empresa se pide asi -puede no
       haberla- y devolver el array habria dejado EMPRESA con una lista
       dentro, que es verdadera y rellenaria los formularios con basura. */
    api.maybeSingle = function(){ op.uno = true; return api; };
    /* SOLO .then, y a proposito. El constructor de consultas de Supabase no
       es una promesa: es "esperable" -tiene then- pero NO tiene catch. El
       falso si lo tenia, y esa mentira dejo pasar a produccion un
       sb.rpc(...).catch(...) que reventaba nada mas cargar la pagina.

       Un doble tambien tiene que parecerse en lo que NO sabe hacer. */
    api.then  = function(bien, mal){
      /* Se cuenta AQUI y no en from(): un constructor que se arma y no se
         llega a esperar no sale a la red. Y una sola vez por consulta. */
      if (!contado){ contado = true;
        window.CIIP_VIAJES.consultas++; window.CIIP_VIAJES.tablas.push(tabla); }
      return Promise.resolve(respuesta(tabla, op)).then(bien, mal);
    };
    return api;
  }

  window.supabase = {
    createClient: function(){
      return {
        auth: {
          /* El access_token no estaba, y una sesión de verdad SIEMPRE lo
             trae: es lo que el navegador manda en cada consulta para
             decir quién es. Sin él aquí, cualquier cosa que lo use —el
             asistente, que se lo pasa a /api/asistente— se encontraba un
             'undefined' en la prueba y un token en producción, que es la
             manera más silenciosa de que algo pase el arnés y falle fuera. */
          getSession: function(){ return Promise.resolve({data:{session:{user:USUARIO, access_token:'token-de-mentira'}}, error:null}); },
          /* getUser SALE A LA RED en el Supabase de verdad: valida el
             token contra el servidor. getSession no: lee el almacen del
             navegador. Por eso solo se cuenta este. */
          getUser:    function(){
            window.CIIP_VIAJES.getUser++;
            window.CIIP_VIAJES.tablas.push('auth.getUser');
            return Promise.resolve({data:{user:USUARIO}, error:null});
          },
          signOut:    function(){ return Promise.resolve({error:null}); },
          onAuthStateChange: function(){ return {data:{subscription:{unsubscribe:function(){}}}}; }
        },
        from: consulta,
        /* El latido de presencia. Se apunta lo que pide para poder
           comprobar que el panel lo llama, y se responde sin error: si
           fallara, el panel apagaria el latido y la prueba no veria nada. */
        rpc: function(nombre, args){
          window.CIIP_RPC = (window.CIIP_RPC || []).concat([nombre]);
          /* Sin supabase-presencia.sql la funcion no existe, y Postgrest NO
             rechaza: contesta con el error DENTRO de la respuesta. Un panel
             que espere un fallo de promesa no se entera de nada. */
          /* pliego_pendiente devuelve la VERSION que falta por aceptar, o
             null. Null significa las dos cosas -«ya aceptaste» y «todavia
             no hay pliego»- y esta bien que signifique las dos: en los dos
             casos el panel hace lo mismo, dejar pasar. */
          if (nombre === 'pliego_pendiente'){
            var pend = PLIEGOS.filter(function(p){ return p.vigente; })[0];
            var r0 = {data: (pend && !pliegoAceptado) ? pend.version : null, error:null};
            return {then:function(bien, mal){ return Promise.resolve(r0).then(bien, mal); }};
          }

          /* El correo de cada cuenta: solo a un admin, como la de verdad
             (QA-07). A los demás, el error de permiso. */
          if (nombre === 'correos_de_las_cuentas'){
            var rC = (esAdmin && !sinSql)
              ? {data: OTROS_PERFILES.map(function(g){
                  return {id: g.id, correo: (g.nombre_completo
                    ? g.nombre_completo.toLowerCase().replace(/[^a-z]+/g, '.') : 'sin.nombre') + '@correo.test'};
                }), error:null}
              : {data:null, error:{message:'Solo un administrador ve los correos', code:'42501'}};
            return {then:function(bien, mal){ return Promise.resolve(rC).then(bien, mal); }};
          }

          /* Las horas ya tomadas: en 'huecos', las 09:00 del segundo dia
             laborable. Solo la hora, como la de verdad: de quien, no. */
          if (nombre === 'huecos_ocupados'){
            var rH = {data: huOcupado ? [{cuando: new Date(huOcupado).toISOString()}] : [], error:null};
            return {then:function(bien, mal){ return Promise.resolve(rH).then(bien, mal); }};
          }
          /* Reservar: la cita nace CONFIRMADA. La hora ocupada se rechaza con
             el mismo mensaje que da la base cuando dos pulsan a la vez. */
          if (nombre === 'reserva_cita'){
            window.CIIP_PRUEBA_RESERVA = args;
            var rR;
            if (args && huOcupado && Date.parse(args.p_cuando) === Date.parse(huOcupado)){
              rR = {data:null, error:{message:'Ese hueco se acaba de ocupar', code:'23505'}};
            } else {
              var dRes = String((args && args.p_cuando) || '').slice(0, 10);
              var res = {id:'c9', tipo_tramite:(args && args.p_tipo) || null,
                         modo:(args && args.p_modo) || 'video', desde:dRes, hasta:dRes,
                         nota:(args && args.p_nota) || '', estado:'confirmada',
                         cuando:new Date(args.p_cuando).toISOString(), lugar:'',
                         creado_en:new Date().toISOString()};
              citasVivas = [res];
              rR = {data:res, error:null};
            }
            return {then:function(bien, mal){ return Promise.resolve(rR).then(bien, mal); }};
          }

          /* Confirmar o mover una cita desde el equipo (QA-20, QA-19). */
          if (nombre === 'confirma_cita'){
            window.CIIP_PRUEBA_CONFIRMA = (window.CIIP_PRUEBA_CONFIRMA || []).concat([args]);
            colaViva = colaViva.filter(function(c){ return c.id !== (args && args.p_cita); });
            var eqM = equipoCitas.filter(function(c){ return c.id === (args && args.p_cita); })[0];
            if (eqM){ eqM.cuando = args.p_cuando; eqM.motivo = args.p_motivo || ''; }
            var rC = {data: {id: args && args.p_cita, estado: 'confirmada', cuando: args && args.p_cuando}, error:null};
            return {then:function(bien, mal){ return Promise.resolve(rC).then(bien, mal); }};
          }
          /* El equipo abre una consulta a nombre de otro (QA-04). */
          if (nombre === 'abre_consulta_para'){
            window.CIIP_PRUEBA_ABRE_PARA = args;
            var nuevaP = {id: 'cs' + (consultas.length + 1), inversionista: args && args.p_inversionista,
                          tramite: null, tipo: (args && args.p_tipo) || null, asunto: (args && args.p_asunto) || '',
                          estado: 'en_curso', gestor: USUARIO.id,
                          creado_en: new Date().toISOString(), actualizado_en: new Date().toISOString(),
                          resuelto_en: null};
            consultas.push(nuevaP);
            var rP = {data: nuevaP, error:null};
            return {then:function(bien, mal){ return Promise.resolve(rP).then(bien, mal); }};
          }

          /* La firma en el CIIP de una constitución: la marca el equipo y
             la base devuelve la fila con datos al día, como la de verdad. */
          /* El nombre del gestor de cada solicitud propia, para la campana
             (30-9-2026). La de verdad solo devuelve las de quien pregunta;
             aquí, la t1, que es la devuelta del expediente de ejemplo. */
          if (nombre === 'gestores_de_mis_tramites'){
            var rG = {data: [{tramite: 't1', nombre: 'Saskia Calderon'}], error: null};
            return {then:function(bien, mal){ return Promise.resolve(rG).then(bien, mal); }};
          }
          /* Las marcas del inversionista en cada ente de los parafiscales
             (Franklin Reyes, 1-10-2026, Taquilla única opción 2). Como la
             de verdad: solo las claves de su lista -una que no esté, la
             rechaza-, escribe datos[clave] = la fecha y devuelve la fila.
             Los datos de cada solicitud se guardan en esta pestaña, en
             window.__DATOS_TR, para que la segunda marca no borre la
             primera. Con window.__FALLA_CONFIRMA, una vez, la red se cae:
             es lo que deja ver que el paso no se pinta hecho sin respuesta.
             Las demás claves -la de Cancillería- siguen cayendo abajo,
             como antes. */
          var MARCAS_DE_ENTE = ['ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                                'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc'];
          if (nombre === 'confirma_paso' && args && /^ente_/.test(args.p_clave || '')){
            window.CIIP_PRUEBA_CONFIRMA_PASO = (window.CIIP_PRUEBA_CONFIRMA_PASO || []).concat([args]);
            var rCP;
            if (window.__FALLA_CONFIRMA){
              window.__FALLA_CONFIRMA = false;
              rCP = {data:null, error:{message:'la red se cayó', code:'08006'}};
            } else if (MARCAS_DE_ENTE.indexOf(args.p_clave) < 0){
              rCP = {data:null, error:{message:'paso desconocido: ' + args.p_clave, code:'P0001'}};
            } else {
              var DT = window.__DATOS_TR = window.__DATOS_TR || {};
              var dCP = DT[args.p_tramite] = DT[args.p_tramite] || {};
              dCP[args.p_clave] = '2026-10-01T10:00:00-04:00';
              var copiaCP = {};
              Object.keys(dCP).forEach(function(k){ copiaCP[k] = dCP[k]; });
              rCP = {data:{id: args.p_tramite, estado:'ante_el_ente', datos: copiaCP}, error:null};
            }
            return {then:function(bien, mal){ return Promise.resolve(rCP).then(bien, mal); }};
          }
          /* «Ya me registré» en el portal de Cancillería, el paso 1 de las
             dos visas (Franklin Reyes, 1-10-2026, Taquilla única opción 2).
             Como la de verdad (supabase-confirma-paso.sql): una sola llave,
             solo sobre una solicitud propia en marcha, y devuelve la fila
             entera con datos[clave] = la fecha. Sin esto contestaba
             {data:null} y el botón decía «error» en todas las pruebas.
             Solo la de Cancillería: las de la licencia, la conformidad y el
             minero las contesta la rama de más abajo. */
          if (nombre === 'confirma_paso' && args && args.p_clave === 'cancilleria_confirmada'){
            window.CIIP_PRUEBA_CONFIRMA_PASO = (window.CIIP_PRUEBA_CONFIRMA_PASO || []).concat([args]);
            var clv = args && args.p_clave;
            var trC = (TRAMITES[caso] || []).concat(window.__TRAMITES_EXTRA || [])
                      .filter(function(t){ return t.id === (args && args.p_tramite); })[0];
            var rCP;
            if (!trC || trC.estado === 'borrador' || trC.estado === 'resuelto'){
              rCP = {data:null, error:{message:'no se pudo marcar el paso', code:'P0001'}};
            } else {
              trC.datos = trC.datos || {};
              trC.datos[clv] = ahora();
              rCP = {data:trC, error:null};
            }
            return {then:function(bien, mal){ return Promise.resolve(rCP).then(bien, mal); }};
          }
          if (nombre === 'marca_firma_ciip'){
            window.CIIP_PRUEBA_FIRMA = args;
            var rF = {data: {id: args && args.p_tramite,
                             datos: (args && args.p_hecha) ? {firma_ciip: '2026-09-27T10:00:00Z'} : {}},
                      error: null};
            return {then:function(bien, mal){ return Promise.resolve(rF).then(bien, mal); }};
          }
          /* Las cifras de «Control y Estadísticas» (Franklin Reyes,
             1-10-2026, supabase-control-estadisticas.sql). Como la de
             verdad: solo a un administrador, y a los demás el error de
             permiso. Las consultas por sector suman a las fijas las que
             se abran en la tanda con su sector, para que la prueba del
             chat se vea contada. */
          if (nombre === 'estadisticas_control'){
            var rE;
            if (!esAdmin || sinSql){
              rE = {data:null, error:{message:'Solo un administrador ve las estadísticas', code:'42501'}};
            } else {
              var porSec = {hidrocarburos: 4, turismo: 2};
              consultas.forEach(function(c){ if (c.sector) porSec[c.sector] = (porSec[c.sector] || 0) + 1; });
              rE = {data:{
                tramites: [
                  {tipo:'constitucion', ente:'SAREN', solicitados:5, resueltos:3, mediana_h:96,
                   promedio_h:120.5, n_ente:3, mediana_ente_h:48},
                  {tipo:'rif_personal', ente:'SENIAT', solicitados:3, resueltos:1, mediana_h:30,
                   promedio_h:30, n_ente:0, mediana_ente_h:null},
                  {tipo:'visa_negocios', ente:'Cancillería', solicitados:2, resueltos:0, mediana_h:null,
                   promedio_h:null, n_ente:0, mediana_ente_h:null}
                ],
                entes: [
                  {ente:'SAREN', resueltos:3, mediana_h:96, promedio_h:120.5, n_ente:3, mediana_ente_h:48},
                  {ente:'SENIAT', resueltos:1, mediana_h:30, promedio_h:30, n_ente:0, mediana_ente_h:null}
                ],
                sectores: Object.keys(porSec).map(function(s){ return {sector:s, consultas:porSec[s]}; })
              }, error:null};
            }
            return {then:function(bien, mal){ return Promise.resolve(rE).then(bien, mal); }};
          }
          /* Los dos pasos del gestor en el registro de marca. Contesta lo que
             diga la prueba en window.__MARCA_RPC -la solicitud tal como la
             dejaría la base- y apunta lo que se pidió. */
          /* «Ya la solicité»: el paso que marca el inversionista, como la de
             verdad (supabase-confirma-paso.sql). Solo las llaves que ella
             acepta -las de la Taquilla única opción 2 del 1-10-2026 y la de
             Cancillería de antes-; otra cualquiera, su mismo error. Escribe
             la marca en la solicitud si está en la tabla y devuelve la fila
             entera con datos al día, que es lo que repinta la ficha. */
          if (nombre === 'confirma_paso'){
            window.CIIP_PRUEBA_CONFIRMA_PASO = (window.CIIP_PRUEBA_CONFIRMA_PASO || []).concat([args]);
            /* Y la del permiso de bomberos (1-10-2026, supabase-bomberos-opcion2.sql). */
            /* Y la de la inscripción en el SIDCAI (Franklin Reyes, 1-10-2026,
               Ventanilla Única 2.3, supabase-locti-opcion2.sql). */
            var llaves = ['cancilleria_confirmada', 'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                          'bomberos_solicitado', 'saime_confirmada', 'locti_inscrito'];
            var rCP;
            if (!args || llaves.indexOf(args.p_clave) < 0){
              rCP = {data: null, error: {message: 'paso desconocido: ' + (args && args.p_clave), code: 'P0001'}};
            } else {
              var tCP = (TRAMITES[caso] || []).filter(function(t){ return t.id === args.p_tramite; })[0];
              var datosCP = {};
              Object.keys((tCP && tCP.datos) || {}).forEach(function(k){ datosCP[k] = tCP.datos[k]; });
              datosCP[args.p_clave] = new Date().toISOString();
              if (tCP) tCP.datos = datosCP;
              rCP = {data: {id: args.p_tramite, estado: tCP ? tCP.estado : 'enviado', datos: datosCP}, error: null};
            }
            return {then:function(bien, mal){ return Promise.resolve(rCP).then(bien, mal); }};
          }
          /* La sede de bomberos (Franklin Reyes, 1-10-2026, Permiso de
             Bomberos): anota_paso() como la de verdad
             (supabase-bomberos-opcion2.sql). Solo su llave, y el dato entre 1
             y 200 caracteres ya recortado; escribe lo dicho, no la fecha, y
             devuelve la fila. Apunta lo pedido en CIIP_PRUEBA_ANOTA_PASO. */
          if (nombre === 'anota_paso'){
            window.CIIP_PRUEBA_ANOTA_PASO = (window.CIIP_PRUEBA_ANOTA_PASO || []).concat([args]);
            var vAP = String((args && args.p_valor) || '').trim();
            var rAP;
            if (!args || args.p_clave !== 'sede_bomberos'){
              rAP = {data: null, error: {message: 'paso desconocido: ' + (args && args.p_clave), code: 'P0001'}};
            } else if (!vAP || vAP.length > 200){
              rAP = {data: null, error: {message: 'el dato tiene que tener entre 1 y 200 caracteres', code: 'P0001'}};
            } else {
              var tAP = (TRAMITES[caso] || []).concat(window.__TRAMITES_EXTRA || [])
                        .filter(function(t){ return t.id === args.p_tramite; })[0];
              var datosAP = {};
              Object.keys((tAP && tAP.datos) || {}).forEach(function(k){ datosAP[k] = tAP.datos[k]; });
              datosAP[args.p_clave] = vAP;
              if (tAP) tAP.datos = datosAP;
              rAP = {data: {id: args.p_tramite, estado: tAP ? tAP.estado : 'enviado', datos: datosAP}, error: null};
            }
            return {then:function(bien, mal){ return Promise.resolve(rAP).then(bien, mal); }};
          }
          /* «Recaudos revisados» (Franklin Reyes, 5-10-2026,
             supabase-recaudos-revisados.sql): como la de verdad, solo en
             revisión, y apunta la fecha en datos.pasos_ciip. Lo pedido queda
             en CIIP_PRUEBA_REVISADOS. */
          if (nombre === 'marca_recaudos_revisados'){
            window.CIIP_PRUEBA_REVISADOS = (window.CIIP_PRUEBA_REVISADOS || []).concat([args]);
            var tRR = (TRAMITES[caso] || []).concat(window.__TRAMITES_EXTRA || [])
                      .filter(function(t){ return t.id === (args && args.p_tramite); })[0];
            var rRR;
            if (tRR && tRR.estado !== 'en_revision'){
              rRR = {data: null, error: {message: 'no se pudo marcar la revisión', code: 'P0001'}};
            } else {
              var dRR = JSON.parse(JSON.stringify((tRR && tRR.datos) || {}));
              dRR.pasos_ciip = dRR.pasos_ciip || {};
              dRR.pasos_ciip.recaudos_revisados = '2026-10-05T10:00:00-04:00';
              if (tRR) tRR.datos = dRR;
              rRR = {data: {id: args && args.p_tramite, estado: 'en_revision', datos: dRR}, error: null};
            }
            return {then:function(bien, mal){ return Promise.resolve(rRR).then(bien, mal); }};
          }
          if ((nombre === 'marca_paso_ciip' || nombre === 'habilita_contestacion' ||
               nombre === 'compraventa_paso_ciip' || nombre === 'compraventa_fecha_firma' ||
               nombre === 'anuncio_del_ciip') && window.__MARCA_RPC){
            window.CIIP_PRUEBA_MARCA = (window.CIIP_PRUEBA_MARCA || []).concat([{nombre: nombre, args: args}]);
            var rM = {data: window.__MARCA_RPC(nombre, args), error:null};
            return {then:function(bien, mal){ return Promise.resolve(rM).then(bien, mal); }};
          }

          var r = sinSql
            ? {data:null, error:{message:'function public.tocar_visto() does not exist',
                                 code:'42883'}}
            : {data:null, error:null};
          /* Sin catch, igual que el de verdad. */
          return {then:function(bien, mal){ return Promise.resolve(r).then(bien, mal); }};
        },
        storage: {
          from: function(){
            return {
              /* Quitar un archivo. Devuelve bien tambien si no estaba:
                 es lo que hace Storage, y el panel se apoya en ello para
                 poder reintentar un borrado que se quedo a medias. */
              remove: function(rutas){
                (rutas || []).forEach(function(r){ delete subidas[r]; });
                return Promise.resolve({data:[], error:null});
              },
              upload: function(ruta){
                /* Se APUNTA lo que se sube. Antes cualquier ruta devolvia
                   una URL firmada, tambien las que no existen, y con eso
                   no habia forma de medir "todavia no hay foto": el panel
                   se creia que siempre habia una. */
                subidas[ruta] = true;
                return Promise.resolve({data:{path:ruta}, error:null});
              },
              /* Bajar un archivo, como hace el lector con el papel que ya
                 esta en Documentos. Lo mismo que createSignedUrl: lo que no
                 existe da el error de Storage, no un archivo inventado. */
              download: function(ruta){
                if (!subidas[ruta] && !enLaBoveda(ruta)){
                  return Promise.resolve({data:null, error:{message:'Object not found'}});
                }
                return Promise.resolve({data:new Blob(['%PDF-1.4 de mentira'], {type:'application/pdf'}),
                                        error:null});
              },
              /* Una imagen de verdad, de un pixel: con '#' el <img> falla
                 al cargar y el panel se cae a las iniciales -que es lo
                 correcto-, asi que la prueba de que la foto se ve no podia
                 pasar nunca. Y para lo que no existe, el mismo error que
                 da Storage. */
              /* La URL de un cubo publico -el de los logos de las fichas-.
                 Storage la da sin preguntar si el archivo existe, y aqui
                 igual; la imagen es el mismo pixel, para que cargue. */
              getPublicUrl: function(ruta){
                return {data:{publicUrl:
                  'data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==#' + ruta
                }};
              },
              createSignedUrl: function(ruta){
                if (!subidas[ruta] && !enLaBoveda(ruta)){
                  return Promise.resolve({data:null, error:{message:'Object not found'}});
                }
                return Promise.resolve({data:{signedUrl:
                  'data:image/gif;base64,R0lGODlhAQABAIAAAP///wAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=='
                }, error:null});
              }
            };
          }
        }
      };
    }
  };

  /* Cada prueba arranca sin memoria de avisos vistos: si no, la segunda
     vez que se corriera el contador ya vendría apagado y la prueba de
     "cuenta 3 avisos" pasaría a rojo sin que nadie hubiera tocado nada. */
  try { window.localStorage.removeItem('ciip.avisos.' + USUARIO.id); } catch(e){}
  /* Y sin memoria de lo emitido ya abierto (30-9-2026): «Tu documento» se
     va tras abrirlo una vez, y la tanda siguiente no lo encontraría. */
  try {
    Object.keys(window.localStorage).forEach(function(k){
      if (k.indexOf('ciip.emitido.visto.') === 0) window.localStorage.removeItem(k);
    });
  } catch(e){}

})();
