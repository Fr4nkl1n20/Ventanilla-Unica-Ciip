# Contrato · Constitución de compañía (SAREN)

Lo que la Ventanilla Única necesita del **SAREN** para constituir una compañía
sin que el inversionista tenga que ir al registro. Está escrito para
preguntárselo, no porque ellos lo hayan dicho: igual que
[contrato-rif-empresa.md](contrato-rif-empresa.md).

Es el segundo. El primero sirvió para saber qué se puede acordar de antemano;
éste sirve para comprobar que el patrón aguanta con un trámite de otra forma.

---

## Por qué éste y no otro

Es el trámite del que cuelgan casi todos los demás: sin acta registrada no hay
compañía, sin compañía no hay RIF de empresa, y sin RIF no hay cuenta bancaria
ni nada de la fase 3. Automatizar el RIF y dejar la constitución a mano es
poner el motor detrás del atasco.

Y tiene una decisión que el RIF no tiene, que es lo que lo hace interesante
como segundo caso: **la denominación puede estar ocupada.**

---

## 1 · Presentar

```
POST /constituciones
Authorization: Bearer <token>
Idempotency-Key: <id del trámite en la VUI>
```

```json
{
  "origen": "CIIP-VUI",
  "referencia": "<uuid del trámite>",
  "solicitante": { "nombre": "…", "representante": "…", "documento": "V-12345678" },
  "compania": {
    "denominacion": "Bianchi Agroindustrias",
    "denominacion_alt": "Bianchi Agro de Venezuela",
    "tipo_sociedad": "C.A.",
    "capital_social": "150000.00",
    "objeto_social": "…",
    "domicilio_social": "…",
    "socios": "…"
  },
  "recaudos": [
    { "tipo": "cedula", "nombre": "…", "sha256": "…", "url": "…" },
    { "tipo": "rif_personal", "…": "…" },
    { "tipo": "comprobante_capital", "…": "…" },
    { "tipo": "domicilio_empresa", "…": "…" }
  ]
}
```

### La denominación alternativa no es un adorno

El panel ya la pide, en el mismo formulario, desde antes de que existiera este
contrato. Aquí es lo que evita un viaje entero: si la primera está ocupada y la
segunda no, **el registro reserva la segunda y sigue**, en vez de devolver el
expediente para que la persona escriba otro nombre y vuelva a empezar.

Por eso la respuesta tiene que decir **cuál de las dos quedó reservada**. Sin
ese dato el CIIP no sabría con qué nombre se está constituyendo la compañía, y
lo descubriría al recibir el acta.

## Qué vuelve

| Código | Significa | Qué hace la VUI |
|---|---|---|
| `202` | Recibido, con denominación reservada | `ante_el_ente`, y se guarda cuál |
| `409` | Ya estaba presentado | Igual que el 202. Es la respuesta correcta a un reintento |
| `422` `denominaciones_ocupadas` | **Las dos** están tomadas | `devuelto`: hay que elegir otro nombre |
| `422` (otro) | Falta o no cuadra algo | `devuelto`, con el motivo |
| `401` `403` | Nuestras credenciales | **alertar**. No es culpa del inversionista |
| `429` `5xx` | Saturado o caído | reintentar con la misma llave |
| sin respuesta | No se sabe si entró | reintentar con la misma llave |

`202` y `409`:

```json
{ "estado": "recibido",
  "expediente_ente": "SAREN-2026-00042",
  "denominacion_reservada": "Bianchi Agro de Venezuela",
  "era_la_alternativa": true }
```

---

## 2 · Preguntar en qué quedó

```
GET /constituciones/<expediente_ente>
```

| `estado` | Qué hace la VUI |
|---|---|
| `en_proceso` | esperar |
| `observado` | `devuelto`, con el motivo del registrador |
| `registrado` | `resuelto`, y el acta entra en la bóveda |

`registrado` tiene que traer **el acta, su tomo y su número**:

```json
{ "estado": "registrado",
  "tomo": "45-A",
  "numero": "12",
  "documento": { "nombre": "acta-registrada.pdf", "sha256": "…", "url": "…" }
}
```

**Si falta cualquiera de los tres, la VUI alerta y NO da el trámite por
resuelto.** Es la misma regla que en el RIF y por la misma razón: una compañía
«constituida» sin acta ni número de registro es una compañía que no existe en
ningún sitio, y decirle al inversionista que ya está sería mandarlo a abrir una
cuenta bancaria con las manos vacías.

---

## Lo que hay que preguntarle al SAREN

1. ¿Exponen algo, hoy, por HTTP? Si no, ¿en qué plazo?
2. ¿Aceptan `Idempotency-Key`? Sin eso, cada corte de red deja un expediente
   que no se puede reintentar sin arriesgarse a duplicarlo.
3. ¿La reserva de denominación es parte de la presentación o un trámite
   aparte? Este contrato supone lo primero; si es lo segundo, hacen falta dos
   llamadas y el conector cambia.
4. ¿Cuánto dura una reserva de denominación? Si caduca, la VUI tiene que saber
   cuándo para avisar antes.
5. ¿Los recaudos por URL firmada o dentro del cuerpo? Aquí van por URL, con su
   `sha256` para poder probar después qué se mandó.
6. ¿Qué devuelven cuando el objeto social no les cuadra: un `422` al presentar
   o un `observado` al consultar? Las dos cosas acaban en `devuelto`, pero la
   primera ahorra días.
