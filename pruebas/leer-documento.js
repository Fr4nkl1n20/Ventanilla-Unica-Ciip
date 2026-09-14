/* ═══════════════════════════════════════════════════════════════════════
   EL LECTOR DE VERCEL, PROBADO SIN GASTAR UN CÉNTIMO
   ═══════════════════════════════════════════════════════════════════════

   Dos piezas, las dos de este cambio:

   A. api/leer-documento.js, contra un Anthropic y un Supabase de mentira.
   B. El trozo de config.js que le habla desde el navegador, corrido en una
      caja de Node con un window, un fetch y un cubo de mentira.

   LO QUE SE VIGILA, Y POR QUÉ:

   1. Encenderlo necesita la clave Y LECTOR_ACTIVO. La clave sola enciende
      el asistente, que solo manda conversación; esto manda poderes y
      pasaportes, y eso no puede quedar decidido de rebote.
   2. Sin sesión no pasa. Es lo que impide gastar la cuenta desde fuera.
   3. SOLO borra de {uid}/lector/. Esta función borra lo que lee: sin esa
      guarda, un gestor -que puede leer la carpeta de cualquiera- le
      pasaría la ruta de un recaudo de verdad y lo haría desaparecer.
   4. Lo que lee lo borra SIEMPRE, vaya bien o mal.
   5. La tijera: ni un tipo de papel ni una casilla que el trámite no pida.
   6. El navegador sube a su carpeta, manda la ruta y no el archivo, y no
      pinta el cuadro si el servidor dice que no está encendido.
   ═══════════════════════════════════════════════════════════════════════ */

'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');
const Module = require('module');

let pasan = 0, fallan = 0;
function ok(que, cierto, detalle) {
  if (cierto) { pasan++; console.log('  PASA  ' + que); return; }
  fallan++;
  console.log('  FALLA ' + que);
  if (detalle) console.log('          ' + detalle);
}

console.log('\n  EL LECTOR DE DOCUMENTOS DE VERCEL\n');

/* ═══════════════════════════════════════════════════════════════════════
   EL DECORADO
   ═══════════════════════════════════════════════════════════════════════ */

const SUPABASE_URL = 'https://dementira.supabase.co';
const UID = 'usuario-1';
const BYTES_PDF = Buffer.from('%PDF-1.4 un poder de mentira');

let ultimaPeticion = null;
let llamadasAnthropic = 0;
let comportamiento = { tipo: 'bien', texto: '{}' };

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
    llamadasAnthropic++;
    if (comportamiento.tipo === 'rate')     throw new RateLimitError(429, 'frenado');
    if (comportamiento.tipo === 'auth')     throw new AuthenticationError(401, 'clave mala');
    if (comportamiento.tipo === 'conexion') throw new APIConnectionError(undefined, 'no se llegó');
    if (comportamiento.tipo === 'api')      throw new APIError(500, 'reventó allí');
    if (comportamiento.tipo === 'raro')     throw new TypeError('algo que no es de Anthropic');
    if (comportamiento.tipo === 'negado')   return { stop_reason: 'refusal', content: [] };
    return { stop_reason: 'end_turn', content: [{ type: 'text', text: comportamiento.texto }] };
  }
}

const cargarDeVerdad = Module._load;
Module._load = function (peticion) {
  if (peticion === '@anthropic-ai/sdk') {
    return { Anthropic: AnthropicFalso, APIError, RateLimitError, AuthenticationError, APIConnectionError };
  }
  return cargarDeVerdad.apply(this, arguments);
};

/* ── Supabase, de mentira: quién eres, bajar un papel, borrarlo ── */
let sesionValida = true;
let papel = { tipo: 'application/pdf', bytes: BYTES_PDF };
let llamadas = [];

