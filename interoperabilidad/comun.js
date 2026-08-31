/* ═══════════════════════════════════════════════════════════════════════
   LO QUE TODOS LOS CONECTORES COMPARTEN
   ═══════════════════════════════════════════════════════════════════════
   Esto salio de escribir el SEGUNDO conector, no de imaginarlo. Con uno
   solo no habia forma de saber que parte era del SENIAT y cual era de
   "hablar con un organismo": adivinarlo antes de tiempo habria dejado una
   abstraccion a medida de un solo caso, que es peor que la copia.

   Lo que resulto ser comun son tres cosas, y ninguna tiene que ver con el
   tramite:

     pide()             pedir por HTTP sabiendo distinguir "contesto que
                        no" de "no contesto"
     esperaSiguiente()  cuanto esperar antes de volver a intentarlo
     fallo()            los codigos que significan lo mismo viniendo de
                        cualquier organismo: 401 y 403 son cosa nuestra,
                        429 y 5xx se reintentan, el resto es contrato
                        incumplido

   Lo que NO esta aqui, y no puede estarlo: que campos lleva un
   expediente, que significa un 422 en ese tramite concreto, y en que
   estados de los suyos cae cada respuesta. Eso es de cada ente y de cada
   tramite, y es justo lo caro de acordar.
   ═══════════════════════════════════════════════════════════════════════ */
'use strict';

/* Las cinco cosas que pueden pasar. Son las de la tabla del contrato, y
   no hay una sexta a proposito: cada respuesta del ente cae en una. */
const ACCIONES = {
  PRESENTADO: 'presentado',   /* -> el tramite pasa a 'ante_el_ente'   */
  DEVOLVER:   'devolver',     /* -> pasa a 'devuelto', con su nota     */
  RESUELTO:   'resuelto',     /* -> pasa a 'resuelto'                  */
  ESPERAR:    'esperar',      /* -> no se toca; se vuelve a preguntar  */
  REINTENTAR: 'reintentar',   /* -> no se toca; se manda otra vez      */
  ALERTAR:    'alertar'       /* -> no se toca; es problema NUESTRO    */
};


async function pide(url, opciones, msLimite) {
  const corta = AbortSignal.timeout(msLimite || 20000);
  try {
    const r = await fetch(url, Object.assign({ signal: corta }, opciones));
    let cuerpo = null;
    try { cuerpo = await r.json(); } catch (e) { cuerpo = null; }
    return { codigo: r.status, cuerpo: cuerpo };
  } catch (e) {
    /* Se agoto el plazo, o la red no llego. NO se sabe si el expediente
       entro: es exactamente el caso que salva la Idempotency-Key. */
    return { codigo: 0, cuerpo: null, fallo: (e && e.message) || String(e) };
  }
}


/* Espera creciente, y con un techo: sin techo, tras un fin de semana
   caido el primer reintento seria dentro de tres dias. */
function esperaSiguiente(intento) {
  return Math.min(300, Math.pow(2, Math.max(1, intento)) * 15);
}


/* ── los codigos que significan lo mismo venga de donde venga ────────
   Devuelve una accion, o null si ese codigo lo tiene que interpretar el
   conector porque en su tramite significa algo concreto.

   Que sea null y no una accion por defecto es a proposito: un conector
   que se olvide de mirar su 422 tiene que quedarse sin respuesta y
   caerse, no seguir adelante con una suposicion. */
function fallo(r, cfg) {
  /* Nuestras credenciales. El tramite del inversionista no tiene la
     culpa y no se toca: esto lo arregla el CIIP. */
  if (r.codigo === 401 || r.codigo === 403) {
    return { accion: ACCIONES.ALERTAR,
             motivo: 'Credenciales rechazadas por el organismo (' + r.codigo + ').' };
  }

  /* Saturado, caido o mudo: no se sabe si llego. Se vuelve a intentar
     con la misma llave, esperando cada vez un poco mas. */
  if (r.codigo === 0 || r.codigo === 429 || r.codigo >= 500) {
    return {
      accion: ACCIONES.REINTENTAR,
      motivo: r.codigo === 0 ? ('Sin respuesta: ' + r.fallo)
                             : ('El organismo contesto ' + r.codigo + '.'),
      esperaS: esperaSiguiente((cfg && cfg.intento) || 1)
    };
  }

  return null;
}


/* Lo que no encaja en ningun sitio. Adivinar aqui es como se corrompen
   los datos: mejor que lo mire una persona. */
function fueraDelContrato(r, donde) {
  return { accion: ACCIONES.ALERTAR,
           motivo: 'Respuesta fuera del contrato' +
                   (donde ? ' al ' + donde : '') + ': ' + r.codigo + '.' };
}


module.exports = { ACCIONES, pide, esperaSiguiente, fallo, fueraDelContrato };
