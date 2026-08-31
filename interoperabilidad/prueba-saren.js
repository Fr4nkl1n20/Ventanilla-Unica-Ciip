/* ═══════════════════════════════════════════════════════════════════
   PRUEBAS DEL CONECTOR · Constitucion de compania
   ═══════════════════════════════════════════════════════════════════
   Lo mismo que prueba.js hace con el RIF, mas lo que este tramite tiene
   y aquel no: que la denominacion puede estar ocupada, y que hay una
   alternativa que evita un viaje entero.

       node interoperabilidad/prueba-saren.js
   ═══════════════════════════════════════════════════════════════════ */
'use strict';
const { arranca } = require('./simulador-saren.js');
const K = require('./conector-saren.js');

let pasan = 0, fallan = 0;
function ok(que, cierto, obtuvo, esperaba) {
  if (cierto) { pasan++; console.log('  PASA  ' + que); return; }
  fallan++;
  console.log('  FALLA ' + que);
  console.log('          esperaba : ' + esperaba);
  console.log('          obtuvo   : ' + obtuvo);
}
function igual(que, a, b) { ok(que, a === b, String(a), String(b)); }

let n = 0;
function unTramite(datos) {
  n++;
  return {
    id: 't-saren-' + String(n).padStart(3, '0'),
    tipo: 'constitucion',
    estado: 'en_revision',
    enviado_en: '2026-08-20T14:02:11Z',
    datos: Object.assign({
      denominacion:     'Bianchi Agroindustrias',
      denominacion_alt: 'Bianchi Agro de Venezuela',
      tipo_sociedad:    'C.A.',
      capital_social:   '150000.00',
      objeto_social:    'Procesamiento y comercializacion de cacao',
      domicilio_social: 'Av. Principal, Galpon 4, Charallave, Miranda',
      socios:           'Franklin Reyes (60%), Giulia Bianchi (40%)'
    }, datos || {})
  };
}
const RECAUDOS = [
  { tipo: 'cedula',              nombre_original: 'cedula.pdf',    sha256: '9f86d081', url_firmada: 'https://x/a' },
  { tipo: 'rif_personal',        nombre_original: 'rif.pdf',       sha256: 'a1b2c3d4', url_firmada: 'https://x/b' },
  { tipo: 'comprobante_capital', nombre_original: 'capital.pdf',   sha256: 'e5f6a7b8', url_firmada: 'https://x/c' },
  { tipo: 'domicilio_empresa',   nombre_original: 'domicilio.pdf', sha256: '11223344', url_firmada: 'https://x/d' }
];
const SOLICITANTE = { nombre: 'Franklin Reyes', representante: 'Franklin Reyes', documento: 'V-12345678' };


