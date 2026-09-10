/* ═══════════════════════════════════════════════════════════════════════
   EL INTERMEDIARIO DEL ASISTENTE, PROBADO SIN GASTAR UN CÉNTIMO
   ═══════════════════════════════════════════════════════════════════════

   api/asistente.js es lo único del proyecto que corre en un servidor, y por
   eso es lo único que no se puede mirar abriendo una página y pulsando. Lo
   que hace mal no se ve: se ve una respuesta que no llega, o una factura a
   fin de mes.

   Aquí se le pone delante un Anthropic de mentira y un Supabase de mentira,
   y se comprueba lo que decide. No sale ni un paquete a la red y no se toca
   ninguna clave de verdad.

   LO QUE SE VIGILA, Y POR QUÉ CADA COSA:

   1. Sin clave, contesta 'sin-clave' y no molesta a nadie más. De eso
      depende que el panel de hoy siga funcionando igual que antes.
   2. Sin sesión, no pasa. Es lo que impide que la dirección quede abierta a
      internet entero gastando la cuenta del CIIP.
   3. El tope por hora corta. Es el freno contra la pestaña olvidada.
   4. El catálogo de la base llega hasta lo que el modelo sabe. Si esto se
      rompe, el asistente contesta plazos de su imaginación con la misma
      seguridad que los de verdad, y eso no se nota leyendo la respuesta.
   5. Cada tipo de fallo sale por su puerta. Esta prueba nació porque el
      manejador de errores preguntaba por 'Anthropic.APIStatusError', que no
      existe: 'instanceof undefined' no devuelve false, LANZA. El único
      fallo que el catch sabía contar era el suyo propio.
   ═══════════════════════════════════════════════════════════════════════ */

'use strict';

const path = require('path');
const Module = require('module');

let pasan = 0, fallan = 0;
function ok(que, cierto, detalle) {
  if (cierto) { pasan++; console.log('  PASA  ' + que); return; }
  fallan++;
  console.log('  FALLA ' + que);
  if (detalle) console.log('          ' + detalle);
}

console.log('\n  EL INTERMEDIARIO DEL ASISTENTE\n');

/* ═══════════════════════════════════════════════════════════════════════
   EL DECORADO
   ═══════════════════════════════════════════════════════════════════════ */

const CATALOGO = [
  { ref_panel:'c1', nombre:'Visa de inversionista', ente:'SAIME',  fase:1, activo:false, plazo_dias:45 },
  { ref_panel:'c3', nombre:'RIF personal',          ente:'SENIAT', fase:1, activo:true,  plazo_dias:7  },
  { ref_panel:'c8', nombre:'Registro de marca',     ente:'SAPI',   fase:2, activo:false, plazo_dias:null }
];

const SUPABASE_URL = 'https://dementira.supabase.co';

/* Lo que el falso Anthropic recibió en la última llamada, para poder
   mirarlo después. */
let ultimaPeticion = null;
/* Lo que el falso Anthropic va a hacer: devolver texto, o lanzar. */
let comportamiento = { tipo: 'bien', texto: 'Contesto yo.' };

/* ── El paquete de Anthropic, de mentira ─────────────────────────────
   Se sustituye por debajo del require, y no reescribiendo api/asistente.js
   para que acepte una dependencia inyectada. La razón es que la prueba
   tiene que correr sobre EL MISMO archivo que se despliega: un archivo
   preparado para ser probado es otro archivo, y el que falla en producción
   siempre es el otro. */

class APIError extends Error {
  constructor(status, message) { super(message || 'fallo'); this.status = status; }
}
class RateLimitError      extends APIError {}
class AuthenticationError extends APIError {}
class APIConnectionError  extends APIError {}

