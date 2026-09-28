# Pendientes de Franklin — lista de trabajo

Sale de `Pendientes FRANK.pdf` (24 de septiembre de 2026). Cada punto se
tacha cuando está subido a `main` y con las pruebas en verde.

- `[ ]` por hacer · `[x]` hecho · **?** necesita que Franklin decida algo

---

## Lo que puedo hacer sin preguntar

Son cambios de lista: quitar un campo, añadir un recaudo, cambiar un
rótulo. No inventan mecanismos nuevos y se deshacen borrando una línea.

### Validación de representación legal (c33)
- [x] Quitar el recaudo «Traducción certificada de la licencia»
- [x] Añadir «Pasaporte vigente del poderdante» (ya estaba; es el suyo)
- [x] Añadir «Cédula de identidad del apoderado» y «RIF del apoderado»

### Visa de negocios (c1) y Visa de inversionista
- [x] Añadir teléfono y correo del solicitante
- [x] Añadir teléfono y correo del contacto en Venezuela
- [x] Añadir itinerario: número de vuelo, fecha de entrada, fecha de salida
- [x] Añadir «¿Te han otorgado antes la visa?» sí/no, con el campo de fechas
      que sale solo al responder que sí
- [x] Sustituir los recaudos por los siete de la lista
- [x] En la de inversionista, dejar monto de inversión y actividad económica
      y añadir además «Certificado médico» a los recaudos

### RIF personal (c3)
- [x] Recaudos: «Pasaporte o cédula venezolana de extranjero» y
      «Carta de residencia de la ubicación indicada»

### Traducción de documentos (c17)
- [x] Añadir la pregunta «¿El documento es apostillado y/o legalizado?»
- [x] Que los recaudos cambien según la respuesta: si ya viene apostillado
      se pide la apostilla que tiene. **Hace falta correr `CORRER-APOSTILLA-PREVIA.sql`**

### RIF de la empresa (c6)
- [x] Recaudos: acta constitutiva; cédula o pasaporte y RIF del
      representante legal; contrato de servicios o constancia de la
      dirección fiscal

### Cuenta bancaria empresarial (c7)
- [x] Quitar el campo «Ciudad donde prefieres la agencia»
- [x] Recaudos: acta constitutiva; RIF de la empresa; cédula o pasaporte y
      RIF del representante legal; declaración jurada de origen de fondos

### Sellado de libros (c24)
- [x] Quitar «Cómo vas a facturar», «Fecha de inicio de actividades»,
      «Dirección fiscal en Venezuela» y «Actividad económica»
- [x] Que «Agregar libros» deje de ser opcional
- [x] Recaudos: acta constitutiva; RIF de la empresa; cédula o pasaporte y
      RIF de la junta directiva; cédula o pasaporte y RIF de los accionistas

### Registro de marcas (c8)
- [x] Cambiar el rótulo del campo por «Descripción detallada de los
      productos o servicios»
- [x] Quitar «A nombre de quién se registra»
- [x] Añadir «Empresa que registra la marca», con su casilla de texto
- [x] Recaudos: logo; acta constitutiva de la empresa que registra; RIF de
      la empresa; cédula o pasaporte y RIF del representante legal

### Trámites que se van
- [x] Eliminar «Homologación de licencia de conducir» (c4)
- [x] Eliminar «Certificado médico» (c21). La prueba del arnés que lo usaba
      pasa a medirse sobre la c17. **Hace falta correr `CORRER-QUITAR-C4-Y-C21.sql`**

---

## Lo que necesito que decidas

### 1. Cuántos pasos tiene cada trámite, y qué significa cada uno — **decidido: A**

Franklin, 24-9-2026: los pasos avanzan con los cuatro estados. Y dos
respuestas suyas del mismo día: en la visa, el paso 2 lo marca el CIIP -el
gestor avisa y el equipo confirma que el inversionista ya se registró en
Cancillería- y el 3 es la firma del inversionista.

Lo que eso significa en el panel: ningún paso se da por terminado hasta
que el trámite está resuelto —los de en medio se topan en el penúltimo—,
así que la escalera puede encender un paso algo antes de tiempo, pero no
puede decir que algo está listo cuando no lo está.

- [x] Que la escalera use los pasos propios lleve los que lleve, y no solo
      cuando son cuatro (`escaleraDe`, la misma cuenta que la columna
      «Progreso» de Mis trámites)
