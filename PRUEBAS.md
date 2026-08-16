# Guía de pruebas del acceso

Cómo comprobar que el registro, el inicio de sesión y la recuperación de clave
funcionan de verdad.

---

## Parte 0 · La forma rápida: doble clic en `PROBAR.bat`

Hay 31 pruebas automáticas. **Haz doble clic en `PROBAR.bat`** y en unos
segundos sale la lista con `PASA` o `FALLA` en cada línea.

Cubren lo mismo que la parte 1 de esta guía, más comprobaciones que a mano son
tediosas: que ningún texto se quede sin traducir en los seis idiomas, que el
logo cargue, que la casilla de la sesión guarde donde debe.

No hace falta instalar nada: usa el Chrome o el Edge que ya tienes. **No modifica
`acceso.html`**; trabaja sobre una copia temporal en `%TEMP%\ciip-pruebas`.

Si sale `FALLA`, debajo aparece qué esperaba y qué obtuvo.

> Estas pruebas están comprobadas: al romper el código a propósito en tres
> sitios, fallaron ocho de ellas señalando exactamente lo roto. No son de las
> que pasan pase lo que pase.

Los archivos están en `pruebas\`: `arnes.js` son las pruebas en sí (añadir una
es copiar una línea `caso(...)`) y `ejecutar.ps1` es el lanzador.

**Lo que estas pruebas NO cubren:** nada que hable con Supabase. Para eso, las
partes 2 a 4.

---

## Parte 1 · Lo que puedes probar AHORA, sin Supabase

Toda la validación del formulario corre **antes** de tocar la base de datos, así
que funciona aunque `SUPABASE_URL` siga con el valor de ejemplo. Abre
`acceso.html` y recorre esta lista.

| # | Qué hacer | Qué debe pasar |
|---|---|---|
| 1 | Entrar con los dos campos vacíos | "Completa todos los campos." y el campo del correo en rojo |
| 2 | Correo `hola` + cualquier clave | "Introduce un correo válido." |
| 3 | En Crear cuenta, clave de 5 caracteres | "La clave debe tener al menos 8 caracteres." |
| 4 | Claves que no coinciden | "Las claves no coinciden." y los dos campos en rojo |
| 5 | Todo bien pero sin marcar la casilla de datos | "Debes aceptar el tratamiento de datos para continuar." |
| 6 | Todo correcto | "El acceso no está conectado a la base de datos todavía." |
| 7 | Botón del ojo en cada campo de clave | Alterna entre puntos y texto, y el icono se pone azul |
| 8 | Enlaces Crear cuenta / ¿Olvidaste tu clave? / Volver | Cambian de vista y limpian los mensajes anteriores |
| 9 | Cambiar de idioma con un mensaje de error en pantalla | El mensaje **también** se traduce |
| 10 | Cambiar el tema y recargar | Se mantiene el tema elegido |
| 11 | Estirar y encoger la ventana | El formulario queda centrado; la página no se desplaza |

Si el paso 6 muestra un mensaje distinto a "no está conectado", algo va mal
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

**SQL Editor → New query**, pega el contenido íntegro de `supabase-setup.sql`
y pulsa **Run**. Se puede ejecutar varias veces sin romper nada.

Comprueba que el RLS quedó activo:

```sql
select relname, relrowsecurity from pg_class where relname = 'perfiles';
```

Debe devolver `true`.

### 2.3 Rellenar `config.js`

**Un solo archivo: `config.js`.** Abre y pega los dos valores:

```js
SUPABASE_URL:      'https://loquesea.supabase.co',
SUPABASE_ANON_KEY: 'eyJhbGciOi...',
```

Ya está. Lo leen tanto `acceso.html` como el panel, así que no hay forma de
configurar uno y dejarse el otro.

> `config.js` tiene que viajar **siempre** junto a los dos `.html`. Si lo
> mueves o lo borras, las páginas vuelven a comportarse como "sin configurar":
> el acceso enseña el aviso ámbar y el panel avisa de que no está protegido.
> No se rompen, pero tampoco funcionan.

---

## Parte 3 · Servirlo por HTTP

**Con `file://` no se puede probar el circuito completo.** Los enlaces de
confirmación y de recuperación que llegan por correo no pueden volver a un
archivo local, y `location.origin` vale `null`.

En esta máquina no hay Node ni un Python real (el `python` que responde es el
marcador de posición de la Microsoft Store). Opciones, de menos a más trabajo:

- **Extensión Live Server de VS Code** — la más rápida, ya usas VS Code.
  Instálala, clic derecho sobre `acceso.html` → *Open with Live Server*.
  Sirve en `http://127.0.0.1:5500`.
