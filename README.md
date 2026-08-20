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
| `supabase-activos.sql` | Esquema del banco de activos. La tabla nace vacía: la llena el equipo desde el propio panel |
| `supabase-gestor.sql` | Lo que necesita el equipo del CIIP: leer los perfiles, anotar una devolución, y cómo nombrar un gestor. Va el último |
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
| `PROBAR-PANEL.bat` | Lanzar las 476 pruebas del panel |

## Puesta en marcha

1. Crear un proyecto en [supabase.com](https://supabase.com)
2. *SQL Editor* → pegar `supabase-setup.sql` → **Run**. Luego
   `supabase-tramites.sql`, `supabase-citas.sql` y `supabase-gestor.sql`, en
   ese orden: el segundo define `es_gestor()`, que los dos últimos usan
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

**El panel** (476 pruebas, `PROBAR-PANEL.bat`): los contadores del camino y de
los filtros, que las cuatro etapas son cuatro cajas parejas, la franja de "te
toca a ti", el buzón de avisos, la ventana de tu perfil, las citas, el banco de
activos —mirarlo, y publicarlo y corregirlo si eres del equipo—, que el panel
abre en el idioma de tu país y que te llama por TU nombre. Todo eso
necesita datos para decir algo, así que se corre con un Supabase de mentira
([pruebas/supabase-mentira.js](pruebas/supabase-mentira.js)) y con TRES
expedientes: uno con una solicitud devuelta y otra en borrador, otro vacío,
otro de una cuenta cuyo perfil no trae nombre, y otro del equipo del CIIP con
dos citas ajenas esperando en la cola. Buena parte de lo que hay que
comprobar es que el panel se calla cuando no hay nada que decir, y eso no se ve
en la misma pasada que comprueba que habla.

**Sin probar**: todo lo que habla con el Supabase de verdad — crear una cuenta,
iniciar sesión, los correos de confirmación y recuperación, el trigger que crea
el perfil, enviar una solicitud y subir recaudos. Requiere un proyecto de
Supabase y se hace a mano.

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
