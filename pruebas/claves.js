/* ═══════════════════════════════════════════════════════════════════════
   LAS CLAVES DE TRADUCCIÓN, CUADRADAS
   ═══════════════════════════════════════════════════════════════════════
   Dos fallos que no rompen nada y por eso se quedan:

   1. Una clave DEFINIDA que no usa nadie. Sobrevive a la pantalla que la
      encargó, se traduce a seis idiomas cada vez que alguien repasa los
      textos, y confunde a quien la lee buscando dónde sale. Se acumularon
      trece del hero de una portada que ya no existe.

   2. Una clave USADA que no está definida. El panel pone cadena vacía y
      sigue: sale un botón sin texto, una etiqueta en blanco. Es peor que
      un error, porque no lo parece.

   Esto no corre en el navegador: lee los archivos. Las claves que se piden
   desde el código —dic['x'], u.clave— no se ven en el DOM.

       node pruebas/claves.js
   ═══════════════════════════════════════════════════════════════════════ */
'use strict';
const fs = require('node:fs');
const path = require('node:path');

const RAIZ = path.join(__dirname, '..');
const PANEL = fs.readFileSync(path.join(RAIZ, 'ciip-ventanilla-unica-local.html'), 'utf8');
const PASOS = fs.readFileSync(path.join(RAIZ, 'pasos.js'), 'utf8');

let pasan = 0, fallan = 0;
function ok(que, cierto, detalle) {
  if (cierto) { pasan++; console.log('  PASA  ' + que); return; }
  fallan++;
  console.log('  FALLA ' + que);
  if (detalle) console.log('          ' + detalle);
}

/* ── 1 · I18N, el diccionario de la interfaz ──────────────────────────── */
const I18N = JSON.parse(PANEL.match(/const I18N = (\{.*?\});\n/s)[1]);
const idiomas = Object.keys(I18N);
const claves = Object.keys(I18N.es);

/* Dónde se pide una clave: por atributo, o desde el código. Los prefijos
   sueltos —'rol.' + rol, 'faq.q' + i— se tratan aparte: son familias
   enteras que se piden en tiempo de ejecución. */
const usadas = new Set();
for (const m of PANEL.matchAll(/data-i18n(?:-ph|-title)?="([^"]+)"/g)) usadas.add(m[1]);
for (const m of PANEL.matchAll(/(?:dic|d|D)\[['"]([^'"]+)['"]\]/g)) usadas.add(m[1]);
for (const m of PANEL.matchAll(/I18N(?:\.[a-z]{2}|\[[^\]]+\])\[['"]([^'"]+)['"]\]/g)) usadas.add(m[1]);
const familias = ['rol.', 'faq.q', 'st.'];

const huerfanas = claves.filter(k =>
  !usadas.has(k) && !familias.some(f => k.startsWith(f)));
ok('i18n: ninguna clave definida se queda sin usar',
   huerfanas.length === 0,
   huerfanas.length ? huerfanas.length + ' sin usar: ' + huerfanas.join(', ') : '');

const pedidasNoDefinidas = [...usadas].filter(k => !(k in I18N.es));
ok('i18n: ninguna clave pedida se queda sin definir',
   pedidasNoDefinidas.length === 0,
   pedidasNoDefinidas.length ? pedidasNoDefinidas.join(', ') : '');

/* Y las seis lenguas con las mismas claves: si a una le falta, ese idioma
   enseña el inglés en medio de la frase y nadie se entera hasta que un
   italiano abre la pantalla. */
const desiguales = [];
for (const l of idiomas) {
  for (const k of claves) if (!(k in I18N[l])) desiguales.push(l + ' → ' + k);
  for (const k of Object.keys(I18N[l])) if (!(k in I18N.es)) desiguales.push(l + ' ← ' + k);
}
ok('i18n: los seis idiomas tienen las mismas claves',
   desiguales.length === 0,
   desiguales.slice(0, 8).join(', '));

/* ── 2 · CIIP_PASOS.ui, los textos de los trámites ────────────────────── */
/* Se lee ejecutándolo: es un archivo de datos, no hay que interpretarlo a
   mano. */
const ctx = { window: {} };
new Function('window', PASOS)(ctx.window);
const UI = ctx.window.CIIP_PASOS.ui;
const clavesUI = Object.keys(UI.es);

const desigualesUI = [];
for (const l of Object.keys(UI)) {
  for (const k of clavesUI) if (!(k in UI[l])) desigualesUI.push(l + ' → ' + k);
  for (const k of Object.keys(UI[l])) if (!(k in UI.es)) desigualesUI.push(l + ' ← ' + k);
}
ok('pasos: los seis idiomas tienen las mismas claves',
   desigualesUI.length === 0,
   desigualesUI.slice(0, 8).join(', '));

/* u.algo pedido en el panel y que no existe en pasos.js. Es el fallo que
   dejó los dos botones de Mi empresa sin una palabra dentro: se pidió
   u.f_guardar y la clave se llama pf_guardar. */
const pedidasUI = new Set();
for (const m of PANEL.matchAll(/\bu\.([a-z][a-z0-9_]{2,})\b/g)) pedidasUI.add(m[1]);
/* Solo se juzgan las que parecen de este diccionario: las demás son
   variables sueltas que se llaman igual. */
const prefijosUI = ['ac_', 'av_', 'ay_', 'ci_', 'co_', 'ct_', 'd_', 'dc_', 'em_',
                    'f_', 'mt_', 'ns_', 'pf_', 'se_', 'tr_'];
const fantasmas = [...pedidasUI].filter(k =>
  prefijosUI.some(p => k.startsWith(p)) && !(k in UI.es));
ok('pasos: ningún texto pedido se queda sin definir',
   fantasmas.length === 0,
   fantasmas.length ? fantasmas.join(', ') : '');

console.log('\n  ' + pasan + ' de ' + (pasan + fallan) + ' comprobaciones superadas');
console.log('  ' + claves.length + ' claves de interfaz y ' + clavesUI.length +
            ' de trámites, en ' + idiomas.length + ' idiomas.\n');
process.exit(fallan ? 1 : 0);
