/* ═══════════════════════════════════════════════════════════════════════
   EL COBRADOR
   ═══════════════════════════════════════════════════════════════════════
   Node 18 o mayor.

   Misma forma que conector-rif.js, y por la misma razon: lo caro no es
   mandar el cargo -son veinte lineas- sino decidir que hacer con cada
   respuesta del banco. Eso se puede acordar, escribir y probar hoy;
   cuando haya convenio, lo que cambia es la direccion y las
   credenciales.

   LO QUE HACE FALTA ENTENDER
   ─────────────────────────────────────────────────────────────────────
   Con un organismo, confundir "no llego" con "llego y lo rechazan"
   cuesta un expediente duplicado. Con un banco cuesta el dinero de una
   persona, dos veces. Por eso el id de la ORDEN es la llave de
   idempotencia y se manda siempre: si la red se cae despues de que el
   banco cobre y antes de contestarnos, reintentar con la misma llave
   devuelve el mismo cargo en vez de hacer otro.

   CINCO RESPUESTAS, NO SEIS
   ─────────────────────────────────────────────────────────────────────
     cobrado      la orden queda pagada, con su referencia
     rechazado    el banco dijo que no. NO se reintenta: reintentar un
                  "sin fondos" es cobrarle a alguien en cuanto ingrese
                  algo, sin que lo haya pedido
     reintentar   no se sabe si entro. Misma llave, se vuelve
     alertar      problema NUESTRO: credenciales, o contrato incumplido
     nada         la orden ya no estaba pendiente. No es un error
   ═══════════════════════════════════════════════════════════════════════ */
'use strict';

const RESPUESTAS = {
  COBRADO:    'cobrado',
  RECHAZADO:  'rechazado',
  REINTENTAR: 'reintentar',
  ALERTAR:    'alertar',
  NADA:       'nada'
};

/* La misma que el conector, y con el mismo techo: sin el, tras un fin de
   semana caido el primer reintento seria dentro de tres dias. */
function esperaSiguiente(intento) {
  return Math.min(300, Math.pow(2, Math.max(1, intento)) * 15);
}

async function pide(url, opciones, msLimite) {
  const corta = new AbortController();
  const reloj = setTimeout(() => corta.abort(), msLimite || 8000);
  try {
    const r = await fetch(url, Object.assign({}, opciones, { signal: corta.signal }));
    let cuerpo = null;
    const txt = await r.text();
    try { cuerpo = txt ? JSON.parse(txt) : null; } catch (e) { cuerpo = null; }
    return { codigo: r.status, cuerpo };
  } catch (e) {
    /* codigo 0 = no hubo respuesta. NO es lo mismo que un 402: alli el
       banco dijo que no, aqui no se sabe nada. */
    return { codigo: 0, fallo: (e && e.name === 'AbortError') ? 'sin respuesta a tiempo' : String(e && e.message || e) };
  }
}


