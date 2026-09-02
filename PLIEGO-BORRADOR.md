# Pliego de tratamiento de datos — BORRADOR

> ## ESTO NO ES EL PLIEGO
>
> Es un borrador para que el abogado del CIIP no empiece en una hoja en
> blanco. **No tiene ningún valor legal y no debe publicarse tal cual.**
>
> Lo escribió quien programó la ventanilla, no un abogado. Su utilidad es
> otra: la parte de un pliego que un abogado no puede redactar sin leerse
> el código es **qué datos se recogen de verdad, quién los ve de verdad y
> qué pasa con ellos de verdad**. Eso es lo que hay aquí, y está
> comprobado contra el esquema, no recordado.
>
> Lo que falta —el encaje legal, las referencias normativas, las
> obligaciones bajo el régimen de la Ley Constitucional Antibloqueo, la
> forma de ejercer los derechos— lo pone el abogado. Donde hace falta una
> decisión suya va marcado así: **[DECIDE EL CIIP]**.
>
> Cuando esté aprobado, se publica con el INSERT que está al final de
> `supabase-pliego.sql`. Hasta entonces la tabla sigue vacía y el panel no
> le pide nada a nadie.

*Borrador redactado el 2 de septiembre de 2026, a partir del punto 3 del
informe «Portal CIIP · Primer avance» de Víctor A. J. Corredor Suárez.*

---

## 1. Quién trata tus datos

El Centro Internacional de Inversión Productiva (CIIP), a través de la
Ventanilla Única del Inversionista.

**[DECIDE EL CIIP]** — Denominación oficial completa, RIF, domicilio, y a
quién se dirige uno para ejercer sus derechos (correo, oficina, horario).

---

## 2. Qué datos se recogen

Esto es exhaustivo: es la lista de lo que el sistema guarda hoy, tabla por
tabla. Si mañana se añade algo, este apartado y la versión del pliego
tienen que cambiar a la vez.

### 2.1 De tu cuenta
Correo electrónico y contraseña. **La contraseña no la guarda el CIIP**:
la custodia cifrada el proveedor de la plataforma, y ni el equipo ni los
administradores pueden verla ni recuperarla.

### 2.2 De ti
Nombre completo, país, sector económico en el que declaras que vas a
invertir, y la última vez que abriste el panel.

### 2.3 De tu empresa
Razón social, RIF, número de registro, fecha de constitución, capital
social, actividad económica, dirección fiscal, municipio, teléfono,
representante, fecha de inicio de actividades y número de trabajadores.

### 2.4 Los recaudos que subes
Los documentos que aportas para cada trámite: identidad, pasaporte, visa,
actas, poderes, solvencias, estados financieros, nóminas y los demás que
pida cada trámite.

De cada uno se guarda el archivo, su nombre original, su fecha de
vencimiento si la tiene, si el CIIP lo dio por bueno y, cuando el
navegador puede calcularla, una **huella digital** (SHA-256) que sirve
para comprobar después que el documento no ha cambiado.

> **Nota para el abogado.** Aquí es donde entra lo que el informe llama
> «balances contables, composiciones accionarias y transferencias de
> activos internacionales». No es una categoría aparte en el sistema: son
> recaudos como los demás, y por eso todo lo que este pliego diga de los
> recaudos les aplica.

### 2.5 De tus trámites
Qué solicitaste, cuándo, en qué estado va, y **los datos del formulario de
cada trámite**, que cambian según cuál sea: números de documento, fechas,
direcciones, montos de inversión, origen de los fondos, composición
accionaria, número de trabajadores, y los demás que exija cada organismo.

También el historial completo: cada cambio de estado, con su fecha, quién
lo hizo y la nota que escribió.

### 2.6 De tus conversaciones
Los mensajes que intercambias con el equipo del CIIP sobre un trámite o
sobre una cita, con sus adjuntos. **No se pueden borrar ni editar**, ni
por ti ni por el equipo: forman parte del expediente.

### 2.7 De tus citas
Qué querías tratar, cómo prefieres verte, qué días te vienen bien, y la
fecha y el lugar que fije el CIIP.

### 2.8 Constancias
Cuándo alguien del equipo comprobó tu documento de identidad, con qué
resultado y quién lo comprobó. Y, si llegas a aceptar este pliego, qué
versión aceptaste y cuándo.

### 2.9 Lo que **NO** se recoge
Se dice porque un pliego que sólo enumera lo que sí recoge se lee como si
recogiera todo:

- No hay rastreadores, ni cookies de publicidad, ni analítica de terceros.
- No se guarda la dirección IP ni el navegador desde el que entras.
- No se comparte nada con anunciantes ni con redes sociales. No las hay.
- No se toma ninguna decisión automatizada sobre ti. Quien resuelve un
  trámite es una persona del CIIP.

---

## 3. Para qué se usan

Para tramitar lo que solicitas, y para nada más:

1. Preparar y presentar tus solicitudes ante los organismos.
2. Reutilizar tus recaudos entre trámites, para no pedirte el mismo papel
   dos veces. **Es la razón de ser de la ventanilla única.**
3. Avisarte por correo cuando algo tuyo cambia: te devuelven un trámite,
   se resuelve, o un documento tuyo está a punto de vencer.
4. Atenderte cuando escribes o pides cita.
5. Dejar constancia de quién hizo qué, que es lo que permite auditar.

**[DECIDE EL CIIP]** — Si estos datos se usan además para estadística
agregada de inversión, hay que decirlo aquí y explicar que va sin
identificar a nadie.

---

