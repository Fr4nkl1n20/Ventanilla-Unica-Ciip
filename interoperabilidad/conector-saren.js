/* ═══════════════════════════════════════════════════════════════════════
   CONECTOR · CONSTITUCION DE COMPANIA (SAREN)
   ═══════════════════════════════════════════════════════════════════════
   Node 18 o mayor. Cumple contrato-constitucion.md.

   EL SEGUNDO, Y POR QUE IMPORTA QUE LO SEA
   ─────────────────────────────────────────────────────────────────────
   El primero -conector-rif.js- sirvio para saber que se puede acordar
   antes de que un organismo conteste. Este sirve para comprobar que el
   patron aguanta con un tramite de otra forma, y para saber QUE parte era
   generica de verdad: eso esta ahora en comun.js, y se saco al escribir
   este, no adivinandolo antes.

   Lo que NO se pudo compartir, y es lo caro: que campos lleva el
   expediente, que significa cada 422, y en que estados de los suyos cae
   cada respuesta.

   LA DECISION QUE EL PRIMERO NO TENIA
   ─────────────────────────────────────────────────────────────────────
   La denominacion puede estar ocupada. El panel ya pide una alternativa
   -en el mismo formulario, desde antes de que existiera este contrato- y
   eso ahorra un viaje entero: si la primera esta tomada y la segunda no,
   el registro reserva la segunda y el tramite sigue, en vez de volver al
   inversionista para que escriba otro nombre y empiece de nuevo.

   Por eso aqui hay que devolver CUAL quedo reservada. Sin ese dato el
   CIIP no sabria con que nombre se esta constituyendo la compania, y lo
   descubriria al recibir el acta.
   ═══════════════════════════════════════════════════════════════════════ */
'use strict';

const { ACCIONES, pide, esperaSiguiente, fallo, fueraDelContrato } = require('./comun');


/* ── de tramite de la VUI a expediente del registro ──────────────── */
function armaExpediente(tramite, recaudos, solicitante) {
  const d = tramite.datos || {};
  return {
    origen: 'CIIP-VUI',
    referencia: tramite.id,
    tramite: 'constitucion',
    presentado_en: tramite.enviado_en || null,
    solicitante: {
      nombre: (solicitante && solicitante.nombre) || '',
      representante: (solicitante && solicitante.representante) || '',
      documento: (solicitante && solicitante.documento) || ''
    },
    compania: {
      denominacion:     d.denominacion || '',
      /* Opcional de verdad: si no la dieron, se manda vacia y el registro
         decidira. Inventarle una alternativa seria constituir una
         compania con un nombre que nadie eligio. */
      denominacion_alt: d.denominacion_alt || '',
      tipo_sociedad:    d.tipo_sociedad || '',
      capital_social:   d.capital_social || '',
      objeto_social:    d.objeto_social || '',
      domicilio_social: d.domicilio_social || '',
      socios:           d.socios || ''
    },
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

  const r = await pide(cfg.base + '/constituciones', {
    method: 'POST',
    headers: Object.assign({
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ' + cfg.token,
      'Idempotency-Key': tramite.id
    }, cfg.cabeceras || {}),
    body: JSON.stringify(expediente)
  }, cfg.msLimite);

  const c = r.cuerpo || {};

  if (r.codigo === 202 || r.codigo === 409) {
    if (!c.expediente_ente) {
      return { accion: ACCIONES.ALERTAR,
               motivo: 'El registro acepto el expediente pero no devolvio su numero.' };
    }
    /* Sin saber cual reservaron, el expediente sigue pero nadie sabe como
       se llama la compania. Es tan grave como no tener numero. */
    if (!c.denominacion_reservada) {
      return { accion: ACCIONES.ALERTAR,
               motivo: 'El registro no dijo que denominacion reservo para ' +
                       c.expediente_ente + '.' };
    }
    return {
      accion: ACCIONES.PRESENTADO,
      expediente_ente: c.expediente_ente,
      denominacion: c.denominacion_reservada,
      eraLaAlternativa: c.era_la_alternativa === true,
      yaEstaba: r.codigo === 409
    };
  }

  /* Lo miraron y algo no cuadra. Es una respuesta del negocio, no una
     averia: llega al inversionista como una devolucion con su nota. */
  if (r.codigo === 422) {
    return {
      accion: ACCIONES.DEVOLVER,
      /* Las dos denominaciones tomadas se distingue del resto porque es
         lo unico que el inversionista arregla escribiendo un nombre
         nuevo, y la nota tiene que decirselo asi. */
      nota: c.motivo || (c.error === 'denominaciones_ocupadas'
        ? 'Las denominaciones propuestas ya estan registradas. Hay que elegir otra.'
        : 'El registro devolvio la solicitud sin indicar el motivo.'),
      campo: c.campo || null,
      esDenominacion: c.error === 'denominaciones_ocupadas'
    };
  }

  const generico = fallo(r, cfg);
  if (generico) return generico;

  return fueraDelContrato(r, 'presentar');
}


/* ── 2 · preguntar en que quedo ──────────────────────────────────── */
async function consulta(expedienteEnte, cfg) {
  const r = await pide(cfg.base + '/constituciones/' + encodeURIComponent(expedienteEnte), {
    method: 'GET',
    headers: Object.assign({ 'Authorization': 'Bearer ' + cfg.token }, cfg.cabeceras || {})
  }, cfg.msLimite);

  const c = r.cuerpo || {};

  /* Igual que en el RIF: al CONSULTAR, no contestar no es un fallo que
     haya que reintentar de otra manera, es simplemente que se vuelve a
     preguntar mas tarde. Nada se ha mandado, asi que nada se puede
     duplicar. */
  if (r.codigo === 0 || r.codigo === 429 || r.codigo >= 500) {
    return { accion: ACCIONES.ESPERAR,
             motivo: 'El registro no contesto; se vuelve a preguntar.' };
  }
  if (r.codigo === 404) {
    return { accion: ACCIONES.ALERTAR,
             motivo: 'El registro no reconoce el expediente ' + expedienteEnte + '.' };
  }
  if (r.codigo !== 200) {
    return fueraDelContrato(r, 'consultar');
  }

  if (c.estado === 'en_proceso') return { accion: ACCIONES.ESPERAR };

  if (c.estado === 'observado') {
    return {
      accion: ACCIONES.DEVOLVER,
      nota: c.motivo || 'El registrador observo el documento sin indicar el motivo.'
    };
  }

  if (c.estado === 'registrado') {
    /* Los TRES o ninguno. Una compania "constituida" sin acta, o sin
       tomo y numero, es una compania que no consta en ningun sitio, y
       darla por resuelta seria mandar al inversionista a abrir una
       cuenta bancaria con las manos vacias. */
    const falta = [];
    if (!c.documento || !c.documento.url) falta.push('el acta');
    if (!c.tomo)   falta.push('el tomo');
    if (!c.numero) falta.push('el numero');
    if (falta.length) {
      return { accion: ACCIONES.ALERTAR,
               motivo: 'El registro dio por registrada la compania pero falta ' +
                       falta.join(' y ') + '.' };
    }
    return {
      accion: ACCIONES.RESUELTO,
      documento: c.documento,
      tomo: c.tomo,
      numero: c.numero,
      registro: 'Tomo ' + c.tomo + ', número ' + c.numero
    };
  }

  return { accion: ACCIONES.ALERTAR, motivo: 'Estado desconocido: "' + c.estado + '".' };
}


module.exports = { ACCIONES, presenta, consulta, armaExpediente, esperaSiguiente };
