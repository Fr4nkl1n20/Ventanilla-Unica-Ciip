# Guía de pruebas

Cómo comprobar que el proyecto funciona: primero lo automático, después el
acceso a mano contra un Supabase de verdad.

> Puesta al día el 25-09-2026. El acceso ya no tiene registro, ni «¿olvidaste
> tu clave?», ni la casilla de «mantener la sesión abierta»: las cuentas las
> crea el CIIP y la clave nueva solo llega por el correo de recuperación. Lo
> que esta guía decía de esas pantallas se ha quitado.

---

## Parte 0 · La forma rápida: doble clic en `PROBAR-TODO.bat`

**Haz doble clic en `PROBAR-TODO.bat`.** Corre las doce tandas —los
conectores, el SAREN, el trabajador, los pagos, los avisos, el barrendero, el
asistente, el lector, el acceso, el panel, el SQL y las cerraduras— y termina
con un cuadro: cuántas fueron bien, cuáles fallaron y **cuáles no se pudieron
probar y por qué**.

Esa tercera columna es la razón de que exista. Una tanda que no corre por
falta de una clave local no es un fallo, pero tampoco es un verde, y contarla
como verde es exactamente lo que pasó: el arnés del acceso estuvo días sin
ejecutarse mientras su `.bat` contestaba que todo bien.

`PROBAR-A-MANO.bat` no entra en la tanda: no es una prueba, es la revisión a
ojo, y abre el navegador.

### El panel en verde quiere decir algo

El arnés del panel (`PROBAR-PANEL.bat`) corre 17 expedientes de prueba y
**tiene que salir entero en verde**: 8.618 de 8.618 el 25-09-2026. Hasta ese
día arrastraba unos 80 fallos viejos —pruebas que no se habían puesto al día
tras un rediseño, una medida de píxeles que solo vale en Windows y cuatro que
fallaban o no según quién ganara una carrera— y con 80 rojos fijos un rojo
nuevo no se ve. Si hoy sale uno, es de verdad.

Antes de nada, `PROBAR-PANEL` corre `pruebas/cerrojos.js`: comprueba que
siguen en su sitio los arreglos de seguridad que viven en archivos
compartidos (la versión fija de supabase-js, la firma del asistente, la clave
nueva solo desde el correo, la CSP…). Si falta alguno **se para**: casi
siempre es que se editó una copia vieja del archivo. Trae la última
(`git pull`) y rehaz encima tu cambio.

### Solo el acceso

`PROBAR.bat`: **33 pruebas** que cubren la parte 1 de esta guía y cosas que a
mano son tediosas —que ningún texto se quede sin traducir en los seis
idiomas, que la ilustración cargue, que el ojo de la clave la muestre y la
esconda, que `#nueva` escrito a mano no abra la vista de clave nueva—.

No hace falta instalar nada: usa el Chrome o el Edge que ya tienes. **No
modifica `acceso.html`**; trabaja sobre una copia temporal en
`%TEMP%\ciip-pruebas`. Si sale `FALLA`, debajo aparece qué esperaba y qué
obtuvo.

Los archivos están en `pruebas\`: `arnes.js` son las pruebas del acceso
(añadir una es copiar una línea `caso(...)`) y `ejecutar.ps1` el lanzador;
`arnes-panel.js` y `panel.ps1`, los del panel.

**Lo que estas pruebas NO cubren:** nada que hable con un Supabase de verdad.
Para eso, las partes 2 a 4, y `PROBAR-CERRADURAS.bat`.

---

## Parte 1 · Lo que puedes probar AHORA, sin Supabase

La validación del formulario corre **antes** de tocar la base de datos, así
que funciona aunque `config.js` no tenga claves. Abre `acceso.html` y recorre
esta lista.

| # | Qué hacer | Qué debe pasar |
|---|---|---|
| 1 | Entrar con los dos campos vacíos | «Completa todos los campos.» y el campo del correo en rojo |
| 2 | Correo `hola` + cualquier clave | «Introduce un correo válido.» |
| 3 | Todo correcto, sin claves en `config.js` | «El acceso no está conectado a la base de datos todavía.» |
| 4 | Botón del ojo en el campo de la clave | Alterna entre puntos y texto |
| 5 | Escribir `#nueva` al final de la dirección | **No** abre «Crea una clave nueva»: se queda en el login |
| 6 | Cambiar de idioma con un mensaje de error en pantalla | El mensaje **también** se traduce |
| 7 | Cambiar el tema y recargar | Se mantiene el tema elegido |
| 8 | Estirar y encoger la ventana | El formulario queda centrado; la página no se desplaza |

Si el paso 3 muestra un mensaje distinto a «no está conectado», algo va mal
antes de tiempo.

---

## Parte 2 · Preparar Supabase

### 2.1 Crear el proyecto

1. Entra en <https://supabase.com> y crea un proyecto.
2. Ve a **Project Settings → API** y copia:
   - **Project URL** → será `SUPABASE_URL`
   - **anon / public key** → será `SUPABASE_ANON_KEY`

