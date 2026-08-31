/* ═══════════════════════════════════════════════════════════════════════
   EL TRABAJADOR: QUIEN VACIA LA COLA
   ═══════════════════════════════════════════════════════════════════════
   Node 18 o mayor.

   LA PIEZA QUE FALTABA
   ─────────────────────────────────────────────────────────────────────
   El conector ya sabia que significa cada respuesta del organismo, y lo
   decia devolviendo una accion. Pero no habia nadie que la ejecutara: el
   LEEME de esta carpeta lo dice sin rodeos, "no esta enchufado al panel".
   Esto es el enchufe.

   Y con esto el sistema hace algo por primera vez sin que haya un
   navegador abierto. Hasta ahora todo pasaba en la pestana del
   inversionista: si la cerraba, se paraba.

   SIN BASE DE DATOS, IGUAL QUE EL CONECTOR
   ─────────────────────────────────────────────────────────────────────
   No importa 'pg' ni el cliente de Supabase. Recibe un DEPOSITO -un
   objeto con nueve metodos- y habla solo con el. Asi se prueba entero
   contra un deposito de mentira y contra el simulador, sin levantar
   nada, que es lo mismo que ya se hace un piso mas arriba y un piso mas
   abajo.

   Tambien recibe el RELOJ. Sin eso, probar "espera creciente" obligaria
   a esperar de verdad, y una prueba que tarda cinco minutos es una
   prueba que nadie corre.

   LAS TRES PIEZAS
   ─────────────────────────────────────────────────────────────────────
     supabase-cola.sql   guarda QUE hay que hacer y CUANDO
     conector-rif.js     dice QUE SIGNIFICA lo que contesto el organismo
     trabajador.js       hace algo con esa decision

   Cada una se prueba sola. Ninguna sabe como funcionan las otras dos.
   ═══════════════════════════════════════════════════════════════════════ */
'use strict';

const conectorRif   = require('./conector-rif');
const conectorSaren = require('./conector-saren');

/* Los conectores que hay, por el nombre que lleva tipos_tramite.conector.
   Anadir uno es anadir una linea aqui y un UPDATE en el catalogo; el
   trabajador no se entera de nada mas, y lo de arriba se comprobo al
   anadir el segundo: no hubo que tocar ni una linea de aqui abajo. */
const CONECTORES = {
  rif_empresa:  conectorRif,
  constitucion: conectorSaren
};

/* Un trabajo no se reintenta para siempre. Doce intentos con la espera
   creciente del conector son algo mas de media hora de organismo caido:
   pasado eso ya no es una averia pasajera y lo tiene que mirar alguien.
   Reintentar sin fin es como un expediente se queda anos en una cola sin
   que nadie se entere. */
const INTENTOS_MAX = 12;


/* ── atender UN trabajo ──────────────────────────────────────────────
   Devuelve que se hizo, para que quien llame pueda contarlo. Nunca
   lanza: un trabajo que revienta no puede llevarse por delante los que
   vienen detras, y lo que no se entiende se alerta, que para eso esta.

   deposito necesita:
     tramite(id)              -> la fila del tramite
     solicitante(tramiteId)   -> el perfil de quien lo pidio
     recaudos(tramiteId)      -> [{tipo, url, huella}]
     mueve(tramiteId, estado, nota)
     guardaExpediente(tramiteId, numero)
     guardaEmitido(tramiteId, documento)
     cierra(trabajoId)
     reprograma(trabajoId, esperaS, motivo)
     alerta(trabajoId, motivo)                                        */
async function atiende(trabajo, deposito, cfg, reloj) {
  reloj = reloj || Date;

  try {
    const tramite = await deposito.tramite(trabajo.tramite);
    if (!tramite) {
      /* El tramite ya no esta. No es una averia: pudo borrarse la
         cuenta. Se cierra el trabajo y no se alerta a nadie. */
      await deposito.cierra(trabajo.id);
      return { hizo: 'sin_tramite' };
    }

    /* Cual conector le toca lo dice el catalogo -tipos_tramite.conector-,
       y lo trae el deposito ya unido a la fila del tramite. cfg.conectorDe
       existe solo para las pruebas, que no tienen catalogo. */
    const cual = cfg.conectorDe ? cfg.conectorDe(tramite) : tramite.conector;
    const conector = CONECTORES[cual];
    if (!conector) {
      await deposito.alerta(trabajo.id,
        'No hay conector para el tipo "' + tramite.tipo + '".');
      return { hizo: 'alertado' };
    }

    let decision;
    if (trabajo.tarea === 'presentar') {
      const solicitante = await deposito.solicitante(trabajo.tramite);
      const recaudos    = await deposito.recaudos(trabajo.tramite);
      decision = await conector.presenta(tramite, recaudos, solicitante,
        Object.assign({}, cfg, { intento: trabajo.intentos + 1 }));
    } else if (trabajo.tarea === 'consultar') {
      if (!tramite.expediente_ente) {
        /* Se pide consultar algo que nunca se presento. Adivinar aqui
           -presentarlo, o darlo por perdido- es como se duplican
           expedientes. Que lo mire una persona. */
        await deposito.alerta(trabajo.id,
          'Hay que consultar un tramite que no tiene numero de expediente.');
        return { hizo: 'alertado' };
      }
      decision = await conector.consulta(tramite.expediente_ente,
        Object.assign({}, cfg, { intento: trabajo.intentos + 1 }));
    } else {
      await deposito.alerta(trabajo.id, 'Tarea desconocida: "' + trabajo.tarea + '".');
      return { hizo: 'alertado' };
    }

    return await aplica(decision, trabajo, tramite, deposito, conector, reloj);
  }
  catch (e) {
    /* Cualquier cosa que no supimos prever. Se alerta con el mensaje
       dentro en vez de reintentar: un fallo que no entendemos repetido
       doce veces sigue sin entenderse, y encima tarda media hora. */
    await deposito.alerta(trabajo.id,
      'El trabajador se rompio: ' + ((e && e.message) || e));
    return { hizo: 'alertado' };
  }
}


