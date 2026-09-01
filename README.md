# CIIP · Ventanilla Única del Inversionista

Acceso y panel para inversionistas extranjeros que tramitan su llegada,
constitución de empresa y operación en Venezuela.

Es un sitio **estático**: HTML, CSS y JavaScript sin compilación. La
autenticación y los datos los pone Supabase.

---

## Archivos

| Archivo | Qué es |
|---|---|
| `acceso.html` | Iniciar sesión, crear cuenta, recuperar clave, clave nueva |
| `ciip-ventanilla-unica-local.html` | El panel, una vez dentro |
| `config.js` | **Lo único que hay que rellenar**: las claves de Supabase |
| `pasos.js` | Los cuatro pasos de cada trámite, en los seis idiomas |
| `supabase-setup.sql` | Esquema del acceso y políticas RLS. Se ejecuta una vez |
| `supabase-tramites.sql` | Esquema de trámites y bóveda de documentos. Se ejecuta una vez |
| `supabase-citas.sql` | Esquema de las citas. Va **después** de los dos anteriores |
| `supabase-admin.sql` | Permite que un admin reparta roles desde el panel, sin entrar a Supabase |
| `supabase-emision.sql` | Permisos para que el equipo entregue por el panel el documento que emitió el ente |
| `supabase-empresa.sql` | Los datos de la compañía del inversionista, para no reescribirlos en cada formulario |
| `supabase-activos.sql` | Esquema del banco de activos. La tabla nace vacía: la llena el equipo desde el propio panel |
| `supabase-identidad.sql` | El registro de las comprobaciones de identidad que hace el equipo |
| `supabase-presencia.sql` | `tocar_visto()`: apunta con la hora del servidor cuándo estuviste por última vez |
| `supabase-sectores.sql` | El catálogo de sectores y el que eliges tú. Usa `es_admin()`, así que va **después** de `supabase-admin.sql` |
| `supabase-gestor.sql` | Lo que necesita el equipo del CIIP: leer los perfiles, anotar una devolución, y cómo nombrar un gestor |
| `supabase-catalogos.sql` | Encender y apagar un trámite del catálogo desde el panel, dejando rastro de quién lo movió |
| `supabase-bitacora.sql` | El registro de lo que hace el equipo: quién tocó el catálogo, los roles, los papeles y las citas |
| `supabase-bloqueo.sql` | Bloquear una cuenta: deja de poder escribir en trámites, documentos y citas |
| `supabase-acompanamiento.sql` | Los ajustes de la burbuja y la nube de soporte, para que los mande el admin y no el código |
| `supabase-cola.sql` | La lista de lo que hay que hacer con los organismos **cuando nadie mira**. La llena un trigger y la vacía el trabajador |
| `supabase-avisos.sql` | El buzón de salida: qué hay que decirle a quién. Se escribe solo al cambiar un estado, y lo vacía el mensajero |
| `supabase-aranceles.sql` | Las tasas y lo que se debe por cada trámite. La tabla nace vacía: aquí no se inventan cifras oficiales |
| `supabase-huellas.sql` | La huella SHA-256 de cada documento, y cómo un tercero verifica uno emitido sin saber de quién es |
| `supabase-encadenado.sql` | Qué papel emite cada trámite. Con eso el panel deduce solo qué trámite espera a cuál |
| `supabase-plazos.sql` | Cuánto debería tardar cada trámite, para poder decir cuándo va más lento de lo prometido |
| `supabase-una-viva.sql` | Una sola solicitud viva por persona y trámite. Las resueltas y las devueltas no cuentan |
| `logos/` | Logos de los organismos, con su procedencia en [FUENTES.md](logos/FUENTES.md) |
| `banderas/` | 197 banderas SVG para el buscador de países, con su procedencia en [FUENTES.md](banderas/FUENTES.md) |
| `original/` | La demostración de partida, intacta, como referencia |

## Atajos