/* ── cobrar una orden ────────────────────────────────────────────── */
async function cobra(orden, cfg) {
  if (orden.estado !== 'pendiente') {
    return { respuesta: RESPUESTAS.NADA, motivo: 'La orden esta "' + orden.estado + '".' };
  }

  const r = await pide(cfg.base + '/cobros', {
    method: 'POST',
    headers: Object.assign({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + cfg.token,
      /* El id de la ORDEN, no el del tramite: un tramite puede llegar a
         tener dos cobros -una tasa y una reposicion- y compartir llave
         haria que el segundo devolviera el primero y nadie cobrara. */
      'Idempotency-Key': orden.id
    }, cfg.cabeceras || {}),
    body: JSON.stringify({
      orden: orden.id,
      monto: String(orden.monto),
      moneda: orden.moneda,
      concepto: orden.concepto
    })
  }, cfg.msLimite);

  const c = r.cuerpo || {};

  /* 201 y 409 acaban igual, como el 202 y el 409 del SENIAT: el 409 dice
     "esto ya se cobro", que es la respuesta correcta a un reintento. */
  if (r.codigo === 201 || r.codigo === 409) {
    if (!c.referencia) {
      return { respuesta: RESPUESTAS.ALERTAR,
               motivo: 'El banco cobro pero no devolvio la referencia.' };
    }
    return {
      respuesta: RESPUESTAS.COBRADO,
      referencia: c.referencia,
      yaEstaba: r.codigo === 409
    };
  }

  /* El banco dijo que no, y lo dijo mirando. Se le cuenta a la persona y
     no se reintenta: un "sin fondos" reintentado solo es un cargo que
     entra el dia que le llegue el sueldo, sin que lo haya pedido. */
  if (r.codigo === 402) {
    return {
      respuesta: RESPUESTAS.RECHAZADO,
      motivo: c.motivo || 'El banco rechazo el pago sin indicar el motivo.',
      codigo: c.error || null
    };
  }

  /* Un monto que el banco no acepta es un error nuestro al emitir la
     orden, no del pagador. */
  if (r.codigo === 422) {
    return { respuesta: RESPUESTAS.ALERTAR,
             motivo: 'La pasarela no acepto la orden: ' + (c.motivo || r.codigo) };
  }

  if (r.codigo === 401 || r.codigo === 403) {
    return { respuesta: RESPUESTAS.ALERTAR,
             motivo: 'Credenciales rechazadas por la pasarela (' + r.codigo + ').' };
  }

  if (r.codigo === 0 || r.codigo === 429 || r.codigo >= 500) {
    return {
      respuesta: RESPUESTAS.REINTENTAR,
      motivo: r.codigo === 0 ? ('Sin respuesta: ' + r.fallo) : ('La pasarela contesto ' + r.codigo + '.'),
      esperaS: esperaSiguiente(cfg.intento || 1)
    };
  }

  return { respuesta: RESPUESTAS.ALERTAR,
           motivo: 'Respuesta fuera del contrato: ' + r.codigo + '.' };
}


/* ── y escribirlo donde toca ─────────────────────────────────────────
   Aparte de cobrar, igual que el trabajador esta aparte del conector.
   Nunca lanza.

   deposito necesita: marcaPagada(ordenId, referencia)
                      marcaRechazada(ordenId, motivo)
                      apunta(ordenId, motivo)                          */
async function aplica(decision, orden, deposito) {
  switch (decision.respuesta) {
    case RESPUESTAS.COBRADO:
      await deposito.marcaPagada(orden.id, decision.referencia);
      return { hizo: 'pagada', referencia: decision.referencia };

    case RESPUESTAS.RECHAZADO:
      /* La orden NO se anula: sigue pendiente y se puede volver a
         intentar cuando la persona arregle su medio de pago. Anularla
         obligaria a rehacer el tramite entero por una tarjeta caducada. */
      await deposito.marcaRechazada(orden.id, decision.motivo);
      return { hizo: 'rechazada', motivo: decision.motivo };

    case RESPUESTAS.REINTENTAR:
      await deposito.apunta(orden.id, decision.motivo);
      return { hizo: 'reintentar', esperaS: decision.esperaS };

    case RESPUESTAS.NADA:
      return { hizo: 'nada' };

    default:
      await deposito.apunta(orden.id, decision.motivo || 'Sin motivo.');
      return { hizo: 'alertado', motivo: decision.motivo };
  }
}

async function cobraYApunta(orden, deposito, cfg) {
  try {
    const decision = await cobra(orden, cfg);
    return await aplica(decision, orden, deposito);
  } catch (e) {
    await deposito.apunta(orden.id, 'El cobrador se rompio: ' + ((e && e.message) || e));
    return { hizo: 'alertado' };
  }
}


module.exports = { RESPUESTAS, cobra, aplica, cobraYApunta, esperaSiguiente };