(async function () {
  const puerto = await arranca(0);
  const base = 'http://127.0.0.1:' + puerto;
  const cfg = { base, token: 'de-mentira', msLimite: 4000 };
  const con = function (cabeceras) { return Object.assign({}, cfg, { cabeceras }); };
  const forzar = function (caso) { return con({ 'X-Simular': caso }); };
  const ocupadas = function (lista, caso) {
    const h = { 'X-Ocupadas': lista };
    if (caso) h['X-Simular'] = caso;
    return con(h);
  };

  console.log('\n  PRUEBAS DEL CONECTOR · Constitucion de compania');
  console.log('  ----------------------------------------------\n');
  console.log('  SAREN de mentira en ' + base + '\n');

  /* ═══ presentar ═══ */
  const t1 = unTramite();
  const r1 = await K.presenta(t1, RECAUDOS, SOLICITANTE, cfg);
  igual('presentar: lo reciben y el tramite queda ante el registro',
        r1.accion, K.ACCIONES.PRESENTADO);
  ok('presentar: con el numero de expediente que ellos dan',
     /^SAREN-2026-\d{5}$/.test(r1.expediente_ente || ''), r1.expediente_ente, 'SAREN-2026-00001');
  igual('presentar: y con la denominacion que reservaron',
        r1.denominacion, 'Bianchi Agroindustrias');
  igual('presentar: que en este caso era la primera', r1.eraLaAlternativa, false);

  {
    const e = K.armaExpediente(t1, RECAUDOS, SOLICITANTE);
    igual('envio: la referencia es el id del tramite', e.referencia, t1.id);
    igual('envio: van los siete campos de la compania',
          Object.keys(e.compania).length, 7);
    igual('envio: y los cuatro recaudos', e.recaudos.length, 4);
    ok('envio: los archivos van por URL firmada, no dentro del cuerpo',
       e.recaudos.every(function (r) { return !!r.url && r.url.indexOf('http') === 0; }),
       JSON.stringify(e.recaudos[0]), 'una url');
    ok('envio: cada archivo lleva su huella, para poder probar cual era',
       e.recaudos.every(function (r) { return !!r.sha256; }),
       JSON.stringify(e.recaudos.map(function (r) { return r.sha256; })), 'todas con sha256');
  }

  /* ═══ lo que este tramite tiene y el RIF no ═══ */
  {
    /* La primera ocupada, la alternativa libre: se reserva la segunda y
       el tramite SIGUE. Sin esto habria un viaje entero de vuelta al
       inversionista para que escribiera otro nombre. */
    const t = unTramite({ denominacion: 'Cacaos del Tuy',
                          denominacion_alt: 'Cacaos del Valle del Tuy' });
    const r = await K.presenta(t, RECAUDOS, SOLICITANTE, ocupadas('cacaos del tuy'));
    igual('denominacion: si la primera esta ocupada, sigue con la alternativa',
          r.accion, K.ACCIONES.PRESENTADO);
    igual('denominacion: y dice cual reservo', r.denominacion, 'Cacaos del Valle del Tuy');
    igual('denominacion: avisando de que fue la alternativa', r.eraLaAlternativa, true);
  }

  {
    /* Las dos ocupadas: ahora si se devuelve, y la nota tiene que decir
       que lo que hay que hacer es elegir otro nombre. */
    const t = unTramite({ denominacion: 'Uno', denominacion_alt: 'Dos' });
    const r = await K.presenta(t, RECAUDOS, SOLICITANTE, ocupadas('uno;dos'));
    igual('denominacion: con las dos ocupadas se devuelve', r.accion, K.ACCIONES.DEVOLVER);
    ok('denominacion: y se dice que hay que elegir otra',
       r.esDenominacion === true && /registrada/i.test(r.nota || ''), r.nota, 'que estan tomadas');
  }

  {
    /* Sin alternativa y con la primera ocupada: tambien se devuelve, y
       eso es correcto. Inventarle un nombre seria constituir una
       compania que nadie eligio. */
    const t = unTramite({ denominacion: 'Tres', denominacion_alt: '' });
    const r = await K.presenta(t, RECAUDOS, SOLICITANTE, ocupadas('tres'));
    igual('denominacion: sin alternativa y ocupada, se devuelve', r.accion, K.ACCIONES.DEVOLVER);
    ok('denominacion: y no se inventa ningun nombre',
       !r.denominacion, String(r.denominacion), 'ninguno');
  }

  /* ═══ reintento ═══ */
  {
    const t = unTramite({ denominacion: 'Reintento SA' });
    const a = await K.presenta(t, RECAUDOS, SOLICITANTE, cfg);
    const b = await K.presenta(t, RECAUDOS, SOLICITANTE,
                               Object.assign({}, cfg, { intento: 2 }));
    igual('reintento: no se presenta dos veces el mismo expediente',
          b.expediente_ente, a.expediente_ente);
    igual('reintento: y la denominacion reservada es la misma',
          b.denominacion, a.denominacion);
    ok('reintento: el conector sabe que ya estaba', b.yaEstaba === true, String(b.yaEstaba), 'true');
  }

  /* ═══ devoluciones ═══ */
  {
    const flaco = unTramite();
    delete flaco.datos.objeto_social;
    const r = await K.presenta(flaco, RECAUDOS, SOLICITANTE, cfg);
    igual('datos incompletos: se devuelve al inversionista', r.accion, K.ACCIONES.DEVOLVER);
    ok('datos incompletos: nombrando el campo que falta',
       /objeto_social/.test(r.nota || ''), r.nota, 'nombra el campo');
    ok('datos incompletos: y no es un problema de denominacion',
       r.esDenominacion !== true, String(r.esDenominacion), 'false');
  }

  {
    const r = await K.presenta(unTramite({ denominacion: 'Objeto SA' }), RECAUDOS,
                               SOLICITANTE, forzar('objeto-social'));
    igual('objeto social: tambien se devuelve, no se reintenta', r.accion, K.ACCIONES.DEVOLVER);
    igual('objeto social: y se dice cual es el campo', r.campo, 'compania.objeto_social');
  }

  {
    const r = await K.presenta(unTramite(), RECAUDOS.slice(0, 2), SOLICITANTE, cfg);
    igual('recaudo que falta: se devuelve', r.accion, K.ACCIONES.DEVOLVER);
    ok('recaudo que falta: y se dice cual', /recaudos\./.test(r.campo || ''),
       r.campo, 'recaudos.algo');
  }

  /* ═══ los que NO se devuelven ═══ */
  {
    const r = await K.presenta(unTramite({ denominacion: 'Cred SA' }), RECAUDOS,
                               SOLICITANTE, forzar('sin-credencial'));
    igual('credenciales: es problema nuestro, no del inversionista', r.accion, K.ACCIONES.ALERTAR);
  }
  {
    const r = await K.presenta(unTramite({ denominacion: 'Sat SA' }), RECAUDOS,
                               SOLICITANTE, forzar('saturado'));
    igual('saturado: se reintenta', r.accion, K.ACCIONES.REINTENTAR);
    ok('saturado: con una espera', r.esperaS > 0, String(r.esperaS), 'mas de cero');
  }
  {
    const r = await K.presenta(unTramite({ denominacion: 'Caido SA' }), RECAUDOS,
                               SOLICITANTE, forzar('caido'));
    igual('caido: se reintenta', r.accion, K.ACCIONES.REINTENTAR);
  }
  {
    const r = await K.presenta(unTramite({ denominacion: 'Mudo SA' }), RECAUDOS, SOLICITANTE,
                               Object.assign({}, forzar('mudo'), { msLimite: 700 }));
    igual('mudo: se corta el plazo y se reintenta', r.accion, K.ACCIONES.REINTENTAR);
    ok('mudo: y no queda dicho que llego, porque no se sabe',
       r.accion !== K.ACCIONES.PRESENTADO, r.accion, 'reintentar');
  }

  /* ═══ consultar ═══ */
  {
    const c1 = await K.consulta(r1.expediente_ente, cfg);
    igual('consulta: al principio sigue en proceso', c1.accion, K.ACCIONES.ESPERAR);
    await K.consulta(r1.expediente_ente, cfg);
    const c3 = await K.consulta(r1.expediente_ente, cfg);
    igual('consulta: cuando lo registran, el tramite se resuelve', c3.accion, K.ACCIONES.RESUELTO);
    ok('consulta: y llega el acta, con su huella',
       !!(c3.documento && c3.documento.url && c3.documento.sha256),
       JSON.stringify(c3.documento || null), 'url y sha256');
    ok('consulta: con el tomo y el numero, que es lo que la hace existir',
       !!c3.tomo && !!c3.numero, c3.tomo + ' / ' + c3.numero, 'los dos');
    ok('consulta: y escritos de una forma que se pueda leer',
       /Tomo .+, número .+/.test(c3.registro || ''), c3.registro, 'Tomo 45-A, número 12');
  }

  {
    const t = unTramite({ denominacion: 'Observada SA' });
    const p = await K.presenta(t, RECAUDOS, SOLICITANTE, cfg);
    const c = await K.consulta(p.expediente_ente, forzar('observado'));
    igual('consulta: si lo observan, se devuelve al inversionista', c.accion, K.ACCIONES.DEVOLVER);
    ok('consulta: con el motivo del registrador',
       /objeto social/i.test(c.nota || ''), c.nota, 'el motivo');
  }

  {
    /* El caso que hay que poder ensayar: registrado PERO sin acta. Un
       registro de verdad no deberia hacerlo, y por eso mismo hay que
       saber que pasa si lo hace. */
    const t = unTramite({ denominacion: 'Sin acta SA' });
    const p = await K.presenta(t, RECAUDOS, SOLICITANTE, cfg);
    const c = await K.consulta(p.expediente_ente, forzar('registrado-sin-acta'));
    igual('registrado sin acta: NO se da por resuelto', c.accion, K.ACCIONES.ALERTAR);
    ok('registrado sin acta: y se dice que falta',
       /acta/i.test(c.motivo || ''), c.motivo, 'que falta el acta');
  }

  {
    const c = await K.consulta('SAREN-2026-99999', cfg);
    igual('consulta: un expediente que no consta es para alertar', c.accion, K.ACCIONES.ALERTAR);
  }

  console.log('');
  console.log('  ' + pasan + ' de ' + (pasan + fallan) + ' pruebas superadas');
  console.log('');
  console.log('  Esto prueba el conector contra el contrato, no contra el SAREN.');
  console.log('  Cuando el SAREN conteste, cambia la direccion y las credenciales;');
  console.log('  si su forma es otra, se le pone un traductor delante.');
  console.log('');
  process.exit(fallan ? 1 : 0);
})();
