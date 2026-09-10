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
/* AVISO PARA EL QUE ESCRIBA UN COMENTARIO EN EL PANEL.
   Esto busca por el texto en crudo: no distingue codigo de comentario. Un
   ejemplo escrito dentro de un comentario —dic, corchete, comilla, nombre—
   cuenta como si alguien pidiera esa clave de verdad, y la comprobacion de
   «ninguna clave pedida se queda sin definir» se pone roja pidiendo una que
   no existe. Paso con un comentario que explicaba precisamente como se
   piden las claves. Si hay que poner un ejemplo, se dice con palabras. */
const usadas = new Set();
for (const m of PANEL.matchAll(/data-i18n(?:-ph|-title)?="([^"]+)"/g)) usadas.add(m[1]);
/* 'u' es el accesor de siempre —var u = T()— y faltaba en esta lista. Una
   clave leída como u['algo.con.punto'] no la veía nadie y salía como
   «definida y sin usar». No se había notado porque las pocas que se leen
   así llevaban detrás un dic['...'] de reserva, que sí se detecta; al
   añadir ocho de golpe sin esa reserva, saltaron las ocho. */
for (const m of PANEL.matchAll(/(?:dic|d|D|u)\[['"]([^'"]+)['"]\]/g)) usadas.add(m[1]);
for (const m of PANEL.matchAll(/I18N(?:\.[a-z]{2}|\[[^\]]+\])\[['"]([^'"]+)['"]\]/g)) usadas.add(m[1]);
/* Y AQUI NO HAY UNA TERCERA LINEA, a proposito.
   La hubo durante una tarde. Alguien escribio un ayudante nuevo —function
   t(k){ return dic[k] || I18N.en[k]; }— y pidio con el cuatro claves. Esta
   lista no lo conocia, asi que las cuatro salieron como «definidas y sin
   usar» estandolo, y el que las habia escrito tuvo que oir que su trabajo
   rompia una prueba que no rompia nada.

   El arreglo evidente era añadir 't' aqui. Es el que se hizo primero, y es
   el equivocado: esta lista no sabe leer JavaScript, solo sabe los accesores
   que alguien se acordo de apuntar, asi que cada dialecto nuevo del panel le
   saca otra linea y el detector va siempre un paso por detras.

   El bueno fue el otro: quitar el ayudante y volver a dic['clave'], que ya
   existia. Un dialecto menos que reconocer en vez de uno mas. Y por eso este
   comentario ocupa el sitio del patron: para que el siguiente que se
   encuentre unas claves «sin usar» que si se usan sepa que la pregunta no es
   «como se lo enseño al detector», sino «por que hay tres formas distintas
   de pedir lo mismo». */

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
  /* El Registro de Extranjeros del SAREN, por su nombre, en los cuatro
     idiomas latinos. Es el mismo caso que «Registro Mercantil»: se llama
     asi, no es una palabra suelta en mayuscula por descuido. El español
     se libraba de la regla por tener seis palabras y no cinco, lo cual
     era suerte y no criterio. */
  'Extranjeros Estrangeiros Stranieri Foreigners ' +
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
  'dc_yatienes',
  /* Y el sello de la casilla que salio de un papel: va DETRAS del rotulo,
     igual que los de la empresa y el de «ya lo escribiste» —«Capital
     social · del documento»—. En mayuscula seria un rotulo suyo, y no lo
     es: es el final del de al lado. */
  'pa_lee_sello',
  /* Y la segunda linea del sitio donde se suelta el papel, que continua la
     primera: «Suelta aqui el documento / o pulsa para elegirlo». */
  'pa_lee_elegir'
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

/* ── CADA IDIOMA EN SU SITIO ──
   El panel enseñaba «Waiting on: Visa de inversionista» en castellano, y
   no era un texto sin traducir: la clave t.espera tenia el ingles bajo la
   etiqueta 'es' y el castellano bajo la 'en'. CRUZADOS. Ya habia pasado
   antes con las ocho claves del hilo del expediente.

   Es el fallo que mas facil se cuela, porque ninguna de las otras nueve
   comprobaciones lo ve: las claves estan las seis, ninguna falta, ninguna
   sobra, y las dos frases existen. Solo estan cambiadas de sitio.

   Y engaña tambien a las pruebas de pantalla. La primera que escribi para
   esto comparaba lo pintado con el diccionario, y pasaba tan tranquila:
   los dos decian lo mismo, los dos mal.

   Se mira con palabras que solo pueden ser de un idioma, y solo se acusa
   cuando la sospecha es DOBLE -el castellano suena a ingles Y el ingles
   suena a castellano-. Con una sola no basta: hay rotulos legitimos en
   castellano que llevan una palabra inglesa dentro. Con las 257 claves
   del panel y las 689 de tramites, esto no da un solo falso positivo. */
