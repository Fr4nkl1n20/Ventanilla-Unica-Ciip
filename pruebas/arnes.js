/* ══════════════════════════════════════════════════════════════════════
   ARNÉS DE PRUEBAS DE acceso.html
   ══════════════════════════════════════════════════════════════════════
   Este archivo NO se toca desde el navegador normal. Lo inyecta
   ejecutar.ps1 al final de una copia temporal de acceso.html, la abre en
   Chrome sin ventana, y lee el resultado del volcado.

   Para añadir una prueba nueva, copia una línea caso(...) y cambia:
       caso( nombre , qué rellenar , qué formulario , dónde sale el aviso , qué debe decir )

   Solo prueba lo que ocurre dentro del navegador. Todo lo que necesita
   Supabase (crear cuenta de verdad, entrar, correos) está en PRUEBAS.md,
   parte 4, y hay que hacerlo a mano.

   ── LO QUE SE FUE DE AQUÍ, Y POR QUÉ ──────────────────────────────────
   Este arnés llevaba días SIN EJECUTARSE Y SIN QUE NADIE LO SUPIERA. Se
   caía en la primera línea —limpiaTodo() pedía seis campos que ya no
   existen— y el .bat contestaba que todo bien, porque el `echo.` del
   final le pisaba el código de salida. Las dos cosas están arregladas: el
   .bat devuelve ahora lo que devuelve la tanda, y esto se ajusta a la
   página que hay.

   acceso.html perdió el REGISTRO y la RECUPERACIÓN -las cuentas las crea
   el equipo del CIIP- y con ellos se fueron de la página el medidor de
   fuerza, el buscador de países, el arreglo de mayúsculas del nombre y el
   almacén de sesión a medida. Quedan tres vistas: entrar, poner una clave
   nueva -a la que se llega desde el enlace del correo- y dentro.

   Así que se retiran las pruebas de todo eso. NO se esconden ni se dejan
   comentadas: una prueba de algo que no existe no protege nada y hace
   creer que sí. Si alguna de esas piezas vuelve a la página, sus pruebas
   se recuperan del historial, que para eso está.

   Se retiran con ellas 'venezuela2024', 'qwertyui' y las demás claves
   adivinables: comprobaban fuerzaClave(), que ya no está en la página. La
   de «tu propio nombre dentro de la clave» no volvería aunque volviera el
   medidor tal cual: a la clave nueva se llega desde un correo, sin nombre
   delante que darle.
   ══════════════════════════════════════════════════════════════════════ */
