# Tipografía de la Ventanilla

Cómo llevar la escala y la jerarquía tipográfica de Atlas a
`ciip-ventanilla-unica-local.html`. La referencia es `tipografia-atlas.md`,
del repositorio `ciip-app`.

| | |
| --- | --- |
| Fecha del inventario | 2026-09-11 |
| Reglas con tamaño de letra | 319 |
| Tamaños distintos hoy | 23 |
| Tamaños distintos al terminar | 14 |
| Estado | Propuesta. Nada aplicado todavía |

---

## 1. Principio

La jerarquía la hace el **peso**, no el tamaño.

Atlas se apoya en dos cosas: el peso y la tinta. En la Ventanilla la tinta no
está disponible. El CIIP pidió el 3 de septiembre de 2026 que *«todos los
textos que tengan letras gris sean negro de color normal»*, y `--gray` y
`--gray-soft` apuntan a `--ink` en los dos temas.

Consecuencias:

- Los grises de Atlas (`#5B6478`, `#8A93A6`) **no se aplican**.
- Toda la jerarquía descansa en el peso. Donde Atlas baja la tinta, aquí se
  mantiene o se sube el peso.
- Si dos textos no se distinguen, se cambia el peso o el aire entre ellos.
  Nunca el tamaño.

---

## 2. Familias

Ya coinciden con Atlas. No cambian.

| Familia | Uso |
| --- | --- |
| Helvetica Neue → Arial → sans-serif | Toda la interfaz |
| Instrument Serif, 400 | Marca de la barra lateral y titular de portada |
| `ui-monospace`, Consolas, monospace | Códigos |

Instrument Serif va incrustada en base64. No hay petición a Google Fonts.

---

## 3. Escala

Catorce escalones. Cada uno tiene un solo trabajo.

| Token | px | Peso | Interletraje | Interlínea | Rol |
| --- | --- | --- | --- | --- | --- |
| `--fs-cifra` | 24 | 800 | -.02em | 1 | Cifra de indicador |
| `--fs-titulo` | 20 | 700 | -.02em | 1.2 | Título de página |
| `--fs-tarjeta` | 14 | 700 | -.01em | 1.3 | Título de tarjeta |
| `--fs-valor` | 13.5 | 500 | — | 1.45 | Valor de un dato |
| `--fs-seccion` | 13 | 800 | .01em | 1.3 | Título de sección |
| `--fs-enlace` | 13 | 600 | — | — | Enlace de acción suelto |
| `--fs-parrafo` | 12.5 | 400 | — | 1.6 | Descripción, párrafo, estado vacío |
| `--fs-campo` | 12.5 | 400 | — | — | Texto dentro de un campo |
| `--fs-pestana` | 12.5 | 600 | — | — | Pestaña y filtro |
| `--fs-fila` | 12 | 600 | — | 1.35 | Nombre en una fila de lista |
| `--fs-boton` | 11.5 | 700 | — | 1 | Botón y enlace dentro de una ficha |
| `--fs-rotulo` | 11 | 800 | .01em | — | Rótulo de un dato |
| `--fs-nota` | 11 | 400 | — | 1.55 | Nota, texto de apoyo |
| `--fs-chip` | 10 | 700 | .01em | 1 | Pastilla, contador, microrótulo |

Fuera de la escala, a propósito:

| px | Peso | Uso |
| --- | --- | --- |
| 34 / 30 | 400 | Instrument Serif: marca y titular de portada |
| 9.5 | 600 | Monoespaciada: códigos |

---

## 4. Equivalencias

Qué pasa con cada regla que hoy está fuera de la escala. Las que ya coinciden
no aparecen.

### 4.1 Títulos y cifras

| Destino | Hoy | Selectores |
| --- | --- | --- |
| Cifra 24 / 800 | 19–25 px | `.pu-n .v` `.ft-t .n` `.hm .v` `.hero-ring .pct` |
| Título de página 20 / 700 | 17–19 px | `.tr-nombre` `.em-nombre` |
| Tarjeta 14 / 700 | 15–15.5 px | `.phase-h .pt` `.g-name` `.pa-cuenta .pc-t` `.sup-panel .sb-q` |
| Tarjeta 14 / 700 | 13.5 / 700 | `.t-name` `.jp .jname` `.cg-nombre` `.ct-linea` `.co-quien` `.ay-t` |
| Tarjeta 14 / **800** | 15 / 800 | `.ac-monto` (es un monto: conserva 800 y cifras tabulares) |
| Sección 13 / 800 | 13 / 700 | `.tr-h` `.sol-h` `.ft-rh .t` `.sol-estado .se-t` `.faq-item summary` `.pa-hoja[data-paso="2"] .sd-n` |
| Sección 13 / 800 | 13.5 / 800 | `.pl-caja .pc-t` |