global.fetch = async function (url, opciones) {
  opciones = opciones || {};
  const u = String(url);
  const metodo = opciones.method || 'GET';
  llamadas.push({ url: u, metodo, headers: opciones.headers || {} });

  if (u.indexOf('/auth/v1/user') >= 0) {
    if (!sesionValida) return { ok: false, status: 401, json: async () => ({}) };
    return { ok: true, status: 200, json: async () => ({ id: UID }) };
  }
  if (metodo === 'GET' && u.indexOf('/storage/v1/object/authenticated/recaudos/') >= 0) {
    if (!papel) return { ok: false, status: 400, json: async () => ({}) };
    const b = papel.bytes;
    return {
      ok: true, status: 200,
      headers: { get: (k) => String(k).toLowerCase() === 'content-type' ? papel.tipo : null },
      arrayBuffer: async () => b.buffer.slice(b.byteOffset, b.byteOffset + b.length)
    };
  }
  if (metodo === 'DELETE' && u.indexOf('/storage/v1/object/recaudos/') >= 0) {
    return { ok: true, status: 200, json: async () => ({}) };
  }
  return { ok: false, status: 404, json: async () => ({}) };
};

const bajadas  = () => llamadas.filter(l => l.metodo === 'GET' && l.url.indexOf('/storage/') >= 0);
const borrados = () => llamadas.filter(l => l.metodo === 'DELETE');

const RUTA_BUENA = UID + '/lector/abc12345-poder.pdf';
const CASILLAS = { poder: ['apoderado_nombre', 'poder_numero', 'poder_fecha'] };

function llamar(opciones) {
  opciones = opciones || {};
  const req = {
    method: opciones.metodo || 'POST',
    headers: opciones.cabeceras || { authorization: 'Bearer token-bueno' },
    body: 'cuerpo' in opciones ? opciones.cuerpo : { ruta: RUTA_BUENA, casillas: CASILLAS }
  };
  const respuesta = { codigo: 0, datos: null, cabeceras: {} };
  const res = {
    setHeader(k, v) { respuesta.cabeceras[k] = v; },
    status(c) { respuesta.codigo = c; return res; },
    json(d) { respuesta.datos = d; return respuesta; }
  };
  return Promise.resolve(lector(req, res)).then(() => respuesta);
}

const RUTA = path.join(__dirname, '..', 'api', 'leer-documento.js');
let lector;
function recargar(entorno) {
  entorno = entorno || {};
  delete require.cache[require.resolve(RUTA)];
  const pon = (k, v) => { if (v) process.env[k] = v; else delete process.env[k]; };
  pon('ANTHROPIC_API_KEY', entorno.clave === null ? '' : (entorno.clave || 'sk-ant-de-mentira'));
  pon('LECTOR_ACTIVO',     entorno.activo === null ? '' : (entorno.activo || 'si'));
  pon('SUPABASE_URL',      entorno.url === null ? '' : SUPABASE_URL);
  pon('SUPABASE_ANON_KEY', entorno.anon === null ? '' : 'anon-de-mentira');
  sesionValida = true;
  papel = { tipo: 'application/pdf', bytes: BYTES_PDF };
  llamadas = [];
  comportamiento = { tipo: 'bien', texto: '{"doc":"poder","campos":{"apoderado_nombre":"María Pérez"}}' };
  ultimaPeticion = null;
  llamadasAnthropic = 0;
  lector = require(RUTA);
}

