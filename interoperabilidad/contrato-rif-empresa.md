# Contrato del conector · RIF de la empresa (SENIAT)

**Esto es una propuesta, no la API del SENIAT.** El SENIAT no ha dicho todavía
qué expone, ni si expone algo. Lo que hay aquí es lo que la Ventanilla Única
*necesita* para presentar un RIF de empresa sin que nadie lleve papeles a
ningún lado, escrito para llevarlo a la primera reunión y preguntar, punto por
punto: **¿esto lo pueden dar?**

Se escribe antes de que contesten a propósito. El conector se programa contra
este contrato y contra un simulador que lo cumple; cuando el ente conteste, lo
que cambia es la dirección y las credenciales, y —si su API resulta distinta—
un traductor entre su forma y ésta. Lo que no cambia es la parte cara: qué se
manda, qué se hace con cada respuesta y cómo se recupera de un fallo.

Es el mismo método con el que ya se prueba el panel entero contra
`pruebas/supabase-mentira.js`, un piso más abajo.

---

## Por qué este trámite y no otro

El **c6, RIF de la empresa**, es el primero que conviene conectar:

- Lo necesita **toda** empresa que se constituya, así que es el de más volumen.
- Sus datos ya están estructurados en la base, no son texto libre.
- Su recaudo principal —el acta constitutiva— **lo produce el trámite
  anterior** y ya vive en la bóveda del inversionista. No hay que pedírselo.
- El SENIAT tiene portal propio y sistemas propios, así que la conversación no
  empieza de cero.

---

## Lo que la VUI tiene hoy para mandar

Todo esto ya existe en la base y está probado. No hay que recolectarlo: hay que
traducirlo.

### Datos del formulario (`tramites.datos`)

| Campo | Etiqueta en el panel |
|---|---|
| `razon_social` | Razón social |
| `numero_registro` | N.º de Registro Mercantil |
| `fecha_constitucion` | Fecha de constitución |
| `capital_social` | Capital social |
| `actividad_economica` | Actividad económica |
| `direccion_fiscal` | Dirección fiscal |

### Recaudos (`tramite_documentos` → `documentos`)

| Tipo | Origen |
|---|---|
| `acta_constitutiva` | Sale del trámite de constitución (c22) |
| `rif_personal` | Ya en la bóveda desde la fase 1 |
| `domicilio_empresa` | Lo sube el inversionista |

Los archivos viven en un bucket privado. **Nada es público**: se abren con una
URL firmada que caduca.

---

## 1 · Presentar el expediente

```
POST /expedientes
Authorization: Bearer <token del CIIP>
Idempotency-Key: <tramites.id>
Content-Type: application/json
```

```json
{
  "origen": "CIIP-VUI",
  "referencia": "8f1c2e4a-...",
  "tramite": "rif_empresa",
  "presentado_en": "2026-08-20T14:02:11Z",
  "solicitante": {
    "nombre": "Bianchi Agroindustrias, C.A.",
    "representante": "Franklin Reyes",
    "documento": "V-12345678"
  },
  "empresa": {
    "razon_social": "Bianchi Agroindustrias, C.A.",
    "numero_registro": "12, Tomo 45-A",
    "fecha_constitucion": "2026-07-14",
    "capital_social": "150000.00",
    "actividad_economica": "Procesamiento de cacao",
    "direccion_fiscal": "Av. Principal, Galpón 4, Charallave, Miranda"
  },
  "recaudos": [
    {
      "tipo": "acta_constitutiva",
      "nombre": "acta-constitutiva.pdf",
      "sha256": "9f86d081...",
      "url": "https://<storage>/recaudos/...?token=...&exp=1755700000"
    }
  ]
}
```

**Los archivos van por URL firmada, no en base64.** Tres razones: el cuerpo no
se infla, la URL caduca sola, y el `sha256` deja probar después que el archivo
que ellos recibieron es el que el inversionista subió. Si el SENIAT no puede
salir a buscar archivos —hay redes cerradas donde no—, la alternativa es
`multipart/form-data`; hay que preguntarlo en la reunión.

**`Idempotency-Key` es el `id` del trámite**, que ya es un UUID. Si la red se
cae después de que ellos reciban pero antes de que nos contesten, reintentamos
con la misma llave y no se presenta dos veces el mismo expediente. Es la
diferencia entre reintentar tranquilo y no atreverse a reintentar.

---

## 2 · Qué significa cada respuesta

