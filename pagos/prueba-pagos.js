/* ═══════════════════════════════════════════════════════════════════
   PRUEBAS DEL COBRADOR
   ═══════════════════════════════════════════════════════════════════
   Con un organismo, confundir "no llego" con "llego y lo rechazan"
   cuesta un expediente duplicado. Con un banco cuesta el dinero de una
   persona, dos veces. Asi que lo que mas se ensaya aqui es lo que pasa
   cuando NO se sabe si el cargo entro.

   No se toca ninguna red ni ningun banco: la pasarela de mentira se
   levanta y se apaga sola, en esta maquina.

       node pagos/prueba-pagos.js
   ═══════════════════════════════════════════════════════════════════ */
'use strict';
const { arranca } = require('./pasarela-mentira.js');
const C = require('./cobrador.js');

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
function unaOrden(extra) {
  n++;
  return Object.assign({
    id: 'orden-' + String(n).padStart(4, '0'),
    tramite: 'tramite-' + n,
    concepto: 'Tasa de inscripcion',
    monto: '120.00',
    moneda: 'USD',
    estado: 'pendiente'
  }, extra || {});
}

function libro() {
  const apuntes = [];
  return {
    apuntes,
    async marcaPagada(id, ref)   { apuntes.push({ que: 'pagada', id, ref }); },
    async marcaRechazada(id, m)  { apuntes.push({ que: 'rechazada', id, m }); },
    async apunta(id, m)          { apuntes.push({ que: 'apunta', id, m }); }
  };
}
function apunte(l, que) { return l.apuntes.find(function (a) { return a.que === que; }) || null; }
function hubo(l, que) { return apunte(l, que) !== null; }


