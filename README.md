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
| `supabase-setup.sql` | Esquema y políticas RLS. Se ejecuta una vez |
| `original/` | La demostración de partida, intacta, como referencia |

## Atajos

| Doble clic en | Para |
|---|---|
| `CONFIGURAR.bat` | Pegar las claves de Supabase sin editar archivos |
| `ABRIR-LOCAL.bat` | Levantar el proyecto en `http://localhost:8080` |
| `PROBAR.bat` | Lanzar las 42 pruebas automáticas |

## Puesta en marcha

1. Crear un proyecto en [supabase.com](https://supabase.com)
2. *SQL Editor* → pegar `supabase-setup.sql` → **Run**
3. `CONFIGURAR.bat` con la *Project URL* y la *anon key*
4. En Supabase, *Authentication → URL Configuration*, autorizar la dirección
   desde la que se abra el proyecto
5. `ABRIR-LOCAL.bat`

El recorrido completo de verificación está en [PRUEBAS.md](PRUEBAS.md).

## Qué está probado y qué no

**Probado** (42 pruebas automáticas, `PROBAR.bat`): validación de los cuatro
formularios, navegación entre vistas, los seis idiomas, el buscador de países,
el almacenamiento de sesión, el logo y la carga de `config.js`. Las pruebas
ejecutan la página de verdad en un navegador sin ventana, no leen el código.

**Sin probar**: todo lo que habla con Supabase — crear una cuenta real,
iniciar sesión, los correos de confirmación y recuperación, el trigger que
crea el perfil. Requiere un proyecto de Supabase y se hace a mano.

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
