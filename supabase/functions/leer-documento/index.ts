// ══════════════════════════════════════════════════════════════════════
//  EL LECTOR DE DOCUMENTOS
//  Una función del Supabase de pruebas, que es donde se monta lo nuevo.
// ══════════════════════════════════════════════════════════════════════
//
//  QUÉ HACE
//
//  Recibe un papel —el acta constitutiva, el pasaporte, un poder— y
//  devuelve lo que ese papel dice, para que el panel proponga las
//  casillas ya rellenas y la persona las repase antes de enviar.
//
//  No decide nada. Devuelve lo que hay escrito; quien confirma es quien
//  rellena la solicitud, y quien responde de ella también.
//
//  ────────────────────────────────────────────────────────────────────
//  CÓMO SE DESPLIEGA
//  ────────────────────────────────────────────────────────────────────
//
//  Hace falta la CLI de Supabase una sola vez:
//
//      npm install -g supabase
//      supabase login
//
//  Y luego, desde la carpeta del proyecto:
//
//      supabase link --project-ref ifhdzxetixhrzqixcfbe
//      supabase secrets set LECTOR_CLAVE=sk-ant-...
//      supabase functions deploy leer-documento --no-verify-jwt
//
//  El --no-verify-jwt es a propósito y conviene entenderlo: sin él la
//  función exige el testigo de sesión de Supabase, que el panel tiene
//  pero que complica la primera prueba. En el proyecto de pruebas da
//  igual —no hay nada real dentro—. ANTES DE LLEVAR ESTO A LA BASE DE
//  VERDAD hay que quitarlo y comprobar la sesión: una función abierta
//  que llama a un modelo de pago es una factura que puede escribir
//  cualquiera.
//
//  El proyecto es el de PRUEBAS —'ifhdzxetixhrzqixcfbe'—, el que
//  config.js describe como «aquí se monta lo nuevo y se puede romper».
//  Al de verdad no sube nada todavía.
//
//  Cuando esté desplegada, en config.js:
//
//      pruebas: { ...
//        LECTOR_URL: 'https://ifhdzxetixhrzqixcfbe.supabase.co/functions/v1/leer-documento'
//      }
//
//  y el cuadro de «si ya tienes el papel» aparece en local. En 'real'
//  se queda vacío hasta que el CIIP diga lo contrario.
//
//  ────────────────────────────────────────────────────────────────────
//  LO QUE HAY QUE DECIDIR, Y NO ES TÉCNICO
//  ────────────────────────────────────────────────────────────────────
//
//  Esta función manda el documento a un tercero para que lo lea. Un acta
//  constitutiva lleva nombres, cédulas, capital y domicilios; un poder
//  lleva la identidad del apoderado. Mientras esto viva sólo en el
//  proyecto de pruebas, los papeles que viajan son de mentira y no hay
//  nada que decidir. El día que se apunte a la base real, sí lo hay, y
//  lo dice el CIIP.
//
//  ────────────────────────────────────────────────────────────────────
//  EL TRATO CON EL PANEL
//  ────────────────────────────────────────────────────────────────────
//
//  Entra, como formulario:
//      archivo    el PDF o la foto
//      casillas   {"acta_constitutiva": ["razon_social", "capital_social"],
//                  "domicilio_empresa": ["direccion_fiscal"]}
//
//                 O sea: qué papeles acepta ESTE trámite y, en cada uno,
//                 qué casillas hay que buscar. La tabla vive en el panel
//                 —LEE_DE— y viaja con cada llamada, para que no haya dos
//                 copias que un día digan cosas distintas.
//
//  Sale:
//      {"doc": "acta_constitutiva",
//       "campos": {"razon_social": "Inversiones Montebello, C.A."}}
//
//  Si no reconoce el papel:
//      {"doc": null, "campos": {}}
//
//  El panel lo dice y sigue: se sube a mano y no pasa nada más.
//
//  ────────────────────────────────────────────────────────────────────
//  LA REGLA QUE HACE QUE ESTO SIRVA
//  ────────────────────────────────────────────────────────────────────
//
//  Lo que no esté LITERALMENTE escrito en el papel, no se devuelve. Una
//  casilla vacía se teclea en diez segundos; una casilla con un dígito
//  inventado viaja al organismo, vuelve devuelta semanas después y nadie
//  sabe por qué. El coste de los dos errores no se parece en nada, y por
//  eso el aviso al modelo insiste tanto.
//
// ══════════════════════════════════════════════════════════════════════

/* Las fechas van en ISO —2024-06-18— porque el panel las mete en tres
   listas y necesita los tres números por separado. Y los importes sin
   puntos ni símbolo: la casilla es un texto, pero un «Bs. 500.000,00»
   copiado tal cual no se parece a lo que el organismo espera. */
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

/* El panel puede abrirse desde localhost, desde file:// y desde el sitio
   publicado. Mientras esto viva en el proyecto de pruebas, cualquiera de
   los tres vale; al llevarlo a la base real hay que cerrar esta lista al
   dominio del panel. */
