/* Pega los 23 supabase-*.sql en uno solo, en el orden que prueba
   PROBAR-SQL.bat, y lo deja en TODO-EN-ORDEN.sql.

   Existe porque pegar veintitres veces en el SQL Editor de Supabase es
   donde se salta uno sin darse cuenta, y saltarse el 15 no da error: da
   una pantalla vacia tres dias despues.

   El archivo que sale NO se edita a mano. Si cambia un supabase-*.sql se
   vuelve a correr esto:

       node pruebas/juntar-sql.js

   Que el archivo unico entra de una sola vez lo comprueba PROBAR-SQL.bat
   corriendo los 23 por separado: es el mismo texto y el mismo orden. */
const fs = require('fs');
process.chdir('C:/Users/ciip/Ventanilla-Unica-Ciip');
const BARRA = String.fromCharCode(92);

const orden = ['supabase-setup','supabase-tramites','supabase-admin','supabase-citas',
'supabase-empresa','supabase-activos','supabase-identidad','supabase-emision',
'supabase-presencia','supabase-sectores','supabase-catalogos','supabase-bitacora',
'supabase-bloqueo','supabase-acompanamiento','supabase-gestor','supabase-cola',
'supabase-avisos','supabase-aranceles','supabase-huellas','supabase-encadenado',
'supabase-plazos','supabase-una-viva','supabase-hilo','supabase-hilo-citas','supabase-informe-victor','supabase-pliego'];

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
  '--  LOS 26 ARCHIVOS, EN EL ORDEN QUE PRUEBA PROBAR-SQL.bat',
  raya,
  '--  Esto es la union literal de los 26 supabase-*.sql, sin cambiar una',
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
  '--  no se edita a mano, que entonces son 25 sitios donde mirar.',
  raya,
  ''
];

orden.forEach(function (n, i) {
  const num = String(i + 1).padStart(2, '0');
  trozos.push('');
  trozos.push(raya);
  trozos.push('--  ' + num + ' / 25   ' + n + '.sql');
  trozos.push(raya);
  trozos.push('');
  trozos.push(fs.readFileSync(n + '.sql', 'utf8').replace(/\r\n/g, '\n').replace(/\s*$/, ''));
});
trozos.push('');

const salida = trozos.join('\n');
fs.writeFileSync('TODO-EN-ORDEN.sql', salida);
console.log('  TODO-EN-ORDEN.sql: ' + Math.round(salida.length / 1024) + ' KB');
