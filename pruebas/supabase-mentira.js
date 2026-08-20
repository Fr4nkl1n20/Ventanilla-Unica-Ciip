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

  /* El catálogo, con los tres tipos que usan las pruebas. ref_panel es lo
     que ata cada tipo a su tarjeta del panel (data-tr). */
  var TIPOS = [
    {codigo:'rif_personal', ref_panel:'c3', ente:'SENIAT', activo:true},
    {codigo:'constitucion', ref_panel:'c5', ente:'SAREN',  activo:true},
    {codigo:'rif_empresa',  ref_panel:'c6', ente:'SENIAT', activo:true},
    {codigo:'rnc',          ref_panel:'c13', ente:'RNC',   activo:true},
    {codigo:'solvencias',   ref_panel:'c14', ente:'Entes varios', activo:true},
    /* La visa, que es la del tramite ya resuelto. Sin su tipo aqui, el
       panel no sabe a que tarjeta pertenece y la deja en "por iniciar"
       aunque el tramite este resuelto. */
    {codigo:'visa_inversionista', ref_panel:'c1', ente:'SAIME', activo:true}
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
      {id:'t4', tipo:'visa_inversionista', estado:'resuelto',
       creado_en:'2026-06-01T10:00:00Z', enviado_en:'2026-06-02T10:00:00Z',
       resuelto_en:'2026-06-18T10:00:00Z', actualizado_en:'2026-06-18T10:00:00Z'}
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
    sinnombre: [],
    gestor: []
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

  var colaViva = (COLA[caso] || []).slice();

  /* Los tramites que esperan por el CIIP. Uno recien enviado y otro que ya
     alguien empezo a mirar: los pasos que se ofrecen no son los mismos. */
  var COLA_TRAM = {
    gestor: [
      {id:'x1', inversionista:'u2', tipo:'rif_empresa', estado:'enviado',
       datos:{razon_social:'Bianchi Agroindustrias, C.A.', rif_empresa:'J-40123456-7',
              actividad_economica:'Procesamiento de cacao'},
       creado_en:'2026-08-05T09:00:00Z', enviado_en:'2026-08-05T09:00:00Z'},
      {id:'x2', inversionista:'u3', tipo:'constitucion', estado:'en_revision',
       creado_en:'2026-08-07T09:00:00Z', enviado_en:'2026-08-07T09:00:00Z'}
    ],
    lleno: [], vacio: [], sinnombre: []
  };
  var colaTram = (COLA_TRAM[caso] || []).slice();

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
  var OTROS_PERFILES = [
    {id:'u1', nombre_completo:'Franklin Reyes',  pais:'Italia',    rol:'gestor'},
    {id:'u2', nombre_completo:'Marta Bianchi',   pais:'Italia',    rol:'inversionista'},
    /* Sin nombre a proposito: la lista tiene que decirlo en vez de dejar
       el hueco, igual que la cola. */
    {id:'u3', nombre_completo:'',                pais:'',          rol:'inversionista'},
    {id:'u4', nombre_completo:'Saskia Calderon', pais:'Venezuela', rol:'gestor',
     rol_cambiado_en:'2026-08-11T10:00:00Z'}
  ];

  /* El expediente personal. En 'sinnombre' viene con la cadena vacía, que es
     como llega de verdad una cuenta creada a mano en Supabase. */
  var PERFILES = {
    gestor:    {nombre_completo:'Franklin Reyes', pais:'Italia', rol:'gestor'},
    lleno:     {nombre_completo:'Franklin Reyes', pais:'Italia', rol:'inversionista'},
    vacio:     {nombre_completo:'Franklin Reyes', pais:'Italia', rol:'inversionista'},
    sinnombre: {nombre_completo:'',               pais:'',       rol:'inversionista'}
  };

  /* De más nuevo a más viejo, que es como los pide el panel. Los dos
     'borrador' están para comprobar que el buzón NO los anuncia: la
     solicitud se crea y se envía en el mismo gesto. */
  var EVENTOS = {
    gestor: [],
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

  var USUARIO = {id:'u1', email:'f.reyes@ciip.com.ve',
                 user_metadata: (caso === 'sinnombre' ? {} : {nombre_completo:'Franklin Reyes', pais:'Italia'})};

  function respuesta(tabla, op){
    if (tabla === 'perfiles'){
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
      return op && op.single
        ? {data:(PERFILES[caso] || PERFILES.lleno), error:null}
        : {data:OTROS_PERFILES, error:null};
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
      return {data:citasVivas.concat(CONFIRMADAS[caso] || []), error:null};
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
    if (tabla === 'tipos_tramite')    return {data:TIPOS, error:null};
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
      return {data:[
        {id:'doc1', tipo:'cedula', archivo:'u1/pasaporte.pdf',
         nombre_original:'pasaporte.pdf', vence_el:null, estado:'cargado',
         nota_revision:'', creado_en:'2026-07-02T10:00:00Z'},
        {id:'doc2', tipo:'antecedentes', archivo:'u1/antecedentes.pdf',
         nombre_original:'antecedentes-apostillados.pdf', vence_el:fechaEn(-9),
         estado:'cargado', nota_revision:'', creado_en:'2026-05-20T10:00:00Z'},
        {id:'doc3', tipo:'acta_constitutiva', archivo:'u1/acta.pdf',
         nombre_original:'acta-constitutiva.pdf', vence_el:fechaEn(12),
         estado:'cargado', nota_revision:'', creado_en:'2026-08-01T10:00:00Z'}
      ], error:null};
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
    if (tabla === 'tipos_documento')  return {data:[], error:null};
    if (tabla === 'bancos_aliados')   return {data:[], error:null};
    if (tabla === 'tramites'){
      /* Dos colas distintas sobre la misma tabla: la del equipo pide lo que
         espera por el CIIP, y la franja del inversionista lo que espera por
         el. Confundirlas seria enseñarle a cada uno lo del otro. */
      if (op && op.in && op.in.estado && op.in.estado.indexOf('enviado') >= 0){
        return {data:colaTram, error:null};
      }
      if (op && op.update && op.eq && op.eq.id){
        colaTram = colaTram.filter(function(t){ return t.id !== op.eq.id; });
        return {data:{}, error:null};
      }
      /* El detalle de un tramite pregunta por SU tipo. Sin filtrar aqui, el
         panel creeria que ya tienes una solicitud de cualquier tramite que
         abras, y enseñaria su estado en vez del formulario. */
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
      return {data:evs, error:null};
    }
    return {data:[], error:null};
  }

  /* Una consulta encadenable. Cada método devuelve el mismo objeto, y el
     objeto es "esperable": basta con que tenga .then para que valga en un
     await o en una cadena de promesas. */
  function consulta(tabla){
    var api = {}, op = {};
    ['select','neq','is','order','limit','range']
      .forEach(function(m){ api[m] = function(){ return api; }; });
    /* Estos S\u00cd se miran: distinguen a qui\u00e9n va dirigida la consulta. */
    api.eq = function(k, v){ (op.eq = op.eq || {})[k] = v; return api; };
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
    api.then  = function(bien, mal){ return Promise.resolve(respuesta(tabla, op)).then(bien, mal); };
    api.catch = function(mal){ return Promise.resolve(respuesta(tabla, op)).catch(mal); };
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
        storage: {
          from: function(){
            return {
              upload:        function(){ return Promise.resolve({data:{path:'x'}, error:null}); },
              createSignedUrl: function(){ return Promise.resolve({data:{signedUrl:'#'}, error:null}); }
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