### 4.2 Datos de una ficha

| Destino | Hoy | Selectores |
| --- | --- | --- |
| Valor 13.5 / 500 | 12–13 px | `.em-dato .v` `.ft-filas dd` `.pa-v` `.co-dato` |
| Rótulo 11 / 800 | 9.5–11.5 px, 600–700 | `.em-dato .k` `.ft-filas dt` `.ft-t .k` `.pa-k` `.pa-l` `.tabla th` `.pu-n .l` `.us-m .l` `.hm .l` `.hm-q` `.cal-h .cual` |

Entre el rótulo y su valor hay dos puntos y medio de diferencia. Los separa el
peso: 800 contra 500.

### 4.3 Texto corrido

| Destino | Hoy | Selectores |
| --- | --- | --- |
| Párrafo 12.5 / 1.6 | 11.5–13 px, 1.45–1.65 | `.tr-desc` `.faq-a` `.pl-texto` `.pl-marca` `.ac-detalle` `.se-ayuda` `.pl-ayuda` `.g-line` `.pista-caja li` `.pa-nota` `.sup-panel .sb-d` |
| Estado vacío 12.5 | 12–13 px | `.ci-vacia` `.ra-vacio` `.pu-vacio` `.co-vacia` `.cons-vacio` `.se-nada` `.av-vacio` `.combo-vacio` `.hilo-vacio` |
| Nota 11 / 1.55 | 10.5 px | `.tr-desde` `.av-i .av-f` `.u-sub` `.jluego` `.jcount` |
| Nota 11 / 1.55 | 11.5 px | `.t-desc` `.t-arch` `.g-role` `.tr-plazo` `.cg-ente` `.asst-h .as` `.pl-caja .pc-s` `.phase-h .pd` `.em-nota` `.em-minimo` `.sug-nada` `.ay-paso-e` `.us-nota` |
| Nota 11 / 1.55 | 12 px | `.sec-h .sub` `.so-nota` `.ci-nota` `.co-nota` |
| Nota 11 / 1.55 | 10 px | `.asst-note` |

### 4.4 Controles

| Destino | Hoy | Selectores |
| --- | --- | --- |
| Botón 11.5 / 700 | 12–12.5 px | `.pa-atras` `.pa-sigue` `.sol-enviar` `.volver` `.asst-in button` `.ac-pie .btn` `.dc-fila .btn` `.dc-pie .btn` `.co-botones .btn` |
| Botón 11.5 / 700 | 11.5 / 600 | `.tb-btn` |
| Pestaña 12.5 / 600 | 12.5 / 500 · 11.5 / 700 | filtros (`#mtFiltros` `#ciFiltros` `#raFiltros` `.co-filtros`) `.ftab` |
| Campo 12.5 | 13 px | `.pf-campo input/select/textarea` `.id-form input/select/textarea` `.so-txt input` `.so-num input` `.asst-in input` `.se-buscar` |
| Rótulo de formulario 11.5 / 700 | 11 / 700 | `.sol-campo label` `.id-form label` |
| Enlace suelto 13 / 600 | 12 px | `.cons-volver` `.tsec-sig` `.t-mas` |
| Enlace en ficha 11.5 / 700 | 11 px | `.sol-doc .sd-btn` `.t-foot .go` |

### 4.5 Listas, pastillas y microrótulos

| Destino | Hoy | Selectores |
| --- | --- | --- |
| Fila 12 / 600 | 12.5–13 px, 600–700 | `.u-name` `.cons-i .ci-as` `.tr-paso-n` `.sol-lado .sd-n` `.sol-doc .sd-n` `.help-row .ht` `.av-i .av-t` `.se-op` `.lang-menu button` `.combo-list li` |
| Grupo en mayúsculas 11 / 800 / .05em | 9.5–10.5 px, hasta .1em | `.pa-grupo` `.pista-caja .pc-g` `.grupo-t` `.us-sec` `.av-h` `.co-seccion` `.em-sec` `.co-exp-t` |
| Pastilla 10 / 700 | 10 / 800 | `.ct-chip` `.co-estado` `.tr-aqui` `.pa-v .pv-ya` `.sol-doc .sd-ya` `.av-n` `.ftab .n` `.tr-punto` `.jp.active[data-ir]::after` |
| Pastilla 10 / 700 | 9–11 px | `.cg-chip` `.t-ente .ebadge` `.chip.niv` |
| Microrótulo 10 / 700 | 8.5–9.5 px | `.sb-gl` `.sb-langs-lbl` `.sb-item .soon-tag` `.hero-ring .pl` `.sup-nube-quien` `.sup-nube-marca` |
| Mono 9.5 / 600 | 9 / 800 | `.combo-list li .bandera-cod` |

