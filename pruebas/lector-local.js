/* ══════════════════════════════════════════════════════════════════════
   EL LECTOR DE DOCUMENTOS, CORRIENDO EN TU MAQUINA
   Se lanza con:  LECTOR-LOCAL.bat
   ══════════════════════════════════════════════════════════════════════

   Es la MISMA funcion que supabase/functions/leer-documento/index.ts, con
   el mismo aviso al modelo y la misma tijera al final, pero escuchando en
   tu ordenador. Sirve para probar el lector de verdad SIN desplegar nada:
   sin Supabase, sin Docker y sin subir una linea.

   Si algun dia las dos dejan de decir lo mismo, manda la de Supabase: esta
   existe para mirar, aquella para funcionar.

   ────────────────────────────────────────────────────────────────────
   LO QUE HACE FALTA
   ────────────────────────────────────────────────────────────────────

   Una clave de la API de Anthropic, de console.anthropic.com. Se pasa por
   el entorno y NO se escribe en ningun archivo del proyecto:

       set LECTOR_CLAVE=sk-ant-...
       node pruebas\lector-local.js

   o directamente con LECTOR-LOCAL.bat, que la pide al arrancar si no esta.

   Sin clave no arranca, y lo dice. Fingir que lee seria peor que no estar.

   ────────────────────────────────────────────────────────────────────
   COMO SE ENCHUFA AL PANEL
   ────────────────────────────────────────────────────────────────────

   En config.js, en el proyecto de PRUEBAS -que es el que usa localhost-:

       LECTOR_URL: 'http://localhost:8787/leer'

   Y ya esta: abres el panel en http://localhost:8080, entras en un
   tramite y sueltas un papel.

   OJO CON DEJARLO PUESTO. Esa linea apunta a tu ordenador: para
   cualquier otra persona que abra el panel en local, el cuadro
   aparecera y no contestara nadie. Es para probar, no para subir.

   ────────────────────────────────────────────────────────────────────
   POR QUE NO USA NINGUNA BIBLIOTECA
   ────────────────────────────────────────────────────────────────────

   El resto del proyecto se abre con doble clic y no tiene node_modules.
   Un lector de pruebas que obligue a instalar dependencias deja de ser
   una prueba rapida. Node trae desde la 18 todo lo que hace falta: fetch,
   FormData y el lector de multipart, que aqui se aprovecha construyendo
   una Response con el cuerpo crudo y pidiendole formData().
   ══════════════════════════════════════════════════════════════════════ */

const http = require('http');

const PUERTO = Number(process.env.LECTOR_PUERTO || 8787);
const CLAVE = process.env.LECTOR_CLAVE || '';

/* ── EL MODO DE MENTIRA ──
   Para probar la TUBERIA mientras no hay clave. El navegador manda el
   archivo de verdad, este servidor lo recibe y lo desempaqueta de verdad,
   y contesta con datos fijos. Lo unico que no ocurre es la lectura.

   Prueba lo que el lector de mentira de dentro de la pagina NO puede
   probar, porque aquel vive en el mismo navegador: que el CORS deja pasar,
   que el multipart llega entero, que el contrato encaja por los dos lados
   y que la tijera recorta lo que sobra.

   Se enciende a proposito -LECTOR_DE_MENTIRA=1- y solo cuando NO hay
   clave: con clave manda la clave, para que nadie se quede leyendo datos
   inventados sin darse cuenta. Y lo dice en cada respuesta, en el campo
   'dementira', por si algo lo pinta en pantalla algun dia. */
const DE_MENTIRA = !CLAVE && process.env.LECTOR_DE_MENTIRA === '1';

/* Un acta y un comprobante de domicilio inventados, con la forma que
   tendria lo leido de verdad: fechas en ISO y el importe sin puntos. */
const INVENTADO = {
  acta_constitutiva: {
    razon_social:          'Inversiones Montebello, C.A.',
    numero_registro:       '48, Tomo 112-A',
    registro_mercantil:    'Registro Mercantil Primero del Distrito Capital',
    fecha_constitucion:    '2024-06-18',
    fecha_protocolizacion: '2024-06-25',
    capital_social:        '500000',
    objeto_social:         'Empaque, frio y exportacion de frutas',
    domicilio_social:      'Av. Libertador, Torre 4, Caracas',
    socios:                'Franklin Reyes (60%), Ana Rojas (40%)',
    tipo_sociedad:         'C.A.'
  },
  domicilio_empresa: {
    direccion_fiscal: 'Av. Libertador, Torre 4, piso 9, Caracas'
  },
  pasaporte: {
    numero_pasaporte: 'YB1234567',
    pais_emisor:      'Italia',
    vence_pasaporte:  '2031-08-14',
    fecha_nacimiento: '1979-02-03'
  }
};

