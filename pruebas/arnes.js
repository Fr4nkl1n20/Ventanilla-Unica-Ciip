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
  /* Tolerante con los campos que ya no existen: al ir retirando vistas del
     acceso, un id desaparecido tumbaba el arnés entero y no se ejecutaba
     ninguna prueba. Mejor que la que sobra se salte a que caigan todas. */
  function val(id,v){
    var e=document.getElementById(id);
    if(!e) return;
    if(e.type==='checkbox'){e.checked=v;} else {e.value=v;}
  }
  function limpiaTodo(){
    ['li-email','li-pass','nv-pass','nv-pass2'].forEach(function(i){ val(i,''); });
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

  /* ---------- CLAVE NUEVA ---------- */
  caso('clave nueva vacía', function(){}, 'formNueva','msgNueva',VACIO);
  caso('clave nueva corta', function(){ val('nv-pass','123'); val('nv-pass2','123'); }, 'formNueva','msgNueva',CORTA);
  caso('clave nueva no coincide', function(){ val('nv-pass','12345678'); val('nv-pass2','87654321'); }, 'formNueva','msgNueva',DISTIN);

  /* ---------- NAVEGACIÓN ---------- */
  limpiaTodo();
  ['nueva','login'].forEach(function(v){
    irA(v);
    var on = document.querySelector('.view.on');
    R.push({n:'navegar a '+v, ok:(on && on.id==='v-'+v), got:(on?on.id:'ninguna'), exp:'v-'+v});
  });

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

  /* ---------- SIN RECUPERAR CLAVE ----------
     Se retiró el "¿Olvidaste tu clave?". La vista de clave nueva SÍ se
     conserva a propósito: es la que atiende el enlace del correo de
     recuperación cuando lo envía un administrador desde Supabase. */
  R.push({n:'no hay enlace de clave olvidada', ok:!document.querySelector('[data-go="recuperar"]'),
          got:(document.querySelector('[data-go="recuperar"]')?'hay uno':'ninguno'), exp:'ninguno'});
  R.push({n:'la vista de recuperar ya no existe', ok:!document.getElementById('v-recuperar'),
          got:(document.getElementById('v-recuperar')?'sigue ahí':'no existe'), exp:'no existe'});
  R.push({n:'pero clave nueva sí sigue', ok:!!document.getElementById('v-nueva'),
          got:(document.getElementById('v-nueva')?'existe':'falta'), exp:'existe'});
  R.push({n:'#recuperar cae al login', ok:(function(){
            irA('login'); irA('recuperar');
            var on=document.querySelector('.view.on');
            return !!on && on.id==='v-login';
          })(), got:(document.querySelector('.view.on')||{id:'ninguna'}).id, exp:'v-login'});

  /* ---------- SIN CREAR CUENTA ----------
     Las cuentas las abre el CIIP: aquí no se puede crear ninguna. Estas tres
     lo comprueban por los tres caminos por los que alguien podría llegar. */
  R.push({n:'la vista de registro ya no existe', ok:!document.getElementById('v-registro'),
          got:(document.getElementById('v-registro')?'sigue ahí':'no existe'), exp:'no existe'});
  R.push({n:'no hay enlace para crear cuenta', ok:!document.querySelector('[data-go="registro"]'),
          got:(document.querySelector('[data-go="registro"]')?'hay uno':'ninguno'), exp:'ninguno'});
  R.push({n:'escribir #registro no abre nada', ok:(function(){
            irA('login'); irA('registro');
            var on=document.querySelector('.view.on');
            return !!on && on.id==='v-login';
          })(), got:(document.querySelector('.view.on')||{id:'ninguna'}).id, exp:'v-login'});
  R.push({n:'no quedan campos del registro', ok:(function(){
            return !document.getElementById('rg-nombre') && !document.getElementById('rg-pais') &&
                   !document.getElementById('rg-email') && !document.getElementById('formReg');
          })(), got:'ninguno', exp:'ninguno'});

  /* ---------- DISPOSICIÓN DE TARJETA ---------- */
  R.push({n:'la tarjeta existe', ok:!!document.querySelector('.marco .tarjeta'),
          got:(document.querySelector('.tarjeta')?'si':'no'), exp:'si'});
  R.push({n:'la tarjeta tiene sus dos lados', ok:!!(document.querySelector('.tarjeta .lado-form') && document.querySelector('.tarjeta .lado-arte')),
          got:'form='+!!document.querySelector('.lado-form')+' arte='+!!document.querySelector('.lado-arte'), exp:'los dos'});
  R.push({n:'el rótulo se traduce', ok:(function(){
            applyLang('es'); var a=document.querySelector('.marca').textContent;
            applyLang('ru'); var b=document.querySelector('.marca').textContent;
            applyLang('es'); return a==='Ventanilla Única' && b!==a;
          })(), got:document.querySelector('.marca').textContent, exp:'Ventanilla Única / cambia'});
  R.push({n:'la ilustración no la lee el lector de pantalla', ok:(document.querySelector('.lado-arte').getAttribute('aria-hidden')==='true'),
          got:document.querySelector('.lado-arte').getAttribute('aria-hidden'), exp:'true'});
  R.push({n:'el pie está fuera de la tarjeta', ok:(function(){
            var p=document.querySelector('.pie'); return !!p && !p.closest('.tarjeta');
          })(), got:(document.querySelector('.pie')?'existe':'no existe'), exp:'fuera'});

  /* ---------- volcado ---------- */
  var pre=document.createElement('pre'); pre.id='RESULTADOS';
  pre.textContent='###'+JSON.stringify(R)+'###';
  document.body.appendChild(pre);
})();
