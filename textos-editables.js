/* LOS TEXTOS, EDITABLES POR EL ADMINISTRADOR. Va aparte, como antes dentro
   del HTML, para poder quitarse entero.
   Separado de ciip-ventanilla-unica-local.html el 25-09-2026 (auditoría de
   código, fase 5): el panel era un solo HTML de 1,8 MB. Se carga desde el HTML
   en el mismo sitio y en el mismo orden en que estaba escrito dentro. */
(function(){
  'use strict';
  var IDIOMAS = ['es', 'en', 'pt', 'it', 'zh', 'ru'];
  var CAMBIOS = {};      /* {es: {clave: texto}}: lo que dice la base */
  var ORIG_DIC = {};     /* {es: {clave: original}} del diccionario, al pisarlo */
  var ORIG_UI = {};      /* lo mismo para pasos.js */
  var ORIG_MARCA = {};   /* {clave: texto del marcado}, la primera vez que se ve */
  var editando = false;
  var actual = null;     /* {el, clave} del texto abierto en el editor */
  var tiene = Object.prototype.hasOwnProperty;

  function cliente(){ return window.sbCIIP || null; }
  function dic(){ return (I18N[curLang] || I18N.en || {}); }
  function esAdminAhora(){ return typeof PERFIL !== 'undefined' && PERFIL && PERFIL.rol === 'admin'; }
  function nombreIdioma(){
    var b = document.querySelector('#langMenu button[data-lang="' + curLang + '"]');
    return b ? b.textContent.trim() : curLang;
  }
  function uiDe(){ var P = window.CIIP_PASOS; return (P && P.ui) || null; }
  function claveDe(el){ return el.getAttribute('data-i18n') || el.getAttribute('data-texto') || el.getAttribute('data-ui'); }

  /* De cual de los tres sitios es una clave. Se pregunta a los seis idiomas
     y no solo al de turno: una clave que el español no tiene y cae al
     ingles sigue siendo del diccionario. */
  function tipoDe(clave){
    if (String(clave).indexOf('_p.') === 0) return 'bloque';
    if (IDIOMAS.some(function(l){ return I18N[l] && tiene.call(I18N[l], clave); })) return 'dic';
    var U = uiDe();
    if (U && IDIOMAS.some(function(l){ return U[l] && tiene.call(U[l], clave); })) return 'ui';
    return 'marca';
  }

  /* ── LOS TEXTOS DE LAS FICHAS, EN pasos.js ──
     Además de sus textos sueltos (ui), pasos.js lleva seis bloques por
     idioma: el título y el «vas por aquí» de la escalera, los estados, los
     sectores, la guía de cómo debe venir cada papel y LOS PASOS DE CADA
     TRÁMITE. Ninguno tenía clave, así que no se podían cambiar.

     La clave es el camino dentro del bloque, con un «_p.» delante para que
     no se confunda con las del diccionario -que nunca empiezan así-:
       '_p.titulo'                    CIIP_PASOS.titulo[idioma]
       '_p.pasos.c5.2'                CIIP_PASOS.pasos[idioma].c5[2]
       '_p.guia.propio.cedula.0'      CIIP_PASOS.guia[idioma].propio.cedula[0]
     Cabe en la regla de la tabla: letras, números, punto y guion bajo. */
  var BLOQUES = ['titulo', 'aqui', 'estados', 'circuito', 'sectores', 'guia', 'pasos'];
  var ORIG_BLOQ = {};    /* {es: {clave: original}} de pasos.js, al pisarlo */
  function trozos(clave){ return String(clave).slice(3).split('.'); }
  /* Los pasos de un trámite (_p.circuito.c37.2) nacen sin escribir: hasta
     que alguien los cambia, dicen lo mismo que el de todos. Por eso, si el
     trámite no tiene el suyo, se lee el general, y al escribir se le hace
     su lista a partir de él. */
  function esDeCircuito(t){ return t[0] === 'circuito' && t.length === 3; }
  /* La escalera la pinta el trámite al abrirse, no applyLang: tras guardar
     uno de sus pasos se vuelve a abrir el trámite que está a la vista, que
     es el único donde ese paso se ha podido pulsar. */
  function repintaTramite(clave){
    var t = trozos(clave);
    if (esDeCircuito(t) && window.CIIP_TRAMITE_REAL &&
        document.body.getAttribute('data-vista') === 'tramite') window.CIIP_TRAMITE_REAL(t[1]);
  }
  function leeBloque(lang, clave){
    var P = window.CIIP_PASOS, t = trozos(clave);
    var v = P && P[t[0]] && P[t[0]][lang];
    for (var i = 1; i < t.length && v != null; i++) v = v[t[i]];
    if (typeof v !== 'string' && P && esDeCircuito(t)){
      v = P.estados && P.estados[lang] && P.estados[lang][t[2]];
    }
    return typeof v === 'string' ? v : undefined;
  }
  function escribeBloque(lang, clave, texto){
    var P = window.CIIP_PASOS, t = trozos(clave);
    if (P && esDeCircuito(t) && P.estados && P.estados[lang]){
      var CI = P.circuito || (P.circuito = {});
      var CL = CI[lang] || (CI[lang] = {});
      if (!CL[t[1]]) CL[t[1]] = P.estados[lang].slice();
    }
    if (!P || !P[t[0]] || P[t[0]][lang] == null) return false;
    if (t.length === 1){ P[t[0]][lang] = texto; return true; }
    var v = P[t[0]][lang];
    for (var i = 1; i < t.length - 1 && v != null; i++) v = v[t[i]];
    if (v == null || typeof v !== 'object') return false;
    v[t[t.length - 1]] = texto;
    return true;
  }

  /* Escribe un cambio (o lo quita, con texto null) donde toca. */
  function pon(lang, clave, texto){
    INDICE = null;     /* lo que dice cada clave ha cambiado: se vuelve a mirar */
    var tipo = tipoDe(clave);
    if (tipo === 'bloque'){
      var OB = ORIG_BLOQ[lang] || (ORIG_BLOQ[lang] = {});
      if (!tiene.call(OB, clave)) OB[clave] = leeBloque(lang, clave);
      /* Solo donde el texto existe: un paso que ese idioma no tiene no se
         inventa. */
      if (OB[clave] !== undefined) escribeBloque(lang, clave, texto == null ? OB[clave] : texto);
    }
    if (tipo === 'dic' || tipo === 'ui'){
      var BASE = tipo === 'dic' ? I18N : uiDe();
      var ORIG = tipo === 'dic' ? ORIG_DIC : ORIG_UI;
      if (!BASE) return;
      var D = BASE[lang] || (BASE[lang] = {});
      var O = ORIG[lang] || (ORIG[lang] = {});
      if (!tiene.call(O, clave)) O[clave] = tiene.call(D, clave) ? D[clave] : undefined;
      if (texto == null){ if (O[clave] === undefined) delete D[clave]; else D[clave] = O[clave]; }
      else D[clave] = texto;
    }
    var C = CAMBIOS[lang] || (CAMBIOS[lang] = {});
    if (texto == null) delete C[clave]; else C[clave] = texto;
  }

  /* El texto de antes de cualquier cambio, en el idioma de turno. */
  function original(clave){
    var tipo = tipoDe(clave);
    if (tipo === 'marca') return ORIG_MARCA[clave] || '';
    if (tipo === 'bloque'){
      var OB = ORIG_BLOQ[curLang] || {};
      var ob = tiene.call(OB, clave) ? OB[clave] : leeBloque(curLang, clave);
      if (ob == null) ob = (ORIG_BLOQ.en && tiene.call(ORIG_BLOQ.en, clave)) ? ORIG_BLOQ.en[clave] : leeBloque('en', clave);
      return ob || '';
    }
    var ORIG = tipo === 'dic' ? ORIG_DIC : ORIG_UI;
    var BASE = (tipo === 'dic' ? I18N : uiDe()) || {};
    function de(l){ var O = ORIG[l] || {}; return tiene.call(O, clave) ? O[clave] : (BASE[l] || {})[clave]; }
    var v = de(curLang);
    return v != null ? v : (de('en') || '');
  }

  /* El texto que se ve ahora mismo, para rellenar el editor. */
  function vigente(clave, el){
    var tipo = tipoDe(clave);
    if (tipo === 'marca') return el ? el.textContent : '';
    if (tipo === 'bloque'){
      var vb = leeBloque(curLang, clave);
      if (vb == null) vb = leeBloque('en', clave);
      return vb != null ? vb : (el ? el.textContent : '');
    }
    var BASE = (tipo === 'dic' ? I18N : uiDe()) || {};
    var v = (BASE[curLang] || {})[clave];
    if (v == null) v = (BASE.en || {})[clave];
    return v == null ? (el ? el.textContent : '') : v;
  }

  /* ── DE QUÉ CLAVE SALE UN TEXTO ──
     «quiero que con el editor de textos se pueda editar todos los textos de
      la pagina» (Franklin Reyes, 16-9-2026).

     Solo se podía pulsar lo que llevaba marca -data-i18n, data-texto,
     data-ui-, y eso eran unos trescientos. El panel pinta por código cerca
     de novecientos textos más -rótulos del formulario, botones, avisos,
     nombres de recaudos- y marcarlos uno a uno era enorme y frágil: cada
     pantalla nueva se olvidaría de la marca.

     Así que se BUSCA: al pulsar un texto, se mira qué claves del idioma en
     pantalla dicen eso. Primero las que lo dicen igual; luego las que
     tienen huecos, como «Hola, {nombre}»; y por último las que van DENTRO
     de lo pulsado, porque el panel pega cosas al lado -«Carta del
     comisario (opcional)»-. Si nada lo dice, es un dato -un nombre, una
     fecha- y no se toca. */
  var INDICE = null;
  function norma(s){
    return String(s == null ? '' : s).replace(/ /g, ' ').replace(/\s+/g, ' ').trim();
  }
  function indice(){
    if (INDICE && INDICE.lang === curLang) return INDICE;
    var filas = [], vistas = {};
    function mete(clave, v){
      if (typeof v !== 'string' || tiene.call(vistas, clave)) return;
      if (!/^[A-Za-z0-9_.-]{1,80}$/.test(clave)) return;   /* no cabría en la tabla */
      var n = norma(v);
      if (!n) return;
      vistas[clave] = true;
      filas.push({clave: clave, texto: n});
    }
    /* El idioma en pantalla, y el inglés para lo que ese idioma no tenga:
       es lo que pinta el panel cuando falta una traducción. */
    var P = window.CIIP_PASOS || {}, U = uiDe();
    [curLang, 'en'].forEach(function(l){
      var D = I18N[l] || {};
      Object.keys(D).forEach(function(k){ mete(k, D[k]); });
      if (U && U[l]) Object.keys(U[l]).forEach(function(k){ mete(k, U[l][k]); });
      BLOQUES.forEach(function(b){
        (function anda(v, clave){
          if (typeof v === 'string') mete(clave, v);
          else if (v && typeof v === 'object') Object.keys(v).forEach(function(k){ anda(v[k], clave + '.' + k); });
        })(P[b] && P[b][l], '_p.' + b);
      });
    });
    INDICE = {lang: curLang, filas: filas, hechas: {}};
    return INDICE;
  }

  var MOLDES = {};
  function molde(v){
    if (tiene.call(MOLDES, v)) return MOLDES[v];
    var partes = v.split(/\{[A-Za-z_]+\}/), re = null;
    /* Un molde que es casi todo hueco -«{n} {unidad}»- casaría con cualquier
       cosa: se exige texto de verdad alrededor. */
    if (partes.length > 1 && partes.join('').replace(/[\s.,:;·()\-–—«»"']/g, '').length >= 4){
      re = new RegExp('^' + partes.map(function(p){
        return p.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      }).join('.+?') + '$');
    }
    return (MOLDES[v] = re);
  }

  function busca(texto){
    var t = norma(texto);
    if (!t) return [];
    var I = indice();
    if (tiene.call(I.hechas, t)) return I.hechas[t];
    var iguales = [], conHuecos = [], dentro = [];
    I.filas.forEach(function(f){
      if (f.texto === t){ iguales.push(f); return; }
      if (f.texto.indexOf('{') >= 0){
        var re = molde(f.texto);
        if (re && re.test(t)){ conHuecos.push(f); return; }
      }
      if (f.texto.length >= 4 && t.indexOf(f.texto) >= 0) dentro.push(f);
    });
    var r;
    if (iguales.length) r = iguales;
    else if (conHuecos.length) r = conHuecos;
    else {
      /* Solo lo que se lleva buena parte de lo pulsado: «de» o «Guardar»
         caben dentro de medio panel y no son lo que se quería cambiar. */
      dentro.sort(function(a, b){ return b.texto.length - a.texto.length; });
      r = dentro.filter(function(f){ return f.texto.length * 2 >= t.length || f.texto.length >= 16; });
    }
    r = r.slice(0, 8);
    I.hechas[t] = r;
    return r;
  }

  /* El texto que lleva un elemento él mismo, sin el de sus hijos: en una
     tarjeta, pulsar el título no es pulsar la tarjeta entera. */
  function propioDe(el){
    if (!el || !el.childNodes) return '';
    if (el.matches && el.matches('input, textarea') && el.placeholder) return norma(el.placeholder);
    if (el.tagName === 'SELECT' && el.selectedIndex >= 0) return norma(el.options[el.selectedIndex].text);
    var s = '';
    for (var i = 0; i < el.childNodes.length; i++){
      if (el.childNodes[i].nodeType === 3) s += el.childNodes[i].textContent;
    }
    s = norma(s);
    if (!s && !el.children.length) s = norma(el.textContent);
    return s;
  }

  /* Lo pulsado: el trozo de texto exacto bajo el ratón, si el navegador lo
     sabe decir; si no, el texto propio del elemento. */
  function textoBajo(e, t){
    var nodo = null;
    try {
      if (document.caretRangeFromPoint){
        var rg = document.caretRangeFromPoint(e.clientX, e.clientY);
        nodo = rg && rg.startContainer;
      } else if (document.caretPositionFromPoint){
        var ps = document.caretPositionFromPoint(e.clientX, e.clientY);
        nodo = ps && ps.offsetNode;
      }
    } catch (err){ nodo = null; }
    if (nodo && nodo.nodeType === 3 && t.contains(nodo) && norma(nodo.textContent)){
      return {nodo: nodo, texto: nodo.textContent};
    }
    return {nodo: null, texto: propioDe(t)};
  }

  /* Si lo guardado no se repinta solo -un formulario a medio rellenar no se
     vuelve a construir, que perdería lo escrito-, se cambia en su sitio.
     Lo que lleva huecos no: el texto en pantalla ya no es el del molde. */
  function aMano(nodo, viejo, nuevo){
    if (!nodo || !document.contains(nodo) || !viejo || viejo === nuevo || viejo.indexOf('{') >= 0) return;
    var t = nodo.textContent, i = t.indexOf(viejo);
    if (i >= 0) nodo.textContent = t.slice(0, i) + nuevo + t.slice(i + viejo.length);
  }

  /* Mientras se edita, lo que se puede cambiar se marca al pasar por encima.
     Lo que ya lleva marca va marcado por el CSS de siempre. */
  var SOBRE = null;
  function marcaSobre(el){
    if (SOBRE === el) return;
    if (SOBRE) SOBRE.classList.remove('tx-sobre');
    SOBRE = el;
    if (el) el.classList.add('tx-sobre');
  }
  document.addEventListener('mouseover', function(e){
    if (!editando) return;
    var t = e.target;
    if (!t || !t.closest || t.closest('.tx-editor, .tx-banda, #langMenu, #langBtn, #navTextos') ||
        t.closest('[data-i18n],[data-texto],[data-ui]')){ marcaSobre(null); return; }
    var propio = propioDe(t);
    marcaSobre(propio && busca(propio).length ? t : null);
  }, true);

  /* Lo del marcado. Lo llama applyLang al final, en cada cambio de idioma. */
  function pintaMarca(){
    var C = CAMBIOS[curLang] || {};
    document.querySelectorAll('[data-texto]').forEach(function(el){
      var k = el.getAttribute('data-texto');
      if (!tiene.call(ORIG_MARCA, k)) ORIG_MARCA[k] = el.textContent;
      el.textContent = tiene.call(C, k) ? C[k] : ORIG_MARCA[k];
    });
    marcaCambiados();
    if (editando){ rotulaBanda(); if (actual) cierra(); }
  }
  window.CIIP_APLICA_TEXTOS = pintaMarca;

  function marcaCambiados(){
    var C = CAMBIOS[curLang] || {};
    document.querySelectorAll('[data-i18n],[data-texto],[data-ui]').forEach(function(el){
      el.classList.toggle('tx-cambiado', editando && tiene.call(C, claveDe(el)));
    });
  }

  function repinta(){
    if (window.CIIP_OLVIDA_T) window.CIIP_OLVIDA_T();
    if (typeof applyLang === 'function') applyLang(curLang);   /* acaba en pintaMarca */
    else pintaMarca();
  }

  /* ── Al entrar: lo cambiado, de la base ──
     Con la sesion puesta, igual que el catalogo: una consulta adelantada a
     la sesion vuelve vacia y sin error. Sin la tabla, se avisa en la consola
     y el panel sigue con su diccionario. */
  function carga(){
    var sb = cliente();
    if (!sb || !sb.auth) return;
    sb.auth.getSession().then(function(r0){
      if (!(r0 && r0.data && r0.data.session)) return;
      sb.from('textos_panel').select('clave, idioma, texto').then(function(r){
        if (!r || r.error){
          if (r && r.error) console.warn('[CIIP] textos editables: ' + r.error.message + ' (¿falta correr supabase-textos.sql?)');
          return;
        }
        var filas = r.data || [];
        filas.forEach(function(f){
          if (f && f.texto && IDIOMAS.indexOf(f.idioma) >= 0) pon(f.idioma, f.clave, f.texto);
        });
        if (filas.length) repinta();
      });
    }).catch(function(e){ console.warn('[CIIP] textos editables:', e && e.message); });
  }

  /* ── El modo de edicion ── */
  var banda, editor, campo, lista, msg, bGuardar, bVolver, bCancelar, bTerminar;

  function construye(){
    if (banda) return;
    banda = document.createElement('div');
    banda.className = 'tx-banda';
    banda.hidden = true;
    banda.setAttribute('role', 'status');
    banda.innerHTML = '<span class="tx-banda-t"></span><span class="tx-banda-msg"></span>' +
                      '<button type="button" class="tx-btn tx-terminar" id="txTerminar"></button>';
    document.body.appendChild(banda);
    bTerminar = banda.querySelector('#txTerminar');
    bTerminar.addEventListener('click', function(){ alterna(false); });

    editor = document.createElement('div');
    editor.className = 'tx-editor';
    editor.hidden = true;
    editor.setAttribute('role', 'dialog');
    editor.setAttribute('aria-labelledby', 'txTitulo');
    editor.innerHTML =
      '<div class="tx-t" id="txTitulo"></div>' +
      '<div class="tx-clave" id="txClave"></div>' +
      '<div class="tx-lista" id="txLista" hidden></div>' +
      '<textarea id="txCampo" rows="3" aria-labelledby="txTitulo"></textarea>' +
      '<div class="tx-nota" id="txNota"></div>' +
      '<div class="tx-orig" id="txOrig" hidden><b></b> <span></span></div>' +
      '<div class="tx-msg" id="txMsg" role="status"></div>' +
      '<div class="tx-botones">' +
        '<button type="button" class="tx-btn" id="txVolver"></button>' +
        '<button type="button" class="tx-btn" id="txCancelar"></button>' +
        '<button type="button" class="tx-btn prim" id="txGuardar"></button>' +
      '</div>';
    document.body.appendChild(editor);
    campo = editor.querySelector('#txCampo');
    lista = editor.querySelector('#txLista');
    msg = editor.querySelector('#txMsg');
    bGuardar = editor.querySelector('#txGuardar');
    bVolver = editor.querySelector('#txVolver');
    bCancelar = editor.querySelector('#txCancelar');
    bGuardar.addEventListener('click', guarda);
    bVolver.addEventListener('click', vuelve);
    bCancelar.addEventListener('click', cierra);
    editor.addEventListener('keydown', function(e){
      if (e.key === 'Escape'){ e.preventDefault(); e.stopPropagation(); cierra(); }
      if (e.key === 'Enter' && (e.ctrlKey || e.metaKey)){ e.preventDefault(); guarda(); }
    });
  }

  function rotulaBanda(){
    if (!banda) return;
    banda.querySelector('.tx-banda-t').textContent = (dic()['tx.banda'] || I18N.en['tx.banda'] || '').replace('{idioma}', nombreIdioma());
    bTerminar.textContent = (dic()['tx.terminar'] || I18N.en['tx.terminar'] || '');
  }
  function avisaBanda(t){
    if (!banda) return;
    var m = banda.querySelector('.tx-banda-msg');
    m.textContent = t || '';
    clearTimeout(avisaBanda.reloj);
    if (t) avisaBanda.reloj = setTimeout(function(){ m.textContent = ''; }, 4000);
  }

  function alterna(on){
    if (on && !esAdminAhora()) return;
    editando = !!on;
    construye();
    document.body.classList.toggle('editando-textos', editando);
    var b = document.getElementById('navTextos');
    if (b) b.setAttribute('aria-pressed', editando ? 'true' : 'false');
    banda.hidden = !editando;
    if (editando) rotulaBanda(); else { cierra(); avisaBanda(''); marcaSobre(null); }
    marcaCambiados();
  }

  function abre(el, claveDada, nodo){
    construye();
    var clave = claveDada || claveDe(el);
    actual = {el: el, clave: clave, nodo: nodo || null};
    /* Si venía de elegir entre varias claves, vuelve a ser el editor. */
    lista.hidden = true;
    campo.hidden = false;
    bGuardar.hidden = false;
    var cambiado = tiene.call(CAMBIOS[curLang] || {}, clave);
    var orig = original(clave);
    editor.querySelector('#txTitulo').textContent = (dic()['tx.titulo'] || I18N.en['tx.titulo'] || '');
    editor.querySelector('#txClave').textContent = clave + ' · ' + curLang;
    campo.value = vigente(clave, el);
    var nota = (dic()['tx.solo'] || I18N.en['tx.solo'] || '').replace('{idioma}', nombreIdioma());
    if (/\{[a-z]+\}/.test(orig)) nota += ' ' + (dic()['tx.llaves'] || I18N.en['tx.llaves'] || '');
    editor.querySelector('#txNota').textContent = nota;
    var caja = editor.querySelector('#txOrig');
    caja.hidden = !cambiado;
    caja.querySelector('b').textContent = (dic()['tx.original'] || I18N.en['tx.original'] || '');
    caja.querySelector('span').textContent = orig;
    bGuardar.textContent = (dic()['tx.guardar'] || I18N.en['tx.guardar'] || '');
    bVolver.textContent = (dic()['tx.volver'] || I18N.en['tx.volver'] || '');
    bVolver.hidden = !cambiado;
    bCancelar.textContent = (dic()['tx.cancelar'] || I18N.en['tx.cancelar'] || '');
    ponMsg('', false);
    ocupado(false);
    editor.hidden = false;
    coloca(el);
    campo.focus();
    campo.select();
  }

  /* Cuando lo pulsado sale de más de una clave -«Guardar» es el botón del
     perfil y el de la empresa-, no se adivina: se enseñan las que lo dicen,
     con su clave debajo, y se elige. Cambiar la que no era cambiaría otra
     pantalla sin que nadie lo viera. */
  function elige(el, candidatas, nodo){
    construye();
    actual = null;
    editor.querySelector('#txTitulo').textContent = (dic()['tx.elige'] || I18N.en['tx.elige'] || '');
    editor.querySelector('#txClave').textContent = '';
    editor.querySelector('#txNota').textContent = '';
    editor.querySelector('#txOrig').hidden = true;
    campo.hidden = true;
    bGuardar.hidden = true;
    bVolver.hidden = true;
    bCancelar.textContent = (dic()['tx.cancelar'] || I18N.en['tx.cancelar'] || '');
    ponMsg('', false);
    lista.textContent = '';
    candidatas.forEach(function(c){
      var b = document.createElement('button');
      b.type = 'button';
      b.className = 'tx-opcion';
      var t1 = document.createElement('span');
      t1.textContent = c.texto;
      var t2 = document.createElement('small');
      t2.textContent = c.clave;
      b.appendChild(t1);
      b.appendChild(t2);
      b.addEventListener('click', function(){ abre(el, c.clave, nodo); });
      lista.appendChild(b);
    });
    lista.hidden = false;
    editor.hidden = false;
    coloca(el);
    var primero = lista.querySelector('button');
    if (primero) primero.focus();
  }

  /* Debajo del texto, y encima si abajo no cabe. Nunca fuera de la ventana. */
  function coloca(el){
    var r = el.getBoundingClientRect();
    var w = editor.offsetWidth, hgt = editor.offsetHeight, m = 16;
    var top = r.bottom + 8;
    if (top + hgt > window.innerHeight - m) top = r.top - hgt - 8;
    top = Math.max(m, Math.min(top, window.innerHeight - hgt - m));
    var left = Math.max(m, Math.min(r.left, window.innerWidth - w - m));
    editor.style.top = top + 'px';
    editor.style.left = left + 'px';
  }

  function cierra(){
    if (editor) editor.hidden = true;
    var el = actual && actual.el;
    actual = null;
    if (el && el.focus && document.contains(el)) { try { el.focus({preventScroll: true}); } catch(e){} }
  }

  function ponMsg(t, espera){ msg.textContent = t || ''; msg.classList.toggle('espera', !!espera); }
  function ocupado(si){ bGuardar.disabled = si; bVolver.disabled = si; }

  function guarda(){
    if (!actual) return;
    var texto = campo.value.trim();
    if (!texto){ ponMsg((dic()['tx.vacio'] || I18N.en['tx.vacio'] || ''), false); campo.focus(); return; }
    var sb = cliente();
    if (!sb){ ponMsg((dic()['tx.nopudo'] || I18N.en['tx.nopudo'] || ''), false); return; }
    var lang = curLang, clave = actual.clave;
    var nodoVivo = actual.nodo, viejo = vigente(clave, actual.el);
    ocupado(true);
    ponMsg((dic()['tx.guardando'] || I18N.en['tx.guardando'] || ''), true);
    /* Con lo que decía antes, para que Trazabilidad pueda contarlo. Si la
       base aún no tiene esa columna -supabase-textos-rastro.sql sin correr-
       se guarda sin ella: el cambio importa más que su apunte. */
    var fila = {clave: clave, idioma: lang, texto: texto,
                original: String(original(clave) || '').slice(0, 1000)};
    function manda(f){
      return sb.from('textos_panel').upsert(f, {onConflict: 'clave,idioma'}).select('clave');
    }
    manda(fila)
      .then(function(r){
        if (r && r.error && /original/i.test(r.error.message || '')){
          delete fila.original;
          return manda(fila);
        }
        return r;
      })
      .then(function(r){
        ocupado(false);
        /* Cero filas sin error es la politica diciendo que no: quien no es
           admin no escribe, y Supabase no lo cuenta como fallo. */
        if (!r || r.error || !(r.data && r.data.length)){
          if (r && r.error) console.warn('[CIIP] textos editables, guardar:', r.error.message);
          ponMsg((dic()['tx.nopudo'] || I18N.en['tx.nopudo'] || ''), false);
          return;
        }
        pon(lang, clave, texto);
        cierra();
        repinta();
        aMano(nodoVivo, viejo, texto);
        repintaTramite(clave);
        avisaBanda((dic()['tx.guardado'] || I18N.en['tx.guardado'] || ''));
      }, function(){ ocupado(false); ponMsg((dic()['tx.nopudo'] || I18N.en['tx.nopudo'] || ''), false); });
  }

  function vuelve(){
    if (!actual) return;
    var sb = cliente();
    if (!sb){ ponMsg((dic()['tx.nopudo'] || I18N.en['tx.nopudo'] || ''), false); return; }
    var lang = curLang, clave = actual.clave;
    var nodoVivo = actual.nodo, elVivo = actual.el, viejo = vigente(clave, actual.el);
    ocupado(true);
    ponMsg((dic()['tx.guardando'] || I18N.en['tx.guardando'] || ''), true);
    sb.from('textos_panel').delete().eq('clave', clave).eq('idioma', lang).select('clave')
      .then(function(r){
        ocupado(false);
        if (!r || r.error || !(r.data && r.data.length)){
          if (r && r.error) console.warn('[CIIP] textos editables, volver al original:', r.error.message);
          ponMsg((dic()['tx.nopudo'] || I18N.en['tx.nopudo'] || ''), false);
          return;
        }
        pon(lang, clave, null);
        var vuelto = vigente(clave, elVivo);
        cierra();
        repinta();
        aMano(nodoVivo, viejo, vuelto);
        repintaTramite(clave);
        avisaBanda((dic()['tx.restaurado'] || I18N.en['tx.restaurado'] || ''));
      }, function(){ ocupado(false); ponMsg((dic()['tx.nopudo'] || I18N.en['tx.nopudo'] || ''), false); });
  }

  /* El clic sobre un texto, mientras se edita, abre el editor y NO hace lo
     que haria normalmente (abrir la ficha, cambiar de vista). Se escucha en
     la fase de captura para llegar antes que los botones y las tarjetas.
     Un clic fuera de un texto sigue funcionando: asi se puede ir a otra
     pantalla sin salir del modo. */
  document.addEventListener('click', function(e){
    if (!editando) return;
    var t = e.target;
    if (!t || !t.closest) return;
    if (t.closest('.tx-editor, .tx-banda, #navTextos, #langMenu, #langBtn')) return;
    var marcado = t.closest('[data-i18n],[data-texto],[data-ui]');
    if (marcado){
      e.preventDefault();
      e.stopPropagation();
      if (e.stopImmediatePropagation) e.stopImmediatePropagation();
      abre(marcado, claveDe(marcado), null);
      return;
    }
    /* Sin marca, se busca de qué clave sale. Si no sale de ninguna es un
       dato: se dice, y el clic sigue su camino -puede ser el enlace a otra
       pantalla, y en el modo de edición también hay que poder moverse-. */
    var hallado = textoBajo(e, t);
    var candidatas = busca(hallado.texto);
    if (!candidatas.length){
      if (norma(hallado.texto)) avisaBanda(dic()['tx.nodic'] || I18N.en['tx.nodic'] || '');
      return;
    }
    e.preventDefault();
    e.stopPropagation();
    if (e.stopImmediatePropagation) e.stopImmediatePropagation();
    var donde = (hallado.nodo && hallado.nodo.parentElement) || t;
    if (candidatas.length === 1) abre(donde, candidatas[0].clave, hallado.nodo);
    else elige(donde, candidatas, hallado.nodo);
  }, true);

  window.addEventListener('resize', function(){ if (actual && editor && !editor.hidden) coloca(actual.el); });

  var boton = document.getElementById('navTextos');
  if (boton) boton.addEventListener('click', function(){ alterna(!editando); });

  window.CIIP_TEXTOS = {alterna: alterna, carga: carga, cambios: function(){ return CAMBIOS; },
                        busca: busca, pon: pon};
  carga();
})();
