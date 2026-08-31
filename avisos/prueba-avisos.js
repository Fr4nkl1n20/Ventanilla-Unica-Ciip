/* ═══════════════════════════════════════════════════════════════════
   PRUEBAS DE LOS AVISOS
   ═══════════════════════════════════════════════════════════════════
   Un aviso se equivoca de tres maneras, y las tres se prueban aqui:

     - llega en el idioma que no es
     - dice algo que no se entiende, o con un hueco sin rellenar
     - se pierde en silencio cuando el correo no sale

   La tercera es la peor y la mas facil de no ver: un sistema que manda
   correos y no comprueba que salieron parece funcionar perfectamente.

   No se levanta ningun SMTP: el transporte es de mentira y guarda lo que
   se le dio, que es la unica forma de leer lo que se habria mandado.

       node avisos/prueba-avisos.js
   ═══════════════════════════════════════════════════════════════════ */
'use strict';
const fs = require('fs');
const path = require('path');
const M = require('./mensajero.js');
const { TEXTOS, IDIOMA_PAIS } = require('./textos.js');

let pasan = 0, fallan = 0;
function ok(que, cierto, obtuvo, esperaba) {
  if (cierto) { pasan++; console.log('  PASA  ' + que); return; }
  fallan++;
  console.log('  FALLA ' + que);
  console.log('          esperaba : ' + esperaba);
  console.log('          obtuvo   : ' + obtuvo);
}
function igual(que, a, b) { ok(que, a === b, String(a), String(b)); }


function unAviso(extra) {
  return Object.assign({
    id: 'aviso-1',
    motivo: 'cambio_estado',
    a_estado: 'devuelto',
    destinatario: 'alguien@ejemplo.com',
    pais: 'Italia',
    nota: '',
    dato: '',
    intentos: 0
  }, extra || {});
}

/* Guarda lo que se le pide, como el cuaderno del trabajador. */
function bandeja() {
  const salidas = [], apuntes = [];
  return {
    salidas, apuntes,
    async pendientes() { return []; },
    async marcaEnviado(id)        { apuntes.push({ que: 'enviado', id }); },
    async marcaFallido(id, e)     { apuntes.push({ que: 'fallido', id, e }); },
    async marcaImposible(id, e)   { apuntes.push({ que: 'imposible', id, e }); },
    transporte: {
      async envia(carta) { salidas.push(carta); }
    },
    /* Un SMTP que no va. */
    roto: {
      async envia() { throw new Error('el servidor de correo no contesta'); }
    }
  };
}
function apunte(b, que) { return b.apuntes.find(function (a) { return a.que === que; }) || null; }


