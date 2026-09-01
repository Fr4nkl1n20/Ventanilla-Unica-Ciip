/* ═══════════════════════════════════════════════════════════════════
   PRUEBAS DEL BARRENDERO
   ═══════════════════════════════════════════════════════════════════
   Un barrendero se equivoca de cuatro maneras, y las cuatro estan aqui:

     - deja el archivo y marca que lo borro
     - borra el archivo y no lo marca, y lo intenta para siempre
     - se para en el primero que da error y no barre los de detras
     - manda a borrar una ruta vacia

   La primera es la que no se ve nunca: la lista se queda limpia, el
   cubo lleno, y la unica señal es la factura.

   No se toca ningun cubo de verdad: el cubo es de mentira y guarda lo
   que se le pidio borrar, que es la unica forma de leer lo que se
   habria borrado.

       node avisos/prueba-barrendero.js
   ═══════════════════════════════════════════════════════════════════ */
'use strict';
const B = require('./barrendero.js');

let pasan = 0, fallan = 0;
function ok(que, cierto, obtuvo, esperaba) {
  if (cierto) { pasan++; console.log('  PASA  ' + que); return; }
  fallan++;
  console.log('  FALLA ' + que);
  console.log('          esperaba : ' + esperaba);
  console.log('          obtuvo   : ' + obtuvo);
}
function igual(que, a, b) { ok(que, a === b, String(a), String(b)); }


/* ── el deposito y el cubo de mentira ──
   El deposito guarda lo que se le marco, en vez de escribirlo en una
   base. El cubo guarda lo que se le mando borrar, en vez de borrarlo. */
function lista(filas) {
  const d = {
    marcados: [],
    fallidos: [],
    imposibles: [],
    borrados: [],
    pendientes: async function () { return filas; },
    marcaBarrido:   async function (id) { d.marcados.push(id); },
    marcaFallido:   async function (id, e) { d.fallidos.push({ id: id, error: e }); },
    marcaImposible: async function (id, e) { d.imposibles.push({ id: id, error: e }); }
  };
  d.cubo = {
    borra: async function (cubo, ruta) { d.borrados.push(cubo + '/' + ruta); }
  };
  return d;
}
function unHuerfano(extra) {
  return Object.assign({
    id: 'h-1', cubo: 'recaudos',
    ruta: '0000-1111/cedula.pdf', intentos: 0
  }, extra || {});
}


