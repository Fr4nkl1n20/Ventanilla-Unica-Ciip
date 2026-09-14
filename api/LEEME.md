# El intermediario, y cómo se enciende

Esta carpeta tiene dos archivos, `asistente.js` y `leer-documento.js`, y son
**las únicas piezas del proyecto que no corren en el navegador**. Todo lo demás
—el panel, el acceso, las maquetas— son archivos que Vercel entrega tal cual.
Estos se ejecutan en una máquina de Vercel: el primero cada vez que alguien
escribe una pregunta en el asistente, el segundo cada vez que alguien suelta un
papel para que se lea. El lector tiene su propio apartado al final.

Existe por una razón sola: **la clave de Anthropic no puede viajar al
navegador**. La clave `anon` de Supabase que está en `config.js` sí puede —es
pública por diseño, y lo que protege los datos son las políticas RLS—. La de
Anthropic no: quien la tenga gasta en la cuenta del CIIP, y en `config.js`
bastaría con abrir «ver código fuente» para llevársela.

---

## Qué pasa hoy, sin la clave puesta

El panel se comporta **exactamente como antes**. Pregunta al servidor, el
servidor contesta `sin-clave`, y el asistente vuelve a las siete respuestas
fijas de siempre. No sale ningún error, no hay nada roto y el usuario no nota
que hubo un intento.

Eso es a propósito: encender la IA no debe ser un salto al vacío, y apagarla
—quitando la variable— tampoco debe dejar un hueco.

---

## Los tres pasos para encenderlo

### 1 · Conseguir la clave