if (!CLAVE && !DE_MENTIRA) {
  console.error('');
  console.error('  FALTA LA CLAVE');
  console.error('  ---------------');
  console.error('  Este lector llama a la API de Anthropic y necesita una clave tuya.');
  console.error('  Se saca en console.anthropic.com y se pasa asi:');
  console.error('');
  console.error('      set LECTOR_CLAVE=sk-ant-...');
  console.error('      node pruebas\\lector-local.js');
  console.error('');
  console.error('  No la escribas en ningun archivo del proyecto.');
  console.error('');
  console.error('  Y si lo que quieres es probar la tuberia mientras llega la clave:');
  console.error('');
  console.error('      set LECTOR_DE_MENTIRA=1');
  console.error('      node pruebas\\lector-local.js');
  console.error('');
  console.error('  Ese modo NO lee el documento: contesta datos inventados.');
  console.error('');
  process.exit(1);
}

/* El mismo aviso que la funcion de Supabase. Si cambia alli, cambia aqui. */
const AVISO = `Eres un lector de documentos oficiales venezolanos para el CIIP.

Te llega un documento y una lista de datos que hay que buscar en él.

REGLAS, por orden de importancia:

1. Devuelve SOLO lo que esté literalmente escrito en el documento. No
   deduzcas, no completes, no corrijas. Si un dato no está, o no se lee
   con seguridad, NO lo incluyas en la respuesta.

   Una casilla vacía se rellena a mano en diez segundos. Una casilla con
   un dígito inventado viaja a un organismo del Estado, vuelve devuelta
   semanas después, y nadie sabe por qué. No se parecen en nada.

2. Di qué tipo de documento es, eligiendo SOLO de la lista que te dan.
   Si no es ninguno de ellos, devuelve doc: null y campos vacíos. Es
   mejor decir «no sé qué es esto» que acertar a medias.

3. Las fechas, en formato AAAA-MM-DD.

4. Los importes, sólo el número, sin símbolo de moneda ni separadores de
   miles: 500000, no «Bs. 500.000,00».

5. Los nombres y razones sociales, EXACTAMENTE como están escritos,
   incluidas las abreviaturas: «Inversiones Montebello, C.A.» no se
   convierte en «Inversiones Montebello Compañía Anónima».

Contesta únicamente con un objeto JSON, sin explicaciones ni texto
alrededor:

{"doc": "<tipo>", "campos": {"<casilla>": "<lo que dice el documento>"}}`;

const CABECERAS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json; charset=utf-8'
};

function contesta(res, cuerpo, estado = 200) {
  res.writeHead(estado, CABECERAS);
  res.end(JSON.stringify(cuerpo));
}

function cuerpoEntero(req) {
  return new Promise((resuelve, falla) => {
    const trozos = [];
    let cuanto = 0;
    req.on('data', (t) => {
      cuanto += t.length;
      /* Diez megas, igual que la funcion de Supabase. Se corta aqui y no
         despues de haberlo leido entero: si alguien manda un archivo de
         cien megas, el corte tiene que llegar antes que la memoria. */
      if (cuanto > 10 * 1024 * 1024) {
        falla(new Error('el archivo pasa de 10 MB'));
        req.destroy();
        return;
      }
      trozos.push(t);
    });
    req.on('end', () => resuelve(Buffer.concat(trozos)));
    req.on('error', falla);
  });
}

