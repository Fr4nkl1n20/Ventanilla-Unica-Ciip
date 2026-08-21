/* ══════════════════════════════════════════════════════════════════════
   LAS CERRADURAS, PROBADAS CONTRA LA BASE DE VERDAD
   ══════════════════════════════════════════════════════════════════════
   Node 18 o mayor.  node pruebas/rls.js

   POR QUE ESTO EXISTE
   ─────────────────────────────────────────────────────────────────────
   Las 1.281 pruebas del panel corren contra pruebas/supabase-mentira.js,
   un doble que escribi yo. Ese doble concede o niega el acceso segun lo
   que YO escribi que deberia pasar, no segun lo que Postgres hace. Que
   esten todas en verde no dice absolutamente nada sobre si un
   inversionista puede leer el expediente de otro.

   Y ya sabemos que un doble miente en lo que no sabe imitar: el falso
   tenia .catch y el cliente de Supabase no, y eso dejo pasar a la pagina
   un fallo que la reventaba al cargar.

   El panel no tiene nada entre el navegador y la base. Eso no es un
   fallo, es la arquitectura de Supabase. Pero significa que la cerradura
   son las politicas RLS y NADA MAS: la clave anon es publica por diseno,
   cualquiera puede abrir una consola y lanzarle a la base la consulta que
   quiera. Lo unico que lo detiene es que la politica diga que no.

   Esto lo comprueba. Entra de verdad con dos cuentas y trata de hacer lo
   que no debe. Cada intento TIENE QUE FALLAR.

   SIN SDK, A PROPOSITO
   ─────────────────────────────────────────────────────────────────────
   Peticiones HTTP crudas contra PostgREST, GoTrue y Storage. Un cliente
   hostil tampoco usaria la libreria de Supabase, y la libreria podria
   estar tapandole la boca a un error.

   LO QUE HACE FALTA
   ─────────────────────────────────────────────────────────────────────
   Dos cuentas de inversionista en el proyecto de PRUEBAS, y un archivo
   pruebas/cuentas.local.json -que .gitignore no deja subir- asi:

     {
       "a": { "correo": "prueba.a@ejemplo.com", "clave": "..." },
       "b": { "correo": "prueba.b@ejemplo.com", "clave": "..." }
     }

   Las dos tienen que tener el correo confirmado y rol inversionista.
   ══════════════════════════════════════════════════════════════════════ */

'use strict';

const fs = require('fs');
const path = require('path');

const RAIZ = path.join(__dirname, '..');

/* ── el candado: esto no se acerca a la base real ──────────────────── */
function laDePruebas(){
  const cfg = fs.readFileSync(path.join(RAIZ, 'config.js'), 'utf8');
  /* Se lee el bloque 'pruebas' de config.js en vez de escribir la
     direccion aqui: una direccion copiada a mano es una direccion que
     algun dia apunta a otro sitio sin que nadie lo note. */
  /* La llave importa: el comentario de arriba tambien dice "pruebas:", y
     cortar por ahi devolvia el comentario en vez del bloque. */
  const bloque = (cfg.match(/pruebas\s*:\s*\{([\s\S]*?)\}/) || [])[1];
  if (!bloque) fin('No encuentro el bloque "pruebas" en config.js');
  const url  = (bloque.match(/SUPABASE_URL:\s*'([^']+)'/)  || [])[1];
  const anon = (bloque.match(/SUPABASE_ANON_KEY:\s*'([^']+)'/) || [])[1];
  if (!url || !anon) fin('No pude leer la direccion o la clave de "pruebas"');

  /* Y una segunda comprobacion que no depende de como este escrito el
     archivo: el "ref" que lleva dentro la propia clave tiene que ser el
     mismo que el de la direccion. Si alguien pega la clave del proyecto
     real bajo la etiqueta "pruebas", esto lo caza. */
  const ref = (url.match(/https:\/\/([a-z0-9]+)\.supabase\.co/) || [])[1];
  let dentro = null;
  try { dentro = JSON.parse(Buffer.from(anon.split('.')[1], 'base64').toString()).ref; }
  catch (e) { fin('La clave anon no se puede leer'); }
  if (!ref || dentro !== ref){
    fin('La clave no es de ' + url + ' (dice "' + dentro + '"). No sigo.');
  }
  if (String(cfg).indexOf('service_role') >= 0 && /SUPABASE_ANON_KEY:\s*'[^']*service_role/.test(cfg)){
    fin('Hay una clave service_role en config.js. Eso se salta el RLS entero.');
  }
  return { url, anon, ref };
}

