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
| `ciip.png` | CIIP | Extraído del propio panel, donde ya iba incrustado en base64 |

## Lo que falta

No se encontró logo utilizable para **INCES**, **FAOV**, **INSAI**, **VUCE**
ni **RNC**. Sus tarjetas siguen mostrando solo las siglas, que es exactamente
como estaba todo antes de este cambio: si no hay archivo, el `onerror` de la
etiqueta `<img>` la retira y no queda ningún hueco ni icono roto.

Para añadir uno que falte, deja el archivo aquí y cambia el `<div class="t-ico">`
de esa tarjeta por la casilla del organismo:

```html
<div class="t-marca">
  <div class="t-ico"><img class="ilogo" src="logos/vuce.png" alt="" onerror="this.closest('.t-marca').remove()"></div>
  <div class="t-sigla">VUCE</div>
</div>
```

Y quita de esa tarjeta el `<span class="ebadge">VUCE</span>`, que ya estaría
repitiendo las siglas.

## Dos avisos

**Hay dos tarjetas que nombran varios organismos** — `IVSS · INCES · FAOV` y
`SENCAMER · INSAI` — y solo llevan el logo del primero. Se ve un logo donde el
texto nombra a tres. Si molesta, quitar el `<img>` de esas dos y dejarlas solo
con texto.

**No están verificados como versión oficial vigente.** Se descargaron de
Commons y de las webs de los organismos en agosto de 2026. Antes de enseñar
esto fuera del CIIP conviene contrastarlos con cada ente.