(function () {
  console.log('\n  PRUEBAS DE LOS AVISOS');
  console.log('  ---------------------\n');

  /* ═══ 1 · EL IDIOMA ═══════════════════════════════════════════════ */
  const porPais = [
    ['España',         'es'], ['Venezuela', 'es'], ['México',        'es'],
    ['Brasil',         'pt'], ['Portugal',  'pt'],
    ['Italia',         'it'],
    ['Rusia',          'ru'], ['Kazajistán', 'ru'],
    ['China',          'zh'],
    ['Estados Unidos', 'en'], ['Canadá',    'en']
  ];
  for (const [pais, esperado] of porPais) {
    igual('idioma: ' + pais + ' escribe en ' + esperado, M.idiomaDe(pais), esperado);
  }

  /* El caso que de verdad importa: un pais que no habla ninguno de los
     seis. Sin este resguardo, un japones recibiria un correo vacio o con
     "undefined" dentro. */
  igual('idioma: un pais fuera de los seis recibe en ingles', M.idiomaDe('Japón'), 'en');
  igual('idioma: sin pais tambien, en vez de fallar', M.idiomaDe(''), 'en');
  igual('idioma: y un pais inventado, igual', M.idiomaDe('Wakanda'), 'en');

  /* Las tildes no cambian el pais. */
  igual('idioma: "espana" sin tilde es el mismo pais', M.idiomaDe('espana'), 'es');

  /* ── que no se desvie de la del panel ─────────────────────────────
     Esta lista es copia de IDIOMA_PAIS del panel. Si alli se anade un
     pais y aqui no, alguien recibe correos en un idioma que no lee, y
     eso no lo notaria nadie hasta que se quejara. Se lee del HTML y se
     compara. */
  {
    const html = fs.readFileSync(
      path.join(__dirname, '..', 'ciip-ventanilla-unica-local.html'), 'utf8');
    const i = html.indexOf('var IDIOMA_PAIS = {');
    const trozo = html.slice(i, html.indexOf('};', i));
    let iguales = true, detalle = '';
    for (const l of Object.keys(IDIOMA_PAIS)) {
      const m = trozo.match(new RegExp(l + ":\\s*\\(?([\\s\\S]*?)\\)?\\.split"));
      const enPanel = m ? (m[1].match(/[A-Z]{2}/g) || []).join(' ') : '(no esta)';
      const aqui = IDIOMA_PAIS[l].join(' ');
      if (enPanel !== aqui) { iguales = false; detalle += l + ' '; }
    }
    ok('idioma: la lista de paises no se ha desviado de la del panel',
       iguales, 'difieren en: ' + detalle, 'identicas');
  }

  /* ═══ 2 · LO QUE DICE ═════════════════════════════════════════════ */
  {
    const c = M.redacta(unAviso({ pais: 'Brasil', nota: 'RIF da empresa' }));
    igual('texto: a un brasileno le llega en portugues', c.idioma, 'pt');
    ok('texto: y el asunto esta en portugues',
       /correção/.test(c.asunto), c.asunto, 'en portugues');
  }

  {
    const c = M.redacta(unAviso({ pais: 'China', a_estado: 'resuelto', nota: '公司税号' }));
    igual('texto: a un chino le llega en chino', c.idioma, 'zh');
    ok('texto: sin un solo hueco sin rellenar',
       c.cuerpo.indexOf('{') < 0 && c.asunto.indexOf('{') < 0,
       c.cuerpo, 'sin llaves');
  }

  /* Ningun texto de ningun idioma puede dejar un hueco. Se comprueban
     los seis por los cuatro motivos, que son veinticuatro, en vez de
     confiar en haberlos mirado a ojo. */
  {
    let malos = [];
    for (const idioma of Object.keys(TEXTOS)) {
      const pais = { es: 'España', en: 'Estados Unidos', pt: 'Brasil',
                     it: 'Italia', zh: 'China', ru: 'Rusia' }[idioma];
      for (const motivo of ['devuelto', 'resuelto', 'ante_el_ente', 'documento_vence']) {
        const av = motivo === 'documento_vence'
          ? unAviso({ pais, motivo: 'documento_vence', a_estado: null,
                      nota: '2026-12-01', dato: 'Pasaporte' })
          : unAviso({ pais, a_estado: motivo, nota: 'RIF' });
        const c = M.redacta(av);
        if (!c) { malos.push(idioma + '/' + motivo + ' sin texto'); continue; }
        if (/[{}]/.test(c.asunto + c.cuerpo)) malos.push(idioma + '/' + motivo);
        if (!c.asunto.trim() || !c.cuerpo.trim()) malos.push(idioma + '/' + motivo + ' vacio');
      }
    }
    ok('texto: los seis idiomas por los cuatro motivos, sin huecos ni vacios',
       malos.length === 0, malos.join(', '), 'ninguno');
  }

  /* La nota del organismo va entrecomillada y aparte. Pegada a la frase
     nuestra daria un parrafo mitad en un idioma y mitad en otro. */
  {
    const c = M.redacta(unAviso({ pais: 'España', nota: 'Falta el acta constitutiva' }));
    ok('texto: la nota del organismo va aparte y entrecomillada',
       /«Falta el acta constitutiva»/.test(c.cuerpo), c.cuerpo, 'entrecomillada');
  }

  /* Y solo en la devolucion: en un "resuelto" no hay nada que citar. */
  {
    const c = M.redacta(unAviso({ pais: 'España', a_estado: 'resuelto', nota: 'RIF' }));
    ok('texto: en un resuelto no se cita ninguna nota',
       c.cuerpo.indexOf('«') < 0, c.cuerpo, 'sin comillas');
  }

  {
    const c = M.redacta(unAviso({ motivo: 'documento_vence', a_estado: null,
                                  pais: 'España', nota: '2026-12-01', dato: 'Pasaporte' }));
    ok('texto: el aviso de vencimiento dice qué documento y cuándo',
       /Pasaporte/.test(c.cuerpo) && /2026-12-01/.test(c.cuerpo),
       c.cuerpo, 'el documento y la fecha');
  }

  /* Un motivo del que no hay texto: se calla en vez de mandar algo raro. */
  {
    const c = M.redacta(unAviso({ a_estado: 'en_revision' }));
    igual('texto: de un estado que no se avisa, no se inventa nada', c, null);
  }

  /* ═══ 3 · QUE NO SE PIERDA ════════════════════════════════════════ */
  (async function () {
    {
      const b = bandeja();
      const r = await M.manda(unAviso({ pais: 'Italia' }), b, b.transporte);
      igual('envio: sale', r.hizo, 'enviado');
      igual('envio: y queda apuntado que salio', (apunte(b, 'enviado') || {}).que, 'enviado');
      igual('envio: al destinatario de la fila', b.salidas[0].para, 'alguien@ejemplo.com');
    }

    {
      const b = bandeja();
      const r = await M.manda(unAviso(), b, b.roto);
      igual('SMTP caido: se reintenta', r.hizo, 'reintentar');
      ok('SMTP caido: y el aviso NO se da por enviado',
         !apunte(b, 'enviado'), 'lo dio por enviado', 'sigue pendiente');
      ok('SMTP caido: con el error escrito, no perdido',
         /no contesta/.test((apunte(b, 'fallido') || {}).e || ''),
         (apunte(b, 'fallido') || {}).e, 'el error dentro');
    }

    {
      const b = bandeja();
      const r = await M.manda(unAviso({ intentos: M.INTENTOS_MAX - 1 }), b, b.roto);
      igual('SMTP caido: al agotar los intentos se deja de intentar', r.hizo, 'imposible');
      ok('y se dice por que, en vez de callar',
         /agotaron/.test((apunte(b, 'imposible') || {}).e || ''),
         (apunte(b, 'imposible') || {}).e, 'que se agotaron');
    }

    {
      /* Un motivo sin texto no atasca la cola: se marca y se sigue. */
      const b = bandeja();
      const r = await M.manda(unAviso({ a_estado: 'en_revision' }), b, b.transporte);
      igual('un aviso sin texto no se reintenta para siempre', r.hizo, 'imposible');
      igual('y no se manda nada', b.salidas.length, 0);
    }

    {
      /* Una vuelta entera, y uno malo no se lleva a los demas. */
      const b = bandeja();
      b.pendientes = async function () {
        return [unAviso({ id: 'a', pais: 'Italia' }),
                unAviso({ id: 'b', a_estado: 'en_revision' }),
                unAviso({ id: 'c', pais: 'Brasil', a_estado: 'resuelto' })];
      };
      const hechos = await M.unaVuelta(b, b.transporte);
      igual('una vuelta atiende todos los pendientes', hechos.length, 3);
      igual('y uno sin texto no impide los otros dos', b.salidas.length, 2);
      ok('cada uno en su idioma',
         b.salidas[0].idioma === 'it' && b.salidas[1].idioma === 'pt',
         b.salidas.map(function (s) { return s.idioma; }).join(', '), 'it, pt');
    }

    console.log('');
    console.log('  ' + pasan + ' de ' + (pasan + fallan) + ' pruebas superadas');
    console.log('');
    console.log('  Esto prueba que se escribe bien y que no se pierde. Que el');
    console.log('  aviso se apunte solo al cambiar un estado lo prueba');
    console.log('  PROBAR-SQL.bat; que el correo LLEGUE, ningun arnes: eso');
    console.log('  necesita un SMTP de verdad y una direccion de verdad.');
    console.log('');
    process.exit(fallan ? 1 : 0);
  })();
})();
