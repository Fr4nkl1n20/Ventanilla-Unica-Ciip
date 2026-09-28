# CIIP · Ventanilla Única del Inversionista

Acceso y panel para inversionistas extranjeros que tramitan su llegada,
constitución de empresa y operación en Venezuela.

Es un sitio **estático**: HTML, CSS y JavaScript sin compilación. La
autenticación y los datos los pone Supabase.

Con una excepción, y solo una: `api/asistente.js`, que corre en un servidor
de Vercel. Está ahí porque la clave de Anthropic no puede viajar al
navegador —a diferencia de la `anon` de Supabase, que es pública por
diseño—. Mientras esa clave no esté puesta, el asistente contesta con las
respuestas fijas de siempre y el sitio se comporta como antes de que ese
archivo existiera. Cómo se enciende: `api/LEEME.md`.

---

## Estado actual

En producción, en **https://ventanilla-unica-2.vercel.app** (proyecto de
Vercel `ventanilla-unica-2`, Root Directory en la raíz del repositorio).
`vercel.json` redirige `/` a `/acceso.html`, que es la puerta de entrada. Hasta
el 25-09-2026 había dos: `/login/` era una copia de `acceso.html` con su propio
`config.js`, más viejo, y al cerrar sesión se volvía a la otra. Ahora es una
sola; `/login` y cualquier `/login/...` redirigen a `/acceso.html` para no
romper marcadores ni enlaces de correos ya enviados. El correo de recuperación
no se tocó: vuelve a la *Site URL* de Supabase, que es la raíz, y de ahí la
redirección lo lleva con su token (el `#…` se conserva al redirigir).

La base de datos real es un proyecto de Supabase aparte del de pruebas
(`fbxdwryppfctuwlnjjqr`, organización CIIP), creado el 1 de septiembre de
2026 y al día con `TODO-EN-ORDEN.sql` (comprobado pieza a pieza el 25-09-2026). El registro de
cuentas nuevas está cerrado ahí (*Allow new users to sign up* apagado):
las cuentas las crea el equipo del CIIP desde Supabase, no hay
autorregistro. `config.js` decide solo, por dónde se abre la página, si
usar esa base o la de pruebas — ver el bloque de comentarios ahí mismo.

---

## Archivos

| Archivo | Qué es |
|---|---|
| `acceso.html` | Iniciar sesión, y clave nueva (por el enlace del correo de recuperación) |
| `ciip-ventanilla-unica-local.html` | El panel, una vez dentro: el marcado, el tema y el guardián de la sesión, que tienen que correr antes que nada |
| `panel.js` · `panel.css` · `i18n.js` | El guion, los estilos y el diccionario de los seis idiomas del panel. Estaban dentro del HTML (1,8 MB en un archivo) hasta el 25-09-2026; se cargan en el mismo sitio y el mismo orden. **No se vuelven a meter dentro**: `pruebas/cerrojos.js` lo vigila, porque cargados dos veces el panel se rompe |
| `textos-editables.js` · `.css` | El modo «Editar textos» del administrador. Aparte a propósito: se quita entero quitando sus dos etiquetas |
| `assets/` | La fuente del título (`instrument-serif.ttf`), los dos logos del CIIP del panel y el fondo del acceso |
| `config.js` | **Lo único que hay que rellenar**: las claves de Supabase |
| `api/asistente.js` | El intermediario del asistente: lo único que corre en un servidor. Guarda la clave de Anthropic, que el navegador no puede ver. Ver `api/LEEME.md` |
| `pasos.js` | Los cuatro pasos de cada trámite, en los seis idiomas |
| `supabase-*.sql` | **Las fuentes del esquema de la base**, un archivo por tema. Cada uno dice en su cabecera qué hace y detrás de cuál va. La lista y el orden están en **un solo sitio**, `pruebas/juntar-sql.js`: de ahí salen `TODO-EN-ORDEN.sql` y la tanda de `PROBAR-SQL.bat`. Un cambio en la base se hace aquí, no en un `CORRER-*.sql` suelto |
| `TODO-EN-ORDEN.sql` | Todos los `supabase-*.sql` unidos en su orden. **Generado**: `node pruebas/juntar-sql.js`, nunca a mano. Es lo que se pega entero en el SQL Editor para montar una base desde cero |
| `logos/` | Logos de los organismos, con su procedencia en [FUENTES.md](logos/FUENTES.md) |
| `banderas/` | 197 banderas SVG para el buscador de países, con su procedencia en [FUENTES.md](banderas/FUENTES.md) |
| `historico/` | Lo que ya pasó y no se usa: los SQL de un solo uso ya aplicados en producción, la demostración de partida (`original/`), las capturas, los bocetos de diseño y la revisión de las cerraduras. Ver [historico/LEEME.md](historico/LEEME.md) |

