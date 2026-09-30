/* Pega los supabase-*.sql en uno solo, en el orden que prueba
   PROBAR-SQL.bat, y lo deja en TODO-EN-ORDEN.sql.

   Existe porque pegar veintitantas veces en el SQL Editor de Supabase es
   donde se salta uno sin darse cuenta, y saltarse el 15 no da error: da
   una pantalla vacia tres dias despues.

   El archivo que sale NO se edita a mano. Si cambia un supabase-*.sql se
   vuelve a correr esto:

       node pruebas/juntar-sql.js

   Que el archivo unico entra de una sola vez lo comprueba PROBAR-SQL.bat
   corriendo los archivos por separado: es el mismo texto y el mismo orden.

   ── LO QUE PASO CON LAS CONSULTAS, PARA QUE NO SE REPITA ──────────────
   El SQL de las consultas se escribio DIRECTAMENTE al final de
   TODO-EN-ORDEN.sql, sin archivo propio. Dos consecuencias, y ninguna se
   veia:

     · PROBAR-SQL.bat no lo probaba nunca. Corre los archivos de esta
       lista, y ese no estaba en ninguna.
     · Y correr este generador lo habria BORRADO, porque reescribe
       TODO-EN-ORDEN.sql desde la lista. El SQL de una funcion que ya
       esta viva en produccion, perdido por regenerar un indice.

   Ahora es supabase-consultas.sql como los demas. La regla que ya estaba
   escrita aqui arriba -«el archivo que sale NO se edita a mano»- era la
   correcta; lo que faltaba era cumplirla.

   Las cuentas de la cabecera se calculan de orden.length. Estaban a mano
   y decian 23, 26 y 25 a la vez, en el mismo archivo. */
const fs = require('fs');
/* La raiz se saca de DONDE ESTA ESTE ARCHIVO, no de una ruta escrita a
   mano. Estaba puesto 'C:/Users/ciip/Ventanilla-Unica-Ciip', que en esta
   maquina es OTRO clon del proyecto y va por detras: correr el generador
   desde la carpeta buena regeneraba TODO-EN-ORDEN.sql con el SQL del clon
   viejo. Un fallo que no da error: da un SQL de la semana pasada. */
process.chdir(require('path').join(__dirname, '..'));
const BARRA = String.fromCharCode(92);