> La clave `anon` es pública y puede ir en el navegador. La que **nunca** debe
> salir del servidor es `service_role`.

### 2.2 Crear las tablas

**SQL Editor → New query**, pega **entero** `TODO-EN-ORDEN.sql` y pulsa
**Run**. Es la unión de todos los `supabase-*.sql` en el orden correcto (la
lista está en `pruebas/juntar-sql.js`) y se puede ejecutar varias veces sin
romper nada.

> **Cópialo desde VS Code o desde GitHub, nunca desde una consola de
> Windows.** La consola enseña el UTF-8 como si fuera otra codificación, y lo
> que se pega se guarda con los acentos rotos («C├®dula»). Pasó el 25-09-2026
> con doce nombres del catálogo.

Si cambias un `supabase-*.sql`, regenera el archivo único:
`node pruebas/juntar-sql.js`. `TODO-EN-ORDEN.sql` no se edita a mano.

Comprueba que el RLS quedó activo:

```sql
select relname, relrowsecurity from pg_class where relname = 'perfiles';
```

Debe devolver `true`.

### 2.3 Rellenar `config.js`

`config.js` tiene **dos** proyectos, `real` y `pruebas`, y elige solo por
dónde se abre la página: `localhost`, `file://` o una IP de la oficina →
pruebas; cualquier otra dirección → real. Pega la *Project URL* y la *anon
key* en el bloque que toque. La consola del navegador dice al cargar contra
cuál estás.

Lo leen `acceso.html` y el panel, así que no hay forma de configurar uno y
dejarse el otro.

---

## Parte 3 · Servirlo por HTTP

**Con `file://` no se puede probar el circuito completo**: el enlace del
correo de recuperación no puede volver a un archivo local.

Doble clic en **`ABRIR-LOCAL.bat`**: levanta `http://localhost:8080` solo para
ti. **`ABRIR-EN-RED.bat`** hace lo mismo abierto a la red de la oficina. Los
dos sirven la carpeta sin `.git`, sin archivos ocultos y sin las cuentas de
prueba (`*.local.json`).

### 3.1 Autorizar las URLs en Supabase

**Authentication → URL Configuration**:

- **Site URL**: `http://localhost:8080/acceso.html`
- **Redirect URLs**: añade `http://localhost:8080/**`

Sin esto, el enlace del correo de recuperación rebota.

---

## Parte 4 · Probar los flujos reales

### 4.1 Las cuentas las crea el CIIP

No hay registro: `/auth/v1/signup` contesta `signup_disabled`. Una cuenta nueva
se da de alta en Supabase, **Authentication → Users → Add user**. El
disparador `al_crear_usuario` le crea su fila en `perfiles`: compruébalo en
*Table Editor → perfiles*.

### 4.2 Iniciar sesión

| Prueba | Resultado esperado |
|---|---|
| Clave incorrecta | «Correo o clave incorrectos.» |
| Credenciales correctas | «Sesión iniciada…» y salta al panel |

### 4.3 Clave nueva, por el correo de recuperación

1. Un administrador envía el correo desde Supabase: **Authentication → Users →
   (el usuario) → Send password recovery**.
2. Abre el enlace del correo: debe llegar al acceso y **abrir sola** la vista
   «Crea una clave nueva».
3. Pon la clave dos veces → «Clave actualizada.» → vuelve al login solo.
4. Entra con la clave nueva.
5. Reutiliza el enlace del correo → «El enlace caducó o ya se usó.»

Y lo que **no** tiene que pasar: con la sesión abierta, escribir `#nueva` en
la dirección no abre esa vista. Antes sí la abría, y cualquiera con una
sesión ajena delante cambiaba la clave sin saber la actual.

### 4.4 El guardián del panel

| Prueba | Resultado esperado |
|---|---|
| Abrir el panel sin haber entrado | Rebota al acceso sin llegar a enseñar datos |
| Abrirlo con sesión | Entra normal, sin franja ámbar |
| Botón de cerrar sesión de la barra | Cierra sesión y sale al acceso |
| Franja ámbar visible | No cargó Supabase o faltan las claves: **el panel no está protegido** |

---

## Si algo falla

Abre la consola del navegador (**F12**). Los errores que no encajan en ningún
mensaje conocido se imprimen con el prefijo `[CIIP]`.

| Mensaje en consola | Causa habitual |
|---|---|
| `redirect_to is not allowed` | Falta la URL en *Redirect URLs* (paso 3.1) |
| `Email rate limit exceeded` | El SMTP de prueba de Supabase permite pocos correos por hora. Configura un SMTP propio |
| `Failed to fetch` | URL de Supabase mal escrita, o sin conexión |
| El navegador rechaza `supabase.js` por su *integrity* | Alguien cambió la versión de supabase-js sin rehacer la huella: ver el comentario junto a la etiqueta |