function fin(msg){ console.error('\n  ' + msg + '\n'); process.exit(2); }

/* ── el marcador ───────────────────────────────────────────────────── */
const R = [];
function debeFallar(nombre, veredicto, detalle){
  R.push({ n: nombre, ok: veredicto, d: detalle });
}

/* ── HTTP crudo ────────────────────────────────────────────────────── */
let BASE = null, ANON = null;

async function pide(ruta, opciones){
  const o = opciones || {};
  const cab = Object.assign({ apikey: ANON }, o.headers || {});
  if (o.token) cab.Authorization = 'Bearer ' + o.token;
  const r = await fetch(BASE + ruta, {
    method: o.method || 'GET',
    headers: cab,
    body: o.body
  });
  let cuerpo = null;
  const txt = await r.text();
  try { cuerpo = txt ? JSON.parse(txt) : null; } catch (e) { cuerpo = txt; }
  return { estado: r.status, ok: r.ok, cuerpo };
}

function json(token, extra){
  return Object.assign({
    'Content-Type': 'application/json',
    Prefer: 'return=representation'
  }, extra || {});
}

async function entra(correo, clave){
  const r = await pide('/auth/v1/token?grant_type=password', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: correo, password: clave })
  });
  if (!r.ok || !r.cuerpo || !r.cuerpo.access_token){
    fin('No pude entrar con ' + correo + ': ' +
        (r.cuerpo && (r.cuerpo.error_description || r.cuerpo.msg) || r.estado));
  }
  return { token: r.cuerpo.access_token, id: r.cuerpo.user.id, correo };
}

/* Una lectura esta BIEN tapada si no devuelve la fila ajena. Ojo: aqui
   200 con lista vacia es un aprobado, no un fallo. PostgREST no da error
   cuando el RLS esconde filas en un select: simplemente no las trae, y
   esa es exactamente la respuesta correcta. */
function noTraeNada(r){
  if (!r.ok) return { bien: true, d: 'rechazada (' + r.estado + ')' };
  const n = Array.isArray(r.cuerpo) ? r.cuerpo.length : (r.cuerpo ? 1 : 0);
  return { bien: n === 0, d: n === 0 ? 'no trae nada' : 'TRAE ' + n + ' fila(s)' };
}

/* Una escritura esta BIEN tapada si da error o no toca ninguna fila.
   Pero "no devolvio nada" no siempre es "no cambio nada", asi que donde
   importa se vuelve a leer con la cuenta duena para confirmarlo. */
function noEscribe(r){
  if (!r.ok) return { bien: true, d: 'rechazada (' + r.estado +
    (r.cuerpo && r.cuerpo.code ? ' ' + r.cuerpo.code : '') + ')' };
  const n = Array.isArray(r.cuerpo) ? r.cuerpo.length : (r.cuerpo ? 1 : 0);
  return { bien: n === 0, d: n === 0 ? 'no toco ninguna fila' : 'ESCRIBIO ' + n + ' fila(s)' };
}

