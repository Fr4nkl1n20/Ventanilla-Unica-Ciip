/* Pega los supabase-*.sql en uno solo, en el orden que prueba
   PROBAR-SQL.bat, y lo deja en TODO-EN-ORDEN.sql.

   Existe porque pegar veintitantas veces en el SQL Editor de Supabase es
   donde se salta uno sin darse cuenta, y saltarse el 15 no da error: da
   una pantalla vacia tres dias despues.

   El archivo que sale NO se edita a mano. Si cambia un supabase-*.sql se
   vuelve a correr esto:

       node pruebas/juntar-sql.js

   Que el archivo unico entra de una sola vez lo comprueba PROBAR-SQL.bat
   corriendo los archivos por separado: es el mismo texto y el mismo orden.

   ── LO QUE PASO CON LAS CONSULTAS, PARA QUE NO SE REPITA ──────────────
   El SQL de las consultas se escribio DIRECTAMENTE al final de
   TODO-EN-ORDEN.sql, sin archivo propio. Dos consecuencias, y ninguna se
   veia:

     · PROBAR-SQL.bat no lo probaba nunca. Corre los archivos de esta
       lista, y ese no estaba en ninguna.
     · Y correr este generador lo habria BORRADO, porque reescribe
       TODO-EN-ORDEN.sql desde la lista. El SQL de una funcion que ya
       esta viva en produccion, perdido por regenerar un indice.

   Ahora es supabase-consultas.sql como los demas. La regla que ya estaba
   escrita aqui arriba -«el archivo que sale NO se edita a mano»- era la
   correcta; lo que faltaba era cumplirla.

   Las cuentas de la cabecera se calculan de orden.length. Estaban a mano
   y decian 23, 26 y 25 a la vez, en el mismo archivo. */
const fs = require('fs');
process.chdir('C:/Users/ciip/Ventanilla-Unica-Ciip');
const BARRA = String.fromCharCode(92);

const orden = ['supabase-setup','supabase-tramites','supabase-admin','supabase-citas',
'supabase-empresa','supabase-activos','supabase-identidad','supabase-emision',
'supabase-presencia','supabase-sectores','supabase-catalogos','supabase-bitacora',
'supabase-bloqueo','supabase-acompanamiento','supabase-gestor','supabase-cola',
'supabase-avisos','supabase-aranceles','supabase-huellas','supabase-encadenado',
'supabase-plazos','supabase-una-viva','supabase-hilo','supabase-hilo-citas',
/* Va detras del hilo y no en cualquier sitio: reusa dos de sus funciones,
   mensaje_lo_firma_la_base() y mensaje_no_se_toca(), y lo comprueba al
   entrar. Puesto antes, se pararia solo diciendo cual falta. */
'supabase-consultas',
'supabase-informe-victor','supabase-pliego'];

let mal = 0;
for (const n of orden) {
  const s = fs.readFileSync(n + '.sql', 'utf8');
  const meta = s.split(/\r?\n/).filter(l => l.charAt(0) === BARRA);
  if (meta.length) { mal++; console.log('  ' + n + '.sql lleva ' + meta.length + ' ordenes de psql'); }
}
if (!mal) console.log('  ninguno lleva ordenes de psql: es SQL puro, vale tal cual en el SQL Editor');

const raya = '-- ' + '='.repeat(68);
const trozos = [
  raya,
  '--  LOS ' + orden.length + ' ARCHIVOS, EN EL ORDEN QUE PRUEBA PROBAR-SQL.bat',
  raya,
  '--  Esto es la union literal de los ' + orden.length + ' supabase-*.sql, sin cambiar una',
  '--  coma, pegados en el orden que ejecuta el arnes contra un Postgres de',
  '--  usar y tirar. Ese orden no esta deducido leyendo cabeceras: si uno',
  '--  usara algo que otro define despues, la tanda se caeria diciendo cual.',
  '--',
  '--  Se pega ENTERO en el SQL Editor de Supabase y se pulsa Run una vez.',
  '--  Todos son idempotentes -create if not exists, create or replace, drop',
  '--  policy if exists-, asi que volver a correrlo no rompe nada y es la',
  '--  forma de poner al dia un proyecto que ya tenia la mitad.',
  '--',
  '--  Generado el ' + new Date().toISOString().slice(0, 10) + '. Si cambia un archivo, se vuelve a generar:',
  '--  no se edita a mano, que entonces son ' + orden.length + ' sitios donde mirar.',
  raya,
  ''
];

orden.forEach(function (n, i) {
  const num = String(i + 1).padStart(2, '0');
  trozos.push('');
  trozos.push(raya);
  trozos.push('--  ' + num + ' / ' + orden.length + '   ' + n + '.sql');
  trozos.push(raya);
  trozos.push('');
  trozos.push(fs.readFileSync(n + '.sql', 'utf8').replace(/\r\n/g, '\n').replace(/\s*$/, ''));
});
trozos.push('');

const salida = trozos.join('\n');
fs.writeFileSync('TODO-EN-ORDEN.sql', salida);
console.log('  TODO-EN-ORDEN.sql: ' + Math.round(salida.length / 1024) + ' KB');
