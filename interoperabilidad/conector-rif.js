/* ═══════════════════════════════════════════════════════════════════
   EL CONECTOR · RIF de la empresa ante el SENIAT
   ═══════════════════════════════════════════════════════════════════
   Traduce un tramite de la VUI a lo que pide contrato-rif-empresa.md, y
   traduce la respuesta a lo unico que le importa al panel: a que estado
   pasa el tramite.

   No decide nada mas. No escribe en la base, no manda correos, no
   reintenta por su cuenta. Devuelve una ACCION y quien lo llama la
   ejecuta. Asi se puede probar entero sin base de datos, y asi se muda
   a un servicio de NestJS sin tocarle una linea.

   Sin dependencias: fetch y AbortSignal vienen en Node.
   ═══════════════════════════════════════════════════════════════════ */
'use strict';

/* Lo generico -pedir por HTTP, la espera creciente, y los codigos que
   significan lo mismo venga el organismo que venga- vive en comun.js.
   Se saco al escribir el segundo conector, no antes: con uno solo no
   habia forma de saber que parte era del SENIAT y cual era de "hablar
   con un organismo". Aqui se queda lo que solo vale para este tramite,
   que es lo caro de acordar. */
const { ACCIONES, pide, esperaSiguiente, fallo, fueraDelContrato } = require('./comun');

/* ── de tramite de la VUI a expediente del ente ──────────────────── */
function armaExpediente(tramite, recaudos, solicitante) {
  const d = tramite.datos || {};
  return {
    origen: 'CIIP-VUI',
    referencia: tramite.id,
    tramite: 'rif_empresa',
    presentado_en: tramite.enviado_en || null,
    solicitante: {
      nombre: (solicitante && solicitante.nombre) || '',
      representante: (solicitante && solicitante.representante) || '',
      documento: (solicitante && solicitante.documento) || ''
    },
    empresa: {
      razon_social:        d.razon_social || '',
      numero_registro:     d.numero_registro || '',
      fecha_constitucion:  d.fecha_constitucion || '',
      capital_social:      d.capital_social || '',
      actividad_economica: d.actividad_economica || '',
      direccion_fiscal:    d.direccion_fiscal || ''
    },
    /* Los archivos van por URL firmada, no dentro del cuerpo: el sha256
       es lo que deja probar despues que lo que recibieron es lo que el
       inversionista subio. */
    recaudos: (recaudos || []).map((r) => ({
      tipo: r.tipo,
      nombre: r.nombre_original,
      sha256: r.sha256 || '',
      url: r.url_firmada
    }))
  };
}

/* ── 1 · presentar ───────────────────────────────────────────────── */
async function presenta(tramite, recaudos, solicitante, cfg) {
  const expediente = armaExpediente(tramite, recaudos, solicitante);

  const r = await pide(cfg.base + '/expedientes', {
    method: 'POST',
    headers: Object.assign({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + cfg.token,
      /* El id del tramite ES la llave. Reintentar con la misma no
         presenta el expediente dos veces. */
      'Idempotency-Key': tramite.id
    }, cfg.cabeceras || {}),
    body: JSON.stringify(expediente)
  }, cfg.msLimite);

  const c = r.cuerpo || {};

  /* 202 y 409 acaban igual. El 409 dice "esto ya estaba", que es la
     respuesta correcta a un reintento y no un error. */
  if (r.codigo === 202 || r.codigo === 409) {
    if (!c.expediente_ente) {
      return { accion: ACCIONES.ALERTAR, motivo: 'El ente acepto el expediente pero no devolvio su numero.' };
    }
    return {
      accion: ACCIONES.PRESENTADO,
      expediente_ente: c.expediente_ente,
      yaEstaba: r.codigo === 409
    };
  }

  /* Lo miraron y falta algo. Es una respuesta del negocio, no una
     averia: llega al inversionista como una devolucion con su nota,
     igual que cuando la escribe un gestor. */
  if (r.codigo === 422) {
    return {
      accion: ACCIONES.DEVOLVER,
      nota: c.motivo || 'El organismo devolvio la solicitud sin indicar el motivo.',
      campo: c.campo || null
    };
  }

  /* Credenciales, saturacion, caida: significan lo mismo venga el
     organismo que venga, asi que lo dice comun.js. */
  const generico = fallo(r, cfg);
  if (generico) return generico;

  return fueraDelContrato(r, 'presentar');
}

/* ── 2 · preguntar en que quedo ──────────────────────────────────── */
async function consulta(expedienteEnte, cfg) {
  const r = await pide(cfg.base + '/expedientes/' + encodeURIComponent(expedienteEnte), {
    method: 'GET',
    headers: Object.assign({ 'Authorization': 'Bearer ' + cfg.token }, cfg.cabeceras || {})
  }, cfg.msLimite);

  const c = r.cuerpo || {};

  if (r.codigo === 0 || r.codigo === 429 || r.codigo >= 500) {
    return { accion: ACCIONES.ESPERAR, motivo: 'El organismo no contesto; se vuelve a preguntar.' };
  }
  if (r.codigo === 404) {
    /* Grave: creiamos tener un expediente alli y no consta. Puede ser
       que lo anularan, o que nunca entrara. No lo resuelve el codigo. */
    return { accion: ACCIONES.ALERTAR, motivo: 'El organismo no reconoce el expediente ' + expedienteEnte + '.' };
  }
  if (r.codigo !== 200) {
    return { accion: ACCIONES.ALERTAR, motivo: 'Respuesta fuera del contrato al consultar: ' + r.codigo + '.' };
  }

  if (c.estado === 'en_proceso') return { accion: ACCIONES.ESPERAR };

  if (c.estado === 'rechazado') {
    return {
      accion: ACCIONES.DEVOLVER,
      nota: c.motivo || 'El organismo rechazo la solicitud sin indicar el motivo.'
    };
  }

  if (c.estado === 'aprobado') {
    /* Sin el documento no hay nada que entregarle al inversionista, y
       darlo por resuelto seria decirle que ya tiene un papel que no
       tiene. */
    if (!c.documento || !c.documento.url) {
      return { accion: ACCIONES.ALERTAR, motivo: 'El organismo aprobo pero no adjunto el documento emitido.' };
    }
    return {
      accion: ACCIONES.RESUELTO,
      documento: c.documento,
      rif_asignado: c.rif_asignado || null
    };
  }

  return { accion: ACCIONES.ALERTAR, motivo: 'Estado desconocido: "' + c.estado + '".' };
}

module.exports = { ACCIONES, presenta, consulta, armaExpediente, esperaSiguiente };