const SOLO_ING = [' the ', ' of ', ' your ', ' you ', ' with ', 'Waiting',
                  'See ', 'Sign ', 'Show ', 'Hide ', ' done', ' and ', ' for '];
const SOLO_ESP = [' el ', ' la ', ' los ', ' las ', ' tu ', ' tus ', ' con ',
                  ' para ', 'Esperando', 'Ver ', 'Elige', 'Sube ', ' de ', ' y '];
function suenaA(s, lista){
  const t = ' ' + String(s) + ' ';
  return lista.some(w => t.indexOf(w) >= 0);
}
/* LA SEGUNDA SEÑAL, Y POR QUE HIZO FALTA.

   Las listas de arriba son palabras funcionales: ' the ', ' de ', 'Esperando'.
   Sirven cuando la frase es larga y lleva alguna. Se colo t.tarde, que estaba
   cruzado en produccion —quien tenia la pagina en ingles leia «Va mas lento de
   lo previsto»— porque «Slower than expected» no contiene NI UNA de las trece
   palabras inglesas de la lista. Las dos mitades pasaron por buenas.

   Una tilde española bajo la bandera inglesa es señal de sobra, y casi no da
   falsos: el ingles no lleva vocales con tilde, ni ñ, ni ¡ ni ¿. Se pide ademas
   que el castellano NO las lleve, que es lo que descarta el caso legitimo -un
   nombre propio acentuado que aparece en los dos, «Migracion», «Alcaldia»-. Si
   estan en los dos, no hay nada cruzado; si solo estan en el ingles, la frase
   española se ha ido al lado de enfrente. */
const TILDES = /[áíóúñ¡¿]/i;

function cruzados(donde, dic){
  const malos = [];
  if (!dic.es || !dic.en) return malos;
  for (const k of Object.keys(dic.es)){
    const es = dic.es[k], en = dic.en[k];
    if (typeof es !== 'string' || typeof en !== 'string') continue;
    if (suenaA(es, SOLO_ING) && !suenaA(es, SOLO_ESP) &&
        suenaA(en, SOLO_ESP) && !suenaA(en, SOLO_ING)){
      malos.push(`${donde} ${k}: es="${es}" en="${en}"`);
      continue;
    }
    if (es !== en && TILDES.test(en) && !TILDES.test(es)){
      malos.push(`${donde} ${k}: el ingles lleva tildes y el castellano no — es="${es}" en="${en}"`);
    }
  }
  return malos;
}
const revueltos = cruzados('i18n', I18N).concat(cruzados('pasos', UI));
ok('escritura: ningún texto está bajo la bandera de otro idioma',
   revueltos.length === 0,
   revueltos.slice(0, 8).join('\n          '));

/* ── 6 · NINGÚN CONTADOR ESCRITO A MANO EN LOS FILTROS ───────────
   Los cuatro filtros de «Tus trámites» llevaban 33, 2, 1 y 3 escritos en el
   marcado. Ninguno podía ser verdad: cuentan la etapa que está abierta, y
   cuál abre depende de lo que conteste la base. El número se veía durante
   el instante que la página tarda en contar, y prometía tarjetas que abajo
   no estaban.

   Esto se mira AQUÍ y no en el arnés del navegador, y por eso hay que
   decirlo: el arnés lee el DOM, o sea el marcado DESPUÉS de que el script
   lo haya reescrito, así que un número viejo en el archivo le llega ya
   corregido y no puede verlo. La prueba que lo intentaba pasó dos años
   dando por bueno el 32 porque coincidía con lo que el script acababa de
   poner. Lo que hay que leer es el TEXTO del archivo. */
