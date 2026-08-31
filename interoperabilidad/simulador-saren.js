/* ═══════════════════════════════════════════════════════════════════
   UN SAREN DE MENTIRA
   ═══════════════════════════════════════════════════════════════════
   Cumple contrato-constitucion.md, incluidos sus fallos.

   Lo que este simulador sabe hacer y el del SENIAT no: llevar un
   registro de denominaciones OCUPADAS, para poder ensayar las tres
   situaciones que importan -la primera libre, la primera ocupada y la
   alternativa libre, y las dos ocupadas-. Eso no se puede ensayar contra
   un registro de verdad sin ir reservando nombres reales.

       node interoperabilidad/simulador-saren.js     (a mano, en el 8730)
   ═══════════════════════════════════════════════════════════════════ */
'use strict';
const http = require('http');

let PUERTO = 8730;

const recibidos = new Map();       /* por Idempotency-Key */
let secuencia = 0;

/* Nombres que ya estan tomados en el registro. Se puede anadir por la
   cabecera X-Ocupadas, separados por punto y coma, para que cada prueba
   monte su escenario sin ensuciar las demas. */
const OCUPADAS = new Set();

const CASOS = new Set(['sin-credencial', 'objeto-social', 'saturado', 'caido', 'mudo',
                       'observado', 'registrado', 'registrado-sin-acta']);

function json(res, codigo, cuerpo) {
  const texto = JSON.stringify(cuerpo, null, 2);
  res.writeHead(codigo, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(texto)
  });
  res.end(texto);
}

function leeCuerpo(req) {
  return new Promise((cumple, falla) => {
    let t = '';
    req.on('data', (p) => { t += p; if (t.length > 2e6) req.destroy(); });
    req.on('end', () => {
      if (!t) return cumple({});
      try { cumple(JSON.parse(t)); } catch (e) { falla(e); }
    });
    req.on('error', falla);
  });
}

function llano(x) {
  return String(x || '').trim().toLowerCase();
}

async function presentar(req, res) {
  const simula = req.headers['x-simular'];
  const llave = req.headers['idempotency-key'];

  if (!req.headers.authorization) {
    return json(res, 401, { error: 'sin_credencial', motivo: 'Falta la autorizacion.' });
  }
  if (simula === 'sin-credencial') {
    return json(res, 403, { error: 'no_autorizado',
                            motivo: 'Esa credencial no puede presentar constituciones.' });
  }
  if (!llave) {
    return json(res, 400, { error: 'sin_llave', motivo: 'Falta Idempotency-Key.' });
  }

  if (recibidos.has(llave)) {
    const ya = recibidos.get(llave);
    return json(res, 409, {
      estado: 'ya_recibido',
      expediente_ente: ya.expediente_ente,
      denominacion_reservada: ya.denominacion,
      era_la_alternativa: ya.era_alt
    });
  }

  if (simula === 'caido')    { req.destroy(); return; }
  if (simula === 'mudo')     { return; }
  if (simula === 'saturado') {
    return json(res, 429, { error: 'saturado', motivo: 'Vuelva a intentarlo.' });
  }

  let cuerpo;
  try { cuerpo = await leeCuerpo(req); }
  catch (e) { return json(res, 400, { error: 'json_invalido', motivo: 'El cuerpo no es JSON.' }); }

  /* Las que esta prueba declara ocupadas. */
  const extra = String(req.headers['x-ocupadas'] || '');
  const tomadas = new Set([...OCUPADAS]);
  extra.split(';').forEach((x) => { if (x.trim()) tomadas.add(llano(x)); });

  const faltan = revisa(cuerpo);
  if (faltan.length) {
    return json(res, 422, { error: 'datos_incompletos',
                            motivo: 'Faltan: ' + faltan.join(', ') + '.',
                            campo: faltan[0] });
  }

  if (simula === 'objeto-social') {
    return json(res, 422, { error: 'objeto_social',
                            motivo: 'El objeto social no corresponde con la actividad declarada.',
                            campo: 'compania.objeto_social' });
  }

  const c = cuerpo.compania || {};
  const primera = llano(c.denominacion);
  const alt = llano(c.denominacion_alt);

  let elegida = null, eraAlt = false;
  if (!tomadas.has(primera)) {
    elegida = c.denominacion;
  } else if (alt && !tomadas.has(alt)) {
    elegida = c.denominacion_alt;
    eraAlt = true;
  } else {
    return json(res, 422, {
      error: 'denominaciones_ocupadas',
      motivo: alt
        ? 'Las dos denominaciones propuestas ya estan registradas.'
        : 'La denominacion propuesta ya esta registrada y no se dio alternativa.',
      campo: 'compania.denominacion'
    });
  }

  secuencia += 1;
  const expediente = 'SAREN-2026-' + String(secuencia).padStart(5, '0');
  OCUPADAS.add(llano(elegida));
  recibidos.set(llave, {
    expediente_ente: expediente,
    denominacion: elegida,
    era_alt: eraAlt,
    estado: 'en_proceso',
    consultas: 0
  });
  json(res, 202, {
    estado: 'recibido',
    expediente_ente: expediente,
    denominacion_reservada: elegida,
    era_la_alternativa: eraAlt
  });
}

