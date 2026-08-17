# Desplegar el acceso en Vercel

Esta carpeta es un sitio **estático**: no se compila, no tiene dependencias que
instalar. Vercel solo tiene que servir los archivos.

---

## 1 · Importar el repositorio

Entra en **[vercel.com/new](https://vercel.com/new)** y elige
`CIIP-INVEST/Ventanilla-Unica-2`.

**Si el repositorio no aparece en la lista**, pulsa *Adjust GitHub App
Permissions* y concede acceso a la organización `CIIP-INVEST`. Ese permiso lo
aprueba un **owner** de la organización.

> **Elige bien el ámbito.** Arriba, donde dice el propietario del proyecto,
> conviene un **Team del CIIP** y no una cuenta personal. Si se despliega en
> una cuenta personal, el proyecto —dominio, configuración y accesos— pertenece
> a esa persona, y se va con ella. Es la misma razón por la que el repositorio
> está en la organización y no en la cuenta de nadie.

---

## 2 · Configurar

Solo hay un campo que importa:

| Campo | Valor |
|---|---|
| **Root Directory** | `login` ← pulsa *Edit* y selecciónala |
| Framework Preset | `Other` |
| Build Command | vacío |
| Output Directory | vacío |
| Install Command | vacío |

Sin el **Root Directory** se publicaría el proyecto entero, incluidas las
pruebas, las capturas y el panel.

Pulsa **Deploy**. Tarda menos de un minuto.

---

## 3 · Autorizar la URL en Supabase

**Este paso no se puede saltar.** Sin él, el login funcionará, pero el correo
de recuperación de clave intentaría devolver al usuario a `localhost` y no
llegaría a ninguna parte.

En Supabase → **Authentication → URL Configuration**:

| Campo | Valor |
|---|---|
| **Site URL** | `https://TU-DOMINIO.vercel.app` |
| **Redirect URLs** | añade `https://TU-DOMINIO.vercel.app/**` |

Si más adelante se le pone un dominio propio, hay que añadirlo también aquí.

---

## Qué se despliega

| Archivo | Qué es |
|---|---|
| `index.html` | La página entera: estilos, textos en 6 idiomas y lógica |
| `config.js` | Las claves de Supabase |
| `assets/login_fondo.webp` | La ilustración del Ávila |
| `vercel.json` | Cabeceras de seguridad y caché |

Son unos 490 KB. Lo único que pide a internet al ejecutarse es la librería de
Supabase desde su CDN.

## Qué hace la página

El formulario es **correo, contraseña y entrar**. Nada más. Tiene una segunda
vista, la de escribir una contraseña nueva, a la que solo se llega desde el
enlace de un correo.

Estas cuatro ausencias son deliberadas, no cosas por terminar:

- **No se pueden crear cuentas.** Las abre el CIIP desde Supabase
  (*Authentication → Users → Add user*), y el registro está cerrado también en
  el servidor: `/auth/v1/signup` responde `signup_disabled`.
- **No hay "olvidé mi clave".** Si alguien no puede entrar, un administrador le
  envía el correo de recuperación desde Supabase. El enlace de ese correo cae
  en esta misma página y abre la vista de contraseña nueva.
- **No hay casilla de "mantener la sesión abierta".** La sesión persiste
  siempre, hasta que se cierre sesión.
- **No lleva a ningún panel después de entrar**: muestra que la sesión quedó
  abierta, con un botón para cerrarla. Para conectarla con un panel, se pone su
  ruta en `RUTA_PANEL` dentro de `config.js`.

## Si algo no cuadra al desplegar

| Síntoma | Causa |
|---|---|
| Sale una franja ámbar de "falta conectar la base de datos" | `config.js` no llegó, o tiene los valores de ejemplo |
| Carga sin la ilustración | La carpeta `assets/` no subió, o el Root Directory está mal |
| El dominio raíz da 404 | El **Root Directory** no es `login` |
| Entrar funciona, pero el correo de recuperación no vuelve | Falta el paso 3, autorizar la URL en Supabase |

## Sobre config.js

La clave que lleva es la `anon` de Supabase, que es **pública por diseño**:
viaja al navegador de todos modos. Lo que protege los datos son las políticas
RLS, no el secreto de esa clave.

Lo que **nunca** debe acabar ahí es la clave `service_role`: esa se salta el
RLS por completo.
