/* ═══════════════════════════════════════════════════════════════════
   PRUEBAS DEL CONECTOR
   ═══════════════════════════════════════════════════════════════════
   Levanta el SENIAT de mentira, le manda un tramite de verdad -con los
   campos que el panel recoge en el c6- y comprueba que CADA respuesta
   lleva al estado que dice el contrato.

   Lo que se prueba no es que el conector sepa mandar: es que sepa
   interpretar. Un conector se equivoca leyendo, no escribiendo.

       node interoperabilidad/prueba.js
   ═══════════════════════════════════════════════════════════════════ */
'use strict';
const { arranca, servidor } = require('./simulador.js');
const K = require('./conector-rif.js');

let pasan = 0, fallan = 0;
function ok(que, cierto, obtuvo, esperaba) {
  if (cierto) { pasan++; console.log('  PASA  ' + que); return; }
  fallan++;
  console.log('  FALLA ' + que);
  console.log('          esperaba : ' + esperaba);
  console.log('          obtuvo   : ' + obtuvo);
}
function igual(que, a, b) { ok(que, a === b, String(a), String(b)); }

/* Un tramite como los que hay en la base: los seis campos del c6 y sus
   tres recaudos, con el acta que sale del tramite anterior. */
function tramiteDePrueba(id) {
  return {
    id: id,
    tipo: 'rif_empresa',
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
  };
}
const RECAUDOS = [
  { tipo: 'acta_constitutiva', nombre_original: 'acta-constitutiva.pdf', sha256: '9f86d081', url_firmada: 'https://x/acta?exp=1' },
  { tipo: 'rif_personal',      nombre_original: 'rif-personal.pdf',      sha256: 'a1b2c3d4', url_firmada: 'https://x/rif?exp=1' },
  { tipo: 'domicilio_empresa', nombre_original: 'domicilio.pdf',         sha256: 'e5f6a7b8', url_firmada: 'https://x/dom?exp=1' }
];
const SOLICITANTE = { nombre: 'Bianchi Agroindustrias, C.A.', representante: 'Franklin Reyes', documento: 'V-12345678' };

