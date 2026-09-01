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
/* 'u' es el accesor de siempre —var u = T()— y faltaba en esta lista. Una
   clave leída como u['algo.con.punto'] no la veía nadie y salía como
   «definida y sin usar». No se había notado porque las pocas que se leen
   así llevaban detrás un dic['...'] de reserva, que sí se detecta; al
   añadir ocho de golpe sin esa reserva, saltaron las ocho. */
for (const m of PANEL.matchAll(/(?:dic|d|D|u)\[['"]([^'"]+)['"]\]/g)) usadas.add(m[1]);
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

/* Los sectores viven fuera de 'ui' -son un catalogo, no textos de
   pantalla- asi que las comprobaciones de arriba no los alcanzan. Si a un
   idioma le falta uno, ese sector se enseña en español en medio de una
   pantalla en ruso y nadie se entera. */
const SEC = ctx.window.CIIP_PASOS.sectores || {};
const refsSec = Object.keys(SEC.es || {});
const secMal = [];
for (const l of Object.keys(SEC)) {
  for (const k of refsSec) if (!(k in SEC[l])) secMal.push(l + ' → ' + k);
  for (const k of Object.keys(SEC[l])) if (!refsSec.includes(k)) secMal.push(l + ' ← ' + k);
}
ok('sectores: los seis idiomas tienen los mismos',
   refsSec.length > 0 && Object.keys(SEC).length === idiomas.length && secMal.length === 0,
   secMal.length ? secMal.slice(0, 6).join(', ')
                 : (refsSec.length + ' sectores en ' + Object.keys(SEC).length + ' idiomas'));

/* u.algo pedido en el panel y que no existe en pasos.js. Es el fallo que
   dejó los dos botones de Mi empresa sin una palabra dentro: se pidió
   u.f_guardar y la clave se llama pf_guardar. */
const pedidasUI = new Set();
for (const m of PANEL.matchAll(/\bu\.([a-z][a-z0-9_]{2,})\b/g)) pedidasUI.add(m[1]);
/* Solo se juzgan las que parecen de este diccionario: las demás son
   variables sueltas que se llaman igual. */
const prefijosUI = ['ac_', 'av_', 'ay_', 'ci_', 'co_', 'ct_', 'd_', 'dc_', 'em_',
                    'f_', 'ft_', 'mt_', 'ns_', 'pf_', 'se_', 'tr_'];
const fantasmas = [...pedidasUI].filter(k =>
  prefijosUI.some(p => k.startsWith(p)) && !(k in UI.es));
ok('pasos: ningún texto pedido se queda sin definir',
   fantasmas.length === 0,
   fantasmas.length ? fantasmas.join(', ') : '');

/* ── 2b · NINGUNA CLAVE ESCRITA DOS VECES ───────────────────────
   Esto no lo ve ninguna de las de arriba, y por eso hay que mirarlo
   aparte: en un objeto de JavaScript, dos claves con el mismo nombre no
   son un error —gana la ÚLTIMA—, así que al parsearlo la duplicada
   desaparece sin dejar rastro y todo cuadra.

   Paso de verdad: al añadir el aviso de «guardado» lo llamé dc_subido,
   que ya existía con «Subido el {fecha}». La fecha de subida de cada
   documento se quedó diciendo «guardado», las 2594 pruebas siguieron en
   verde y no se veía hasta abrir la bóveda a mirar. Se lee el ARCHIVO, no
   el objeto. */
function repetidas(texto, donde) {
  const malas = [];
  /* Cada bloque de idioma por su cuenta: la misma clave en es y en en no
     es una repetición, es lo normal. Se parte por los cierres de bloque
     de idioma, que van a dos niveles de sangrado. */
  /* Sin barras invertidas en la expresion: este archivo se genera
     desde otro sitio y una barra de menos convierte la regla en un
     error de sintaxis que tumba el comprobador entero. */
  const CIERRE = String.fromCharCode(10) + '    }';
  for (const bloque of texto.split(CIERRE)) {
    const vistas = new Map();
    for (const m of bloque.matchAll(/^ {6}([a-z][a-z0-9_.]*): /gm)) {
      vistas.set(m[1], (vistas.get(m[1]) || 0) + 1);
    }
    for (const [k, n] of vistas) if (n > 1) malas.push(`${donde} ${k} ×${n}`);
  }
  return [...new Set(malas)];
}
const dobles = repetidas(PASOS, 'pasos');
ok('claves: ninguna escrita dos veces en el mismo idioma',
   dobles.length === 0, dobles.slice(0, 10).join(', '));