(async function () {
  {
    /* Lo normal: se pide borrar y se marca. Las dos cosas, y en ese
       orden: marcar sin haber borrado es la mentira que se busca. */
    const d = lista([unHuerfano()]);
    const hechos = await B.unaVuelta(d, d.cubo);
    igual('se le pide al cubo que borre', d.borrados[0], 'recaudos/0000-1111/cedula.pdf');
    igual('y queda marcado como barrido', d.marcados[0], 'h-1');
    igual('sin fallidos', d.fallidos.length, 0);
    igual('y lo cuenta', hechos[0].hizo, 'barrido');
  }

  {
    /* Lo que NO puede pasar: marcar como barrido algo que el cubo no
       acepto borrar. Si esto se rompe, la lista queda limpia y el cubo
       lleno, que es la averia que no se ve. */
    const d = lista([unHuerfano()]);
    d.cubo.borra = async function () { throw new Error('el cubo dijo que no'); };
    await B.unaVuelta(d, d.cubo);
    igual('un borrado que fallo NO se marca como hecho', d.marcados.length, 0);
    igual('se apunta para reintentar', d.fallidos.length, 1);
    ok('con el motivo escrito', /dijo que no/.test(d.fallidos[0].error),
       d.fallidos[0].error, 'el cubo dijo que no');
  }

  {
    /* Un archivo que ya no esta es el final feliz tardio, no un error:
       pasa cuando la vuelta anterior borro y no llego a marcar. Si se
       tratara como fallo, ese apunte se reintentaria hasta agotarse y
       acabaria en la lista de imposibles, en rojo, sin nada que
       arreglar. */
    const d = lista([unHuerfano()]);
    d.cubo.borra = async function () { const e = new Error('Object not found'); e.estado = 404; throw e; };
    const hechos = await B.unaVuelta(d, d.cubo);
    igual('un archivo que ya no estaba se da por barrido', d.marcados[0], 'h-1');
    igual('y no como fallo', d.fallidos.length + d.imposibles.length, 0);
    igual('pero se distingue de haberlo borrado ahora', hechos[0].hizo, 'ya-no-estaba');
  }

  {
    /* Y por el numero solo, sin texto: el cliente de Supabase envuelve
       el error y no siempre trae el mensaje. */
    const d = lista([unHuerfano()]);
    d.cubo.borra = async function () { const e = new Error('vacio'); e.status = 404; throw e; };
    await B.unaVuelta(d, d.cubo);
    igual('el 404 se reconoce aunque el texto no diga nada', d.marcados.length, 1);
  }

  {
    /* Al tercer intento se deja de insistir. Una ruta mal escrita no se
       arregla insistiendo, y un apunte que se reintenta cada noche para
       siempre tapa los que si tienen arreglo. */
    const d = lista([unHuerfano({ intentos: B.INTENTOS_MAX - 1 })]);
    d.cubo.borra = async function () { throw new Error('sigue sin poder'); };
    await B.unaVuelta(d, d.cubo);
    igual('agotados los intentos, se deja de insistir', d.imposibles.length, 1);
    igual('y no se reintenta mas', d.fallidos.length, 0);
    ok('quedando dicho cuantas veces se probo',
       d.imposibles[0].error.indexOf(String(B.INTENTOS_MAX)) >= 0,
       d.imposibles[0].error, 'los ' + B.INTENTOS_MAX + ' intentos');
  }

  {
    /* Una ruta vacia no se manda al cubo. Segun como este montado, un
       borrado sin nombre puede entenderse como la carpeta entera. */
    const d = lista([unHuerfano({ ruta: '' })]);
    await B.unaVuelta(d, d.cubo);
    igual('una ruta vacia no llega al cubo', d.borrados.length, 0);
    igual('se aparta para que la mire alguien', d.imposibles.length, 1);
  }

  {
    /* Una vuelta entera, y uno malo no se lleva a los demas. */
    const d = lista([unHuerfano({ id: 'a', ruta: 'x/1.pdf' }),
                     unHuerfano({ id: 'b', ruta: 'x/2.pdf' }),
                     unHuerfano({ id: 'c', ruta: 'x/3.pdf' })]);
    const original = d.cubo.borra;
    d.cubo.borra = async function (cubo, ruta) {
      if (ruta === 'x/2.pdf') throw new Error('ese no');
      return original(cubo, ruta);
    };
    const hechos = await B.unaVuelta(d, d.cubo);
    igual('una vuelta atiende todos los apuntes', hechos.length, 3);
    igual('y uno que falla no impide los otros dos', d.marcados.length, 2);
    igual('el que fallo queda apuntado, no perdido', d.fallidos[0].id, 'b');
  }

  {
    /* El cubo se toma del apunte, no se supone. El dia que haya un
       segundo cubo, suponer 'recaudos' borraria del que no es. */
    const d = lista([unHuerfano({ cubo: 'otro-cubo' })]);
    await B.unaVuelta(d, d.cubo);
    ok('borra del cubo que dice el apunte', d.borrados[0].indexOf('otro-cubo/') === 0,
       d.borrados[0], 'otro-cubo/...');
  }

  console.log('');
  console.log('  ' + pasan + ' de ' + (pasan + fallan) + ' pruebas superadas');
  console.log('');
  console.log('  Esto prueba que no se marca lo que no se borro y que un');
  console.log('  fallo no para la vuelta. Que el archivo quede apuntado al');
  console.log('  borrar la ficha lo prueba PROBAR-SQL.bat; que la API de');
  console.log('  Storage se lleve de verdad los bytes, ningun arnes: eso');
  console.log('  necesita un cubo de verdad.');
  console.log('');
  process.exit(fallan ? 1 : 0);
})();