---

## 5. Lo que no se toca

| Qué | Por qué |
| --- | --- |
| `.hero h1`, `.sb-head .pn` | Ya son la serif de Atlas: 34 px, peso 400 |
| Chevrones, flechas, íconos de letra | No son texto: `.faq-h .chev` `.phase-h .chev` `.volver .v-ico` `.asst-h .ax` `.th-orden .flecha` `.lang-btn .caret` |
| Iniciales de avatar, banderas | Se dimensionan con su caja: `.avatar` `.gestor .g-av` `.pf-foto-vista` `.sb-langs .flag` |
| Burbujas de conversación | `.bub` `.hilo-txt` tienen su propia interlínea de chat |
| Tokens de color | Pedido del CIIP del 3 de septiembre (ver §1) |
| `acceso.html`, `login/index.html` | Ya usan Helvetica e Instrument Serif. Se revisan aparte |

---

## 6. Convenciones de base

Dos reglas globales, las dos de Atlas.

```css
/* Los controles no traen su propia letra */
input, select, textarea, button { font-family: inherit; }

/* Cifras que se comparan en columna */
.tnum,
.pu-n .v, .ft-t .n, .hm .v, .us-m .n, .hero-ring .pct, .ac-monto {
  font-variant-numeric: tabular-nums;
}
```

Hoy solo unas pocas reglas les ponen la letra heredada a los controles
(`font-family: inherit` o `font: inherit`), pero en el marcado hay 117
botones, 26 inputs, 9 selects y 3 textareas.

---

## 7. Implementación

La escala entra como **tokens** en `:root`, igual que los colores: cambiar un
escalón es cambiar una línea.

```css
:root{
  --fs-cifra:24px;   --fs-titulo:20px;   --fs-tarjeta:14px;
  --fs-valor:13.5px; --fs-seccion:13px;  --fs-enlace:13px;
  --fs-parrafo:12.5px; --fs-campo:12.5px; --fs-pestana:12.5px;
  --fs-fila:12px;    --fs-boton:11.5px;
  --fs-rotulo:11px;  --fs-nota:11px;     --fs-chip:10px;
}
```

Cada regla de §4 pasa de `font-size:15px` a `font-size:var(--fs-tarjeta)` y
ajusta su peso según la tabla.

No usar el atajo `font:` con `inherit` dentro. Es CSS inválido y el navegador
descarta la declaración entera (ya pasó con `.volver`).

### Orden de trabajo

1. Esperar a que la otra pestaña termine con el HTML.
2. Añadir los tokens y las dos reglas de §6.
3. Aplicar §4, un bloque a la vez, en un solo commit.
4. Volver a contar los tamaños: deben quedar solo los 14 de la escala más los de §5.
5. Revisar en claro y en oscuro: portada, catálogo de fichas, ficha abierta,
   formulario de solicitud, panel del trabajador.
6. Comprobar que la cifra de `.hero-ring .pct` cabe en el anillo a 24 px.

---

## 8. Decisiones pendientes

- [ ] **Rótulo de formulario.** Atlas usa 11.5 / 500 gris. Sin gris, se
      propone 11.5 / **700** para que no se confunda con lo escrito.
- [ ] **Enlaces de acción.** Se propone 13 / 600 para los sueltos y
      11.5 / 700 para los que van dentro de una ficha, para no agrandarla.
- [ ] **`--mudo` (#737373).** Sigue gris en 16 reglas (filtros, contadores,
      estados vacíos). No cumple el pedido del CIIP. ¿Pasa a `--ink`?

---

## 9. Antipatrones

1. **Subir el tamaño para crear jerarquía.** Aquí no hay tinta: sube el peso.
2. **Un rótulo con el mismo peso que su dato.** Sin gris, esto borra la
   jerarquía por completo.
3. **Un tamaño nuevo fuera de la escala.** Si ningún escalón sirve, el problema
   es el diseño, no la escala.
4. **Un control nuevo sin `font-family: inherit`.** La regla global lo cubre;
   no la sobrescribas.
5. **Interletraje en texto corrido.** Solo en rótulos pequeños, mayúsculas y
   títulos grandes.