class AnthropicFalso {
  constructor(opciones) {
    this.apiKey = opciones && opciones.apiKey;
    this.beta = { messages: { create: (p) => this._create(p) } };
  }
  async _create(peticion) {
    ultimaPeticion = peticion;
    if (comportamiento.tipo === 'rate')    throw new RateLimitError(429, 'frenado');
    if (comportamiento.tipo === 'auth')    throw new AuthenticationError(401, 'clave mala');
    if (comportamiento.tipo === 'conexion')throw new APIConnectionError(undefined, 'no se llegó');
    if (comportamiento.tipo === 'api')     throw new APIError(500, 'reventó allí');
    if (comportamiento.tipo === 'raro')    throw new TypeError('algo que no es de Anthropic');
    if (comportamiento.tipo === 'negado')  return { stop_reason:'refusal', content:[] };
    if (comportamiento.tipo === 'vacio')   return { stop_reason:'end_turn', content:[] };
    return {
      stop_reason: 'end_turn',
      content: [{ type:'text', text: comportamiento.texto }]
    };
  }
}

const paqueteFalso = {
  Anthropic: AnthropicFalso,
  APIError, RateLimitError, AuthenticationError, APIConnectionError
};

const cargarDeVerdad = Module._load;
Module._load = function (peticion, padre, esPrincipal) {
  if (peticion === '@anthropic-ai/sdk') return paqueteFalso;
  return cargarDeVerdad.apply(this, arguments);
};

/* ── Supabase, de mentira ────────────────────────────────────────────
   Dos direcciones: la que dice quién eres y la que da el catálogo. */
let sesionValida = true;
let catalogoResponde = true;
let llamadasABase = [];

global.fetch = async function (url, opciones) {
  llamadasABase.push({ url, opciones });
  if (String(url).indexOf('/auth/v1/user') >= 0) {
    if (!sesionValida) return { ok:false, status:401, json: async () => ({}) };
    return { ok:true, status:200, json: async () => ({ id:'usuario-1', email:'quien@ejemplo.com' }) };
  }
  if (String(url).indexOf('/rest/v1/tipos_tramite') >= 0) {
    if (!catalogoResponde) return { ok:false, status:500, json: async () => ({}) };
    return { ok:true, status:200, json: async () => CATALOGO };
  }
  return { ok:false, status:404, json: async () => ({}) };
};

/* ── Un req y un res de mentira ──────────────────────────────────── */

function llamar(opciones) {
  opciones = opciones || {};
  const req = {
    method: opciones.metodo || 'POST',
    headers: opciones.cabeceras || { authorization: 'Bearer token-bueno' },
    body: 'cuerpo' in opciones ? opciones.cuerpo
        : { mensajes: [{ papel:'usuario', texto:'¿cuánto tarda el RIF?' }] }
  };
  let respuesta = { codigo:0, datos:null, cabeceras:{} };
  const res = {
    setHeader(k, v){ respuesta.cabeceras[k] = v; },
    status(c){ respuesta.codigo = c; return res; },
    json(d){ respuesta.datos = d; return respuesta; }
  };
  return Promise.resolve(asistente(req, res)).then(() => respuesta);
}

/* Cada prueba recarga el módulo: lleva memoria dentro (el catálogo
   cacheado, el contador por persona) y arrastrarla de una prueba a la
   siguiente haría que el orden importara. */
const RUTA = path.join(__dirname, '..', 'api', 'asistente.js');
let asistente;
function recargar(entorno) {
  delete require.cache[require.resolve(RUTA)];
  process.env.ANTHROPIC_API_KEY  = entorno.clave     === null ? '' : (entorno.clave || 'sk-ant-de-mentira');
  process.env.SUPABASE_URL       = entorno.url       === null ? '' : (entorno.url   || SUPABASE_URL);
  process.env.SUPABASE_ANON_KEY  = entorno.anon      === null ? '' : (entorno.anon  || 'anon-de-mentira');
  if (!process.env.ANTHROPIC_API_KEY) delete process.env.ANTHROPIC_API_KEY;
  if (!process.env.SUPABASE_URL)      delete process.env.SUPABASE_URL;
  if (!process.env.SUPABASE_ANON_KEY) delete process.env.SUPABASE_ANON_KEY;
  sesionValida = true; catalogoResponde = true; llamadasABase = [];
  comportamiento = { tipo:'bien', texto:'Contesto yo.' };
  ultimaPeticion = null;
  asistente = require(RUTA);
}

