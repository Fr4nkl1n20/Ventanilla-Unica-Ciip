/* ══════════════════════════════════════════════════════════════════════
   ██  CONFIGURACIÓN DEL PROYECTO — EL ÚNICO ARCHIVO QUE HAY QUE TOCAR  ██
   ══════════════════════════════════════════════════════════════════════

   Lo leen los dos archivos del proyecto:
       · acceso.html                        (el inicio de sesión)
       · ciip-ventanilla-unica-local.html   (el panel)

   Antes las claves estaban repetidas en los dos, y bastaba con cambiar
   una y olvidar la otra para que el panel se quedara SIN PROTECCIÓN
   en silencio. Ahora solo existen aquí.

   ─────────────────────────────────────────────────────────────────────
   HAY DOS BASES DE DATOS
   ─────────────────────────────────────────────────────────────────────
   Una real, con las cuentas de verdad, y una de pruebas donde se montan
   las cosas nuevas antes de tocar la real.

   Cuál se usa NO se decide con un interruptor que haya que acordarse de
   mover: se decide por dónde se abre la página.

       localhost o file://  →  pruebas
       cualquier otro sitio →  real

   Así no se sube a producción una configuración de pruebas por olvido,
   ni se trabaja en local contra la base real por descuido. Los dos
   errores son fáciles de cometer y caros de descubrir.

   Para saber contra cuál estás, abre la consola del navegador: la página
   lo dice al cargar.

   ─────────────────────────────────────────────────────────────────────
   DE DÓNDE SALEN LOS DOS VALORES DE CADA PROYECTO
   ─────────────────────────────────────────────────────────────────────
   Panel de Supabase → Project Settings → API
       · Project URL        →  SUPABASE_URL
       · anon / public key  →  SUPABASE_ANON_KEY

   La clave "anon" es PÚBLICA y puede ir en el navegador: por sí sola no
   da acceso a los datos. Lo que de verdad protege son las políticas RLS
   que crean supabase-setup.sql y supabase-tramites.sql.

   NUNCA pongas aquí la clave "service_role": esa sí lo abre todo.
   ══════════════════════════════════════════════════════════════════════ */

