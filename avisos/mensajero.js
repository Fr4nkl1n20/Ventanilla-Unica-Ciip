/* ═══════════════════════════════════════════════════════════════════════
   EL MENSAJERO: QUIEN VACIA EL BUZON DE SALIDA
   ═══════════════════════════════════════════════════════════════════════
   Node 18 o mayor.

   supabase-avisos.sql APUNTA lo que hay que decir. Esto lo dice.

   SIN SMTP Y SIN BASE, IGUAL QUE EL TRABAJADOR
   ─────────────────────────────────────────────────────────────────────
   Recibe un DEPOSITO -de donde saca los avisos pendientes- y un
   TRANSPORTE -por donde salen-. No importa nodemailer ni el cliente de
   Supabase. Asi se prueba entero sin levantar un servidor de correo, que
   ademas es la unica forma de comprobar lo que de verdad importa: que a
   un brasileno le llegue en portugues y que un fallo del SMTP no borre el
   aviso.

   EL IDIOMA SALE DEL PAIS, COMO EN EL PANEL
   ─────────────────────────────────────────────────────────────────────
   Y con el mismo criterio, que esta en IDIOMA_PAIS. No se puede usar lo
   que eligio a mano en el navegador -eso vive en su localStorage y aqui
   no hay navegador-, asi que queda el pais, que lo escribio el sobre si
   mismo. Si su pais no habla ninguno de los seis, ingles.

   LO QUE NO HACE
   ─────────────────────────────────────────────────────────────────────
   No decide a quien avisar ni de que: eso ya viene decidido en la fila.
   No borra nada. Un aviso que no pudo salir se queda escrito con su
   error, porque un correo perdido en silencio es peor que uno que no
   sale: al menos el segundo se ve.
   ═══════════════════════════════════════════════════════════════════════ */
'use strict';

const { TEXTOS, IDIOMA_PAIS } = require('./textos');

/* Cinco intentos. Un SMTP no se cae media hora como un organismo: o va o
   la direccion esta mal, y reintentar doce veces a una direccion mal
   escrita no la arregla. */
const INTENTOS_MAX = 5;


/* ── de que pais eres a en que idioma se te escribe ──────────────────
   El expediente guarda el pais en espanol -"Venezuela"-, no su codigo.
   Intl.DisplayNames existe en Node desde la 14, asi que se resuelve
   igual que en el panel y no hay una segunda lista de nombres que
   mantener. */
let _codigos = null;
function codigoDePais(nombreEs) {
  if (!nombreEs) return '';
  if (!_codigos) {
    _codigos = {};
    let dn = null;
    try { dn = new Intl.DisplayNames(['es'], { type: 'region' }); }
    catch (e) { return ''; }
    for (const l of Object.keys(IDIOMA_PAIS)) {
      for (const c of IDIOMA_PAIS[l]) {
        let n = null;
        try { n = dn.of(c); } catch (e) { /* un codigo que Intl no conoce */ }
        if (n && n !== c) _codigos[llano(n)] = c;
      }
    }
  }
  return _codigos[llano(nombreEs)] || '';
}

/* minusculas y sin tildes: "España" y "espana" son el mismo pais.
   El rango va escrito con escapes y no con los caracteres de verdad:
   son marcas que se combinan con la letra de al lado, asi que pegadas en
   el codigo son invisibles y cualquier editor puede comerselas. */
function llano(x) {
  return String(x || '').normalize('NFD')
    .replace(new RegExp('[' + "\\u0300-\\u036f" + ']', 'g'), "").toLowerCase().trim();
}

function idiomaDe(pais) {
  const cod = codigoDePais(pais);
  if (!cod) return 'en';
  for (const l of Object.keys(IDIOMA_PAIS)) {
    if (IDIOMA_PAIS[l].indexOf(cod) >= 0) return l;
  }
  return 'en';
}


