/* ═══════════════════════════════════════════════════════════════════
   PRUEBAS DEL TRABAJADOR
   ═══════════════════════════════════════════════════════════════════
   El conector ya esta probado: sabe leer al organismo. Aqui se prueba lo
   otro, que es lo que faltaba: que con esa lectura se HAGA lo que toca.

   Un conector se equivoca interpretando. Un trabajador se equivoca
   actuando, y sus errores son peores porque quedan escritos: un tramite
   movido al estado que no era, un expediente presentado dos veces, o uno
   que se queda callado para siempre porque nadie lo reprogramo.

   El deposito es de mentira y APUNTA TODO lo que le piden. Asi cada
   prueba puede decir no solo "acabo bien", sino "se escribio esto y no
   se escribio aquello", que es donde estan los fallos de verdad.

       node interoperabilidad/prueba-trabajador.js
   ═══════════════════════════════════════════════════════════════════ */
'use strict';
const { arranca } = require('./simulador.js');
const T = require('./trabajador.js');

let pasan = 0, fallan = 0;
function ok(que, cierto, obtuvo, esperaba) {
  if (cierto) { pasan++; console.log('  PASA  ' + que); return; }
  fallan++;
  console.log('  FALLA ' + que);
  console.log('          esperaba : ' + esperaba);
  console.log('          obtuvo   : ' + obtuvo);
}
function igual(que, a, b) { ok(que, a === b, String(a), String(b)); }


/* ── el deposito de mentira ────────────────────────────────────────
   Guarda el tramite en memoria y lleva un cuaderno de todo lo que se le
   pidio, en orden. El orden importa: guardar el numero de expediente
   DESPUES de mover el tramite dejaria una ventana en la que el trabajo
   ya esta cerrado y el numero no esta escrito, y si el proceso se cae
   ahi, el expediente queda perdido en el organismo. */
function depositoDeMentira(tramite) {
  const cuaderno = [];
  return {
    cuaderno,
    tramiteGuardado: tramite,
    async tramite()      { return this.tramiteGuardado; },
    async solicitante()  { return { nombre: 'Bianchi Agroindustrias, C.A.',
                                    representante: 'Franklin Reyes',
                                    documento: 'V-12345678' }; },
    async recaudos()     { return [
      { tipo: 'acta_constitutiva', nombre_original: 'acta.pdf', sha256: '9f86d081', url_firmada: 'https://x/a' },
      { tipo: 'rif_personal',      nombre_original: 'rif.pdf',  sha256: 'a1b2c3d4', url_firmada: 'https://x/b' },
      { tipo: 'domicilio_empresa', nombre_original: 'dom.pdf',  sha256: 'e5f6a7b8', url_firmada: 'https://x/c' }
    ]; },
    async pendientes()   { return []; },
    async mueve(id, estado, nota)  { cuaderno.push({ que: 'mueve', estado, nota }); },
    async guardaExpediente(id, n)  { cuaderno.push({ que: 'expediente', n });
                                     this.tramiteGuardado.expediente_ente = n; },
    async guardaEmitido(id, doc)   { cuaderno.push({ que: 'emitido', doc }); },
    async cierra()                 { cuaderno.push({ que: 'cierra' }); },
    async reprograma(id, s, m)     { cuaderno.push({ que: 'reprograma', esperaS: s, motivo: m }); },
    async alerta(id, m)            { cuaderno.push({ que: 'alerta', motivo: m }); }
  };
}

/* Cada caso, con SU id. No es cosmetico: el id del tramite ES la llave de
   idempotencia, asi que repetirlo entre casos hace que el simulador
   conteste "esto ya estaba" al segundo y siguientes, sin mirar siquiera
   el X-Simular. Se descubrio con seis pruebas en rojo que en realidad
   estaban demostrando que la idempotencia funciona. */
let nCaso = 0;
function idNuevo() {
  nCaso++;
  return '11111111-2222-3333-4444-' + String(nCaso).padStart(12, '0');
}

function unTramite(extra) {
  return Object.assign({
    id: idNuevo(),
    tipo: 'rif_empresa',
    conector: 'rif_empresa',
    estado: 'en_revision',
    enviado_en: '2026-08-20T14:02:11Z',
    datos: {
      razon_social: 'Bianchi Agroindustrias, C.A.',
      numero_registro: '12, Tomo 45-A',
      fecha_constitucion: '2026-07-14',
      capital_social: '150000.00',
      actividad_economica: 'Procesamiento de cacao',
      direccion_fiscal: 'Av. Principal, Galpon 4, Charallave, Miranda'
    }
  }, extra || {});
}

