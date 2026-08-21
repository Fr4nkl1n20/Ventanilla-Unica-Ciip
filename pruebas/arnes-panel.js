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
  var PASE = (location.search.match(/caso=(\w+)/) || [])[1] || 'lleno';
  /* 'sinsql' trae LOS MISMOS DATOS que 'gestor': lo unico que cambia es que
     la base no tiene corridas dos columnas. Si CASO valiera 'sinsql', cada
     prueba que mira "eres del equipo?" se creeria que eres inversionista y
     saldria roja por el nombre del pase, no por lo que mide. */
  var SIN_SQL = (PASE === 'sinsql');
  var ES_ADMIN = (PASE === 'admin');
  var CASO = (SIN_SQL || ES_ADMIN) ? 'gestor' : PASE;
  /* El rol de la cabecera sale del PASE, no de los datos: 'admin' trae
     los mismos tramites que un gestor, pero no el mismo rotulo. */
  var ROL_ESPERADO = ES_ADMIN ? 'Administrador'
                   : CASO === 'gestor' ? 'Equipo CIIP' : 'Inversionista';

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
              colaAbre, colaTramites,
              /* La identidad se mira con el expediente ya desplegado y
                 ANTES de colaExpediente, que termina devolviendo el
                 tramite: al devolverlo sale de la cola y se lleva por
                 delante la ficha entera. */
              idMira, idRechazaSinNota, idFirma, idTrasFirmar,
              colaExpediente, colaTrasDevolver, colaConfirma, colaTrasConfirmar,
              agendaMira, agendaTrasEntrar, agendaTrasSalir,
              rncAbre, rncTrasAbrir, solvenciasAbre, solvenciasTrasAbrir,
              activosAbre, activosMira, activosPublica, activosTrasPublicar,
              activosEdita, activosTrasEditar, activosBorra, activosTrasBorrar,
              devueltoAbre, devueltoMira, escaleraAbre, escaleraMira,
              usuariosMira, usuariosCambia, usuariosTrasCambiar, usuariosSeMueve,
              sinSqlAbre, sinSqlMira,
              adminMira, adminAbre, adminDentro,
              f5Entra, f5Espera, f5Llega,
              f5TardeEntra, f5TardeEspera, f5TardeLlega,
              empresaAbre, empresaMira, empresaGuarda, empresaTrasGuardar,
              entregaAbre, entregaMira,
              docsAbre, docsMira,
              ayudaAbre, ayudaMira, ayudaFaq,
              supAbre, supMira, supTemas, supVuelve,
              logosMiran], volcar);
  });

  function pruebas(){

    /* Antes de tocar nada: el panel tenía que haberse abierto SOLO en el
       idioma del expediente. Estas cuentas dicen Italia, y hasta ahora el
       panel abría siempre en inglés por mucho que dijera el perfil —y por
       mucho que hubieras entrado en español por la pantalla de acceso—. */
    if (CASO !== 'sinnombre'){
      igual('idioma: el panel abre en el idioma de tu país', curLang, 'it');
    }
    /* Y se limpia lo que una pasada anterior pudiera haber dejado escrito:
       si no, la de arriba dependeria de cómo terminó la de ayer. */
    try { window.localStorage.removeItem('ciip_lang'); } catch(e){}

    applyLang('es');

    /* ═══════════ EL CAMINO: LOS CONTADORES SALEN DE LAS TARJETAS ═══════════
       Los cuatro renglones estaban escritos a mano para las 15 tarjetas de
       antes. Ahora se cuentan, y estas cuatro pruebas son lo que impide que
       vuelvan a quedarse atrás cuando el catálogo crezca. */
    /* Antes decia "3 de 10": tres tarjetas de la fase 01 llevaban
       "Completado" escrito a mano. Ninguna cuenta era de nadie. Ahora sale
       de tus tramites, y en ningun expediente de prueba hay uno resuelto. */
    /* En 'lleno' hay una visa resuelta y en los demás expedientes no: el
       mismo catálogo de diez trámites cuenta distinto según quién mira, que
       es justo lo que un marcador escrito a mano no podía hacer. */
    igual('camino: la fase 01 cuenta lo que tú llevas hecho', deEtapa(0, '.jcount'),
          (CASO === 'lleno') ? '1 de 10 listos' : '0 de 10 listos');
    igual('camino: la fase 02 cuenta sus 7',           deEtapa(1, '.jcount'), '0 de 7 listos');
    igual('camino: la fase 03 cuenta sus 10',          deEtapa(2, '.jcount'), '0 de 10 listos');
    igual('camino: la fase 04 cuenta sus 3',           deEtapa(3, '.jcount'), '0 de 3 listos');
    igual('camino: la fase 05 cuenta su único trámite', deEtapa(4, '.jcount'), '0 de 1 listos');

    (function(){
      var barra = etapas()[0].querySelector('.jbar > span');
      igual('camino: la barra de la fase 01 mide lo hecho', barra.style.width,
            (CASO === 'lleno') ? '10%' : '0%');
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

    /* El numero del marcado tambien, no solo el que calcula el script: es lo
       que se ve durante el instante que tarda la pagina en contar, y llevaba
       24 con 31 tarjetas puestas. */
    ok('camino: y el marcado no arranca con una cuenta vieja',
       /<span class="n">31<\/span>/.test(document.querySelector('.ftab[data-f="todos"]').outerHTML) ||
       document.querySelector('.ftab[data-f="todos"] .n').textContent === '31',
       document.querySelector('.ftab[data-f="todos"] .n').textContent, '31');

    igual('camino: los filtros cuentan las 31 tarjetas',
          (document.querySelector('.ftab[data-f="todos"] .n') || {}).textContent, '31');

    /* ═══════════ EL ESTADO DE CADA TARJETA ═══════════
       Iba escrito a mano en las 31: tres decían "Completado" y una fecha de
       emisión de un trámite que nadie había pedido. Los cuatro filtros de
       arriba contaban esos ejemplos. */
    (function(){
      function st(ref){ return (document.querySelector('.tcard[data-tr="' + ref + '"]') || {getAttribute:function(){return null;}}).getAttribute('data-st'); }
      function chip(ref){ var c = document.querySelector('.tcard[data-tr="' + ref + '"] .t-top .chip'); return c ? c.textContent.trim() : ''; }
      function reloj(ref){ var t = document.querySelector('.tcard[data-tr="' + ref + '"] .t-time'); return t ? t.textContent.trim() : ''; }

      /* Tantas tarjetas en verde como trámites resueltos tengas: ni una
         más. En 'lleno' hay uno —la visa— y en los demás ninguno. */
      var listas = document.querySelectorAll('.tcard[data-st="listo"]').length;
      var esperadas = (CASO === 'lleno') ? 1 : 0;
      ok('estados: tantas en verde como trámites resueltos', listas === esperadas,
         listas + ' tarjetas en verde', esperadas + '');

      /* Una que nadie ha pedido: por iniciar, y con su estimado intacto.
         El estimado no es un estado, es cuánto tarda: sigue siendo cierto. */
      /* La c1 es la visa, y en 'lleno' está resuelta: la que no ha pedido
         nadie en ningún expediente es la c16. */
      igual('estados: sin solicitud, la tarjeta está por iniciar', st('c16'), 'pendiente');
      igual('estados: y su distintivo lo dice', chip('c16'), 'Por iniciar');
      /* El renglón del reloj de la visa decía "Emitida el 18 jun" —una
         fecha de emisión de un trámite que nadie había pedido—. Ahora dice
         cuándo se puede pedir, que es lo que el panel sabe sin expediente. */
      ok('estados: y el reloj dice cuándo se pide, no cuándo se emitió',
         !/(Emitid|Rilasciat|Issued|签发|Выдан)/i.test(reloj('c16')),
         reloj('c16'), 'sin fecha de emisión');
      /* Y tampoco lo cuenta la descripción: seis estaban escritas como si
         el trámite ya estuviera hecho —"tu cédula ya está lista"— o con la
         persona de la demostración dentro —"tu licencia italiana"—. Una
         tarjeta que dice "Por iniciar" no puede decir eso debajo. */
      ok('estados: ni la descripción da por hecho el trámite',
         !/(ya está lista|quedó estampada|licencia italiana|Bianchi)/i.test(document.getElementById('secTramites').textContent),
         'busca "ya está lista", "italiana", "Bianchi"', 'ninguna');
      ok('estados: y ninguna de las 31 inventa una fecha de emisión',
         !/(Emitid|Rilasciat|Issued|签发|Выдан)/i.test(document.getElementById('secTramites').textContent),
         'busca "Emitida" en las tarjetas', 'ninguna');

      if (CASO === 'lleno'){
        /* t1 es un RIF de empresa devuelto y t2 una constitución en
           borrador: en las dos la pelota la tienes tú. */
        igual('estados: un trámite devuelto pide tu acción', st('c6'), 'accion');
        igual('estados: y lo dice el distintivo', chip('c6'), 'Requiere acción');
        ok('estados: la tarjeta se enmarca en ámbar',
           document.querySelector('.tcard[data-tr="c6"]').classList.contains('action'),
           document.querySelector('.tcard[data-tr="c6"]').className, 'con la clase action');
        igual('estados: un borrador también', st('c5'), 'accion');

        /* t3 es un RIF personal recién enviado. */
        igual('estados: uno enviado va en proceso', st('c3'), 'proceso');
        ok('estados: y el reloj dice cuándo lo enviaste',
           /Enviada el/.test(reloj('c3')), reloj('c3'), 'Enviada el ...');

        igual('estados: el filtro de acción cuenta los dos',
              document.querySelector('.ftab[data-f="accion"] .n').textContent, '2');
        igual('estados: y el de en proceso, el uno',
              document.querySelector('.ftab[data-f="proceso"] .n').textContent, '1');
        igual('estados: y el de completados, el resuelto',
              document.querySelector('.ftab[data-f="listo"] .n').textContent, '1');
        ok('estados: un trámite resuelto pone su tarjeta en verde',
           st('c1') === 'listo' && chip('c1') === 'Completado',
           st('c1') + ' / ' + chip('c1'), 'listo / Completado');
      }

      if (CASO === 'vacio'){
        /* Dos del mismo trámite: un borrador viejo y una revisión en
           marcha. La tarjeta enseña la de ahora, no la que se quedó atrás
           —que es lo mismo que ya hace la franja de arriba—. */
        igual('estados: entre dos del mismo trámite manda la más reciente', st('c3'), 'proceso');
      }

      if (CASO === 'sinnombre' || CASO === 'gestor'){
        /* Las 31: las 30 solicitables más la del banco de activos, que ya
           nacía 'pendiente' en el marcado -lo suyo es el distintivo, que
           sigue diciendo Disponible-. */
        var pend = document.querySelectorAll('.tcard[data-st="pendiente"]').length;
        ok('estados: sin ningún trámite, ninguna tarjeta promete nada', pend === 31,
           pend + ' por iniciar de 31', '31');
      }

      /* El banco de activos no es una solicitud —por eso tiene vista
         propia— y su distintivo no puede pasar a "por iniciar". */
      igual('estados: el banco de activos sigue diciendo Disponible', chip('c15'), 'Disponible');
    })();

    /* El renglón contaba las tarjetas del catálogo —decía cuántos trámites
       EXISTEN, que es justo lo que "Mis" no significa—. Ahora cuenta los
       TUYOS en marcha, como hace el renglón de las citas: así los dos
       números de la barra significan lo mismo.

       En el expediente 'lleno' hay tres: uno devuelto, un borrador y uno
       recién enviado. Ninguno resuelto, así que los tres están en marcha. */
    (function(){
      var n = document.getElementById('navTramitesN');
      /* Se cuenta contra lo que la propia lista dibuja, no contra un número
         escrito: cada expediente de prueba trae los suyos, y el expediente
         "vacío" no es "sin filas" sino "sin nada que anunciar". Una cifra a
         mano aquí rompería cada vez que alguien toque un fixture. */
      var vivos = 0;
      document.querySelectorAll('#mtLista .ci-ficha').forEach(function(f){
        if (!f.classList.contains('pasada')) vivos++;
      });
      igual('barra: "Mis trámites" cuenta los tuyos en marcha, no el catálogo',
            n.hidden ? '0' : n.textContent, String(vivos));
      ok('barra: y solo se ve si hay alguno',
         n.hidden === (vivos === 0),
         'oculto=' + n.hidden + ' con ' + vivos + ' en marcha',
         vivos ? 'oculto=false' : 'oculto=true');
    })();

    /* El renglón ya no lleva data-i18n: lo compone el mismo bloque que lo
       cuenta, así que el cambio de idioma tiene que alcanzarlo aparte. */
    (function(){
      applyLang('en');
      var en = deEtapa(0, '.jcount');
      applyLang('es');
      var es = deEtapa(0, '.jcount');
      var n = (CASO === 'lleno') ? '1' : '0';
      ok('camino: el renglón se traduce',
         en === n + ' of 10 done' && es === n + ' de 10 listos',
         'en="' + en + '" es="' + es + '"',
         'en="' + n + ' of 10 done" es="' + n + ' de 10 listos"');
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
      igual('camino: y el punto sigue numándolas', puntos.join(''), '12345');

      var nombres = [];
      etapas().forEach(function(e){ nombres.push(e.querySelector('.jname').textContent.trim()); });
      igual('camino: los cinco nombres son verbos del mismo tipo',
            nombres.join(' → '), 'Llegar → Constituir → Operar → Crecer → Invertir');
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
      igual('fases: el índice numera con puntos, no con la palabra', pns.join(''), '12345');

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

    /* Parejas LAS DE CADA FILA, no las cinco. En pantalla ancha van en una
       sola y la comprobación es la de siempre; en una estrecha el camino se
       reparte en varias, y exigir que la de arriba mida lo mismo que la de
       abajo era pedirle a la rejilla algo que no significa nada.

       Lo encontró la pasada estrecha el día que se añadió: 165/165/122/122/122,
       que es exactamente lo correcto. */
    (function(){
      var porFila = {};
      etapas().forEach(function(e){
        var y = Math.round(e.getBoundingClientRect().top);
        (porFila[y] = porFila[y] || []).push(e.offsetHeight);
      });
      var filas = Object.keys(porFila);
      var parejas = filas.every(function(y){
        return porFila[y].every(function(a){ return a === porFila[y][0]; });
      });
      ok('cajas: las de cada fila miden lo mismo de alto', parejas,
         filas.map(function(y){ return porFila[y].join('/'); }).join('  —  '),
         'iguales dentro de su fila');
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

    /* De dónde sale el idioma, por orden. La bandera no entra aquí: es la
       del idioma y no la de tu país, y así se queda. */
    (function(){
      var antes = PERFIL.pais;
      try { window.localStorage.removeItem('ciip_lang'); } catch(e){}
      PERFIL.pais = 'Venezuela';
      igual('idioma: tu país lo elige mientras no elijas tú', idiomaParaMi(), 'es');
      PERFIL.pais = 'Brasil';
      igual('idioma: y cambia si cambia tu país', idiomaParaMi(), 'pt');
      /* Un país que no habla ninguno de los seis no fuerza nada. */
      PERFIL.pais = 'Japón';
      ok('idioma: un país fuera de los seis no elige por ti',
         !!I18N[idiomaParaMi()], idiomaParaMi(), 'uno de los seis');

      try { window.localStorage.setItem('ciip_lang', 'ru'); } catch(e){}
      PERFIL.pais = 'Venezuela';
      igual('idioma: lo que elegiste a mano manda sobre tu país', idiomaParaMi(), 'ru');
      try { window.localStorage.removeItem('ciip_lang'); } catch(e){}

      PERFIL.pais = antes;
      applyLang('es');
    })();

    /* ═══════════ LA BARRA EN PANTALLA ESTRECHA ═══════════
       Por debajo de 840 px la barra se aparta —y hasta ahora nada la traía
       de vuelta—. Mis trámites, Documentos, Mi empresa, Activos, Citas,
       Ayuda y Usuarios desaparecían sin forma de llegar a ellos. No es que
       el menú quedara feo: quedaba inservible. */
    (function(){
      var btn = document.getElementById('menuBtn');
      var barra = document.getElementById('barraLateral');
      ok('menú: hay un botón para traer la barra de vuelta', !!btn,
         btn ? 'existe' : 'no existe', 'existe');

      var estrecha = window.innerWidth <= 840;
      if (!estrecha){
        /* En pantalla ancha la barra está siempre puesta, así que el botón
           sería un control que no hace nada. */
        igual('menú: y en pantalla ancha no se ofrece',
              window.getComputedStyle(btn).display, 'none');
        ok('menú: porque la barra ya está a la vista',
           barra.getBoundingClientRect().right > 0,
           'acaba en ' + Math.round(barra.getBoundingClientRect().right), 'a la vista');
        return;
      }

      /* De aquí abajo, solo la pasada estrecha. */
      ok('menú: en pantalla estrecha sí se ofrece',
         window.getComputedStyle(btn).display !== 'none',
         window.getComputedStyle(btn).display, 'visible');
      ok('menú: y la barra empieza fuera de la pantalla',
         barra.getBoundingClientRect().right <= 1,
         'acaba en ' + Math.round(barra.getBoundingClientRect().right), 'fuera');

      /* Abrir y cerrar, que es lo único que tiene que hacer. */
      btn.click();
      ok('menú: al pulsarlo, la barra entra',
         document.body.classList.contains('menu-abierto'),
         document.body.className, 'con la clase menu-abierto');
      /* Y ENTRA CON ANCHO. La primera versión deslizaba una barra de cero
         píxeles: la clase se ponía, la cortina bajaba y no se veía nada,
         porque en ese ancho --sb vale 0 y la barra usaba esa variable para
         su propio ancho. Medir la clase no habría encontrado el fallo. */
      ok('menú: y la barra ocupa un ancho de verdad',
         barra.getBoundingClientRect().width > 100,
         Math.round(barra.getBoundingClientRect().width) + ' px', 'más de 100 px');
      igual('menú: y lo dice para quien no la ve', btn.getAttribute('aria-expanded'), 'true');

      /* Elegir un renglón lo cierra: nadie quiere el menú encima de la
         pantalla que acaba de pedir. */
      document.getElementById('navDocs').click();
      ok('menú: elegir un renglón lo cierra',
         !document.body.classList.contains('menu-abierto'),
         document.body.className, 'sin la clase');
      location.hash = '';

      btn.click();
      document.dispatchEvent(new KeyboardEvent('keydown', {key:'Escape'}));
      ok('menú: y Escape también',
         !document.body.classList.contains('menu-abierto'),
         document.body.className, 'sin la clase');
    })();

    /* ═══════════ LA CABECERA ═══════════
       Nada de ella partía en dos renglones a propósito, pero todo podía. Y
       como la barra tiene alto fijo, lo que sobraba se salía por arriba: el
       nombre apareció cortado por la mitad y el botón de salir, fuera del
       borde derecho. */
    (function(){
      var tb = document.querySelector('.topbar');
      ok('cabecera: cabe entera, sin salirse por los lados',
         tb.scrollWidth <= tb.clientWidth + 1,
         'contenido=' + tb.scrollWidth + ' caja=' + tb.clientWidth, 'contenido <= caja');

      var usu = document.querySelector('.user');
      ok('cabecera: tu nombre y tu rol no la hacen crecer a lo alto',
         usu.offsetHeight <= tb.offsetHeight,
         'nombre=' + usu.offsetHeight + ' barra=' + tb.offsetHeight, 'nombre <= barra');

      var salir = document.getElementById('btnSalir');
      ok('cabecera: el botón de salir queda dentro',
         salir.getBoundingClientRect().right <= tb.getBoundingClientRect().right + 1,
         'salir=' + Math.round(salir.getBoundingClientRect().right) +
         ' borde=' + Math.round(tb.getBoundingClientRect().right), 'dentro del borde');

      /* Un nombre largo se corta con puntos suspensivos; entero se lee en la
         ventana del perfil, que es donde toca. */
      var nom = document.querySelector('.u-name');
      var antes = nom.textContent;
      nom.textContent = 'María Fernanda de la Concepción Villanueva Echeverría';
      ok('cabecera: un nombre muy largo no la desarma',
         tb.scrollWidth <= tb.clientWidth + 1 && usu.offsetHeight <= tb.offsetHeight,
         'contenido=' + tb.scrollWidth + ' caja=' + tb.clientWidth +
         ' alto=' + usu.offsetHeight, 'sigue cabiendo');
      nom.textContent = antes;
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
                ROL_ESPERADO + ' · Italia');
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
      /* El caso trae un borrador de RIF personal Y su envío posterior. Lo
         único pendiente, por tanto, no lo está: la franja debe callar.
         Antes anunciaba "no la has enviado" mientras el detalle del mismo
         trámite decía "Enviada", y las dos pantallas se contradecían. */
      ok('franja: un borrador ya superado por el envío no se anuncia',
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
      /* Que HAYA cargado no se puede mirar aquí: el navegador acaba de
         crear la imagen y aún no ha ido a por el archivo. Se guarda y se
         comprueba en el paso siguiente, medio segundo después. Mirarlo en
         el acto daba verde o rojo según lo cargada que fuera la máquina. */
      banderaEnPrueba = img ? marca : null;
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
  var banderaEnPrueba = null;

  function trasGuardar(){
    if (banderaEnPrueba){
      ok('paises: y la bandera carga de verdad',
         banderaEnPrueba.complete && banderaEnPrueba.naturalWidth > 0,
         banderaEnPrueba.naturalWidth + 'x' + banderaEnPrueba.naturalHeight, 'con tamaño');
      banderaEnPrueba = null;
    }
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
          ROL_ESPERADO + ' · Italia');
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
    /* Una opción por cada tipo del catálogo que tenga tarjeta, más la
       consulta general. Se cuenta el catálogo en vez de escribir el número:
       cada trámite que se activa lo cambiaba, y la prueba rompía sin que
       nadie hubiera tocado las citas. */
    (function(){
      var deberian = (window.PRUEBA_TIPOS || 0) + 1;
      ok('citas: el asunto ofrece la consulta general y los trámites',
         sel.options.length === deberian && sel.options[0].value === '',
         sel.options.length + ' opciones, la primera "' + sel.options[0].textContent + '"',
         deberian + ' (general + ' + (deberian - 1) + ' del catálogo)');
    })();

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

  /* ═══════════ EL RNC, RECIEN ACTIVADO ═══════════
     Era una ficha de solo lectura: decía "Ver detalle" y no se podía
     solicitar. Sus recaudos son PROVISIONALES —la hoja los trae en blanco—
     pero el circuito tiene que funcionar igual. */
  function rncAbre(){
    if (CASO !== 'vacio') return;
    location.hash = 'tramite-c13';
  }

  function rncTrasAbrir(){
    if (CASO !== 'vacio') return;
    igual('rnc: se abre su detalle', document.body.getAttribute('data-vista'), 'tramite');

    var caja = document.getElementById('trReal');
    var campos = caja.querySelectorAll('.sol-campo');
    var docs   = caja.querySelectorAll('.sol-doc');

    /* Lo que separa un trámite vivo de una ficha de lectura: que salga el
       formulario, no solo la escalera de pasos. */
    ok('rnc: ya se puede solicitar, no solo leer',
       campos.length > 0 && docs.length > 0,
       campos.length + ' campos y ' + docs.length + ' recaudos', 'formulario con campos y recaudos');
    igual('rnc: pide los ocho datos de la empresa', campos.length, 8);
    igual('rnc: y sus doce recaudos', docs.length, 12);

    /* Un recaudo que ya estaba en la bóveda se reutiliza, pero hay que poder
       MIRARLO antes de enviar: "pasaporte.pdf" puede ser el vencido, y como
       se reutiliza entre trámites el fallo viajaría de uno a otro. */
    (function(){
      var conArchivo = caja.querySelector('.sol-doc[data-ya]');
      ok('recaudos: el que ya estaba en la bóveda se puede mirar',
         !!conArchivo && !!conArchivo.querySelector('.sd-ver'),
         conArchivo ? (conArchivo.querySelector('.sd-ver') ? 'con botón' : 'sin botón')
                    : 'ninguno reutilizado',
         'un botón para verlo');
    })();
    /* Solo uno, y es el único que el SNC marca como condicional: el poder,
       cuando quien firma no es el representante de los estatutos. */
    igual('rnc: solo el poder es opcional',
          caja.querySelectorAll('.sol-doc[data-opcional]').length, 1);
    /* La nómina del RNC no es la del RNET: aquí va la de personal TÉCNICO
       con sus títulos, porque lo que se mide es capacidad técnica. */
    ok('rnc: la nómina es la técnica, no la de trabajadores',
       /personal técnico/i.test(caja.textContent) && !/Nómina de trabajadores/.test(caja.textContent),
       'busca "personal técnico"', 'la técnica y no la otra');

    /* El relleno: la razón social ya viene escrita desde Mi empresa, y el
       campo dice de dónde salió. Sin decirlo, parecería que el panel se
       inventó el dato. */
    (function(){
      var c = document.querySelector('.sol-campo[data-campo="razon_social"]');
      igual('empresa: el formulario llega con la razón social puesta',
            c.querySelector('input').value, 'Bianchi Agroindustrias, C.A.');
      ok('empresa: y dice que salió de tu empresa',
         !!c.querySelector('.de-empresa'),
         c.querySelector('label').textContent, 'con el sello "De tu empresa"');
      var rif = document.querySelector('.sol-campo[data-campo="rif_empresa"] input');
      igual('empresa: y el RIF también', rif ? rif.value : '(no hay campo)', 'J-40123456-7');
    })();

    ok('rnc: los recaudos salen con su nombre, no con su código',
       /Estados financieros auditados/.test(caja.textContent),
       'busca "Estados financieros auditados"', 'aparece');

    /* La escalera del trámite en curso marca dónde vas. El texto vive en
       CIIP_PASOS.aqui, no dentro de ui: buscarlo en el sitio equivocado
       pintaba una etiqueta VACÍA, que en pantalla es un rectángulo de dos
       píxeles y no se lee como un fallo. */
    location.hash = '';
  }

  /* Se mira en el expediente 'lleno', que es el único con una solicitud ya
     enviada: sin solicitud no hay escalera que marcar. */
  /* ═══════════ UN TRÁMITE DEVUELTO SE PUEDE ARREGLAR ═══════════
     La base dejaba corregir un devuelto —su política lo permite— pero la
     pantalla lo enseñaba en solo lectura, y el circuito se cortaba justo
     donde el inversionista tiene que actuar. */
  function devueltoAbre(){
    if (CASO !== 'lleno') return;
    location.hash = 'tramite-c6';
  }

  function devueltoMira(){
    if (CASO !== 'lleno') return;
    var caja = document.getElementById('trReal');

    /* Lo primero, la nota: quien abre el trámite para arreglarlo tiene que
       leer qué falta sin volver atrás a buscarlo en la portada. */
    ok('devuelto: la nota del gestor se lee en el propio trámite',
       /ilegible/.test(caja.textContent),
       'busca la nota dentro del trámite', 'aparece');

    var arreglar = null;
    caja.querySelectorAll('button').forEach(function(b){
      if (b.textContent.trim() === 'Corregir y reenviar') arreglar = b;
    });
    ok('devuelto: y ofrece arreglarlo', !!arreglar,
       arreglar ? 'lo ofrece' : 'no hay botón', 'un botón para corregir');

    if (arreglar){
      arreglar.click();
      var campos = caja.querySelectorAll('.sol-campo');
      ok('devuelto: al pulsarlo vuelve el formulario', campos.length > 0,
         campos.length + ' campos', 'con campos');
      /* Y con lo que ya había escrito: obligarle a teclearlo otra vez sería
         castigarle por un recaudo borroso. */
      var razon = caja.querySelector('.sol-campo[data-campo="razon_social"] input');
      igual('devuelto: y con lo que ya había rellenado',
            razon ? razon.value : '(no está)', 'Bianchi Agroindustrias, C.A.');
    }
    location.hash = '';
  }

  function escaleraAbre(){
    if (CASO !== 'lleno') return;
    location.hash = 'tramite-c3';
  }

  function escaleraMira(){
    if (CASO !== 'lleno') return;
    var aqui = document.querySelector('#trReal .tr-aqui');
    ok('escalera: el paso en curso dice "vas por aquí", y no en blanco',
       !!aqui && aqui.textContent.trim().length > 0,
       aqui ? ('"' + aqui.textContent.trim() + '"') : 'no hay etiqueta',
       'con texto dentro');

    /* Y respira como los demás distintivos del panel. Con 1px de relleno
       salía apretado y parecía un botón a medio hacer. */
    if (aqui){
      var ea = window.getComputedStyle(aqui);
      ok('escalera: y la etiqueta respira, como los demás distintivos',
         parseFloat(ea.paddingTop) >= 3 && aqui.getBoundingClientRect().height >= 16,
         'relleno ' + ea.paddingTop + ', alto ' + aqui.getBoundingClientRect().height.toFixed(1) + 'px',
         'al menos 3px de relleno y 16px de alto');
      /* Y no se sale de su caja. */
      ok('escalera: y su texto cabe dentro',
         aqui.scrollWidth <= aqui.clientWidth + 1,
         aqui.scrollWidth + ' vs ' + aqui.clientWidth, 'sin desbordar');
    }
    location.hash = '';
  }

  function solvenciasAbre(){
    if (CASO !== 'vacio') return;
    location.hash = 'tramite-c14';
  }

  function solvenciasTrasAbrir(){
    if (CASO !== 'vacio') return;
    var caja = document.getElementById('trReal');
    var campos = caja.querySelectorAll('.sol-campo');
    var docs   = caja.querySelectorAll('.sol-doc');

    /* UNA solicitud y no cuatro: son cuatro certificados —laboral, IVSS,
       INCES y municipal— pero se piden con el mismo expediente. */
    ok('solvencias: ya se pueden solicitar', campos.length > 0 && docs.length > 0,
       campos.length + ' campos y ' + docs.length + ' recaudos', 'formulario con los dos');
    igual('solvencias: siete datos', campos.length, 7);
    igual('solvencias: seis recaudos', docs.length, 6);

    /* La autorización solo la pide el INCES cuando el trámite lo lleva
       alguien que no es el representante legal. */
    igual('solvencias: solo la autorización es opcional',
          caja.querySelectorAll('.sol-doc[data-opcional]').length, 1);

    /* La llave de cada solvencia: sin el número patronal y el NIL no hay
       nada que consultar en el sistema del IVSS ni en el del INCES. */
    ok('solvencias: pide el número patronal y el NIL',
       /patronal del IVSS/.test(caja.textContent) && /NIL/.test(caja.textContent),
       'busca "patronal del IVSS" y "NIL"', 'aparecen los dos');

    /* La licencia municipal la emite el c10 y se consume aquí. */
    /* Dos recaudos son cosecha de otros trámites del panel: la licencia la
       emite el c10 y la constancia del RNET el c27. */
    ok('solvencias: y lo que emiten los trámites anteriores',
       /Licencia de actividades económicas/.test(caja.textContent) &&
       /RNET/.test(caja.textContent),
       'busca la licencia y el RNET', 'aparecen los dos');
    /* La solvencia laboral exige estar al día también con BANAVIH. */
    ok('solvencias: pide también el número del FAOV',
       /FAOV/.test(caja.textContent), 'busca "FAOV"', 'aparece');

    location.hash = '';
  }

  /* ═══════════ EL BANCO DE ACTIVOS ═══════════
     La única de las 31 tarjetas que no es un trámite: es el catálogo del
     CIIP y lo que se hace con él es mirarlo. La tabla nace vacía. */
  function activosAbre(){
    document.getElementById('navActivos').click();
  }

  function activosMira(){
    igual('activos: se abre su vista', document.body.getAttribute('data-vista'), 'activos');
    var fichas = document.querySelectorAll('#acLista .ci-ficha');
    var num = document.getElementById('navActivosN');

    if (CASO === 'gestor'){
      /* El equipo publica desde aquí. Mandarlo al editor de tablas de
         Supabase cada vez es pedirle que entre a la base de datos. */
      ok('activos: el equipo tiene con qué publicar',
         !document.getElementById('acNuevo').hidden, 'oculto=' +
         document.getElementById('acNuevo').hidden, 'el botón a la vista');
      igual('activos: y ve también el cerrado', fichas.length, 2);
      /* Un cerrado ya no se ofrece: la política de la base no se lo manda a
         nadie más, y aquí se ve apagado y sin botón de preguntar. */
      var cerr = fichas[1];
      ok('activos: el cerrado se ve como tal',
         cerr.classList.contains('cerrado'), cerr.className, 'con la clase cerrado');
      igual('activos: y lo dice su etiqueta',
            cerr.querySelector('.ct-chip').textContent, 'Cerrado');
      ok('activos: sobre un cerrado no se pregunta',
         !cerr.querySelector('.btn'),
         cerr.querySelector('.btn') ? 'lo ofrece' : 'no lo ofrece', 'sin botón');
      ok('activos: cada ficha se puede editar',
         document.querySelectorAll('#acLista .ac-editar').length === 2,
         document.querySelectorAll('#acLista .ac-editar').length + ' botones', '2 botones');
      /* El contador sigue contando lo que se puede TOMAR. */
      igual('activos: el cerrado no cuenta en el renglón', num.textContent, '1');
      document.getElementById('acVolver').click();
      return;
    }

    if (CASO === 'lleno'){
      igual('activos: enseña los publicados', fichas.length, 2);
      /* Al inversionista no se le enseña por dónde se administra esto. */
      ok('activos: al inversionista no se le ofrece publicar',
         document.getElementById('acNuevo').hidden, 'oculto=' +
         document.getElementById('acNuevo').hidden, 'oculto=true');
      ok('activos: ni editar',
         !document.querySelector('#acLista .ac-editar'),
         document.querySelectorAll('#acLista .ac-editar').length + ' botones', 'ninguno');
      /* El contador cuenta lo que se puede TOMAR: el reservado ya tiene a
         alguien delante. */
      igual('activos: y el renglón cuenta solo los disponibles', num.textContent, '1');
      ok('activos: el destacado va primero',
         /cacao/i.test(fichas[0].textContent), fichas[0].querySelector('.ci-linea').textContent,
         'la planta de cacao');
      /* Sin techo se dice "desde", no una cifra cerrada que no existe. */
      ok('activos: un monto sin techo se anuncia como "desde"',
         /^Desde /.test(fichas[1].querySelector('.ac-monto').textContent),
         fichas[1].querySelector('.ac-monto').textContent, 'empieza por "Desde"');
      ok('activos: y el rango, con sus dos extremos',
         /^Entre /.test(fichas[0].querySelector('.ac-monto').textContent),
         fichas[0].querySelector('.ac-monto').textContent, 'empieza por "Entre"');
      /* Sobre un reservado no se pregunta: ya hay alguien en conversaciones. */
      ok('activos: el reservado no ofrece preguntar',
         !fichas[1].querySelector('.btn'),
         fichas[1].querySelector('.btn') ? 'lo ofrece' : 'no lo ofrece', 'sin botón');
      /* Preguntar por uno es pedir una cita: no hay circuito nuevo. */
      fichas[0].querySelector('.btn').click();
      ok('activos: preguntar por uno abre la ventana de citas',
         document.getElementById('citaBack').classList.contains('open'),
         document.getElementById('citaBack').className, 'con la clase open');
      document.getElementById('ctCerrar').click();
    } else {
      /* La tabla nace vacía y lo dice. Prometer 42 oportunidades que no
         existen es peor que decir que aún no hay ninguna. */
      igual('activos: sin nada publicado, lo dice',
            (document.querySelector('#acLista .ci-vacia') || {}).textContent,
            'Todavía no hay activos publicados. El equipo del CIIP los va cargando.');
      ok('activos: y el renglón no lleva número', num.hidden,
         'oculto=' + num.hidden, 'oculto=true');
    }
    document.getElementById('acVolver').click();
  }

  /* La tabla se llena A MANO, y se llena desde el panel. Estas cuatro
     pruebas son el circuito entero: publicar uno, verlo aparecer, abrirlo
     para corregirlo y ver el cambio en la lista. */
  function activosPublica(){
    if (CASO !== 'gestor') return;
    document.getElementById('navActivos').click();
    document.getElementById('acNuevo').click();

    var back = document.getElementById('activoBack');
    ok('publicar: se abre la ficha', back.classList.contains('open'),
       back.className, 'con la clase open');
    igual('publicar: y viene en blanco', document.getElementById('afTit').value, '');
    ok('publicar: uno nuevo no ofrece borrarse',
       document.getElementById('afBorrar').hidden,
       'oculto=' + document.getElementById('afBorrar').hidden, 'oculto=true');

    /* Sin título la ficha no dice nada, y la base lo rechazaría igual: se
       dice con palabras en vez de con un error de SQL. */
    document.getElementById('afGuardar').click();
    igual('publicar: sin título no se guarda',
          document.getElementById('afAviso').textContent,
          'Ponle un título: sin él la ficha no dice nada.');
    ok('publicar: y se señala el campo',
       document.getElementById('afTit').closest('.pf-campo').classList.contains('mal'),
       document.getElementById('afTit').closest('.pf-campo').className, 'marcado');

    /* Un rango al revés tampoco: es una ficha que nadie podría leer, y la
       base tiene el mismo límite (activos_rango_valido). */
    document.getElementById('afTit').value   = 'Finca cafetalera en produccion';
    document.getElementById('afDesde').value = '900000';
    document.getElementById('afHasta').value = '100000';
    document.getElementById('afGuardar').click();
    igual('publicar: un rango al revés no pasa',
          document.getElementById('afAviso').textContent,
          'El monto de hasta no puede ser menor que el de desde.');

    document.getElementById('afHasta').value   = '1500000';
    document.getElementById('afSector').value  = 'Agroindustria';
    document.getElementById('afUbic').value    = 'Tachira';
    document.getElementById('afResumen').value = 'En produccion, con marca propia.';
    document.getElementById('afGuardar').click();
  }

  function activosTrasPublicar(){
    if (CASO !== 'gestor') return;
    ok('publicar: la ficha se cierra sola',
       !document.getElementById('activoBack').classList.contains('open'),
       document.getElementById('activoBack').className, 'sin la clase open');
    var fichas = document.querySelectorAll('#acLista .ci-ficha');
    igual('publicar: y el nuevo entra en la lista', fichas.length, 3);
    ok('publicar: con su título',
       /Finca cafetalera/.test(document.getElementById('acLista').textContent),
       'busca "Finca cafetalera"', 'aparece');
    /* Recién publicado y disponible: el renglón de la barra lo cuenta. */
    igual('publicar: y el renglón lo cuenta',
          document.getElementById('navActivosN').textContent, '2');
  }

  function activosEdita(){
    if (CASO !== 'gestor') return;
    var fichas = document.querySelectorAll('#acLista .ci-ficha');
    /* El cerrado es el último: no está destacado y es el más viejo. */
    fichas[2].querySelector('.ac-editar').click();
    igual('editar: la ficha se abre con otro título',
          document.getElementById('afTitulo').textContent, 'Editar el activo');
    igual('editar: y con lo que ya había dentro',
          document.getElementById('afTit').value, 'Hotel de playa en remodelacion');
    igual('editar: incluido su estado',
          document.getElementById('afEstado').value, 'cerrado');
    /* Se vuelve a abrir: un cerrado no es una fila muerta. */
    document.getElementById('afEstado').value = 'disponible';
    document.getElementById('afGuardar').click();
  }

  function activosTrasEditar(){
    if (CASO !== 'gestor') return;
    var textos = [].map.call(document.querySelectorAll('#acLista .ci-ficha'),
                             function(f){ return f.textContent; }).join(' | ');
    ok('editar: el cambio se ve en la lista',
       !/Hotel de playa en remodelacion[^|]*Cerrado/.test(textos) &&
       /Hotel de playa/.test(textos), 'el hotel ya no está cerrado', 'reabierto');
    igual('editar: y el renglón vuelve a contar',
          document.getElementById('navActivosN').textContent, '3');
    document.getElementById('acVolver').click();
  }

  /* Borrar es lo único de esta ventana que no se puede deshacer, así que
     pide dos toques. Y no una ventana del navegador: esas salen fuera de la
     página, se leen a medias y se cierran por costumbre. */
  function activosBorra(){
    if (CASO !== 'gestor') return;
    document.getElementById('navActivos').click();

    var fichas = [].slice.call(document.querySelectorAll('#acLista .ci-ficha'));
    var finca = fichas.filter(function(f){ return /Finca cafetalera/.test(f.textContent); })[0];
    finca.querySelector('.ac-editar').click();

    var bo = document.getElementById('afBorrar');
    ok('borrar: uno que ya existe sí se puede borrar', !bo.hidden,
       'oculto=' + bo.hidden, 'a la vista');

    /* Primer toque: avisa y NO borra. */
    bo.click();
    igual('borrar: el primer toque solo avisa',
          document.getElementById('afAviso').textContent,
          'Se borra de verdad y no se puede deshacer. Si solo quieres retirarlo, ponlo en Cerrado.');
    igual('borrar: y cambia lo que dice el botón', bo.textContent, 'Pulsa otra vez para borrarlo');
    igual('borrar: el activo sigue ahí',
          document.querySelectorAll('#acLista .ci-ficha').length, 3);

    bo.click();   /* el segundo toque sí */
  }

  function activosTrasBorrar(){
    if (CASO !== 'gestor') return;
    ok('borrar: la ficha se cierra sola',
       !document.getElementById('activoBack').classList.contains('open'),
       document.getElementById('activoBack').className, 'sin la clase open');
    igual('borrar: y sale de la lista',
          document.querySelectorAll('#acLista .ci-ficha').length, 2);
    ok('borrar: con su título',
       !/Finca cafetalera/.test(document.getElementById('acLista').textContent),
       'busca "Finca cafetalera"', 'ya no aparece');
    igual('borrar: y el renglón baja',
          document.getElementById('navActivosN').textContent, '2');

    /* Cerrarla desarma: nadie vuelve a encontrarse un botón cargado. */
    var fichas = document.querySelectorAll('#acLista .ci-ficha');
    fichas[0].querySelector('.ac-editar').click();
    igual('borrar: al reabrir, el botón vuelve a estar en reposo',
          document.getElementById('afBorrar').textContent, 'Borrar');
    document.getElementById('afCerrar').click();
    document.getElementById('acVolver').click();
  }

  /* ═══════════ LO QUE SE ENTREGA AL FINAL ═══════════
     El circuito acababa en el aire: el gestor pulsaba "Resuelta", el estado
     cambiaba, y el documento —lo único que la persona vino a buscar— se
     mandaba por fuera. Ningún expediente de prueba tenía un trámite
     resuelto, y por eso no lo notó nadie. */
  function entregaAbre(){
    if (CASO !== 'lleno') return;
    location.hash = 'tramite-c1';
  }

  function entregaMira(){
    if (CASO !== 'lleno') return;
    var b = document.querySelector('#trReal .tr-entrega');
    ok('entrega: el trámite resuelto enseña lo que se emitió', !!b,
       b ? 'la enseña' : 'no hay caja', 'una caja con el documento');
    igual('entrega: con su título', b.querySelector('.te-t').textContent.trim(), 'Tu documento');
    igual('entrega: y el archivo que dejó el equipo',
          b.querySelector('.te-n').textContent.trim(), 'visa-tr1-estampada.pdf');
    ok('entrega: con un botón para abrirlo', !!b.querySelector('.btn'),
       b.querySelector('.btn') ? 'lo tiene' : 'sin botón', 'con botón');
    /* Encima de la escalera: quien abre un trámite terminado viene a por el
       papel, no a repasar por dónde pasó. */
    var pasos = document.querySelector('#trReal .tr-pasos');
    ok('entrega: y va encima de la escalera',
       !!pasos && (b.compareDocumentPosition(pasos) & Node.DOCUMENT_POSITION_FOLLOWING) !== 0,
       'la caja va antes', 'antes de los pasos');
    location.hash = '';
  }

  /* ═══════════ USUARIOS Y EQUIPO ═══════════
     Hasta ahora, para hacer gestor a alguien había que entrar a Supabase y
     escribir un update: el CIIP dependía de una persona con la llave de la
     base de datos. */
  function usuariosMira(){
    if (SIN_SQL || ES_ADMIN) return;
    var grupo = document.getElementById('grupoAdmin');
    /* Grupo propio, no colgado del de al lado: el aire entre grupos lo pone
       ese contenedor, y metido dentro del vecino dejaba "ACOMPAÑAMIENTO"
       pegado al renglón de arriba. */
    ok('usuarios: el grupo es hermano de los demás, no hijo de uno',
       grupo.classList.contains('sb-group') && grupo.parentNode.classList.contains('sb-nav'),
       grupo.className + ' dentro de ' + grupo.parentNode.className, 'sb-group dentro de sb-nav');
    /* El renglón solo se le ofrece a un admin. Es cortesía, no la
       cerradura: la base vuelve a comprobar quién pide el cambio. */
    if (CASO !== 'gestor'){
      ok('usuarios: a quien no es admin no se le ofrece',
         grupo.hidden, 'oculto=' + grupo.hidden, 'oculto=true');
      return;
    }
    /* El expediente 'gestor' tiene rol gestor, no admin: tampoco lo ve. */
    ok('usuarios: ni siquiera a un gestor',
       grupo.hidden, 'oculto=' + grupo.hidden, 'oculto=true');

    /* Se entra igual por la dirección, y la vista se pinta: lo que impide
       el cambio es la base, no que el renglón no esté. */
    location.hash = 'usuarios';
  }

  function usuariosCambia(){
    if (CASO !== 'gestor' || SIN_SQL || ES_ADMIN) return;
    igual('usuarios: la vista se abre por su dirección',
          document.body.getAttribute('data-vista'), 'usuarios');

    var m = document.querySelectorAll('#usMetricas .us-m');
    igual('usuarios: con los cinco números de arriba', m.length, 5);
    igual('usuarios: y cuentan las cuentas de verdad',
          m[0].querySelector('.n').textContent, '4');
    /* De los cuatro expedientes solo uno tiene el panel abierto ahora:
       los otros son de hace veinte minutos, de hace tres días y de nunca. */
    igual('usuarios: y cuántos tienen el panel abierto ahora',
          m[1].querySelector('.n').textContent, '1');

    var fichas = document.querySelectorAll('#usLista .ci-ficha');
    igual('usuarios: están las cuatro cuentas', fichas.length, 4);
    /* El equipo primero: quien abre esto viene a mirar quién tiene
       permisos, no a repasar inversionistas. */
    igual('usuarios: el equipo va primero',
          document.querySelector('#usLista .us-sec').textContent.trim(), 'El equipo');
    ok('usuarios: y una cuenta sin nombre lo dice',
       /\(sin nombre en su expediente\)/.test(document.getElementById('usLista').textContent),
       'busca "(sin nombre en su expediente)"', 'aparece');

    /* ── EN LÍNEA ── Que no es una conexión: es cuándo estuvo abierto el
       panel. Las tres formas de decirlo tienen que salir las tres, porque
       las tres pasan de verdad. */
    var pres = document.querySelectorAll('#usLista .us-presencia');
    igual('presencia: cada cuenta dice cuándo se la vio', pres.length, 4);

    function presDe(nombre){
      var f = [].slice.call(fichas).filter(function(x){
        return new RegExp(nombre).test(x.textContent); })[0];
      return f && f.querySelector('.us-presencia');
    }
    var pFr = presDe('Franklin Reyes');
    ok('presencia: quien tiene el panel abierto sale en verde',
       pFr && pFr.classList.contains('aqui') && /En línea/.test(pFr.textContent),
       pFr ? pFr.textContent : 'no la encuentro', 'En línea');

    var pMa = presDe('Marta Bianchi');
    ok('presencia: quien no, dice desde cuándo',
       pMa && !pMa.classList.contains('aqui') && /hace 3 días|anteayer/.test(pMa.textContent),
       pMa ? pMa.textContent : 'no la encuentro', 'Visto hace 3 días');
    /* Veinte minutos son más de tres: NO está en línea. Sin esta
       comprobación, un umbral mal puesto dejaría a todo el mundo dentro. */
    var pSa = presDe('Saskia Calderon');
    ok('presencia: veinte minutos ya no es "ahora"',
       pSa && !pSa.classList.contains('aqui') && /hace 20 min/.test(pSa.textContent),
       pSa ? pSa.textContent : 'no la encuentro', 'Visto hace 20 minutos');

    var pNu = presDe('sin nombre en su expediente');
    ok('presencia: y quien nunca entró, lo dice sin inventar fecha',
       pNu && /No ha entrado todavía/.test(pNu.textContent),
       pNu ? pNu.textContent : 'no la encuentro', 'No ha entrado todavía');

    /* Y el latído: si el panel no lo apunta, la columna entera se queda
       en "no ha entrado todavía" para todos, para siempre. */
    ok('presencia: el panel apunta que sigue abierto',
       (window.CIIP_RPC || []).indexOf('tocar_visto') >= 0,
       'rpc pedidos: ' + JSON.stringify(window.CIIP_RPC || []), 'tocar_visto');

    /* La tuya no se toca: el desplegable llega apagado y lo dice. */
    var mia = [].slice.call(fichas).filter(function(f){ return /Tu cuenta/.test(f.textContent); })[0];
    ok('usuarios: tu propia cuenta no ofrece cambiarse', !!mia && mia.querySelector('select').disabled,
       mia ? ('apagado=' + mia.querySelector('select').disabled) : 'no la encuentro', 'apagado=true');
    ok('usuarios: y explica por qué',
       /Nadie cambia su propio rol/.test(mia.textContent),
       'busca el motivo', 'lo dice');

    /* Y ahora sí: subir a alguien. */
    var otra = [].slice.call(fichas).filter(function(f){ return /Marta Bianchi/.test(f.textContent); })[0];
    var sel = otra.querySelector('select');
    igual('usuarios: llega con el rol que tiene', sel.value, 'inversionista');
    sel.value = 'gestor';
    sel.dispatchEvent(new Event('change'));
  }

  function usuariosTrasCambiar(){
    if (CASO !== 'gestor' || SIN_SQL || ES_ADMIN) return;
    var t = document.getElementById('usLista').textContent;
    ok('usuarios: el cambio se guarda y se dice', /Rol cambiado|Rol puesto/.test(t),
       'busca "Rol cambiado"', 'lo dice');

    /* Y la tarjeta YA lo dice, en el mismo momento. Mientras esto no
       cuadraba, la pantalla se contradecia sola: el aviso daba el cambio
       por hecho y el distintivo de al lado seguía diciendo el rol
       viejo. Nadie confia en una pantalla que se lleva la contraria. */
    var m0 = [].slice.call(document.querySelectorAll('#usLista .ci-ficha')).filter(function(f){
      return /Marta Bianchi/.test(f.textContent); })[0];
    /* El distintivo, no el texto entero: el desplegable lleva los tres
       roles escritos como opciones, y buscar "Inversionista" en toda la
       tarjeta lo encuentra siempre. */
    var chip0 = m0 && m0.querySelector('.ct-chip');
    var sel0  = m0 && m0.querySelector('select');
    ok('usuarios: y la tarjeta no se contradice mientras tanto',
       chip0 && chip0.textContent.trim() === 'Equipo CIIP' && sel0.value === 'gestor',
       chip0 ? ('distintivo=' + chip0.textContent.trim() + ' desplegable=' + sel0.value)
             : 'no la encuentro',
       'distintivo=Equipo CIIP desplegable=gestor');
  }

  /* ═══════════ EL RENGLÓN DEL ADMINISTRADOR ═══════════
     Este pase faltaba, y su falta costó caro: ningún expediente entraba
     con rol admin, así que el renglón solo se probaba por su AUSENCIA. Un
     permiso que solo se comprueba cuando no toca no está comprobado.

     Lo que escondía: el panel apunta el perfil dos veces —primero lo que
     trae la sesión, sin rol, y después la fila de perfiles, que es la
     única que lo sabe— y el reloj que espera al rol se rendía en la
     primera. El renglón no salía nunca por mucho que la base dijera
     admin. */
  function adminMira(){
    if (!ES_ADMIN) return;
    var grupo = document.getElementById('grupoAdmin');
    ok('admin: a un administrador SÍ se le ofrece el renglón',
       !grupo.hidden, 'oculto=' + grupo.hidden, 'oculto=false');
    /* Y con el rol puesto, no con el de la sesión vacía. */
    igual('admin: la cabecera lo dice también',
          document.querySelector('.u-sub').textContent.indexOf('Administrador') >= 0, true);
  }

  function adminAbre(){
    if (!ES_ADMIN) return;
    document.getElementById('navUsuarios').click();
  }

  function adminDentro(){
    if (!ES_ADMIN) return;
    igual('admin: el renglón abre la vista',
          document.body.getAttribute('data-vista'), 'usuarios');
    var f = document.querySelectorAll('#usLista .ci-ficha');
    igual('admin: con las cuentas dentro', f.length, 4);

    /* ── EN REJILLA ── Una ficha de usuario son cuatro renglones cortos, y
       en columna sobraba media pantalla a lo ancho: una oficina de quince
       personas se recorría con la rueda del ratón. */
    var arriba = {};
    [].forEach.call(f, function(x){
      var y = Math.round(x.getBoundingClientRect().top);
      arriba[y] = (arriba[y] || 0) + 1;
    });
    var masEnUnaFila = Math.max.apply(null, Object.keys(arriba).map(function(k){ return arriba[k]; }));
    ok('rejilla: en pantalla ancha las cuentas van una al lado de otra',
       masEnUnaFila >= 2, 'lo más que comparten fila: ' + masEnUnaFila, '2 o más');
    /* El rótulo de sección cruza entero: es el techo de lo que viene
       debajo, no una ficha más metida en la fila. */
    var sec = document.querySelector('#usLista .us-sec');
    ok('rejilla: y el rótulo de sección cruza de lado a lado',
       Math.round(sec.getBoundingClientRect().width) >
       Math.round(f[0].getBoundingClientRect().width) + 20,
       'rótulo ' + Math.round(sec.getBoundingClientRect().width) +
       ' vs ficha ' + Math.round(f[0].getBoundingClientRect().width), 'el rótulo, más ancho');
    /* Y ninguna se sale por la derecha: 280px de mínimo con la barra
       lateral puesta es justo donde esto se rompería. */
    var caja = document.getElementById('usLista').getBoundingClientRect();
    var desborda = [].filter.call(f, function(x){
      return x.getBoundingClientRect().right > caja.right + 1; });
    igual('rejilla: y ninguna se sale por la derecha', desborda.length, 0);

    location.hash = '';
  }

  /* ═══════════ F5 SOBRE UNA VISTA QUE PIDE DATOS ═══════════
     Pulsando el renglón no se notaba: para entonces hacía rato que la
     sesión estaba puesta. Pero con F5 sobre #usuarios el router corre
     durante la carga, la consulta sale SIN sesión y las políticas
     contestan con cero filas —sin error—. La vista decía "no hay ninguna
     cuenta que enseñar" y era mentira: había cuatro.

     Aquí se recrea ese momento apagando la señal de "el rol ya llegó". */
  var f5Antes = null;
  function f5Entra(){
    if (!ES_ADMIN) return;
    f5Antes = PERFIL.rolReal;
    PERFIL.rolReal = false;
    document.getElementById('usLista').textContent = '';
    location.hash = 'usuarios';
  }

  function f5Espera(){
    if (!ES_ADMIN) return;
    /* Lo que NO tiene que pasar: dar por vacía una lista que aún no se ha
       podido pedir. Callarse es la respuesta correcta mientras tanto. */
    var t = document.getElementById('usLista').textContent;
    ok('F5: sin sesión todavía, no declara que no hay nadie',
       t.indexOf('No hay ninguna cuenta') < 0, t.slice(0, 60) || '(vacía)', 'sin ese mensaje');
    PERFIL.rolReal = f5Antes;
  }

  function f5Llega(){
    if (!ES_ADMIN) return;
    igual('F5: y en cuanto la sesión está, salen las cuentas',
          document.querySelectorAll('#usLista .ci-ficha').length, 4);
    location.hash = '';
  }

  /* ═══════════ F5 CUANDO EL MÓDULO AÚN NO SE HA PRESENTADO ═══════════
     El punto ciego de la prueba de arriba, y por eso el fallo siguió vivo
     después de darlo por arreglado: aquella apagaba la señal de la sesión
     con el módulo YA registrado, que no es lo que pasa al recargar.

     Al recargar sobre #usuarios el router corre durante la carga, y estos
     módulos se registran más abajo en el mismo guión: window.CIIP_PINTA_
     USUARIOS todavía no existía. La llamada se saltaba en silencio y la
     vista se quedaba diciendo que no había ninguna cuenta. Había cuatro. */
  var f5Fn = null;
  function f5TardeEntra(){
    if (!ES_ADMIN) return;
    f5Fn = window.CIIP_PINTA_USUARIOS;
    delete window.CIIP_PINTA_USUARIOS;      /* como durante la carga */
    document.getElementById('usLista').textContent = '';
    location.hash = 'usuarios';
  }

  function f5TardeEspera(){
    if (!ES_ADMIN) return;
    var t = document.getElementById('usLista').textContent;
    ok('F5 tardío: sin el módulo puesto, no declara que no hay nadie',
       t.indexOf('No hay ninguna cuenta') < 0, t.slice(0, 60) || '(vacía)', 'sin ese mensaje');
    window.CIIP_PINTA_USUARIOS = f5Fn;      /* el módulo se presenta */
  }

  function f5TardeLlega(){
    if (!ES_ADMIN) return;
    igual('F5 tardío: y en cuanto se presenta, carga sin que nadie lo pida',
          document.querySelectorAll('#usLista .ci-ficha').length, 4);
    location.hash = '';
  }

  /* ═══════════ EL CÓDIGO POR DELANTE DE LA BASE ═══════════
     Pasó de verdad: el panel empezó a pedir visto_en y rol_cambiado_en, y
     en una base sin esos dos archivos corridos Postgres rechazó la
     consulta ENTERA. La vista se quedó en blanco —ni equipo, ni
     inversionistas, ni un aviso— y pareció que el panel se había roto.

     Una función nueva no puede apagar lo que ya servía. */
  function sinSqlAbre(){
    if (!SIN_SQL) return;
    location.hash = 'usuarios';
  }

  function sinSqlMira(){
    if (!SIN_SQL) return;
    var fichas = document.querySelectorAll('#usLista .ci-ficha');
    igual('sin sql: las cuentas salen igual, sin las columnas nuevas', fichas.length, 4);
    ok('sin sql: y con sus nombres',
       /Marta Bianchi/.test(document.getElementById('usLista').textContent),
       'busca a Marta', 'está');
    /* Y no se inventa presencia: sin la columna, decir "no ha entrado
       todavía" de los cuatro sería mentira, no un hueco. */
    igual('sin sql: y sin inventarse quién estuvo en línea',
          document.querySelectorAll('#usLista .us-presencia').length, 0);
    var m = document.querySelectorAll('#usMetricas .us-m');
    igual('sin sql: el número de en línea se queda en raya',
          m[1].querySelector('.n').textContent, '—');
    /* Y el desplegable de roles sigue ahí: cambiar un rol no dependía de
       ninguna de las dos columnas. */
    ok('sin sql: y los roles se siguen pudiendo cambiar',
       !!fichas[0].querySelector('select'), 'hay desplegable', 'lo hay');
    location.hash = '';
  }

  /* Guardar no es enseñar. El aviso de "rol cambiado" salía enseguida,
     pero la tarjeta se quedaba con su distintivo viejo y en su sección
     vieja hasta que la lista se repintaba —y nadie comprobaba que se
     repintase—. Quien lo hacía veía "hecho" y una pantalla que decía lo
     contrario, y acababa recargando a ver si esta vez sí. */
  function usuariosSeMueve(){
    if (CASO !== 'gestor' || SIN_SQL || ES_ADMIN) return;
    var lista = document.getElementById('usLista');
    var marta = [].slice.call(lista.querySelectorAll('.ci-ficha')).filter(function(f){
      return /Marta Bianchi/.test(f.textContent); })[0];
    ok('usuarios: y la tarjeta pasa a decir el rol nuevo',
       marta && /Equipo CIIP/.test(marta.textContent),
       marta ? marta.textContent.slice(0, 40) : 'no la encuentro', 'Equipo CIIP');
    /* Y cambia de sección: quien sube a gestor deja de estar entre los
       inversionistas. Si no, la lista se contradice a sí misma. */
    var secciones = [].slice.call(lista.children);
    var iEquipo = secciones.findIndex(function(x){ return /El equipo/.test(x.textContent) && x.classList.contains('us-sec'); });
    var iTodos  = secciones.findIndex(function(x){ return /Todas las cuentas/.test(x.textContent) && x.classList.contains('us-sec'); });
    var iMarta  = secciones.indexOf(marta);
    ok('usuarios: y sube a la sección del equipo',
       iMarta > iEquipo && (iTodos < 0 || iMarta < iTodos),
       'equipo=' + iEquipo + ' marta=' + iMarta + ' todos=' + iTodos,
       'entre El equipo y Todas las cuentas');
    /* Y el número de arriba, que contaba tres del equipo y ahora son
       cuatro... o lo que toque. Lo que no puede es quedarse como estaba. */
    var m = document.querySelectorAll('#usMetricas .us-m');
    igual('usuarios: las cuentas siguen siendo las mismas cuatro',
          m[0].querySelector('.n').textContent, '4');
    location.hash = '';
  }

  /* ═══════════ MI EMPRESA ═══════════
     La razón social se escribía a mano en ocho formularios, el RIF en seis,
     la dirección fiscal en cinco. Y escribir ocho veces el mismo nombre es
     escribirlo ocho veces distintas. */
  function empresaAbre(){
    document.getElementById('navEmpresa').click();
  }

  function empresaMira(){
    igual('empresa: el renglón abre su vista', document.body.getAttribute('data-vista'), 'empresa');

    if (CASO === 'lleno' || CASO === 'vacio'){
      var t = document.querySelector('#emCuerpo .em-tarjeta');
      ok('empresa: enseña la que tienes registrada', !!t,
         t ? 'la enseña' : 'no hay tarjeta', 'una tarjeta');
      igual('empresa: con su razón social',
            t.querySelector('.em-nombre').textContent.trim(), 'Bianchi Agroindustrias, C.A.');
      igual('empresa: y su RIF', t.querySelector('.em-rif').textContent.trim(), 'J-40123456-7');
      /* Solo lo escrito: dos de los doce campos vienen vacíos y no pintan
         un renglón con una raya, que escondería lo que sí hay. */
      igual('empresa: y solo los datos que tiene escritos',
            t.querySelectorAll('.em-dato').length, 8);

      /* Y repartidos por los MISMOS tres apartados que el formulario. En
         una sola tira había que leer los doce para encontrar uno: el
         teléfono aparecía entre la fecha de constitución y el número de
         trabajadores. Y si el formulario los agrupa y la ficha no, el
         mismo dato vive en dos órdenes distintos. */
      var secs = [].map.call(t.querySelectorAll('.em-sec'),
                             function(x){ return x.textContent.trim(); });
      igual('empresa: la ficha usa los mismos apartados que el formulario',
            secs.join(' | '), 'La empresa | Actividad | Dónde y quién');

      /* Cada dato bajo el suyo, no bajo el que le toque por orden. */
      var bajoQue = function(clave){
        var d = [].filter.call(t.querySelectorAll('.em-dato'), function(x){
          return x.querySelector('.k').textContent.trim() === clave; })[0];
        if (!d) return '(no está)';
        var p = d.parentNode.previousElementSibling;
        return p ? p.textContent.trim() : '(sin apartado)';
      };
      igual('empresa: y el teléfono cae en su apartado',
            bajoQue('Teléfono'), 'Dónde y quién');
      igual('empresa: y la fecha de constitución en el suyo',
            bajoQue('Fecha de constitución'), 'La empresa');
      ok('empresa: el botón ofrece editarla',
         document.getElementById('emBoton').textContent.trim() === 'Editar',
         document.getElementById('emBoton').textContent, 'Editar');
    } else {
      igual('empresa: sin registrar, lo dice',
            (document.querySelector('#emCuerpo .ci-vacia') || {}).textContent,
            'Todavía no has registrado tu empresa. Cuando lo hagas, los formularios que pidan estos datos te los ofrecerán ya escritos.');
      igual('empresa: y ofrece registrarla',
            document.getElementById('emBoton').textContent.trim(), 'Registrar mi empresa');
    }
  }

  function empresaGuarda(){
    if (CASO !== 'gestor') return;
    document.getElementById('emBoton').click();
    ok('empresa: la ficha se abre', document.getElementById('empresaBack').classList.contains('open'),
       document.getElementById('empresaBack').className, 'con la clase open');

    /* ── DE CINCO EN CINCO ── Los doce campos EXISTEN todos desde el
       principio; lo que cambia es cual se enseña. Crearlos por pasos
       habría borrado lo escrito al ir y volver, que es justo lo que hace
       odioso un formulario por pasos. */
    igual('empresa: los doce campos siguen ahí',
          document.querySelectorAll('#emCampos .pf-campo').length, 12);
    var visibles = function(){
      return [].filter.call(document.querySelectorAll('#emCampos .pf-campo'),
                            function(c){ return !c.hidden; });
    };
    igual('empresa: pero solo se ven los cinco del primer paso', visibles().length, 5);

    /* La tira de arriba: sin ella, partir el formulario solo escondería
       campos. Lo que convierte "menos campos" en "vas por aquí" es ver los
       tres de un vistazo y cuál es el tuyo. */
    var pasos = document.querySelectorAll('#emTira .em-paso');
    igual('empresa: con los tres pasos a la vista', pasos.length, 3);
    igual('empresa: y con sus nombres, no solo números',
          [].map.call(pasos, function(p){ return p.querySelector('.t').textContent.trim(); }).join(' | '),
          'La empresa | Actividad | Dónde y quién');
    ok('empresa: el primero es el que está marcado',
       pasos[0].classList.contains('aqui') && !pasos[1].classList.contains('aqui'),
       pasos[0].className + ' / ' + pasos[1].className, 'solo el primero con "aqui"');
    igual('empresa: y el pie dice por dónde vas',
          document.getElementById('emCuenta').querySelector('b').textContent.trim(), 'Paso 1 de 3');

    /* En los dos primeros el botón adelanta, no guarda. Decir "Guardar"
       en el paso 1 y no guardar es mentirle a quien lo pulsa. */
    igual('empresa: y el botón dice que adelanta, no que guarda',
          document.getElementById('emGuardar').textContent.trim(), 'Siguiente');
    ok('empresa: y no hay "Atrás" desde el primero',
       document.getElementById('emAtras').hidden, 'oculto', 'oculto');
    igual('empresa: el de cancelar sigue diciendo lo suyo',
          document.getElementById('emCancelar').textContent.trim(), 'Cancelar');

    /* El pie a la vista: con cinco campos ya no hace falta que el cuerpo
       ruede, pero el botón tiene que seguir dentro de la pantalla. */
    (function(){
      var r = document.getElementById('emGuardar').getBoundingClientRect();
      ok('empresa: y el botón dentro de la pantalla',
         r.bottom > 0 && r.bottom <= window.innerHeight + 1,
         'acaba en ' + Math.round(r.bottom) + ' y la ventana mide ' + window.innerHeight,
         'dentro');
    })();

    /* Las etiquetas son las MISMAS que usan los formularios de los
       trámites: si divergieran, el mismo dato tendría dos nombres. */
    igual('empresa: y con las etiquetas de los formularios',
          document.querySelector('label[for="em_razon_social"]').textContent.trim(), 'Razón social');
    /* La forma del RIF a la vista ahorra una devolución por un dígito. */
    igual('empresa: el RIF enseña su forma',
          document.getElementById('em_rif_empresa').placeholder, 'J-00000000-0');

    /* Lo único obligatorio es la razón social, y no se puede pasar de
       paso sin ella: descubrir en el tercero que falta algo del primero es
       lo que hace que la gente abandone. */
    document.getElementById('emGuardar').click();
    igual('empresa: sin razón social no se pasa de paso',
          document.getElementById('emAviso').textContent,
          'Ponle al menos la razón social: es lo que se copia en los formularios.');
    igual('empresa: y sigue en el primero',
          document.getElementById('emCuenta').querySelector('b').textContent.trim(), 'Paso 1 de 3');

    document.getElementById('em_razon_social').value = 'Cacao del Tuy, C.A.';
    document.getElementById('em_rif_empresa').value  = 'J-40987654-3';
    document.getElementById('emGuardar').click();

    igual('empresa: con ella puesta, adelanta',
          document.getElementById('emCuenta').querySelector('b').textContent.trim(), 'Paso 2 de 3');
    igual('empresa: y enseña los del segundo', visibles().length, 3);
    ok('empresa: ahora sí hay "Atrás"',
       !document.getElementById('emAtras').hidden, 'a la vista', 'a la vista');

    /* Ir y volver NO puede borrar lo escrito. */
    document.getElementById('emAtras').click();
    igual('empresa: "Atrás" vuelve al primero',
          document.getElementById('emCuenta').querySelector('b').textContent.trim(), 'Paso 1 de 3');
    igual('empresa: y lo escrito sigue ahí',
          document.getElementById('em_razon_social').value, 'Cacao del Tuy, C.A.');

    /* Un paso ya andado se pulsa y se vuelve a él: corregir un dato de
       dos pasos atrás no puede costar dos "Atrás". */
    document.getElementById('emGuardar').click();
    document.getElementById('emGuardar').click();
    igual('empresa: y en el tercero el botón ya guarda',
          document.getElementById('emGuardar').textContent.trim(), 'Guardar');
    igual('empresa: con los cuatro del último paso', visibles().length, 4);
    var p1 = document.querySelectorAll('#emTira .em-paso')[0];
    ok('empresa: y el primero se puede pulsar para volver',
       p1.classList.contains('hecho') && p1.classList.contains('pulsable'),
       p1.className, 'hecho y pulsable');
    p1.click();
    igual('empresa: pulsarlo vuelve al primero',
          document.getElementById('emCuenta').querySelector('b').textContent.trim(), 'Paso 1 de 3');

    /* ── SALIR ANTES ── Lo unico obligatorio es la razon social, asi
       que obligar a recorrer doce campos para registrar una empresa era
       pedir un rato que casi nadie tiene en ese momento. */
    var ya = document.getElementById('emGuardarYa');
    ok('empresa: con lo minimo puesto, ofrece guardar ya',
       !ya.hidden && /Guardar y seguir después/.test(ya.textContent),
       ya.hidden ? '(oculto)' : ya.textContent, 'Guardar y seguir después');

    /* Y lo dice ANTES de empezar, no al final: al final ya te lo has
       escrito todo y enterarte entonces no sirve de nada. */
    var mn = document.getElementById('emMinimo');
    ok('empresa: y lo avisa desde el primer paso',
       mn && !mn.hidden && /basta para guardar/.test(mn.textContent),
       mn ? mn.textContent.slice(0, 45) : 'no existe', 'lo avisa');

    /* El contador de los doce, que es el unico que dice cuanto falta de
       verdad: "paso 1 de 3" no distingue entre uno escrito y doce. */
    ok('empresa: y cuenta cuantos de los doce llevas',
       /2 de 12 escritos/.test(document.getElementById('emCuenta').textContent),
       document.getElementById('emCuenta').querySelector('b').textContent.trim(), '2 de 12 escritos');

    /* En el ultimo paso el atajo NO sale: alli "Guardar" ya es
       exactamente eso, y dos botones que hacen lo mismo confunden. */
    document.getElementById('emGuardar').click();
    document.getElementById('emGuardar').click();
    ok('empresa: en el ultimo paso el atajo sobra y no sale',
       document.getElementById('emGuardarYa').hidden, 'oculto', 'oculto');
    document.querySelectorAll('#emTira .em-paso')[0].click();

    /* Y guarda desde el paso 1, sin pasar por los otros dos. */
    document.getElementById('emGuardarYa').click();
  }

  function empresaTrasGuardar(){
    if (CASO !== 'gestor') return;
    ok('empresa: al guardar se cierra la ficha',
       !document.getElementById('empresaBack').classList.contains('open'),
       document.getElementById('empresaBack').className, 'sin la clase open');
    igual('empresa: y la tarjeta ya la enseña',
          document.querySelector('#emCuerpo .em-nombre').textContent.trim(), 'Cacao del Tuy, C.A.');
    document.getElementById('emVolver').click();
  }

  /* ═══════════ LA BÓVEDA ═══════════
     Los recaudos ya se guardaban y se reutilizaban entre trámites. Lo que
     faltaba era verlos todos, y saber cuál está vencido antes de que te lo
     diga un ente devolviéndote la solicitud. */
  function docsAbre(){
    document.getElementById('navDocs').click();
  }

  function docsMira(){
    igual('bóveda: el renglón abre su vista', document.body.getAttribute('data-vista'), 'documentos');

    var fichas = document.querySelectorAll('#dcLista .ci-ficha');
    igual('bóveda: están los tres documentos', fichas.length, 3);
    igual('bóveda: y el renglón los cuenta',
          document.getElementById('navDocsN').textContent, '3');

    /* Lo caducado primero: es lo único de esta lista sobre lo que hay algo
       que hacer. */
    igual('bóveda: el vencido va el primero',
          fichas[0].querySelector('.ct-chip').textContent.trim(), 'Vencido');
    ok('bóveda: y se enmarca como una devolución',
       fichas[0].classList.contains('vencido'), fichas[0].className, 'con la clase vencido');

    /* Treinta días de aviso: el que vence dentro de doce ya lo dice. */
    var textos = [].map.call(fichas, function(f){ return f.textContent; }).join(' | ');
    ok('bóveda: avisa del que está por vencer antes de que venza',
       /Vence pronto/.test(textos), 'busca "Vence pronto"', 'aparece');

    /* El tipo se enseña con su nombre, no con el código interno. Ese
       nombre ya estaba escrito, repartido por los trámites que lo piden. */
    ok('bóveda: cada uno con su nombre, no con su código',
       /Acta constitutiva/i.test(textos) && !/acta_constitutiva/.test(textos),
       'busca "Acta constitutiva" y no "acta_constitutiva"', 'el nombre');
    ok('bóveda: y con el nombre del archivo que subiste',
       /acta-constitutiva\.pdf/.test(textos), 'busca "acta-constitutiva.pdf"', 'aparece');

    /* En cuántos trámites se usa: es lo que la convierte en bóveda y no en
       una carpeta de descargas. */
    ok('bóveda: dice en cuántos trámites se usa cada uno',
       /Se usa en 2 trámites/.test(textos), 'busca "Se usa en 2 trámites"', 'aparece');
    ok('bóveda: y cuando no se usa en ninguno, lo dice',
       /Todavía no se ha usado/.test(textos), 'busca "Todavía no se ha usado"', 'aparece');

    ok('bóveda: cada uno se puede abrir', fichas.length === document.querySelectorAll('#dcLista .btn').length,
       document.querySelectorAll('#dcLista .btn').length + ' botones', '3 botones');

    document.getElementById('dcVolver').click();
  }

  /* ═══════════ AYUDA Y GUÍA ═══════════
     El renglón se iluminaba y no llevaba a ninguna parte. Lo que faltaba no
     eran más preguntas sobre invertir en Venezuela —esas ya están en la
     portada— sino quién explica cómo funciona el panel. */
  function ayudaAbre(){
    document.getElementById('navAyuda').click();
  }

  function ayudaMira(){
    igual('ayuda: el renglón abre su vista', document.body.getAttribute('data-vista'), 'ayuda');
    var bloques = document.querySelectorAll('#ayLista .ay-bloque');
    igual('ayuda: con sus cinco apartados', bloques.length, 5);

    /* Los cuatro pasos NO se escriben en la ayuda: salen de donde ya
       estaban, para que no puedan contradecir a la pantalla que describen. */
    var pasos = document.querySelectorAll('#ayLista .ay-paso');
    igual('ayuda: los cuatro pasos de una solicitud', pasos.length, 4);
    igual('ayuda: y son los mismos que enseña el trámite',
          pasos[0].textContent.replace(/^1/, '').trim(), 'Solicitud recibida por el CIIP');
    ok('ayuda: sin huecos del marcado a la vista',
       document.getElementById('ayLista').textContent.indexOf('{') < 0,
       'busca "{"', 'ninguna llave suelta');

    /* Los cuatro distintivos, con el distintivo de verdad al lado: si
       cambia el de la tarjeta, cambia el de la ayuda. */
    var chips = document.querySelectorAll('#ayLista .ay-chip .chip');
    igual('ayuda: los cuatro distintivos, con su color', chips.length, 4);
    igual('ayuda: el de por iniciar', chips[0].textContent.trim(), 'Por iniciar');
    ok('ayuda: y el de completado va en verde',
       chips[3].classList.contains('good'), chips[3].className, 'con la clase good');
    /* Los cuatro con su color, y los cuatro distintos: si salieran todos
       del mismo, el color no diría nada y sobraría. */
    var colores = {};
    [].forEach.call(chips, function(c){
      colores[window.getComputedStyle(c).backgroundColor] = 1;
    });
    igual('ayuda: y cada uno de su color', Object.keys(colores).length, 4);

    /* Pedir una cita desde aquí abre la MISMA ventana: no hay una segunda
       forma de pedirla. */
    document.querySelector('#ayLista .btn.navy').click();
    ok('ayuda: pedir cita abre la ventana de siempre',
       document.getElementById('citaBack').classList.contains('open'),
       document.getElementById('citaBack').className, 'con la clase open');
    document.getElementById('ctCerrar').click();

    /* Las ocho claves que se escribieron para esta pantalla y no usó
       ninguna. Repetían dos preguntas de la portada con respuestas más
       cortas, así que se fueron en vez de resucitarlas. */
    ok('ayuda: las claves muertas de help.* ya no están',
       !I18N.es['help.title'] && !I18N.en['help.q1.t'],
       I18N.es['help.title'] || 'ninguna', 'ninguna');

    document.querySelector('#ayLista .btn.ghost').click();
  }

  function ayudaFaq(){
    /* Las preguntas de la portada no se copian aquí: se lleva hasta ellas
       y se despliegan. Copiarlas dejaría dos sitios que mantener. */
    igual('ayuda: "ver las preguntas" vuelve a la portada',
          document.body.getAttribute('data-vista'), 'inicio');
    var sec = document.querySelector('.faq-sec');
    ok('ayuda: y las deja desplegadas', !sec.classList.contains('plegada'),
       sec.className, 'sin la clase plegada');
  }

  /* ═══════════ LOS LOGOS DE LOS ORGANISMOS ═══════════
     Va al FINAL de la cadena a propósito: una imagen tarda en cargar, y
     preguntarle nada más pintar la página daría rojo por lo que aún no ha
     llegado. Para cuando llega aquí han pasado veinte pasos.

     Cada <img> lleva un onerror que retira su placa entera, así que un
     archivo que falte NO deja un icono roto: deja la tarjeta sin logo y
     nadie se entera. Esta prueba es lo único que lo notaría. */
  /* ═══════════ LA BURBUJA DE ACOMPAÑAMIENTO ═══════════
     Dos puertas nuevas: lo que es el CIIP y en qué se puede invertir. La
     segunda todavía no tiene contenido, y lo que se vigila aquí es que
     lo DIGA. Un menú que promete respuestas y contesta humo es peor que
     no ofrecerlo: quien entra se va creyendo que el CIIP no sabe. */
  function supAbre(){
    location.hash = '';
    document.getElementById('supFab').click();
  }

  function supMira(){
    var caja = document.querySelector('.sup-fab');
    ok('burbuja: se abre al pulsar el botón', caja.classList.contains('abierto'),
       caja.className, 'con la clase abierto');
    var menu = document.getElementById('supMenu');
    var botones = [].map.call(menu.querySelectorAll('.btn span, .btn'), function(b){
      return b.textContent.trim(); }).filter(Boolean);
    ok('burbuja: ofrece preguntar por el CIIP',
       /Preguntas sobre el CIIP/.test(menu.textContent),
       menu.textContent.slice(0, 80), 'Preguntas sobre el CIIP');
    ok('burbuja: y por dónde invertir',
       /Sobre invertir en Venezuela/.test(menu.textContent),
       'busca el renglón', 'aparece');
    ok('burbuja: y apartar una cita',
       !!document.getElementById('citaBtn'),
       'existe el botón de cita', 'existe');
    /* La nube no se queda encima del panel abierto: ya estás dentro. */
    var nube = document.getElementById('supNube');
    ok('burbuja: con el panel abierto la nube no estorba',
       !nube || nube.offsetHeight === 0,
       nube ? ('alto ' + nube.offsetHeight) : 'no hay nube', '0');
  }

  function supTemas(){
    /* Las dos puertas llevan al MISMO sitio que "Preguntar al
       asistente": la conversación. Tener dos maneras distintas de
       contestar lo mismo —una lista en el panel y un chat detrás— era
       pedir que se contradijeran. */
    document.getElementById('supInv').click();
    ok('burbuja: invertir abre el asistente',
       document.getElementById('asstBack').classList.contains('open'),
       document.getElementById('asstBack').className, 'con la clase open');
    ok('burbuja: y la burbuja se aparta',
       !document.querySelector('.sup-fab').classList.contains('abierto'),
       'cerrada', 'cerrada');

    /* Las siete que ya tenía el asistente son TODAS de inversión, así
       que este botón sirve desde hoy. */
    var vivos = [].filter.call(document.querySelectorAll('#asstSug .sug-chips button'),
                               function(b){ return !b.hidden; });
    igual('burbuja: con las siete preguntas de inversión', vivos.length, 7);
    ok('burbuja: y no dice que falte nada, porque no falta',
       document.getElementById('asstNada').hidden, 'oculto', 'oculto');
  }

  function supVuelve(){
    /* Y ahora la que SÍ está vacía. Lo que se vigila es que lo diga en
       el sitio donde ibas a buscar las preguntas, no que se quede una
       fila de chips en blanco. */
    document.getElementById('asstClose').click();
    document.getElementById('supFab').click();
    document.getElementById('supCiip').click();
    var vivos = [].filter.call(document.querySelectorAll('#asstSug .sug-chips button'),
                               function(b){ return !b.hidden; });
    igual('burbuja: del CIIP no hay ninguna cargada todavía', vivos.length, 0);
    var nada = document.getElementById('asstNada');
    ok('burbuja: y lo dice, en vez de dejar el hueco',
       !nada.hidden && /Todavía no hay temas cargados/.test(nada.textContent),
       nada.hidden ? '(oculto)' : nada.textContent.slice(0, 60), 'lo dice');

    /* Y el botón de siempre las devuelve todas: filtrar por un tema no
       puede dejar el asistente mutilado para el resto de la sesión. */
    document.getElementById('asstClose').click();
    document.getElementById('supFab').click();
    document.getElementById('supAsk').click();
    var todos = [].filter.call(document.querySelectorAll('#asstSug .sug-chips button'),
                               function(b){ return !b.hidden; });
    igual('burbuja: y "preguntar al asistente" las devuelve todas', todos.length, 7);
    document.getElementById('asstClose').click();
  }

  function logosMiran(){
    var placas = document.querySelectorAll('.t-marca img.ilogo');
    ok('logos: las tarjetas con organismo llevan el suyo', placas.length >= 15,
       placas.length + ' placas', 'quince o más');

    var rotos = [];
    [].forEach.call(placas, function(im){
      if (!im.complete || !im.naturalWidth) rotos.push(im.getAttribute('src'));
    });
    ok('logos: todos cargan de verdad', rotos.length === 0,
       rotos.length ? rotos.join(', ') : 'ninguno roto', 'ninguno roto');

    /* Debajo de cada logo va la sigla del organismo. Sin ella, un logo que
       no se reconoce no dice de quién es. */
    var sinSigla = [];
    [].forEach.call(document.querySelectorAll('.t-marca'), function(m){
      var s = m.querySelector('.t-sigla');
      if (!s || !s.textContent.trim()) sinSigla.push(m.parentNode.getAttribute('data-tr'));
    });
    ok('logos: y cada uno dice de quién es', sinSigla.length === 0,
       sinSigla.length ? sinSigla.join(', ') : 'ninguna sin sigla', 'ninguna sin sigla');

    /* Y donde la sigla ya lo dice, el distintivo de al lado no lo repite.
       Antes de esto, "SUSCERTE" salía dos veces en la misma tarjeta. */
    var repes = [];
    [].forEach.call(document.querySelectorAll('.tcard'), function(c){
      var s = c.querySelector('.t-sigla'), b = c.querySelector('.ebadge');
      if (s && b && s.textContent.trim() === b.textContent.trim())
        repes.push(c.getAttribute('data-tr'));
    });
    ok('logos: y no repite la sigla al lado del nombre', repes.length === 0,
       repes.length ? repes.join(', ') : 'ninguna repetida', 'ninguna repetida');

    /* La marca de agua del fondo. Iba solo en la primera tarjeta: las otras
       dieciséis tenían el logo arriba y el fondo vacío. data-marca sin su
       regla de CSS no pinta nada —el pseudo-elemento existe y se queda sin
       imagen—, así que no basta con mirar el atributo: hay que preguntarle al
       navegador qué fondo le salió. */
    var sinFondo = [], desparejas = [];
    [].forEach.call(document.querySelectorAll('.tcard'), function(c){
      var im = c.querySelector('.t-marca img.ilogo');
      var marca = c.getAttribute('data-marca');
      if (!im && !marca) return;                 /* sin organismo: ni logo ni fondo */
      if (!im || !marca){ desparejas.push(c.getAttribute('data-tr')); return; }
      /* el mismo archivo arriba y al fondo */
      if (im.getAttribute('src').indexOf('logos/' + marca + '.') !== 0)
        desparejas.push(c.getAttribute('data-tr'));
      var fondo = window.getComputedStyle(c, '::before').backgroundImage || '';
      if (fondo.indexOf('logos/' + marca + '.') < 0) sinFondo.push(c.getAttribute('data-tr'));
    });
    ok('marca: cada tarjeta con logo lo lleva también al fondo',
       sinFondo.length === 0,
       sinFondo.length ? sinFondo.join(', ') : 'ninguna sin fondo', 'ninguna sin fondo');
    ok('marca: y es el mismo logo arriba y detrás', desparejas.length === 0,
       desparejas.length ? desparejas.join(', ') : 'ninguna despareja', 'ninguna despareja');
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
      /* ── REPARTIDA EN TRES ── Una cita no se borra: solo se cancela, para
         que quede constancia de que se pidió. Así que la lista de una
         cuenta usada de verdad se llena de canceladas, y en una sola pila
         ordenada por fecha de petición enterraban a la que sí importa. */
      var secs = [].map.call(document.querySelectorAll('#ciLista .ag-sec .t'),
                             function(x){ return x.textContent.trim(); });
      igual('agenda: se reparte en marcha, pasadas y canceladas',
            secs.join(' | '), 'En marcha | Ya pasaron | Canceladas');
      /* Lo que está en marcha va PRIMERO: es lo único sobre lo que se
         puede hacer algo. */
      igual('agenda: y lo que está en marcha va primero', secs[0], 'En marcha');

      igual('agenda: enseña la cita viva y la que ya pasó', fichas.length, 2);

      /* Las canceladas no gastan una ficha entera, y llegan plegadas: son
         tres y solo estorban. */
      igual('agenda: las canceladas no ocupan una ficha cada una',
            document.querySelectorAll('#ciLista .ag-fila').length, 3);
      var pleg = document.querySelector('#ciLista .ag-mas');
      ok('agenda: llegan plegadas, y el botón dice cuántas son',
         pleg && /Ver las 3 canceladas/.test(pleg.textContent),
         pleg ? pleg.textContent : 'no hay botón', 'Ver las 3 canceladas');
      ok('agenda: y de verdad no se ven',
         document.querySelector('#ciLista .ag-fila').offsetHeight === 0,
         'alto ' + document.querySelector('#ciLista .ag-fila').offsetHeight, '0');
      pleg.click();
      ok('agenda: al pulsar se despliegan',
         document.querySelector('#ciLista .ag-fila').offsetHeight > 0,
         'alto ' + document.querySelector('#ciLista .ag-fila').offsetHeight, 'mayor que 0');
      ok('agenda: y lo dice para quien no lo ve',
         pleg.getAttribute('aria-expanded') === 'true',
         'aria-expanded=' + pleg.getAttribute('aria-expanded'), 'true');
      /* Tres canceladas que pedían LOS MISMOS días. Sin la fecha de
         petición son tres renglones idénticos y no se sabe cuál es cuál. */
      var pedidas = [].map.call(document.querySelectorAll('#ciLista .ag-fila .pe'),
                                function(x){ return x.textContent.trim(); });
      igual('agenda: cada cancelada dice cuándo se pidió', pedidas.length, 3);
      igual('agenda: y las tres se distinguen entre sí', new Set(pedidas).size, 3);
      pleg.click();
      ok('agenda: con su fecha puesta, no un hueco',
         /Confirmada para el/.test(fichas[0].querySelector('.ci-linea').textContent) &&
         fichas[0].querySelector('.ci-linea').textContent.indexOf('{') < 0,
         fichas[0].querySelector('.ci-linea').textContent, 'la fecha, sin llaves');
      ok('agenda: la viva se distingue del historial',
         fichas[0].classList.contains('viva'), fichas[0].className, 'con la clase viva');

      /* Cómo es la cita —verse, llamarse o ir— decide si tienes que salir de
         casa, así que va con el estado y no perdido en el renglón gris. */
      var mo = fichas[0].querySelector('.ci-cab .ct-chip.modo');
      ok('agenda: el modo lleva su propio distintivo', !!mo,
         mo ? mo.textContent : 'no existe', 'un distintivo aparte');
      igual('agenda: y dice cuál de los tres es', mo.textContent, 'Presencial');
      ok('agenda: con su dibujo, no solo la palabra', !!mo.querySelector('svg'),
         mo.querySelector('svg') ? 'lo lleva' : 'sin dibujo', 'con dibujo');
      /* Y sale del renglón gris: decirlo dos veces en la misma ficha es
         gastar la línea que lleva el trámite y el sitio. */
      ok('agenda: y no se repite abajo',
         !/Presencial/.test(fichas[0].querySelector('.ci-que').textContent),
         fichas[0].querySelector('.ci-que').textContent, 'sin el modo');
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
    /* Dos citas y dos trámites: el contador es "cuánto tienes encima". */
    igual('cola: el botón lleva cuántas esperan',
          (document.getElementById('colaN') || {}).textContent, '4');

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

    ok('cola: y sobre qué y qué días le vienen bien',
       /RIF de la empresa/.test(fichas[0].querySelector('.co-que').textContent),
       fichas[0].querySelector('.co-que').textContent, 'el trámite y las fechas');

    /* Cómo quiere verse decide cómo se reparte la mañana: vídeo, teléfono o
       una sala no cuestan lo mismo. Va con el nombre, no en el renglón gris,
       y es el MISMO distintivo que el inversionista ve en su agenda. */
    var moc = fichas[0].querySelector('.co-cab .ct-chip.modo');
    ok('cola: y cómo quiere verse, con su distintivo', !!moc,
       moc ? moc.textContent : 'no existe', 'un distintivo aparte');
    igual('cola: cuál de los tres es', moc.textContent, 'Presencial');
    ok('cola: con su dibujo, como en la agenda', !!moc.querySelector('svg'),
       moc.querySelector('svg') ? 'lo lleva' : 'sin dibujo', 'con dibujo');
    ok('cola: y no se repite en el renglón gris',
       !/Presencial/.test(fichas[0].querySelector('.co-que').textContent),
       fichas[0].querySelector('.co-que').textContent, 'sin el modo');
    igual('cola: una cita sin trámite es una consulta general',
          fichas[1].querySelector('.co-que').textContent.split(' · ')[0], 'Consulta general');

    /* Confirmar sin fecha no puede pasar: la base rechaza una cita
       confirmada sin ella, y aquí se dice con palabras. */
    fichas[0].querySelectorAll('.btn')[1].click();
    /* Resolver sin adjuntar nada dejaba al inversionista con un aviso de
       que ya está y sin nada en la mano. */
    (function(){
      var f = [].slice.call(document.querySelectorAll('#colaTram .co-ficha'))
        .filter(function(x){ return /Presentada ante|revisión/i.test(x.textContent); })[0];
      if (!f) return;
      var sube = f.querySelector('.co-emitir');
      if (!sube) return;
      igual('cola: al presentar ante el ente se pide el documento emitido',
            sube.querySelector('label').textContent.trim(), 'Documento emitido por el organismo');
    })();

    igual('cola: sin fecha no confirma, y lo dice',
          fichas[0].querySelector('.co-aviso').textContent, 'Pon la fecha y la hora.');

    fichas[0].querySelector('input[type="datetime-local"]').value = '2026-08-26T10:00';
    fichas[0].querySelector('input[type="text"]').value = 'Torre CIIP, piso 4';
    fichas[0].querySelectorAll('.btn')[1].click();
  }

  function colaTramites(){
    if (CASO !== 'gestor') return;
    var fichas = document.querySelectorAll('#colaTram .co-ficha');
    igual('cola: enseña los trámites que esperan por el CIIP', fichas.length, 2);

    /* El contador es "cuánto tienes encima", no "cuántas citas": dos citas
       y dos trámites. */
    igual('cola: y el contador suma las dos colas',
          (document.getElementById('colaN') || {}).textContent, '4');

    /* Los pasos que se ofrecen salen del estado. Enseñarlos todos siempre
       invitaría a presentar ante el ente algo que nadie ha revisado. */
    function botones(f){
      var t = []; f.querySelectorAll('.co-botones .btn').forEach(function(b){ t.push(b.textContent.trim()); });
      return t.join(' | ');
    }
    igual('cola: un trámite recién enviado se devuelve o se empieza a revisar',
          botones(fichas[0]), 'Devolver | Empezar la revisión');
    igual('cola: y uno en revisión se devuelve o se presenta ante el ente',
          botones(fichas[1]), 'Devolver | Presentada ante el ente');

    /* ── el expediente ──
       La cola decía quién, qué y cuándo, pero no qué había dentro: se movían
       estados a ciegas. */
    ok('cola: el expediente nace plegado',
       fichas[0].querySelector('.co-exp') && !fichas[0].querySelector('.co-exp').classList.contains('abierto'),
       'abierto=' + (fichas[0].querySelector('.co-exp') || {className:'(no existe)'}).className,
       'plegado');
    fichas[0].querySelector('.co-ver').click();
    ok('cola: se despliega al pulsar',
       fichas[0].querySelector('.co-exp').classList.contains('abierto'),
       fichas[0].querySelector('.co-exp').className, 'con la clase abierto');

    /* Lo que rellenó, con las etiquetas del formulario y no los nombres
       internos de las columnas. */
    var exp = fichas[0].querySelector('.co-exp');
    ok('cola: enseña lo que rellenó, con sus etiquetas',
       /Razón social/.test(exp.textContent) && /Bianchi Agroindustrias/.test(exp.textContent) &&
       !/razon_social/.test(exp.textContent),
       'busca "Razón social" y su valor, y que NO salga razon_social',
       'la etiqueta y el valor');

  }

  /* ═══════════ LA CONSTANCIA DE IDENTIDAD ═══════════
     No valida contra nadie: deja constancia de que una persona del CIIP
     miró el documento, quién fue y cuándo. Lo que estas pruebas vigilan
     de verdad es que el panel NO diga más de lo que hizo. */
  function idCaja(){
    var f = document.querySelectorAll('#colaTram .co-ficha')[0];
    return f && f.querySelector('.id-caja');
  }

  function idMira(){
    if (CASO !== 'gestor') return;
    var c = idCaja();
    ok('identidad: el expediente empieza por quién dice ser', !!c,
       c ? 'la caja está' : 'no hay caja', 'una caja de identidad');
    /* Y ARRIBA: al final se firmaría sin mirar, con el ratón ya en el
       botón de aprobar. */
    var exp = document.querySelectorAll('#colaTram .co-ficha')[0].querySelector('.co-exp');
    igual('identidad: y va antes que los datos y los archivos',
          exp.firstElementChild === c, true);

    ok('identidad: sin comprobar, lo dice',
       /Sin comprobar/.test(c.textContent), c.textContent.slice(0, 40), 'Sin comprobar');
    /* Lo más importante de toda la pantalla: que el gestor no crea que
       una máquina comprobó algo. Si esto se cae, firmará constancias
       creyendo que las respalda el SAIME. */
    ok('identidad: y avisa de que no consulta al SAIME',
       /no consulta al SAIME/.test(c.textContent), 'busca el aviso', 'a la vista');
    ok('identidad: el aviso no es letra escondida',
       c.querySelector('.id-ojo') && c.querySelector('.id-ojo').offsetHeight > 0,
       'alto ' + (c.querySelector('.id-ojo') || {}).offsetHeight, 'se ve');

    /* Los tres documentos con los que se identifica a alguien, con su
       nombre legible y no con su código. */
    var opciones = c.querySelectorAll('.id-fila select option');
    igual('identidad: ofrece cédula, pasaporte y RIF', opciones.length, 3);
    ok('identidad: por su nombre, no por su código',
       !/rif_personal/.test(c.textContent), 'busca "rif_personal"', 'no aparece');
  }

  function idRechazaSinNota(){
    if (CASO !== 'gestor') return;
    var c = idCaja();
    var sel = c.querySelectorAll('select');
    var num = c.querySelector('input');
    num.value = 'V-12345678';
    sel[1].value = 'rechazada';
    c.querySelector('.id-form button').click();
    /* Rechazar sin decir por qué deja al inversionista sin saber qué
       arreglar. Es la misma regla que la devolución de un trámite. */
    ok('identidad: rechazar sin decir por qué no pasa',
       /hace falta decir por qu/.test(c.querySelector('.id-av').textContent),
       c.querySelector('.id-av').textContent, 'lo dice');
    ok('identidad: y no se guardó nada',
       /Sin comprobar/.test(c.textContent), 'sigue sin comprobar', 'sin comprobar');
  }

  function idFirma(){
    if (CASO !== 'gestor') return;
    var c = idCaja();
    c.querySelectorAll('select')[1].value = 'comprobada';
    c.querySelector('input').value = 'V-12345678';
    c.querySelector('.id-form button').click();
  }

  function idTrasFirmar(){
    if (CASO !== 'gestor') return;
    var c = idCaja();
    ok('identidad: firmada, la constancia queda', /Comprobada/.test(c.textContent),
       c.textContent.slice(0, 50), 'Comprobada');
    /* Una constancia sin autor ni fecha no es una constancia: es una
       casilla marcada. */
    ok('identidad: con el nombre de quien la firmó',
       /Franklin Reyes/.test(c.textContent), 'busca el nombre', 'aparece');
    ok('identidad: y contra qué documento, con su número',
       /V-12345678/.test(c.textContent), 'busca el número', 'aparece');
    /* Y el aviso NO desaparece al firmar. Es cuando más falta hace: la
       pantalla ya dice "Comprobada" en verde. */
    ok('identidad: y el aviso sigue puesto con la casilla en verde',
       /no consulta al SAIME/.test(c.textContent), 'busca el aviso', 'sigue');
    /* Y no se ha ido al fondo: al repintar se colocaba detras de los
       archivos, y la segunda constancia habria que buscarla. */
    var exp = document.querySelectorAll('#colaTram .co-ficha')[0].querySelector('.co-exp');
    igual('identidad: y sigue siendo lo primero del expediente',
          exp.firstElementChild === c, true);
  }

  function colaExpediente(){
    if (CASO !== 'gestor') return;
    var exp = document.querySelectorAll('#colaTram .co-ficha')[0].querySelector('.co-exp');
    var archivos = exp.querySelectorAll('.co-arch');
    igual('cola: y lista los archivos que subió', archivos.length, 2);
    ok('cola: cada uno con su nombre de verdad',
       /acta-bianchi\.pdf/.test(exp.textContent),
       'busca "acta-bianchi.pdf"', 'aparece');
    /* El cubo es privado: no hay URL fija, se pide una firmada al abrir. */
    ok('cola: y con un botón para abrirlo',
       archivos[0].querySelector('button') !== null,
       archivos[0].querySelector('button') ? 'lo tiene' : 'sin botón', 'un botón por archivo');
  
    var fichas = document.querySelectorAll('#colaTram .co-ficha');

    /* Devolver sin decir por qué deja al inversionista con un aviso que no
       explica nada. Es el único paso que exige la nota. */
    fichas[0].querySelectorAll('.co-botones .btn')[0].click();
    igual('cola: devolver sin explicar no pasa, y lo dice',
          fichas[0].querySelector('.co-aviso').textContent, 'Escribe por qué la devuelves.');
    ok('cola: y el trámite sigue en la cola',
       document.querySelectorAll('#colaTram .co-ficha').length === 2,
       document.querySelectorAll('#colaTram .co-ficha').length + ' fichas', '2');

    /* Y ahora con la nota. */
    /* Por su clase y no por su etiqueta: el expediente tiene ahora su
       propia textarea -la nota de identidad- y va antes en el arbol. */
    fichas[0].querySelector('.co-nota-in').value = 'Falta el comprobante del capital.';
    fichas[0].querySelectorAll('.co-botones .btn')[0].click();
  }

  function colaTrasDevolver(){
    if (CASO !== 'gestor') return;
    igual('cola: devuelto, sale de la cola',
          document.querySelectorAll('#colaTram .co-ficha').length, 1);
    /* Lo que importa de verdad: que la nota LLEGÓ. El estado por si solo
       dejaría al inversionista con un aviso mudo. */
    igual('cola: y la nota viaja con la devolución',
          (window.PRUEBA_NOTA && window.PRUEBA_NOTA()) || '(ninguna)',
          'Falta el comprobante del capital.');
    igual('cola: el contador baja', (document.getElementById('colaN') || {}).textContent, '3');
  }

  function colaTrasConfirmar(){
    if (CASO !== 'gestor') return;
    igual('cola: confirmada, sale de la cola', document.querySelectorAll('#colaLista .co-ficha').length, 1);
    /* Quedan una cita y un trámite: se devolvió uno antes y ahora se
       confirmó una. El contador cuenta las dos colas juntas. */
    igual('cola: y el contador baja', (document.getElementById('colaN') || {}).textContent, '2');
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
