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

  /* El catálogo, con los tres tipos que usan las pruebas. ref_panel es lo
     que ata cada tipo a su tarjeta del panel (data-tr). */
  var TIPOS = [
    {codigo:'rif_personal', ref_panel:'c3', ente:'SENIAT', activo:true,
     nombre:'RIF personal', fase:1,
     activo_por:null, activo_en: haceHoras(30)},
    {codigo:'constitucion', ref_panel:'c5', ente:'SAREN',  activo:true,
     nombre:'Constitución de empresa', fase:2},
    {codigo:'rif_empresa',  ref_panel:'c6', ente:'SENIAT', activo:true,
     nombre:'RIF de la empresa', fase:2},
    {codigo:'rnc',          ref_panel:'c13', ente:'RNC',   activo:true,
     nombre:'Registro Nacional de Contratistas', fase:3},
    {codigo:'solvencias',   ref_panel:'c14', ente:'Entes varios', activo:true,
     nombre:'Solvencias laborales', fase:3},
    /* Uno APAGADO a proposito. Con todos encendidos, la prueba de que el
       interruptor enciende no se puede distinguir de la de que no hace
       nada: los dos casos dejan la lista igual. */
    {codigo:'marca',        ref_panel:'c8', ente:'SAPI',   activo:false,
     nombre:'Registro de marca', fase:2,
     /* Con autor y fecha: es lo que lee el rastro. Uno apagado por
        alguien del equipo y otro encendido sin autor -hecho desde el
        editor de Supabase-, que son los dos casos que la pantalla tiene
        que saber contar distinto. */
     activo_por:'u4', activo_en: haceHoras(5)},
    /* La visa, que es la del tramite ya resuelto. Sin su tipo aqui, el
       panel no sabe a que tarjeta pertenece y la deja en "por iniciar"
       aunque el tramite este resuelto. */
    {codigo:'visa_inversionista', ref_panel:'c1', ente:'SAIME', activo:true,
     nombre:'Visa de inversionista', fase:1},
    /* La visa de dependientes pregunta pasaporte, pais emisor y fecha de
       nacimiento: las tres que la de inversionista ya contesto. Es donde se
       mide que no se pide dos veces lo mismo. */
    {codigo:'visa_dependientes', ref_panel:'c20', ente:'SAIME', activo:true,
     nombre:'Visa de dependientes', fase:1}
  ];

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
      {id:'t4', tipo:'visa_inversionista', estado:'resuelto',
       datos:{numero_pasaporte:'YB1234567', pais_emisor:'Italia',
              fecha_nacimiento:'1979-04-11'},
       creado_en:'2026-06-01T10:00:00Z', enviado_en:'2026-06-02T10:00:00Z',
       resuelto_en:'2026-06-18T10:00:00Z', actualizado_en:'2026-06-18T10:00:00Z'},
      /* Una SEGUNDA visa, mas NUEVA y en borrador. Con "la ultima creada"
         la tarjeta ensenaba el formulario en blanco sobre un tramite que
         YA ESTA RESUELTO: las dos pantallas del mismo tramite decian
         cosas distintas. */
      {id:'t5', tipo:'visa_inversionista', estado:'borrador', datos:{},
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
    ],
    sinnombre: [
      /* Un borrador SOLO, y a medio subir: es el unico expediente donde
         el aviso ensena el caso del borrador. En 'lleno' gana siempre el
         devuelto, y sin esto la barra de "2 de 4 recaudos" no la mira
         nadie. La visa pide cuatro obligatorios. */
      {id:'s1', tipo:'visa_inversionista', estado:'borrador',
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
  /* Lo que se borro en esta pasada, para que la lista lo respete. */
  var borrados = {};
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
       creado_en:'2026-08-07T09:00:00Z', enviado_en:'2026-08-07T09:00:00Z',
       gestor:'u4'}
    ],
    lleno: [], vacio: [], sinnombre: []
  };
  /* Doce solicitudes para el pase de mirar. Las fechas son RELATIVAS a hoy
     y no fijas: escritas a mano, «lleva esperando 17 días» se convierte en
     «lleva 200» con el tiempo y la pantalla acaba mintiendo sola. */
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
    {id:'d4', inversionista:'u5', tipo:'visa_inversionista', estado:'en_revision',
     datos:{numero_pasaporte:'TR8842019', pais_emisor:'Japón',
            consulado:'Consulado de Venezuela en Tokio'},
     creado_en: haceDias(4), enviado_en: haceDias(4), gestor:'u1'},
    {id:'d5', inversionista:'u9', tipo:'visa_dependientes', estado:'enviado',
     datos:{nombre_familiar:'Chen Li', parentesco:'Hijo/a', numero_pasaporte:'EA9920114'},
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

  /* La nota de una devolucion viaja en un UPDATE aparte, sobre el evento que
     escribe el trigger. Se guarda para que la prueba compruebe que llego:
     sin esto solo se sabria que el tramite cambio de estado. */
  var notaPuesta = null;
  window.PRUEBA_NOTA = function(){ return notaPuesta; };

  /* Una cita YA CONFIRMADA, para el buzon de avisos. Se fecha ANTES que los
     eventos de tramites a proposito: asi se comprueba que el buzon la mete
     en su sitio por fecha y no simplemente al final o al principio. */
  var CONFIRMADAS = {
    lleno: [{id:'k1', tipo_tramite:'constitucion', modo:'presencial',
             estado:'confirmada', desde:'2026-08-24', hasta:'2026-08-28', nota:'',
             cuando:'2026-08-26T14:00:00Z', lugar:'Torre CIIP, piso 4',
             creado_en:'2026-06-30T09:00:00Z',
             actualizado_en:'2026-07-01T09:00:00Z'}],
    vacio: [], sinnombre: [], gestor: []
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
       creado_en: dentroDe(37)}
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
    vacio: [],
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
  var IDENTIDAD = [];

  var USUARIO = {id:'u1', email:'f.reyes@ciip.com.ve',
                 user_metadata: (caso === 'sinnombre' ? {} : {nombre_completo:'Franklin Reyes', pais:'Italia'})};

  function respuesta(tabla, op){
    if (tabla === 'perfiles'){
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
      /* El buzon pide las confirmadas; son otra lista y otro sitio. */
      if (op && op.eq && op.eq.estado === 'confirmada'){
        return {data:(CONFIRMADAS[caso] || []), error:null};
      }
      if (op && op.eq && op.eq.estado === 'solicitada'){
        if (op.update){
          colaViva = colaViva.filter(function(c){ return c.id !== op.eq.id; });
          return {data:{}, error:null};
        }
        return {data:colaViva, error:null};
      }
      if (op && op.update && op.eq && op.eq.id){
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
      return {data:TIPOS, error:null};
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
         estado:'cargado', nota_revision:'', creado_en:'2026-08-01T10:00:00Z'}
      ]);
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
        {codigo:'comprobante_capital', vence:false}
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
      if (op && op.update && 'gestor' in op.update && op.eq && op.eq.id){
        var suyo = colaTram.filter(function(t){ return t.id === op.eq.id; })[0];
        if (suyo) suyo.gestor = op.update.gestor;
        return {data:(suyo || {}), error:null};
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
          if (!esta) todo.push(x);
        });
        return {data: todo, error:null};
      }
      var mios = TRAMITES[caso] || [];
      if (op && op.eq && op.eq.tipo){
        mios = mios.filter(function(t){ return t.tipo === op.eq.tipo; });
      }
      /* La franja pide solo devueltos y borradores. Sin filtrar, se le
         colaria un enviado y lo anunciaria como si te tocara a ti. */
      if (op && op.in && op.in.estado){
        mios = mios.filter(function(t){ return op.in.estado.indexOf(t.estado) >= 0; });
      }
      return {data:mios, error:null};
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
      if (op && op.eq && op.eq.tramite === 't4'){
        return {data:[{documento:'dr1', documentos:{tipo:'resolucion',
          nombre_original:'visa-tr1-estampada.pdf',
          archivo:'u1/emitidos/visa-tr1-estampada.pdf'}}], error:null};
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
        return {data:{}, error:null};
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
  function consulta(tabla){
    var api = {}, op = {};
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
    api.then  = function(bien, mal){ return Promise.resolve(respuesta(tabla, op)).then(bien, mal); };
    return api;
  }

  window.supabase = {
    createClient: function(){
      return {
        auth: {
          getSession: function(){ return Promise.resolve({data:{session:{user:USUARIO}}, error:null}); },
          getUser:    function(){ return Promise.resolve({data:{user:USUARIO}, error:null}); },
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
              /* Una imagen de verdad, de un pixel: con '#' el <img> falla
                 al cargar y el panel se cae a las iniciales -que es lo
                 correcto-, asi que la prueba de que la foto se ve no podia
                 pasar nunca. Y para lo que no existe, el mismo error que
                 da Storage. */
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

})();
