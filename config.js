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
      SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZieGR3cnlwcGZjdHV3bG5qanFyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgyODY0MzcsImV4cCI6MjEwMzg2MjQzN30.3pu7IrjE5Lgu3J9csZUHyE_kY1DA-czgb5Z8G3_kfyw'
    },

    /* ---- el de pruebas: aquí se monta lo nuevo y se puede romper ---- */
    pruebas: {
      SUPABASE_URL:      'https://ifhdzxetixhrzqixcfbe.supabase.co',
      SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlmaGR6eGV0aXhocnpxaXhjZmJlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY5OTI3OTUsImV4cCI6MjEwMjU2ODc5NX0.7e3QDtDKAYGYgIF-ZfMZJk9OXEYEo0_hpgR1BG_iT4Y'
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

  /* Saber contra qué base estás es la diferencia entre "esto no funciona"
     y "estoy mirando la base equivocada". */
  if (window.console && console.info) {
    console.info('CIIP · base de datos: ' + entorno + ' → ' + elegido.SUPABASE_URL);
  }

})();