(async function () {

/* ═══════════════════════════════════════════════════════════════════════
   A · EL SERVIDOR
   ═══════════════════════════════════════════════════════════════════════ */

recargar();
ok('el módulo carga y exporta una función', typeof lector === 'function');

/* ── 1 · LOS DOS INTERRUPTORES ─────────────────────────────────────── */

recargar({ clave: null });
let r = await llamar({ metodo: 'GET', cuerpo: undefined });
ok('GET sin clave: listo es false', r.codigo === 200 && r.datos.listo === false, JSON.stringify(r.datos));

recargar({ activo: null });
r = await llamar({ metodo: 'GET', cuerpo: undefined });
ok('GET con la clave pero sin LECTOR_ACTIVO: listo sigue en false',
   r.codigo === 200 && r.datos.listo === false, JSON.stringify(r.datos));

recargar({ activo: 'true' });
r = await llamar({ metodo: 'GET', cuerpo: undefined });
ok('LECTOR_ACTIVO tiene que decir «si», no cualquier cosa', r.datos.listo === false,
   JSON.stringify(r.datos));

recargar();
r = await llamar({ metodo: 'GET', cuerpo: undefined });
ok('GET con las dos: listo es true', r.codigo === 200 && r.datos.listo === true, JSON.stringify(r.datos));
ok('GET no se cachea: si se apaga, el panel se entera en la siguiente carga',
   r.cabeceras['Cache-Control'] === 'no-store');
ok('GET no pregunta a nadie', llamadas.length === 0, llamadas.length + ' llamadas');

recargar({ clave: null });
r = await llamar();
ok('POST sin clave: 503 sin-clave', r.codigo === 503 && r.datos.motivo === 'sin-clave', JSON.stringify(r.datos));
ok('...y no toca Supabase', llamadas.length === 0);

recargar({ activo: null });
r = await llamar();
ok('POST con la clave pero apagado: 503 apagado', r.codigo === 503 && r.datos.motivo === 'apagado',
   JSON.stringify(r.datos));
ok('...y no baja ni lee nada', llamadas.length === 0 && llamadasAnthropic === 0);

recargar({ url: null });
r = await llamar();
ok('sin SUPABASE_URL: sin-base', r.codigo === 503 && r.datos.motivo === 'sin-base');

recargar();
r = await llamar({ metodo: 'PUT' });
ok('por PUT: 405', r.codigo === 405, 'contestó ' + r.codigo);

/* ── 2 · LA PUERTA ─────────────────────────────────────────────────── */

recargar();
r = await llamar({ cabeceras: {} });
ok('sin token: 401', r.codigo === 401 && r.datos.motivo === 'sin-sesion');
ok('...y no se borra nada: sin saber quién eres no sabe de quién es', borrados().length === 0);

recargar();
sesionValida = false;
r = await llamar();
ok('con una sesión que Supabase rechaza: 401', r.codigo === 401);
ok('...ni se baja ni se borra', bajadas().length === 0 && borrados().length === 0);

/* ── 3 · SOLO SU CARPETA DEL LECTOR ──────────────────────────────────
   Esta función BORRA lo que lee. Lo que viene aquí es lo que impide que
   se lleve un recaudo de verdad. */

const rutasMalas = [
  ['la carpeta de otra persona',           'otra-persona/lector/abc-poder.pdf'],
  ['un recaudo suyo fuera del lector',     UID + '/poder-abc-poder.pdf'],
  ['lo que emitió el CIIP',                UID + '/emitidos/abc-titulo.pdf'],
  ['una subcarpeta dentro del lector',     UID + '/lector/otra/poder.pdf'],
  ['una ruta que sube de carpeta',         UID + '/lector/../poder-abc.pdf'],
  ['la carpeta del lector sin archivo',    UID + '/lector/'],
  ['nada',                                 '']
];
for (const [que, ruta] of rutasMalas) {
  recargar();
  r = await llamar({ cuerpo: { ruta, casillas: CASILLAS } });
  ok('ruta con ' + que + ': 400', r.codigo === 400, 'contestó ' + r.codigo);
  ok('ruta con ' + que + ': no se baja ni se borra', bajadas().length === 0 && borrados().length === 0,
     bajadas().length + ' bajadas, ' + borrados().length + ' borrados');
}

/* ── 4 · EL CAMINO BUENO ──────────────────────────────────────────── */

recargar();
r = await llamar();
ok('un poder que se lee: 200 con doc y campos',
   r.codigo === 200 && r.datos.doc === 'poder' && r.datos.campos.apoderado_nombre === 'María Pérez',
   r.codigo + ' ' + JSON.stringify(r.datos));

const bajada = bajadas()[0];
ok('el papel se baja con el token de quien pregunta, no con una llave de servicio',
   bajada && bajada.headers.Authorization === 'Bearer token-bueno',
   bajada && JSON.stringify(bajada.headers));
ok('...de la ruta que se dijo',
   bajada && bajada.url === SUPABASE_URL + '/storage/v1/object/authenticated/recaudos/' + RUTA_BUENA,
   bajada && bajada.url);

const bloque = ultimaPeticion && ultimaPeticion.messages[0].content[0];
ok('un PDF va como documento', bloque && bloque.type === 'document' &&
   bloque.source.media_type === 'application/pdf', JSON.stringify(bloque && bloque.source.media_type));
ok('...con los bytes que había en el cubo',
   bloque && Buffer.from(bloque.source.data, 'base64').equals(BYTES_PDF));
const pide = ultimaPeticion && ultimaPeticion.messages[0].content[1].text;
ok('se le dice qué casillas buscar en qué papel',
   pide && pide.indexOf('poder: apoderado_nombre, poder_numero, poder_fecha') >= 0, pide);
ok('el modelo es claude-opus-5', ultimaPeticion && ultimaPeticion.model === 'claude-opus-5');
ok('el aviso prohíbe inventar y se cachea',
   ultimaPeticion && /literalmente escrito/.test(ultimaPeticion.system[0].text) &&
   ultimaPeticion.system[0].cache_control.type === 'ephemeral');
ok('lo escrito en el papel son datos, no órdenes',
   ultimaPeticion && /nunca\s+instrucciones/.test(ultimaPeticion.system[0].text));
ok('hay reencaminamiento si el modelo declina',
   ultimaPeticion && ultimaPeticion.fallbacks === 'default' && ultimaPeticion.betas.length > 0);

const borrado = borrados()[0];
ok('y al terminar se borra el papel del cubo, con el token de quien pregunta',
   borrados().length === 1 && borrado.url === SUPABASE_URL + '/storage/v1/object/recaudos/' + RUTA_BUENA &&
   borrado.headers.Authorization === 'Bearer token-bueno',
   JSON.stringify(borrados()));

recargar();
r = await llamar({ cuerpo: JSON.stringify({ ruta: RUTA_BUENA, casillas: CASILLAS }) });
ok('el cuerpo en texto plano también se entiende', r.codigo === 200, 'contestó ' + r.codigo);

recargar();
r = await llamar({ cuerpo: { ruta: UID + '/lector/abc-poder notariado ñ.pdf', casillas: CASILLAS } });
ok('un nombre con espacios y eñes se pide bien codificado',
   bajadas()[0] && bajadas()[0].url.indexOf('poder%20notariado%20%C3%B1.pdf') >= 0,
   bajadas()[0] && bajadas()[0].url);

recargar();
papel = { tipo: 'image/jpeg', bytes: Buffer.from('jpeg de mentira') };
r = await llamar();
const img = ultimaPeticion && ultimaPeticion.messages[0].content[0];
ok('una foto va como imagen, con su tipo', r.codigo === 200 && img && img.type === 'image' &&
   img.source.media_type === 'image/jpeg', JSON.stringify(img && img.source.media_type));

/* ── 5 · LO QUE NO SE PUEDE LEER, TAMBIÉN SE BORRA ─────────────────── */

recargar();
papel = { tipo: 'image/heic', bytes: Buffer.from('heic de mentira') };
r = await llamar();
ok('una foto HEIC: 415 formato, sin molestar al modelo',
   r.codigo === 415 && r.datos.motivo === 'formato' && llamadasAnthropic === 0,
   r.codigo + ' ' + JSON.stringify(r.datos));
ok('...y se borra', borrados().length === 1);

recargar();
papel = null;
r = await llamar();
ok('si el papel no está: 404', r.codigo === 404, 'contestó ' + r.codigo);
ok('...y se intenta borrar igual', borrados().length === 1);

recargar();
papel = { tipo: 'application/pdf', bytes: Buffer.alloc(10 * 1024 * 1024 + 1) };
r = await llamar();
ok('pasado de 10 MB: 413, sin molestar al modelo', r.codigo === 413 && llamadasAnthropic === 0,
   'contestó ' + r.codigo);
ok('...y se borra', borrados().length === 1);

recargar();
r = await llamar({ cuerpo: { ruta: RUTA_BUENA, casillas: 'poder' } });
ok('casillas que no son un mapa: 400', r.codigo === 400, 'contestó ' + r.codigo);
ok('...y el papel, que sí era suyo, se borra', borrados().length === 1);

recargar();
const muchas = {};
for (let i = 0; i < 20; i++) muchas['papel_' + i] = ['casilla_a', 'casilla_b', 'casilla_c', 'casilla_d'];
r = await llamar({ cuerpo: { ruta: RUTA_BUENA, casillas: muchas } });
ok('un mapa de ochenta casillas no viene del panel: 400', r.codigo === 400, 'contestó ' + r.codigo);

/* ── 6 · LA TIJERA ─────────────────────────────────────────────────── */

recargar();
comportamiento = { tipo: 'bien', texto: '```json\n{"doc":"poder","campos":{"apoderado_nombre":"Ana","cedula_de_otro":"V-1","poder_numero":"","poder_fecha":null}}\n```' };
r = await llamar();
ok('el JSON envuelto en un bloque de código se entiende', r.datos.doc === 'poder', JSON.stringify(r.datos));
ok('una casilla que el trámite no pide se recorta', !('cedula_de_otro' in r.datos.campos));
ok('las vacías y las nulas no salen', !('poder_numero' in r.datos.campos) && !('poder_fecha' in r.datos.campos),
   JSON.stringify(r.datos.campos));

recargar();
comportamiento = { tipo: 'bien', texto: '{"doc":"pasaporte","campos":{"apoderado_nombre":"Ana"}}' };
r = await llamar();
ok('un tipo de papel que no estaba en la lista: doc null y nada más',
   r.datos.doc === null && Object.keys(r.datos.campos).length === 0, JSON.stringify(r.datos));

recargar();
comportamiento = { tipo: 'bien', texto: 'No sé leer esto.' };
r = await llamar();
ok('una respuesta que no es JSON: doc null, no un 500', r.codigo === 200 && r.datos.doc === null,
   r.codigo + ' ' + JSON.stringify(r.datos));

recargar();
comportamiento = { tipo: 'negado' };
r = await llamar();
ok('si el modelo declina: doc null, y se sube a mano', r.codigo === 200 && r.datos.doc === null);
ok('...y se borra', borrados().length === 1);

/* ── 7 · EL TOPE ───────────────────────────────────────────────────── */

recargar();
let ultima;
for (let i = 0; i < 21; i++) ultima = await llamar();
ok('a la lectura 21 en una hora: 429 tope', ultima.codigo === 429 && ultima.datos.motivo === 'tope',
   ultima.codigo + ' ' + JSON.stringify(ultima.datos));
ok('...y ese papel también se borra', borrados().length === 21, borrados().length + ' borrados');

/* ── 8 · CADA FALLO POR SU PUERTA, Y EL PAPEL SIEMPRE FUERA ────────── */

const puertas = [
  { tipo: 'rate',     codigo: 429, motivo: 'tope',      que: 'Anthropic frenándonos' },
  { tipo: 'auth',     codigo: 503, motivo: 'sin-clave', que: 'una clave que no vale' },
  { tipo: 'conexion', codigo: 504, motivo: null,        que: 'no llegar a Anthropic' },
  { tipo: 'api',      codigo: 502, motivo: null,        que: 'Anthropic contestando mal' },
  { tipo: 'raro',     codigo: 500, motivo: null,        que: 'un fallo que no es de Anthropic' }
];
for (const p of puertas) {
  recargar();
  comportamiento = { tipo: p.tipo };
  r = await llamar();
  ok(p.que + ': ' + p.codigo, r.codigo === p.codigo, 'contestó ' + r.codigo);
  if (p.motivo) ok(p.que + ': motivo ' + p.motivo, r.datos.motivo === p.motivo, JSON.stringify(r.datos));
  ok(p.que + ': el papel se borra igual', borrados().length === 1, borrados().length + ' borrados');
  ok(p.que + ': ni la clave ni el detalle interno salen',
     JSON.stringify(r.datos).indexOf('sk-ant') < 0 && !r.datos.stack);
}

/* ═══════════════════════════════════════════════════════════════════════
   B · EL NAVEGADOR: config.js
   ═══════════════════════════════════════════════════════════════════════ */

const CONFIG = fs.readFileSync(path.join(__dirname, '..', 'config.js'), 'utf8');

function navegador(opciones) {
  const escena = {
    hostname: opciones.hostname,
    listo: 'listo' in opciones ? opciones.listo : true,
    sesion: 'sesion' in opciones ? opciones.sesion
          : { access_token: 'token-del-panel', user: { id: UID } },
    subeMal: !!opciones.subeMal,
    servidor: opciones.servidor || { ok: true, status: 200, datos: { doc: 'poder', campos: { poder_numero: '12' } } },
    redCaida: !!opciones.redCaida,
    peticiones: [], subidas: [], quitados: []
  };
  const ventana = {
    location: { protocol: 'https:', hostname: escena.hostname },
    console: { info() {}, warn() {} },
    FormData: class {},
    fetch: async (url, op) => {
      op = op || {};
      escena.peticiones.push({ url, metodo: op.method || 'GET', headers: op.headers || {}, body: op.body });
      if (escena.redCaida) throw new TypeError('Failed to fetch');
      if ((op.method || 'GET') === 'GET') return { ok: true, status: 200, json: async () => ({ listo: escena.listo }) };
      const s = escena.servidor;
      return { ok: s.ok, status: s.status, json: async () => s.datos };
    },
    sbCIIP: {
      auth: { getSession: async () => ({ data: { session: escena.sesion } }) },
      storage: {
        from: (cubo) => ({
          upload: async (ruta, archivo) => {
            escena.subidas.push({ cubo, ruta, archivo });
            return escena.subeMal ? { error: new Error('el cubo dijo que no') } : { data: { path: ruta }, error: null };
          },
          remove: async (rutas) => { escena.quitados.push({ cubo, rutas }); return { error: null }; }
        })
      }
    }
  };
  ventana.window = ventana;
  vm.createContext(ventana);
  vm.runInContext(CONFIG, ventana);
  escena.ventana = ventana;
  return escena;
}

const PUBLICADO = 'ventanilla-unica-2.vercel.app';
const casillasDelPanel = { poder: ['poder_numero'] };
const archivo = { name: 'poder notariado.pdf' };

let n = navegador({ hostname: 'localhost' });
ok('en local (proyecto de pruebas, sin dirección) no hay lector', !n.ventana.CIIP_LECTOR);

n = navegador({ hostname: PUBLICADO });
ok('en el sitio publicado hay lector, y sabe preguntar si está listo',
   typeof n.ventana.CIIP_LECTOR === 'function' && typeof n.ventana.CIIP_LECTOR.listo === 'function');

n = navegador({ hostname: PUBLICADO, listo: false });
let listo = await n.ventana.CIIP_LECTOR.listo();
ok('si el servidor dice que no está encendido, listo es false', listo === false);
await n.ventana.CIIP_LECTOR.listo();
ok('...y se pregunta UNA vez por página', n.peticiones.length === 1, n.peticiones.length + ' veces');
ok('...a /api/leer-documento', n.peticiones[0] && n.peticiones[0].url === '/api/leer-documento');

n = navegador({ hostname: PUBLICADO, listo: true });
listo = await n.ventana.CIIP_LECTOR.listo();
ok('si dice que sí, listo es true', listo === true);

n = navegador({ hostname: PUBLICADO, redCaida: true });
listo = await n.ventana.CIIP_LECTOR.listo();
ok('sin red, listo es false y no revienta: mejor sin cuadro que con uno mudo', listo === false);

n = navegador({ hostname: PUBLICADO });
let leido = await n.ventana.CIIP_LECTOR(archivo, casillasDelPanel);
const subida = n.subidas[0];
ok('el papel se sube al cubo de recaudos, a {uid}/lector/',
   subida && subida.cubo === 'recaudos' && subida.ruta.indexOf(UID + '/lector/') === 0,
   subida && subida.ruta);
ok('...con el nombre limpio', subida && /-poder_notariado\.pdf$/.test(subida.ruta), subida && subida.ruta);
ok('...y la ruta vale para el servidor', subida && lector.rutaValida(subida.ruta, UID), subida && subida.ruta);
const post = n.peticiones.find(p => p.metodo === 'POST');
const cuerpo = post && JSON.parse(post.body);
ok('al servidor va la ruta y las casillas, NO el archivo',
   cuerpo && cuerpo.ruta === subida.ruta && cuerpo.casillas.poder[0] === 'poder_numero' &&
   Object.keys(cuerpo).length === 2, post && post.body);
ok('...con el token de la sesión', post && post.headers.Authorization === 'Bearer token-del-panel');
ok('lo que contesta el servidor llega al panel tal cual',
   leido && leido.doc === 'poder' && leido.campos.poder_numero === '12', JSON.stringify(leido));
ok('si el servidor contestó, el panel no borra: ya lo hizo él', n.quitados.length === 0);

n = navegador({ hostname: PUBLICADO, servidor: { ok: false, status: 503, datos: { motivo: 'apagado' } } });
let fallo = null;
try { await n.ventana.CIIP_LECTOR(archivo, casillasDelPanel); } catch (e) { fallo = e; }
ok('si el servidor contesta mal, la promesa falla y el panel dice «no pude»', !!fallo);
ok('...y el panel intenta quitar el papel que subió',
   n.quitados.length === 1 && n.quitados[0].rutas[0] === n.subidas[0].ruta, JSON.stringify(n.quitados));

n = navegador({ hostname: PUBLICADO, sesion: null });
fallo = null;
try { await n.ventana.CIIP_LECTOR(archivo, casillasDelPanel); } catch (e) { fallo = e; }
ok('sin sesión falla antes de subir nada', !!fallo && n.subidas.length === 0 && n.peticiones.length === 0);

n = navegador({ hostname: PUBLICADO, subeMal: true });
fallo = null;
try { await n.ventana.CIIP_LECTOR(archivo, casillasDelPanel); } catch (e) { fallo = e; }
ok('si el cubo no deja subir, falla sin llamar al servidor ni borrar nada',
   !!fallo && n.peticiones.length === 0 && n.quitados.length === 0);

/* ═══════════════════════════════════════════════════════════════════════
   C · EL PANEL ESPERA AL «LISTO»
   ═══════════════════════════════════════════════════════════════════════
   El recorrido entero del cuadro lo prueba el arnés del panel con un lector
   de mentira que no trae listo. Aquí se mira que el panel, cuando el lector
   SÍ lo trae, no pinte el cuadro sin preguntar. */

const PANEL = fs.readFileSync(path.join(__dirname, '..', 'ciip-ventanilla-unica-local.html'), 'utf8');
const trozo = PANEL.slice(PANEL.indexOf('var lector = window.CIIP_LECTOR;'),
                          PANEL.indexOf('/* ── el cuadro cuando todavia no has soltado nada ── */'));
ok('el panel pregunta lector.listo antes de pintar el cuadro',
   /lector\.listo\(\)/.test(trozo) && /insertBefore\(cuadro/.test(trozo), trozo.slice(0, 200));

console.log('\n  ' + pasan + ' de ' + (pasan + fallan) + ' comprobaciones superadas\n');
process.exit(fallan ? 1 : 0);

})().catch(e => {
  console.log('\n  La tanda se cayó: ' + (e && e.stack) + '\n');
  process.exit(1);
});