(function () {

  var PROYECTOS = {

    /* ---- el de verdad: cuentas reales, no es sitio para experimentos ----
       Proyecto "Ventanilla Unica - Produccion" (fbxdwryppfctuwlnjjqr),
       creado el 1 de septiembre de 2026 en el organization CIIP de
       Supabase, con las 21 tablas de TODO-EN-ORDEN.sql ya puestas.
       Reemplaza al ugmpeldbasujuchdmzsc que dejo de existir. */
    real: {
      SUPABASE_URL:      'https://fbxdwryppfctuwlnjjqr.supabase.co',
      SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZieGR3cnlwcGZjdHV3bG5qanFyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyODY0MzcsImV4cCI6MjEwMzg2MjQzN30.3pu7IrjE5Lgu3J9csZUHyE_kY1DA-czgb5Z8G3_kfyw',
      /* El de Vercel, al lado del asistente. Tener la direccion puesta NO
         lo enciende: el panel le pregunta primero y, mientras en Vercel
         falten la clave o LECTOR_ACTIVO, contesta que no y no se pinta
         nada. Ver api/LEEME.md. */
      LECTOR_URL:        '/api/leer-documento'
    },

    /* ---- el de pruebas: aquí se monta lo nuevo y se puede romper ---- */
    pruebas: {
      SUPABASE_URL:      'https://ifhdzxetixhrzqixcfbe.supabase.co',
      SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlmaGR6eGV0aXhocnpxaXhjZmJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY5OTI3OTUsImV4cCI6MjEwMjU2ODc5NX0.7e3QDtDKAYGYgIF-ZfMZJk9OXEYEo0_hpgR1BG_iT4Y',
      LECTOR_URL:        ''
    }

  };

  /* Las direcciones de la oficina (10.x, 172.16-31.x, 192.168.x) y los nombres
     de maquina sin punto cuentan tambien como local: cuando un companero abre
     http://172.21.20.49:8080 esta mirando el servidor de pruebas del PC de al
     lado, no un sitio publicado.

     Sin esto pasaba algo que costo un rato entender: el que servia la pagina
     trabajaba contra 'pruebas' —entra por localhost— y el que la miraba desde
     otro PC caia en 'real'. Misma pantalla, bases distintas, y ninguno de los
     dos veia lo que veia el otro. */
  var RED_PRIVADA = /^(10\.|127\.|169\.254\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/;

  var enLocal = location.protocol === 'file:' ||
                ['localhost', '127.0.0.1', '::1', ''].indexOf(location.hostname) >= 0 ||
                RED_PRIVADA.test(location.hostname) ||
                location.hostname.indexOf('.') === -1;

  var entorno = enLocal ? 'pruebas' : 'real';
  var elegido = PROYECTOS[entorno];

  window.CIIP_CONFIG = {

    SUPABASE_URL:      elegido.SUPABASE_URL,
    SUPABASE_ANON_KEY: elegido.SUPABASE_ANON_KEY,

    /* ---- rutas entre páginas: solo si renombras los archivos ---- */
    RUTA_PANEL:  './ciip-ventanilla-unica-local.html',
    RUTA_ACCESO: './acceso.html',

    /* por si alguna pantalla quiere avisar de que no es la base real */
    ENTORNO: entorno
  };

  /* ═══════════════════════════════════════════════════════════════════
     EL LECTOR DE DOCUMENTOS
     ═══════════════════════════════════════════════════════════════════
     Lo que hace: recibe un papel -el acta constitutiva, el pasaporte, el
     poder- y devuelve lo que ese papel dice, para que el panel proponga
     las casillas ya rellenas y la persona las repase.

     HAY DOS MANERAS DE ENCHUFARLO, y la direccion dice cual:

     · Empieza por «/»  →  el de Vercel, api/leer-documento.js, en el mismo
       sitio que el panel. El papel NO viaja en la peticion -Vercel corta
       a 4,5 MB y un poder escaneado pasa de eso-: se sube un momento a
       tu carpeta del cubo, {uid}/lector/, y alli va solo la ruta. El
       servidor lo lee con tu sesion y lo borra al terminar.

       Y antes de pintar nada, el panel le pregunta si esta encendido
       (CIIP_LECTOR.listo). Asi la direccion puede estar puesta en el
       proyecto real sin que aparezca un cuadro que no lee: mientras en
       Vercel falten la clave o LECTOR_ACTIVO=si, contesta que no.

     · Cualquier otra  →  un lector que recibe el archivo entero en un
       formulario: la funcion de Supabase o pruebas/lector-local.js.

     Vacia, no hay lector y el cuadro de «suelta el papel» no se pinta.

     LO QUE HAY QUE DECIDIR ANTES DE ENCENDERLO

     No es una decision tecnica. Un acta constitutiva lleva nombres,
     cedulas, capital y domicilios; un poder lleva el numero de la
     notaria y la identidad del apoderado. Encender el lector es decidir
     que esos documentos SALEN hacia Anthropic para leerse, y eso lo
     tiene que decir el CIIP. Por eso en Vercel es un interruptor aparte
     de la clave del asistente.

     EL TRATO, POR SI SE ESCRIBE OTRO LECTOR

     Se le llama:   CIIP_LECTOR(archivo, {acta_constitutiva: ['razon_social',
                                                             'capital_social'],
                                          domicilio_empresa: ['direccion_fiscal']})

                    El segundo es el mapa de ESE tramite: que papeles acepta
                    y, en cada uno, que casillas hay que buscar. Va entero y
                    no solo la lista de papeles porque el que lee necesita
                    los dos datos; copiar la tabla al otro lado seria tener
                    dos que mantener, y un dia dirian cosas distintas.

     Devuelve una promesa con:
                    {doc: 'acta_constitutiva',
                     campos: {razon_social: '...', capital_social: '...'}}

     Los nombres de 'campos' son los de CAMPOS del panel. Lo que no
     sepa leer, que no lo mande: una casilla vacia se teclea, y una
     casilla mal puesta viaja al organismo.

     Si no reconoce el documento, o falla, el panel lo dice y sigue: se
     sube el papel a mano y no pasa nada mas.
     ═══════════════════════════════════════════════════════════════════ */
  function lectorDelSitio(url){
    var listoPide = null;

    function lector(archivo, quePapeles){
      /* El guardian del <head> del panel deja aqui el cliente de Supabase.
         Cuando se llama al lector ya hay sesion: el cuadro solo existe
         dentro de un tramite abierto. */
      var sb = window.sbCIIP;
      if (!sb) return Promise.reject(new Error('sin cliente de Supabase'));
      var ruta = null, token = null;

      return sb.auth.getSession().then(function(r){
        var s = r && r.data && r.data.session;
        if (!s || !s.access_token || !s.user || !s.user.id) throw new Error('sin sesion');
        token = s.access_token;
        /* {uid}/lector/: la primera carpeta es la del dueño, que es lo que
           miran las politicas del cubo, y la segunda es la unica de la que
           el servidor acepta borrar. */
        var limpio = String(archivo && archivo.name || 'papel').replace(/[^\w.\-]+/g, '_').slice(-60);
        ruta = s.user.id + '/lector/' + Math.random().toString(36).slice(2, 10) + '-' + limpio;
        return sb.storage.from('recaudos').upload(ruta, archivo, {upsert: false});
      }).then(function(subido){
        if (subido && subido.error){ ruta = null; throw subido.error; }
        return fetch(url, {
          method: 'POST',
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ' + token},
          body: JSON.stringify({ruta: ruta, casillas: quePapeles || {}})
        });
      }).then(function(resp){
        if (!resp.ok) throw new Error('el lector contesto ' + resp.status);
        return resp.json();
      }).catch(function(e){
        /* El servidor borra el papel en cuanto sabe que es suyo. Si no
           llego a contestar -sin red, o se corto-, nadie lo ha borrado:
           se intenta desde aqui. Si ya no esta, no pasa nada. */
        if (ruta){
          try { sb.storage.from('recaudos').remove([ruta]).catch(function(){}); } catch (x){}
        }
        throw e;
      });
    }

    /* Una vez por pagina. Un fallo de red cuenta como «no»: mejor sin
       cuadro que con uno que no contesta. */
    lector.listo = function(){
      if (!listoPide){
        listoPide = fetch(url, {method: 'GET'})
          .then(function(r){ return r.ok ? r.json() : {}; })
          .then(function(d){ return !!(d && d.listo === true); })
          .catch(function(){ return false; });
      }
      return listoPide;
    };

    return lector;
  }

  if (elegido.LECTOR_URL && elegido.LECTOR_URL.charAt(0) === '/'){
    window.CIIP_LECTOR = lectorDelSitio(elegido.LECTOR_URL);
  } else if (elegido.LECTOR_URL){
    window.CIIP_LECTOR = function(archivo, quePapeles){
      var sobre = new FormData();
      sobre.append('archivo', archivo);
      sobre.append('casillas', JSON.stringify(quePapeles || {}));
      return fetch(elegido.LECTOR_URL, {method: 'POST', body: sobre})
        .then(function(r){
          if (!r.ok) throw new Error('el lector contesto ' + r.status);
          return r.json();
        });
    };
  }

  /* Saber contra qué base estás es la diferencia entre "esto no funciona"
     y "estoy mirando la base equivocada". */
  if (window.console && console.info) {
    console.info('CIIP · base de datos: ' + entorno + ' → ' + elegido.SUPABASE_URL);
  }

})();
