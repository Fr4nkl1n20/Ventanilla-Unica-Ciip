# CIIP · Ventanilla Única del Inversionista

Prototipo de la ventanilla única para inversionistas extranjeros, con
pantalla de acceso conectada a Supabase.

## Archivos

| Archivo | Qué es |
|---|---|
| `acceso.html` | Pantalla de acceso: iniciar sesión, crear cuenta, recuperar clave y fijar clave nueva. Cuatro vistas en un solo archivo. |
| `ciip-ventanilla-unica-local.html` | El panel del inversionista: 15 trámites en 4 fases, preguntas frecuentes y asistente de demostración. |
| `supabase-setup.sql` | Esquema de base de datos: tabla `perfiles`, políticas RLS y trigger de alta automática. |
| `original/` | El archivo tal como llegó, sin tocar. Es un fragmento HTML sin cabecera; se conserva solo como respaldo. |

## Puesta en marcha

### 1. Subir el esquema a Supabase

Panel de Supabase → **SQL Editor** → *New query* → pega `supabase-setup.sql`
completo → **Run**. Es idempotente: se puede ejecutar varias veces sin romper
nada.

### 2. Conectar `acceso.html`

Abre el archivo y busca el bloque de configuración cerca del inicio del
`<script>`. Es lo único que hay que rellenar:

```js
const SUPABASE_URL      = 'https://TU-PROYECTO.supabase.co';
const SUPABASE_ANON_KEY = 'TU_CLAVE_ANON_PUBLICA';
const RUTA_PANEL        = './ciip-ventanilla-unica-local.html';
```

Los dos primeros valores salen de **Project Settings → API**.

La clave `anon` es pública y puede ir en el navegador: por sí sola no da
acceso a los datos, la protección real la dan las políticas RLS del paso 1.
**Nunca pongas aquí la clave `service_role`.**

### 3. Configurar las URL de retorno

Supabase → **Authentication → URL Configuration**: pon tu dominio en
*Site URL* y en *Redirect URLs*. Sin esto, los correos de confirmación y de
recuperación de clave no saben a dónde devolver al usuario.

## Probar en local

Doble clic sobre `acceso.html` sirve para ver el diseño, pero **los enlaces
por correo no funcionan con `file://`**: el navegador trata el origen como
`null` y Supabase no puede devolver al usuario.

Para probar el flujo completo, levanta un servidor en esta carpeta:

```
python -m http.server 8000
```

y entra por `http://localhost:8000/acceso.html`. Añade ese mismo origen a las
*Redirect URLs* del paso 3.

## Notas de mantenimiento

**El texto visible no está en el HTML.** Los elementos con `data-i18n` reciben
su contenido del diccionario `I18N` al cargar la página; editar el texto en el
marcado no tiene efecto. Para cambiar un texto hay que editar el diccionario.

**Sobre el panel** (`ciip-ventanilla-unica-local.html`):

- Todavía **no comprueba la sesión**: quien escriba la URL entra sin pasar por
  el acceso. Falta añadir esa comprobación al cargar.
- Los datos del inversionista (Marco Bianchi, los 15 trámites y sus estados)
  están escritos a mano en el marcado; no vienen de la base de datos.
- El asistente responde por coincidencia de palabras clave contra respuestas
  fijas. No hay IA ni backend detrás.
- Contiene CSS muerto (`.hero`, `.hero-ring`, `.duo`, `.gestor`, `.help-list`)
  y claves de idioma sin usar, de una portada que se eliminó.
