# Acceso · Ventanilla Única

La página de acceso **por sí sola**. No depende de ninguna otra página del
proyecto: entras, y te confirma que la sesión quedó abierta, con un botón
para cerrarla.

## Qué hay aquí

| Archivo | Para qué |
|---|---|
| `acceso.html` | La página entera: estilos, textos en 6 idiomas y lógica |
| `config.js` | **Lo único que se toca**: las claves de Supabase |
| `assets/login_fondo.webp` | La ilustración del Ávila sobre Caracas |

Son 483 KB en tres archivos. La única cosa que pide a internet en tiempo de
ejecución es la librería de Supabase, desde su CDN.

## Cómo usarlo

Abre `acceso.html`. Para que los correos de recuperación funcionen hace falta
servirlo por HTTP, no con doble clic — desde `file://` el navegador no tiene
una dirección a la que devolver al usuario.

## Qué hace y qué no

**Tiene tres vistas:** entrar, recuperar clave y clave nueva.

**No se pueden crear cuentas.** Las abre el CIIP desde el panel de Supabase.

**No lleva a ningún sitio después de entrar.** Es a propósito: `RUTA_PANEL`
está vacío en `config.js`, y por eso se queda en su propia pantalla de
"sesión iniciada". Si algún día lo conectas con un panel, pon ahí su ruta:

```js
RUTA_PANEL: './panel.html',
```

y volverá a redirigir al entrar. Con `RUTA_PANEL: ''` se queda; sin la clave,
usa la ruta por defecto del proyecto completo.

## Aviso sobre el registro

Quitar el formulario de crear cuenta **no cierra el registro en el servidor**.
La dirección `POST /auth/v1/signup` sigue aceptando altas con la clave `anon`,
que es pública. Para cerrarlo de verdad:

> Supabase → Authentication → Sign In / Providers → Email
> → apagar **Allow new users to sign up** → Save

Se comprueba con `/auth/v1/settings`: debe decir `"disable_signup": true`.