| Doble clic en | Para |
|---|---|
| `CONFIGURAR.bat` | Pegar las claves de Supabase sin editar archivos |
| `ABRIR-LOCAL.bat` | Levantar el proyecto en `http://localhost:8080`, solo para ti |
| `ABRIR-EN-RED.bat` | Igual, pero abierto a la red: otros PC de la oficina pueden entrar |
| `PROBAR.bat` | Lanzar las 57 pruebas del acceso |
| `PROBAR-PANEL.bat` | Lanzar las 2668 pruebas del panel y las 10 comprobaciones de las claves de traducción |
| `PROBAR-CONECTOR.bat` | Lanzar las 28 pruebas del conector del RIF |
| `PROBAR-SAREN.bat` | Lanzar las 42 pruebas del conector de la constitución de compañía |
| `PROBAR-TRABAJADOR.bat` | Lanzar las 44 pruebas del trabajador, que es quien ejecuta lo que el conector decide |
| `PROBAR-AVISOS.bat` | Lanzar las 38 pruebas de los avisos: que cada quien los reciba en su idioma y que ninguno se pierda |
| `PROBAR-PAGOS.bat` | Lanzar las 32 pruebas del cobrador, sobre todo las de no cobrar dos veces |
| `PROBAR-SQL.bat` | Ejecutar los once archivos SQL en un Postgres de esta máquina y comprobar que los triggers saltan. No pide claves ni toca ningún servidor tuyo |
| `PROBAR-CERRADURAS.bat` | Comprobar las políticas RLS **entrando de verdad** en el Supabase de pruebas. Se niega a correr contra el real |

## Puesta en marcha