- [x] Representación legal (c33), dos pasos
- [x] RIF personal (c3) y RIF de la empresa (c6), tres pasos
- [x] Cuenta bancaria (c7), dos pasos
- [x] Sellado de libros (c24), tres pasos
- [x] Visa (c1) y visa de inversionista, seis pasos. Franklin los dictó uno
      a uno el 25-9-2026:

      1. Solicitud recibida por el CIIP
      2. Regístrate en el portal de Cancillería
      3. Descarga aquí el documento
      4. Recibo de planilla de solicitud por el CIIP
      5. Solicitud recibida por Cancillería
      6. Visa otorgada

      El 2 no lo mueve ningún estado: lo marca el inversionista con un
      botón, y hasta entonces la escalera se queda ahí. Se guarda en
      `tramites.datos` a través de `confirma_paso()`. **Hace falta correr
      `CORRER-CONFIRMA-UN-PASO.sql`.**
- [ ] Traducción (c17): son dos escaleras distintas según la respuesta. Ver
      el punto 4
- [ ] Registro de marcas (c8): en tu documento sigue «aún se está diseñando»

### 2. Los tres mecanismos nuevos de la visa — **dos hechos, falta uno**

Franklin, 25-9-2026, el paso 2 y el 3 de la visa:

> «el 2 se marca cuando el usuario confirma que registró el usuario»
> «en apenas el usuario confirme que se creó el usuario se le habilita la 3
> con la descarga del pdf»

- [x] **El paso con enlace externo.** El 2 enseña el enlace a
      cancilleriadigital.mppre.gob.ve y el botón «Ya me registré». Va por
      `confirma_paso()`, que comprueba que el trámite es tuyo y revienta si
      no tocó ninguna fila: un update a secas habría cambiado cero filas en
      silencio, que es como se perdieron la nota de la devolución y el
      comprobante de la publicación.
- [x] **El paso que entrega un documento.** El 3 trae la descarga de la
      planilla, y solo aparece cuando el 2 está confirmado. El PDF vive en
      `planillas/visa-solicitud.pdf`, junto al panel, para que no dependa de
      la página del ministerio.
- [x] **La observación del CIIP sobre esa planilla.** Franklin, 25-9-2026:
      una nota que no tumba el papel. El gestor tiene ahora un tercer botón
      -«Dejar una observación»- que escribe la nota y NO toca el estado: el
      papel sigue su camino, le suena la campana al inversionista y la ve
      junto al papel en Documentos y en el recaudo del trámite.

      Sin migración: la nota va donde ya iba el motivo del rechazo
      (`documentos.nota_revision`), y lo que separa una cosa de la otra es
      el estado. La política que deja al equipo escribirla ya existía.

Queda una cosa a medias y conviene tenerla escrita: la planilla firmada se
sube en la hoja de recaudos, como los demás papeles, y no DENTRO del paso 3.
Subirla funciona —`planilla_visa` es uno de los siete recaudos de la visa—,
pero el paso solo la da, no la recoge. Moverlo ahí es otro trabajo.

---

El texto de partida, para no perderlo. El proceso de la visa pide tres
cosas que el panel no sabía hacer:

- **Un paso que enseña un mensaje y un enlace externo** («regístrese en
  cancilleriadigital.mppre.gob.ve y avísenos»).
- **Un paso donde el inversionista sube un documento** — hoy los recaudos
  se suben todos juntos en su hoja, no dentro de un paso.
- **Una observación del CIIP sobre ese documento** («si tiene errores,
  poder hacerle una observación»). Existe algo parecido: el gestor puede
  rechazar un recaudo con su motivo. ¿Vale eso, o quieres una conversación
  por paso?

Cada uno es un trabajo aparte. Dime si van los tres, o cuáles.

### 3. El RIF personal: qué campos — **decidido**

Franklin, 25-9-2026: «coloca los que salen en la casilla del RIF». Puestos
los catorce del portal, en el orden del portal.

- [x] tipo de persona, documento, fecha de nacimiento, apellidos, nombres,
      sexo, estado civil, domiciliado en el país, firma personal, cierre
      fiscal, tipo de actividad, profesión, RIF de la empresa, razón social,
      cargo, correo, dirección fiscal y teléfono

Y después: «acopla todo a lo que dice la página del RIF». Las casillas salen
ahora del instructivo que publica el propio SENIAT
(declaraciones.seniat.gob.ve/portal/.../InscRifPN.pdf, leído el 25-9-2026),
con sus tres pantallas: identificación, datos básicos y domicilio fiscal.

