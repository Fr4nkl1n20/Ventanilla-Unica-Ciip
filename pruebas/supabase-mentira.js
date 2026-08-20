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
    {codigo:'rif_empresa',  ref_panel:'c6', ente:'SENIAT', activo:true}
  ];

  /* El borrador se toca DESPUÉS que el devuelto a propósito: así se
     comprueba que la franja antepone la devolución y no coge sin más lo
     último que se movió. */
  var TRAMITES = {
    lleno: [
      {id:'t1', tipo:'rif_empresa',  estado:'devuelto',
       creado_en:'2026-07-02T10:00:00Z', actualizado_en:'2026-08-14T10:00:00Z'},
      {id:'t2', tipo:'constitucion', estado:'borrador',
       creado_en:'2026-08-01T10:00:00Z', actualizado_en:'2026-08-18T10:00:00Z'}
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
  var colaViva = (COLA[caso] || []).slice();

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
    {id:'u2', nombre_completo:'Marta Bianchi'},
    {id:'u3', nombre_completo:''}
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

  var USUARIO = {id:'u1', email:'f.reyes@ciip.com.ve',
                 user_metadata: (caso === 'sinnombre' ? {} : {nombre_completo:'Franklin Reyes', pais:'Italia'})};

  function respuesta(tabla, op){
    if (tabla === 'perfiles'){
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
    if (tabla === 'tipos_tramite')    return {data:TIPOS, error:null};
    if (tabla === 'tipos_documento')  return {data:[], error:null};
    if (tabla === 'bancos_aliados')   return {data:[], error:null};
    if (tabla === 'tramites')         return {data:(TRAMITES[caso] || []), error:null};
    if (tabla === 'tramite_eventos')  return {data:(EVENTOS[caso]  || []), error:null};
    return {data:[], error:null};
  }

  /* Una consulta encadenable. Cada método devuelve el mismo objeto, y el
     objeto es "esperable": basta con que tenga .then para que valga en un
     await o en una cadena de promesas. */
  function consulta(tabla){
    var api = {}, op = {};
    ['select','neq','is','order','limit','range','upsert','delete','maybeSingle']
      .forEach(function(m){ api[m] = function(){ return api; }; });
    /* Estos S\u00cd se miran: distinguen a qui\u00e9n va dirigida la consulta. */
    api.eq = function(k, v){ (op.eq = op.eq || {})[k] = v; return api; };
    api.in = function(k, v){ (op.in = op.in || {})[k] = v; return api; };
    api.single = function(){ op.single = true; return api; };
    /* Estos dos SÍ se miran: son los que cambian algo. */
    api.insert = function(fila){ op.insert = fila; return api; };
    api.update = function(campos){ op.update = campos; return api; };
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