Ésta es la parte que de verdad hay que acordar. Un conector no se equivoca
mandando: se equivoca interpretando.

| Respuesta | Qué pasó | Qué hace la VUI |
|---|---|---|
| `202` + `expediente_ente` | Lo recibieron | El trámite pasa a **`ante_el_ente`**, guardando su número |
| `409` + `expediente_ente` | Ya lo habíamos mandado | Lo mismo que un `202`. **No se duplica** |
| `422` + `motivo` | Lo miraron y falta algo | El trámite pasa a **`devuelto`** con ese motivo. **No se reintenta** |
| `401` · `403` | Nuestras credenciales | **No se toca el trámite.** Avisa al equipo del CIIP |
| `429` · `5xx` · sin respuesta | No se sabe si llegó | **Reintentar** con la misma llave, espaciando los intentos |

> **La distinción que sostiene todo el conector** es la de las dos últimas
> filas: *no llegó* y *llegó pero lo rechazan* se parecen desde fuera y piden
> lo contrario. Confundirlas significa o bien presentar cuatro veces el mismo
> expediente, o bien dejar al inversionista esperando un trámite que hace
> semanas que está rechazado.

Un `422` **no es un error del sistema, es una respuesta del negocio**: llega al
inversionista como una devolución con su nota, igual que hoy cuando la escribe
un gestor. Ahí está la gracia: el circuito de subsanación ya existe y ya está
probado. El conector no inventa nada, solo lo alimenta desde fuera.

---

## 3 · Saber en qué quedó

El RIF no se emite en el mismo segundo. Hacen falta dos formas de enterarse, y
la primera es mejor:

**Si el ente puede avisar** (preferido) — nos llama cuando cambie algo:

```
POST https://<vui>/interop/seniat/aviso
X-Firma: <HMAC-SHA256 del cuerpo con el secreto compartido>
```

La firma no es opcional: sin ella, cualquiera que descubra la dirección puede
dar por aprobado un RIF que no existe.

**Si no puede** (respaldo) — preguntamos nosotros:

```
GET /expedientes/{expediente_ente}
```

```json
{
  "estado": "en_proceso",
  "actualizado_en": "2026-08-21T09:00:00Z"
}
```

| `estado` | Qué hace la VUI |
|---|---|
| `en_proceso` | Nada. Vuelve a preguntar más tarde |
| `aprobado` | Trámite a **`resuelto`**, y el documento emitido entra en la bóveda |
| `rechazado` | Trámite a **`devuelto`** con el `motivo` |

Cuando venga `aprobado`, el cuerpo trae el documento igual que lo mandamos
nosotros: URL y `sha256`.

```json
{
  "estado": "aprobado",
  "documento": {
    "nombre": "rif-J-401234567.pdf",
    "sha256": "3b1a5c...",
    "url": "https://<seniat>/descargas/...?token=..."
  },
  "rif_asignado": "J-40123456-7"
}
```

---

## 4 · Lo que hay que preguntarle al SENIAT

Ordenado por lo que más cambia el diseño si la respuesta es «no»:

1. **¿Hay API, o hay portal?** Si solo hay portal, esto no es un conector: es
   un acuerdo de procedimiento, y el estado `ante_el_ente` sigue moviéndolo una
   persona. Sigue siendo un avance —el plazo se puede medir—, pero es otra
   cosa.
2. **¿Pueden avisar cuando cambie el estado, o hay que preguntar?**
3. **¿Pueden ir a buscar los archivos a una URL firmada, o hay que
   mandárselos?**
4. **¿Con qué autorizan?** Casi siempre una IP fija. Eso decide dónde vive el
   backend, y de ahí que no pueda ser serverless.
5. **¿Hay entorno de pruebas?** Sin él, la primera prueba de verdad es contra
   producción, con un expediente real de un inversionista real.
6. **¿Qué plazo se comprometen a cumplir?** Es el número que alimenta las
   alertas de la capa 3.

---

## Lo que ya se puede dejar hecho sin que contesten

- El conector, escrito y probado contra el simulador (`conector-rif.js`).
- El simulador, que finge cada una de las respuestas de la tabla
  (`simulador.js`).
- Las pruebas, que comprueban que cada respuesta lleva al estado que debe
  (`prueba.js`).

Lo que falta cuando contesten: la dirección, las credenciales y —si su API es
distinta a esta propuesta— un traductor entre su forma y la nuestra. El resto,
que es donde está el trabajo, ya estaría.