const orden = ['supabase-setup','supabase-tramites','supabase-admin','supabase-citas',
'supabase-empresa','supabase-activos','supabase-identidad','supabase-emision',
'supabase-presencia','supabase-sectores','supabase-catalogos','supabase-bitacora',
'supabase-bloqueo','supabase-acompanamiento','supabase-gestor','supabase-cola',
'supabase-avisos','supabase-aranceles','supabase-huellas','supabase-encadenado',
'supabase-plazos','supabase-una-viva','supabase-hilo','supabase-hilo-citas',
/* Va detras del hilo y no en cualquier sitio: reusa dos de sus funciones,
   mensaje_lo_firma_la_base() y mensaje_no_se_toca(), y lo comprueba al
   entrar. Puesto antes, se pararia solo diciendo cual falta. */
'supabase-consultas',
'supabase-informe-victor','supabase-pliego',
/* El horario de citas. Solo necesita que existan citas y es_gestor(), asi
   que podria ir mucho antes; va el ULTIMO para no mover el numero de
   ninguno de los otros, que es por el que se les nombra en PARA-LA-BASE-REAL
   y en las conversaciones. */
'supabase-disponibilidad',
/* Los textos que el administrador cambia desde el panel. Solo necesita
   es_admin(); va al final por la misma razon que el horario: no mover el
   numero de nadie. */
'supabase-textos',
/* Lo que la bitacora no apuntaba: el plazo, el bloqueo, los activos, el
   horario, el acompañamiento y los textos. Se engancha a tablas de cinco
   archivos distintos, asi que va detras de todos. */
'supabase-bitacora-ajustes',
/* La opinion favorable de la ZODI (c34). Solo necesita el catalogo con
   `nivel` y `emite`; va al final para no mover el numero de nadie. */
'supabase-zodi',
/* El RUPDAE (c35) y el Registro Unico Minero (c36). Como la ZODI: solo
   necesita el catalogo con `nivel` y `emite`, y va al final. */
'supabase-rupdae-rum',
/* Los papeles de la junta directiva (c5): de quién es cada papel, y la
   certificación de inventario. Sólo necesita documentos y el catálogo;
   va al final para no mover el número de nadie. */
'supabase-junta',
/* Quién cambió qué texto y qué decía antes. Necesita textos_panel y la
   bitácora; va al final para no mover el número de nadie. */
'supabase-textos-rastro',
/* La revisión de los documentos: cuándo se revisó y el apunte de quién.
   Necesita documentos, perfiles y la bitácora; va al final. */
'supabase-revision-papeles',
/* La accionista jurídica (c5): dos tipos de documento. Solo necesita el
   catálogo de documentos; va al final. */
'supabase-accionista-juridica',
/* La reserva del nombre antes de resolver la constitución (c5), y el pago
   de aranceles adjuntable con la protocolización en marcha (c22). Necesita
   tramites, documentos y tramite_documentos; va al final. */
'supabase-reserva-nombre',
/* El logo de cada ficha, que sube el admin. Necesita el catalogo con su
   politica de escritura y la bitacora; va al final. */
'supabase-logos-fichas',
/* La protocolizacion del acta (c22), que nace al resolverse la
   constitucion, con su documento para pagar los aranceles y la guarda de
   su comprobante. Necesita tramites, documentos y es_gestor(); va al
   final. */
'supabase-protocolizacion',
/* La publicacion del acta (c23), que nace al resolverse la
   protocolizacion, con su PUB para pagar el periodico y la guarda de su
   comprobante. Necesita tramites, documentos y es_gestor(), y va DETRAS
   de supabase-protocolizacion, que es de quien cuelga. */
'supabase-publicacion',
/* Las cinco inscripciones en una casilla (c37): BANAVIH, INCES, RNET, RNC
   y RUPDAE. Va DETRAS de supabase-rupdae-rum, que es quien enciende el
   c35 que este apaga; si fuera delante, aquel lo volveria a encender. */
'supabase-parafiscales',
/* Los cinco entes de los registros parafiscales: tramite_entes, sus
   politicas y el disparador que crea las cinco filas al enviar la
   solicitud. Estuvo fuera de la lista hasta el 25-09-2026, y una base
   montada desde TODO-EN-ORDEN.sql salia sin la tabla. */
'supabase-entes-parafiscales',
/* La visa se parte en dos (c1 y c38): libera el codigo 'visa_inversionista'
   -que se habia quedado en la ficha de la TR-N- y da de alta la TR-I. Va el
   ULTIMO a proposito: toca una fila del catalogo y lo que cuelga de ella en
   cuatro tablas, asi que todo lo demas tiene que existir ya. */
'supabase-visa-tri',
/* La inscripcion en el SIDCAI (c39). Solo necesita el catalogo con
   `nivel` y `emite`; va al final para no mover el numero de nadie. */
'supabase-locti',
/* La revision de seguridad del 25 de septiembre: el estado de un papel lo
   pone el equipo, emitidos/ no se toca y la verificacion solo responde
   por lo emitido. Redefine verificar_documento() y apuntar_el_huerfano(),
   asi que va detras de todo lo que las define. */
'supabase-papeles-sellados',
/* Paso 2 de esa revision: las columnas del CIIP en un tramite y el
   bloqueo en todo lo que escribe el inversionista. Redefine las politicas
   del cubo del anterior, asi que va detras. */
'supabase-tramites-y-bloqueo',
/* El tope del asistente y del lector, contado en la base y no en la
   memoria de cada copia de la funcion. No depende de nadie. */
'supabase-tope-ia',
/* El «ya me registré»: confirma_paso(). Vivia solo en
   CORRER-HOY-2026-09-25.sql. Solo necesita tramites. */
'supabase-confirma-paso',
/* Cancelar una solicitud mientras siga en el CIIP. Redefine la escalera
   de supabase-tramites.sql, asi que va detras de todo. */
'supabase-cancelar',
/* El importe del día: el papel del CIIP que caduca a medianoche en
   Caracas y el comprobante que se paga contra él. Su trigger va aparte
   del de supabase-papeles-sellados, y necesita es_gestor() y es_admin();
   va al final para no mover el número de nadie. */
'supabase-importe-del-dia',
/* La traducción de documentos (c17): su fila en importe_del_dia_pasos y
   el trigger que no la deja resolver sin el comprobante. Necesita la
   tabla del anterior, así que va detrás. */
'supabase-traduccion',
/* La firma en el CIIP de la constitución: marca_firma_ciip() y la guarda de
   su marca en datos. Solo necesita tramites y es_gestor(); va al final
   para no mover el número de nadie. */
'supabase-firma-ciip',
/* La contraseña del IVSS y del INCES en tramite_entes. Va detrás de
   supabase-entes-parafiscales, que crea la tabla. */
'supabase-entes-clave',
/* El registro de marca por etapas (c8): sus dos papeles del CIIP, los
   pasos apuntados en tramites.datos, la contestación con su anuncio y el
   certificado antes de resolver. Va DETRÁS del importe del día, cuyos
   importes con nombre usa, y de los avisos y el hilo, donde escribe. */
'supabase-marca',
/* Los registros parafiscales sin código: el inversionista solo escribe en
   las filas del IVSS y del INCES. Redefine dos políticas de
   supabase-entes-parafiscales, así que va detrás. */
'supabase-entes-sin-codigo',
/* La conformidad de uso (c28): los tres tipos de documento que pide el
   SIGAT y el borrado de sus pasos viejos. Solo necesita el catálogo de
   documentos y textos_panel. */
'supabase-conformidad-uso',
/* La licencia de actividades económicas (c10): sus dos importes del día con
   nombre, los pasos que apunta la base y el freno para resolver sin los dos
   comprobantes. Va DETRÁS del importe del día y de la marca, de quien usa
   la guarda de los pasos apuntados. */
'supabase-licencia',
/* El registro de importador y exportador (c11) se apaga en el catálogo.
   Va detrás de supabase-tramites, cuyas listas ya no lo encienden. */
'supabase-quitar-importador',
/* El permiso de bomberos (c29): el borrado de sus pasos viejos, y desde el
   29-9-2026 el plano de seguridad y el importe de aranceles con su
   comprobante. Va DETRÁS del importe del día y de la marca, como la
   licencia. */
'supabase-bomberos',
/* El sellado de libros (c24): el PUB, importe del día con nombre, y su
   comprobante. Va DETRÁS del importe del día y de la marca. */
'supabase-libros',
/* El nombre del gestor de cada solicitud propia, para la campana del
   inversionista (30-9-2026). Solo necesita tramites y perfiles. */
'supabase-gestor-visible',
/* Citas y consultas tras la auditoría QA del 28-9-2026: estados de la cita,
   motivo, una viva por persona, confirmar desde el equipo y la consulta que
   se reabre. Redefine reserva_cita() y consulta_la_firma_la_base(), así que
   va detrás de supabase-disponibilidad y supabase-consultas. */
'supabase-qa-atencion',
/* Lo que encontró la revisión de trámites y papeles (QA, 28-9-2026): lo
   pendiente de un trámite cancelado, los papeles de una solicitud en
   marcha, los seis entes de las parafiscales, la nota de un evento y la
   mezcla de datos. Toca trabajos, ordenes_pago y tramite_entes y redefine
   confirma_paso(), así que va detrás de todo. */
'supabase-qa-tramites',
/* La auditoría QA de administración y cuentas: el bloqueo dentro de
   es_gestor() y es_admin(), la baja en vez del borrado, el correo para el
   admin y lo que cada cual puede cambiar de un perfil. Redefine
   funciones de supabase-tramites, -admin, -bitacora y -tope-ia, así que
   va detrás de todo. */
'supabase-qa-admin',
/* La traducción automática del chat (28-9-2026): lee los tres hilos y
   redefine gasta_uso_ia() de supabase-qa-admin con la pieza 'traductor',
   así que va la última. */
'supabase-traduccion-chat',
/* La planilla firmada que el inversionista devuelve desde «Firme la
   planilla» (c3, c6, c10): su tipo de documento y la política que la deja
   colgar con la solicitud en marcha. Solo necesita las tablas de
   supabase-tramites; va al final para no mover el número de nadie. */
'supabase-planilla-firmada',
/* Y la planilla del RIF que manda el CIIP para firmarla (30-9-2026): su
   tipo y las dos políticas del equipo. Mismas tablas; detrás de la otra. */
'supabase-planilla-rif',
/* Las dos visas (c1, c38) con la planilla de solicitud: el tipo, lo que
   deja al equipo mandarla, la firmada en la política de la anterior, el
   paso apuntado al colgarse y el candado de la Cancillería. Va detrás de
   la marca (marca_ahora) y de la planilla firmada, cuya política rehace. */
'supabase-visa-planilla',
/* La planilla de inscripción del IVSS que manda el CIIP (30-9-2026): su
   tipo, las dos políticas del equipo y el candado. Solo necesita las tablas
   de los entes y de los documentos; al final para no mover a nadie. */
'supabase-planilla-ivss'];