(async function () {
  const puerto = await arranca(0);
  const base = 'http://127.0.0.1:' + puerto;
  const cfg = { base, token: 'de-mentira', msLimite: 4000 };
  const forzar = function (caso) {
    return Object.assign({}, cfg, { cabeceras: { 'X-Simular': caso } });
  };

  console.log('\n  PRUEBAS DEL COBRADOR');
  console.log('  --------------------\n');
  console.log('  Pasarela de mentira en ' + base + '\n');

  /* ═══ 1 · COBRAR ══════════════════════════════════════════════════ */
  {
    const o = unaOrden();
    const d = await C.cobra(o, cfg);
    igual('cobro: sale', d.respuesta, C.RESPUESTAS.COBRADO);
    ok('cobro: y vuelve con la referencia del banco',
       /^BCO-2026-\d{6}$/.test(d.referencia || ''), d.referencia, 'BCO-2026-000001');

    const l = libro();
    const r = await C.aplica(d, o, l);
    igual('cobro: la orden queda pagada', r.hizo, 'pagada');
    igual('cobro: con la referencia guardada', apunte(l, 'pagada').ref, d.referencia);
  }

  /* ═══ 2 · LO QUE MAS IMPORTA: NO COBRAR DOS VECES ═════════════════ */
  {
    const o = unaOrden();
    const primero = await C.cobra(o, cfg);
    const otraVez = await C.cobra(o, Object.assign({}, cfg, { intento: 2 }));

    igual('reintento: no se cobra dos veces', otraVez.respuesta, C.RESPUESTAS.COBRADO);
    igual('reintento: y la referencia es la MISMA', otraVez.referencia, primero.referencia);
    ok('reintento: el cobrador sabe que ya estaba',
       otraVez.yaEstaba === true, String(otraVez.yaEstaba), 'true');
  }

  {
    /* Dos ordenes distintas del mismo tramite SI son dos cobros: una tasa
       y una reposicion, por ejemplo. La llave es la orden, no el
       tramite; si fuera el tramite, el segundo devolveria el primero y
       nadie cobraria. */
    const a = unaOrden({ tramite: 'el-mismo' });
    const b = unaOrden({ tramite: 'el-mismo' });
    const da = await C.cobra(a, cfg);
    const db = await C.cobra(b, cfg);
    ok('la llave es la orden, no el tramite: dos ordenes son dos cobros',
       da.referencia !== db.referencia, da.referencia + ' / ' + db.referencia, 'distintas');
  }

  /* ═══ 3 · EL BANCO DICE QUE NO ════════════════════════════════════ */
  {
    const o = unaOrden();
    const d = await C.cobra(o, forzar('fondos'));
    igual('sin fondos: se rechaza, no se reintenta', d.respuesta, C.RESPUESTAS.RECHAZADO);
    ok('sin fondos: con un motivo que se pueda leer',
       /saldo/i.test(d.motivo || ''), d.motivo, 'habla del saldo');

    const l = libro();
    const r = await C.aplica(d, o, l);
    igual('sin fondos: queda anotado en la orden', r.hizo, 'rechazada');
    /* Y la orden NO se anula: anularla obligaria a rehacer el tramite
       entero por una tarjeta caducada. */
    ok('sin fondos: la orden sigue viva para volver a intentarlo',
       !hubo(l, 'pagada'), 'la dio por pagada', 'sigue pendiente');
  }

  {
    const o = unaOrden();
    const d = await C.cobra(o, forzar('tarjeta-mala'));
    igual('medio rechazado: tambien se rechaza', d.respuesta, C.RESPUESTAS.RECHAZADO);
    igual('medio rechazado: y se dice cual fue', d.codigo, 'medio_rechazado');
  }

  /* ═══ 4 · NO SE SABE SI ENTRO ═════════════════════════════════════ */
  {
    const o = unaOrden();
    const d = await C.cobra(o, forzar('saturado'));
    igual('saturado: se reintenta', d.respuesta, C.RESPUESTAS.REINTENTAR);
    ok('saturado: con una espera', d.esperaS > 0, String(d.esperaS), 'mas de cero');
  }

  {
    const o = unaOrden();
    const d = await C.cobra(o, forzar('caido'));
    igual('caido: se reintenta', d.respuesta, C.RESPUESTAS.REINTENTAR);
    ok('caido: y NO se da por cobrado, porque no se sabe',
       d.respuesta !== C.RESPUESTAS.COBRADO, d.respuesta, 'reintentar');
  }

  {
    /* El peor: ni contesta ni cierra. Sin plazo, el cobrador se queda
       colgado para siempre y la orden nunca se resuelve. */
    const o = unaOrden();
    const d = await C.cobra(o, Object.assign({}, forzar('mudo'), { msLimite: 700 }));
    igual('mudo: se corta el plazo y se reintenta', d.respuesta, C.RESPUESTAS.REINTENTAR);
    ok('mudo: y no queda dicho que se cobro',
       d.respuesta !== C.RESPUESTAS.COBRADO, d.respuesta, 'reintentar');
  }

  /* Y el reintento despues de un mudo NO cobra otra vez: la llave sigue
     siendo la misma. Este es el caso que justifica todo el diseno. */
  {
    const o = unaOrden();
    await C.cobra(o, Object.assign({}, forzar('mudo'), { msLimite: 700 }));
    const luego = await C.cobra(o, Object.assign({}, cfg, { intento: 2 }));
    igual('mudo: al reintentar se cobra UNA sola vez', luego.respuesta, C.RESPUESTAS.COBRADO);
    ok('mudo: y con una referencia, no dos cargos',
       !!luego.referencia, luego.referencia, 'una referencia');
  }

  {
    ok('reintentos: la espera crece', C.esperaSiguiente(2) > C.esperaSiguiente(1),
       C.esperaSiguiente(1) + ' -> ' + C.esperaSiguiente(2), 'creciente');
    igual('reintentos: y no pasa de cinco minutos', C.esperaSiguiente(20), 300);
  }

  /* ═══ 5 · PROBLEMA NUESTRO ════════════════════════════════════════ */
  {
    const o = unaOrden();
    const d = await C.cobra(o, forzar('sin-credencial'));
    igual('credenciales: es problema del CIIP, no del pagador',
          d.respuesta, C.RESPUESTAS.ALERTAR);

    const l = libro();
    await C.aplica(d, o, l);
    /* Lo que importa: al pagador no se le dice que su pago fue
       rechazado. No lo fue: fue nuestra credencial. */
    ok('credenciales: y la orden NO se marca rechazada',
       !hubo(l, 'rechazada'), 'la marco rechazada', 'sin tocar');
  }

  {
    const o = unaOrden({ monto: '0.00' });
    const d = await C.cobra(o, cfg);
    igual('monto invalido: es error nuestro, no del pagador', d.respuesta, C.RESPUESTAS.ALERTAR);
    const l = libro();
    const r = await C.aplica(d, o, l);
    igual('monto invalido: se alerta', r.hizo, 'alertado');
    ok('monto invalido: y la orden no se toca',
       !hubo(l, 'pagada') && !hubo(l, 'rechazada'), 'la toco', 'sin tocar');
  }

  /* ═══ 6 · UNA ORDEN QUE YA NO TOCA ════════════════════════════════ */
  {
    const o = unaOrden({ estado: 'pagada' });
    const d = await C.cobra(o, cfg);
    igual('una orden ya pagada no se vuelve a cobrar', d.respuesta, C.RESPUESTAS.NADA);
  }
  {
    const o = unaOrden({ estado: 'anulada' });
    const d = await C.cobra(o, cfg);
    igual('ni una anulada', d.respuesta, C.RESPUESTAS.NADA);
  }

  {
    /* Un deposito que revienta no puede propagar. */
    const o = unaOrden();
    const l = libro();
    l.marcaPagada = async function () { throw new Error('la base no contesta'); };
    const r = await C.cobraYApunta(o, l, cfg);
    igual('si el deposito revienta, se alerta y no se propaga', r.hizo, 'alertado');
  }

  console.log('');
  console.log('  ' + pasan + ' de ' + (pasan + fallan) + ' pruebas superadas');
  console.log('');
  console.log('  Esto prueba el cobrador contra el contrato, no contra un banco.');
  console.log('  Que la orden se emita sola y frene la presentacion lo prueba');
  console.log('  PROBAR-SQL.bat. Cobrar de verdad necesita convenio bancario.');
  console.log('');
  process.exit(fallan ? 1 : 0);
})();
