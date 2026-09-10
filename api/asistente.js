/* ═══════════════════════════════════════════════════════════════════════
   ██  EL INTERMEDIARIO: LO ÚNICO DEL PROYECTO QUE CORRE EN UN SERVIDOR  ██
   ═══════════════════════════════════════════════════════════════════════

   Todo lo demás de la ventanilla son archivos que el navegador descarga y
   ejecuta: HTML, CSS y JavaScript. Este no. Este corre en Vercel, en una
   máquina que el usuario no ve, y existe por una razón concreta:

       LA CLAVE DE ANTHROPIC NO PUEDE VIAJAR AL NAVEGADOR.

   La clave "anon" de Supabase que está en config.js sí puede: es pública a
   propósito, y sola no abre nada —lo que protege los datos son las
   políticas RLS de la base—. La de Anthropic es lo contrario: quien la
   tenga puede gastar lo que quiera en la cuenta del CIIP. Si la pusiéramos
   en config.js bastaría con abrir "ver código fuente" para llevársela.

   Así que la clave se queda aquí, en el servidor, en una variable de
   entorno que solo Vercel conoce. El panel no la ve nunca. El panel manda
   la pregunta a esta dirección, y esta dirección devuelve la respuesta ya
   escrita.

   ─────────────────────────────────────────────────────────────────────
   QUIÉN PUEDE PREGUNTAR
   ─────────────────────────────────────────────────────────────────────
   Solo quien tenga sesión abierta en la ventanilla. El panel manda su
   token de Supabase en la cabecera Authorization, y lo primero que hace
   esta función es preguntarle a Supabase si ese token es de verdad y de
   quién es. Sin eso, la dirección quedaría abierta a internet entero y
   cualquiera podría gastar la cuenta del CIIP desde una terminal.

   ─────────────────────────────────────────────────────────────────────
   DE DÓNDE SACA LO QUE SABE
   ─────────────────────────────────────────────────────────────────────
   De la tabla public.tipos_tramite: los 33 trámites, con su organismo, su
   fase, su plazo y si ya se puede solicitar o solo se muestra. Es la MISMA
   fuente que pinta las fichas del panel, y eso es deliberado: si el
   asistente tuviera su propia copia escrita a mano, el día que
   Administración cambie un plazo la ficha diría una cosa y el asistente
   otra. Dos verdades sobre el mismo trámite son peores que una sola a
   medias.

   Lo que la tabla no sabe, el asistente no lo inventa: se le pide
   expresamente que diga que no lo sabe y remita al CIIP. Un plazo
   inventado con aplomo sale más caro que un "no le puedo decir": con un
   plazo se organiza un viaje.

   ─────────────────────────────────────────────────────────────────────
   SI FALTA LA CLAVE
   ─────────────────────────────────────────────────────────────────────
   Devuelve 503 con motivo 'sin-clave'. El panel lo entiende y sigue
   contestando con las respuestas fijas de siempre, que es lo que hace hoy.
   Nadie se queda sin asistente porque la clave no esté puesta: se queda
   con el de antes.
   ═══════════════════════════════════════════════════════════════════════ */

'use strict';

/* El paquete expone la clase de tres maneras según cómo se le cargue. Se
   prueban las tres en vez de apostar por una: equivocarse aquí revienta el
   arranque de la función, y eso solo se ve una vez desplegado. */
var paquete   = require('@anthropic-ai/sdk');
var Anthropic = paquete.Anthropic || paquete.default || paquete;

/* Los tipos de fallo se sacan del paquete y no de la clase, que es donde
   están de verdad. Esto empezó siendo `Anthropic.APIStatusError`, un nombre
   que suena bien y no existe: `instanceof undefined` no devuelve false, LANZA.
   Es decir, el manejador de errores se rompía a sí mismo, y el único fallo
   que sabía contar era el suyo. Aquí se nombran los cuatro que se usan, y si
   alguno dejara de existir el fallo saldría al cargar la función —en el
   primer despliegue— y no escondido dentro de un catch en producción. */
var APIError            = paquete.APIError;
var RateLimitError      = paquete.RateLimitError;
var AuthenticationError = paquete.AuthenticationError;
var APIConnectionError  = paquete.APIConnectionError;

/* ── LO QUE SE PUEDE AJUSTAR SIN TOCAR LA LÓGICA ────────────────────── */

var MODELO = 'claude-opus-5';

/* Cuántas preguntas puede hacer una persona en una hora. No es una
   sospecha sobre el usuario: es el tope que impide que una pestaña
   olvidada, o un bucle mal cerrado en el panel, se coma el presupuesto de
   un mes en una tarde. */
var TOPE_POR_HORA = 40;

/* La conversación que se le manda al modelo. Más allá de esto la respuesta
   no mejora y cada pregunta cuesta más que la anterior. */