1. Crear un proyecto en [supabase.com](https://supabase.com)
2. *SQL Editor* → pegar cada archivo SQL y pulsar **Run**, **en este orden**.
   Son veintidós, no cuatro: cada uno que falte apaga su pantalla del panel.
   Este orden no está deducido de las cabeceras: lo ejecuta `PROBAR-SQL.bat`
   en un PostgreSQL de usar y tirar, y si uno usara algo que otro define
   después, esa tanda se caería diciendo cuál

   | # | Archivo | Por qué va ahí |
   |---|---|---|
   | 1 | `supabase-setup.sql` | Define `tocar_actualizado_en()`, que usan casi todos |
   | 2 | `supabase-tramites.sql` | Define `es_gestor()` |
   | 3 | `supabase-admin.sql` | Define `es_admin()` |
   | 4 | `supabase-citas.sql` | Usa `es_gestor()` |
   | 5 | `supabase-empresa.sql` | Usa `es_gestor()` |
   | 6 | `supabase-activos.sql` | Usa `es_gestor()` |
   | 7 | `supabase-identidad.sql` | Usa `es_gestor()` |
   | 8 | `supabase-emision.sql` | Usa `es_gestor()` |
   | 9 | `supabase-presencia.sql` | No depende de nadie |
   | 10 | `supabase-sectores.sql` | Usa `es_admin()`, del 3 |
   | 11 | `supabase-catalogos.sql` | Después del 2, del 3 y del 10 |
   | 12 | `supabase-bitacora.sql` | Después del 11, y se engancha a `citas` |
   | 13 | `supabase-bloqueo.sql` | Se engancha a `tramites`, `documentos` y `citas` |
   | 14 | `supabase-acompanamiento.sql` | Usa `es_admin()` |
   | 15 | `supabase-gestor.sql` | Las políticas del equipo |
   | 16 | `supabase-cola.sql` | Necesita los trámites y `es_gestor()` |
   | 17 | `supabase-avisos.sql` | Cuelga del historial de trámites |
   | 18 | `supabase-aranceles.sql` | Envuelve el encolado del 16 |
   | 19 | `supabase-huellas.sql` | Sólo necesita `documentos` |
   | 20 | `supabase-encadenado.sql` | Sólo necesita el catálogo |
   | 21 | `supabase-plazos.sql` | Sólo necesita el catálogo |
   | 22 | `supabase-una-viva.sql` | El último. Sólo necesita `tramites` |

   Del 4 al 9 el orden entre ellos da igual: solo piden que el 2 esté hecho.

   **Cuidado con volver a ejecutar `supabase-setup.sql`.** El 3 redefine
   `bloquear_cambio_de_rol()`, que nace en el 1. Correr el 1 otra vez la deja
   como estaba y el admin se queda sin repartir roles, sin decir nada. Si lo
   haces, corre el 3 detrás.

   Saltarse alguno del 4 al 14 no rompe el panel —abre igual, y así lo prueban
   los expedientes `sinsql`, `sinsector`, `sinsectorsql` y `sincatalogo`—,
   pero la pantalla que dependa de él se queda muda
3. `CONFIGURAR.bat` con la *Project URL* y la *anon key*
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
| Ayuda | `#ayuda` | Cómo funciona el panel: los pasos, los distintivos y cómo hablar con el equipo |
| Activos | `#activos` | El banco de oportunidades del CIIP. El equipo publica y corrige desde aquí |

Una dirección que no exista (`#fase-9`, `#tramite-c99`) devuelve a la portada
en vez de dejar la pantalla en blanco.

## Qué está probado y qué no

Las dos tandas ejecutan la página de verdad en un navegador sin ventana; no
leen el código, lo corren.

**El acceso** (57 pruebas, `PROBAR.bat`): validación de los cuatro formularios,
el medidor de fuerza de la clave, navegación entre vistas, los seis idiomas, el
buscador de países, el almacenamiento de sesión, el logo y la carga de
`config.js`.

**El panel** (2668 pruebas, `PROBAR-PANEL.bat`): los contadores del camino y de
los filtros, que las cuatro etapas son cuatro cajas parejas, la franja de "te
toca a ti", el buzón de avisos, la ventana de tu perfil, las citas, el banco de
activos —mirarlo, y publicarlo, corregirlo y borrarlo si eres del equipo—, que el panel
abre en el idioma de tu país y que te llama por TU nombre. Todo eso
necesita datos para decir algo, así que se corre con un Supabase de mentira
([pruebas/supabase-mentira.js](pruebas/supabase-mentira.js)) y con TRES
expedientes: uno con una solicitud devuelta y otra en borrador, otro vacío,
otro de una cuenta cuyo perfil no trae nombre, y otro del equipo del CIIP con
dos citas ajenas esperando en la cola. Buena parte de lo que hay que
comprobar es que el panel se calla cuando no hay nada que decir, y eso no se ve
en la misma pasada que comprueba que habla.

**El SQL** (21 comprobaciones, `PROBAR-SQL.bat`): levanta un PostgreSQL vacío
en una carpeta temporal —sin claves, sin tocar ningún servidor de la máquina—,
ejecuta los veintidós archivos **en el orden de más arriba**, que ya es la primera
prueba, y luego intenta lo que no se debe: saltarse la escalera de estados,
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

**Sin probar**: crear una cuenta, iniciar sesión, los correos de confirmación y
recuperación, el trigger que crea el perfil, y el recorrido completo de enviar
una solicitud con sus recaudos desde el panel. Requiere un proyecto de Supabase
y se hace a mano.

## Límites conocidos

- **El panel muestra datos de ejemplo.** Nombre, iniciales, rol y país sí
  salen de `public.perfiles`, pero los quince trámites, la empresa y las
  cifras están escritos a mano. Con sesión activa se avisa de ello en pantalla.
- **El guardián del panel es del lado del cliente.** Impide el paso en el
  navegador, pero cualquiera puede pedir el HTML directamente. La protección
  real de los datos son las políticas RLS.
- **Hay CSS y traducciones muertas**: existe el diseño completo de una
  cabecera `.hero` con doce claves de traducción, pero ningún elemento del
  marcado las usa.

## Seguridad

La clave `anon` de `config.js` es pública por diseño y viaja al navegador.
Lo que protege los datos es el RLS de `supabase-setup.sql`.

**Nunca** poner ahí la clave `service_role`: esa se salta el RLS por completo.
