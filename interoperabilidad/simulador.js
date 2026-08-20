/* ═══════════════════════════════════════════════════════════════════
   EL SENIAT DE MENTIRA
   ═══════════════════════════════════════════════════════════════════
   Un servidor que cumple contrato-rif-empresa.md. No es una imitación
   del SENIAT: es la forma que le PEDIMOS al SENIAT, para poder escribir
   el conector antes de que nadie conteste.

   Hace de verdad lo único que no se puede fingir a medias: recuerda lo
   que ya recibió. Sin eso, la prueba de que un reenvio no duplica el
   expediente daria verde sin comprobar nada.

   Node y nada mas: sin dependencias, sin instalar.
       node interoperabilidad/simulador.js
   ═══════════════════════════════════════════════════════════════════ */
'use strict';
const http = require('node:http');

const PUERTO = Number(process.env.PUERTO || 8710);

/* Lo recibido, por Idempotency-Key. En el SENIAT de verdad esto es una
   base de datos; aqui basta con que sobreviva a la siguiente peticion. */
const recibidos = new Map();
let secuencia = 0;

/* Que conteste. La cabecera X-Simular fuerza uno de los casos de la
   tabla del contrato; sin ella, contesta lo normal. Es la razon de ser
   del simulador: un ente real no te deja ensayar sus fallos. */
const CASOS = new Set(['falta-recaudo', 'sin-credencial', 'saturado', 'caido', 'mudo']);