(function(){
  var R = [];
  function texto(id){ var m=document.getElementById(id); return m && m.classList.contains('show') ? m.textContent.trim() : ''; }
  function malos(){ return Array.prototype.slice.call(document.querySelectorAll('.field.bad')).map(function(f){return f.id;}).sort().join(','); }
  function val(id,v){ var e=document.getElementById(id); if(e.type==='checkbox'){e.checked=v;} else {e.value=v;} }
  function limpiaTodo(){
    /* Los cuatro que quedan en la página. Antes había once, y seis de
       ellos se fueron con el registro: pedirlos devolvía null y la línea
       de abajo reventaba antes de la primera prueba. */
    ['li-email','li-pass','nv-pass','nv-pass2']
      .forEach(function(i){ val(i,''); });
    document.querySelectorAll('.msg').forEach(function(m){m.classList.remove('show','err','ok');});
    document.querySelectorAll('.field').forEach(function(f){f.classList.remove('bad');});
  }
  function enviar(formId){
    document.getElementById(formId).dispatchEvent(new Event('submit',{cancelable:true,bubbles:true}));
  }
  function caso(nombre, prep, formId, msgId, esperado){
    limpiaTodo(); prep();
    try{ enviar(formId); }catch(e){ R.push({n:nombre,ok:false,got:'EXCEPCION: '+e.message,exp:esperado}); return; }
    var got = texto(msgId);
    R.push({n:nombre, ok:(got===esperado), got:got, exp:esperado, bad:malos()});
  }

  var SIN_BD = 'El acceso no está conectado a la base de datos todavía.';
  var VACIO  = 'Completa todos los campos.';
  var CORREO = 'Introduce un correo válido.';
  var CORTA  = 'La clave debe tener al menos 8 caracteres.';
  var DISTIN = 'Las claves no coinciden.';

  /* Una clave larga de verdad, para que la prueba de «no coinciden» llegue
     a comprobar lo suyo y no se quede en «es corta». */
  var FUERTE = 'Guacamaya-Tepuy-41';

  /* ---------- LA PÁGINA ES LA QUE CREEMOS ----------
     Esto va PRIMERO y a propósito. El arnés estuvo roto porque la página
     cambió debajo y nadie se enteró: probaba formularios que ya no
     existían. Si mañana desaparece otra pieza, que lo diga una prueba en
     rojo con su nombre, y no una excepción a mitad de la tanda. */
  ['formLogin','msgLogin','formNueva','msgNueva','li-email','li-pass','nv-pass','nv-pass2']
    .forEach(function(id){
      R.push({n:'la página tiene #'+id, ok:!!document.getElementById(id),
              got:(document.getElementById(id)?'está':'NO ESTÁ'), exp:'está'});
    });

  /* ---------- INICIAR SESIÓN ---------- */
  caso('login vacío', function(){}, 'formLogin','msgLogin',VACIO);
  caso('login sin clave', function(){ val('li-email','a@b.com'); }, 'formLogin','msgLogin',VACIO);
  caso('login correo inválido', function(){ val('li-email','hola'); val('li-pass','12345678'); }, 'formLogin','msgLogin',CORREO);
  caso('login datos correctos (sin Supabase)', function(){ val('li-email','a@b.com'); val('li-pass','12345678'); }, 'formLogin','msgLogin',SIN_BD);

  /* ---------- CLAVE NUEVA ---------- */
  caso('clave nueva vacía', function(){}, 'formNueva','msgNueva',VACIO);
  caso('clave nueva corta', function(){ val('nv-pass','123'); val('nv-pass2','123'); }, 'formNueva','msgNueva',CORTA);
  caso('clave nueva no coincide', function(){ val('nv-pass',FUERTE); val('nv-pass2','87654321'); }, 'formNueva','msgNueva',DISTIN);

  /* ---------- NAVEGACIÓN ---------- */
  limpiaTodo();
  ['nueva','login'].forEach(function(v){
    irA(v);
    var on = document.querySelector('.view.on');
    R.push({n:'navegar a '+v, ok:(on && on.id==='v-'+v), got:(on?on.id:'ninguna'), exp:'v-'+v});
  });

  /* Y una vista que ya no existe no deja la tarjeta en blanco: irA() la
     manda al login. Es lo que le pasa a un enlace viejo a #registro, que
     los hay repartidos por correos ya enviados. */
  irA('registro');
  (function(){
    var on = document.querySelector('.view.on');
    R.push({n:'un enlace viejo a una vista que ya no está cae en el login',
            ok:(on && on.id==='v-login'), got:(on?on.id:'ninguna'), exp:'v-login'});
  })();

  limpiaTodo(); enviar('formLogin');
  var habia = texto('msgLogin') !== '';
  irA('nueva'); irA('login');
  R.push({n:'cambiar de vista limpia el mensaje', ok:(habia && texto('msgLogin')===''), got:'antes='+habia+' despues="'+texto('msgLogin')+'"', exp:'vacío'});

  /* ---------- TRADUCCIÓN EN CALIENTE ---------- */
  limpiaTodo(); enviar('formLogin');
  var es = texto('msgLogin');
  applyLang('en');
  var en = texto('msgLogin');
  R.push({n:'mensaje visible se retraduce', ok:(es!=='' && en!=='' && es!==en), got:'es="'+es+'" en="'+en+'"', exp:'distintos'});
  R.push({n:'traduce la interfaz', ok:(document.querySelector('#v-login .f-title').textContent==='Sign in to your file'), got:document.querySelector('#v-login .f-title').textContent, exp:'Sign in to your file'});
  applyLang('es');

  /* ---------- OJO DE LA CLAVE ---------- */
  var inp=document.getElementById('li-pass'), ojo=document.querySelector('[data-eye="li-pass"]');
  var t0=inp.type; ojo.click(); var t1=inp.type; ojo.click(); var t2=inp.type;
  R.push({n:'mostrar/ocultar clave', ok:(t0==='password'&&t1==='text'&&t2==='password'), got:t0+'->'+t1+'->'+t2, exp:'password->text->password'});

  /* ---------- TRADUCCIONES COMPLETAS ---------- */
  var IDIOMAS=['es','en','pt','it','zh','ru'];
  R.push({n:'clave e.otro en los 6 idiomas',
          ok:IDIOMAS.every(function(l){ return I18N[l] && I18N[l]['e.otro']; }),
          got:IDIOMAS.filter(function(l){ return !(I18N[l]&&I18N[l]['e.otro']); }).join(',')||'todos', exp:'todos'});

  var faltan=[];
  Object.keys(I18N.es).forEach(function(k){
    IDIOMAS.forEach(function(l){ if(!I18N[l] || !I18N[l][k]) faltan.push(l+':'+k); });
  });
  R.push({n:'ningún texto sin traducir', ok:(faltan.length===0), got:(faltan.slice(0,5).join(' ')||'ninguno'), exp:'ninguno'});

  var sinClave=[];
  document.querySelectorAll('[data-i18n]').forEach(function(el){
    var k=el.getAttribute('data-i18n'); if(!I18N.es[k]) sinClave.push(k);
  });
  R.push({n:'todo data-i18n tiene su clave', ok:(sinClave.length===0), got:(sinClave.join(' ')||'ninguno'), exp:'ninguno'});

  /* ---------- CONFIGURACIÓN CENTRALIZADA ---------- */
  R.push({n:'config.js se carga', ok:(typeof window.CIIP_CONFIG==='object' && !!window.CIIP_CONFIG),
          got:(window.CIIP_CONFIG? 'cargado':'NO se cargo'), exp:'cargado'});
  R.push({n:'las claves salen de config.js', ok:(SUPABASE_URL===window.CIIP_CONFIG.SUPABASE_URL && SUPABASE_ANON_KEY===window.CIIP_CONFIG.SUPABASE_ANON_KEY),
          got:SUPABASE_URL, exp:'el valor de config.js'});
  R.push({n:'RUTA_PANEL sale de config.js', ok:(RUTA_PANEL===window.CIIP_CONFIG.RUTA_PANEL), got:RUTA_PANEL, exp:window.CIIP_CONFIG.RUTA_PANEL});

  /* ---------- MARCA ----------
     El diseño de tarjeta no lleva logo: la marca es el rótulo serif y la
     ilustración del Ávila. Antes aquí se comprobaba el PNG del monograma. */
  R.push({n:'la ilustración carga', ok:(function(){ var i=document.querySelector('.lado-arte img'); return !!i && i.complete && i.naturalWidth>0; })(),
          got:(function(){ var i=document.querySelector('.lado-arte img'); return i? i.naturalWidth+'x'+i.naturalHeight : 'no existe'; })(), exp:'1232x928'});
  R.push({n:'la marca es texto real, no una imagen', ok:(function(){ var m=document.querySelector('.marca'); return !!m && m.textContent.trim().length>0; })(),
          got:(document.querySelector('.marca')||{textContent:'no existe'}).textContent.replace(/\s+/g,' ').trim(), exp:'texto real'});
  R.push({n:'la marca se traduce', ok:(function(){ var m=document.querySelector('.marca'); return !!m && m.getAttribute('data-i18n')==='marca'; })(),
          got:(document.querySelector('.marca')||{}).getAttribute? (document.querySelector('.marca').getAttribute('data-i18n')||'sin data-i18n') : 'no existe', exp:'marca'});

  /* ---------- volcado ---------- */
  var pre=document.createElement('pre'); pre.id='RESULTADOS';
  pre.textContent='###'+JSON.stringify(R)+'###';
  document.body.appendChild(pre);
})();
