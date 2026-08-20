# De dónde salió cada logo

Se usan en el distintivo del organismo de cada trámite, en el panel. Todos
están reducidos a 48 px de alto, que es cuatro veces el tamaño al que se
muestran (13 px), para que se vean nítidos en pantallas densas sin pesar.

| Archivo | Organismo | Origen |
|---|---|---|
| `saime.png` | SAIME | Wikimedia Commons, `File:SAIME logo.png` |
| `seniat.png` | SENIAT | Wikimedia Commons, `File:LogoSENIAT.png` |
| `saren.png` | SAREN | Wikimedia Commons, `File:SAREN logo.png` |
| `intt.png` | INTT | Wikimedia Commons, `File:INTT logo.png` |
| `ivss.svg` | IVSS | Wikimedia Commons, `File:IVSS (azul).svg` |
| `sapi.png` | SAPI | Sitio oficial, `sapi.gob.ve` |
| `sencamer.png` | SENCAMER | Sitio oficial, `sencamer.gob.ve` |
| `snc.png` | Servicio Nacional de Contrataciones | Wikimedia Commons, `File:Logo Servicio Nacional de Contrataciones.png` |
| `sacs.png` | SACS (Contraloría Sanitaria) | Sitio oficial, `sacs.gob.ve` |
| `suscerte.png` | SUSCERTE | Sitio oficial, `suscerte.gob.ve` |
| `inces.png` | INCES | Sitio oficial, `inces.gob.ve` |
| `mppre.png` | MPPRE (Relaciones Exteriores) | Sitio oficial, `mppre.gob.ve` (`img/logo_mppre_redes.png`) |
| `mpprijp.png` | MPPRIJP (Interiores, Justicia y Paz) | Sitio oficial, `mpprijp.gob.ve` (recortado del cintillo de cabecera) |
| `mpppst.png` | MPPPST (Ministerio del Trabajo) | Cintillo oficial publicado en `inces.gob.ve`, recortado |
| `ciip.png` | CIIP | Extraído del propio panel, donde ya iba incrustado en base64 |

## Cómo se prepararon

Los que venían como **cintillo** —bandera + nombre del ministerio + a veces
otro logo al lado— se recortaron al primer bloque de tinta y luego a su caja,
antes de bajarlos a 48 px. Es lo que hace que `mpppst.png` diga "TRABAJO" y no
arrastre el logo del INCES que iba pegado a su derecha.

## Lo que sigue faltando

No se encontró logo utilizable para:

| Organismo | Por qué |
|---|---|
| **MINEC** (permiso ambiental) | Su logo lleva el texto en gris clarísimo; a 13 px queda una mancha ilegible. El icono del sitio es solo la bandera, que no dice MINEC |
| **BANAVIH** (FAOV) | Solo publica la versión en blanco, invisible sobre la placa. Su icono es un arco azul sin nombre |
| **VUCE** (importación y exportación) | El sitio no respondió |
| **INSAI**, **FAOV**, **RNET como tal** | Sin sitio propio con logo |

Y hay tarjetas que **no tienen un organismo único**, así que no les toca logo:
el Registro Civil o consejo comunal, el periódico mercantil, la banca aliada,
la alcaldía —depende del municipio—, los bomberos y la de "entes varios".

Sus tarjetas siguen mostrando solo las siglas, que es como estaba todo antes:
si no hay archivo, el `onerror` de la etiqueta `<img>` retira la placa entera
y no queda ningún hueco ni icono roto.

Para añadir uno que falte, deja el archivo aquí y cambia el `<div class="t-ico">`
de esa tarjeta por la casilla del organismo:

```html
<div class="t-marca">
  <div class="t-ico"><img class="ilogo" src="logos/vuce.png" alt="" onerror="this.closest('.t-marca').remove()"></div>
  <div class="t-sigla">VUCE</div>
</div>
```

Y quita de esa tarjeta el `<span class="ebadge">VUCE</span>`, que ya estaría
repitiendo las siglas. Hay una prueba que lo comprueba
(`logos: y no repite la sigla al lado del nombre`).

## La marca de agua del fondo

Cada tarjeta con logo lo lleva **dos veces**: en la placa de arriba y, muy
apagado, al fondo a la derecha. Eso son dos cosas separadas y hay que poner
las dos:

1. el atributo `data-marca="vuce"` en el `<div class="tcard" …>`;
2. su regla de CSS, al lado de las demás:
   `.tcard[data-marca="vuce"]::before{background-image:url('logos/vuce.png');}`

Sin la regla, `data-marca` no pinta nada: el pseudo-elemento existe y se queda
sin imagen, y la tarjeta se ve igual que si no lo hubieras puesto. Por eso la
prueba `marca: cada tarjeta con logo lo lleva también al fondo` no mira el
atributo, sino lo que el navegador acabó pintando.

## Tres avisos

**El de MPPRE es el escudo nacional.** Es el archivo que la propia Cancillería
usa como su logo, pero no es una marca propia: si otro ministerio entra
después, los dos enseñarían lo mismo.

**Dos tarjetas llevan el logo del organismo que hace el trámite, no el del
trámite.** En "Registro Nacional de Contratistas" el logo es del SNC, y en
"Registro Nacional de Entidades de Trabajo" es del Ministerio del Trabajo. Por
eso esas dos conservan su distintivo —RNC, RNET— al lado del nombre: la sigla
de abajo dice quién lo lleva y el distintivo dice qué es.

**Hay dos tarjetas que nombran varios organismos** — `IVSS · INCES · FAOV` y
`SENCAMER · INSAI` — y solo llevan el logo del primero. Se ve un logo donde el
texto nombra a tres. Si molesta, quitar el `<img>` de esas dos y dejarlas solo
con texto.

**No están verificados como versión oficial vigente.** Se descargaron de
Commons y de las webs de los organismos en agosto de 2026. Antes de enseñar
esto fuera del CIIP conviene contrastarlos con cada ente.
