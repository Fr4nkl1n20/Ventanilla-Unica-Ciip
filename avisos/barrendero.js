/* ═══════════════════════════════════════════════════════════════════════
   EL BARRENDERO: QUIEN SE LLEVA LOS ARCHIVOS SIN FICHA
   ═══════════════════════════════════════════════════════════════════════
   Node 18 o mayor.

   supabase-tramites.sql APUNTA en archivos_huerfanos el archivo que se
   quedo sin ficha. Esto se lo lleva.

   POR QUE HACE FALTA ALGUIEN DE FUERA
   ─────────────────────────────────────────────────────────────────────
   Porque desde SQL no se puede. Un `delete from storage.objects` borra el
   INDICE del cubo y deja los bytes en el almacen de detras, donde ya no
   los nombra nadie; y en un Supabase de verdad ni eso, porque esa tabla
   es de otro dueño y el trigger se va en silencio sin tocar nada.

   La API de Storage si se lleva las dos cosas. Y para llamarla hace falta
   la clave de servidor, que no puede estar en el panel.

   MISMO TRATO QUE EL MENSAJERO
   ─────────────────────────────────────────────────────────────────────
   Recibe un DEPOSITO -de donde saca lo apuntado y donde marca lo hecho- y
   un CUBO -a quien le pide que borre-. Ni cliente de Supabase ni fetch
   aqui dentro: asi se prueba entero sin tocar un proyecto de verdad, que
   es la unica forma de comprobar lo que importa, que es lo que pasa
   cuando la API contesta que no.

   LO QUE NO HACE
   ─────────────────────────────────────────────────────────────────────
   No decide que sobra: eso ya lo decidio la base cuando se borro la
   ficha. Y no borra el apunte: lo marca. Una lista de lo que se llevo,
   con su fecha, es lo unico que despues permite responder «ese recaudo
   se borro tal dia» sin tener que creerselo.
   ═══════════════════════════════════════════════════════════════════════ */
'use strict';

/* Tres intentos, no cinco. Un cubo no se cae como un organismo: o
   contesta o la ruta esta mal, y una ruta mal escrita no se arregla
   insistiendo. */
const INTENTOS_MAX = 3;


/* ── un archivo que ya no esta no es un fallo ────────────────────────
   Es el final feliz tardio. Pasa siempre que el barrendero se corta a la
   mitad -borro el archivo y no llego a marcarlo- y a la vuelta siguiente
   lo encuentra otra vez. Tratarlo como error dejaria la lista llena de
   rojos que no significan nada, y con ellos tapados los que si.

   La API de Storage contesta 404, o «not found» en el texto. Se mira lo
   que se pueda de las dos cosas, porque el cliente de Supabase envuelve
   el error y no siempre trae el numero. */
function noEstaba(fallo) {
  if (!fallo) return false;
  if (fallo.estado === 404 || fallo.status === 404) return true;
  const texto = ((fallo && fallo.message) || String(fallo)).toLowerCase();
  return texto.includes('not found') || texto.includes('no existe');
}


/* ── barrer UNO ──────────────────────────────────────────────────────
   Nunca lanza, por lo mismo que el mensajero: un archivo que revienta no
   puede llevarse por delante los que vienen detras.

   deposito necesita: pendientes(tope), marcaBarrido(id),
                      marcaFallido(id, error), marcaImposible(id, error)
   cubo     necesita: borra(cubo, ruta)                                */
async function barre(huerfano, deposito, cubo) {
  /* Una ruta vacia no se manda a la API. Segun el cubo, un DELETE sin
     nombre puede entenderse como «la carpeta entera», y eso no se
     arriesga: se marca imposible y que lo mire una persona. */
  if (!huerfano.ruta) {
    await deposito.marcaImposible(huerfano.id, 'El apunte no trae ruta.');
    return { hizo: 'imposible' };
  }

  try {
    await cubo.borra(huerfano.cubo || 'recaudos', huerfano.ruta);
    await deposito.marcaBarrido(huerfano.id);
    return { hizo: 'barrido', ruta: huerfano.ruta };
  } catch (e) {
    if (noEstaba(e)) {
      await deposito.marcaBarrido(huerfano.id);
      return { hizo: 'ya-no-estaba', ruta: huerfano.ruta };
    }
    const fallo = (e && e.message) || String(e);
    if ((huerfano.intentos || 0) + 1 >= INTENTOS_MAX) {
      await deposito.marcaImposible(huerfano.id,
        'Se agotaron los ' + INTENTOS_MAX + ' intentos. Ultimo: ' + fallo);
      return { hizo: 'imposible' };
    }
    await deposito.marcaFallido(huerfano.id, fallo);
    return { hizo: 'reintentar' };
  }
}


/* ── una vuelta ──────────────────────────────────────────────────────
   De uno en uno. Aqui no es por educacion con el servidor de enfrente
   -un cubo aguanta de sobra- sino porque un fallo a mitad de una tanda
   deja sin saber cuales se hicieron; asi cada uno se marca antes de
   empezar el siguiente. */
async function unaVuelta(deposito, cubo, tope) {
  const hechos = [];
  const lista = await deposito.pendientes(tope || 50);
  for (const h of lista) {
    hechos.push(await barre(h, deposito, cubo));
  }
  return hechos;
}


module.exports = { barre, unaVuelta, noEstaba, INTENTOS_MAX };