## 4. Quién los ve

- **Tú**, todo lo tuyo, siempre.
- **El equipo del CIIP** (gestores y administradores), para atender tu
  expediente.
- **Nadie más.** Ningún otro inversionista puede ver nada de lo tuyo, y no
  es una promesa: lo impide la propia base de datos, fila por fila, no la
  pantalla. Se comprueba automáticamente antes de cada publicación.

### Fuera del CIIP

- **El proveedor de la plataforma**, que aloja la base de datos y los
  archivos. **[DECIDE EL CIIP]** — nombrarlo, decir en qué país están los
  servidores, y qué contrato lo obliga.
- **Los organismos** (SAIME, SENIAT, SAREN, alcaldías y demás), cuando el
  CIIP les presenta tu expediente. Es el objeto del trámite.
- **Nadie más.** No se venden ni se ceden datos.

**[DECIDE EL CIIP]** — Régimen aplicable a la transferencia
internacional, si los servidores están fuera de Venezuela, y su encaje con
la Ley Constitucional Antibloqueo para la información protegida.

---

## 5. Cuánto tiempo se guardan

Mientras tengas cuenta. **Hoy no hay borrado automático de nada.**

**[DECIDE EL CIIP]** — Cuánto tiempo debe conservarse un expediente
terminado. Un plazo legal de conservación documental haría que este
apartado dejara de ser «mientras tengas cuenta».

Hay dos cosas que **no** se borran aunque tú quieras, y conviene que se
digan claras:

- **El historial de un trámite y los mensajes del expediente.** Registran
  lo que ocurrió entre tú y el CIIP; borrarlos sería reescribir lo que
  pasó.
- **Las constancias de comprobación de identidad.** Por lo mismo.

Las dos desaparecen si se borra la cuenta entera.

---

## 6. Tus derechos

- **Acceder** a todo lo tuyo: ya lo tienes en el panel, sin pedir permiso.
- **Corregir** lo que esté mal. Los datos de tus formularios y de tu
  empresa los cambias tú; un recaudo ya validado lo corrige el equipo.
- **Suprimir**: borrar la cuenta se lleva por delante el expediente
  entero —trámites, recaudos, mensajes, citas y constancias— y borra
  también los archivos del almacén.
- **Oponerte o retirar tu consentimiento.** Hay que decir sin rodeos qué
  significa: como todo el tratamiento existe para tramitar lo que pides,
  retirarlo equivale a no poder seguir usando la ventanilla.

**[DECIDE EL CIIP]** — Cómo se ejercen: a qué dirección se escribe, en
cuánto tiempo se contesta, y qué hacer si no se contesta.

---

## 7. Seguridad

Lo que hay, dicho sin adornos:

- Los archivos viven en un almacén **privado**. No hay ninguna dirección
  pública que los sirva: para verlos se genera un enlace firmado que
  caduca.
- La base de datos filtra **por fila**: cada consulta devuelve sólo lo que
  esa persona puede ver, y eso lo comprueba el servidor, no el navegador.
- Quién puede ver expedientes ajenos es una decisión que sólo toma un
  administrador, queda registrada, y **nadie puede dársela a sí mismo**.
- Cada movimiento sobre roles, catálogos, papeles y citas queda anotado
  con su autor y su fecha, y ese registro **no se puede editar ni borrar**
  desde la aplicación.

Y lo que no se promete: ningún sistema es inviolable. **[DECIDE EL CIIP]**
— qué se hace y a quién se avisa si alguna vez hay una brecha.

---

## 8. Cambios en este pliego

Cuando cambie, se publica una **versión nueva** y se te pide aceptarla al
entrar. Las versiones anteriores no se borran: puedes releer lo que
aceptaste y cuándo.

---

## 9. Aceptación

Al marcar la casilla queda constancia de **qué versión** aceptaste y **en
qué fecha**. Esa constancia no se puede modificar después, ni por ti ni
por el CIIP.

**[DECIDE EL CIIP]** — Fórmula exacta de la aceptación, y si hace falta
una declaración aparte para los datos protegidos bajo el régimen especial.

---

## Notas de quien programó esto, para quien lo revise

Cinco cosas que conviene saber antes de corregir el texto:

1. **La casilla existía desde el principio y no era un consentimiento.**
   Decía «Acepto el tratamiento de mis datos para la gestión de trámites»,
   no enlazaba a ningún documento y no dejaba constancia de nada. Eso es
   lo que este trabajo viene a arreglar.

2. **Quien entra por el acceso del CIIP no ha aceptado nunca nada.** Las
   cuentas las crea el equipo, y ese camino no pasaba por la casilla. Son
   probablemente la mayoría de los usuarios reales.

3. **El panel lo usan apoderados, no inversionistas.** Lo dice el propio
   informe: «será utilizado por sus asistentes, administradores, abogados
   en la mayoría de los casos». Quien acepta el pliego puede no ser el
   titular de los datos. **[DECIDE EL CIIP]** — cómo se resuelve eso.

4. **El castellano es el que obliga.** El sistema admite el pliego en seis
   idiomas, pero guarda cuál es el que rige y la pantalla lo dice al pie.
   Los demás son cortesía para que se entienda lo que se firma.

5. **No se guarda ni la IP ni el navegador de la aceptación.** Se pensó y
   se dejó fuera: es un dato personal más que habría que justificar en
   este mismo pliego, y para acreditar el consentimiento bastan quién, qué
   versión y cuándo. Si hace falta para sostenerlo jurídicamente, se
   añade — pero entonces hay que decirlo en el apartado 2.
