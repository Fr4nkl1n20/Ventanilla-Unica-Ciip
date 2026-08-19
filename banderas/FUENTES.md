# Banderas

197 banderas, una por cada país de la lista del panel, en SVG y con
proporción 4×3. El nombre de cada archivo es su código ISO 3166-1 alfa-2 en
minúscula: `ve.svg`, `it.svg`, `cn.svg`.

## De dónde salen

**[flag-icons](https://github.com/lipis/flag-icons)** v7.2.3, de Panayiotis
Lipiridis. Licencia **MIT**, que permite usarlas y redistribuirlas siempre
que se conserve el aviso de copyright — este archivo lo conserva.

Se bajaron de `cdn.jsdelivr.net/npm/flag-icons@7.2.3/flags/4x3/`.

## Por qué están aquí y no se piden a un servidor

Dos razones, y la primera pesa más:

1. **`ABRIR-EN-RED.bat` sirve el panel en la oficina.** Un equipo sin salida
   a internet tiene que ver las banderas igual.
2. **Nadie de fuera necesita saber quién abre el panel.** Pedirlas a una CDN
   le entrega a un tercero la IP de cada inversionista que entra.

## Por qué no son emoji

Porque Windows no los dibuja. `🇻🇪` se ve como **VE** en cualquier navegador
sobre Windows: no hay fuente del sistema con banderas. En macOS y en Android
sí, y por eso es un fallo que se descubre tarde.

## Cuánto pesan

1,7 MB en total, y muy mal repartidos: Serbia 184 KB, Bolivia 112 KB, México
93 KB y España 91 KB, porque llevan el escudo dibujado entero. Italia, que
son tres franjas, ocupa 289 bytes.

Se ven a 20×15 px, donde ese detalle no se distingue. Si algún día molesta el
peso, el camino es sustituir la docena de banderas con escudo por versiones
simplificadas, no cambiar las 197.

## Cómo las usa el panel

El buscador de países de la ventana *Tu perfil* pide `banderas/{cod}.svg`.

Antes de pedir ninguna comprueba **una sola** (`ve.svg`): si esa no está, da
por hecho que no hay carpeta y enseña el código del país en una insignia
gris, sin volver a pedir nada. Así, un despliegue sin esta carpeta funciona
igual en vez de soltar doscientos errores en la consola por cada tecla.

Si falta una suelta, esa cae al código y las demás siguen saliendo.
