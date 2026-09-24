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
- [ ] Añadir teléfono y correo del solicitante
- [ ] Añadir teléfono y correo del contacto en Venezuela
- [ ] Añadir itinerario: número de vuelo, fecha de entrada, fecha de salida
- [ ] Añadir «¿Te han otorgado antes la visa?» sí/no, con el campo de fechas
      que sale solo al responder que sí
- [x] Sustituir los recaudos por los siete de la lista
- [x] En la de inversionista, dejar monto de inversión y actividad económica
      y añadir además «Certificado médico» a los recaudos

### RIF personal (c3)
- [x] Recaudos: «Pasaporte o cédula venezolana de extranjero» y
      «Carta de residencia de la ubicación indicada»

### Traducción de documentos (c17)
- [ ] Añadir la pregunta «¿El documento es apostillado y/o legalizado?»
- [ ] Que los recaudos cambien según la respuesta (el panel ya sabe
      esconder y pedir recaudos según una casilla)

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
- [ ] Eliminar «Homologación de licencia de conducir» (c4)
- [ ] Eliminar «Certificado médico» (c21) — **ojo**: una prueba del arnés lo
      usa desde el lunes; hay que repuntarla, y lo hago yo

---

## Lo que necesito que decidas

### 1. Cuántos pasos tiene cada trámite, y qué significa cada uno **?**

Casi todas las «casillas» del documento cambian los pasos del proceso: la
representación legal pasa a dos, el RIF a tres, la visa a seis.

El panel ya guarda los pasos propios de los 37 trámites, así que ponerlos
no es el problema. El problema es **qué los marca como hechos**: hoy lo
decide el estado de la solicitud, y los estados son cuatro —recibida, en
revisión, ante el organismo, resuelta—. Con cuatro pasos encaja; con dos
sobra sitio y con seis falta.

Concretamente, la visa tiene seis pasos y dos de ellos —«regístrese en
Cancillería» y «llene la planilla»— **los hace el inversionista**, no el
CIIP. Hoy no hay forma de que el panel sepa que eso ya se hizo.

Necesito saber una de dos cosas:

- **A.** Los pasos son un dibujo informativo y basta con que avancen a
  ojo con los cuatro estados. Barato, y algún paso se marcará antes o
  después de tiempo.
- **B.** Cada paso se marca de verdad. Eso pide estados nuevos en la base,
  por trámite, y es un cambio de fondo.

### 2. Los tres mecanismos nuevos de la visa **?**

El proceso de la visa pide tres cosas que el panel no sabe hacer:

- **Un paso que enseña un mensaje y un enlace externo** («regístrese en
  cancilleriadigital.mppre.gob.ve y avísenos»).
- **Un paso donde el inversionista sube un documento** — hoy los recaudos
  se suben todos juntos en su hoja, no dentro de un paso.
- **Una observación del CIIP sobre ese documento** («si tiene errores,
  poder hacerle una observación»). Existe algo parecido: el gestor puede
  rechazar un recaudo con su motivo. ¿Vale eso, o quieres una conversación
  por paso?

Cada uno es un trabajo aparte. Dime si van los tres, o cuáles.

### 3. El RIF personal: qué campos exactamente **?**

El documento dice «colocar estos campos en el primer paso» con una captura
del SENIAT al lado. En esa pantalla hay más de quince casillas —apellidos,
nombres, pasaporte, tipo de persona, nacionalidad, estado civil, tiene
firma personal, tipo de actividad, RIF de la empresa, razón social, cargo,
profesión, fecha de cierre fiscal, correo—.

No sé cuáles quieres. Dime la lista o márcamela sobre la captura.

### 4. Traducción: dos procesos según la respuesta **?**

El documento pide que el proceso sea de cuatro pasos para un documento
normal y de cinco si va apostillado. Que los **recaudos** cambien según una
respuesta ya se puede. Que cambien **los pasos** no: hoy un trámite tiene
una escalera y solo una.

¿Lo hago como dos trámites distintos en el catálogo, o esperamos a la
decisión del punto 1?

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

---

## Lo que ya está hecho

_(vacío por ahora)_