const contadoresAMano = [...PANEL.matchAll(/<span class="n">([^<]*)<\/span>/g)]
  .map(m => m[1].trim()).filter(Boolean);
ok('filtros: ningún contador escrito a mano en el marcado',
   contadoresAMano.length === 0,
   contadoresAMano.length ? ('lleva: ' + contadoresAMano.join(', ')) : '');

/* ══════════ LO QUE LA FICHA DICE ANTES DE SABER NADA ══════════
   «Al darle F5, por unos milisegundos salen fichas que dicen Completadas.»
   (CIIP)

   El panel nacio como maqueta estatica y traia un expediente de ejemplo
   escrito en el marcado: tres fichas con data-st="listo", su distintivo
   verde y renglones como «Issued Jun 18». El navegador lo pinta al instante
   -esta en el archivo- y solo despues llega la respuesta de Supabase y lo
   repinta. En ese hueco, unos cientos de milisegundos en cada recarga, el
   panel le decia a un inversionista que su visa estaba resuelta.

   Esto lo mira EN EL ARCHIVO y no en la pantalla, y ahi esta el porque de
   que durara tanto: cuando el arnes abre el panel, la base ya contesto y el
   ejemplo ya se borro. Una prueba de pantalla no puede ver esto.

   La del banco de activos se queda fuera: no es un tramite -no tiene cola ni
   estado- y su «Disponible» no lo pinta nadie desde la base. Se nombra aqui
   igual que en el panel, y si algun dia entra otra ficha de mirar, esta
   lista es el segundo sitio que hay que tocar. */
const NO_ES_TRAMITE_MARCADO = ['c15'];

function fichasDelMarcado() {
  const fichas = [];
  const re = /<div class="tcard([^>]*)>([\s\S]*?)<div class="t-ente">/g;
  let m;
  while ((m = re.exec(PANEL))) {
    const ref = (/data-tr="(c\d+)"/.exec(m[1]) || [])[1];
    if (ref) fichas.push({ ref, attrs: m[1], cuerpo: m[2] });
  }
  return fichas.filter(f => !NO_ES_TRAMITE_MARCADO.includes(f.ref));
}