/* El trabajo apunta al tramite que le toca: se le pasa el de su caso. */
function unTrabajo(tramite, extra) {
  return Object.assign({
    id: 'trabajo-1',
    tramite: tramite.id,
    tarea: 'presentar',
    intentos: 0,
    llave: '11111111-2222-3333-4444-555555555555'
  }, extra || {});
}

/* Del cuaderno: el primer apunte de un tipo, o null. */
function apunte(dep, que) {
  return dep.cuaderno.find(function (a) { return a.que === que; }) || null;
}
function hubo(dep, que) { return apunte(dep, que) !== null; }


(async function () {
  const puerto = await arranca(0);
  const base = 'http://127.0.0.1:' + puerto;
  const cfg = { base: base, token: 'de-mentira', msLimite: 4000 };
  const forzar = function (caso) {
    return Object.assign({}, cfg, { cabeceras: { 'X-Simular': caso } });
  };

  console.log('\n  PRUEBAS DEL TRABAJADOR');
  console.log('  ----------------------\n');
  console.log('  SENIAT de mentira en ' + base + '\n');

  /* ── 1 · presentar, y que salga bien ───────────────────────────── */
  {
    const tr = unTramite();
    const dep = depositoDeMentira(tr);
    const r = await T.atiende(unTrabajo(tr), dep, cfg);

    igual('presentar: el tramite queda ante el ente', r.hizo, 'presentado');
    igual('presentar: y se le pone ese estado',
          (apunte(dep, 'mueve') || {}).estado, 'ante_el_ente');
    ok('presentar: se guarda el numero que dio el organismo',
       hubo(dep, 'expediente') && !!apunte(dep, 'expediente').n,
       String((apunte(dep, 'expediente') || {}).n), 'un numero');
    ok('presentar: el trabajo se cierra', hubo(dep, 'cierra'), 'no', 'si');

    /* El numero ANTES del estado. Si se cae el proceso entre las dos,
       con este orden queda un tramite que sigue en revision y un
       expediente ya abierto: se reintenta con la misma llave y el ente
       devuelve el mismo numero. Al reves quedaria un tramite "ante el
       ente" sin numero, que no se puede consultar ni reintentar. */
    const iNum = dep.cuaderno.findIndex(function (a) { return a.que === 'expediente'; });
    const iEst = dep.cuaderno.findIndex(function (a) { return a.que === 'mueve'; });
    ok('presentar: el numero se escribe ANTES de mover el estado',
       iNum >= 0 && iNum < iEst, iNum + ' vs ' + iEst, 'el numero primero');
  }

  /* ── 2 · presentar dos veces ───────────────────────────────────── */
  {
    const tr = unTramite();
    const dep = depositoDeMentira(tr);
    await T.atiende(unTrabajo(tr), dep, cfg);
    const primero = apunte(dep, 'expediente').n;

    /* El MISMO tramite, mandado otra vez. Deposito nuevo porque el
       proceso se cayo y no recuerda nada; el ente si. */
    const dep2 = depositoDeMentira(unTramite({ id: tr.id }));
    const r2 = await T.atiende(unTrabajo(tr, { intentos: 1 }), dep2, cfg);

    igual('reintento: no se abre un expediente nuevo',
          apunte(dep2, 'expediente').n, primero);
    igual('reintento: y el tramite acaba igual', r2.hizo, 'presentado');
    ok('reintento: la nota dice que ya constaba',
       /ya constaba/i.test((apunte(dep2, 'mueve') || {}).nota || ''),
       (apunte(dep2, 'mueve') || {}).nota, 'que ya constaba');
  }

  /* ── 3 · lo devuelven ──────────────────────────────────────────── */
  {
    const tr = unTramite();
    const dep = depositoDeMentira(tr);
    const r = await T.atiende(unTrabajo(tr), dep, forzar('falta-recaudo'));

    igual('devuelto: el tramite vuelve al inversionista', r.hizo, 'devuelto');
    igual('devuelto: con ese estado', (apunte(dep, 'mueve') || {}).estado, 'devuelto');
    ok('devuelto: y con el motivo que dio el organismo',
       !!(apunte(dep, 'mueve') || {}).nota,
       (apunte(dep, 'mueve') || {}).nota, 'un motivo');
    ok('devuelto: no se guarda ningun numero de expediente',
       !hubo(dep, 'expediente'), 'lo guardo', 'ninguno');
    ok('devuelto: el trabajo se cierra, no se reintenta',
       hubo(dep, 'cierra') && !hubo(dep, 'reprograma'), 'reintento', 'cerrado');
  }

  /* ── 4 · el organismo no contesta ──────────────────────────────── */
  {
    const tr = unTramite();
    const dep = depositoDeMentira(tr);
    const r = await T.atiende(unTrabajo(tr), dep, forzar('caido'));

    igual('caido: se reintenta', r.hizo, 'reintentar');
    ok('caido: con una espera escrita en la cola',
       (apunte(dep, 'reprograma') || {}).esperaS > 0,
       String((apunte(dep, 'reprograma') || {}).esperaS), 'mas de cero');
    ok('caido: y el tramite NO se toca',
       !hubo(dep, 'mueve'), 'lo movio', 'sin tocar');
    ok('caido: ni se cierra el trabajo',
       !hubo(dep, 'cierra'), 'lo cerro', 'sigue pendiente');
  }

  /* La espera crece con los intentos. Si no creciera, un organismo caido
     recibiria doce peticiones en tres minutos. */
  {
    const trA = unTramite();
    const a = depositoDeMentira(trA);
    await T.atiende(unTrabajo(trA, { intentos: 1 }), a, forzar('caido'));
    const trB = unTramite();
    const b = depositoDeMentira(trB);
    await T.atiende(unTrabajo(trB, { intentos: 5 }), b, forzar('caido'));
    ok('caido: la espera crece entre intentos',
       apunte(b, 'reprograma').esperaS > apunte(a, 'reprograma').esperaS,
       apunte(a, 'reprograma').esperaS + ' -> ' + apunte(b, 'reprograma').esperaS,
       'que suba');
  }

  /* Y no para siempre. Un tramite reintentandose sin fin es un tramite
     perdido que nadie mira. */
  {
    const tr = unTramite();
    const dep = depositoDeMentira(tr);
    const r = await T.atiende(unTrabajo(tr, { intentos: T.INTENTOS_MAX - 1 }), dep, forzar('caido'));
    igual('caido: al agotar los intentos se alerta, no se reintenta', r.hizo, 'alertado');
    ok('caido: y el aviso dice que se agotaron',
       /agotaron/i.test((apunte(dep, 'alerta') || {}).motivo || ''),
       (apunte(dep, 'alerta') || {}).motivo, 'que se agotaron');
    ok('caido: el tramite sigue sin tocarse', !hubo(dep, 'mueve'), 'lo movio', 'sin tocar');
  }

  /* ── 5 · el problema es nuestro ────────────────────────────────── */
  {
    const tr = unTramite();
    const dep = depositoDeMentira(tr);
    const r = await T.atiende(unTrabajo(tr), dep, forzar('sin-credencial'));

    igual('credenciales: se alerta al CIIP', r.hizo, 'alertado');
    ok('credenciales: y el tramite del inversionista NO se mueve',
       !hubo(dep, 'mueve'), 'lo movio', 'sin tocar');
    ok('credenciales: tampoco se cierra el trabajo',
       !hubo(dep, 'cierra'), 'lo cerro', 'esperando a una persona');
  }

  /* ── 6 · preguntar en que quedo ────────────────────────────────── */
  {
    /* Primero se presenta, para tener numero de expediente. */
    const tr = unTramite();
    const dep = depositoDeMentira(tr);
    await T.atiende(unTrabajo(tr), dep, cfg);
    dep.cuaderno.length = 0;

    const r = await T.atiende(unTrabajo(tr, { id: 'trabajo-2', tarea: 'consultar' }), dep, cfg);
    igual('consultar: al principio sigue en proceso', r.hizo, 'esperando');
    ok('consultar: se vuelve a preguntar, no cada minuto',
       (apunte(dep, 'reprograma') || {}).esperaS >= 600,
       String((apunte(dep, 'reprograma') || {}).esperaS), 'al menos diez minutos');
    ok('consultar: y el tramite no se toca', !hubo(dep, 'mueve'), 'lo movio', 'sin tocar');
  }

  /* Lo aprueban. */
  {
    const tr = unTramite();
    const dep = depositoDeMentira(tr);
    await T.atiende(unTrabajo(tr), dep, cfg);
    dep.cuaderno.length = 0;

    const r = await T.atiende(unTrabajo(tr, { id: 'trabajo-2', tarea: 'consultar' }),
                              dep, forzar('aprobado'));
    igual('aprobado: el tramite se resuelve', r.hizo, 'resuelto');
    igual('aprobado: con ese estado', (apunte(dep, 'mueve') || {}).estado, 'resuelto');
    ok('aprobado: y el documento emitido entra en la boveda',
       hubo(dep, 'emitido') && !!apunte(dep, 'emitido').doc,
       String(hubo(dep, 'emitido')), 'que entre');

    /* El documento ANTES del estado, por lo mismo que el numero: un
       tramite "resuelto" cuyo documento no llego a guardarse le dice al
       inversionista que tiene un papel que no tiene. */
    const iDoc = dep.cuaderno.findIndex(function (a) { return a.que === 'emitido'; });
    const iEst = dep.cuaderno.findIndex(function (a) { return a.que === 'mueve'; });
    ok('aprobado: el documento se guarda ANTES de dar por resuelto',
       iDoc >= 0 && iDoc < iEst, iDoc + ' vs ' + iEst, 'el documento primero');
  }

  /* Lo rechazan. */
  {
    const tr = unTramite();
    const dep = depositoDeMentira(tr);
    await T.atiende(unTrabajo(tr), dep, cfg);
    dep.cuaderno.length = 0;

    const r = await T.atiende(unTrabajo(tr, { id: 'trabajo-2', tarea: 'consultar' }),
                              dep, forzar('rechazado'));
    igual('rechazado: vuelve al inversionista', r.hizo, 'devuelto');
    ok('rechazado: con el motivo del organismo',
       !!(apunte(dep, 'mueve') || {}).nota,
       (apunte(dep, 'mueve') || {}).nota, 'un motivo');
  }

  /* Consultar algo que nunca se presento. */
  {
    const tr = unTramite();
    const dep = depositoDeMentira(tr);
    const r = await T.atiende(unTrabajo(tr, { tarea: 'consultar' }), dep, cfg);
    igual('consultar sin numero de expediente: se alerta', r.hizo, 'alertado');
    ok('consultar sin numero: no se inventa una presentacion',
       !hubo(dep, 'mueve') && !hubo(dep, 'expediente'), 'hizo algo', 'nada');
  }

  /* ── 7 · lo que no se entiende ─────────────────────────────────── */
  {
    const tr = unTramite({ tipo: 'marca', conector: null });
    const dep = depositoDeMentira(tr);
    const r = await T.atiende(unTrabajo(tr), dep, cfg);
    igual('un tramite sin conector se alerta, no se adivina', r.hizo, 'alertado');
    ok('y no se le toca el estado', !hubo(dep, 'mueve'), 'lo movio', 'sin tocar');
  }

  {
    const tr = unTramite();
    const dep = depositoDeMentira(tr);
    const r = await T.atiende(unTrabajo(tr, { tarea: 'bailar' }), dep, cfg);
    igual('una tarea que no existe se alerta', r.hizo, 'alertado');
  }

  {
    /* El tramite ya no esta: se borro la cuenta. No es una averia y no
       se alerta a nadie; el trabajo se cierra y ya. */
    const dep = depositoDeMentira(null);
    const r = await T.atiende(unTrabajo(unTramite()), dep, cfg);
    igual('un tramite que ya no existe cierra el trabajo sin alertar', r.hizo, 'sin_tramite');
    ok('y sin dar la alarma', !hubo(dep, 'alerta'), 'alerto', 'callado');
  }

  {
    /* Un deposito que revienta. El trabajador no puede propagar la
       excepcion: se llevaria por delante los trabajos que vienen
       detras. */
    const tr = unTramite();
    const dep = depositoDeMentira(tr);
    dep.recaudos = async function () { throw new Error('la base no contesta'); };
    const r = await T.atiende(unTrabajo(tr), dep, cfg);
    igual('si el deposito revienta, se alerta y no se propaga', r.hizo, 'alertado');
    ok('y el aviso lleva dentro que paso',
       /no contesta/.test((apunte(dep, 'alerta') || {}).motivo || ''),
       (apunte(dep, 'alerta') || {}).motivo, 'el mensaje del fallo');
  }

  /* ── 8 · una vuelta entera ─────────────────────────────────────── */
  {
    const tr = unTramite();
    const dep = depositoDeMentira(tr);
    dep.pendientes = async function () {
      return [unTrabajo(tr, { id: 'a' }), unTrabajo(tr, { id: 'b', tarea: 'bailar' })];
    };
    const hechos = await T.unaVuelta(dep, cfg);
    igual('una vuelta atiende todos los pendientes', hechos.length, 2);
    ok('y uno malo no se lleva por delante a los demas',
       hechos[0].hizo === 'presentado' && hechos[1].hizo === 'alertado',
       hechos.map(function (h) { return h.hizo; }).join(', '),
       'presentado, alertado');
  }

  console.log('');
  console.log('  ' + pasan + ' de ' + (pasan + fallan) + ' pruebas superadas');
  console.log('');
  console.log('  Esto prueba que la decision del conector se ejecuta bien.');
  console.log('  Que se guarde de verdad en Postgres lo prueba PROBAR-SQL.bat,');
  console.log('  y que el organismo conteste asi, nadie: no hay convenio aun.');
  console.log('');
  process.exit(fallan ? 1 : 0);
})();
