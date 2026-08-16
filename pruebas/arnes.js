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
   ══════════════════════════════════════════════════════════════════════ */
(function(){
  var R = [];
  function texto(id){ var m=document.getElementById(id); return m && m.classList.contains('show') ? m.textContent.trim() : ''; }
  function malos(){ return Array.prototype.slice.call(document.querySelectorAll('.field.bad')).map(function(f){return f.id;}).sort().join(','); }
  function val(id,v){ var e=document.getElementById(id); if(e.type==='checkbox'){e.checked=v;} else {e.value=v;} }
  function limpiaTodo(){
    ['li-email','li-pass','rg-nombre','rg-pais','rg-email','rg-pass','rg-pass2','rc-email','nv-pass','nv-pass2']
      .forEach(function(i){ val(i,''); });
    val('rg-terms',false);
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

  /* ---------- INICIAR SESIÓN ---------- */
  caso('login vacío', function(){}, 'formLogin','msgLogin',VACIO);
  caso('login sin clave', function(){ val('li-email','a@b.com'); }, 'formLogin','msgLogin',VACIO);
  caso('login correo inválido', function(){ val('li-email','hola'); val('li-pass','12345678'); }, 'formLogin','msgLogin',CORREO);
  caso('login datos correctos (sin Supabase)', function(){ val('li-email','a@b.com'); val('li-pass','12345678'); }, 'formLogin','msgLogin',SIN_BD);

  /* ---------- CREAR CUENTA ---------- */
  /* el país ya no es texto libre: hay que elegir uno real */
  function regOk(){ val('rg-nombre','X'); val('rg-pais','Italia'); val('rg-email','a@b.com'); val('rg-pass','12345678'); val('rg-pass2','12345678'); val('rg-terms',true); }
  caso('registro vacío', function(){}, 'formReg','msgReg',VACIO);
  caso('registro correo inválido', function(){ regOk(); val('rg-email','nope'); }, 'formReg','msgReg',CORREO);
  caso('registro clave corta', function(){ regOk(); val('rg-pass','1234'); val('rg-pass2','1234'); }, 'formReg','msgReg',CORTA);
  caso('registro claves distintas', function(){ regOk(); val('rg-pass2','87654321'); }, 'formReg','msgReg',DISTIN);
  caso('registro sin aceptar términos', function(){ regOk(); val('rg-terms',false); }, 'formReg','msgReg','Debes aceptar el tratamiento de datos para continuar.');
  caso('registro correcto (sin Supabase)', regOk, 'formReg','msgReg',SIN_BD);

  caso('registro con país inventado', function(){ regOk(); val('rg-pais','Talia'); }, 'formReg','msgReg','Elige un país de la lista.');

  /* ---------- NOMBRE EN MAYÚSCULAS ---------- */
  (function(){
    var n = document.getElementById('rg-nombre');
    function teclea(v){ n.value=v; n.dispatchEvent(new Event('input',{bubbles:true})); return n.value; }
    function sale(v){ n.value=v; n.dispatchEvent(new Event('blur',{bubbles:true})); return n.value; }

    R.push({n:'al escribir sube las iniciales', ok:(teclea('marco bianchi')==='Marco Bianchi'),
            got:teclea('marco bianchi'), exp:'Marco Bianchi'});
    R.push({n:'no estropea lo ya escrito en mayúscula', ok:(teclea('McDonald Llosa')==='McDonald Llosa'),
            got:teclea('McDonald Llosa'), exp:'McDonald Llosa'});
    R.push({n:'nombres compuestos con guion', ok:(teclea('jean-pierre du pont')==='Jean-Pierre Du Pont'),
            got:teclea('jean-pierre du pont'), exp:'Jean-Pierre Du Pont'});
    R.push({n:'respeta las tildes', ok:(teclea('ángel íñigo')==='Ángel Íñigo'),
            got:teclea('ángel íñigo'), exp:'Ángel Íñigo'});
    R.push({n:'al salir arregla TODO EN MAYÚSCULAS', ok:(sale('PEDRO PEREZ RONDON')==='Pedro Perez Rondon'),
            got:sale('PEDRO PEREZ RONDON'), exp:'Pedro Perez Rondon'});
    R.push({n:'al salir deja en minúscula las partículas', ok:(sale('juan DE LA cruz')==='Juan de la Cruz'),
            got:sale('juan DE LA cruz'), exp:'Juan de la Cruz'});
    R.push({n:'una partícula al principio sí va en mayúscula', ok:(sale('de la torre ana')==='De la Torre Ana'),
            got:sale('de la torre ana'), exp:'De la Torre Ana'});
    R.push({n:'al salir quita espacios de sobra', ok:(sale('  ana   maria  ')==='Ana Maria'),
            got:'"'+sale('  ana   maria  ')+'"', exp:'Ana Maria'});
    n.value='';
  })();

  /* ---------- BUSCADOR DE PAÍSES ---------- */
  R.push({n:'la lista de países se construyó', ok:(PAISES.length>180), got:PAISES.length+' países', exp:'más de 180'});

  var campo=document.getElementById('rg-pais'), lista=document.getElementById('listaPais');
  limpiaTodo();
  campo.value='ital'; campo.dispatchEvent(new Event('input',{bubbles:true}));
  var op=lista.querySelectorAll('li[role="option"]');
  R.push({n:'escribir "ital" filtra', ok:(op.length>0 && op.length<12 && /Italia/.test(lista.textContent)), got:op.length+' resultados: '+lista.textContent.replace(/\s+/g,' ').slice(0,60), exp:'pocos, con Italia'});

  campo.value='peru'; campo.dispatchEvent(new Event('input',{bubbles:true}));
  R.push({n:'busca sin tildes ("peru" halla "Perú")', ok:/Per/.test(lista.textContent), got:lista.textContent.replace(/\s+/g,' ').slice(0,40), exp:'aparece Perú'});

  campo.value='venez'; campo.dispatchEvent(new Event('input',{bubbles:true}));
  var pri=lista.querySelector('li[role="option"]');
  if(pri) pri.dispatchEvent(new MouseEvent('mousedown',{bubbles:true,cancelable:true}));
  R.push({n:'elegir con el ratón rellena el campo', ok:(campo.value.indexOf('Venezuela')>=0 && document.getElementById('rg-pais-cod').value==='VE'),
          got:'campo="'+campo.value+'" codigo="'+document.getElementById('rg-pais-cod').value+'"', exp:'Venezuela / VE'});

  campo.value='esp'; campo.dispatchEvent(new Event('input',{bubbles:true}));
  campo.dispatchEvent(new KeyboardEvent('keydown',{key:'ArrowDown',bubbles:true}));
  var sel=lista.querySelector('li.sel');
  R.push({n:'la flecha abajo marca un resultado', ok:!!sel, got:(sel?sel.textContent.trim():'ninguno'), exp:'uno marcado'});

  /* el país elegido se retraduce al cambiar de idioma, sin perder el código */
  campo.value='venez'; campo.dispatchEvent(new Event('input',{bubbles:true}));
  var p0=lista.querySelector('li[role="option"]'); if(p0) p0.dispatchEvent(new MouseEvent('mousedown',{bubbles:true,cancelable:true}));
  var antes=campo.value;
  applyLang('zh');
  var despues=campo.value, codIgual=(document.getElementById('rg-pais-cod').value==='VE');
  applyLang('es');
  R.push({n:'el país se retraduce al cambiar de idioma', ok:(antes!==despues && codIgual && campo.value===antes),
          got:'es="'+antes+'" zh="'+despues+'" vuelve="'+campo.value+'"', exp:'cambia y vuelve, código intacto'});

  R.push({n:'lo que se guarda va siempre en español', ok:(function(){
            campo.value='venez'; campo.dispatchEvent(new Event('input',{bubbles:true}));
            var x=lista.querySelector('li[role="option"]'); if(x) x.dispatchEvent(new MouseEvent('mousedown',{bubbles:true,cancelable:true}));
            applyLang('en'); var g=window.paisParaGuardar(); applyLang('es');
            return g==='Venezuela';
          })(), got:'—', exp:'Venezuela'});

  /* ---------- RECUPERAR ---------- */
  caso('recuperar vacío', function(){}, 'formRec','msgRec',VACIO);
  caso('recuperar correo inválido', function(){ val('rc-email','xx'); }, 'formRec','msgRec',CORREO);
  caso('recuperar correcto (sin Supabase)', function(){ val('rc-email','a@b.com'); }, 'formRec','msgRec',SIN_BD);

  /* ---------- CLAVE NUEVA ---------- */
  caso('clave nueva vacía', function(){}, 'formNueva','msgNueva',VACIO);
  caso('clave nueva corta', function(){ val('nv-pass','123'); val('nv-pass2','123'); }, 'formNueva','msgNueva',CORTA);
  caso('clave nueva no coincide', function(){ val('nv-pass','12345678'); val('nv-pass2','87654321'); }, 'formNueva','msgNueva',DISTIN);

  /* ---------- NAVEGACIÓN ---------- */
  limpiaTodo();
  ['registro','recuperar','nueva','login'].forEach(function(v){
    irA(v);
    var on = document.querySelector('.view.on');
    R.push({n:'navegar a '+v, ok:(on && on.id==='v-'+v), got:(on?on.id:'ninguna'), exp:'v-'+v});
  });

  limpiaTodo(); enviar('formLogin');
  var habia = texto('msgLogin') !== '';
  irA('registro'); irA('login');
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

  /* ---------- ADAPTADOR DE SESIÓN ---------- */
  almacenSesion.recordar = false;
  var r1 = almacenSesion.recordar;
  almacenSesion.setItem('prueba-x','1');
  var enSession = (window.sessionStorage.getItem('prueba-x')==='1');
  var enLocal   = (window.localStorage.getItem('prueba-x')==='1');
  almacenSesion.recordar = true;
  var r2 = almacenSesion.recordar;
  almacenSesion.removeItem('prueba-x');
  R.push({n:'recordar=false guarda en sessionStorage', ok:(r1===false && enSession && !enLocal), got:'recordar='+r1+' session='+enSession+' local='+enLocal, exp:'session sí, local no'});
  R.push({n:'la preferencia persiste', ok:(r2===true && window.localStorage.getItem('ciip_recordar')==='1'), got:'recordar='+r2+' guardado='+window.localStorage.getItem('ciip_recordar'), exp:'true / "1"'});

  /* ---------- CONFIGURACIÓN CENTRALIZADA ---------- */
  R.push({n:'config.js se carga', ok:(typeof window.CIIP_CONFIG==='object' && !!window.CIIP_CONFIG),
          got:(window.CIIP_CONFIG? 'cargado':'NO se cargo'), exp:'cargado'});
  R.push({n:'las claves salen de config.js', ok:(SUPABASE_URL===window.CIIP_CONFIG.SUPABASE_URL && SUPABASE_ANON_KEY===window.CIIP_CONFIG.SUPABASE_ANON_KEY),
          got:SUPABASE_URL, exp:'el valor de config.js'});
  R.push({n:'RUTA_PANEL sale de config.js', ok:(RUTA_PANEL===window.CIIP_CONFIG.RUTA_PANEL), got:RUTA_PANEL, exp:window.CIIP_CONFIG.RUTA_PANEL});

  /* ---------- MARCA ---------- */
  R.push({n:'el logo carga', ok:(function(){ var i=document.querySelector('.brand-mark'); return !!i && i.complete && i.naturalWidth>0; })(),
          got:(function(){ var i=document.querySelector('.brand-mark'); return i? i.naturalWidth+'x'+i.naturalHeight : 'no existe'; })(), exp:'199x72'});
  R.push({n:'el nombre está al lado, como texto', ok:!!document.querySelector('.brand-lockup .brand-name'),
          got:(document.querySelector('.brand-name')||{textContent:'no existe'}).textContent.replace(/\s+/g,' ').trim(), exp:'texto real'});

  /* ---------- volcado ---------- */
  var pre=document.createElement('pre'); pre.id='RESULTADOS';
  pre.textContent='###'+JSON.stringify(R)+'###';
  document.body.appendChild(pre);
})();
