# Ventanilla Única del CIIP — reglas del proyecto

Las lee toda sesión y todo agente que trabaje en este repositorio. Las decide Franklin Reyes (CIIP); el contenido de los trámites lo confirma el CIIP (Valeria Ramos).

## Idioma
- Todo en español latinoamericano neutro: respuestas, avisos, commits, comentarios y textos de pantalla. Nada en inglés ni jerga.
- Los textos de pantalla van en los 8 idiomas: es, en, pt, it, zh, ru, fr, ja (pasos.js e i18n.js).

## Estilo de pantalla
- Sin filos, franjas ni marcos de color (nada de border-left de color). Lo elegido se distingue por el fondo (`--activa-bg`); lo urgente, por el color del dato, no del marco.
- Colores solo con las variables de `panel.css`. Nada de anaranjado.
- Sin `text-transform:uppercase`. Títulos tal cual, casi negros.
- Rótulos: mayúscula solo en la primera palabra, en nombres propios y en siglas. En los 8 idiomas.
- Toda tarjeta de sistema (`.st-tarjeta`) mide 155×176 px en computadora: sigla, un renglón de nombre y hasta tres de «Te toca si». Un texto nuevo se mide en los 8 idiomas; un aviso que no cabe va al paso 1.

## Forma de trabajo
- Cambios de pantalla: primero una maqueta en `maquetas/`, que Franklin elija, y después llevarla al panel. Las maquetas no tocan el panel.
- No inventar requisitos, recaudos, enlaces ni nombres de organismos. Lo que no se sabe se dice y queda «por confirmar con el CIIP».
- Antes de borrar o sobrescribir, mirar qué hay.

## Pruebas
- `node pruebas/claves.js`: textos e idiomas. Hay 2 fallas previas aceptadas: «ninguna clave definida se queda sin usar» y «el punto final, o en todos los idiomas o en ninguno».
- `powershell -NoProfile -ExecutionPolicy Bypass -File pruebas\panel.ps1`: el panel en el navegador.
- `powershell -NoProfile -ExecutionPolicy Bypass -File pruebas\postgres.ps1`: la base de datos de prueba.
- Nunca dos `panel.ps1` o `postgres.ps1` a la vez: comparten carpeta temporal. Un agente que trabaje en paralelo no las corre.
- Leer el resultado antes de subir: nunca pruebas y `git push` en el mismo comando.
- Las pruebas no miden el diseño: un cambio de pantalla se revisa además con capturas (computadora y 390 px).

## Git
- El main bueno es el remoto `ciip`: `git push ciip main`. `origin` está parado desde el 16-9-2026.
- Subir a main solo cuando Franklin lo pide.
- Antes de cada push, sin que haga falta pedirlo, se envía al agente `verificador` con solo el cambio pendiente (`ciip/main..HEAD`). Un candado (`.claude/hooks/exigir-verificador.js`) bloquea el push si el verificador no aprobó ese mismo commit. Si después hay otro commit, se revisa de nuevo.
- Si hay cambios de otras sesiones en el árbol, agregar solo los archivos propios.
- En Windows, `git show HEAD^:archivo` falla desde cmd (el `^` es escape): usar `HEAD~1`.

## SQL
- Cada cambio de base lleva dos archivos: `supabase-<nombre>.sql`, con comentarios, y `CORRER-<NOMBRE>-<fecha>.sql`, solo con sentencias, sin comentarios ni cabecera.
- Se puede correr más de una vez, y se prueba en la base de prueba antes de entregarlo: copiarlo en lugar del `supabase-*.sql` de origen y correr `postgres.ps1`. Se agrega a `pruebas/juntar-sql.js` en su orden.
- Nadie corre SQL en la base real: lo corre Franklin en Supabase.
- Borrar filas solo si nada las referencia.