## Atajos

| Doble clic en | Para |
|---|---|
| `ABRIR-LOCAL.bat` | Levantar el proyecto en `http://localhost:8080`, solo para ti |
| `ABRIR-EN-RED.bat` | Igual, pero abierto a la red: otros PC de la oficina pueden entrar |
| `PROBAR-TODO.bat` | **Las doce de una vez**, con un cuadro al final: cuántas fueron bien, cuáles fallaron y cuáles **no se pudieron probar y por qué**. Es lo que hay que mirar antes de subir a `main` |
| `PROBAR.bat` | Lanzar las 33 pruebas del acceso |
| `PROBAR-PANEL.bat` | Primero los cerrojos de seguridad (`pruebas/cerrojos.js`, se para si falta alguno); luego las pruebas del panel en sus 17 expedientes —**tienen que salir todas en verde**, 8.617 el 25-09-2026— y las de las claves de traducción |
| `PROBAR-A-MANO.bat` | Abrir el panel **para mirarlo y pulsarlo**, contra la misma base de mentira de las pruebas: sus expedientes —vacío, con trabajo, gestor, administrador, sin los SQL nuevos— con un índice para elegir. Sin clave y sin tocar la base real |
| `PROBAR-CONECTOR.bat` | Lanzar las 28 pruebas del conector del RIF |
| `PROBAR-SAREN.bat` | Lanzar las 42 pruebas del conector de la constitución de compañía |
| `PROBAR-TRABAJADOR.bat` | Lanzar las 44 pruebas del trabajador, que es quien ejecuta lo que el conector decide |
| `PROBAR-AVISOS.bat` | Lanzar las 38 pruebas de los avisos: que cada quien los reciba en su idioma y que ninguno se pierda |
| `PROBAR-BARRENDERO.bat` | Lanzar las 20 pruebas del barrendero, que se lleva del cubo los archivos que se quedaron sin ficha. Sobre todo la de no dar por borrado lo que el cubo no acepto |
| `PROBAR-PAGOS.bat` | Lanzar las 32 pruebas del cobrador, sobre todo las de no cobrar dos veces |
| `PROBAR-SQL.bat` | Ejecutar todos los `supabase-*.sql`, en el orden de `juntar-sql.js`, en un Postgres de esta máquina y comprobar que los triggers saltan. No pide claves ni toca ningún servidor tuyo |
| `PROBAR-CERRADURAS.bat` | Comprobar las políticas RLS **entrando de verdad** en el Supabase de pruebas. Se niega a correr contra el real |

## Puesta en marcha