const servidor = http.createServer(async (req, res) => {
  if (req.method === 'OPTIONS') { res.writeHead(204, CABECERAS); return res.end(); }
  if (req.method !== 'POST') return contesta(res, { error: 'solo POST' }, 405);

  let archivo = null;
  let casillas = {};
  try {
    const crudo = await cuerpoEntero(req);
    /* El truco para no traerse una biblioteca de multipart: se envuelve el
       cuerpo crudo en una Response con su content-type y se le pide
       formData(), que Node ya sabe hacer. */
    const sobre = await new Response(crudo, {
      headers: { 'content-type': req.headers['content-type'] || '' }
    }).formData();
    archivo = sobre.get('archivo');
    casillas = JSON.parse(String(sobre.get('casillas') || '{}'));
  } catch (e) {
    console.log('  · peticion que no se entiende: ' + e.message);
    return contesta(res, { error: 'no se entiende la peticion: ' + e.message }, 400);
  }

  if (!archivo || !archivo.size) return contesta(res, { error: 'no viene ningun archivo' }, 400);

  const papeles = Object.keys(casillas);
  if (!papeles.length) return contesta(res, { doc: null, campos: {} });

  const tipo = archivo.type || 'application/pdf';
  const esPdf = tipo === 'application/pdf';
  const datos = Buffer.from(await archivo.arrayBuffer()).toString('base64');

  console.log('  · leyendo «' + (archivo.name || 'sin nombre') + '» (' +
              Math.round(archivo.size / 1024) + ' KB), buscando: ' + papeles.join(', '));

  if (DE_MENTIRA) {
    /* Se elige el papel por el NOMBRE del archivo, no por su contenido:
       aqui no se lee nada. Asi se puede probar a proposito un documento
       que se reconoce, uno que no, y uno que falla. */
    const n = String(archivo.name || '').toLowerCase();
    let doc = null;
    if (!/nose|desconocid/.test(n)) {
      doc = papeles.filter((p) => n.indexOf(p.split('_')[0]) >= 0)[0] ||
            papeles.filter((p) => INVENTADO[p])[0] || null;
    }
    if (!doc || !INVENTADO[doc]) {
      console.log('  · (de mentira) no reconoce el documento');
      return contesta(res, { doc: null, campos: {}, dementira: true });
    }
    const dejo = {};
    for (const c of (casillas[doc] || [])) {
      if (INVENTADO[doc][c] !== undefined) dejo[c] = INVENTADO[doc][c];
    }
    console.log('  · (de mentira) es un «' + doc + '», ' + Object.keys(dejo).length +
                ' casillas: ' + (Object.keys(dejo).join(', ') || 'ninguna'));
    return contesta(res, { doc, campos: dejo, dementira: true });
  }

  const queBusco = papeles.map((p) => '  - ' + p + ': ' + casillas[p].join(', ')).join('\n');

  let respuesta;
  try {
    respuesta = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': CLAVE,
        'anthropic-version': '2023-06-01'
      },
      body: JSON.stringify({
        model: 'claude-sonnet-5',
        max_tokens: 1024,
        system: AVISO,
        messages: [{
          role: 'user',
          content: [
            esPdf
              ? { type: 'document', source: { type: 'base64', media_type: 'application/pdf', data: datos } }
              : { type: 'image', source: { type: 'base64', media_type: tipo, data: datos } },
            {
              type: 'text',
              text: 'Tipos de documento posibles, y qué buscar en cada uno:\n' + queBusco +
                    '\n\nDevuelve el JSON con el tipo que sea y sólo los datos que estén ' +
                    'escritos en el documento.'
            }
          ]
        }]
      })
    });
  } catch (e) {
    console.log('  · no se pudo llamar al modelo: ' + e.message);
    return contesta(res, { error: 'el lector no contesta' }, 502);
  }

  if (!respuesta.ok) {
    const detalle = await respuesta.text();
    console.log('  · el modelo contesto ' + respuesta.status + ': ' + detalle.slice(0, 300));
    /* El detalle vuelve tambien por HTTP y no solo a la consola: quien
       esta mirando el panel no siempre tiene delante la ventana negra, y
       un '400' a secas no dice que arreglar. Esto es el lector de PRUEBAS;
       el de Supabase no lo hace, que alli el detalle es para el registro. */
    return contesta(res, { error: 'el lector contesto ' + respuesta.status,
                           detalle: detalle.slice(0, 500) }, 502);
  }

  const dicho = await respuesta.json();
  const texto = (dicho.content || []).map((c) => c.text || '').join('');

  let leido;
  try {
    const trozo = texto.slice(texto.indexOf('{'), texto.lastIndexOf('}') + 1);
    leido = JSON.parse(trozo);
  } catch (e) {
    console.log('  · no se entiende lo que devolvio: ' + texto.slice(0, 200));
    return contesta(res, { doc: null, campos: {} });
  }

  /* La tijera, igual que en la funcion de Supabase: fuera el tipo que no
     estaba en la lista y fuera las casillas que este tramite no pide.
     Escribirlas en el formulario seria inventar. */
  const doc = leido.doc && papeles.indexOf(leido.doc) >= 0 ? leido.doc : null;
  if (!doc) {
    console.log('  · no reconoce el documento');
    return contesta(res, { doc: null, campos: {} });
  }

  const permitidas = casillas[doc] || [];
  const campos = {};
  for (const [k, v] of Object.entries(leido.campos || {})) {
    if (permitidas.indexOf(k) < 0) continue;
    if (v === null || v === undefined || String(v).trim() === '') continue;
    campos[k] = String(v).trim();
  }

  console.log('  · es un «' + doc + '», ' + Object.keys(campos).length + ' casillas: ' +
              (Object.keys(campos).join(', ') || 'ninguna'));
  contesta(res, { doc, campos });
});

servidor.listen(PUERTO, () => {
  console.log('');
  console.log('  EL LECTOR DE DOCUMENTOS, EN TU MAQUINA');
  console.log('  --------------------------------------');
  if (DE_MENTIRA) {
    console.log('');
    console.log('  *** MODO DE MENTIRA: NO LEE NADA ***');
    console.log('  Contesta datos inventados. Sirve para probar la tuberia');
    console.log('  -el envio, el CORS, el contrato y el relleno- mientras');
    console.log('  llega la clave. Con clave puesta, este modo no se enciende.');
    console.log('');
  }
  console.log('  Escuchando en  http://localhost:' + PUERTO + '/leer');
  console.log('');
  console.log('  Para que el panel lo use, en config.js, proyecto "pruebas":');
  console.log("      LECTOR_URL: 'http://localhost:" + PUERTO + "/leer'");
  console.log('');
  console.log('  Y el panel en  http://localhost:8080/ciip-ventanilla-unica-local.html');
  console.log('  Para parar: cierra esta ventana.');
  console.log('');
});