/* ── el correo, escrito ──────────────────────────────────────────────
   Devuelve {para, idioma, asunto, cuerpo}. Se saca aparte de mandarlo
   para poder probar lo que dice sin mandar nada. */
function redacta(aviso) {
  const idioma = idiomaDe(aviso.pais);
  const dicc = TEXTOS[idioma] || TEXTOS.en;

  /* La llave es el estado para un cambio, y el motivo para lo demas. */
  const llave = aviso.motivo === 'cambio_estado' ? aviso.a_estado : aviso.motivo;
  const t = dicc[llave];
  if (!t) return null;   /* nada que decir: mejor callar que inventar */

  const con = function (texto) {
    return String(texto)
      .replace('{tramite}', aviso.nota || '')
      .replace('{dato}', aviso.dato || '');
  };

  /* La nota del organismo va DENTRO y entrecomillada, no pegada al
     texto: es de ellos y esta en su idioma, no en el de la persona.
     Mezclarla con la frase nuestra da un parrafo mitad en un idioma y
     mitad en otro que no se entiende en ninguno de los dos. */
  const partes = [con(t.cuerpo)];
  if (aviso.motivo === 'cambio_estado' && aviso.a_estado === 'devuelto' && aviso.nota) {
    partes.push('');
    partes.push('  «' + aviso.nota + '»');
  }
  partes.push('');
  partes.push(con(t.pie));
  partes.push('');
  partes.push('— ' + dicc.firma);

  return {
    para: aviso.destinatario,
    idioma: idioma,
    asunto: con(t.asunto),
    cuerpo: partes.join('\n')
  };
}


/* ── mandar UNO ──────────────────────────────────────────────────────
   Nunca lanza, por lo mismo que el trabajador: un aviso que revienta no
   puede llevarse por delante los que vienen detras.

   deposito necesita: pendientes(tope), marcaEnviado(id),
                      marcaFallido(id, error), marcaImposible(id, error)
   transporte necesita: envia({para, asunto, cuerpo})                  */
async function manda(aviso, deposito, transporte) {
  let carta;
  try {
    carta = redacta(aviso);
  } catch (e) {
    await deposito.marcaImposible(aviso.id, 'No se pudo redactar: ' + ((e && e.message) || e));
    return { hizo: 'imposible' };
  }

  /* Un motivo del que no hay texto no se reintenta: mañana tampoco lo
     habra. Se marca y se sigue, para que no atasque la cola. */
  if (!carta) {
    await deposito.marcaImposible(aviso.id,
      'No hay texto para el motivo "' + aviso.motivo + '" / "' + aviso.a_estado + '".');
    return { hizo: 'imposible' };
  }

  try {
    await transporte.envia(carta);
    await deposito.marcaEnviado(aviso.id);
    return { hizo: 'enviado', idioma: carta.idioma };
  } catch (e) {
    const fallo = (e && e.message) || String(e);
    if (aviso.intentos + 1 >= INTENTOS_MAX) {
      await deposito.marcaImposible(aviso.id,
        'Se agotaron los ' + INTENTOS_MAX + ' intentos. Ultimo: ' + fallo);
      return { hizo: 'imposible' };
    }
    await deposito.marcaFallido(aviso.id, fallo);
    return { hizo: 'reintentar' };
  }
}


/* ── una vuelta ──────────────────────────────────────────────────────
   De uno en uno, como el trabajador. Un SMTP aguanta mas que un
   organismo, pero mandar cincuenta a la vez desde una direccion nueva es
   la forma mas rapida de acabar en la carpeta de correo no deseado. */
async function unaVuelta(deposito, transporte, tope) {
  const hechos = [];
  const avisos = await deposito.pendientes(tope || 50);
  for (const a of avisos) {
    hechos.push(await manda(a, deposito, transporte));
  }
  return hechos;
}


module.exports = { redacta, manda, unaVuelta, idiomaDe, INTENTOS_MAX };