function revisa(cuerpo) {
  const faltan = [];
  const c = cuerpo.compania || {};
  ['denominacion', 'tipo_sociedad', 'capital_social', 'objeto_social',
   'domicilio_social', 'socios']
    .forEach((k) => { if (!c[k]) faltan.push('compania.' + k); });
  const tipos = (cuerpo.recaudos || []).map((r) => r.tipo);
  ['cedula', 'rif_personal', 'comprobante_capital', 'domicilio_empresa']
    .forEach((t) => { if (tipos.indexOf(t) < 0) faltan.push('recaudos.' + t); });
  return faltan;
}

function consultar(req, res, expediente) {
  const simula = req.headers['x-simular'];
  let ficha = null;
  for (const v of recibidos.values()) if (v.expediente_ente === expediente) ficha = v;
  if (!ficha) return json(res, 404, { error: 'no_existe', motivo: 'Ese expediente no consta.' });

  if (simula === 'observado') {
    ficha.estado = 'observado';
    return json(res, 200, {
      estado: 'observado',
      motivo: 'El registrador observo la redaccion del objeto social.',
      actualizado_en: '2026-08-21T09:00:00Z'
    });
  }

  /* Un acta no se registra en el primer vistazo. A la tercera, como el
     SENIAT: obliga al conector a saber esperar. */
  ficha.consultas += 1;
  if (simula !== 'registrado' && simula !== 'registrado-sin-acta' && ficha.consultas < 3) {
    return json(res, 200, { estado: 'en_proceso', actualizado_en: '2026-08-20T16:00:00Z' });
  }

  /* El caso que hay que poder ensayar: registrado PERO sin el acta. Un
     registro de verdad no deberia hacerlo, y por eso mismo hay que saber
     que pasa si lo hace. */
  if (simula === 'registrado-sin-acta') {
    return json(res, 200, { estado: 'registrado', tomo: '45-A', numero: '12' });
  }

  ficha.estado = 'registrado';
  json(res, 200, {
    estado: 'registrado',
    tomo: '45-A',
    numero: String(10 + (secuencia % 90)),
    documento: {
      nombre: 'acta-registrada.pdf',
      sha256: '7c9e6679e2f2d5b1a3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6',
      url: 'http://localhost:' + PUERTO + '/descargas/' + expediente + '.pdf'
    },
    actualizado_en: '2026-08-25T11:30:00Z'
  });
}

const servidor = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (req.method === 'POST' && url.pathname === '/constituciones') return presentar(req, res);
  const m = url.pathname.match(/^\/constituciones\/(.+)$/);
  if (req.method === 'GET' && m) return consultar(req, res, decodeURIComponent(m[1]));
  json(res, 404, { error: 'no_existe', motivo: 'Esa ruta no esta en el contrato.' });
});

function arranca(puerto) {
  return new Promise((cumple) => {
    servidor.listen(puerto === undefined ? PUERTO : puerto, '127.0.0.1', () => {
      PUERTO = servidor.address().port;
      cumple(PUERTO);
    });
  });
}

if (require.main === module) {
  arranca().then((p) => {
    console.log('SAREN de mentira en http://127.0.0.1:' + p);
    console.log('Cabecera X-Simular:  ' + [...CASOS].join(' | '));
    console.log('Cabecera X-Ocupadas: denominaciones ya tomadas, separadas por ;');
  });
}

module.exports = { arranca, servidor };