- [x] Entran **sexo**, **domiciliado en el país** y **tipo de persona**
      (venezolano / extranjero / pasaporte), que es lo que el portal
      pregunta de verdad
- [x] Sale la **nacionalidad**: el formulario del SENIAT no la pide, el tipo
      de persona ya la dice
- [x] El viejo «tipo de documento» deja su sitio al «tipo de persona»:
      preguntaban lo mismo, y ahora se pregunta con las palabras del portal

Dos cosas decididas por mí, las dos se deshacen con una línea:

- **El cierre fiscal sale sólo si tienes firma personal.** Sin firma no hay
  ejercicio que cerrar.
- **RIF de la empresa, razón social, cargo y correo van opcionales**, como
  los marca el instructivo: son el bloque de dónde trabajas, y exigirlos
  dejaría fuera a quien viene a sacarse su primer RIF.

- [x] **El domicilio fiscal, partido** (Franklin: «sí, pártelo»). Estado,
      municipio, parroquia, ciudad, urbanización, avenida o calle, casa o
      edificio, piso, apartamento, código postal y punto de referencia. El
      piso y el apartamento van opcionales: una casa no tiene ninguno de los
      dos, y exigirlos obligaría a inventárselos.

      Lo que se gana es de quien transcribe: una dirección escrita de
      corrido hay que despiezarla a ojo —¿esto es la urbanización o la
      avenida?— y ahí es donde el expediente vuelve con la dirección mal
      puesta.

### 4. Traducción: dos procesos según la respuesta — **hecho**

Franklin, 25-9-2026: «¿podemos trabajar mediante una pregunta de selección?
¿dependiendo de lo que digan sale la escalera con los pasos distintos, así
como se divide en el documento?». Sí, y ya está puesto.

La pregunta que lo decide es la misma que ya cambiaba los recaudos: «¿El
documento es apostillado y/o legalizado?». Ahora cambia también los pasos.

- [x] **Si hay que apostillarlo** (por defecto), cinco pasos: solicitud
      recibida · apostilla en el país que emitió el documento · traducción
      por intérprete público · legalización ante el MPPRE · documento
      apostillado y traducido
- [x] **Si ya viene apostillado**, cuatro: solicitud recibida · traducción
      por intérprete público · legalización ante el MPPRE · documento
      traducido y legalizado

Antes de contestar manda la larga: lo honesto es enseñar el camino completo
y no el corto.

**Los diez rótulos son míos y hay que revisarlos.** Salen de los cuatro que
la ficha ya tenía y de cómo tu documento divide el proceso, no de una lista
que tú hayas dictado. Como los de la visa: córrigelos y los cambio.

### 5. El enlace del RNC **?**

El documento acaba con un enlace de inscripción del RNC y sin instrucción.
¿Qué hago con él?

### 6. Documentos que todavía no existen en la base **?**

Varios recaudos nuevos no están en el catálogo de tipos de documento:
carta de solicitud de la empresa, foto tipo carnet, planilla de solicitud,
solvencia económica, declaración jurada de origen de fondos, carta de
residencia, contrato de servicios, logo, declaración jurada de
antecedentes.

Los añado yo, pero **hace falta correr un SQL en la base real** y sin eso
el panel los pedirá y la base los rechazará al subirlos. Te lo prepararé
junto con el primer bloque de cambios.

### 7. Lo que dejó abierto la revisión de trámites (QA, 28-9-2026) **?**

Lo arreglado va en la rama `noche-qa-tramites`, con
`supabase-qa-tramites.sql` para correr en la base real. Quedan cuatro
cosas que no me toca decidir:

- **¿Hace falta un estado «denegado»?** Si el organismo dice que no, hoy
  se devuelve con una nota que lo explica (ya se puede devolver desde
  «ante el ente»). Un estado propio necesita su chip, su aviso y su sitio
  en la escalera.
- **¿Qué pasa con lo pagado de una solicitud cancelada?** Al cancelar, la
  orden de pago pendiente se anula sola. Una ya pagada no se toca:
  devolver el dinero o guardarlo para otra solicitud es decisión del CIIP.
- **¿El equipo cancela también lo recién enviado o en revisión?** La base
  lo deja; el panel solo lo ofrece en un devuelto que no vuelve. En los
  otros dos lo que hay hoy es devolver.
- **¿La cancelación del CIIP va también por correo?** Llega a la campana y
  al trámite con su motivo; el correo de avisos no la cuenta todavía.

---

## Lo que ya está hecho

_(vacío por ahora)_