let mal = 0;
for (const n of orden) {
  const s = fs.readFileSync(n + '.sql', 'utf8');
  const meta = s.split(/\r?\n/).filter(l => l.charAt(0) === BARRA);
  if (meta.length) { mal++; console.log('  ' + n + '.sql lleva ' + meta.length + ' ordenes de psql'); }
}
if (!mal) console.log('  ninguno lleva ordenes de psql: es SQL puro, vale tal cual en el SQL Editor');

const raya = '-- ' + '='.repeat(68);
const trozos = [
  raya,
  '--  LOS ' + orden.length + ' ARCHIVOS, EN EL ORDEN QUE PRUEBA PROBAR-SQL.bat',
  raya,
  '--  Esto es la union literal de los ' + orden.length + ' supabase-*.sql, sin cambiar una',
  '--  coma, pegados en el orden que ejecuta el arnes contra un Postgres de',
  '--  usar y tirar. Ese orden no esta deducido leyendo cabeceras: si uno',
  '--  usara algo que otro define despues, la tanda se caeria diciendo cual.',
  '--',
  '--  Se pega ENTERO en el SQL Editor de Supabase y se pulsa Run una vez.',
  '--  Todos son idempotentes -create if not exists, create or replace, drop',
  '--  policy if exists-, asi que volver a correrlo no rompe nada y es la',
  '--  forma de poner al dia un proyecto que ya tenia la mitad.',
  '--',
  '--  Generado el ' + new Date().toISOString().slice(0, 10) + '. Si cambia un archivo, se vuelve a generar:',
  '--  no se edita a mano, que entonces son ' + orden.length + ' sitios donde mirar.',
  raya,
  ''
];

orden.forEach(function (n, i) {
  const num = String(i + 1).padStart(2, '0');
  trozos.push('');
  trozos.push(raya);
  trozos.push('--  ' + num + ' / ' + orden.length + '   ' + n + '.sql');
  trozos.push(raya);
  trozos.push('');
  trozos.push(fs.readFileSync(n + '.sql', 'utf8').replace(/\r\n/g, '\n').replace(/\s*$/, ''));
});
trozos.push('');

const salida = trozos.join('\n');
fs.writeFileSync('TODO-EN-ORDEN.sql', salida);
console.log('  TODO-EN-ORDEN.sql: ' + Math.round(salida.length / 1024) + ' KB');