(async function () {
  const puerto = await arranca(0);
  const base = 'http://127.0.0.1:' + puerto;
  const cfg = { base: base, token: 'de-mentira', msLimite: 4000 };

  console.log('\n  PRUEBAS DEL CONECTOR · RIF de la empresa');
  console.log('  ----------------------------------------\n');
  console.log('  SENIAT de mentira en ' + base + '\n');

  /* ═══ lo que se manda ═══ */
  (function () {
    const e = K.armaExpediente(tramiteDePrueba('t-forma'), RECAUDOS, SOLICITANTE);
    igual('envio: la referencia es el id del tramite', e.referencia, 't-forma');
    igual('envio: van los seis campos de la empresa', Object.keys(e.empresa).length, 6);
    igual('envio: y los tres recaudos', e.recaudos.length, 3);
    ok('envio: los archivos van por URL firmada, no dentro del cuerpo',
       !!e.recaudos[0].url && !('contenido' in e.recaudos[0]),
       Object.keys(e.recaudos[0]).join(','), 'tipo,nombre,sha256,url');
    ok('envio: cada archivo lleva su huella, para poder probar cual era',
       e.recaudos.every((r) => !!r.sha256), 'alguno sin sha256', 'todos con sha256');
  })();

  /* ═══ presentar ═══ */
  const r1 = await K.presenta(tramiteDePrueba('t-001'), RECAUDOS, SOLICITANTE, cfg);
  igual('presentar: lo reciben y el tramite queda ante el ente', r1.accion, K.ACCIONES.PRESENTADO);
  ok('presentar: y se guarda el numero que ellos dan',
     /^SENIAT-2026-\d{5}$/.test(r1.expediente_ente || ''), r1.expediente_ente, 'SENIAT-2026-00001');

  /* La prueba que justifica la Idempotency-Key: el mismo tramite otra
     vez tiene que dar el MISMO expediente, no uno nuevo. */
  const r2 = await K.presenta(tramiteDePrueba('t-001'), RECAUDOS, SOLICITANTE, cfg);
  igual('reintento: no se presenta dos veces el mismo expediente', r2.accion, K.ACCIONES.PRESENTADO);
  igual('reintento: y el numero es el mismo de antes', r2.expediente_ente, r1.expediente_ente);
  ok('reintento: el conector sabe que ya estaba', r2.yaEstaba === true, String(r2.yaEstaba), 'true');

  /* Faltan datos: es una devolucion, no una averia. */
  const flaco = tramiteDePrueba('t-002');
  delete flaco.datos.actividad_economica;
  const r3 = await K.presenta(flaco, RECAUDOS, SOLICITANTE, cfg);
  igual('datos incompletos: se devuelve al inversionista', r3.accion, K.ACCIONES.DEVOLVER);
  ok('datos incompletos: con un motivo que se pueda leer',
     /actividad_economica/.test(r3.nota || ''), r3.nota, 'nombra el campo que falta');

  const r4 = await K.presenta(tramiteDePrueba('t-003'), RECAUDOS, SOLICITANTE,
                              Object.assign({}, cfg, { cabeceras: { 'X-Simular': 'falta-recaudo' } }));
  igual('recaudo mal: tambien se devuelve, no se reintenta', r4.accion, K.ACCIONES.DEVOLVER);
  igual('recaudo mal: y se dice cual', r4.campo, 'recaudos.acta_constitutiva');

  /* ═══ los tres fallos que NO se devuelven ═══ */
  const r5 = await K.presenta(tramiteDePrueba('t-004'), RECAUDOS, SOLICITANTE,
                              Object.assign({}, cfg, { cabeceras: { 'X-Simular': 'sin-credencial' } }));
  igual('credenciales: es problema nuestro, no del inversionista', r5.accion, K.ACCIONES.ALERTAR);

  const r6 = await K.presenta(tramiteDePrueba('t-005'), RECAUDOS, SOLICITANTE,
                              Object.assign({}, cfg, { cabeceras: { 'X-Simular': 'saturado' } }));
  igual('saturado: se reintenta', r6.accion, K.ACCIONES.REINTENTAR);

  const r7 = await K.presenta(tramiteDePrueba('t-006'), RECAUDOS, SOLICITANTE,
                              Object.assign({}, cfg, { cabeceras: { 'X-Simular': 'caido' } }));
  igual('caido: se reintenta', r7.accion, K.ACCIONES.REINTENTAR);

  /* El peor: ni contesta ni cierra. El conector tiene que rendirse solo. */
  const r8 = await K.presenta(tramiteDePrueba('t-007'), RECAUDOS, SOLICITANTE,
                              Object.assign({}, cfg, { msLimite: 700, cabeceras: { 'X-Simular': 'mudo' } }));
  igual('mudo: se corta el plazo y se reintenta', r8.accion, K.ACCIONES.REINTENTAR);
  ok('mudo: y no queda dicho que llego, porque no se sabe',
     r8.accion !== K.ACCIONES.PRESENTADO, r8.accion, 'reintentar');

  /* La espera crece, pero con techo. */
  ok('reintentos: la espera crece entre intentos',
     K.esperaSiguiente(2) > K.esperaSiguiente(1),
     K.esperaSiguiente(1) + 's -> ' + K.esperaSiguiente(2) + 's', 'creciente');
  igual('reintentos: y no pasa de cinco minutos', K.esperaSiguiente(20), 300);

  /* ═══ consultar ═══ */
  const c1 = await K.consulta(r1.expediente_ente, cfg);
  igual('consulta: al principio sigue en proceso', c1.accion, K.ACCIONES.ESPERAR);
  await K.consulta(r1.expediente_ente, cfg);
  const c3 = await K.consulta(r1.expediente_ente, cfg);
  igual('consulta: cuando lo aprueban, el tramite se resuelve', c3.accion, K.ACCIONES.RESUELTO);
  ok('consulta: y llega el documento emitido, con su huella',
     !!(c3.documento && c3.documento.url && c3.documento.sha256),
     JSON.stringify(c3.documento || null), 'url y sha256');
  ok('consulta: con el RIF asignado', /^J-\d{8}-\d$/.test(c3.rif_asignado || ''),
     c3.rif_asignado, 'J-40123456-7');

  const r9 = await K.presenta(tramiteDePrueba('t-008'), RECAUDOS, SOLICITANTE, cfg);
  const c4 = await K.consulta(r9.expediente_ente,
                              Object.assign({}, cfg, { cabeceras: { 'X-Simular': 'rechazado' } }));
  igual('consulta: si lo rechazan, se devuelve al inversionista', c4.accion, K.ACCIONES.DEVOLVER);
  ok('consulta: con el motivo que dio el organismo',
     /objeto social/.test(c4.nota || ''), c4.nota, 'el motivo del ente');

  const c5 = await K.consulta('SENIAT-2026-99999', cfg);
  igual('consulta: un expediente que no consta es para alertar', c5.accion, K.ACCIONES.ALERTAR);

  /* ═══ ═══ */
  console.log('\n  ' + pasan + ' de ' + (pasan + fallan) + ' pruebas superadas\n');
  console.log('  Esto prueba el conector contra el contrato, no contra el SENIAT.');
  console.log('  Cuando el SENIAT conteste, cambia la direccion y las credenciales;');
  console.log('  si su forma es otra, se le pone un traductor delante.\n');

  servidor.close();
  process.exit(fallan ? 1 : 0);
})();
