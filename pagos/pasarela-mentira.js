/* ═══════════════════════════════════════════════════════════════════
   UNA PASARELA DE PAGO DE MENTIRA
   ═══════════════════════════════════════════════════════════════════
   Lo mismo que interoperabilidad/simulador.js hace con el SENIAT, pero
   con el banco: cumple el contrato que le vamos a pedir, incluidos sus
   fallos, para poder escribir y probar el cobrador antes de que haya
   convenio con nadie.

   Y aqui los fallos importan MAS que con un organismo. Un expediente
   presentado dos veces se anula; un cobro duplicado es dinero de una
   persona. Por eso lo que se ensaya sobre todo es lo que pasa cuando NO
   se sabe si el cargo entro.

       node pagos/pasarela-mentira.js       (a mano, en el 8720)
   ═══════════════════════════════════════════════════════════════════ */
'use strict';
const http = require('http');

let PUERTO = 8720;

/* Lo cobrado, por Idempotency-Key. Igual que en el SENIAT: reintentar
   con la misma llave devuelve el mismo cargo en vez de hacer otro. */
const cobrados = new Map();
let secuencia = 0;

const CASOS = new Set(['sin-credencial', 'fondos', 'tarjeta-mala', 'saturado', 'caido', 'mudo']);

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
    req.on('data', (p) => { t += p; if (t.length > 1e6) req.destroy(); });
    req.on('end', () => {
      if (!t) return cumple({});
      try { cumple(JSON.parse(t)); } catch (e) { falla(e); }
    });
    req.on('error', falla);
  });
}

async function cobrar(req, res) {
  const simula = req.headers['x-simular'];
  const llave = req.headers['idempotency-key'];

  if (!req.headers.authorization) {
    return json(res, 401, { error: 'sin_credencial', motivo: 'Falta la autorizacion.' });
  }
  if (!llave) {
    return json(res, 400, { error: 'sin_llave', motivo: 'Falta Idempotency-Key.' });
  }

  /* Lo primero, antes de mirar nada: si esta llave ya se cobro, se
     devuelve lo mismo. Cobrar dos veces por un corte de red es el peor
     fallo que puede tener esto. */
  if (cobrados.has(llave)) {
    const ya = cobrados.get(llave);
    return json(res, 409, { estado: 'ya_cobrado', referencia: ya.referencia, monto: ya.monto });
  }

  if (simula === 'sin-credencial') {
    return json(res, 403, { error: 'no_autorizado',
                            motivo: 'Esa credencial no puede cobrar en esta cuenta.' });
  }
  if (simula === 'caido')    { req.destroy(); return; }
  if (simula === 'mudo')     { return; }   /* ni contesta ni cierra */
  if (simula === 'saturado') {
    return json(res, 429, { error: 'saturado', motivo: 'Vuelva a intentarlo.' });
  }

  let cuerpo;
  try { cuerpo = await leeCuerpo(req); }
  catch (e) { return json(res, 400, { error: 'json_invalido', motivo: 'El cuerpo no es JSON.' }); }

  if (!cuerpo.monto || Number(cuerpo.monto) <= 0) {
    return json(res, 422, { error: 'monto_invalido', motivo: 'El monto tiene que ser mayor que cero.' });
  }

  /* Los dos rechazos del negocio. No son averias: el cargo NO entro y
     reintentarlo da lo mismo, asi que se le dice a la persona. */
  if (simula === 'fondos') {
    return json(res, 402, { error: 'fondos_insuficientes',
                            motivo: 'La cuenta no tiene saldo suficiente.' });
  }
  if (simula === 'tarjeta-mala') {
    return json(res, 402, { error: 'medio_rechazado',
                            motivo: 'El banco emisor rechazo el medio de pago.' });
  }

  secuencia += 1;
  const referencia = 'BCO-2026-' + String(secuencia).padStart(6, '0');
  cobrados.set(llave, { referencia, monto: cuerpo.monto, orden: cuerpo.orden });
  json(res, 201, { estado: 'cobrado', referencia, monto: cuerpo.monto });
}

const servidor = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (req.method === 'POST' && url.pathname === '/cobros') return cobrar(req, res);
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
    console.log('Pasarela de mentira en http://127.0.0.1:' + p);
    console.log('Cabecera X-Simular: ' + [...CASOS].join(' | '));
  });
}

module.exports = { arranca, servidor };