const CABECERAS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS'
};

function contesta(cuerpo: unknown, estado = 200): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { ...CABECERAS, 'Content-Type': 'application/json' }
  });
}

/* Un base64 de un PDF de varios megas hecho con String.fromCharCode(...)
   y el array entero revienta la pila. Se hace a trozos. */
function aBase64(bytes: Uint8Array): string {
  let s = '';
  const TROZO = 0x8000;
  for (let i = 0; i < bytes.length; i += TROZO) {
    s += String.fromCharCode(...bytes.subarray(i, i + TROZO));
  }
  return btoa(s);
}

Deno.serve(async (peticion: Request) => {
  if (peticion.method === 'OPTIONS') return new Response('ok', { headers: CABECERAS });
  if (peticion.method !== 'POST') return contesta({ error: 'solo POST' }, 405);

  const clave = Deno.env.get('LECTOR_CLAVE');
  if (!clave) {
    /* Sin clave no se finge que se ha leído: el panel dice que no ha
       podido y la persona sube el papel a mano. */
    console.error('[lector] falta LECTOR_CLAVE: supabase secrets set LECTOR_CLAVE=...');
    return contesta({ error: 'el lector no está configurado' }, 500);
  }

  let archivo: File | null = null;
  let casillas: Record<string, string[]> = {};
  try {
    const sobre = await peticion.formData();
    archivo = sobre.get('archivo') as File;
    casillas = JSON.parse(String(sobre.get('casillas') || '{}'));
  } catch (e) {
    return contesta({ error: 'no se entiende la petición: ' + (e as Error).message }, 400);
  }

  if (!archivo || !archivo.size) return contesta({ error: 'no viene ningún archivo' }, 400);
  /* Diez megas. Un pasaporte fotografiado con el móvil pesa dos o tres;
     por encima de esto casi siempre es un escaneo sin comprimir, y el
     coste de leerlo no se corresponde con lo que aporta. */
  if (archivo.size > 10 * 1024 * 1024) return contesta({ error: 'el archivo pasa de 10 MB' }, 413);

  const papeles = Object.keys(casillas);
  if (!papeles.length) return contesta({ doc: null, campos: {} });

  const tipo = archivo.type || 'application/pdf';
  const esPdf = tipo === 'application/pdf';
  const datos = aBase64(new Uint8Array(await archivo.arrayBuffer()));

  const queBusco = papeles
    .map((p) => '  - ' + p + ': ' + casillas[p].join(', '))
    .join('\n');

  let respuesta: Response;
  try {
    respuesta = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': clave,
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
              text: 'Tipos de documento posibles, y qué buscar en cada uno:\n' +
                    queBusco + '\n\n' +
                    'Devuelve el JSON con el tipo que sea y sólo los datos que estén ' +
                    'escritos en el documento.'
            }
          ]
        }]
      })
    });
  } catch (e) {
    console.error('[lector] no se pudo llamar al modelo:', (e as Error).message);
    return contesta({ error: 'el lector no contesta' }, 502);
  }

  if (!respuesta.ok) {
    const detalle = await respuesta.text();
    console.error('[lector] el modelo contestó ' + respuesta.status + ': ' + detalle.slice(0, 400));
    return contesta({ error: 'el lector contestó ' + respuesta.status }, 502);
  }

  const dicho = await respuesta.json();
  const texto = (dicho.content || []).map((c: { text?: string }) => c.text || '').join('');

  let leido: { doc?: string | null; campos?: Record<string, unknown> };
  try {
    /* A veces el JSON viene envuelto en un bloque de código. Se busca el
       objeto en vez de exigir que la respuesta sea exactamente él: fallar
       por unas comillas de más sería tirar una lectura buena. */
    const trozo = texto.slice(texto.indexOf('{'), texto.lastIndexOf('}') + 1);
    leido = JSON.parse(trozo);
  } catch (e) {
    console.error('[lector] no se entiende lo que devolvió:', texto.slice(0, 300));
    return contesta({ doc: null, campos: {} });
  }

  /* Y aquí se recorta lo que venga de más. El modelo puede devolver un
     tipo que no estaba en la lista o una casilla que este trámite no
     pide; escribirla en el formulario sería inventar. Esto es lo último
     que toca el dato antes de que salga, así que es donde tiene que
     estar la tijera. */
  const doc = leido.doc && papeles.indexOf(leido.doc) >= 0 ? leido.doc : null;
  if (!doc) return contesta({ doc: null, campos: {} });

  const permitidas = casillas[doc] || [];
  const campos: Record<string, string> = {};
  for (const [k, v] of Object.entries(leido.campos || {})) {
    if (permitidas.indexOf(k) < 0) continue;
    if (v === null || v === undefined || String(v).trim() === '') continue;
    campos[k] = String(v).trim();
  }

  return contesta({ doc, campos });
});