var TURNOS_MAXIMOS = 12;

/* El catálogo cambia cuando Administración enciende un trámite o corrige
   un plazo: unas cuantas veces al mes, no cada minuto. Diez minutos de
   memoria ahorran una consulta a la base en cada pregunta. */
var CATALOGO_VALE_MS = 10 * 60 * 1000;

/* ── MEMORIA DE LA INSTANCIA ─────────────────────────────────────────
   Vercel puede tener varias copias de esta función a la vez, y las apaga
   cuando no se usan. Así que esto NO es un contador exacto: es una barrera
   barata que corta lo evidente. Un tope de verdad, a prueba de todo, va en
   una tabla de la base; el día que haga falta se cambia aquí dentro y el
   resto del proyecto no se entera. */
var contador = new Map();
var catalogo = { datos: null, cuando: 0 };

/* ═══════════════════════════════════════════════════════════════════════
   1 · ¿QUIÉN PREGUNTA?
   ═══════════════════════════════════════════════════════════════════════ */

async function quienPregunta(token, supabaseUrl, supabaseKey) {
  var r = await fetch(supabaseUrl + '/auth/v1/user', {
    headers: { apikey: supabaseKey, Authorization: 'Bearer ' + token }
  });
  if (!r.ok) return null;
  var usuario = await r.json();
  return usuario && usuario.id ? usuario : null;
}

/* ═══════════════════════════════════════════════════════════════════════
   2 · EL CATÁLOGO, DE LA BASE
   ═══════════════════════════════════════════════════════════════════════
   Se lee con el token del propio usuario, no con una llave de servicio.
   Así la política RLS sigue mandando: si mañana se decide que ciertos
   trámites solo los ve cierta gente, esta función se entera sola y no hay
   que acordarse de replicar la regla aquí. */

async function traerCatalogo(token, supabaseUrl, supabaseKey) {
  var ahora = Date.now();
  if (catalogo.datos && ahora - catalogo.cuando < CATALOGO_VALE_MS) {
    return catalogo.datos;
  }
  var campos = 'ref_panel,nombre,ente,fase,activo,plazo_dias';
  var r = await fetch(
    supabaseUrl + '/rest/v1/tipos_tramite?select=' + campos + '&order=ref_panel',
    { headers: { apikey: supabaseKey, Authorization: 'Bearer ' + token } }
  );
  if (!r.ok) {
    /* Que la base no conteste no debe dejar mudo al asistente: puede
       seguir contestando lo general. Se anota en el registro y se devuelve
       lo último que se supo, si es que se supo algo. */
    console.warn('[asistente] no se pudo leer el catálogo:', r.status);
    return catalogo.datos || [];
  }
  catalogo.datos = await r.json();
  catalogo.cuando = ahora;
  return catalogo.datos;
}

/* ═══════════════════════════════════════════════════════════════════════
   3 · LO QUE SABE EL ASISTENTE
   ═══════════════════════════════════════════════════════════════════════
   Este texto es el prefijo estable de cada petición, y por eso lleva
   cache_control: Anthropic lo guarda y las preguntas siguientes cuestan
   una fracción. Para que eso funcione tiene que ser BYTE A BYTE el mismo,
   así que aquí no entra nada que cambie: ni la hora, ni el nombre de quien
   pregunta, ni la pregunta misma. Todo eso va después. */

function fichaDeTramite(t) {
  var linea = t.ref_panel + ' · ' + t.nombre + ' — organismo: ' + t.ente +
              ' — fase ' + t.fase;
  linea += t.plazo_dias
    ? ' — plazo estimado: ' + t.plazo_dias + ' días'
    : ' — plazo: no consta';
  linea += t.activo
    ? ' — SE PUEDE SOLICITAR YA por la ventanilla'
    : ' — todavía NO se solicita en línea: se informa, pero el expediente aún no se abre aquí';
  return linea;
}