En **[console.anthropic.com](https://console.anthropic.com)** → *API Keys* →
*Create Key*.

Conviene que la cuenta sea **de la organización**, no personal, por la misma
razón por la que el repositorio está en `CIIP-INVEST` y el proyecto de Vercel
debería estar en un Team del CIIP: lo que se crea en una cuenta personal se va
con esa persona.

Se factura por uso, así que en *Billing* → *Limits* conviene poner un tope
mensual antes de nada. La cuenta empieza sin saldo: hay que cargarle crédito.

### 2 · Poner las tres variables en Vercel

Proyecto `ventanilla-unica-2` → **Settings → Environment Variables**:

| Nombre | Valor | Dónde sale |
|---|---|---|
| `ANTHROPIC_API_KEY` | `sk-ant-...` | el paso 1 |
| `SUPABASE_URL` | `https://fbxdwryppfctuwlnjjqr.supabase.co` | `config.js`, bloque `real` |
| `SUPABASE_ANON_KEY` | `eyJhbGci...` | `config.js`, bloque `real` |

Las dos de Supabase no son un secreto —están en `config.js`, que se publica—,
pero el servidor las necesita para **comprobar que quien pregunta tiene sesión
abierta**. Sin esa comprobación, la dirección quedaría abierta a internet
entero y cualquiera podría gastar la cuenta desde una terminal.

> La `service_role` de Supabase **no** va aquí. El intermediario lee el
> catálogo con el token del propio usuario, para que las políticas RLS sigan
> mandando. Una llave de servicio se las saltaría todas.

### 3 · Dejar que Vercel instale la dependencia

Este es el paso que se olvida, y falla en silencio.

`login/DESPLEGAR.md` dice que el **Install Command** vaya vacío. Eso era cierto
cuando el proyecto no tenía ni una dependencia. Desde que existe `package.json`
ya no: si el Install Command está vacío, Vercel no ejecuta `npm install`, el
paquete `@anthropic-ai/sdk` no se instala y la función revienta al arrancar con
un `Cannot find module`.

En **Settings → Build and Deployment → Install Command**: que esté en el
**valor por defecto**, no vacío. (El *Build Command* y el *Output Directory* sí
siguen vacíos: el sitio no se compila.)

Después, un despliegue nuevo. El asistente contesta con IA desde el primero.

---

## Comprobar que quedó bien

```
node pruebas/asistente.js
```

Prueba la función entera contra un Anthropic y un Supabase de mentira: que sin
clave contesta `sin-clave`, que sin sesión no deja pasar, que el tope por hora
corta, que el catálogo de la base entra en lo que el modelo sabe y que cada
tipo de fallo sale por su puerta. No gasta un céntimo ni toca la red.

Para probarlo **de verdad**, con la clave y contra Anthropic, hace falta
`vercel dev` y un `.env` local (que `.gitignore` ya excluye).

---

## Lo que cuesta

El modelo es `claude-opus-5`, con `effort: low` —una conversación de mostrador
no necesita más— y con el texto de instrucciones cacheado, que es lo que abarata
la segunda pregunta y las siguientes.

Una pregunta corriente sale por céntimos. Lo que hay que vigilar no es la
pregunta suelta sino el volumen, y para eso hay tres frenos ya puestos:

- **40 preguntas por persona y hora**, en `TOPE_POR_HORA`.
- **Los últimos 12 turnos** de conversación, en `TURNOS_MAXIMOS`: sin esto,
  cada pregunta de una charla larga cuesta más que la anterior.
- **4.000 caracteres por mensaje**: un pegado accidental de treinta páginas
  convierte una pregunta de céntimos en una de varios dólares.

El tope de la cuenta en la consola de Anthropic es el que de verdad no se
salta. Los de aquí son cortafuegos, no contabilidad.

> El contador de las 40 no es exacto: Vercel puede tener varias copias de la
> función a la vez y las apaga cuando no se usan, así que cada copia cuenta lo
> suyo. Corta lo evidente —una pestaña olvidada, un bucle mal cerrado—, que es
> para lo que está. Un tope exacto va en una tabla de Supabase, y el día que
> haga falta se cambia dentro de este archivo sin que el panel se entere.

---

## Lo que este asistente NO sabe

Conviene tenerlo claro antes de enseñárselo a nadie:

- **No sabe nada del expediente de quien pregunta.** Ni en qué estado está, ni
  qué documentos entregó. A propósito: eso son datos personales, y meterlos en
  la conversación es una decisión del CIIP, no un detalle técnico. Hoy lo único
  que sale de esta página es la conversación.
- **Sabe lo que dice `public.tipos_tramite`**: los 33 trámites con su
  organismo, su fase, su plazo estimado y si ya se pueden solicitar. La misma
  fuente que pinta las fichas del panel, para que las dos no se contradigan.
- **No sabe requisitos, recaudos ni costos**, porque eso todavía no está en la
  base. Se le pide expresamente que diga que no lo sabe y remita al CIIP, en
  vez de inventárselo. El día que los recaudos estén en una tabla, se añaden a
  `loQueSabe()` y el asistente los usa.

---

# El lector de documentos

`leer-documento.js` es el cuadro de **«si ya tienes el papel, lo leemos»** que
sale encima de las casillas del paso 1 de un trámite. Sueltas el poder, el acta
o el pasaporte, y las casillas que ese papel contiene se rellenan solas, con un
sello que dice de dónde salió cada dato. La persona las repasa antes de enviar.

## Qué pasa hoy

Nada visible. `config.js` ya apunta el proyecto real a `/api/leer-documento`,
pero el panel **le pregunta primero si está encendido**, y mientras falte algo
contesta que no y el cuadro no se pinta.

## Encenderlo

Además de lo del asistente (la clave y las dos variables de Supabase), una
variable más en Vercel:

| Nombre | Valor |
|---|---|
| `LECTOR_ACTIVO` | `si` |

Es un interruptor **aparte de la clave a propósito**. El asistente solo manda la
conversación; el lector manda poderes, actas y pasaportes —nombres, cédulas,
domicilios— a Anthropic para leerlos. Eso lo tiene que decidir el CIIP, y no
puede quedar decidido de rebote por haber puesto la clave para el asistente.

Para apagarlo, se quita la variable (o se pone cualquier otra cosa) y un
despliegue nuevo.

## Cómo viaja el papel

Vercel no deja entrar en una función más de 4,5 MB, y un poder escaneado pasa
de eso. Así que el papel **no va en la petición**:

1. El panel lo sube a la carpeta de la persona en el cubo `recaudos`, dentro de
   `{uid}/lector/`. Las políticas del cubo ya le dejan escribir ahí.
2. A `/api/leer-documento` llega solo la ruta y qué casillas buscar.
3. La función comprueba la sesión, baja el papel **con el token de la persona**
   —ninguna llave de servicio—, se lo enseña a `claude-opus-5` y **lo borra**,
   haya ido bien o mal.

Solo acepta rutas de `{uid}/lector/` de quien pregunta, porque borra lo que lee:
un gestor puede leer la carpeta de cualquiera, y sin esa guarda podría hacer
desaparecer un recaudo de verdad pasándole su ruta.

## Lo que lee y lo que no

- **PDF, JPEG, PNG, WebP y GIF.** Las fotos HEIC de iPhone, TIFF y BMP las
  admite el cubo pero no el modelo: el cuadro dice que no pudo, y el papel se
  sube a mano como siempre.
- **Solo lo que está escrito.** Lo que el modelo no lee con seguridad se queda
  vacío, y lo que devuelva de más —un tipo de papel que el trámite no pide, una
  casilla que no es de ese papel— se recorta antes de salir.
- **Lo que ya habías escrito manda**: el papel no pisa una casilla llena.

## Frenos

- **20 lecturas por persona y hora** (`TOPE_POR_HORA`). Cada lectura es un
  documento entero, bastante más cara que una pregunta al asistente.
- **10 MB por papel**, igual que el cubo.
- Mismo aviso que arriba: el contador no es exacto entre copias de la función.
  El tope que de verdad no se salta es el de la consola de Anthropic.

## Comprobar que quedó bien

```
node pruebas/leer-documento.js
```

O `PROBAR-LECTOR.bat`. Prueba la función contra un Anthropic y un Supabase de
mentira —los dos interruptores, la puerta, que solo borre de su carpeta, que
borre siempre, la tijera, el tope, cada fallo— y el trozo de `config.js` que le
habla desde el navegador. No gasta un céntimo ni toca la red.
