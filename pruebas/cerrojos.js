/* ═══════════════════════════════════════════════════════════════════════
   LOS CERROJOS QUE VIVEN EN ARCHIVOS COMPARTIDOS
   ═══════════════════════════════════════════════════════════════════════
   La revisión de seguridad del 25-09-2026 dejó varios arreglos dentro de
   archivos que todo el mundo toca: el panel, la página de acceso,
   vercel.json, .vercelignore. Ese mismo día se perdieron TRES veces, al
   subir encima una copia vieja de un archivo que no los tenía. Nada falló
   a la vista: el panel seguía funcionando, solo que otra vez abierto.

   Esto lee los archivos y comprueba que siguen ahí. Si algo falta, no se
   arregla a mano copiando de otro sitio: casi siempre es que se editó una
   copia vieja. Hay que traer la última (git pull) y rehacer encima el
   cambio propio.

       node pruebas/cerrojos.js

   Lo corre PROBAR-PANEL.bat antes que nada, y se para si algo falta.
   ═══════════════════════════════════════════════════════════════════════ */

'use strict';

const fs = require('node:fs');
const path = require('node:path');

const RAIZ = path.join(__dirname, '..');
const lee = (f) => fs.readFileSync(path.join(RAIZ, f), 'utf8');

let pasan = 0, fallan = 0;
function ok(que, cierto, arreglo) {
  if (cierto) { pasan++; console.log('  PASA  ' + que); return; }
  fallan++;
  console.log('  FALLA ' + que);
  if (arreglo) console.log('          ' + arreglo);
}

console.log('\n  LOS CERROJOS\n');

const panel  = lee('ciip-ventanilla-unica-local.html');
const acceso = lee('acceso.html');
const vercel = lee('vercel.json');
const ignora = lee('.vercelignore');

/* supabase-js con versión fija y huella: con «@2» el navegador ejecuta la
   última 2.x que se publique, con la sesión del admin. */
const LIBRERIA = /<script src="https:\/\/cdn\.jsdelivr\.net\/npm\/@supabase\/supabase-js@2\.\d+\.\d+\/dist\/umd\/supabase\.js"\s+integrity="sha384-[A-Za-z0-9+\/=]+"\s+crossorigin="anonymous"><\/script>/;
const SIN_VERSION = /supabase-js@2\/dist/;

for (const [nombre, texto] of [['el panel', panel], ['acceso.html', acceso]]) {
  ok(nombre + ': supabase-js con versión fija y huella (SRI)',
     LIBRERIA.test(texto) && !SIN_VERSION.test(texto),
     'Se subió una copia vieja: la etiqueta volvió a «supabase-js@2». Trae la última (git pull).');
}

/* El asistente firma cada respuesta y solo se cree las firmadas. Sin
   devolver la firma, pierde la memoria de la conversación. */
ok('el panel devuelve la firma de cada respuesta del asistente',
   /papel:'asistente', texto:d\.respuesta, firma:d\.firma/.test(panel),
   'Falta «firma:d.firma» en conversacion.push: se subió una copia vieja del panel.');

/* La clave nueva solo con el enlace del correo de recuperación. */
for (const [nombre, texto] of [['acceso.html', acceso]]) {
  ok(nombre + ': la clave nueva solo llega desde el correo',
     /var VIENE_DEL_CORREO = false;/.test(texto) &&
     /if \(!VIENE_DEL_CORREO\) return irA\('login'\);/.test(texto),
     'Falta VIENE_DEL_CORREO: cualquiera con una sesión abierta cambiaría la clave escribiendo #nueva.');
}
/* Una sola puerta desde el 25-09-2026. /login/ era una copia de acceso.html
   con su propio config.js, y los arreglos había que hacerlos dos veces. Ahora
   /, /login y /login/... redirigen a /acceso.html: si una redirección se va,
   un marcador viejo o el enlace de un correo ya enviado dan 404. */
(function(){
  let red = [];
  try { red = JSON.parse(vercel).redirects || []; } catch (e) {}
  const va = (desde) => red.some(r => r.source === desde && r.destination === '/acceso.html');
  ok('vercel.json lleva a /acceso.html desde /, /login y /login/...',
     va('/') && va('/login') && va('/login/:ruta*'),
     'Faltan redirecciones a /acceso.html en vercel.json: ' +
     ['/', '/login', '/login/:ruta*'].filter(d => !va(d)).join(', '));
  ok('y no queda una segunda página de acceso en login/',
     !fs.existsSync(path.join(RAIZ, 'login', 'index.html')),
     'Ha vuelto login/index.html: la puerta es acceso.html, y dos copias se separan.');
})();

/* La CSP del sitio. */
ok('vercel.json lleva la Content-Security-Policy',
   /"Content-Security-Policy"/.test(vercel) && /frame-ancestors 'none'/.test(vercel),
   'Se perdió la CSP de vercel.json.');

/* Lo que no se publica. */
ok('.vercelignore deja fuera todos los .sql', /^\*\.sql$/m.test(ignora),
   'Los .sql llevan escritas las políticas y los disparadores de la base.');
ok('.vercelignore deja fuera las maquetas', /^maquetas\/$/m.test(ignora));

console.log('\n  ' + pasan + ' de ' + (pasan + fallan) + ' cerrojos en su sitio\n');
process.exit(fallan ? 1 : 0);