function json(res, codigo, cuerpo, cabeceras) {
  const texto = JSON.stringify(cuerpo, null, 2);
  res.writeHead(codigo, Object.assign({
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(texto)
  }, cabeceras || {}));
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

/* ── presentar un expediente ─────────────────────────────────────── */
async function presentar(req, res) {
  const simula = req.headers['x-simular'];
  const llave = req.headers['idempotency-key'];

  if (!req.headers.authorization) {
    return json(res, 401, { error: 'sin_credencial', motivo: 'Falta la autorizacion.' });
  }
  if (simula === 'sin-credencial') {
    return json(res, 403, { error: 'no_autorizado', motivo: 'Esa credencial no puede presentar este tramite.' });
  }
  if (simula === 'saturado') {
    return json(res, 429, { error: 'saturado', motivo: 'Demasiadas solicitudes.' }, { 'Retry-After': '2' });
  }
  if (simula === 'caido') {
    return json(res, 503, { error: 'no_disponible', motivo: 'El servicio esta en mantenimiento.' });
  }
  if (simula === 'mudo') {
    /* Ni contesta ni cierra: es el peor caso y el que mas cuesta
       distinguir. El conector tiene que rendirse por su cuenta. */
    return;
  }

  if (!llave) {
    return json(res, 400, { error: 'sin_llave', motivo: 'Falta la cabecera Idempotency-Key.' });
  }

  /* Ya lo teniamos: se devuelve el MISMO numero de expediente. Es lo que
     permite reintentar sin miedo cuando no se sabe si llego. */
  if (recibidos.has(llave)) {
    const ya = recibidos.get(llave);
    return json(res, 409, {
      estado: 'recibido',
      expediente_ente: ya.expediente_ente,
      motivo: 'Ese expediente ya estaba presentado.'
    });
  }

  let cuerpo;
  try { cuerpo = await leeCuerpo(req); }
  catch (e) { return json(res, 400, { error: 'json_invalido', motivo: 'El cuerpo no es JSON.' }); }

  /* Un rechazo del NEGOCIO, no un error del sistema: lo miraron y falta
     algo. Sale con 422 y llega al inversionista como una devolucion. */
  if (simula === 'falta-recaudo') {
    return json(res, 422, {
      error: 'recaudo_incompleto',
      campo: 'recaudos.acta_constitutiva',
      motivo: 'El acta constitutiva no trae el sello del Registro Mercantil.'
    });
  }

  const faltan = revisa(cuerpo);
  if (faltan.length) {
    return json(res, 422, {
      error: 'datos_incompletos',
      campo: faltan[0],
      motivo: 'Faltan datos obligatorios: ' + faltan.join(', ') + '.'
    });
  }

  secuencia += 1;
  const expediente = 'SENIAT-2026-' + String(secuencia).padStart(5, '0');
  recibidos.set(llave, {
    expediente_ente: expediente,
    referencia: cuerpo.referencia,
    razon_social: (cuerpo.empresa || {}).razon_social || '',
    estado: 'en_proceso',
    consultas: 0
  });
  json(res, 202, { estado: 'recibido', expediente_ente: expediente });
}

function revisa(cuerpo) {
  const faltan = [];
  const e = cuerpo.empresa || {};
  ['razon_social', 'numero_registro', 'fecha_constitucion',
   'capital_social', 'actividad_economica', 'direccion_fiscal']
    .forEach((c) => { if (!e[c]) faltan.push('empresa.' + c); });
  const tipos = (cuerpo.recaudos || []).map((r) => r.tipo);
  ['acta_constitutiva', 'rif_personal', 'domicilio_empresa']
    .forEach((t) => { if (tipos.indexOf(t) < 0) faltan.push('recaudos.' + t); });
  return faltan;
}

/* ── consultar en que quedo ──────────────────────────────────────── */
function consultar(req, res, expediente) {
  const simula = req.headers['x-simular'];
  let ficha = null;
  for (const v of recibidos.values()) if (v.expediente_ente === expediente) ficha = v;
  if (!ficha) return json(res, 404, { error: 'no_existe', motivo: 'Ese expediente no consta.' });

  if (simula === 'rechazado') {
    ficha.estado = 'rechazado';
    return json(res, 200, {
      estado: 'rechazado',
      motivo: 'La actividad economica declarada no corresponde al objeto social del acta.',
      actualizado_en: '2026-08-21T09:00:00Z'
    });
  }

  /* Un tramite no se resuelve en el primer vistazo. A la tercera
     consulta contesta, que es como se comporta cualquier ente y obliga
     al conector a saber esperar. */
  ficha.consultas += 1;
  if (simula !== 'aprobado' && ficha.consultas < 3) {
    return json(res, 200, { estado: 'en_proceso', actualizado_en: '2026-08-20T16:00:00Z' });
  }

  ficha.estado = 'aprobado';
  json(res, 200, {
    estado: 'aprobado',
    rif_asignado: 'J-4012345' + (secuencia % 10) + '-7',
    documento: {
      nombre: 'rif-empresa.pdf',
      sha256: '3b1a5c7d9e2f4a6b8c0d1e3f5a7b9c1d3e5f7a9b1c3d5e7f9a1b3c5d7e9f1a3b',
      url: 'http://localhost:' + PUERTO + '/descargas/' + expediente + '.pdf'
    },
    actualizado_en: '2026-08-22T11:30:00Z'
  });
}

const servidor = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (req.method === 'POST' && url.pathname === '/expedientes') return presentar(req, res);
  const m = url.pathname.match(/^\/expedientes\/([^/]+)$/);
  if (req.method === 'GET' && m) return consultar(req, res, decodeURIComponent(m[1]));
  if (req.method === 'GET' && url.pathname === '/salud') return json(res, 200, { estado: 'en pie' });
  json(res, 404, { error: 'no_existe', motivo: 'Esa direccion no existe en el contrato.' });
});

function arranca(puerto) {
  return new Promise((cumple) => {
    servidor.listen(puerto || PUERTO, '127.0.0.1', () => cumple(servidor.address().port));
  });
}

if (require.main === module) {
  arranca().then((p) => {
    console.log('SENIAT de mentira escuchando en http://127.0.0.1:' + p);
    console.log('Cabecera X-Simular: ' + [...CASOS].join(' | ') + ' | aprobado | rechazado');
  });
}

module.exports = { arranca, servidor, recibidos };