{
  const fichas = fichasDelMarcado();
  ok('arranque: hay fichas que mirar en el marcado', fichas.length >= 30,
     fichas.length + ' fichas');

  const conEstado = fichas.filter(f => /data-st="/.test(f.attrs)).map(f => f.ref);
  ok('arranque: ninguna ficha trae su estado escrito',
     conEstado.length === 0,
     conEstado.length ? conEstado.length + ': ' + conEstado.slice(0, 6).join(', ') : '');

  const conChip = fichas
    .filter(f => /<span class="chip [a-z]/.test(f.cuerpo))
    .map(f => f.ref);
  ok('arranque: ni su distintivo de color',
     conChip.length === 0,
     conChip.length ? conChip.length + ': ' + conChip.slice(0, 6).join(', ') : '');

  /* El reloj: ni texto de ejemplo, ni a la vista. Las dos cosas, porque
     esconderlo con algo escrito dentro lo dejaria listo para asomar el dia
     que alguien toque el CSS. */
  const conHora = fichas
    .filter(f => /<span class="t-time"[^>]*>[\s\S]*?<span>[^<]+<\/span>/.test(f.cuerpo))
    .map(f => f.ref);
  ok('arranque: ni una hora de ejemplo en el reloj',
     conHora.length === 0,
     conHora.length ? conHora.length + ': ' + conHora.slice(0, 6).join(', ') : '');

  const alaVista = fichas
    .filter(f => /<span class="t-time">/.test(f.cuerpo))
    .map(f => f.ref);
  ok('arranque: y el reloj nace escondido',
     alaVista.length === 0,
     alaVista.length ? alaVista.length + ': ' + alaVista.slice(0, 6).join(', ') : '');

  /* Y las etapas, que contaban «3 of 10 done» antes de saber nada. */
  const cuentas = (PANEL.match(/class="jcount">[^<]+</g) || []).length;
  ok('arranque: las etapas no cuentan nada todavia', cuentas === 0,
     cuentas + ' cuentas escritas');
  const barras = (PANEL.match(/<span style="width:(?!0%)\d+%"><\/span>/g) || []).length;
  ok('arranque: ni sus barras traen avance', barras === 0,
     barras + ' barras con avance');
}

/* ══════════ NI TE LLAMA POR EL NOMBRE DE OTRO ══════════
   La esquina de la barra traia escrito el inversionista de la maqueta: «MB»
   en el avatar, «Marco Bianchi» y «Investor · Italy». El navegador lo pinta
   al instante, asi que en cada F5 habia un momento en que el panel te
   llamaba por el nombre de otra persona.

   Ya paso una vez, y esta escrito en el panel lo que se penso entonces: las
   cuentas creadas fuera del registro llegan con el nombre vacio, caian en un
   'if (nombre)' y se quedaban con el de la demostracion. «Un panel que te
   llama por el nombre de otro no es un detalle estetico, es una cuenta que
   parece la equivocada.» Aquello se arreglo; el arranque se quedo.

   Se mira el archivo en crudo, como las de arriba: cuando el arnes abre el
   panel la sesion ya contesto y la esquina ya dice quien eres.

   Y NO basta con vaciarlo: el chip tiene que nacer OCULTO. Vacio y visible
   deja un circulo gris y un hueco en la barra que se mueve al llenarse, y
   sobre todo deja el sitio listo para que alguien vuelva a escribir un
   ejemplo dentro. Es lo mismo que ya hace el boton de la cola, dos lineas
   mas arriba en el mismo marcado. */
{
  const chip = /<button class="user"[^>]*>([\s\S]*?)<\/button>/.exec(PANEL);
  ok('esquina: hay chip de usuario que mirar', !!chip, chip ? '' : '(no esta)');
  if (chip) {
    ok('esquina: nace oculto, que quien eres no se sabe todavia',
       /<button class="user"[^>]*\shidden[\s>]/.test(chip[0]),
       /<button class="user"([^>]*)>/.exec(chip[0])[1].trim() || '(sin atributos)');

    const conTexto = [...chip[1].matchAll(/<div class="(avatar|u-name|u-sub)"[^>]*>([^<]+)<\/div>/g)]
      .map(m => m[1] + '="' + m[2].trim() + '"')
      .filter(s => !/=""$/.test(s));
    ok('esquina: y sin nombre, iniciales ni rol escritos',
       conTexto.length === 0,
       conTexto.join(', '));
  }

  /* Y que no quede el nombre de la demostracion en ninguna parte del
     marcado. La variable PERFIL lo sigue teniendo de arranque —el panel se
     puede abrir sin sesion— pero eso vive en el guion, no en lo que el
     navegador pinta antes de saber nada. */
  const enElMarcado = [...PANEL.matchAll(/<[^>]*>\s*Marco Bianchi\s*</g)].length;
  ok('esquina: ni el nombre de la maqueta suelto en el marcado',
     enElMarcado === 0, enElMarcado + ' veces');
}

/* ═══════════════════════════════════════════════════════════════════
   LA TABLA DEL LECTOR: QUE CASILLA SALE DE QUE DOCUMENTO
   ═══════════════════════════════════════════════════════════════════
   LEE_DE ata nombres de casilla con tipos de documento, y los dos lados
   viven en otras dos tablas del mismo archivo. Nada comprueba que
   coincidan: escribir 'razon_sociaal' o 'acta_constitutiba' no da error en
   ninguna parte —simplemente esa casilla no se rellena nunca, y si el tipo
   mal escrito era el unico del tramite, el cuadro de «suelta el papel» no
   llega a pintarse—.

   Un fallo que no dice nada es el que hay que cazar leyendo el texto. */
{
  const bloque = /var LEE_DE = \{([\s\S]*?)\n  \};/.exec(PANEL);
  ok('lector: la tabla LEE_DE esta en el panel', !!bloque, bloque ? '' : '(no esta)');

  if (bloque) {
    /* Los nombres de casilla que la tabla promete rellenar. */
    const promete = [...bloque[1].matchAll(/^\s*([a-z_]+):\s*\[/gm)].map(m => m[1]);
    /* Los que de verdad existen, en CAMPOS. */
    const existen = new Set([...PANEL.matchAll(/\{n:'([a-z_]+)'/g)].map(m => m[1]));
    const inventadas = promete.filter(n => !existen.has(n));
    ok('lector: no promete rellenar casillas que no existen',
       inventadas.length === 0,
       inventadas.length ? inventadas.join(', ') : promete.length + ' casillas, todas de CAMPOS');

    /* Y los documentos: los que nombra contra los que algun tramite pide. */
    const nombra = new Set([...bloque[1].matchAll(/'([a-z_]+)'/g)].map(m => m[1]));
    const pedidos = new Set([...PANEL.matchAll(/\{tipo:'([a-z_]+)'/g)].map(m => m[1]));
    const fantasmas = [...nombra].filter(d => !pedidos.has(d));
    ok('lector: ni leer de documentos que ningun tramite pide',
       fantasmas.length === 0,
       fantasmas.length ? fantasmas.join(', ') : nombra.size + ' documentos, todos de RECAUDOS');

    /* Lo que NO esta en la tabla importa tanto como lo que esta. Estas
       cuatro no las lleva escritas ningun papel del mundo: las decide el
       inversionista —en que consulado tramita, cuanto invierte, en que, y
       para que autoriza al apoderado—. Si alguna apareciera aqui, el panel
       estaria prometiendo sacar de un documento algo que no puede estar
       dentro. */
    const inventables = ['consulado', 'monto_inversion', 'motivo_inversion', 'poder_alcance']
      .filter(n => promete.indexOf(n) >= 0);
    ok('lector: y no promete leer lo que decide el inversionista',
       inventables.length === 0,
       inventables.length ? inventables.join(', ') : 'ninguna de las cuatro');
  }
}

/* El cuadro no se pinta si no hay lector configurado, y hoy no lo hay. Si
   algun dia se subiera una direccion sin querer, esto lo canta: el panel
   empezaria a mandar documentos a un sitio que nadie ha decidido. */
{
  const conf = fs.readFileSync(path.join(RAIZ, 'config.js'), 'utf8');
  const puestas = [...conf.matchAll(/LECTOR_URL:\s*'([^']*)'/g)].map(m => m[1]);
  ok('lector: config.js declara el lector en los dos proyectos',
     puestas.length === 2, puestas.length + ' veces');
  ok('lector: y el panel no se pone un lector por su cuenta',
     !/CIIP_LECTOR\s*=/.test(PANEL),
     /CIIP_LECTOR\s*=/.test(PANEL) ? 'el panel se lo pone solo' : 'solo lo lee');
}

/* EL PIE DE LA TARJETA, QUE YA LLEVA TRES COSAS
   Desde que existe «tienes los papeles», el pie lleva el reloj, la marca y
   «Ver detalles». En dos columnas la tarjeta deja unos 313 px por dentro y
   los tres suman mas: sin envoltura se estrujan entre ellos y los TRES
   textos se parten por la mitad -«Vedi / dettagli» en dos renglones-.

   Se comprueba AQUI, leyendo el CSS, y no con el arnes, por una razon
   concreta: eso solo pasa entre 860 y 1160 px de ventana, y ninguna de las
   trece pasadas mide ahi -doce van a 1400 y una a 760-. Una prueba de
   pantalla que no corre en el ancho donde esta el fallo no sirve de nada, y
   añadir una pasada entera para un renglon de CSS sale caro. */
{
  /* Anclado al principio de renglon. Sin la ^ tambien encaja
     «.t-body .t-foot{margin-top:auto}», que es otra regla y no lleva la
     envoltura: la primera version de esta comprobacion se puso roja por eso,
     y no por el panel. */
  const pie = /^\.t-foot\{([^}]*)\}/m.exec(PANEL);
  ok('tarjeta: la regla del pie esta donde se espera', !!pie, pie ? '' : '(no esta)');
  if (pie) {
    ok('tarjeta: el pie envuelve, que ya lleva tres cosas',
       /flex-wrap:\s*wrap/.test(pie[1]),
       pie[1].replace(/\s+/g, ' ').trim().slice(0, 70), 'con flex-wrap:wrap');
  }
}

console.log('\n  ' + pasan + ' de ' + (pasan + fallan) + ' comprobaciones superadas');
console.log('  ' + claves.length + ' claves de interfaz y ' + clavesUI.length +
            ' de trámites, en ' + idiomas.length + ' idiomas.\n');
process.exit(fallan ? 1 : 0);