- **Instalar Node** desde <https://nodejs.org> y luego `npx serve` en la carpeta.
- **Instalar Python** desde la Microsoft Store y luego
  `python -m http.server 8080` en la carpeta.

Anota la URL que te quede; hace falta en el paso siguiente.

### 3.1 Autorizar las URLs en Supabase

**Authentication → URL Configuration**:

- **Site URL**: `http://127.0.0.1:5500/acceso.html` (ajusta el puerto)
- **Redirect URLs**: añade `http://127.0.0.1:5500/**`

Sin esto, los enlaces del correo caducan o rebotan, y `resetPasswordForEmail`
devuelve un error de redirección no autorizada.

---

## Parte 4 · Probar los flujos reales

### 4.1 Crear cuenta

1. Ve a *Crear cuenta*, rellena todo con un correo tuyo real, marca la casilla.
2. Debe salir: *"Cuenta creada. Te enviamos un correo para confirmarla…"*
3. **Comprueba en Supabase** → *Authentication → Users*: el usuario aparece con
   `Waiting for verification`.
4. **Comprueba la tabla** → *Table Editor → perfiles*: debe existir una fila con
   tu `nombre_completo` y tu `pais`. Si la fila **no** está, el trigger
   `al_crear_usuario` falló — vuelve a ejecutar `supabase-setup.sql`.
5. Abre el correo y pulsa el enlace de confirmación.

> **Registrar dos veces el mismo correo no da error a propósito.** Supabase
> responde igual que con uno nuevo para no revelar quién está registrado.

### 4.2 Iniciar sesión

| Prueba | Resultado esperado |
|---|---|
| Clave incorrecta | "Correo o clave incorrectos." |
| Correo sin confirmar | "Tu correo aún no está confirmado…" |
| Credenciales correctas | "Sesión iniciada…" y salta al panel |

### 4.3 La casilla "mantener la sesión abierta"

Este es el que más fácil se rompe. Pruébalo así:

1. **Desmarca** la casilla e inicia sesión. Entras al panel.
2. Cierra **toda** la ventana del navegador y vuelve a abrir el panel.
   → Debe echarte a `acceso.html`.
3. Repite **marcando** la casilla.
   → Debe dejarte entrar directamente.

Si en el paso 2 te deja pasar, la sesión se está guardando donde no debe.

### 4.4 Recuperar clave

1. *¿Olvidaste tu clave?* → tu correo → *Enviar enlace*.
2. Mensaje verde de confirmación.
3. Abre el enlace del correo: debe llegar a `acceso.html#nueva` y **abrir sola**
   la vista de clave nueva.
4. Pon una clave nueva dos veces → "Clave actualizada." → vuelve al login solo.
5. Entra con la clave nueva.
6. Reutiliza el enlace del correo → "El enlace caducó o ya se usó."

> Un correo que no existe da el **mismo** mensaje verde, a propósito. Pero un
> fallo real (límite de peticiones, SMTP mal configurado) ahora sí se muestra
> como error, ya no se disfraza de éxito.

### 4.5 El guardián del panel

| Prueba | Resultado esperado |
|---|---|
| Abrir el panel sin haber entrado | Rebota a `acceso.html` sin llegar a enseñar datos |
| Abrirlo con sesión | Entra normal, sin franja ámbar |
| Con sesión abierta, ejecutar `ciipSalir()` en la consola | Cierra sesión y sale al acceso |
| Franja ámbar visible | Faltan las claves en el bloque del guardián: **el panel no está protegido** |

---

## Si algo falla

Abre la consola del navegador (**F12**). Los errores que no encajan en ningún
mensaje conocido se imprimen ahí con el prefijo `[CIIP] Error de Supabase:`.

| Mensaje en consola | Causa habitual |
|---|---|
| `Database error saving new user` | El trigger `al_crear_usuario` falla. Reejecuta `supabase-setup.sql` |
| `redirect_to is not allowed` | Falta la URL en *Redirect URLs* (paso 3.1) |
| `Email rate limit exceeded` | El SMTP de prueba de Supabase permite pocos correos por hora. Configura un SMTP propio |
| `Failed to fetch` | URL de Supabase mal escrita, o sin conexión |

---

## Lo que sigue pendiente

- **El panel muestra datos de demostración fijos** ("Marco", "Bianchi
  Agroindustrias"). El guardián comprueba quién entra, pero el contenido no
  cambia según el usuario. Para eso hay que leer `public.perfiles` con
  `window.sbCIIP` y sustituir los textos fijos.
- **No hay botón visible de cerrar sesión** en el panel. De momento solo existe
  la función `ciipSalir()`.