1. Crear un proyecto en [supabase.com](https://supabase.com)
2. *SQL Editor* → pegar **entero** `TODO-EN-ORDEN.sql` y pulsar **Run**. Lleva
   todos los `supabase-*.sql` en el orden bueno —el de `pruebas/juntar-sql.js`,
   el mismo que ejecuta `PROBAR-SQL.bat`— y se puede correr más de una vez.

   **Cópialo desde VS Code o desde GitHub, nunca desde una consola de
   Windows**: la consola enseña el UTF-8 con otra codificación y lo pegado
   se guarda con los acentos rotos («C├®dula»). Pasó el 25-09-2026.

   Saltarse alguno no rompe el panel —abre igual, y así lo prueban los
   expedientes `sinsql`, `sinsector`, `sinsectorsql` y `sincatalogo`—, pero
   la pantalla que dependa de él se queda muda
3. Las claves van en `config.js`, en el bloque del proyecto que toque (`real`
   o `pruebas`): *Project URL* y *anon key*. Se editan a mano; el antiguo
   `CONFIGURAR.bat` escribía la misma clave en los dos bloques y se retiró
   el 25-09-2026
4. En Supabase, *Authentication → URL Configuration*, autorizar la dirección
   desde la que se abra el proyecto
5. `ABRIR-LOCAL.bat`

El recorrido completo de verificación está en [PRUEBAS.md](PRUEBAS.md).

## Cómo se navega el panel

Tres niveles, todos dentro del mismo archivo. La dirección cambia, así que la
flecha *atrás* del navegador funciona y cualquier pantalla se comparte por
enlace:

| Nivel | Dirección | Qué se ve |
|---|---|---|
| Portada | *(sin nada)* | Las cuatro etapas y los quince trámites |
| Fase | `#fase-2` | Solo los trámites de esa etapa |
| Trámite | `#tramite-c5` | El detalle y sus cuatro pasos |
| Citas | `#citas` | Tus citas con el CIIP, la viva y las pasadas |
| Mis trámites | `#tramites` | Las solicitudes que has hecho, con su estado |
| Usuarios | `#usuarios` | Solo admin: quién entra, con qué rol, y cuánto trabajo hay encima de la mesa |
| Mi empresa | `#empresa` | Los datos de la compañía, escritos una vez, que rellenan los formularios |
| Documentos | `#documentos` | La bóveda: todo lo que has subido, con lo vencido primero |
| Ayuda | `#ayuda` | Preguntas y respuestas, y dónde hacer la firma electrónica y los certificados médicos |
| Activos | `#activos` | El banco de oportunidades del CIIP. El equipo publica y corrige desde aquí |

Una dirección que no exista (`#fase-9`, `#tramite-c99`) devuelve a la portada
en vez de dejar la pantalla en blanco.

## Qué está probado y qué no

Las dos tandas ejecutan la página de verdad en un navegador sin ventana; no
leen el código, lo corren.

**El acceso** (33 pruebas, `PROBAR.bat`). Estuvieron rotas: se escribieron
para cuatro formularios y `acceso.html` hoy solo tiene dos —iniciar sesión
y clave nueva—, porque las cuentas las crea el equipo del CIIP desde
Supabase, sin autorregistro. El arnés buscaba campos que ya no existen y se
cortaba antes de correr ni una prueba.

De las dos salidas que quedaban escritas aquí se tomó la primera: **se
achicó el arnés a los dos formularios reales**. Se fueron con él las
pruebas del registro, de la recuperación, del medidor de fuerza, del
buscador de países, del arreglo de mayúsculas del nombre y del almacén de
sesión — todas ellas de piezas que ya no están en la página. No se dejaron
comentadas: una prueba de algo que no existe no protege nada y hace creer
que sí. Si el CIIP decide que el registro vuelve, sus pruebas se recuperan
del historial.

Y se arregló lo que hacía que nadie se enterara, que era lo de fondo: **los
diez `.bat` contestaban 0 pasara lo que pasara**, porque el `echo.` del
final pisaba el código de salida. Ahora lo devuelven. Además el arnés
empieza comprobando que la página tiene las piezas que va a usar, así que
si mañana desaparece otra sale una prueba roja con su nombre en vez de
morirse la tanda entera en silencio.

**El panel** (8.617 comprobaciones en 17 expedientes, `PROBAR-PANEL.bat`): los contadores del camino y de
los filtros, que las cuatro etapas son cuatro cajas parejas, la franja de "te
toca a ti", el buzón de avisos, la ventana de tu perfil, las citas, el banco de
activos —mirarlo, y publicarlo, corregirlo y borrarlo si eres del equipo—, que el panel
abre en el idioma de tu país y que te llama por TU nombre. Todo eso
necesita datos para decir algo, así que se corre con un Supabase de mentira
([pruebas/supabase-mentira.js](pruebas/supabase-mentira.js)) y con diecisiete
expedientes: con trabajo, vacío, sin nombre, del gestor, del administrador, sin
los SQL nuevos, con los tramos de la constitución… Buena parte de lo que hay que
comprobar es que el panel se calla cuando no hay nada que decir, y eso no se ve
en la misma pasada que comprueba que habla.

**Tiene que salir entero en verde**, y desde el 25-09-2026 sale: tres pasadas
seguidas de 8.617/8.617. Hasta entonces arrastraba unos 80 rojos fijos —pruebas
que describían pantallas de antes de un rediseño, una medida de píxeles que en
un Linux mide otra letra, un simulador que se había quedado atrás del panel y
pruebas que ganaban o perdían una carrera con la subida de un archivo— y con
80 rojos fijos el rojo nuevo no se ve. Si hoy sale uno, es de verdad.

**El SQL** (`PROBAR-SQL.bat`): levanta un PostgreSQL vacío
en una carpeta temporal —sin claves, sin tocar ningún servidor de la máquina—,
ejecuta todos los `supabase-*.sql` **en el orden de `pruebas/juntar-sql.js`**,
que ya es la primera prueba, y luego intenta lo que no se debe: saltarse la escalera de estados,
ascender a otro a admin, escribir en un catálogo. Se entra como entra Supabase,
con `set role authenticated` y el `sub` en `request.jwt.claims`, porque
dejando el rol de dueño el RLS no se aplica —un dueño se salta sus propias
políticas— y saldría todo en verde sin haber comprobado ni una cerradura. Lo que
Postgres no puede decir queda fuera: el tope del cubo lo aplica storage-api, que
es otro servicio.

**Las cerraduras** (`PROBAR-CERRADURAS.bat`, [pruebas/rls.js](pruebas/rls.js)):
la única tanda que habla con un Supabase de verdad. Las otras tres corren contra
[pruebas/supabase-mentira.js](pruebas/supabase-mentira.js), un doble que concede
o niega según lo que se escribió que debería pasar, no según lo que la base
hace; que estén en verde no dice nada sobre si un inversionista puede leer el
expediente de otro. Esta entra con dos cuentas y trata de hacer lo que no debe:
leer lo ajeno, escribir en la carpeta de otro, ascenderse de rol, saltarse la
escalera de estados, colar un archivo que el cubo no admite. Cada intento tiene
que fallar. Necesita `pruebas/cuentas.local.json` —que `.gitignore` no deja
subir— y una tercera cuenta con rol gestor para la parte que un inversionista no
puede ni intentar.

**Sin probar**: iniciar sesión de verdad, los correos de recuperación, el
trigger que crea el perfil, y el recorrido completo de enviar una
solicitud con sus recaudos desde el panel. Requiere un proyecto de
Supabase y se hace a mano.

## Límites conocidos

- **El guardián del panel es del lado del cliente.** Impide el paso en el
  navegador, pero cualquiera puede pedir el HTML directamente. La protección
  real de los datos son las políticas RLS.
- **La ficha antigua del trámite sigue en el código sin pintarse** (`FICHA`,
  `pintaFichaTramite`, las clases `.ft-*` y las claves `ft_*`). Se dejó a
  propósito, con los plazos legales de dieciséis trámites; borrarla o volver
  a enseñarla es una decisión pendiente.

## Seguridad

La clave `anon` de `config.js` es pública por diseño y viaja al navegador.
Lo que protege los datos son las políticas RLS y los disparadores de los
`supabase-*.sql`, revisados el 25-09-2026 (el estado de un papel lo pone el
equipo, lo del CIIP en un trámite no lo toca el inversionista, el bloqueo es
entero, el tope del asistente se cuenta en la base).

Varios arreglos de esa revisión viven en archivos que todo el mundo toca
—la versión fija de supabase-js con su huella, la firma de las respuestas del
asistente, la clave nueva solo desde el correo, la CSP de `vercel.json`— y se
perdieron más de una vez al subir encima una copia vieja. `pruebas/cerrojos.js`
los vigila y `PROBAR-PANEL.bat` se para si falta alguno.

**Nunca** poner ahí la clave `service_role`: esa se salta el RLS por completo.
