/* ══════════════════════════════════════════════════════════════════════
   ARNÉS DE PRUEBAS DEL PANEL
   ══════════════════════════════════════════════════════════════════════
   Lo inyecta panel.ps1 al final de una copia temporal del panel, junto a
   supabase-mentira.js. El panel de verdad NUNCA los carga.

   Prueba lo que la portada dice de tus trámites:

       el camino     que los contadores y las barras salen de las tarjetas
       las cajas     que las cuatro etapas son cuatro cajas parejas
       la franja     que anuncia lo que de verdad te toca, o se calla
       el buzón      que la campana enseña el historial y lleva a él
       la sesión     que el panel te llama a TI y no a la demostración
       el perfil     que puedes completar tu nombre y tu país, y que se ven
       las citas     que se piden, que solo hay una a la vez, y que se anulan
       la cola       que el equipo del CIIP las ve y les pone fecha, y que
                     al inversionista no se le ofrece siquiera

   Se corre TRES veces, con expedientes distintos (?caso=lleno, ?caso=vacio
   y ?caso=sinnombre): la mitad de lo que hay que comprobar es que el panel
   se calla cuando no hay nada, y eso no se puede ver en la misma pasada que
   comprueba que habla cuando lo hay.

   Todo se mide en español, y hay una prueba aparte para el cambio de
   idioma: fijar el idioma evita que la prueba dependa de lo que el
   navegador dejara guardado la última vez.
   ══════════════════════════════════════════════════════════════════════ */