/* ═══════════════════════════════════════════════════════════════════════
   LAS PRUEBAS
   ═══════════════════════════════════════════════════════════════════════ */

(async function () {

/* ── 1 · EL ARRANQUE ─────────────────────────────────────────────────
   Que el archivo se pueda cargar es media prueba en sí misma: los nombres
   que saca del paquete de Anthropic se resuelven aquí, y si uno no existe
   se queda en 'undefined' sin quejarse hasta que alguien lo usa. */

recargar({});
ok('el módulo carga y exporta una función', typeof asistente === 'function');

/* ── 2 · SIN CLAVE, EL PANEL DE ANTES ────────────────────────────── */

recargar({ clave: null });
let r = await llamar();
ok('sin clave: contesta 503', r.codigo === 503, 'contestó ' + r.codigo);
ok('sin clave: el motivo es sin-clave', r.datos && r.datos.motivo === 'sin-clave',
   JSON.stringify(r.datos));
ok('sin clave: ni siquiera molesta a Supabase', llamadasABase.length === 0,
   llamadasABase.length + ' llamadas');

recargar({ url: null });
r = await llamar();
ok('sin SUPABASE_URL: contesta sin-base', r.codigo === 503 && r.datos.motivo === 'sin-base',
   r.codigo + ' ' + JSON.stringify(r.datos));

/* ── 3 · LA PUERTA ───────────────────────────────────────────────────
   Sin esto, la dirección queda abierta a internet entero y cualquiera
   gasta la cuenta del CIIP desde una terminal. */

recargar({});
r = await llamar({ cabeceras: {} });
ok('sin cabecera: no pasa', r.codigo === 401 && r.datos.motivo === 'sin-sesion',
   r.codigo + ' ' + JSON.stringify(r.datos));

recargar({});
r = await llamar({ cabeceras: { authorization: 'token-suelto-sin-Bearer' } });
ok('con un token sin Bearer: no pasa', r.codigo === 401, 'contestó ' + r.codigo);

recargar({});
sesionValida = false;
r = await llamar();
ok('con una sesión que Supabase rechaza: no pasa', r.codigo === 401,
   'contestó ' + r.codigo);

recargar({});
r = await llamar({ metodo: 'GET' });
ok('por GET: no se atiende', r.codigo === 405, 'contestó ' + r.codigo);

/* ── 4 · LO QUE LLEGA ──────────────────────────────────────────────── */

recargar({});
r = await llamar({ cuerpo: { mensajes: [] } });
ok('sin pregunta: 400', r.codigo === 400, 'contestó ' + r.codigo);

recargar({});
r = await llamar({ cuerpo: { mensajes: [{ papel:'asistente', texto:'yo hablé el último' }] } });
ok('si la conversación no acaba en pregunta: 400', r.codigo === 400,
   'contestó ' + r.codigo);

recargar({});
r = await llamar({ cuerpo: '{"mensajes":[{"papel":"usuario","texto":"hola"}]}' });
ok('el cuerpo en texto plano también se entiende', r.codigo === 200,
   'contestó ' + r.codigo);

/* Los últimos doce turnos y no más: sin este recorte, cada pregunta de una
   charla larga cuesta más que la anterior y nadie lo ve hasta la factura. */
recargar({});
const muchos = [];
for (let i = 0; i < 40; i++) {
  muchos.push({ papel: i % 2 ? 'asistente' : 'usuario', texto: 'turno ' + i });
}
muchos.push({ papel:'usuario', texto:'la última' });
await llamar({ cuerpo: { mensajes: muchos } });
ok('la conversación se recorta a 12 turnos',
   ultimaPeticion && ultimaPeticion.messages.length === 12,
   'fueron ' + (ultimaPeticion ? ultimaPeticion.messages.length : '?'));

/* Un pegado de treinta páginas convierte una pregunta de céntimos en una
   de varios dólares. Se corta a 4.000 caracteres. */
recargar({});
await llamar({ cuerpo: { mensajes: [{ papel:'usuario', texto:'x'.repeat(50000) }] } });
ok('un mensaje larguísimo se corta a 4.000 caracteres',
   ultimaPeticion && ultimaPeticion.messages[0].content.length === 4000,
   'quedó en ' + (ultimaPeticion ? ultimaPeticion.messages[0].content.length : '?'));

recargar({});
await llamar({ cuerpo: { mensajes: [
  { papel:'usuario',   texto:'primera' },
  { papel:'asistente', texto:'contesté' },
  { papel:'usuario',   texto:'segunda' }
] } });
ok('los papeles se traducen a los del modelo',
   ultimaPeticion &&
   ultimaPeticion.messages[0].role === 'user' &&
   ultimaPeticion.messages[1].role === 'assistant' &&
   ultimaPeticion.messages[2].role === 'user',
   JSON.stringify(ultimaPeticion && ultimaPeticion.messages.map(m => m.role)));

/* ── 5 · EL TOPE ────────────────────────────────────────────────────
   No es una sospecha sobre el usuario: es lo que impide que una pestaña
   olvidada se coma el presupuesto de un mes en una tarde. */

recargar({});
let ultima;
for (let i = 0; i < 41; i++) ultima = await llamar();
ok('a la pregunta 41 en una hora: 429', ultima.codigo === 429,
   'contestó ' + ultima.codigo);
ok('y el motivo es tope', ultima.datos && ultima.datos.motivo === 'tope',
   JSON.stringify(ultima.datos));

/* ── 6 · LO QUE EL MODELO SABE ───────────────────────────────────────
   Si esto se rompe, el asistente inventa plazos con la misma seguridad con
   la que diría los de verdad, y eso no se nota leyendo la respuesta. Por
   eso se mira aquí y no a ojo. */

recargar({});
await llamar();
const sistema = ultimaPeticion && ultimaPeticion.system[0].text;

ok('el catálogo de la base entra en lo que el modelo sabe',
   sistema && sistema.indexOf('RIF personal') >= 0 && sistema.indexOf('SENIAT') >= 0);
ok('el plazo de cada trámite entra',
   sistema && sistema.indexOf('7 días') >= 0);
ok('un trámite sin plazo se dice, no se calla',
   sistema && sistema.indexOf('plazo: no consta') >= 0);
ok('se distingue el que ya se puede solicitar del que no',
   sistema && sistema.indexOf('SE PUEDE SOLICITAR YA') >= 0 &&
   sistema.indexOf('todavía NO se solicita') >= 0);
ok('se le prohíbe inventar plazos',
   sistema && /No inventas plazos/.test(sistema));
ok('se le dice que no sabe nada del expediente de quien pregunta',
   sistema && /No sabes nada del expediente/.test(sistema));

ok('el texto de instrucciones se cachea',
   ultimaPeticion && ultimaPeticion.system[0].cache_control &&
   ultimaPeticion.system[0].cache_control.type === 'ephemeral');
ok('el modelo es el que dice el archivo, no uno inventado',
   ultimaPeticion && ultimaPeticion.model === 'claude-opus-5',
   ultimaPeticion && ultimaPeticion.model);
ok('el esfuerzo es bajo: esto es un mostrador, no un problema difícil',
   ultimaPeticion && ultimaPeticion.output_config &&
   ultimaPeticion.output_config.effort === 'low');
ok('hay reencaminamiento si el modelo declina',
   ultimaPeticion && ultimaPeticion.fallbacks === 'default' &&
   Array.isArray(ultimaPeticion.betas) && ultimaPeticion.betas.length > 0);

/* El catálogo se lee CON EL TOKEN DEL USUARIO. Con una llave de servicio
   se saltaría el RLS, y el día que se decida que ciertos trámites solo los
   ve cierta gente, esta función se los enseñaría a todos. */
recargar({});
await llamar();
const consulta = llamadasABase.find(l => String(l.url).indexOf('tipos_tramite') >= 0);
ok('el catálogo se pide con el token de quien pregunta',
   consulta && consulta.opciones.headers.Authorization === 'Bearer token-bueno',
   consulta && consulta.opciones.headers.Authorization);

/* Que la base falle deja al asistente con menos que decir, no mudo. */
recargar({});
catalogoResponde = false;
r = await llamar();
ok('si el catálogo no responde, sigue contestando', r.codigo === 200,
   'contestó ' + r.codigo);
ok('...y se le avisa al modelo de que va a ciegas',
   ultimaPeticion && /no se pudo leer/.test(ultimaPeticion.system[0].text));

/* ── 7 · LA RESPUESTA ───────────────────────────────────────────── */

recargar({});
comportamiento = { tipo:'bien', texto:'El RIF suele tardar una semana.' };
r = await llamar();
ok('una respuesta normal llega entera',
   r.codigo === 200 && r.datos.respuesta === 'El RIF suele tardar una semana.',
   JSON.stringify(r.datos));

recargar({});
comportamiento = { tipo:'negado' };
r = await llamar();
ok('si el modelo declina, el usuario recibe una frase y no un error',
   r.codigo === 200 && r.datos.respuesta && r.datos.respuesta.length > 0,
   r.codigo + ' ' + JSON.stringify(r.datos));

recargar({});
comportamiento = { tipo:'vacio' };
r = await llamar();
ok('una respuesta vacía se cuenta como fallo, no como silencio',
   r.codigo === 502, 'contestó ' + r.codigo);

/* ── 8 · CADA FALLO POR SU PUERTA ────────────────────────────────────
   Aquí es donde estaba el error que dio pie a esta tanda. Los cuatro tipos
   heredan de APIError, así que el orden de las preguntas es la prueba: si
   alguien mueve el general delante del de conexión, «no llegamos a
   Anthropic» pasa a leerse como «Anthropic contestó mal», y quien lo lea se
   va a mirar al sitio equivocado. */

const puertas = [
  { tipo:'rate',     codigo:429, motivo:'tope',      que:'a Anthropic frenándonos' },
  { tipo:'auth',     codigo:503, motivo:'sin-clave', que:'a una clave que no vale' },
  { tipo:'conexion', codigo:504, motivo:null,        que:'a no llegar a Anthropic' },
  { tipo:'api',      codigo:502, motivo:null,        que:'a Anthropic contestando mal' },
  { tipo:'raro',     codigo:500, motivo:null,        que:'a un fallo que no es de Anthropic' }
];

for (const p of puertas) {
  recargar({});
  comportamiento = { tipo: p.tipo };
  r = await llamar();
  ok(p.que + ': contesta ' + p.codigo, r.codigo === p.codigo, 'contestó ' + r.codigo);
  if (p.motivo) {
    ok(p.que + ': con motivo ' + p.motivo, r.datos && r.datos.motivo === p.motivo,
       JSON.stringify(r.datos));
  }
  ok(p.que + ': no se filtra el detalle interno al usuario',
     r.datos && !r.datos.stack && typeof r.datos.error === 'string',
     JSON.stringify(r.datos));
}

/* Y que la clave no salga NUNCA en lo que se devuelve. Es lo único de todo
   esto que no tiene arreglo si se escapa una vez. */
recargar({});
comportamiento = { tipo:'auth' };
r = await llamar();
ok('la clave no aparece en ninguna respuesta',
   JSON.stringify(r.datos).indexOf('sk-ant') < 0, JSON.stringify(r.datos));

console.log('\n  ' + pasan + ' de ' + (pasan + fallan) + ' comprobaciones superadas\n');
process.exit(fallan ? 1 : 0);

})().catch(e => {
  console.log('\n  La tanda se cayó: ' + (e && e.stack) + '\n');
  process.exit(1);
});