/* ══════════════════════════════════════════════════════════════════ */
async function principal(){
  const cfg = laDePruebas();
  BASE = cfg.url;
  ANON = cfg.anon;

  /* Se dice contra QUE BASE va antes de mirar nada mas, incluso si esto
     va a pararse a la linea siguiente: lo primero que hay que poder
     comprobar de un arnes que escribe en una base es a cual apunta. */
  console.log('\n  LAS CERRADURAS DE LA BASE');
  console.log('  -------------------------\n');
  console.log('  Base    : ' + BASE + '  (pruebas)');

  const fichero = path.join(__dirname, 'cuentas.local.json');
  if (!fs.existsSync(fichero)){
    fin('Falta pruebas/cuentas.local.json. Mira la cabecera de este archivo.');
  }
  const cuentas = JSON.parse(fs.readFileSync(fichero, 'utf8'));
  if (!cuentas.a || !cuentas.b) fin('cuentas.local.json necesita "a" y "b"');

  const A = await entra(cuentas.a.correo, cuentas.a.clave);
  const B = await entra(cuentas.b.correo, cuentas.b.clave);
  if (A.id === B.id) fin('Las dos cuentas son la misma. Hacen falta dos distintas.');
  console.log('  Cuenta A: ' + A.correo + '  ' + A.id);
  console.log('  Cuenta B: ' + B.correo + '  ' + B.id + '\n');

  const basura = { tramites: [], citas: [], documentos: [], archivos: [] };

  /* ── B pone el cebo ─────────────────────────────────────────────── */
  const tipo = await pide('/rest/v1/tipos_tramite?select=codigo&activo=eq.true&limit=1',
                          { token: B.token });
  const CODIGO = (Array.isArray(tipo.cuerpo) && tipo.cuerpo[0] && tipo.cuerpo[0].codigo) || null;
  if (!CODIGO) fin('No hay tipos de tramite activos en la base de pruebas.');

  /* documentos.tipo apunta a tipos_documento, no a tipos_tramite: son dos
     catalogos distintos y confundirlos deja el cebo sin poner. */
  const td = await pide('/rest/v1/tipos_documento?select=codigo&limit=1', { token: B.token });
  const TIPO_DOC = (Array.isArray(td.cuerpo) && td.cuerpo[0] && td.cuerpo[0].codigo) || null;
  if (!TIPO_DOC) fin('No hay tipos de documento en la base de pruebas.');

  const trB = await pide('/rest/v1/tramites', {
    method: 'POST', token: B.token, headers: json(),
    body: JSON.stringify({ inversionista: B.id, tipo: CODIGO, estado: 'borrador' })
  });
  if (!trB.ok || !trB.cuerpo[0]) fin('B no pudo crear su tramite: ' + JSON.stringify(trB.cuerpo));
  const TR_B = trB.cuerpo[0].id;
  basura.tramites.push({ id: TR_B, token: B.token });

  const RUTA_B = B.id + '/rls-' + Date.now() + '.txt';
  const subeB = await fetch(BASE + '/storage/v1/object/recaudos/' + RUTA_B, {
    method: 'POST',
    headers: { apikey: ANON, Authorization: 'Bearer ' + B.token, 'Content-Type': 'text/plain' },
    body: 'documento privado de B'
  });
  if (subeB.ok) basura.archivos.push({ ruta: RUTA_B, token: B.token });

  const docB = await pide('/rest/v1/documentos', {
    method: 'POST', token: B.token, headers: json(),
    body: JSON.stringify({ inversionista: B.id, tipo: TIPO_DOC, archivo: RUTA_B,
                           nombre_original: 'privado-de-b.txt', estado: 'cargado' })
  });
  const DOC_B = docB.ok && docB.cuerpo && docB.cuerpo[0] ? docB.cuerpo[0].id : null;
  if (DOC_B) basura.documentos.push({ id: DOC_B, token: B.token });

  console.log('  Cebo puesto por B: tramite ' + TR_B.slice(0, 8) +
              (subeB.ok ? ', un archivo' : ', SIN archivo (' + subeB.status + ')') +
              (DOC_B ? ', un documento' : '') + '\n');

  /* ═══ 1 · SIN ENTRAR SIQUIERA ═══════════════════════════════════ */
  for (const tabla of ['perfiles', 'tramites', 'documentos', 'citas', 'empresas', 'activos']){
    const r = await pide('/rest/v1/' + tabla + '?select=*&limit=5', {});
    /* activos es publico a proposito: el banco de activos se enseña a
       cualquiera. Los demas no. */
    if (tabla === 'activos') continue;
    const v = noTraeNada(r);
    debeFallar('sin entrar: no puede leer ' + tabla, v.bien, v.d);
  }

  /* ═══ 2 · A MIRA LO DE B ════════════════════════════════════════ */
  let r = await pide('/rest/v1/tramites?select=*&inversionista=eq.' + B.id, { token: A.token });
  let v = noTraeNada(r);
  debeFallar('A no ve los tramites de B', v.bien, v.d);

  r = await pide('/rest/v1/documentos?select=*&inversionista=eq.' + B.id, { token: A.token });
  v = noTraeNada(r);
  debeFallar('A no ve los recaudos de B', v.bien, v.d);

  r = await pide('/rest/v1/tramite_documentos?select=*&tramite=eq.' + TR_B, { token: A.token });
  v = noTraeNada(r);
  debeFallar('A no ve que recaudos colgo B de su tramite', v.bien, v.d);

  r = await pide('/rest/v1/citas?select=*&inversionista=eq.' + B.id, { token: A.token });
  v = noTraeNada(r);
  debeFallar('A no ve las citas de B', v.bien, v.d);

  r = await pide('/rest/v1/empresas?select=*&inversionista=eq.' + B.id, { token: A.token });
  v = noTraeNada(r);
  debeFallar('A no ve la ficha de empresa de B', v.bien, v.d);

  r = await pide('/rest/v1/tramite_eventos?select=*&tramite=eq.' + TR_B, { token: A.token });
  v = noTraeNada(r);
  debeFallar('A no ve el historial del tramite de B', v.bien, v.d);

  /* ═══ 3 · EL ARCHIVO DE B, POR LA RUTA DIRECTA ══════════════════ */
  const baja = await fetch(BASE + '/storage/v1/object/recaudos/' + RUTA_B, {
    headers: { apikey: ANON, Authorization: 'Bearer ' + A.token }
  });
  debeFallar('A no descarga el archivo de B sin URL firmada',
             !baja.ok, baja.ok ? 'LO DESCARGO (200)' : 'rechazada (' + baja.status + ')');

  const bajaAnon = await fetch(BASE + '/storage/v1/object/recaudos/' + RUTA_B,
                               { headers: { apikey: ANON } });
  debeFallar('sin entrar: tampoco se descarga el archivo de B',
             !bajaAnon.ok, bajaAnon.ok ? 'LO DESCARGO (200)' : 'rechazada (' + bajaAnon.status + ')');

  /* Y la firma: A no puede pedir una URL firmada de un archivo ajeno. */
  const firma = await fetch(BASE + '/storage/v1/object/sign/recaudos/' + RUTA_B, {
    method: 'POST',
    headers: { apikey: ANON, Authorization: 'Bearer ' + A.token, 'Content-Type': 'application/json' },
    body: JSON.stringify({ expiresIn: 120 })
  });
  debeFallar('A no consigue firmar una URL del archivo de B',
             !firma.ok, firma.ok ? 'LA FIRMO (200)' : 'rechazada (' + firma.status + ')');

  /* ═══ 4 · A ESCRIBE EN LA CARPETA DE B ══════════════════════════ */
  for (const destino of [B.id + '/colado.txt', B.id + '/emitidos/falsa-resolucion.txt']){
    const sube = await fetch(BASE + '/storage/v1/object/recaudos/' + destino, {
      method: 'POST',
      headers: { apikey: ANON, Authorization: 'Bearer ' + A.token, 'Content-Type': 'text/plain' },
      body: 'esto no deberia estar aqui'
    });
    if (sube.ok) basura.archivos.push({ ruta: destino, token: A.token });
    debeFallar('A no cuelga nada en ' + (destino.indexOf('emitidos') > 0 ? 'la carpeta emitidos de B' : 'la carpeta de B'),
               !sube.ok, sube.ok ? 'LO SUBIO (200)' : 'rechazada (' + sube.status + ')');
  }

  /* ═══ 5 · A SE ASCIENDE ═════════════════════════════════════════ */
  for (const rol of ['gestor', 'admin']){
    const sube = await pide('/rest/v1/perfiles?id=eq.' + A.id, {
      method: 'PATCH', token: A.token, headers: json(),
      body: JSON.stringify({ rol })
    });
    v = noEscribe(sube);
    debeFallar('A no se hace ' + rol + ' a si mismo', v.bien, v.d);
  }
  /* Y se comprueba mirando la fila, no fiandose de la respuesta. */
  const yoA = await pide('/rest/v1/perfiles?select=rol&id=eq.' + A.id, { token: A.token });
  const rolA = Array.isArray(yoA.cuerpo) && yoA.cuerpo[0] ? yoA.cuerpo[0].rol : '?';
  debeFallar('y su rol sigue siendo inversionista', rolA === 'inversionista', 'es "' + rolA + '"');

  /* ═══ 6 · A LE CAMBIA EL ROL A OTRO ═════════════════════════════ */
  const aB = await pide('/rest/v1/perfiles?id=eq.' + B.id, {
    method: 'PATCH', token: A.token, headers: json(),
    body: JSON.stringify({ rol: 'gestor' })
  });
  v = noEscribe(aB);
  debeFallar('A no le cambia el rol a B sin ser admin', v.bien, v.d);
  const yoB = await pide('/rest/v1/perfiles?select=rol&id=eq.' + B.id, { token: B.token });
  const rolB = Array.isArray(yoB.cuerpo) && yoB.cuerpo[0] ? yoB.cuerpo[0].rol : '?';
  debeFallar('y B sigue siendo lo que era', rolB === 'inversionista', 'es "' + rolB + '"');

  /* ═══ 7 · A TOCA EL TRAMITE DE B ════════════════════════════════ */
  const resuelve = await pide('/rest/v1/tramites?id=eq.' + TR_B, {
    method: 'PATCH', token: A.token, headers: json(),
    body: JSON.stringify({ estado: 'resuelto' })
  });
  v = noEscribe(resuelve);
  debeFallar('A no da por resuelto el tramite de B', v.bien, v.d);

  const borra = await pide('/rest/v1/tramites?id=eq.' + TR_B, {
    method: 'DELETE', token: A.token, headers: json()
  });
  v = noEscribe(borra);
  debeFallar('A no borra el tramite de B', v.bien, v.d);

  /* ═══ 8 · EL HISTORIAL ══════════════════════════════════════════ */
  /* A crea el suyo: el historial se escribe SOLO por disparador, y de la
     nota para abajo no se toca nada mas. */
  const trA = await pide('/rest/v1/tramites', {
    method: 'POST', token: A.token, headers: json(),
    body: JSON.stringify({ inversionista: A.id, tipo: CODIGO, estado: 'borrador' })
  });
  const TR_A = trA.ok && trA.cuerpo[0] ? trA.cuerpo[0].id : null;
  if (TR_A) basura.tramites.push({ id: TR_A, token: A.token });

  const inventado = await pide('/rest/v1/tramite_eventos', {
    method: 'POST', token: A.token, headers: json(),
    body: JSON.stringify({ tramite: TR_B, a_estado: 'resuelto', nota: 'me lo aprobe yo' })
  });
  v = noEscribe(inventado);
  debeFallar('A no escribe un evento en el tramite de B', v.bien, v.d);

  if (TR_A){
    const mio = await pide('/rest/v1/tramite_eventos', {
      method: 'POST', token: A.token, headers: json(),
      body: JSON.stringify({ tramite: TR_A, a_estado: 'resuelto', nota: 'a mano' })
    });
    v = noEscribe(mio);
    debeFallar('ni uno en el suyo: el historial lo escribe la base', v.bien, v.d);

    const evs = await pide('/rest/v1/tramite_eventos?select=id&tramite=eq.' + TR_A + '&limit=1',
                           { token: A.token });
    const EV = Array.isArray(evs.cuerpo) && evs.cuerpo[0] ? evs.cuerpo[0].id : null;
    if (EV){
      const falsea = await pide('/rest/v1/tramite_eventos?id=eq.' + EV, {
        method: 'PATCH', token: A.token, headers: json(),
        body: JSON.stringify({ a_estado: 'resuelto' })
      });
      v = noEscribe(falsea);
      debeFallar('A no reescribe el estado de un evento suyo', v.bien, v.d);

      const fecha = await pide('/rest/v1/tramite_eventos?id=eq.' + EV, {
        method: 'PATCH', token: A.token, headers: json(),
        body: JSON.stringify({ creado_en: '2020-01-01T00:00:00Z' })
      });
      v = noEscribe(fecha);
      debeFallar('ni la fecha: la traza no se retoca', v.bien, v.d);
    } else {
      debeFallar('A no reescribe el estado de un evento suyo', false, 'no encontre ningun evento');
    }
  }

  /* ═══ 9 · LA CITA CANCELADA ═════════════════════════════════════ */
  const desde = new Date(Date.now() + 86400000 * 3).toISOString().slice(0, 10);
  const hasta = new Date(Date.now() + 86400000 * 8).toISOString().slice(0, 10);
  const cita = await pide('/rest/v1/citas', {
    method: 'POST', token: A.token, headers: json(),
    body: JSON.stringify({ inversionista: A.id, desde, hasta,
                           modo: 'video', estado: 'solicitada' })
  });
  const CITA = cita.ok && cita.cuerpo[0] ? cita.cuerpo[0].id : null;
  if (CITA){
    basura.citas.push({ id: CITA, token: A.token });
    const cancela = await pide('/rest/v1/citas?id=eq.' + CITA, {
      method: 'PATCH', token: A.token, headers: json(),
      body: JSON.stringify({ estado: 'cancelada' })
    });
    debeFallar('A si puede cancelar su cita (esto TIENE que salir)',
               cancela.ok && Array.isArray(cancela.cuerpo) && cancela.cuerpo.length === 1,
               cancela.ok ? 'la cancelo' : 'no pudo (' + cancela.estado + ')');

    const resucita = await pide('/rest/v1/citas?id=eq.' + CITA, {
      method: 'PATCH', token: A.token, headers: json(),
      body: JSON.stringify({ estado: 'solicitada' })
    });
    v = noEscribe(resucita);
    debeFallar('pero no resucitarla', v.bien, v.d);

    const confirma = await pide('/rest/v1/citas?id=eq.' + CITA, {
      method: 'PATCH', token: A.token, headers: json(),
      body: JSON.stringify({ estado: 'confirmada' })
    });
    v = noEscribe(confirma);
    debeFallar('ni confirmarsela ella misma', v.bien, v.d);
  } else {
    debeFallar('A crea una cita para probar a resucitarla', false,
               'no pudo crearla: ' + JSON.stringify(cita.cuerpo).slice(0, 90));
  }

  /* ═══ 10 · EL DOCUMENTO DE B ════════════════════════════════════ */
  if (DOC_B){
    const roba = await pide('/rest/v1/documentos?id=eq.' + DOC_B, {
      method: 'PATCH', token: A.token, headers: json(),
      body: JSON.stringify({ inversionista: A.id })
    });
    v = noEscribe(roba);
    debeFallar('A no se apropia del documento de B', v.bien, v.d);
  }
  const cuelga = await pide('/rest/v1/documentos', {
    method: 'POST', token: A.token, headers: json(),
    body: JSON.stringify({ inversionista: B.id, tipo: TIPO_DOC, archivo: B.id + '/x.txt',
                           nombre_original: 'x.txt', estado: 'validado' })
  });
  v = noEscribe(cuelga);
  debeFallar('A no le cuelga un documento a B', v.bien, v.d);

  /* ── recoger ────────────────────────────────────────────────────── */
  console.log('  Recogiendo el cebo...\n');
  for (const a of basura.archivos){
    await fetch(BASE + '/storage/v1/object/recaudos/' + a.ruta, {
      method: 'DELETE', headers: { apikey: ANON, Authorization: 'Bearer ' + a.token }
    }).catch(function(){});
  }
  for (const d of basura.documentos){
    await pide('/rest/v1/documentos?id=eq.' + d.id, { method: 'DELETE', token: d.token });
  }
  for (const c of basura.citas){
    await pide('/rest/v1/citas?id=eq.' + c.id, { method: 'DELETE', token: c.token });
  }
  const sinRecoger = [];
  for (const t of basura.tramites){
    const q = await pide('/rest/v1/tramites?id=eq.' + t.id, { method: 'DELETE', token: t.token });
    if (!q.ok) sinRecoger.push(t.id);
  }

  /* ── el resultado ───────────────────────────────────────────────── */
  let mal = 0;
  for (const x of R){
    console.log('  ' + (x.ok ? 'PASA ' : 'FALLA') + '  ' + x.n);
    if (!x.ok){ mal++; console.log('          ' + x.d); }
  }
  console.log('\n  ' + (R.length - mal) + ' de ' + R.length + ' cerraduras aguantan\n');

  if (sinRecoger.length){
    console.log('  Quedaron sin borrar (la politica no deja, y esta bien que');
    console.log('  no deje): tramites ' + sinRecoger.map(function(i){ return i.slice(0,8); }).join(', '));
    console.log('  Se pueden quitar desde el panel de Supabase.\n');
  }

  if (mal){
    console.log('  Cada FALLA de arriba es un agujero de verdad en la base de');
    console.log('  pruebas, y el mismo SQL esta puesto en la real.\n');
  } else {
    console.log('  Esto prueba las politicas, no el panel. Que la base no deje');
    console.log('  hacer algo no quiere decir que el panel lo pida bien.\n');
  }
  process.exit(mal ? 1 : 0);
}

principal().catch(function(e){
  console.error('\n  Se rompio el arnes: ' + (e && e.message) + '\n');
  process.exit(2);
});