function loQueSabe(tramites) {
  return [
    'Eres el asistente de la Ventanilla Única del CIIP (Centro Internacional',
    'de Inversión Productiva), el organismo venezolano que acompaña a un',
    'inversionista extranjero a lo largo de los trámites que necesita para',
    'instalarse en el país.',
    '',
    'QUÉ HACES',
    'Contestas dudas sobre esos trámites: qué son, quién los emite, en qué',
    'orden van, cuánto suelen tardar y cuáles ya se pueden pedir por la',
    'ventanilla.',
    '',
    'CÓMO CONTESTAS',
    '· En el idioma en que te escriben. Si te escriben en inglés, contestas',
    '  en inglés; si en portugués, en portugués. Sin preguntar cuál prefiere.',
    '· Breve: dos o tres párrafos cortos como mucho. Quien pregunta está',
    '  delante de un trámite, no leyendo un manual.',
    '· En prosa llana. Sin listas numeradas salvo que te pidan un orden de',
    '  pasos, y sin negritas decorativas.',
    '· De usted.',
    '',
    'QUÉ NO HACES',
    '· No inventas plazos, requisitos, costos ni documentos. Si el dato no',
    '  está en la lista de abajo, dices que no lo tienes y que lo confirme',
    '  con el CIIP. Un plazo inventado con seguridad le hace más daño a la',
    '  persona que un "no le puedo decir": con un plazo se compran pasajes.',
    '· No das asesoría legal, fiscal ni migratoria, ni interpretas leyes.',
    '  Explicas el trámite; el criterio lo pone un profesional.',
    '· No hablas de nada ajeno a la ventanilla. Si te preguntan otra cosa,',
    '  lo dices en una línea y ofreces ayuda con los trámites.',
    '· No sabes nada del expediente concreto de quien te escribe: ni en qué',
    '  estado está, ni qué documentos entregó. Eso lo ve en su panel. Si te',
    '  lo preguntan, dilo así.',
    '',
    'SOBRE LOS PLAZOS',
    'Los días que aparecen abajo son estimaciones de lo que suele tardar en',
    'la práctica, no plazos legales publicados en Gaceta. Cuando cites uno,',
    'que se note: "suele tardar unas tres semanas", no "el plazo legal es de',
    '21 días".',
    '',
    'LOS TRÁMITES DE LA VENTANILLA',
    tramites.length
      ? tramites.map(fichaDeTramite).join('\n')
      : '(el catálogo no se pudo leer en este momento: contesta solo lo general, y dilo)',
    '',
    'LAS CINCO FASES',
    'Fase 1: la persona (visa, cédula, RIF personal, licencia).',
    'Fase 2: la empresa (constitución, RIF, cuenta bancaria, marca).',
    'Fase 3: la operación (registros laborales, licencias, permisos).',
    'Fase 4: los documentos de apoyo (antecedentes, apostillas, certificados).',
    'Fase 5: el registro de la inversión extranjera.'
  ].join('\n');
}

/* ═══════════════════════════════════════════════════════════════════════
   4 · LA FUNCIÓN
   ═══════════════════════════════════════════════════════════════════════ */

