/* ══════════════════════════════════════════════════════════════════════
 *  PEGAR-EN-LA-BASE.sql: lo que hay que correr, SIN UNA LETRA DE MAS
 *  Se lanza con:  node pruebas/limpiar-sql.js
 * ══════════════════════════════════════════════════════════════════════
 *  Franklin Reyes, 22 de septiembre de 2026: «puedes limpiarme ese codigo,
 *  que no tenga comentarios». LO-QUE-FALTA-CORRER.sql explica cada punto
 *  -por que hace falta, que pasa si no se corre, en que base va- y eso es
 *  justo lo que estorba cuando ya lo has leido y solo quieres pegar y
 *  pulsar Run.
 *
 *  ASI QUE NO SE ESCRIBE A MANO: se saca del otro. Una copia escrita
 *  aparte envejece sola -se arregla una y se olvida la otra- y entonces
 *  hay dos archivos que dicen cosas distintas sobre la misma base. Aqui
 *  hay UNA fuente y esto es su sombra.
 *
 *  QUE SE QUEDA Y QUE NO
 *  Se queda lo que CAMBIA la base: update, delete, insert y los bloques
 *  do $$. Se van los comentarios y tambien los `select`, que en ese
 *  archivo son de mirar -el diagnostico del punto 1, los «comprobar» de
 *  cada punto- y no hacen nada. Para mirar esta el otro.
 *
 *  HAY PUNTOS QUE NO TRAEN SU SQL, SINO QUE REMITEN A UN ARCHIVO. El 6
 *  dice «pega entero supabase-visa-tri.sql», porque renombrar un codigo
 *  son cinco pasos en un orden que importa y partirlos en dos sitios
 *  acabaria en dos versiones distintas del mismo plpgsql. Este guion
 *  sigue esas remisiones: sin eso el archivo limpio salia con seis
 *  sentencias en vez de nueve, y quien lo pegaba corria MENOS de lo que
 *  creia sin que nada se lo dijera.
 *
 *  Las sentencias se separan contando los delimitadores $tag$: dentro de
 *  un bloque do hay puntos y coma a patadas, y cortar por ';' a secas lo
 *  partiria por la mitad.
 * ══════════════════════════════════════════════════════════════════════ */
'use strict';
const fs = require('fs');
const path = require('path');

const raiz   = path.join(__dirname, '..');
const fuente = path.join(raiz, 'LO-QUE-FALTA-CORRER.sql');
const salida = path.join(raiz, 'PEGAR-EN-LA-BASE.sql');

/*  Los puntos que mandan pegar otro archivo entero, y cual. Va DELANTE de
 *  las sentencias propias del punto: en el 6, el archivo da de alta la
 *  ficha y la linea de despues la enciende en las bases donde ya se corrio
 *  cuando nacia apagada. */
const REMITEN = { 6: ['supabase-visa-tri.sql'] };

const CAMBIAN = /^(update|delete|insert|do)\b/i;

/*  Parte un texto en sentencias, respetando los bloques $tag$. */
function enSentencias(texto) {
  const fuera = [];
  let actual = '';
  let dentro = null;
  for (let i = 0; i < texto.length; i++) {
    const c = texto[i];
    if (c === '$') {
      const m = /^\$[A-Za-z_]*\$/.exec(texto.slice(i));
      if (m) {
        const tag = m[0];
        if (dentro === null) dentro = tag;
        else if (dentro === tag) dentro = null;
        actual += tag;
        i += tag.length - 1;
        continue;
      }
    }
    if (c === ';' && dentro === null) { fuera.push(actual + ';'); actual = ''; continue; }
    actual += c;
  }
  if (actual.trim()) fuera.push(actual);
  return fuera;
}

/*  PRIMERO se van los comentarios y DESPUES se trocea, nunca al reves.
 *  Los comentarios de estos archivos llevan puntos y coma dentro -«dura un
 *  año; la TR-I dura tres»- y troceando antes se corta por la mitad de una
 *  frase: la sentencia siguiente nacia con media explicacion pegada
 *  delante, dejaba de empezar por update o insert, y este guion la tiraba
 *  por no reconocerla. Se perdian tres de nueve sin decir nada. */
function soloLasQueCambian(texto) {
  const sinComentarios = texto
    .split('\n')
    .filter(l => !/^\s*--/.test(l))
    .join('\n');
  return enSentencias(sinComentarios)
    .map(s => s.replace(/\n{3,}/g, '\n\n').trim())
    .filter(s => s && CAMBIAN.test(s));
}

const texto = fs.readFileSync(fuente, 'utf8');

/*  Por puntos, para saber cual remite a que. */
/*  Con lookahead: parte DELANTE del renglon del punto y no se come nada.
 *  Partiendo por el propio renglon, el resto del titulo -«LAS TRES FICHAS
 *  DEL 21 DE SEPTIEMBRE»- se quedaba pegado a la primera sentencia del
 *  punto y la tiraba por no empezar por update. */
const trozos = texto.split(/(?=^--  PUNTO \d+\.)/m);
const limpias = [];
const deDonde = [];
for (const cuerpo of trozos) {
  const m = /^--  PUNTO (\d+)\./.exec(cuerpo);
  const punto = m ? m[1] : '0';
  for (const archivo of (REMITEN[punto] || [])) {
    const ruta = path.join(raiz, archivo);
    if (!fs.existsSync(ruta)) {
      console.log('  El punto ' + punto + ' remite a ' + archivo + ' y no está. Lo dejo fuera.');
      continue;
    }
    const suyas = soloLasQueCambian(fs.readFileSync(ruta, 'utf8'));
    suyas.forEach(s => { limpias.push(s); deDonde.push(punto + ' · ' + archivo); });
  }
  soloLasQueCambian(cuerpo).forEach(s => { limpias.push(s); deDonde.push(punto); });
}

if (!limpias.length) {
  console.log('  No sale ninguna sentencia. ¿Cambió el formato de ' +
              path.basename(fuente) + '?');
  process.exit(2);
}

fs.writeFileSync(salida, limpias.join('\n\n') + '\n', 'utf8');

console.log('  ' + path.basename(salida) + ': ' + limpias.length +
            ' sentencias, sin un comentario.');
const porPunto = {};
deDonde.forEach(d => { porPunto[d] = (porPunto[d] || 0) + 1; });
Object.keys(porPunto).forEach(d => console.log('     punto ' + d + ': ' + porPunto[d]));
console.log('  Sacado de ' + path.basename(fuente) + '. No se edita a mano:');
console.log('  se arregla allí y se vuelve a correr esto.');
