# El intermediario, y cómo se enciende

Esta carpeta tiene un solo archivo, `asistente.js`, y es **la única pieza del
proyecto que no corre en el navegador**. Todo lo demás —el panel, el acceso,
las maquetas— son archivos que Vercel entrega tal cual. Este se ejecuta en una
máquina de Vercel cada vez que alguien escribe una pregunta en el asistente.

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
