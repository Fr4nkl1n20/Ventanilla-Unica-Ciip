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
/* El chat de un paso (9-10-2026): la columna paso de tramite_mensajes y
   cuándo se escribe en él. DELANTE de la marca, cuyo habilita_contestacion
   escribe su primer mensaje. */
'supabase-chat-del-paso',
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
'supabase-planilla-ivss',
/* La Taquilla única opción 2 (1-10-2026): las marcas nuevas de confirma_paso
   y fuera los candados de la planilla de la visa y de los pagos de la
   licencia. Redefine la confirma_paso de supabase-qa-tramites; al final. */
'supabase-opcion2',
/* El permiso de bomberos por el portal (1-10-2026): 'bomberos_solicitado'
   en confirma_paso, anota_paso() para la sede y fuera el candado del
   comprobante de aranceles. Redefine la confirma_paso de supabase-opcion2. */
'supabase-bomberos-opcion2',
/* La cédula por el portal del SAIME (1-10-2026): 'saime_confirmada' en
   confirma_paso. Redefine la de supabase-bomberos-opcion2; al final. */
'supabase-cedula-opcion2',
/* La inscripción en el SIDCAI por el portal (1-10-2026, Ventanilla Única
   2.3): 'locti_inscrito' en confirma_paso y fuera los pasos del c39 escritos
   a mano. Redefine la confirma_paso de supabase-cedula-opcion2, con su
   'saime_confirmada' dentro; al final. */
'supabase-locti-opcion2',
/* Control y Estadísticas (1-10-2026): el sector de cada consulta, los
   trámites específicos de cada sector y estadisticas_control(). Usa
   es_admin, consultas, tramites, tipos_tramite y tramite_eventos; no
   redefine nada de nadie, así que va al final. */
'supabase-control-estadisticas',
/* «Bienes» (2-10-2026): la compraventa (c41) y el alquiler (c42) de un
   inmueble, y los tres tipos de documento de sus recaudos. Solo inserta
   en el catálogo; necesita nivel y emite, así que va al final. */
'supabase-bienes',
/* La marca en proceso de registro (c43), Franklin Reyes, 5-10-2026: el
   trámite y los dos tipos de documento de sus recaudos. Solo inserta en
   el catálogo, como «Bienes»; necesita nivel y emite, así que va al final. */
'supabase-marca-proceso',
/* «Recaudos revisados» como botón aparte (Franklin Reyes, 5-10-2026):
   marca_recaudos_revisados() apunta datos.pasos_ciip.recaudos_revisados.
   No redefine nada de nadie; al final. */
'supabase-recaudos-revisados',
/* «Ya lo solicité» (Franklin Reyes, 5-10-2026, Ventanilla única 2.6): los
   cuatro trámites c44 a c47. Solo inserta en el catálogo y copia el nivel
   de su casilla madre; necesita nivel y emite, así que va al final. */
'supabase-ya-solicitado',
/* Los recaudos del comprador en la compraventa (c41), Franklin Reyes,
   5-10-2026: cuatro tipos de documento. Solo inserta en el catálogo. */
'supabase-bienes-comprador',
/* La compraventa en dos fases, contrato y registro (5-10-2026): el contrato
   del CIIP, los dos importes, los pasos del gestor, la fecha de la firma y
   el anuncio del CIIP. Redefine importe_del_dia_vigente(); va DETRÁS del
   importe del día, la marca, los libros y «Bienes». */
'supabase-bienes-registro',
/* El SACS (Franklin Reyes, 7-10-2026, Ventanilla única 2.7): los trámites c48
   y c49, el c12 apagado, 'sacs_registrado' en confirma_paso y
   estadisticas_control() con el SACS ya solicitado. Redefine la confirma_paso
   de supabase-locti-opcion2 y la estadisticas_control() de
   supabase-control-estadisticas, y copia el nivel del c12; va la última. */
'supabase-sacs',
/* El sellado de libros (c24) ante el SAREN y los nombres de la cédula (c2)
   y la traducción (c17), Franklin Reyes, 7-10-2026. Tres update sobre
   tipos_tramite, que ya existe desde el segundo; al final para no mover el
   número de nadie. */
'supabase-libros-saren',
/* Los modelos de «Autorizaciones y NDA»: un cubo que solo llena el admin
   (Franklin Reyes, 8-10-2026). Solo pide es_admin(); al final para no
   mover el número de nadie. */
'supabase-modelos',
/* La segunda auditoría de seguridad (8-10-2026): las contraseñas de los
   entes por columna y con rastro, dos papeles más que solo emite el CIIP y
   anon fuera de confirma_cita y abre_consulta_para. Toca tramite_entes,
   documentos y la bitácora de muchos archivos de antes: va la última. */
'supabase-seguridad-octubre',
/* La autorización al CIIP trámite a trámite, aceptada en línea y sin firma
   (Franklin Reyes, 8-10-2026). Una tabla nueva y revoca_autorizacion();
   solo pide tramites, tipos_tramite y es_gestor(). Al final para no mover
   el número de nadie. */
'supabase-autorizaciones',
/* El detalle de Control y Estadísticas (Franklin Reyes, 9-10-2026): el
   trámite que el inversionista pulsa en el chat de sectores, guardado en
   consultas.tramite_sector, y los casos de «¿Por qué piden ayuda?» con lo
   que escribió. Reescribe estadisticas_control(), así que va detrás de
   supabase-sacs, que fue quien la dejó escrita. */
'supabase-control-detalle',
/* El tiempo de respuesta en sus dos tramos, el del CIIP y el del ente
   (Franklin Reyes, 15-10-2026). Reescribe estadisticas_control(), así que
   va detrás de supabase-control-detalle, que fue quien la dejó escrita. */
'supabase-tiempos',
/* El tiempo de respuesta paso a paso (Franklin Reyes, 15-10-2026): cuánto
   se estuvo en cada estado y quién lo movió. Reescribe estadisticas_control(),
   así que va detrás de supabase-tiempos. */
'supabase-tiempos-pasos',
/* El Registro Turístico Nacional (c50), Franklin Reyes, 13-10-2026: el
   trámite, su credencial y 'rtn_solicitado' en confirma_paso. Redefine la
   confirma_paso de supabase-sacs; al final para no mover el número de
   nadie. */
'supabase-rtn',
/* El administrador borra lo de las pruebas desde el panel (Franklin Reyes,
   15-10-2026): una solicitud, un papel o una cuenta entera. Redefine tres
   cerrojos de supabase-hilo, supabase-qa-tramites y supabase-autorizaciones,
   y la regla de fuentes de la bitácora: va la última. */
'supabase-borrado-admin'];

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