module.exports = async function (req, res) {

  if (req.method !== 'POST') {
    res.setHeader('Allow', 'POST');
    return res.status(405).json({ error: 'Aquí solo se escucha por POST.' });
  }

  /* ── la clave ──────────────────────────────────────────────────────
     Se comprueba antes que nada: si no está, no tiene sentido molestar a
     Supabase. El panel recibe 'sin-clave' y vuelve al asistente de
     palabras clave sin decirle nada raro al usuario. */
  var clave = process.env.ANTHROPIC_API_KEY;
  if (!clave) {
    return res.status(503).json({
      motivo: 'sin-clave',
      error: 'El asistente con IA todavía no está configurado en este despliegue.'
    });
  }

  var supabaseUrl = process.env.SUPABASE_URL;
  var supabaseKey = process.env.SUPABASE_ANON_KEY;
  if (!supabaseUrl || !supabaseKey) {
    console.error('[asistente] faltan SUPABASE_URL o SUPABASE_ANON_KEY');
    return res.status(503).json({
      motivo: 'sin-base',
      error: 'El asistente no puede comprobar la sesión ahora mismo.'
    });
  }

  /* ── la sesión ─────────────────────────────────────────────────── */
  var cabecera = req.headers.authorization || '';
  var token = cabecera.indexOf('Bearer ') === 0 ? cabecera.slice(7) : '';
  if (!token) {
    return res.status(401).json({
      motivo: 'sin-sesion',
      error: 'Hay que entrar en la ventanilla antes de preguntar.'
    });
  }

  var usuario;
  try {
    usuario = await quienPregunta(token, supabaseUrl, supabaseKey);
  } catch (e) {
    console.error('[asistente] Supabase no contestó:', e && e.message);
    return res.status(503).json({ motivo: 'sin-base', error: 'No se pudo comprobar la sesión.' });
  }
  if (!usuario) {
    return res.status(401).json({
      motivo: 'sin-sesion',
      error: 'Esa sesión ya no vale. Vuelva a entrar.'
    });
  }

  /* ── el tope ───────────────────────────────────────────────────── */
  var ahora = Date.now();
  var mio = contador.get(usuario.id);
  if (!mio || ahora - mio.desde > 60 * 60 * 1000) {
    mio = { desde: ahora, cuantas: 0 };
  }
  if (mio.cuantas >= TOPE_POR_HORA) {
    return res.status(429).json({
      motivo: 'tope',
      error: 'Ha hecho muchas preguntas seguidas. Pruebe de nuevo dentro de un rato.'
    });
  }
  mio.cuantas++;
  contador.set(usuario.id, mio);

  /* ── la pregunta ───────────────────────────────────────────────── */
  var cuerpo = req.body;
  if (typeof cuerpo === 'string') {
    try { cuerpo = JSON.parse(cuerpo); } catch (e) { cuerpo = null; }
  }
  var entrantes = (cuerpo && cuerpo.mensajes) || [];
  if (!Array.isArray(entrantes) || !entrantes.length) {
    return res.status(400).json({ error: 'No venía ninguna pregunta.' });
  }

  /* Se traduce el formato del panel al del modelo, se recorta a los
     últimos turnos y se limita el largo de cada uno. Lo segundo no es
     desconfianza: un pegado accidental de treinta páginas convierte una
     pregunta de céntimos en una de varios dólares. */
  var mensajes = entrantes
    .slice(-TURNOS_MAXIMOS)
    .filter(function (m) { return m && typeof m.texto === 'string' && m.texto.trim(); })
    .map(function (m) {
      return {
        role: m.papel === 'asistente' ? 'assistant' : 'user',
        content: String(m.texto).slice(0, 4000)
      };
    });

  if (!mensajes.length || mensajes[mensajes.length - 1].role !== 'user') {
    return res.status(400).json({ error: 'La conversación tiene que terminar en una pregunta.' });
  }

  /* ── la respuesta ──────────────────────────────────────────────── */
  var tramites = [];
  try {
    tramites = await traerCatalogo(token, supabaseUrl, supabaseKey);
  } catch (e) {
    console.warn('[asistente] catálogo:', e && e.message);
  }

  var anthropic = new Anthropic({ apiKey: clave });

  try {
    var salida = await anthropic.beta.messages.create({
      model: MODELO,
      max_tokens: 4000,

      /* effort 'low' porque esto es una conversación de mostrador, no un
         problema difícil: contesta en unos segundos en vez de en medio
         minuto, y cuesta bastante menos. El razonamiento sigue encendido
         —en este modelo viene así de fábrica— porque apagarlo tiene sus
         propias rarezas y no compensa. */
      output_config: { effort: 'low' },

      /* Si el modelo declina contestar algo, Anthropic reencamina la
         pregunta a otro modelo suyo en vez de devolver un hueco. En un
         mostrador público eso importa: el usuario recibe una respuesta, no
         un error que no sabe interpretar. */
      betas: ['server-side-fallback-2026-07-01'],
      fallbacks: 'default',

      system: [{
        type: 'text',
        text: loQueSabe(tramites),
        cache_control: { type: 'ephemeral' }
      }],
      messages: mensajes
    });

    if (salida.stop_reason === 'refusal') {
      return res.status(200).json({
        respuesta: 'Esa consulta no la puedo atender. Si es sobre un trámite de la ventanilla, pruebe a formularla de otra manera; si no, escríbale al CIIP.'
      });
    }

    var texto = salida.content
      .filter(function (b) { return b.type === 'text'; })
      .map(function (b) { return b.text; })
      .join('\n')
      .trim();

    if (!texto) {
      return res.status(502).json({ error: 'El asistente no devolvió nada. Inténtelo otra vez.' });
    }

    return res.status(200).json({ respuesta: texto });

  } catch (e) {

    /* Cada fallo se cuenta distinto porque significan cosas distintas, y
       tratarlos todos igual deja al panel sin saber si esperar o rendirse.

       EL ORDEN NO ES ADORNO. Los cuatro heredan de APIError, así que hay
       que ir del más concreto al más general. APIConnectionError también
       es un APIError: preguntando por el general primero, "no llegamos a
       Anthropic" saldría como "Anthropic contestó mal", que manda a mirar
       en el sitio equivocado. */

    if (e instanceof RateLimitError) {
      console.warn('[asistente] Anthropic nos frenó');
      return res.status(429).json({ motivo: 'tope', error: 'Hay mucha gente preguntando. Pruebe en un minuto.' });
    }
    if (e instanceof AuthenticationError) {
      console.error('[asistente] la clave no vale');
      return res.status(503).json({ motivo: 'sin-clave', error: 'El asistente con IA no está bien configurado.' });
    }
    if (e instanceof APIConnectionError) {
      console.error('[asistente] no se llegó a Anthropic:', e && e.message);
      return res.status(504).json({ error: 'El asistente tardó demasiado. Inténtelo otra vez.' });
    }
    if (e instanceof APIError) {
      console.error('[asistente] Anthropic devolvió', e.status, e.message);
      return res.status(502).json({ error: 'El asistente no está disponible ahora mismo.' });
    }

    console.error('[asistente] fallo inesperado:', e && e.stack);
    return res.status(500).json({ error: 'Algo falló al preparar la respuesta.' });
  }
};