/* ── 2c · NINGUNA FUNCION DECLARADA DOS VECES ──────────────────
   Lo mismo que las claves repetidas, y por el mismo motivo: en JavaScript
   dos "function X" en el mismo ambito no son un error, gana la SEGUNDA. La
   primera desaparece sin dejar rastro y las llamadas que iban a ella van a
   la otra.

   Paso de verdad: la ficha del tramite se llamo pintaFicha, y ya habia una
   pintaFicha -la de la boveda- doscientas lineas mas abajo. La ficha no se
   dibujaba, la consola no decia nada y las pruebas hablaban de campos que
   faltaban en un formulario. Una hora.

   Se mira por IIFE: el archivo tiene trece bloques de primer nivel y el
   mismo nombre en dos bloques distintos es correcto -hay dos 'pinta', una
   del router y otra de las etapas-. */
function funcionesRepetidas(texto) {
  const malas = [];
  /* Los bloques de primer nivel empiezan por '(function(){' pegado al
     margen. Partir por ahi no es un parser, pero distingue lo que hay que
     distinguir: dos ambitos distintos de dos declaraciones en el mismo. */
  const bloques = texto.split(String.fromCharCode(10) + '(function(){');
  for (const bloque of bloques) {
    const vistas = new Map();
    for (const m of bloque.matchAll(/^  function ([A-Za-z_$][\w$]*)\s*\(/gm)) {
      vistas.set(m[1], (vistas.get(m[1]) || 0) + 1);
    }
    for (const [k, n] of vistas) if (n > 1) malas.push(`${k} ×${n}`);
  }
  return [...new Set(malas)];
}
const dosVeces = funcionesRepetidas(PANEL);
ok('panel: ninguna funcion declarada dos veces en el mismo bloque',
   dosVeces.length === 0, dosVeces.join(', '));

/* ── 3 · CÓMO SE ESCRIBE ──────────────────────────────────────────────
   Ni el navegador ni las pruebas del panel miran esto: un rótulo con una
   mayúscula de más se ve igual de bien y nadie lo nota hasta que hay
   veinte y la pantalla parece de tres manos distintas.

   Se mira SOLO lo corto —rótulos, botones, chips—. En una frase larga,
   dos palabras con inicial mayúscula casi siempre son un nombre propio
   («Ministerio del Trabajo») y marcarlas daba treinta avisos sin uno solo
   de verdad. */
const LATINAS = ['es', 'en', 'pt', 'it'];

/* Lo que SÍ va con mayúscula en mitad de un rótulo: siglas, entes,
   países y los nombres propios de los registros. Un registro se llama
   como se llama; «Registro Nacional de Contratistas» no es Title Case
   mal puesto, es su nombre. */
const PROPIOS = new Set((
  'CIIP SENIAT SAREN SAIME RNC RNET SNC IVSS INCES SUNAGRO BCV FAOV RIF ' +
  'IGTF ISLR IVA SQL Venezuela Caracas Italia Portugal China Rusia Nigeria ' +
  'Colombia Estado Registro Registo Nacional Nazionale National Mercantil ' +
  'Entidades Entità Entities Trabajo Trabalho Lavoro Work Contratistas ' +
  'Contratados Contractors Appaltatori Registry Register Único Única Unico ' +
  'Productiva Internacional Inversión Centro Ventanilla Inversionista ' +
  /* El nombre de la casa en los cuatro idiomas latinos. «Balcão Único do
     Investidor» se llama así igual que «Ventanilla Única del
     Inversionista»: faltaba solo el portugués, y no se notó mientras el
     rótulo llevaba detrás «· Demonstração de conceito», porque con eso
     pasaba de cinco palabras y la regla ni lo miraba. */
  'Balcão Investidor ' +
  'Investitore Sportello Investor One Stop Window Concept Demo Ministerio ' +
  /* Y las formas societarias: «Compañía Anónima», «Sociedad de
     Responsabilidad Limitada» son figuras jurídicas con nombre propio, no
     un rótulo escrito con mayúsculas de adorno. */
  'Anónima Anonima Responsabilidad Limitada Ltda Company Limited ' +
  /* Y los registros de cada país, que también se llaman como se llaman:
     el Registo Comercial portugués, el Registro delle Imprese italiano.
     «Paese» va con mayúscula en italiano cuando quiere decir el país
     como nación, que es lo que dice ahí. */
  'Comercial Imprese Quotas Paese'
).split(' '));

/* Dos que se salen de la regla a propósito, y por qué:
     tag.soon   se pinta con text-transform:uppercase. En minúscula en el
                diccionario es lo correcto: la presentación la decide el
                CSS, no el texto.
     asst.greet lleva dos espacios detrás del emoji, y la burbuja usa
                white-space:pre-wrap, así que ese aire se ve. Está igual
                en los seis idiomas: es una decisión, no un descuido. */
const SALTOS = new Set([
  'tag.soon', 'asst.greet',
  /* Y estos tres no son rótulos: son TROZOS que se pegan detrás de otra
     cosa —«pasaporte.pdf · ya estaba en tu expediente», «resuelta el 4 de
     agosto»—. Empezar en minúscula ahí no es un descuido, es lo correcto:
     van en mitad de una frase. */
  'reutilizado', 'mt_resuelta', 'ay_ente',
  /* Y los cuatro estados de una cita, que se meten DENTRO de otra frase:
     la bitacora escribe «Cita confirmada», no «confirmada» a secas. En
     mayuscula quedaria «Cita Confirmada», que es peor que el aviso. */
  'ra_e_solicitada', 'ra_e_confirmada', 'ra_e_hecha', 'ra_e_cancelada',
  /* Y las dos unidades del formulario del acompañamiento, que van DETRAS
     de una casilla de numero: «Tarda en asomar [ 3 ] segundos». En
     mayuscula quedaria «3 Segundos». */
  'sop_seg', 'sop_min',
  /* Y estos dos, que se pegan detras del nombre de un recaudo: «Pasaporte
     · lo emite el consulado · ya esta en tu boveda». */
  'ft_tuyo', 'ft_emite',
  /* Y la coletilla que va debajo del numero en ambar: «95 dias / en la
     practica / por encima del plazo legal». Es el final de esa frase, no un
     rotulo suyo. */
  'ft_tarde',
  /* Y la pareja del visto: van en el 'title' del signo de cada recaudo
     —«ya esta en tu boveda» / «todavia no lo tienes»—, que es una frase
     dicha del papel, no el rotulo de una columna. */
  'ft_falta',
  /* Y este, que se pega detras del nombre del tipo en el desplegable de
     subir: «Pasaporte · ya lo tienes». */
  'dc_yatienes'
]);

const EMOJI = /[\u{1F300}-\u{1FAFF}\u2600-\u27BF]\s*/gu;

function comoSeEscribe(donde, dic) {
  const malos = [];
  for (const lang of Object.keys(dic)) {
    for (const [k, valor] of Object.entries(dic[lang])) {
      if (SALTOS.has(k)) continue;
      /* Hay claves que son LISTAS —las opciones de un desplegable—. Cada
         opción es un rótulo por su cuenta y se mira igual; juntarlas en
         una cadena convertía «Corriente» y «Ahorro» en un solo rótulo con
         una mayúscula en medio que no existe. */
      for (const trozo of (Array.isArray(valor) ? valor : [valor])) {
      const v = String(trozo == null ? '' : trozo).trim();
      if (!v) continue;
      const palabras = v.split(/\s+/);
      const corto = palabras.length <= 5;
      const di = (q) => malos.push(`${donde} ${lang} ${k}: ${q} — "${v.slice(0, 46)}"`);

      if ((LATINAS.includes(lang) || lang === 'ru') &&
          /^\p{Ll}/u.test(v)) di('empieza en minúscula');

      if (LATINAS.includes(lang) && corto && !v.endsWith('.')) {
        /* La barra separa DOS rótulos —«Celibe/Nubile», «Soltero/a»—,
           así que lo de después empieza otra vez y puede ir en mayúscula. */
        const sueltas = v.split('/').flatMap(trozo =>
            (trozo.match(/[A-Za-z\u00C0-\u024F]+/g) || []).slice(1))
          .filter(w => /^\p{Lu}/u.test(w) && w !== w.toUpperCase() && !PROPIOS.has(w));
        if (sueltas.length) di('mayúscula en mitad del rótulo: ' + sueltas.join(' '));
      }

      /* Los puntos suspensivos son UN carácter, «…», y así están las 69
         veces que salen en el archivo. Escribirlos con tres puntos se ve
         casi igual, ocupa más y no parte de línea igual; y donde de
         verdad se nota es al lado de otro que sí es «…». Aquí lo que se
         mide es que no haya dos maneras de escribir lo mismo. */
      if (/\.\.\.$/.test(v)) di('tres puntos en vez de «…»');

      if (lang === 'es' && v.includes('?') && !v.includes('¿')) di('? sin abrir');
      if (lang === 'es' && v.includes('!') && !v.includes('¡')) di('! sin abrir');

      if (LATINAS.includes(lang) && /\s[,.;:!?]/.test(v)) di('espacio antes del signo');
      if (v.replace(EMOJI, '').includes('  ')) di('espacio doble');
      }
    }
  }
  return malos;
}

const escritura = comoSeEscribe('i18n', I18N).concat(comoSeEscribe('pasos', UI));
ok('escritura: los rótulos siguen la misma norma en los seis idiomas',
   escritura.length === 0,
   escritura.slice(0, 10).join('\n          '));

/* Y el punto final, o en todos o en ninguno. Media frase con punto y la
   misma sin él, según el idioma, es lo que hace que una pantalla parezca
   traducida por turnos. */
/* Una abreviatura lleva punto y eso no es el punto de una frase: «{n}
   дн.» en ruso es lo correcto, y «дн» sin punto estaria mal escrito. Es la
   unica de todo el archivo, asi que se nombra en vez de inventar una regla
   que adivine abreviaturas. */
const PUNTO_OK = new Set(['ft_dias']);

function puntoDesigual(donde, dic) {
  const idiomas = Object.keys(dic);
  const claves = new Set();
  for (const l of idiomas) for (const k of Object.keys(dic[l])) claves.add(k);
  const malos = [];
  for (const k of claves) {
    if (PUNTO_OK.has(k)) continue;
    const vals = idiomas
      .filter(l => typeof dic[l][k] === 'string' && dic[l][k].trim())
      .map(l => [l, dic[l][k].trim()]);
    if (vals.length < 2) continue;
    const con = vals.filter(([, v]) => /[.。]$/.test(v)).map(([l]) => l);
    const sin = vals.filter(([, v]) => !/[.。]$/.test(v)).map(([l]) => l);
    if (con.length && sin.length) malos.push(`${donde} ${k}: con punto ${con} y sin punto ${sin}`);
  }
  return malos;
}
const puntos = puntoDesigual('i18n', I18N).concat(puntoDesigual('pasos', UI));
ok('escritura: el punto final, o en todos los idiomas o en ninguno',
   puntos.length === 0,
   puntos.slice(0, 8).join('\n          '));

console.log('\n  ' + pasan + ' de ' + (pasan + fallan) + ' comprobaciones superadas');
console.log('  ' + claves.length + ' claves de interfaz y ' + clavesUI.length +
            ' de trámites, en ' + idiomas.length + ' idiomas.\n');
process.exit(fallan ? 1 : 0);
