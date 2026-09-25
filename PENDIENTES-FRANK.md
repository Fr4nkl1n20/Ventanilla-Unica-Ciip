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
- [ ] Visa (c1) y visa de inversionista: **me faltan los seis rótulos tal
      como los quieres**. Sé quién marca el 2 y el 3; no tengo escritos los
      seis nombres

      Franklin, 25-9-2026, sobre el paso 2: «se marca cuando el usuario
      confirma que registró el usuario». Eso afina lo de ayer —«el gestor
      avisa y el equipo CIIP confirma»— y cambia una cosa de fondo: ese
      paso NO lo mueven los cuatro estados, lo mueve un botón que aprieta
      el inversionista. Es el primero de los tres mecanismos del punto 2.

      Dónde se guardaría, sin tocar la base: en `tramites.datos`, una
      casilla del estilo `paso2_confirmado`. No hace falta un estado nuevo
      ni tocar la escalera de la base, y por tanto no puede romper el
      orden de los estados que el disparador vigila.
- [ ] Traducción (c17): son dos escaleras distintas según la respuesta. Ver
      el punto 4
- [ ] Registro de marcas (c8): en tu documento sigue «aún se está diseñando»

### 2. Los tres mecanismos nuevos de la visa — **medio decidido**

Franklin, 25-9-2026, el paso 2 y el 3 de la visa:

> «el 2 se marca cuando el usuario confirma que registró el usuario»
> «en apenas el usuario confirme que se creó el usuario se le habilita la 3
> con la descarga del pdf»

Así queda el tramo, tal como lo entiendo:

1. **Paso 2** — el panel enseña el enlace a cancilleriadigital.mppre.gob.ve
   y un botón de «ya me registré». Lo aprieta el inversionista, y eso es
   lo que marca el paso. Se guarda en `tramites.datos`, sin estado nuevo.
2. **Paso 3** — nace cerrado y se abre con esa confirmación. Dentro va la
   descarga del PDF de la planilla, que el inversionista firma y sube.

Lo de subirla ya existe: `planilla_visa` es uno de los siete recaudos de
la visa. Lo que cambia es DÓNDE se sube —dentro del paso y no en la hoja
de papeles—, que es el segundo de los tres mecanismos.

**Me faltan dos cosas para montarlo:** los seis rótulos, y el PDF de la
planilla (el archivo, o el enlace de donde se baja).

Sigue sin decidir el tercer mecanismo: la observación del CIIP sobre ese
documento. Hoy el gestor puede rechazar un recaudo con su motivo. ¿Vale
eso, o quieres una conversación por paso?

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