/* ── que se hace con cada una de las seis acciones ───────────────────
   La tabla es la del contrato, y esta escrita tambien en el LEEME de
   esta carpeta. Aqui no se inventa ninguna septima. */
async function aplica(decision, trabajo, tramite, deposito, conector, reloj) {
  const A = conector.ACCIONES;

  switch (decision.accion) {

    /* Llego. El tramite pasa a estar ante el ente y se guarda SU numero,
       que es por el que habra que preguntar despues. No hace falta
       encolar la consulta a mano: el trigger de supabase-cola.sql la
       pone al ver el cambio de estado, que es un sitio menos donde
       acordarse. */
    case A.PRESENTADO:
      await deposito.guardaExpediente(trabajo.tramite, decision.expediente_ente);
      await deposito.mueve(trabajo.tramite, 'ante_el_ente',
        decision.yaEstaba
          ? 'Ya constaba presentado en el organismo, con el mismo numero.'
          : 'Presentado ante el organismo.');
      await deposito.cierra(trabajo.id);
      return { hizo: 'presentado', expediente: decision.expediente_ente };

    /* Lo miraron y falta algo. Es una respuesta del negocio, no una
       averia: le llega al inversionista igual que si la escribiera un
       gestor, con su nota. */
    case A.DEVOLVER:
      await deposito.mueve(trabajo.tramite, 'devuelto', decision.nota);
      await deposito.cierra(trabajo.id);
      return { hizo: 'devuelto' };

    /* Aprobado, y con el documento. El conector ya se nego a dar por
       resuelto un tramite sin documento -seria decirle al inversionista
       que tiene un papel que no tiene- asi que si llega aqui, viene. */
    case A.RESUELTO:
      await deposito.guardaEmitido(trabajo.tramite, decision.documento);
      await deposito.mueve(trabajo.tramite, 'resuelto',
        decision.rif_asignado
          ? 'Resuelto por el organismo. RIF asignado: ' + decision.rif_asignado
          : 'Resuelto por el organismo.');
      await deposito.cierra(trabajo.id);
      return { hizo: 'resuelto' };

    /* Sigue en tramite alli. No se toca nada y se vuelve a preguntar,
       pero no dentro de quince segundos: un expediente en un organismo
       tarda dias, y preguntar cada minuto es hacerle un ataque de
       denegacion de servicio al ente con el que acabas de firmar un
       convenio. Una hora. */
    case A.ESPERAR:
      await deposito.reprograma(trabajo.id, 3600, null);
      return { hizo: 'esperando' };

    /* No se sabe si llego. Se vuelve a mandar con la MISMA llave, que es
       lo que hace seguro reintentar. La espera la calcula el conector. */
    case A.REINTENTAR:
      if (trabajo.intentos + 1 >= INTENTOS_MAX) {
        await deposito.alerta(trabajo.id,
          'Se agotaron los ' + INTENTOS_MAX + ' intentos. Ultimo: ' +
          (decision.motivo || 'sin motivo'));
        return { hizo: 'alertado' };
      }
      await deposito.reprograma(trabajo.id, decision.esperaS, decision.motivo);
      return { hizo: 'reintentar', esperaS: decision.esperaS };

    /* Problema NUESTRO: credenciales, o el organismo contestando algo
       que no esta en el contrato. El tramite del inversionista no se
       toca -no tiene la culpa y moverlo seria mentirle- y el trabajo
       espera a una persona. */
    case A.ALERTAR:
      await deposito.alerta(trabajo.id, decision.motivo || 'Sin motivo.');
      return { hizo: 'alertado' };

    default:
      await deposito.alerta(trabajo.id,
        'El conector devolvio una accion que no existe: "' + decision.accion + '".');
      return { hizo: 'alertado' };
  }
}


/* ── una vuelta entera ───────────────────────────────────────────────
   Coge lo pendiente cuya hora ya paso y lo atiende de uno en uno. De uno
   en uno y no en paralelo a proposito: son organismos, no un CDN, y
   veinte peticiones a la vez a un servicio publico venezolano es la
   forma mas rapida de que te corten el acceso.

   El tope es para que una cola muy larga no deje al proceso una hora sin
   volver a mirar si hay algo mas urgente. */
async function unaVuelta(deposito, cfg, reloj, tope) {
  const hechos = [];
  const trabajos = await deposito.pendientes(tope || 25);
  for (const t of trabajos) {
    hechos.push(await atiende(t, deposito, cfg, reloj));
  }
  return hechos;
}


module.exports = { atiende, unaVuelta, CONECTORES, INTENTOS_MAX };