(function(){

  var R = [];
  var CASO = (location.search.match(/caso=(\w+)/) || [])[1] || 'lleno';

  function ok(nombre, bien, got, exp){
    R.push({n:nombre, ok:!!bien, got:String(got), exp:String(exp)});
  }
  function igual(nombre, got, exp){ ok(nombre, got === exp, got, exp); }

  function etapas(){ return document.querySelectorAll('.jp[data-ir]'); }
  function deEtapa(i, sel){
    var e = etapas()[i];
    if (!e) return '(no hay etapa ' + i + ')';
    var x = e.querySelector(sel);
    return x ? x.textContent.trim() : '(no hay ' + sel + ')';
  }
  function franja(){ return document.getElementById('teToca'); }
  function enFranja(sel){
    var f = franja(); if (!f) return '(no hay franja)';
    var x = f.querySelector(sel); return x ? x.textContent.trim() : '';
  }
  function avisos(){ return document.querySelectorAll('#avisosLista .av-i'); }

  function volcar(){
    var pre = document.createElement('pre');
    pre.id = 'RESULTADOS';
    pre.textContent = '###' + JSON.stringify(R) + '###';
    document.body.appendChild(pre);
  }

  /* La portada habla con la base al cargar, así que no se puede medir
     nada hasta que conteste. Se espera a que el buzón esté pintado —lleve
     avisos o lleve el texto de "no hay nada"— y no a un reloj fijo: un
     reloj corto deja pruebas rojas al azar en una máquina lenta, y uno
     largo hace esperar de balde siempre. */
  function cuandoConteste(sigue){
    var intentos = 0;
    (function mira(){
      var lista = document.getElementById('avisosLista');
      if ((lista && lista.children.length) || ++intentos > 120) {
        setTimeout(sigue, 200);   /* un respiro para lo que venga detrás */
        return;
      }
      setTimeout(mira, 50);
    })();
  }

  /* Varias pruebas terminan pidiéndole algo a la base —guardar el perfil,
     pedir una cita, cancelarla— y lo que hay que medir llega después. Cada
     paso corre, se le deja medio segundo para que conteste, y sigue el
     siguiente. Es lo mismo que hacía el par pruebas()/trasGuardar(), pero
     sin que cada trato nuevo con la base añada otro setTimeout anidado. */
  function enCadena(pasos, alFinal){
    var i = 0;
    (function siguiente(){
      if (i >= pasos.length) return alFinal();
      var paso = pasos[i++];
      try { paso(); } catch(e){
        ok('el arnés llegó al final', false, 'EXCEPCION en el paso ' + i + ': ' + e.message, 'sin excepciones');
      }
      setTimeout(siguiente, 500);
    })();
  }

  cuandoConteste(function(){
    enCadena([pruebas, trasGuardar, citasAbre, citasPide, citasTrasPedir, citasAnula, citasTrasAnular,
              colaAbre, colaConfirma, colaTrasConfirmar,
              agendaMira, agendaTrasEntrar, agendaTrasSalir], volcar);
  });

  function pruebas(){

    applyLang('es');

    /* ═══════════ EL CAMINO: LOS CONTADORES SALEN DE LAS TARJETAS ═══════════
       Los cuatro renglones estaban escritos a mano para las 15 tarjetas de
       antes. Ahora se cuentan, y estas cuatro pruebas son lo que impide que
       vuelvan a quedarse atrás cuando el catálogo crezca. */
    igual('camino: la fase 01 cuenta sus 10 trámites', deEtapa(0, '.jcount'), '3 de 10 listos');
    igual('camino: la fase 02 cuenta sus 7',           deEtapa(1, '.jcount'), '0 de 7 listos');
    igual('camino: la fase 03 cuenta sus 4',           deEtapa(2, '.jcount'), '0 de 4 listos');
    igual('camino: la fase 04 cuenta sus 3',           deEtapa(3, '.jcount'), '0 de 3 listos');

    (function(){
      var barra = etapas()[0].querySelector('.jbar > span');
      igual('camino: la barra de la fase 01 mide lo hecho', barra.style.width, '30%');
    })();

    /* La palomita estaba escrita en el marcado y se quedaba en verde con
       trámites sin hacer. Una etapa solo termina si TODOS los suyos están. */
    (function(){
      var e = etapas()[0];
      var num = e.querySelector('.num').textContent.trim();
      ok('camino: la fase 01 no se da por terminada',
         !e.classList.contains('done') && num === '1',
         'done=' + e.classList.contains('done') + ' num=' + num, 'done=false num=1');
    })();

    igual('camino: los filtros cuentan las 24 tarjetas',
          (document.querySelector('.ftab[data-f="todos"] .n') || {}).textContent, '24');

    /* El renglón ya no lleva data-i18n: lo compone el mismo bloque que lo
       cuenta, así que el cambio de idioma tiene que alcanzarlo aparte. */
    (function(){
      applyLang('en');
      var en = deEtapa(0, '.jcount');
      applyLang('es');
      var es = deEtapa(0, '.jcount');
      ok('camino: el renglón se traduce', en === '3 of 10 done' && es === '3 de 10 listos',
         'en="' + en + '" es="' + es + '"', 'en="3 of 10 done" es="3 de 10 listos"');
    })();

    /* ═══════════ EL CAMINO: CÓMO SE LLAMAN LAS ETAPAS ═══════════
       El cintillo "FASE 01" repetía en letra lo que el punto dice en número,
       justo encima y en el mismo golpe de vista. */
    (function(){
      ok('camino: la etapa no repite su número en letra',
         document.querySelectorAll('.jp .jeye').length === 0,
         document.querySelectorAll('.jp .jeye').length + ' cintillos', '0');

      /* Pero el orden no puede perderse: lo llevan los puntos. */
      var puntos = [];
      etapas().forEach(function(e){ puntos.push(e.querySelector('.num').textContent.trim()); });
      igual('camino: y el punto sigue numándolas', puntos.join(''), '1234');

      var nombres = [];
      etapas().forEach(function(e){ nombres.push(e.querySelector('.jname').textContent.trim()); });
      igual('camino: los cuatro nombres son verbos del mismo tipo',
            nombres.join(' → '), 'Llegar → Constituir → Operar → Crecer');

      /* En el ÍNDICE de abajo hace falta algo que ponga las cuatro en orden,
         pero no la palabra: el mismo punto numerado que usa el camino. */
      /* Los números, centrados de verdad dentro de su punto. Centrar la caja
         de línea no centra el trazo: una cifra se apoya en la línea base y deja
         vacío el hueco de las colas que no tiene. Se mide la TINTA. */
      (function(){
        function desvio(el){
          var caja = el.getBoundingClientRect();
          var cs = window.getComputedStyle(el);
          var r = document.createRange(); r.selectNodeContents(el);
          var linea = r.getBoundingClientRect();
          var cv = document.createElement('canvas').getContext('2d');
          cv.font = cs.fontWeight + ' ' + cs.fontSize + ' ' + cs.fontFamily;
          var m = cv.measureText(el.textContent.trim());
          var medioHueco = (linea.height - (m.fontBoundingBoxAscent + m.fontBoundingBoxDescent)) / 2;
          var base = linea.top + medioHueco + m.fontBoundingBoxAscent;
          var centroTinta = ((base - m.actualBoundingBoxAscent) + (base + m.actualBoundingBoxDescent)) / 2;
          return centroTinta - (caja.top + caja.height / 2);
        }
        var peor = 0, donde = '';
        document.querySelectorAll('.jp .num, .phase-h .pn, .faq-item .qi').forEach(function(e){
          var d = Math.abs(desvio(e));
          if (d > peor){ peor = d; donde = (e.className || '') + ' "' + e.textContent.trim() + '"'; }
        });
        ok('números: el trazo va centrado en su punto, no solo la caja',
           peor <= 0.5, 'el peor se desvía ' + peor.toFixed(2) + 'px (' + donde + ')',
           'medio píxel o menos');
      })();

      /* Las cuatro cifras tienen que ocupar el mismo ancho: si no, en columna
         se leen torcidas aunque cada una esté centrada en su caja. */
      (function(){
        var anchos = [];
        document.querySelectorAll('.phase-h .pn').forEach(function(e){
          anchos.push(window.getComputedStyle(e).fontVariantNumeric);
        });
        ok('números: las cifras van en tabular, para que midan igual',
           anchos.every(function(a){ return a.indexOf('tabular-nums') >= 0; }),
           anchos.join(', '), 'tabular-nums en las cuatro');
      })();

      var pns = [];
      document.querySelectorAll('.phase-h .pn').forEach(function(p){ pns.push(p.textContent.trim()); });
      igual('fases: el índice numera con puntos, no con la palabra', pns.join(''), '1234');

      /* Y en ningún sitio de la portada vuelve a aparecer "Fase". */
      var conFase = [];
      document.querySelectorAll('.journey, #secTramites').forEach(function(z){
        if (/fase/i.test(z.textContent)) conFase.push(z.className || z.id);
      });
      ok('fases: la palabra "Fase" ya no sale en el camino ni en el índice',
         conFase.length === 0, conFase.join(', ') || 'en ninguno', 'en ninguno');
    })();

    /* ═══════════ EL CAMINO: CUATRO CAJAS, NO UNA BANDA ═══════════ */
    (function(){
      var e = etapas()[0];
      var s = window.getComputedStyle(e);
      ok('cajas: cada etapa tiene su propio borde', s.borderTopWidth === '1px',
         'borde=' + s.borderTopWidth, '1px');
    })();

    (function(){
      var altos = [];
      etapas().forEach(function(e){ altos.push(e.offsetHeight); });
      var parejas = altos.every(function(a){ return a === altos[0]; });
      ok('cajas: las cuatro miden lo mismo de alto', parejas, altos.join(' / '), 'todas iguales');
    })();

    /* Separadas las cuatro, el punto azul solo no bastaba para encontrar la
       etapa en curso: se marca también el borde de su caja. */
    (function(){
      var activa = document.querySelector('.jp.active');
      var otra   = document.querySelector('.jp[data-ir]:not(.active)');
      var ca = activa ? window.getComputedStyle(activa).borderTopColor : '';
      var co = otra   ? window.getComputedStyle(otra).borderTopColor   : '';
      ok('cajas: la etapa en curso se distingue por el borde', !!ca && ca !== co,
         'activa=' + ca + ' otra=' + co, 'colores distintos');
    })();

    /* La bandera del selector de idioma llevaba el mismo emoji, y el botón
       decía "ES ES": la bandera convertida en dos letras al lado del código. */
    (function(){
      applyLang('es');
      var b = document.getElementById('langFlag');
      ok('idioma: la bandera del botón es una imagen, no un emoji',
         !!b && b.tagName === 'IMG' && /banderas\/es\.svg$/.test(b.getAttribute('src') || ''),
         b ? (b.tagName + ' ' + (b.getAttribute('src') || b.textContent)) : 'no existe',
         'IMG a banderas/es.svg');
      applyLang('ru');
      ok('idioma: y cambia al cambiar de idioma',
         /banderas\/ru\.svg$/.test(b.getAttribute('src') || ''),
         b.getAttribute('src'), 'banderas/ru.svg');
      applyLang('es');
    })();

    /* ═══════════ LAS PREGUNTAS FRECUENTES ═══════════
       Se pliegan bajo su cabecera, igual que los trámites de cada fase. Se
       probó antes con una caja de alto fijo y barra propia: se recorría por
       dentro, pero gastaba su alto siempre y metía una segunda barra dentro
       de la página, que nadie espera en una portada. */
    (function(){
      var secF = document.querySelector('.faq-sec');
      var cabF = secF && secF.querySelector('.faq-h');
      var lisF = secF && secF.querySelector('.faq');
      if (!secF || !cabF || !lisF){
        ok('preguntas: la sección se pliega', false, 'falta .faq-sec o su cabecera', 'las tres piezas');
        return;
      }

      ok('preguntas: arranca plegada, que la portada es el índice',
         secF.classList.contains('plegada') && lisF.offsetHeight === 0,
         'plegada=' + secF.classList.contains('plegada') + ' alto=' + lisF.offsetHeight,
         'plegada y sin alto');

      igual('preguntas: y sin barra de desplazamiento propia',
            window.getComputedStyle(lisF).overflowY, 'visible');

      cabF.click();
      ok('preguntas: al pulsar la cabecera se despliegan',
         !secF.classList.contains('plegada') && lisF.offsetHeight > 100,
         'plegada=' + secF.classList.contains('plegada') + ' alto=' + lisF.offsetHeight,
         'desplegada y con alto');
      igual('preguntas: y lo dice para quien no la ve',
            cabF.getAttribute('aria-expanded'), 'true');
      igual('preguntas: hay siete', lisF.querySelectorAll('details').length, 7);

      /* Al cerrar se cierran también las respuestas abiertas: si no, al
         volver a desplegar aparecerían sueltas sin que nadie las pidiera. */
      lisF.querySelectorAll('details')[2].open = true;
      cabF.click();
      cabF.click();
      igual('preguntas: al plegarla se cierran las respuestas que quedaran abiertas',
            lisF.querySelectorAll('details[open]').length, 0);
      cabF.click();   /* se deja como estaba */
    })();

    /* ═══════════ QUIÉN DICE EL PANEL QUE ERES ═══════════
       El panel nace con el nombre de una persona inventada, que es lo que se
       enseña mientras no hay sesión. En cuanto la hay, ese nombre NO puede
       seguir en pantalla: llamarte por el nombre de otro hace dudar de en
       qué cuenta has entrado. */
    (function(){
      var enPantalla = (document.querySelector('.u-name') || {}).textContent || '';
      var avatar     = (document.querySelector('.avatar') || {}).textContent || '';

      ok('sesión: nunca se queda el nombre de la demostración',
         enPantalla.trim() !== 'Marco Bianchi', enPantalla.trim(), 'cualquier cosa menos Marco Bianchi');

      /* El aviso de que parte del panel sigue siendo maqueta. Se enciende con
         la sesión, y tiene que seguir encendido mientras las 24 tarjetas
         lleven el estado escrito a mano. Es lo único que impide que alguien
         se crea las cifras de la cabecera. */
      (function(){
        var d = document.getElementById('avisoDemo');
        ok('sesión: el aviso de datos de ejemplo sigue a la vista',
           !!d && d.classList.contains('show'),
           d ? d.className : '(no existe)', 'con la clase show');
        /* Y ya no puede decir que TUS solicitudes son de ejemplo: el buzón y
           la franja salen de la base. */
        ok('sesión: el aviso no desmiente lo que sí es de verdad',
           !!d && d.textContent.indexOf('tus solicitudes son reales') >= 0,
           d ? d.textContent.trim() : '(no existe)', 'nombra tus solicitudes como reales');
      })();

      /* El país va pegado al rol: "{rol} · {pais}". Sin país en el
         expediente no puede salir el de la demostración, ni quedarse la raya
         suelta al final. */
      (function(){
        var sub = (document.querySelector('.u-sub') || {}).textContent || '';
        sub = sub.trim();
        if (CASO === 'sinnombre'){
          igual('sesión: sin país, solo el rol y sin raya suelta', sub, 'Inversionista');
          ok('sesión: sin país, nunca el de la demostración',
             sub.indexOf('Italia') < 0, sub, 'sin Italia');
        } else {
          /* En el expediente del equipo el rol no es el mismo, y la prueba no
             puede darlo por hecho: diría que hay un fallo donde hay un gestor. */
          igual('sesión: el rol y el país de tu expediente', sub,
                (CASO === 'gestor' ? 'Equipo CIIP' : 'Inversionista') + ' · Italia');
        }
      })();

      if (CASO === 'sinnombre'){
        /* Sin nombre en el expediente ni en los metadatos, se saca del
           correo f.reyes@ciip.com.ve. La inicial suelta lleva punto. */
        igual('sesión: sin nombre, uno sacado del correo', enPantalla.trim(), 'F. Reyes');
        igual('sesión: y las iniciales acompañan',           avatar.trim(),     'FR');
      } else {
        igual('sesión: el panel te llama por tu nombre', enPantalla.trim(), 'Franklin Reyes');
        igual('sesión: el avatar lleva tus iniciales',   avatar.trim(),     'FR');
      }
    })();

    /* ═══════════ LA FRANJA DE "TE TOCA A TI" ═══════════ */
    if (CASO === 'lleno'){
      ok('franja: sale cuando hay una solicitud devuelta',
         franja().classList.contains('puesta'), franja().className, 'con la clase puesta');

      /* El borrador del expediente es MÁS RECIENTE que la devolución. Si la
         franja cogiera sin más lo último movido, aquí diría "Constitución". */
      igual('franja: antepone la devolución al borrador más reciente',
            enFranja('.ns-t'), 'RIF de la empresa');
      igual('franja: avisa de que requiere tu acción',
            enFranja('.ns-k'), 'Requiere tu acción');
      igual('franja: enseña la nota que escribió el gestor',
            enFranja('.ns-d'), 'El comprobante del capital esta ilegible: vuelve a subirlo escaneado.');

      /* La nota es del gestor, no del diccionario: no se traduce. */
      (function(){
        applyLang('ru');
        var nota = enFranja('.ns-d');
        var titular = enFranja('.ns-k');
        applyLang('es');
        ok('franja: se traduce, pero la nota del gestor no',
           nota === 'El comprobante del capital esta ilegible: vuelve a subirlo escaneado.' &&
           titular !== 'Requiere tu acción' && titular.length > 0,
           'nota="' + nota + '" titular ru="' + titular + '"',
           'la nota intacta y el titular en ruso');
      })();
    }

    if (CASO === 'vacio'){
      ok('franja: sin nada pendiente, no se enseña',
         !franja().classList.contains('puesta'), franja().className, 'sin la clase puesta');
      igual('franja: y no deja textos sueltos del marcado', enFranja('.ns-t'), '');
    }

    /* ═══════════ EL BUZÓN DE AVISOS ═══════════ */
    var campana = document.getElementById('avisosBtn');
    var buzon   = document.getElementById('avisosMenu');
    var cuenta  = document.getElementById('avisosN');

    if (CASO === 'lleno'){
      /* El historial trae cinco eventos; dos son de creación del borrador. */
      /* Tres del historial de trámites y uno de la cita confirmada. */
      igual('buzón: cuenta los avisos sin abrirlo', cuenta.textContent, '4');
      ok('buzón: el contador se ve', !cuenta.hidden, 'oculto=' + cuenta.hidden, 'oculto=false');

      campana.click();
      ok('buzón: se abre al pulsar la campana', buzon.classList.contains('open'),
         buzon.className, 'con la clase open');

      igual('buzón: no anuncia la creación del borrador', avisos().length, 4);

      (function(){
        var primero = avisos()[0];
        var t = primero.querySelector('.av-t').textContent.trim();
        var q = primero.querySelector('.av-q').textContent.trim();
        var nota = primero.querySelector('.av-nota');
        ok('buzón: el primero es la devolución, con su nota',
           t === 'RIF de la empresa' && q === 'Te la devolvimos: falta algo' &&
           !!nota && nota.textContent.indexOf('ilegible') >= 0,
           t + ' / ' + q + ' / ' + (nota ? nota.textContent.trim() : '(sin nota)'),
           'RIF de la empresa / Te la devolvimos: falta algo / con nota');
      })();

      igual('buzón: los avisos sin nota no inventan una',
            avisos()[1].querySelector('.av-nota'), null);


      ok('buzón: marca como nuevo lo no visto',
         avisos()[0].classList.contains('nuevo'), avisos()[0].className, 'con la clase nuevo');

      (function(){
        applyLang('en');
        var q = avisos()[0].querySelector('.av-q').textContent.trim();
        var h = document.getElementById('avisosH').textContent.trim();
        applyLang('es');
        ok('buzón: se traduce', q === 'Sent back to you: something is missing' && h === 'Your alerts',
           'q="' + q + '" cabecera="' + h + '"',
           'q="Sent back to you: something is missing" cabecera="Your alerts"');
      })();

      /* Al CERRAR, no al abrir: si se apagara al abrirlo, no daría tiempo a
         ver cuál era nuevo. */
      document.body.click();
      ok('buzón: se cierra al pulsar fuera', !buzon.classList.contains('open'),
         buzon.className, 'sin la clase open');
      ok('buzón: al cerrarlo se apaga el contador', cuenta.hidden,
         'oculto=' + cuenta.hidden, 'oculto=true');

      (function(){
        var g = null;
        try { g = window.localStorage.getItem('ciip.avisos.u1'); } catch(e){}
        /* Se guarda la fecha del servidor del aviso más nuevo (14 ago 2026),
           no la hora de esta máquina: con la hora local, un reloj adelantado
           escondería avisos que nunca llegaste a ver. */
        ok('buzón: recuerda lo visto con la fecha del servidor',
           g === String(Date.parse('2026-08-14T10:00:00Z')),
           'guardado=' + g, String(Date.parse('2026-08-14T10:00:00Z')));
      })();

      /* Navegación. Va al final porque cambia de vista. */
      campana.click();
      avisos()[0].click();
      igual('buzón: pulsar un aviso lleva a su trámite', location.hash, '#tramite-c6');
      ok('buzón: y se cierra al hacerlo', !buzon.classList.contains('open'),
         buzon.className, 'sin la clase open');

      /* Se reabre para mirar la cita. Va aquí, al final, y no arriba: abrir y
         cerrar el buzón marca todo como visto, y hacerlo antes dejaría sin
         sentido la prueba de "marca como nuevo lo no visto". */
      campana.click();
      /* ── la cita confirmada, en el mismo buzón ──
         Es lo único de una cita que se anuncia: pedirla y cancelarla lo hace
         el propio inversionista, y confirmarla solo puede hacerlo el CIIP. */
      (function(){
        var cita = avisos()[3];
        igual('buzón: la cita confirmada va con los demás avisos',
              cita.querySelector('.av-t').textContent.trim(), 'Tu cita');
        ok('buzón: y dice para cuándo quedó, con su hora',
           /Confirmada para el/.test(cita.querySelector('.av-q').textContent) &&
           /26 ago 2026/.test(cita.querySelector('.av-q').textContent) &&
           cita.querySelector('.av-q').textContent.indexOf('{') < 0,
           cita.querySelector('.av-q').textContent, 'la fecha puesta, sin llaves');
        igual('buzón: y dónde', (cita.querySelector('.av-nota') || {}).textContent, 'Torre CIIP, piso 4');

        /* Va la última porque se confirmó en julio, antes que los tres
           movimientos del trámite: el buzón ordena por fecha, no por origen. */
        ok('buzón: se ordena por fecha, no por de dónde viene',
           avisos()[0].querySelector('.av-t').textContent.trim() === 'RIF de la empresa',
           avisos()[0].querySelector('.av-t').textContent.trim(), 'primero el más reciente');

        /* Y lleva a su ventana, no al detalle de un trámite. Se compara la
           dirección ANTES y DESPUÉS: mirar solo el "después" haría que un
           #tramite- que ya estuviera puesto de una prueba anterior contara
           como si lo hubiera puesto este clic. */
        var hashAntes = location.hash;
        cita.click();
        ok('buzón: pulsar la cita abre su ventana, no un trámite',
           document.getElementById('citaBack').classList.contains('open') &&
           location.hash === hashAntes,
           'ventana=' + document.getElementById('citaBack').classList.contains('open') +
           ' hash ' + (hashAntes || '(vacio)') + ' → ' + (location.hash || '(vacio)'),
           'la ventana de la cita, y sin cambiar de dirección');
        document.getElementById('ctCerrar').click();
      })();

      location.hash = '';
      franja().querySelector('.btn').click();
      igual('franja: el botón lleva al trámite que anuncia', location.hash, '#tramite-c6');
      location.hash = '';
    }

    if (CASO === 'vacio'){
      ok('buzón: sin historial, el contador no se ve', cuenta.hidden,
         'oculto=' + cuenta.hidden, 'oculto=true');
      igual('buzón: sin historial, no hay avisos', avisos().length, 0);
      campana.click();
      igual('buzón: sin historial lo dice, en vez de quedarse en blanco',
            (document.querySelector('#avisosLista .av-vacio') || {}).textContent,
            'Todavía no hay nada que contarte.');
      document.body.click();
    }

    /* ═══════════ TU PERFIL ═══════════
       Una cuenta dada de alta a mano en Supabase llega sin nombre y sin país,
       y hasta ahora no había dónde ponerlos. */
    var chip  = document.querySelector('.user');
    var caja  = document.getElementById('perfilBack');
    var cPais = document.getElementById('pfPais');
    var cCod  = document.getElementById('pfPaisCod');
    var cLista= document.getElementById('pfLista');

    function teclea(v){
      cPais.value = v;
      cPais.dispatchEvent(new Event('input', {bubbles:true}));
    }
    function opciones(){ return cLista.querySelectorAll('li[role="option"]'); }
    function textoDe(li){ return li ? li.querySelector('span:last-child').textContent.trim() : ''; }
    function elige(li){ li.dispatchEvent(new MouseEvent('mousedown', {bubbles:true, cancelable:true})); }

    ok('perfil: el avatar avisa cuando falta algo',
       chip.classList.contains('incompleto') === (CASO === 'sinnombre'),
       'incompleto=' + chip.classList.contains('incompleto') + ' (caso ' + CASO + ')',
       CASO === 'sinnombre' ? 'incompleto=true' : 'incompleto=false');

    chip.click();
    ok('perfil: la ventana se abre al pulsar tu nombre', caja.classList.contains('open'),
       caja.className, 'con la clase open');

    igual('perfil: llega con lo que ya hay en tu expediente',
          document.getElementById('pfNombre').value,
          CASO === 'sinnombre' ? '' : 'Franklin Reyes');
    igual('perfil: y con tu país ya escrito',
          cPais.value, CASO === 'sinnombre' ? '' : 'Italia');

    /* ── el buscador de países ── */
    cPais.dispatchEvent(new Event('focus', {bubbles:true}));
    ok('países: al enfocar se despliega la lista',
       cLista.classList.contains('open') && opciones().length > 0,
       'abierta=' + cLista.classList.contains('open') + ' opciones=' + opciones().length,
       'abierta con opciones');

    teclea('ven');
    ok('países: escribir filtra, y lo que empieza por ahí va primero',
       textoDe(opciones()[0]) === 'Venezuela',
       textoDe(opciones()[0]) + ' (' + opciones().length + ' resultados)', 'Venezuela');

    /* Sin esto habría que saber dónde está la tilde para encontrar tu país. */
    teclea('peru');
    igual('países: busca sin tildes', textoDe(opciones()[0]), 'Perú');

    teclea('xkcd');
    ok('países: lo que no existe no inventa resultados', opciones().length === 0,
       opciones().length + ' resultados', '0');

    teclea('ven');
    /* La bandera es un <img> y no un emoji: Windows dibuja "VE" en vez de la
       bandera, y ese fallo no se ve en macOS. */
    (function(){
      var marca = opciones()[0].firstChild;
      var img = marca && marca.tagName === 'IMG';
      ok('paises: cada pais enseña su bandera dibujada',
         img && /banderas\/ve\.svg$/.test(marca.getAttribute('src') || ''),
         img ? marca.getAttribute('src') : ('etiqueta ' + (marca && marca.tagName) + ' = ' + (marca && marca.textContent)),
         'un <img> a banderas/ve.svg');
      ok('paises: y la bandera carga de verdad',
         img && marca.complete && marca.naturalWidth > 0,
         img ? (marca.naturalWidth + 'x' + marca.naturalHeight) : 'no es imagen', 'con tamaño');
    })();
    elige(opciones()[0]);
    ok('países: elegir rellena el campo y guarda el código',
       cPais.value === 'Venezuela' && cCod.value === 'VE',
       'campo=' + cPais.value + ' cod=' + cCod.value, 'campo=Venezuela cod=VE');
    ok('países: y la lista se cierra', !cLista.classList.contains('open'),
       cLista.className, 'sin la clase open');

    /* ── lo que falta, dicho ── */
    document.getElementById('pfNombre').value = '';
    teclea('');
    document.getElementById('pfGuardar').click();
    igual('perfil: sin nombre ni país no guarda, y lo dice',
          (document.getElementById('pfAviso') || {}).textContent,
          'Escribe tu nombre y elige tu país.');
    ok('perfil: y marca los dos campos', document.querySelectorAll('.pf-campo.mal').length === 2,
       document.querySelectorAll('.pf-campo.mal').length + ' campos marcados', '2');

    /* Un país inventado no puede llegar a la base: si no, acaban
       "Venezuela", "venezuela" y "Benezuela" como tres países distintos. */
    document.getElementById('pfNombre').value = 'Ana Rojas';
    teclea('Benezuela');
    document.getElementById('pfGuardar').click();
    igual('perfil: un país que no está en la lista no pasa',
          (document.getElementById('pfAviso') || {}).textContent,
          'Elige un país de la lista.');

    /* ── y ahora de verdad, con la interfaz en INGLÉS ──
       Se ve "Italy" y a la base tiene que ir "Italia". Es la prueba de que
       cambiar de idioma no cambia el dato guardado. */
    applyLang('en');
    document.getElementById('pfNombre').value = '  Ana   María  Rojas  ';
    teclea('ital');
    ok('países: la lista se ve en tu idioma',
       textoDe(opciones()[0]) === 'Italy', textoDe(opciones()[0]), 'Italy');
    elige(opciones()[0]);
    igual('países: elegido en inglés, el código es el mismo', cCod.value, 'IT');
    document.getElementById('pfGuardar').click();
  }

  /* Lo que hay que comprobar DESPUÉS de que la base conteste al guardado. */
  function trasGuardar(){
    var caja = document.getElementById('perfilBack');
    var chip = document.querySelector('.user');
    applyLang('es');

    ok('perfil: al guardar se cierra la ventana', !caja.classList.contains('open'),
       caja.className, 'sin la clase open');

    /* Los espacios de sobra se recortan: "Ana   María  Rojas" y
       "Ana María Rojas" no pueden ser dos nombres distintos en la base. */
    igual('perfil: lo guardado sube a la cabecera, sin espacios de sobra',
          (document.querySelector('.u-name') || {}).textContent.trim(), 'Ana María Rojas');
    /* Se eligió "Italy" con la interfaz en inglés; lo guardado es "Italia". */
    igual('perfil: el país se guarda en español aunque se eligiera en inglés',
          (document.querySelector('.u-sub') || {}).textContent.trim(),
          (CASO === 'gestor' ? 'Equipo CIIP' : 'Inversionista') + ' · Italia');
    igual('perfil: las iniciales se rehacen',
          (document.querySelector('.avatar') || {}).textContent.trim(), 'AR');
    ok('perfil: y el aviso del avatar se apaga', !chip.classList.contains('incompleto'),
       chip.className, 'sin la clase incompleto');
  }

  /* ═══════════ LAS CITAS ═══════════
     "Agendar una cita" era un botón sin manejador. Lo que se pide es una
     PETICIÓN —qué días te vienen bien— y el CIIP pone la hora. */
  function ctVentana(){ return document.getElementById('citaBack'); }
  function ctForm(){    return document.getElementById('ctForm'); }
  function ctEstado(){  return document.getElementById('ctEnMarcha'); }
  function ctTexto(id){ return (document.getElementById(id) || {}).textContent || ''; }

  function citasAbre(){
    /* El expediente del equipo está para probar la cola, no para pedir cita:
       un gestor también puede pedirla, pero eso ya lo cubren los otros tres. */
    if (CASO === 'gestor') return;
    document.getElementById('citaBtn').click();
    ok('citas: el botón abre la ventana', ctVentana().classList.contains('open'),
       ctVentana().className, 'con la clase open');
  }

  function citasPide(){
    if (CASO === 'gestor') return;
    var hayUna = (CASO === 'lleno');   /* el expediente 'lleno' ya trae una pedida */

    if (hayUna){
      /* Con una cita en marcha no puede salir un formulario en blanco: eso
         invitaría a pedir la misma reunión cinco veces. */
      ok('citas: si ya hay una, no ofrece el formulario',
         ctForm().classList.contains('oculto') && ctEstado().classList.contains('puesto'),
         'form oculto=' + ctForm().classList.contains('oculto') +
         ' estado puesto=' + ctEstado().classList.contains('puesto'),
         'form oculto, estado puesto');
      igual('citas: y dice que ya tienes una en marcha', ctTexto('ctSub'), 'Ya tienes una cita en marcha');
      /* El título no puede seguir diciendo "Solicitar una cita" cuando ya
         hay una: contradice al subtítulo que va justo debajo. */
      igual('citas: y el título deja de invitarte a pedir otra', ctTexto('ctTitulo'), 'Tu cita');
      /* El distintivo dice el ESTADO, no el nombre de un botón ni una frase
         con el hueco de la fecha sin rellenar. */
      igual('citas: el distintivo dice en qué estado está', ctTexto('ctChip'), 'Pedida');
      ok('citas: y no deja ningún hueco sin rellenar a la vista',
         ctTexto('ctChip').indexOf('{') < 0 && ctTexto('ctLinea').indexOf('{') < 0,
         'chip="' + ctTexto('ctChip') + '" linea="' + ctTexto('ctLinea') + '"', 'sin llaves');
      ok('citas: con la fecha en que se pidió',
         ctTexto('ctLinea').indexOf('Pedida el') === 0, ctTexto('ctLinea'), 'empieza por "Pedida el"');
      ok('citas: el botón de enviar desaparece',
         document.getElementById('ctEnviar').style.display === 'none',
         'display=' + document.getElementById('ctEnviar').style.display, 'display=none');
      igual('citas: y el gris pasa a cancelar la cita',
            ctTexto('ctCancelar'), 'Cancelar la cita');
      return;
    }

    ok('citas: sin ninguna en marcha, sale el formulario',
       !ctForm().classList.contains('oculto') && !ctEstado().classList.contains('puesto'),
       'form oculto=' + ctForm().classList.contains('oculto'), 'el formulario a la vista');

    /* El asunto sale del catálogo: no se puede pedir cita sobre un trámite
       que la base no conoce, porque tipo_tramite apunta a tipos_tramite. */
    var sel = document.getElementById('ctAsunto');
    ok('citas: el asunto ofrece la consulta general y los trámites',
       sel.options.length === 4 && sel.options[0].value === '',
       sel.options.length + ' opciones, la primera "' + sel.options[0].textContent + '"',
       '4 opciones (general + 3 del catálogo)');

    /* La regla que viste los <input> de la ventana los ponía de lado a lado,
       y a un radio eso lo convertiía en una barra que empujaba su etiqueta
       fuera de la caja. Se mide el ancho, que es donde se ve. */
    (function(){
      var r = document.querySelector('#ctModos input');
      var ancho = r ? r.getBoundingClientRect().width : 999;
      ok('citas: el botón redondo del modo es redondo, no una barra',
         ancho > 0 && ancho < 30, Math.round(ancho) + 'px de ancho', 'menos de 30px');
      var lb = r ? r.closest('label') : null;
      var sp = lb ? lb.querySelector('span') : null;
      ok('citas: y su etiqueta cabe dentro de su caja',
         !!sp && sp.getBoundingClientRect().right <= lb.getBoundingClientRect().right + 1,
         sp ? (Math.round(sp.getBoundingClientRect().right) + ' vs ' + Math.round(lb.getBoundingClientRect().right)) : 'sin etiqueta',
         'el texto no se sale');
    })();

    igual('citas: los tres modos, y por defecto la videollamada',
          document.querySelectorAll('#ctModos label').length + '/' +
          (document.querySelector('#ctModos input:checked') || {}).value, '3/video');

    var d = document.getElementById('ctDesde'), h = document.getElementById('ctHasta');
    ok('citas: las fechas vienen puestas, no en blanco',
       !!d.value && !!h.value && h.value > d.value,
       d.value + ' → ' + h.value, 'de mañana a dentro de una semana');
    ok('citas: y no dejan elegir un día pasado', !!d.min, 'min=' + d.min, 'con mínimo');

    /* Una ventana al revés la rechaza también la base; aquí se dice con
       palabras en vez de con un error de SQL. */
    var guarda = h.value;
    h.value = '2020-01-01';
    document.getElementById('ctEnviar').click();
    igual('citas: una ventana al revés no se envía, y lo dice',
          ctTexto('ctAviso'), 'El último día no puede ser anterior al primero.');
    h.value = guarda;

    /* Y ahora de verdad. */
    sel.value = sel.options[1].value;
    document.getElementById('ctNota').value = 'Prefiero por la mañana';
    document.getElementById('ctEnviar').click();
  }

  function citasTrasPedir(){
    if (CASO === 'gestor') return;
    if (CASO === 'lleno') return;
    ok('citas: pedida, la ventana pasa a enseñar su estado',
       ctForm().classList.contains('oculto') && ctEstado().classList.contains('puesto'),
       'form oculto=' + ctForm().classList.contains('oculto') +
       ' estado puesto=' + ctEstado().classList.contains('puesto'),
       'form oculto, estado puesto');
    ok('citas: y dice desde cuándo está pedida',
       ctTexto('ctLinea').indexOf('Pedida el') === 0, ctTexto('ctLinea'), 'empieza por "Pedida el"');
    ok('citas: el detalle recoge el modo y tu nota',
       ctTexto('ctDetalle').indexOf('Videollamada') >= 0 &&
       ctTexto('ctDetalle').indexOf('mañana') >= 0,
       ctTexto('ctDetalle'), 'con "Videollamada" y tu nota');
    ok('citas: y ya no ofrece pedir otra',
       document.getElementById('ctEnviar').style.display === 'none',
       'display=' + document.getElementById('ctEnviar').style.display, 'display=none');
  }

  function citasAnula(){
    if (CASO === 'gestor') return;
    document.getElementById('ctCancelar').click();
  }

  /* ═══════════ CITAS Y AGENDA ═══════════
     El renglón de la barra lateral se iluminó durante meses sin llevar a
     ninguna parte, con un "2" de ejemplo al lado. */
  function agendaMira(){
    var nav = document.getElementById('navCitas');
    var num = document.getElementById('navCitasN');

    /* El contador sale de las citas VIVAS, no de un ejemplo. En 'lleno' hay
       una confirmada; en los demás expedientes, ninguna. */
    var vivas = (CASO === 'lleno') ? '1' : '';
    if (vivas){
      igual('agenda: el renglón cuenta tus citas vivas', num.textContent, vivas);
      ok('agenda: y el contador se ve', !num.hidden, 'oculto=' + num.hidden, 'oculto=false');
    } else {
      ok('agenda: sin citas vivas, el renglón no lleva número', num.hidden,
         'oculto=' + num.hidden + ' texto="' + num.textContent + '"', 'oculto=true');
    }

    /* Es un <button> entre <div>: sin devolverle el aspecto salía con letra
       del sistema y texto oscuro sobre la barra azul, y cantaba al lado de
       sus vecinos. Se compara contra uno de ellos. */
    (function(){
      /* Un vecino CUALQUIERA no vale: el primero es "Mi panel", que está
         activo y por eso va en blanco puro. Se compara con uno en reposo. */
      var vecino = document.querySelector('.sb-item:not(.active):not(.soon)');
      var a = window.getComputedStyle(nav), b = window.getComputedStyle(vecino);
      ok('agenda: el renglón se ve igual que sus vecinos',
         a.fontFamily === b.fontFamily && a.fontSize === b.fontSize && a.color === b.color,
         'letra ' + a.fontSize + ' ' + a.color + ' vs ' + b.fontSize + ' ' + b.color,
         'la misma letra y el mismo color');
      ok('agenda: y ocupa el mismo ancho',
         Math.abs(nav.getBoundingClientRect().width - vecino.getBoundingClientRect().width) < 1,
         Math.round(nav.getBoundingClientRect().width) + 'px vs ' + Math.round(vecino.getBoundingClientRect().width) + 'px',
         'el mismo ancho');
    })();

    /* Y lleva a alguna parte, con su propia dirección. */
    nav.click();
    igual('agenda: el renglón lleva a su vista', location.hash, '#citas');
  }

  function agendaTrasEntrar(){
    igual('agenda: y la vista se abre', document.body.getAttribute('data-vista'), 'citas');
    var fichas = document.querySelectorAll('#ciLista .ci-ficha');

    if (CASO === 'lleno'){
      igual('agenda: enseña la cita que tienes', fichas.length, 1);
      ok('agenda: con su fecha puesta, no un hueco',
         /Confirmada para el/.test(fichas[0].querySelector('.ci-linea').textContent) &&
         fichas[0].querySelector('.ci-linea').textContent.indexOf('{') < 0,
         fichas[0].querySelector('.ci-linea').textContent, 'la fecha, sin llaves');
      ok('agenda: la viva se distingue del historial',
         fichas[0].classList.contains('viva'), fichas[0].className, 'con la clase viva');
      /* Con una cita viva no se ofrece pedir otra: la ventana no dejaría. */
      igual('agenda: y no ofrece pedir otra',
            document.getElementById('ciPedir').style.display, 'none');
    } else {
      igual('agenda: sin ninguna, lo dice en vez de dejarlo en blanco',
            (document.querySelector('#ciLista .ci-vacia') || {}).textContent,
            'Todavía no has pedido ninguna cita.');
      ok('agenda: y ofrece pedir una', document.getElementById('ciPedir').style.display !== 'none',
         'display=' + document.getElementById('ciPedir').style.display, 'visible');
    }

    /* El resaltado lo pone la VISTA, no el último clic: si no, te quedabas
       con un renglón encendido apuntando a un sitio donde no estás. */
    ok('barra: estando en las citas, el renglón encendido es el suyo',
       document.getElementById('navCitas').classList.contains('active') &&
       !document.getElementById('navPanel').classList.contains('active'),
       'citas=' + document.getElementById('navCitas').classList.contains('active') +
       ' panel=' + document.getElementById('navPanel').classList.contains('active'),
       'citas encendido, panel apagado');

    /* Y "Mi panel" saca de aquí. Era un <div> que solo se iluminaba, así que
       desde la vista de citas no había salida por la barra. */
    document.getElementById('navPanel').click();
  }

  function agendaTrasSalir(){
    if (false) return;
    igual('barra: "Mi panel" devuelve a la portada',
          document.body.getAttribute('data-vista'), 'inicio');
    ok('barra: y el resaltado vuelve con él',
       document.getElementById('navPanel').classList.contains('active') &&
       !document.getElementById('navCitas').classList.contains('active'),
       'panel=' + document.getElementById('navPanel').classList.contains('active') +
       ' citas=' + document.getElementById('navCitas').classList.contains('active'),
       'panel encendido, citas apagado');

    /* Los renglónes que no llevan a ninguna parte ya no se quedan el
       resaltado: un "estás aquí" falso es peor que ninguno. */
    var inerte = document.querySelectorAll('.sb-item')[1];
    inerte.click();
    ok('barra: un renglón que no lleva a nada no se queda el resaltado',
       !inerte.classList.contains('active') &&
       document.getElementById('navPanel').classList.contains('active'),
       'inerte=' + inerte.classList.contains('active'),
       'sigue encendido el de la portada');
  }

  /* ═══════════ LA COLA DEL EQUIPO ═══════════
     Una cita pedida se quedaba en la base esperando a que alguien mirara la
     tabla a mano. */
  function colaAbre(){
    var sel = document.getElementById('colaSel');

    /* Lo primero, y lo que más importa: a un inversionista ni se le ofrece.
       No es la protección —esa es la política de la base— pero ofrecer una
       puerta que no se puede abrir es peor que no ofrecerla. */
    ok('cola: solo se le ofrece al equipo del CIIP',
       sel.hidden === (CASO !== 'gestor'),
       'oculta=' + sel.hidden + ' (caso ' + CASO + ')',
       CASO === 'gestor' ? 'oculta=false' : 'oculta=true');
    if (CASO !== 'gestor') return;

    /* "Cola" era ambiguo: en español es tanto fila como pegamento. */
    igual('cola: el botón dice para qué sirve',
          (document.getElementById('colaTxt') || {}).textContent, 'Por atender');
    igual('cola: el botón lleva cuántas esperan',
          (document.getElementById('colaN') || {}).textContent, '2');

    document.getElementById('colaBtn').click();
    var caja = document.getElementById('colaBack');
    ok('cola: se abre al pulsarlo', caja.classList.contains('open'), caja.className, 'con la clase open');
  }

  function colaConfirma(){
    if (CASO !== 'gestor') return;
    var fichas = document.querySelectorAll('#colaLista .co-ficha');
    igual('cola: enseña las dos que esperan', fichas.length, 2);

    /* La más vieja primero: una cola que empieza por lo recién llegado deja
       lo de hace un mes al final para siempre. */
    ok('cola: la más vieja va primero',
       fichas[0].querySelector('.co-cuando').textContent.indexOf('10 ago') >= 0,
       fichas[0].querySelector('.co-cuando').textContent, 'la del 10 de agosto');

    igual('cola: dice quién la pidió',
          fichas[0].querySelector('.co-quien').textContent.trim(), 'Marta Bianchi');
    /* Sin nombre en su expediente se dice, en vez de dejar el hueco: un hueco
       parece un fallo del dato y no un permiso que falta. */
    igual('cola: y cuando no hay nombre, lo dice',
          fichas[1].querySelector('.co-quien').textContent.trim(), '(sin nombre en su expediente)');

    ok('cola: y sobre qué, cómo y qué días le vienen bien',
       /RIF de la empresa/.test(fichas[0].querySelector('.co-que').textContent) &&
       /Presencial/.test(fichas[0].querySelector('.co-que').textContent),
       fichas[0].querySelector('.co-que').textContent, 'el trámite y el modo');
    igual('cola: una cita sin trámite es una consulta general',
          fichas[1].querySelector('.co-que').textContent.split(' · ')[0], 'Consulta general');

    /* Confirmar sin fecha no puede pasar: la base rechaza una cita
       confirmada sin ella, y aquí se dice con palabras. */
    fichas[0].querySelectorAll('.btn')[1].click();
    igual('cola: sin fecha no confirma, y lo dice',
          fichas[0].querySelector('.co-aviso').textContent, 'Pon la fecha y la hora.');

    fichas[0].querySelector('input[type="datetime-local"]').value = '2026-08-26T10:00';
    fichas[0].querySelector('input[type="text"]').value = 'Torre CIIP, piso 4';
    fichas[0].querySelectorAll('.btn')[1].click();
  }

  function colaTrasConfirmar(){
    if (CASO !== 'gestor') return;
    igual('cola: confirmada, sale de la cola', document.querySelectorAll('#colaLista .co-ficha').length, 1);
    igual('cola: y el contador baja', (document.getElementById('colaN') || {}).textContent, '1');
  }

  function citasTrasAnular(){
    if (CASO === 'gestor') return;
    /* Cancelada, se puede volver a pedir: el formulario vuelve. */
    ok('citas: al cancelarla vuelve el formulario',
       !ctForm().classList.contains('oculto') && !ctEstado().classList.contains('puesto'),
       'form oculto=' + ctForm().classList.contains('oculto') +
       ' estado puesto=' + ctEstado().classList.contains('puesto'),
       'el formulario a la vista');
    igual('citas: y el gris vuelve a ser cerrar', ctTexto('ctCancelar'), 'Cancelar');
  }

})();
