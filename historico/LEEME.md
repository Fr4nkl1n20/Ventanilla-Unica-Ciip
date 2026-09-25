# Histórico

Lo que ya cumplió su función y no usa nada del proyecto. Se guarda por si
hace falta mirar cómo era algo, no para ejecutarlo. No se publica
(`.vercelignore`).

| Carpeta / archivo | Qué es |
|---|---|
| `sql-aplicado/` | Los SQL de un solo uso que se pegaron en el SQL Editor de producción: `CORRER-*`, `PARA-LA-BASE-REAL`, `LO-QUE-FALTA-CORRER`, `PEGAR-EN-LA-BASE`, `QUITAR-*`… El 25-09-2026 se comprobó uno por uno que **todos estaban aplicados**, y lo que definen vive ya en los `supabase-*.sql` de la raíz, de donde sale `TODO-EN-ORDEN.sql`. Ahí van también `vaciar-lo-pedido.sql` (borraba datos de producción: **no volver a pegarlo**), `limpiar-sql.js` (generaba `PEGAR-EN-LA-BASE.sql`) y la guía de altas de cuentas. |
| `original/` | La demostración de partida, intacta. |
| `capturas/` | Capturas de pantalla de agosto de 2026, algunas de pantallas que ya no existen (registro, recuperar clave). |
| `diseno/` | Los bocetos de diseño descartados (antes `.diseno/`). |
| `revision-cerraduras.html` | La revisión de seguridad del 3 de septiembre de 2026. |

Si un SQL de aquí hiciera falta otra vez, no se pega tal cual: lo vigente
está en los `supabase-*.sql` de la raíz.
