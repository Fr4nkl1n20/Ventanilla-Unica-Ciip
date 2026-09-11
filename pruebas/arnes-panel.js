/* ══════════════════════════════════════════════════════════════════════
   ARNÉS DE PRUEBAS DEL PANEL
   ══════════════════════════════════════════════════════════════════════
   Lo inyecta panel.ps1 al final de una copia temporal del panel, junto a
   supabase-mentira.js. El panel de verdad NUNCA los carga.

   Prueba lo que la portada dice de tus trámites:

       el camino     que los contadores y las barras salen de las tarjetas
       las cajas     que las cuatro etapas son cuatro cajas parejas
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
  /* 'pliego' trae LOS MISMOS DATOS que 'vacio': lo unico que cambia es que
     hay un pliego sin aceptar. Si CASO valiera 'pliego', las pruebas que
     miran el expediente vacio se saltarian todas y este pase mediria solo
     la puerta -y de paso dejaria sin comprobar que el panel funciona con
     normalidad DESPUES de aceptar, que es la mitad que importa-. */
  var CASO = (SIN_SQL || ES_ADMIN) ? 'gestor'
           : (PASE === 'pliego' || PASE === 'pliegoya') ? 'vacio'
           : PASE;
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
  /* Y algunos pasos no caben en medio segundo por mucho que se les dé.
     Subir un papel calcula ahora su SHA-256, y eso ocurre fuera del hilo
     principal: con --virtual-time-budget el reloj del navegador corre
     solo, así que los 500 ms "pasan" antes de que el resumen esté hecho.
     No es lento —son ocho milisegundos de verdad—, es que ese reloj no
     espera a nadie.

     Un paso que declara UN argumento recibe el "sigue" y dice él cuándo
     ha terminado. Es el mismo criterio de cuandoConteste, que ya está
     unas líneas más arriba: esperar a que algo ocurra, no a que pase un
     rato. */
  function enCadena(pasos, alFinal){
    var i = 0;
    (function siguiente(){
      if (i >= pasos.length) return alFinal();
      var paso = pasos[i++];
      try {
        if (paso.length === 1){ paso(function(){ setTimeout(siguiente, 60); }); return; }
        paso();
      } catch(e){
        ok('el arnés llegó al final', false, 'EXCEPCION en el paso ' + i + ': ' + e.message, 'sin excepciones');
      }
      setTimeout(siguiente, 500);
    })();
  }

  /* Espera a que una lista crezca, o se rinde. Rendirse y seguir es lo
     correcto: así la prueba de después falla diciendo QUÉ no apareció, en
     vez de quedarse el arnés colgado sin decir nada. */
  function esperaFilas(selector, cuantas, sigue){
    var n = 0;
    (function mira(){
      if (document.querySelectorAll(selector).length >= cuantas || ++n > 80) return sigue();
      setTimeout(mira, 40);
    })();
  }

  /* Lo que costo ARRANCAR, apuntado en cuanto el panel termina y antes de
     que la cadena toque nada. Medirlo mas tarde contaria los viajes del
     propio arnes: la primera version de esta prueba hacia justo eso y daba
     rojo por pasos que no tenian nada que ver. */
  var VIAJES_ARRANQUE = null;

  cuandoConteste(function(){
    if (window.CIIP_VIAJES) VIAJES_ARRANQUE = window.CIIP_VIAJES.getUser;
    /* El pliego PRIMERO, y no es capricho de orden: mientras su puerta
       esta puesta el panel no termina de pintarse -plDejaPasar guarda en
       una cola lo que va despues- asi que cualquier prueba que corriera
       antes miraria un panel a medio hacer. Se comprueba la puerta, se
       acepta, y desde ahi la tanda sigue como en cualquier otro pase. */
    enCadena([pliegoMira, pliegoAcepta, pliegoCerrada,
              puertaEspera, puertaMira, puertaTrasResponder,
              pruebas, trasGuardar, citasAbre, citasPide, citasTrasPedir,
              /* El hilo ANTES de anular: al cancelar la cita, el hilo se
                 va con ella y no habría nada que mirar. */
              hiloCitaMira,
              citasAnula, citasTrasAnular, hiloCitaTrasAnular,
              colaAbre,
              /* El reparto ANTES de desplegar nada: tomar un tramite
                 repinta la cola entera, y eso pliega el expediente que
                 los pasos de abajo necesitan abierto. */
              colaReparto, colaTrasTomar,
              colaTramites, colaLleva,
              colaHiloEspera, colaHiloMira,
              /* La identidad se mira con el expediente ya desplegado y
                 ANTES de colaExpediente, que termina devolviendo el
                 tramite: al devolverlo sale de la cola y se lleva por
                 delante la ficha entera. */
              idMira, idRechazaSinNota, idFirma, idTrasFirmar,
              colaExpediente, colaTrasDevolver, colaConfirma, colaTrasConfirmar,
              agendaMira, agendaTrasEntrar, agendaHilo, agendaHiloMira, agendaTrasSalir,
              paisesMira, empiezaSolicitud, paisesTrasAbrir,
              dupeAbre, empiezaSolicitud, dupeMira, dupeTrasEnviar,
              antesAbre, empiezaSolicitud, antesMira, fecha3Mira, fecha3Cambia,
              fichaAbre, fichaMira, empiezaSolicitud, fichaTrasEmpezar,
              rncAbre, empiezaSolicitud, rncTrasAbrir,
              sisrefAbre, empiezaSolicitud, sisrefTrasAbrir,
              pistaAbre, empiezaSolicitud, pistaMira,
              solvenciasAbre, empiezaSolicitud, solvenciasTrasAbrir,
              activosAbre, activosMira, opacidadActivos, activosPublica, activosTrasPublicar,
              activosEdita, activosTrasEditar, activosBorra, activosTrasBorrar,
              devueltoAbre, devueltoMira, escaleraAbre, escaleraMira, variasAbre, variasMira,
              usuariosMira, usuariosCambia, usuariosTrasCambiar, usuariosSeMueve,
              sinSqlAbre, sinSqlMira,
              adminMira, adminAbre, adminDentro,
              f5Entra, f5Espera, f5Llega,
              f5TardeEntra, f5TardeEspera, f5TardeLlega,
              mtLleva, mtLlevaMira, colaRenglon, colaRenglonAbre,
              tablaMira, tablaAbre, tablaTrasAbrir,
              empresaAbre, empresaMira, empresaGuarda, empresaTrasGuardar,
              entregaAbre, entregaMira,
              hiloAbre, hiloMira,
              docsAbre, docsMira, docsCambia, docsEsperaCambio, docsTrasCambiar,
              docsNuevoMira, docsNuevoFalta, docsNuevoSube, docsEsperaSubida, docsTrasSubir,
              /* DESPUES de todo lo de la boveda: estos pasos suben un papel,
                 y puestos antes le cambiaban la cuenta a las pruebas que
                 esperan los tres del expediente de partida. */
              cacheAbre, cacheMira, cacheSube, cacheSube2, cacheVuelve, cacheTrasVolver,
              ayudaAbre, ayudaMira, ayudaFaq,
              supAbre, supMira, supTemas, supVuelve,
              asstConServidor, asstSinServidor,
              fotoAbre, fotoMira, fotoMala, fotoSube, fotoTrasSubir, fotoCierra,
              temaMira,
              logosMiran, tokensMiran,
              cabecerasMiran,
              comentariosMiran,
              cajasConDueño,
              letraMira,
              habilesMira,
              iFasesMira,
              tablasMiran,
              /* La consulta DESPUES de tokensMiran y antes de lo que
                 abre ventanas: estas abren la suya y la cierran al
                 final, y dejarla abierta le taparia la pantalla a las
                 de despues -que es como 886 pruebas se pusieron rojas
                 de golpe una vez-. */
              catalogoAbre, catalogoEspera, catalogoMira, catalogoGuarda, catalogoTrasGuardar,
              catalogoVuelveEspera, catalogoSeVeEnLaFicha,
              catalogoDeshace, catalogoDeshaceEspera, catalogoDeshacePonlo,
              puertaTodos,
              consultaAbre, consultaMira, consultaEntra, consultaDentro,
              rotulosMiran, consultaNueva, consultaNuevaMira, consultaTrasCrear,
              consultaCola, consultaToma, consultaTrasTomar,
              consultaResuelve, consultaTrasResolver,
              velocidadArranque, velocidadAbre, velocidadMira,
              velocidadRepite, velocidadTrasRepetir,
              pliegaAbre, pliegaMira, pliegaVuelve, pliegaTrasVolver,
              pliegaTramite, pliegaVuelveDeTramite, pliegaTrasTramite,
              opacidadMira, opacidadSenal,
              loHacemosMira,
              gestionAbre, gestionMira, escaleraNoParpadea, gestionTrasPulsar,
              escaleraApagadoAbre, escaleraApagadoMira,
              migajaAbre, migajaMira, migajaVuelve,
              cuadraAbre, cuadraMira, cuadraMira, cuadraMira,
              nuevaVersionMira, guardaCatalogo,
              rastroAbre, rastroMira,
              rastroDesdeTramiteAbre, rastroDesdeTramiteEntra,
              rastroDesdeTramiteSalta, rastroDesdeTramiteMira,
              alDiaGuardas, alDiaAntes, alDiaVuelve, alDiaDespues, alDiaFreno], volcar);
  });

  /* ═══════════════ LA PUERTA DEL SECTOR ═══════════════
     Se pregunta una vez, antes de dejar entrar. Lo que hay que medir no
     es solo que se abra: es que NO se abra en los tres casos en que
     abrirla dejaria a alguien fuera para siempre. */
  /* ═══════════ LA PUERTA DEL PLIEGO DE DATOS ═══════════
     Del punto 3 del informe del 2 de septiembre. La pantalla se escribio
     el 3 de septiembre y llego SIN una sola prueba: 541 lineas de las
     cuales la mas delicada es un bloqueo al entrar.

     Y no llegaba a ejecutarse aqui. El doble no sabia nada del pliego:
     sb.rpc devolvia null para cualquier nombre, plPidePendiente lo leia
     como «no hay nada que aceptar» y el panel dejaba pasar. O sea que la
     puerta habria podido estar completamente rota y la tanda en verde.

     Se mide en los DOS sentidos, y el segundo importa igual:

       con pliego sin aceptar  la puerta se abre y no deja pasar
       sin pliego publicado    NO se abre, y eso hay que comprobarlo en
                               todos los demas pases, porque es el estado
                               real de produccion hasta que el abogado
                               apruebe el texto. Una puerta cerrada con
                               nada detras deja fuera a todo el mundo.  */
  function pliegoMira(){
    var back = document.getElementById('pliegoBack');
    var abierta = !!(back && back.classList.contains('open'));

    /* ── quien YA lo aceptó ──
       El caso normal de todo el mundo a partir del día siguiente: no hay
       puerta, pero tiene que quedar dónde releerlo.

       Necesita pase propio, y lo dijo el sabotaje: en el pase 'pliego' ese
       enlace lo enciende OTRA rama del código, así que quitar la que lo
       enciende aquí no ponía nada en rojo. Un consentimiento que no se
       puede volver a leer es medio habeas data sin hacer. */
    if (PASE === 'pliegoya'){
      var nav0 = document.getElementById('navPliego');
      ok('pliego: a quien ya lo aceptó no se le vuelve a pedir', !abierta,
         abierta ? 'abierta' : 'cerrada', 'cerrada');
      ok('pliego: pero puede volver a leerlo cuando quiera',
         !!nav0 && !nav0.hidden,
         nav0 ? (nav0.hidden ? 'escondido' : 'a la vista') : 'no existe', 'a la vista');
      return;
    }

    if (PASE !== 'pliego'){
      /* Ésta es la que corre en los otros diez pases. */
      /* Se mira SOLO la puerta del pliego y no el bloqueo del cuerpo: en
         el pase 'sinsector' hay otra puerta legitima puesta -la del sector-
         y las dos usan la misma clase en el body. Mirar el body media las
         dos a la vez y salia roja por la que no toca. */
      ok('pliego: sin pliego publicado no hay puerta', !abierta,
         abierta ? 'abierta' : 'cerrada', 'cerrada');
      return;
    }

    ok('pliego: con uno sin aceptar, la puerta se abre', abierta,
       back ? back.className : 'no hay puerta', 'con la clase open');
    ok('pliego: y el panel queda bloqueado detras',
       document.body.classList.contains('con-puerta'),
       document.body.className || 'sin clase', 'con con-puerta');

    /* El titulo sale de la BASE y no del diccionario: es el nombre que le
       puso el abogado a esa version, y traducirlo seria renombrarle un
       documento juridico. */
    igual('pliego: el titulo es el de la version publicada',
          (document.getElementById('plTitulo') || {}).textContent, 'Pliego de prueba');
    ok('pliego: y dice que version es',
       ((document.getElementById('plSub') || {}).textContent || '').indexOf('1') !== -1,
       (document.getElementById('plSub') || {}).textContent, 'algo con el 1');

    /* El texto, en parrafos y no en un ladrillo. Dos, que es lo que trae
       el doble: si saliera uno, los saltos de linea se estarian comiendo. */
    var parrafos = document.querySelectorAll('#plTexto p');
    igual('pliego: el texto se parte en parrafos', parrafos.length, 2);
    ok('pliego: y es el de la base, no un relleno',
       (parrafos[0] || {}).textContent === 'Primer parrafo del pliego de prueba.',
       (parrafos[0] || {}).textContent, 'Primer parrafo del pliego de prueba.');

    /* NO se puede aceptar sin marcar. Es el boton el que esta apagado, y
       no un aviso al pulsar: un boton encendido que luego riñe es peor.  */
    var bt = document.getElementById('plAceptar');
    var cx = document.getElementById('plCasilla');
    ok('pliego: no se acepta sin marcar la casilla', !!bt && bt.disabled,
       bt ? (bt.disabled ? 'apagado' : 'ENCENDIDO') : 'no hay boton', 'apagado');
    ok('pliego: y la casilla empieza sin marcar', !!cx && !cx.checked,
       cx ? (cx.checked ? 'marcada' : 'sin marcar') : 'no hay casilla', 'sin marcar');

    if (cx && bt){
      cx.checked = true;  cx.dispatchEvent(new Event('change'));
      ok('pliego: al marcarla se puede aceptar', !bt.disabled,
         bt.disabled ? 'sigue apagado' : 'encendido', 'encendido');
      /* Y al revés. Sin esto, un boton que se enciende y no se apaga
         nunca pasaria igual: se mide una vez y parece bien. */
      cx.checked = false; cx.dispatchEvent(new Event('change'));
      ok('pliego: y al desmarcarla vuelve a apagarse', bt.disabled,
         bt.disabled ? 'apagado' : 'SIGUE ENCENDIDO', 'apagado');
    }

    /* El idioma se cambia AQUI DENTRO. Quien no lea castellano se
       quedaria delante de un documento juridico en una lengua que no
       entiende, con la casilla como unica salida. */
    ok('pliego: se puede cambiar de idioma sin salir',
       document.querySelectorAll('#plLang button[data-lang]').length >= 6,
       document.querySelectorAll('#plLang button[data-lang]').length + ' idiomas', '6 o mas');

    /* Y si esa version no esta traducida a tu idioma, se cae al
       CASTELLANO -que es el que obliga- y lo DICE. Quedarse en blanco
       seria pedir que se firme una hoja vacia; no decirlo, hacer creer que
       lo que se lee es la version que rige. El doble trae solo es y en, y
       el italiano es de los que faltan. */
    (function(){
      var antes = curLang;
      applyLang('it');
      if (window.CIIP_REPINTA_PLIEGO) window.CIIP_REPINTA_PLIEGO();
      var p = document.querySelectorAll('#plTexto p');
      ok('pliego: sin traducir, se lee el castellano',
         (p[0] || {}).textContent === 'Primer parrafo del pliego de prueba.',
         (p[0] || {}).textContent, 'el parrafo en castellano');
      ok('pliego: y se avisa de que se esta leyendo el castellano',
         ((document.getElementById('plNota') || {}).textContent || '').trim() !== '',
         (document.getElementById('plNota') || {}).textContent || 'sin nota', 'una nota');
      applyLang(antes || 'es');
      if (window.CIIP_REPINTA_PLIEGO) window.CIIP_REPINTA_PLIEGO();
    })();
  }

  function pliegoAcepta(){
    if (PASE !== 'pliego') return;
    var cx = document.getElementById('plCasilla');
    var bt = document.getElementById('plAceptar');
    if (!cx || !bt) return;
    cx.checked = true; cx.dispatchEvent(new Event('change'));
    bt.click();
  }

  function pliegoCerrada(){
    if (PASE !== 'pliego') return;
    var back = document.getElementById('pliegoBack');
    ok('pliego: al aceptarlo, se entra', !back.classList.contains('open'),
       back.className, 'cerrada');
    ok('pliego: y el panel deja de estar bloqueado',
       !document.body.classList.contains('con-puerta'),
       document.body.className || 'sin clase', 'sin con-puerta');

    /* Y queda donde releerlo. Un consentimiento que no se puede volver a
       leer es medio habeas data sin hacer: la version vieja se guarda en
       la base justamente para eso. */
    var nav = document.getElementById('navPliego');
    ok('pliego: y queda un sitio donde releerlo', !!nav && !nav.hidden,
       nav ? (nav.hidden ? 'escondido' : 'a la vista') : 'no existe', 'a la vista');
  }

  function puertaEspera(){
    /* Un paso vacio. La puerta se abre despues de que conteste el perfil
       Y de que conteste el catalogo, o sea dos idas y venidas; este medio
       segundo es para no medirla antes de que exista. */
  }

  function puertaMira(){
    var back = document.getElementById('sectorBack');
    var abierta = !!(back && back.classList.contains('open'));

    /* Aqui se mira el PASE y no el CASO. CASO junta a proposito varios
       pases bajo 'gestor' -sinsql es uno-, y con el la prueba del que no
       puede guardar la respuesta caia en la rama del equipo del CIIP y
       pasaba sin comprobar nada. */
    if (PASE === 'gestor' || PASE === 'admin' || PASE === 'sinsql'){
      ok('sector: al equipo del CIIP no se le pregunta', !abierta,
         abierta ? 'le sale la puerta' : 'no le sale', 'no le sale');
      return;
    }
    /* La columna no existe: la respuesta no se podria guardar, asi que
       preguntarla seria plantarle delante una puerta que no abre. Este es
       el pase con un INVERSIONISTA de verdad detras. */
    if (PASE === 'sinsectorsql'){
      ok('sector: si la base no sabe guardarlo, no se pregunta', !abierta,
         abierta ? 'bloquea igual' : 'no bloquea', 'no bloquea');
      return;
    }
    /* Y sin nada que elegir, tampoco. */
    if (PASE === 'sincatalogo'){
      ok('sector: con el catalogo vacio no bloquea a nadie', !abierta,
         abierta ? 'bloquea sin lista' : 'no bloquea', 'no bloquea');
      return;
    }
      /* ESTA PUERTA YA NO ES SOLO DEL SECTOR. Pregunta las dos cosas -quien
         eres y a que te dedicas- y se abre si falta CUALQUIERA de las dos.

         El expediente 'sinnombre' tiene el sector contestado -turismo- y el
         nombre en blanco, asi que ahora le sale, y le tiene que salir: sin
         eso el panel le seguia llamando por el trozo del correo anterior a
         la arroba, porque nadie le habia preguntado como se llama.

         Esta comprobacion exigia lo contrario y se puso roja al cambiar la
         puerta. Tenia razon en preguntar -algo habia cambiado- pero la
         respuesta buena es la nueva, no la vieja. */
      if (PASE === 'sinnombre'){
        ok('sector: al que no dio su nombre se le pregunta, aunque tenga sector',
           abierta, abierta ? 'le sale' : 'no le sale', 'le sale');
        /* Y le sale POR EL NOMBRE: el campo esta ahi y en blanco. Sin esto,
           lo de arriba se cumpliria igual si la puerta se abriera por
           cualquier otro motivo, que es como una prueba deja de medir lo que
           dice medir sin que se note. */
        var camp = document.getElementById('seNombre');
        ok('sector: y la puerta trae el campo del nombre, en blanco',
           !!camp && !camp.value,
           camp ? 'valor="' + camp.value + '"' : 'no hay campo', 'el campo, vacio');
        return;
      }
    if (PASE !== 'sinsector'){
      ok('sector: al que ya contesto no se le vuelve a preguntar', !abierta,
         abierta ? 'se lo repregunta' : 'no se lo repregunta', 'no se lo repregunta');
      return;
    }

    /* ── y aqui, el unico que no ha contestado ── */
    ok('sector: al que no ha contestado se le pregunta', abierta,
       abierta ? 'le sale la puerta' : 'no le sale', 'le sale');
    if (!abierta) return;

    var ops = document.querySelectorAll('#seLista .se-op');
    /* Ocho motores mas uno inventado, para medir que un sector que el CIIP
       añada por SQL sale igual aunque el panel no tenga su icono. */
    igual('sector: los que da la base, sin recortar', ops.length, 9);
    /* Cada uno con su icono. Sin esto, un dibujo que se dejara de pintar
       daria un cuadro vacio y las pruebas seguirian en verde. */
    var conIcono = [].filter.call(ops, function(o){
      return !!o.querySelector('.se-ico svg path, .se-ico svg rect');
    });
    igual('sector: y cada uno con su icono', conIcono.length, 9);
    /* Los ocho conocidos llevan color propio; el noveno, ninguno, y cae al
       azul del panel. */
    var conColor = [].filter.call(ops, function(o){
      return !!o.style.getPropertyValue('--sc');
    });
    igual('sector: los ocho conocidos, con su color', conColor.length, 8);
    ok('sector: y el que el panel no conoce sale igual',
       ops[8] && !ops[8].style.getPropertyValue('--sc') &&
       !!ops[8].querySelector('.se-ico svg'),
       ops[8] ? 'sale con el generico' : 'no sale', 'sale con el generico');
    /* Sin escribir el nombre a mano: en este pase el panel esta en
       italiano, asi que comparar con "Hidrocarburos" fallaria por el
       idioma y no por el orden. Se compara con lo que dice pasos.js para
       s1, que de paso comprueba que la traduccion se esta usando. */
    var s1 = ((window.CIIP_PASOS.sectores || {})[curLang] || {}).s1 || '';
    igual('sector: y por el orden que dice la base',
          ops[0].textContent.trim(), s1);
    /* Con ocho, la caja de filtrar estorba y no sale. Sale a partir de
       diez. Si el CIIP amplia la lista, esto se entera. */
    ok('sector: con menos de diez no saca caja de filtrar',
       document.getElementById('seBuscar').hidden,
       document.getElementById('seBuscar').hidden ? 'escondida' : 'a la vista',
       'escondida');

    /* El fondo tapa del todo. Un velo translucido deja ver datos de
       ejemplo detras de la unica pregunta que hay que contestar, y da a
       entender que hay algo ahi a lo que se puede volver. */
    var fondo = window.getComputedStyle(back).backgroundColor;
    ok('sector: el fondo tapa lo de detras', /^rgb\(/.test(fondo),
       fondo, 'opaco, sin transparencia');

    /* El panel se sigue viendo -la barra lateral y la de arriba- y lo que
       queda en blanco es la zona de las fases. Si la puerta volviera a
       taparlo todo, se perderia el sitio donde estas. */
    var caja = back.getBoundingClientRect();
    var lat  = document.querySelector('.sidebar').getBoundingClientRect();
    ok('sector: la barra lateral se sigue viendo',
       caja.left >= lat.right - 1,
       Math.round(caja.left) + ' contra ' + Math.round(lat.right),
       'la puerta empieza donde acaba la barra');
    ok('sector: y la cabecera tambien', caja.top > 40,
       Math.round(caja.top), 'por debajo de la cabecera');

    /* Se ve, pero no se toca: si el menu siguiera vivo se podria navegar
       por detras de una pantalla que existe para no dejar pasar. */
    igual('sector: pero el menu no se puede usar',
          window.getComputedStyle(document.querySelector('.sidebar')).pointerEvents,
          'none');
    igual('sector: ni la cabecera',
          window.getComputedStyle(document.querySelector('.topbar')).pointerEvents,
          'none');

    /* No se cierra sola. Si se cerrara pulsando fuera o con Escape, el
       bloqueo seria un adorno. */
    back.click();
    ok('sector: no se cierra al pulsar fuera', back.classList.contains('open'),
       back.className, 'sigue abierta');
    document.dispatchEvent(new KeyboardEvent('keydown', {key:'Escape'}));
    ok('sector: ni con Escape', back.classList.contains('open'),
       back.className, 'sigue abierta');

    /* Sin elegir no deja pasar, pero DICE por que: una puerta que no se
       abre y no explica nada es una pantalla rota. */
    document.getElementById('seGuardar').click();
    ok('sector: sin elegir no deja pasar', back.classList.contains('open'),
       back.className, 'sigue abierta');
    var esperado = ((window.CIIP_PASOS.ui[curLang] || {}).se_falta || '');
    igual('sector: y dice por que no',
          document.getElementById('seAviso').textContent.trim(), esperado);

    /* Y siempre hay por donde salir: bloquear sin salida es encerrar. */
    var btSalir = document.getElementById('seSalir');
    ok('sector: y se puede salir de la cuenta', !!btSalir, 'hay boton', 'hay boton');

    /* Que el boton ESTÉ no es que funcione, y esta prueba se quedó ahí.
       Llamaba a signOut() sin esperarlo y se iba en la misma línea: la
       petición quedaba a medias, la sesión seguía en el navegador y el
       acceso —que mira si hay sesión y devuelve al panel— metía otra vez
       dentro. Darle a "salir" te dejaba donde estabas.

       Se mide que sale por ciipSalir(), que es el único camino que espera
       a que la sesión se cierre de verdad antes de irse. Se sustituye por
       uno de mentira: el de verdad navega, y ahí se acabaría el arnés. */
    ok('sector: y el panel sabe cerrar la sesion',
       typeof window.ciipSalir === 'function',
       typeof window.ciipSalir, 'function');
    var salioPor = 'nada';
    var salirDeVerdad = window.ciipSalir;
    window.ciipSalir = function(){ salioPor = 'ciipSalir'; return Promise.resolve(); };
    if (btSalir) btSalir.click();
    window.ciipSalir = salirDeVerdad;
    if (btSalir) btSalir.disabled = false;
    igual('sector: y salir cierra la sesion antes de irse', salioPor, 'ciipSalir');

    /* ── El idioma, sin salir ──
       La puerta tapa la barra de arriba. Quien abriera el panel en un
       idioma que no entiende se quedaba delante de una pregunta que no
       deja pasar, con cerrar sesion como unica salida. */
    var banderas = document.querySelectorAll('#seLang button');
    igual('sector: se puede cambiar de idioma sin salir', banderas.length, 6);
    var eraTitulo = document.getElementById('seTitulo').textContent.trim();
    var eraLang = curLang;
    document.querySelector('#seLang button[data-lang="es"]').click();
    igual('sector: y la pregunta se repinta en el nuevo',
          document.getElementById('seTitulo').textContent.trim(),
          window.CIIP_PASOS.ui.es.se_titulo);
    ok('sector: y no se queda con el texto de antes',
       document.getElementById('seTitulo').textContent.trim() !== eraTitulo,
       eraTitulo.slice(0, 30), 'otro distinto');
    /* Los sectores tambien se retraducen: son el contenido, no el marco. */
    igual('sector: y los sectores tambien se traducen',
          document.querySelectorAll('#seLista .se-op')[0].textContent.trim(),
          window.CIIP_PASOS.sectores.es.s1);
    /* Y se vuelve al de este pase: si no, todo lo que corre despues
       mediria una pantalla en un idioma que nadie eligio. */
    document.querySelector('#seLang button[data-lang="' + eraLang + '"]').click();
    igual('sector: y se puede volver al de antes', curLang, eraLang);

    /* Se elige el segundo -mineria- y se contesta. La lista se rehizo al
       cambiar de idioma, asi que se vuelve a pedir: la de antes son nodos
       que ya no estan en la pagina. */
    ops = document.querySelectorAll('#seLista .se-op');
    ops[1].click();
    var puestos = document.querySelectorAll('#seLista .se-op.puesto');
    igual('sector: al elegir se marca uno, y solo uno', puestos.length, 1);
    document.getElementById('seGuardar').click();
  }

  function puertaTrasResponder(){
    if (PASE !== 'sinsector') return;
    var back = document.getElementById('sectorBack');
    ok('sector: al contestar, se entra', !back.classList.contains('open'),
       back.className, 'cerrada');
    ok('sector: y el panel deja de estar bloqueado',
       !document.body.classList.contains('con-puerta'),
       document.body.className || 'sin clase', 'sin con-puerta');
    ok('sector: y queda guardado en el perfil',
       (typeof PERFIL !== 'undefined' && PERFIL.sector === 'mineria'),
       (typeof PERFIL !== 'undefined' ? (PERFIL.sector || 'ninguno') : 'sin PERFIL'),
       'mineria');
  }

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
       mismo catálogo de once trámites cuenta distinto según quién mira, que
       es justo lo que un marcador escrito a mano no podía hacer. */
    igual('camino: la fase 01 cuenta lo que tú llevas hecho', deEtapa(0, '.jcount'),
          (CASO === 'lleno') ? '1 de 11 listos' : '0 de 11 listos');
    /* SIETE, y antes eran ocho. No se ha perdido ninguna: el registro de
       marca está APAGADO en el catálogo, y desde que el interruptor gobierna
       la portada, lo apagado no se enseña ni se cuenta.

       Contar ocho y ofrecer siete sería lo peor de los dos mundos: el camino
       prometiendo un trámite que no está debajo. La cuenta dice lo que hay.
       Y en cuanto el CIIP lo encienda vuelve a ser ocho sin recargar, que eso
       lo comprueba el bloque de «sin pulsar F5». */
    igual('camino: la fase 02 cuenta las que están encendidas',
          deEtapa(1, '.jcount'), '0 de 7 listos');
    igual('camino: la fase 03 cuenta sus 11',          deEtapa(2, '.jcount'), '0 de 11 listos');
    /* Tres desde que las fases 4 y 5 se fundieron: el registro de la
       inversión extranjera tenía una etapa para él solo —y una etapa con una
       sola tarjeta dentro— y ahora comparte la 4 con el banco de activos y
       las solvencias. Ya no hay quinta. */
    igual('camino: la fase 04 cuenta sus 3',           deEtapa(3, '.jcount'), '0 de 3 listos');

    (function(){
      var barra = etapas()[0].querySelector('.jbar > span');
      igual('camino: la barra de la fase 01 mide lo hecho', barra.style.width,
            /* 1 de 11, no 1 de 10: la fase 1 gano el c33. */
            (CASO === 'lleno') ? '9%' : '0%');
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

    /* ── EL FILTRO NO PUEDE PROMETER MAS TARJETAS DE LAS QUE HAY DEBAJO ──
       Aqui se exigia un 32: los filtros contaban el panel entero. Desde que
       la portada abre con una etapa elegida cuentan LA ETAPA ABIERTA, que es
       lo unico que se ve; un 32 encima de una lista de once seria el mismo
       engaño que se acaba de quitar de las tarjetas.

       Y no se compara contra un numero escrito aqui -el catalogo crece y la
       copia se queda vieja, que es como esta prueba acabo pidiendo 32 con
       once delante-, sino contra las tarjetas de la etapa abierta. Eso solo
       repetiria la cuenta del panel, asi que va con una segunda mitad que no
       la repite: que no se vea NINGUNA tarjeta de otra etapa.

       El numero escrito a mano en el marcado no se mira aqui: el arnes lee
       el DOM, o sea lo que el script ya reescribio, asi que le llega
       corregido. Eso vive en pruebas/claves.js, que lee el archivo. */
    (function(){
      var abierta = document.querySelector('.phase.etapa-abierta');
      var suyas = abierta ? abierta.querySelectorAll('.tcard') : [];
      igual('camino: el filtro de todos cuenta las de la etapa abierta',
            (document.querySelector('.ftab[data-f="todos"] .n') || {}).textContent,
            String(suyas.length));

      /* La mitad que no es repetir su cuenta: que no haya NINGUNA tarjeta de
         otra etapa a la vista. Si el numero saliera bien contando el panel
         entero, o si abajo se colara la lista de otra fase, esto se cae.
         Los pasos opcionales van plegados y no se ven; entran igual en el
         numero, y eso esta bien: estan ahi, a un golpe de «Ver 2 pasos
         opcionales», no en otra pantalla. */
      var deOtra = [].filter.call(
        document.querySelectorAll('#secTramites .tcard'),
        function(c){ return c.offsetParent !== null && (!abierta || !abierta.contains(c)); });
      ok('camino: y no se ve ninguna tarjeta de otra etapa',
         suyas.length > 0 && deOtra.length === 0,
         deOtra.length ? ('se cuelan: ' + deOtra.map(function(c){
           return c.getAttribute('data-tr'); }).join(', '))
                       : (suyas.length + ' en la etapa abierta'),
         'ninguna de fuera');
    })();

    /* ═══════════ EL ESTADO DE CADA TARJETA ═══════════
       Iba escrito a mano en las 33: tres decían "Completado" y una fecha de
       emisión de un trámite que nadie había pedido. Los cuatro filtros de
       arriba contaban esos ejemplos. */
    (function(){
      function st(ref){ return (document.querySelector('.tcard[data-tr="' + ref + '"]') || {getAttribute:function(){return null;}}).getAttribute('data-st'); }
      function chip(ref){ var c = document.querySelector('.tcard[data-tr="' + ref + '"] .t-top .chip'); return c ? c.textContent.trim() : ''; }
      /* ── DESHACER EL PLAZO DEL RELOJ ──
     El renglon dice el estimado en la unidad en la que se piensa: 7 dias son
     «1 semana» y 240 son «8 meses». Esto va al reves -del renglon al numero-
     para comprobar que la conversion es EXACTA sin volver a escribir aqui la
     regla que la elige. Los moldes salen del diccionario, asi que vale en los
     seis idiomas sin una lista de palabras a mano. Devuelve dias, o null. */
  function deshaceElPlazo(dice, dic){
    var MOLDES = [['t.estmes', 30], ['t.estmesN', 30],
                  ['t.estsem',  7], ['t.estsemN',  7],
                  ['t.est1', 1], ['t.estN', 1]];
    function escapa(s){ return s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'); }
    for (var i = 0; i < MOLDES.length; i++){
      var molde = String((dic || {})[MOLDES[i][0]] || '');
      if (!molde) continue;
      var trozos = molde.split('{n}');
      var re = new RegExp('^' + trozos.map(escapa).join('(\\d+)') + '$');
      var m = re.exec(String(dice || '').trim());
      if (!m) continue;
      return (trozos.length > 1 ? parseInt(m[1], 10) : 1) * MOLDES[i][1];
    }
    return null;
  }

  /* A quién espera una ficha. Vive en el atributo desde que el reloj se
     quedó sólo para el tiempo; lleva la REFERENCIA del trámite que bloquea. */
  function esperaDe(ref){
    var c = document.querySelector('.tcard[data-tr="' + ref + '"]');
    return c ? (c.getAttribute('data-espera') || '') : '';
  }

  function reloj(ref){ var t = document.querySelector('.tcard[data-tr="' + ref + '"] .t-time'); return t ? t.textContent.trim() : ''; }

      /* ── «Esperando: …» EN EL IDIOMA DE TURNO ──
         Ese renglón lo escribe pintaCuando a mano y le QUITA el data-i18n
         a su hueco, asi que applyLang ya no puede alcanzarlo: si se pinta
         antes de que el panel resuelva tu idioma, se queda congelado.
         En produccion se veia «Waiting on: Visa de inversionista» dentro
         de un panel entero en castellano.
         Se comprueba contra el molde del diccionario y no contra la frase
         escrita aqui: escribirla obligaria a tocar esta prueba cada vez
         que se retoque el texto, y una prueba que hay que retocar acaba
         retocandose hasta que pasa.

         LO QUE ESTA PRUEBA NO VE, dicho para que nadie se fie de mas: si
         el diccionario tiene el ingles bajo la etiqueta 'es' -que es
         justamente como aparecio este renglon en produccion- esto pasa
         tan tranquilo, porque compara lo pintado con el diccionario y los
         dos dicen lo mismo, los dos mal. Se comprobo: con los idiomas
         cruzados a proposito, las 4605 pruebas siguieron en verde.
         De los idiomas cruzados se encarga «escritura: ningun texto esta
         bajo la bandera de otro idioma», en pruebas/claves.js. Hacen
         falta las dos: esta ve que el renglon no se quede congelado en el
         idioma de arranque, y aquella que el diccionario diga la verdad. */
      (function(){
        /* Esto vigilaba el «Esperando: …», que ya no se escribe: el reloj es
           para el tiempo y a quien esperas vive en data-espera. El RIESGO no
           se fue con la frase, solo cambio de sujeto -el renglon lo sigue
           escribiendo pintaCuando a mano, sin data-i18n que lo alcance-, asi
           que la prueba se queda y mira lo que hay ahora.

           Las que esperan a otra son justo las que antes NO enseñaban el
           estimado: si alguien vuelve a dejar que otra cosa gane el renglon,
           aqui se ve primero. Y se DESHACE la cifra, para que esto no pase
           con un numero cualquiera: tiene que ser el de la base. */
        var dic2 = (I18N[curLang] || I18N.en) || {};
        var cat = window.CIIP_TIPOS_POR_REF || {};
        var esperando = document.querySelectorAll('.tcard.espera');

        /* Con el estimado apagado a proposito, lo que hay que ver es lo
           contrario: que ninguna diga un plazo, y que el reloj vacio se
           esconda en vez de quedarse con el icono solo. */
        if (!window.CIIP_ESTIMADO_EN_FICHA){
          var hablan = [], iconoSolo = [];
          [].forEach.call(document.querySelectorAll('.tcard'), function(c){
            var t = c.querySelector('.t-time');
            if (!t) return;
            var dice = (t.textContent || '').trim();
            if (dice && deshaceElPlazo(dice, dic2) !== null) hablan.push(c.getAttribute('data-tr'));
            if (!dice && !t.hidden) iconoSolo.push(c.getAttribute('data-tr'));
          });
          igual('estados: apagado, ninguna ficha dice su estimado',
                hablan.length ? hablan.join(', ') : '(ninguna)', '(ninguna)');
          igual('estados: y el reloj sin nada que decir se esconde',
                iconoSolo.length ? iconoSolo.join(', ') : '(ninguno)', '(ninguno)');
        }

        if (window.CIIP_ESTIMADO_EN_FICHA){
          var mal = [], conCifra = 0;
          [].forEach.call(esperando, function(c){
            var v = cat[c.getAttribute('data-tr')] || {};
            if (!v.plazo_dias) return;
            conCifra++;
            var t = c.querySelector('.t-time');
            var dice = ((t && t.textContent) || '').trim();
            if (deshaceElPlazo(dice, dic2) !== v.plazo_dias)
              mal.push(c.getAttribute('data-tr') + ': "' + dice.slice(0, 40) + '"');
          });
          ok('estados: la que espera dice su tiempo, en el idioma del panel',
             conCifra > 0 && mal.length === 0,
             conCifra ? (mal.join(' | ') || 'las ' + conCifra + ' en ' + curLang)
                      : 'ninguna esperando con cifra',
             'todas con su plazo de la base');
        }

        /* Y sigue sabiendo a quien espera, aunque ya no lo escriba: sin esto,
           borrar el calculo entero pasaria igual de verde. */
        var sinRastro = [];
        [].forEach.call(esperando, function(c){
          if (!(c.getAttribute('data-espera') || '').trim())
            sinRastro.push(c.getAttribute('data-tr'));
        });
        igual('estados: y la ficha sigue sabiendo a quien espera',
              sinRastro.length ? sinRastro.join(', ') : '(ninguna)', '(ninguna)');
      })();

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
      ok('estados: y ninguna de las 33 inventa una fecha de emisión',
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

        /* ── LOS FILTROS, ETAPA POR ETAPA ──
           Cuentan la etapa que está abierta, no el panel entero, así que
           aquí hace falta decir DÓNDE está cada cosa o el número no
           significa nada. Los dos que te reclaman -el RIF de empresa y la
           constitución- viven en la 02, y son los que hacen que la portada
           abra ahí; el RIF personal en marcha y la visa resuelta están en la
           01, y para verlos contados hay que pulsarla.

           Que los cinco números no salgan a la vez es la consecuencia de la
           decisión, y por eso se prueba así en vez de sumarlos todos: si
           algún día vuelven a contar el panel entero, estas dos mitades se
           caen y hay que venir a mirar. */
        igual('estados: el filtro de acción cuenta los dos, en su etapa',
              document.querySelector('.ftab[data-f="accion"] .n').textContent, '2');

        (function(){
          var laUna = document.querySelector('.jp[data-ir="1"]');
          if (!laUna) return;
          laUna.click();
          igual('estados: y en la 01, el de en proceso cuenta el uno',
                document.querySelector('.ftab[data-f="proceso"] .n').textContent, '1');
          igual('estados: y el de completados, el resuelto',
                document.querySelector('.ftab[data-f="listo"] .n').textContent, '1');

          /* Y se devuelve la portada a COMO ABRIÓ, no a la 02 con otro
             golpe: pulsar deja apagada la elección automática, y las pruebas
             de más abajo comprueban justamente qué elige sola. Se borra la
             marca y se le pide que vuelva a elegir. */
          document.querySelectorAll('.jp[data-ir]').forEach(function(e){
            e.classList.remove('active');
            e.removeAttribute('data-aqui');
            e.setAttribute('aria-pressed', 'false');
          });
          if (window.CIIP_ELIGE_SOLA) window.CIIP_ELIGE_SOLA();
        })();
        ok('estados: un trámite resuelto pone su tarjeta en verde',
           st('c1') === 'listo' && chip('c1') === 'Completado',
           st('c1') + ' / ' + chip('c1'), 'listo / Completado');
      }

      if (CASO === 'vacio'){
        /* Dos del mismo trámite: un borrador viejo y una revisión en
           marcha. La tarjeta enseña la de ahora, no la que se quedó atrás. */
        igual('estados: entre dos del mismo trámite manda la más reciente', st('c3'), 'proceso');
      }

      if (CASO === 'sinnombre'){
        /* Este expediente tiene UN borrador, asi que su tarjeta no puede
           decir "por iniciar": 32 y no 33. Y de paso se comprueba lo que
           ninguna prueba miraba, que el borrador se vea en su tarjeta.
           Desde que se retiro la franja de "te toca a ti", esta es la
           unica pantalla que lo dice. */
        var pendS = document.querySelectorAll('.tcard[data-st="pendiente"]').length;
        ok('estados: con un borrador, treinta y dos por iniciar y no treinta y tres',
          /* 31 y no 32: el registro de marca esta apagado y su tarjeta ya no
             esta en el documento, asi que no puede decir «por iniciar» ni
             ninguna otra cosa. Una menos arriba y una menos abajo. */
             pendS === 31, pendS + ' por iniciar de 32 ofrecidas', '31');
        igual('estados: y la tarjeta del borrador pide tu accion', st('c1'), 'accion');
      }

      if (CASO === 'gestor'){
        /* Las 33: las 32 solicitables más la del banco de activos, que ya
           nacía 'pendiente' en el marcado -lo suyo es el distintivo, que
           sigue diciendo Disponible-. */
        var pend = document.querySelectorAll('.tcard[data-st="pendiente"]').length;
          ok('estados: sin ningún trámite, ninguna tarjeta promete nada', pend === 32,
             pend + ' por iniciar de 32 ofrecidas', '32');
      }

      /* ── la cadena entre trámites ──
         No está escrita en ninguna lista: se deduce cruzando los recaudos
         que pide cada trámite con el papel que emite cada otro. Si mañana
         se le quita un recaudo al c5, la cadena se recoloca sola y estas
         dos pruebas lo dirán.

         Las dos van en 'vacio' porque es el único expediente cuya bóveda
         no trae el RIF personal, y sin esa falta no hay nada que esperar. */
      if (CASO === 'vacio'){
        /* El c5 pide el RIF personal, ese papel no está aquí, y lo emite
           el c3. La tarjeta lo dice con su nombre, en vez del «Estimado:
           2–3 semanas» que llevaba escrito a mano. */
        /* Se pregunta al ATRIBUTO. El reloj lo decia con el nombre del
           tramite y ahi se leia; desde que ese renglon es solo para el
           tiempo, lo que la ficha deduce vive en data-espera, igual que su
           estado vive en data-st. Y se gana algo: el atributo lleva la
           REFERENCIA, asi que esto pregunta por 'c3' en vez de por cinco
           maneras de escribir «RIF personal» -esa lista se quedaba coja con
           el sexto idioma-. */
        ok('cadena: sin el papel, la tarjeta apunta a quién espera',
           esperaDe('c5') === 'c3', esperaDe('c5') || '(a nadie)', 'c3');

        /* Y ésta es la que separa "encadenar por el PAPEL" de "encadenar
           por el TRÁMITE".

           El c6 pide dos papeles que alguien emite: el acta —del c5— y el
           RIF personal —del c3—. El acta YA está en esta bóveda; el RIF
           personal no. Así que tiene que esperar al c3 y NO al c5, aunque
           el acta aparezca antes en su lista de recaudos.

           Si se encadenara por el trámite anterior, o si se olvidara mirar
           lo que ya tienes, diría «Constitución» y esto se pondría rojo. */
        ok('cadena: espera al papel que falta, no al primero de la lista',
           esperaDe('c6') === 'c3', esperaDe('c6') || '(a nadie)', 'c3');
      }

      /* ── el plazo, comparado ──
         El panel ya enseñaba «Estimado: 2–3 semanas» y «lleva 40 días» en
         la misma tarjeta, sin juntarlos nunca. Aquí se comprueba que ya
         hace la resta. */
      if (CASO === 'lleno'){
        /* t3 es un RIF personal enviado hace más días que su plazo. */
        ok('plazo: si tarda más de lo prometido, la tarjeta lo dice',
           /lento|Slower|lentamente|previsto|预期|медленнее/i.test(reloj('c3')),
           reloj('c3'), 'que va más lento de lo previsto');

        /* Y ésta es la que importa: t4 es la visa, que tardó MUCHO más que
           su plazo... pero ya está resuelta. No se puede llegar tarde a
           algo que ya llegó, y decirlo sería convertir el aviso en ruido
           sobre expedientes cerrados.

           Si el aviso se calculara sólo con la resta de fechas, sin mirar
           el estado, esta prueba se pondría roja. */
        ok('plazo: uno ya resuelto no se marca, aunque tardara de más',
           !/lento|Slower|lentamente|previsto|预期|медленнее/i.test(reloj('c1')),
           reloj('c1'), 'sin marcar, porque ya terminó');
      }

      /* El banco de activos no es una solicitud —por eso tiene vista
         propia— y su distintivo no puede pasar a "por iniciar". */
      igual('estados: el banco de activos sigue diciendo Disponible', chip('c15'), 'Disponible');

      /* ── el nivel de cada tramite ──
         Del informe del 2 de septiembre: «que a la vista el inversionista
         no sienta que debe concretar todos los tramites». Treinta y tres
         tarjetas iguales son un muro.

         Esto faltaba: se hizo el distintivo y no se comprobo que llegara a
         pintarse. El nivel sale del catalogo, asi que entre la columna de
         la base y el marcado hay tres sitios donde puede perderse -el
         select, el reparto de claves y el diccionario- y ninguno avisa.

         Se miran los tres casos, y el tercero es el que importa tanto como
         los otros dos: 'esencial' es el caso normal y NO lleva nada. Un
         distintivo en todas las tarjetas no distingue nada. */
      (function(){
        function niv(ref){
          var c = document.querySelector('.tcard[data-tr="' + ref + '"] .chip.niv');
          return c ? c.textContent.trim() : '';
        }
        /* ── QUIEN LO PIDE, O NADA ──
           Decia «Obligatorio», y el CIIP lo quito con un motivo que no es de
           estilo: una ventanilla unica no obliga a nadie. Quien exige es la
           ley o el organismo.

           Asi que ahora dice quien lo pide, y SOLO cuando se sabe. El dato
           no existe todavia -lo tiene que decir el CIIP, tramite por
           tramite- y por eso hoy casi ninguna tarjeta lleva distintivo.

           Se comprueban las DOS mitades. Sin la segunda, vaciar el
           diccionario entero pasaria por bueno: todo callado es todo
           correcto si solo se mira que no diga «Obligatorio». */
        ok('nivel: el obligatorio ya no dice Obligatorio',
           niv('c3') !== 'Obligatorio', '"' + niv('c3') + '"', 'cualquier cosa menos eso');

        igual('nivel: sin saber quien lo pide, no dice nada', niv('c3'), '');

        /* Y con el dato puesto, lo dice. Se rellena a mano lo que el CIIP
           rellenara en el guion, y se repinta. */
        if (window.CIIP_EXIGE && window.CIIP_REPINTA_ESTADOS){
          window.CIIP_EXIGE.c3 = 'SAIME';
          window.CIIP_REPINTA_ESTADOS();
          igual('nivel: y sabiendolo, dice quien lo pide', niv('c3'), 'Lo pide el SAIME');

          var pide = document.querySelector('.tcard[data-tr="c3"] .chip.niv');
          ok('nivel: y se distingue del resto',
             !!pide && pide.classList.contains('obliga'),
             pide ? pide.className : 'no hay distintivo', 'chip niv obliga');

          /* Y se deja como estaba: una prueba que cambia el catalogo y no lo
             devuelve le mueve el suelo a las de despues. */
          delete window.CIIP_EXIGE.c3;
          window.CIIP_REPINTA_ESTADOS();
        }

        igual('nivel: el que depende del ramo tambien', niv('c13'), 'Según tu actividad');
        igual('nivel: y el corriente no lleva nada',  niv('c6'),  '');
      })();

      /* AQUI SE MEDIA el renglon de «Te quedan N de T por hacer», que
         contaba solo los obligatorios de cada etapa. El CIIP lo quito de la
         tarjeta: ya lleva su cuenta -«0 de 8 listos»- y dos numeros seguidos
         que cuentan cosas distintas se leen como uno mal puesto.

         Se van con el sus seis comprobaciones. No se dejan «por si acaso»:
         una prueba de algo que no existe no protege nada y hace creer que
         si. El nivel de cada tramite sigue en el catalogo, asi que el dia
         que vuelva, vuelven. */

      /* ── los opcionales, apartados ──
         «Los que son opcionales quiero que los coloques en una lista aparte,
         que cuando se dé clic salga la información pero que no estén siempre
         a la vista.» (CIIP, 2 de septiembre de 2026)

         Lo que hay que comprobar no es que se oculten -eso lo hace una
         linea de CSS- sino que sigan estando: apartar y esconder se ven
         igual en la primera pantalla y sólo se distinguen al buscarlos.
         Por eso van las cuatro: que la caja empiece cerrada, que el rótulo
         diga cuántos hay, que el clic los saque, y que la cuenta de la
         etapa siga siendo la misma que antes de apartarlos. */
      (function(){
        var f1 = document.querySelector('[data-fase="1"]');
        var caja = f1 && f1.querySelector('.opc-caja');
        var btn  = caja && caja.querySelector('.opc-btn');
        var rej  = caja && caja.querySelector('.opc-rejilla');
        ok('opcionales: la fase 01 tiene su lista aparte', !!(caja && btn && rej),
           caja ? 'caja incompleta' : 'no hay caja', 'caja, botón y rejilla');
        if (!(caja && btn && rej)) return;

        /* Cerrada al entrar, que es todo el encargo. */
        igual('opcionales: empieza cerrada',        rej.hidden, true);
        igual('opcionales: y el botón lo declara',  btn.getAttribute('aria-expanded'), 'false');
        igual('opcionales: el rótulo dice cuántos', btn.textContent.trim(), 'Ver los 2 opcionales');

        /* Dentro de la caja, y fuera de la rejilla principal: si sólo se
           ocultaran con CSS seguirían colgando de #trs-1 y esta prueba
           pasaría igual estando el encargo sin hacer. */
        igual('opcionales: los dos están dentro de la caja',
          rej.querySelectorAll('.tcard[data-tr]').length, 2);
        igual('opcionales: y ya no cuelgan de la rejilla de la fase',
          document.querySelectorAll('#trs-1 > .tcard[data-tr="c19"], #trs-1 > .tcard[data-tr="c20"]').length, 0);

        /* Apartar NO es quitar. La etapa sigue diciendo once, no nueve:
           el inversionista tiene once trámites en la fase 01, estén donde
           estén en la pantalla. */
        /* Sólo el total: cuántos lleva hechos cambia según por dónde vaya
           la tanda, y ese no es el punto. El punto es el once. */
        igual('opcionales: la etapa los sigue contando',
          (deEtapa(0, '.jcount') || '').split(' de ')[1], '11 listos');

        /* El clic, que es la otra mitad de «que cuando se dé clic salga la
           información». */
        btn.click();
        igual('opcionales: el clic los saca',            rej.hidden, false);
        igual('opcionales: y el botón cambia de rótulo', btn.textContent.trim(), 'Ocultar los opcionales');
        btn.click();
        igual('opcionales: el segundo clic los recoge',  rej.hidden, true);

        /* Y si uno de los apartados pide acción, la caja se abre sola.
           Un trámite devuelto detrás de un botón cerrado es peor que no
           haberlo apartado: el aviso está, pero no se ve. */
        var c19 = document.querySelector('.tcard[data-tr="c19"]');
        var era = c19.getAttribute('data-st');
        c19.setAttribute('data-st', 'accion');
        window.CIIP_APARTA_OPCIONALES();
        igual('opcionales: uno devuelto abre la caja solo', rej.hidden, false);
        c19.setAttribute('data-st', era);

        /* Llamarla dos veces no puede duplicar nada: la rejilla de dentro
           lleva también class grid-tr, y el recorrido llegó a encontrarse a
           sí mismo y a meter una caja dentro de la caja. */
        window.CIIP_APARTA_OPCIONALES();
        igual('opcionales: repintar no duplica la caja',
          f1.querySelectorAll('.opc-caja').length, 1);

        /* Aquí había otra que miraba la fase 4 para decir que una fase sin
           nada que apartar no estrena botón. Al fundirse la 4 con la 5, esa
           fase pasó a tener un opcional, y la comprobación de más abajo
           -«la que no tiene obligatorios se queda entera»- mide lo mismo
           sobre la misma fase y además con un caso más difícil. Se quita
           en vez de dejar dos nombres distintos para una sola cosa. */
      })();

      /* ── el nombre no repite lo que ya dice el ente ──
         Al renombrar las tarjetas de la fase 3 con los nombres del informe,
         varias venian con el organismo entre parentesis: «Habilitacion
         Aduanera y Comercio Exterior (VUCE)», «Calificacion para
         Contratacion Publica (RNC)». Y el galon del ente sale justo debajo,
         en el mismo golpe de vista, diciendo VUCE y RNC.

         Se quitaron esos, y NO los que anaden algo: «(licencia municipal)»
         se queda, porque el ente de esa tarjeta dice «Alcaldia» y la gente
         la conoce por el otro nombre.

         Esto no fija los NOMBRES -son contenido, los decide el CIIP y
         cambian- sino la regla. Un nombre que repite su propio ente entra
         solo, sin que nadie lo note, y son treinta y tres tarjetas. */
      (function(){
        /* Sobre el DICCIONARIO y no sobre lo pintado, y es la diferencia
           entre medir y no medir: la tarjeta enseña un solo idioma a la vez,
           así que mirando el DOM se comprueba uno de seis. Se saboteó el
           nombre en castellano y la prueba salió verde porque la pantalla
           iba en inglés.

           El ente es el mismo en los seis -es una sigla, no se traduce-, así
           que se lee del marcado una vez y se cruza con las seis. */
        var entes = {};
        document.querySelectorAll('.tcard[data-tr]').forEach(function(c){
          var eb = (c.querySelector('.t-ente .ebadge') || {}).textContent || '';
          if (eb.trim()) entes[c.getAttribute('data-tr')] = eb.trim().toLowerCase();
        });

        var repes = [];
        Object.keys(I18N).forEach(function(lang){
          Object.keys(I18N[lang]).forEach(function(clave){
            var m = clave.match(/^(c[0-9]+)\.name$/);
            if (!m || !entes[m[1]]) return;
            /* El paréntesis del final, ENTERO. Aquí estuvo escrito
               /(([^)]+))s*$/ —sin las barras invertidas, que se perdieron al
               escribir el fichero— y esa expresión no puede coincidir NUNCA:
               la cadena acaba en «)» y ni [^)] ni s* lo aceptan. La prueba
               existía, corría, y no medía nada. Salió sólo al romper el
               código a propósito y ver que seguía verde. */
            var par = String(I18N[lang][clave]).match(/\(([^)]+)\)\s*$/);
            if (par && par[1].trim().toLowerCase() === entes[m[1]])
              repes.push(lang + ' ' + m[1] + ' «' + I18N[lang][clave] + '»');
          });
        });
        igual('tarjetas: ningún nombre repite entre paréntesis su propio ente',
              repes.join(' · '), '');
      })();

      /* ── los que van juntos ──
         «Inscripción IVSS/INCES/FAOV/RNET: Cumplimiento de Obligaciones
         Parafiscales y Laborales.» (informe del 2 de septiembre de 2026)

         Cuatro trámites ante cuatro organismos que el inversionista hace
         de una vez, y que estaban desperdigados entre los once de la fase
         con permisos ambientales de por medio. */
      (function(){
        var rej = document.getElementById('trs-3');
        var t   = rej && rej.querySelector('.grupo-t');

        ok('grupo: la fase 03 lleva su título de grupo', !!t,
           t ? t.textContent : 'no hay título', 'un título');
        if (!t) return;

        igual('grupo: y dice de qué son', t.textContent.trim(),
              'Obligaciones parafiscales y laborales');

        /* Y lo escribe QUIEN LO CREA, sin depender de que pase applyLang
           después. Se comprueba quitando el título y volviéndolo a pedir,
           porque si no las dos cosas se tapan: el rótulo lo pinta también
           el data-i18n, así que romper una de las dos no se notaba y el
           sabotaje salía verde. Sin esto habría un parpadeo en blanco
           entre que se crea y se traduce. */
        t.parentNode.removeChild(t);
        if (window.CIIP_JUNTA_GRUPOS) window.CIIP_JUNTA_GRUPOS();
        t = rej.querySelector('.grupo-t');
        ok('grupo: nace ya con su texto, sin esperar a applyLang',
           !!t && t.textContent.trim() === 'Obligaciones parafiscales y laborales',
           t ? (t.textContent.trim() || '(vacío)') : 'no volvió a salir',
           'Obligaciones parafiscales y laborales');
        if (!t) return;

        /* Y lleva data-i18n, que es como se traduce todo lo demás del
           panel: applyLang lo repinta al cambiar de idioma sin que haya
           que volver a montar las tarjetas. */
        igual('grupo: y se traduce como cualquier otro rótulo',
              t.getAttribute('data-i18n'), 'g.parafiscal');

        /* Y el SEGUNDO grupo: las licencias sectoriales, que son dos y de
           dos organismos distintos. Se mira aparte porque con uno solo la
           función podría estar escrita para un caso y no para una lista, y
           eso no se ve hasta que llega el segundo. */
        var t2 = rej.querySelector('.grupo-t[data-grupo="g.sectorial"]');
        ok('grupo: y el de las licencias sectoriales también', !!t2,
           t2 ? t2.textContent.trim() : 'no está', 'Licencias sectoriales');
        if (t2){
          var h2 = [].slice.call(rej.children);
          var j  = h2.indexOf(t2);
          igual('grupo: con sus dos detrás',
                h2.slice(j+1, j+3).map(function(e){ return e.getAttribute('data-tr'); }).join(' '),
                'c12 c30');
        }
        igual('grupo: y son dos títulos, no uno repetido',
              rej.querySelectorAll('.grupo-t').length, 2);

        /* Las cuatro, JUNTAS y detrás del título. Se lee la rejilla tal
           como quedó, en orden, y se comprueba que los cuatro que siguen
           al título son exactamente esos: si una se quedara donde estaba,
           el título estaría encabezando a otra cosa. */
        var hijos = [].slice.call(rej.children);
        var i = hijos.indexOf(t);
        var siguen = hijos.slice(i + 1, i + 5)
          .map(function(e){ return e.getAttribute('data-tr'); });
        igual('grupo: las cuatro van detrás y en orden',
              siguen.join(' '), 'c9 c25 c26 c27');

        /* Y el título es UN HIJO MÁS de la rejilla, no una caja con las
           tarjetas dentro. Es lo que hace que nada de lo que las cuenta
           se entere: acaba de pasar con los recaudos, donde meter una
           lista dentro de cada renglón hizo que seis contaran 52. */
        igual('grupo: la fase 03 sigue teniendo sus once tarjetas',
              rej.querySelectorAll(':scope > .tcard[data-tr]').length, 11);
        ok('grupo: y el título no es una tarjeta',
           !t.classList.contains('tcard') && !t.hasAttribute('data-tr'),
           t.className, 'sin ser tarjeta');

        /* Ocupa la fila entera. Sin esto cae en una de las dos columnas y
           deja media fila vacía a su lado, que se ve como un hueco y no
           como un encabezado. */
        ok('grupo: el título ocupa la fila entera',
           /1\s*\/\s*(-1|end)/.test(window.getComputedStyle(t).gridColumn) ||
             window.getComputedStyle(t).gridColumnStart === '1',
           window.getComputedStyle(t).gridColumn, '1 / -1');

        /* Repintar no duplica el título. Es el mismo fallo que tuvo la
           caja de opcionales al encontrarse a sí misma. */
        if (window.CIIP_JUNTA_GRUPOS) window.CIIP_JUNTA_GRUPOS();
        /* Por GRUPO y no en total: contar todos los títulos hacía que
           añadir el segundo -las licencias sectoriales- pusiera esto en
           rojo sin que nada estuviera mal. Lo que no puede pasar es que un
           grupo salga dos veces, no que haya dos grupos. */
        igual('grupo: repintar no lo duplica',
              rej.querySelectorAll('.grupo-t[data-grupo="g.parafiscal"]').length, 1);
        igual('grupo: y las cuatro siguen donde estaban',
              [].slice.call(rej.children)
                .slice([].slice.call(rej.children).indexOf(t) + 1, 
                       [].slice.call(rej.children).indexOf(t) + 5)
                .map(function(e){ return e.getAttribute('data-tr'); }).join(' '),
              'c9 c25 c26 c27');

        /* Y se traduce al cambiar de idioma, como cualquier otro rótulo:
           lleva data-i18n, así que de eso se encarga applyLang. */
        (function(){
          var antes = curLang;
          applyLang('en');
          igual('grupo: y se traduce', t.textContent.trim(),
                'Payroll and parafiscal obligations');
          applyLang(antes || 'es');
        })();
      })();

      /* ── y la misma regla en las demás fases ──
         «¿Podemos trabajar las otras fases de la misma manera?» (CIIP).

         La regla no es «lo opcional» sino «lo que no bloquea al CIIP», y
         sólo donde haya algo que sí bloquee. Las tres cosas que se miran
         aquí son las tres que distinguen esa regla de la ingenua, y las
         tres se ven igual en la primera pantalla si se hace mal. */
      (function(){
        var cat = window.CIIP_TIPOS_POR_REF || {};

        /* 1. La fase 02 enseña sus OCHO y no aparta nada.

              «Dicha etapa es la más importante en el panel [...] quiero
              que tenga estas 8 opciones.» (CIIP, 2 de septiembre de 2026)

              Aquí llegó a apartar tres —la marca, la cuenta bancaria y los
              libros, que en la base son 'esencial'— y la fase se quedó
              enseñando cinco. Esta prueba es lo que impide que vuelva a
              pasar sin que nadie lo note: apartar de más se ve igual de
              bien en pantalla que apartar lo justo.

              Se cuentan las ocho DENTRO de su rejilla, no en el documento
              entero: una tarjeta movida a la caja seguiría estando en el
              documento y el recuento no se enteraría. */
        var f2 = document.querySelector('[data-fase="2"]');
        igual('fases: la 02 no aparta nada',
          f2 ? f2.querySelectorAll('.opc-caja').length : -1, 0);
        /* Siete de las ocho. La octava es el registro de marca, que está
           apagado en el catálogo; las otras siete siguen ahí, que es lo que
           esta comprobación vino a defender: que apartar los opcionales no se
           llevara por delante media fase. */
        igual('fases: y enseña las encendidas de sus ocho',
          document.querySelectorAll('#trs-2 > .tcard[data-tr]').length, 7);
        /* Y la que falta es LA APAGADA, no otra cualquiera. Sin esto, el 7 se
           cumpliría igual habiéndose caído una tarjeta encendida por error. */
        ok('fases: y la que falta es la apagada, no otra',
           !document.querySelector('#trs-2 > .tcard[data-tr="c8"]'),
           'c8 sigue puesta', 'c8 fuera, por apagada');

        /* Y el SISREF es una de las ocho: es el que pedía el informe y el
           que no estaba. Que salga el número bien sin que él esté sería
           haber cambiado una tarjeta por otra. */
        ok('fases: el SISREF está en la fase 02',
           !!document.querySelector('#trs-2 > .tcard[data-tr="c32"]'),
           'no está', 'la tarjeta c32');

        /* Lo 'esencial' se queda a la vista, que es la regla nueva escrita
           al revés: si algún día se volviera a apartar, esto lo dice. */
        var esenciales = [];
        document.querySelectorAll('.opc-rejilla .tcard[data-tr]').forEach(function(c){
          var t = cat[c.getAttribute('data-tr')];
          if (t && t.nivel === 'esencial') esenciales.push(c.getAttribute('data-tr'));
        });
        igual('fases: lo esencial no se aparta', esenciales.join(' '), '');

        /* Una fase SIN ningún obligatorio se queda entera a la vista, aunque
           lo que tenga sea opcional. Sin nada que bloquee no hay de qué
           distinguir lo demás, y la fase acabaría vacía detrás de un botón:
           eso ya no es apartar. La 05 tiene UNA tarjeta, así que ahí se ve
           más claro que en ninguna.

           Esta comprobación se perdió al reescribir el bloque de la fase 02
           -el corte se llevó lo que había en medio- y el sabotaje que quita
           la guarda salió VERDE dos veces seguidas. Vuelve, y por eso la
           tanda hay que correrla entera después de mover pruebas de sitio,
           no sólo mirar que el número final suba. */
        /* La 4 desde que se fundió con la 5. Y sigue siendo el caso que
           hace falta: en el doble tiene un OPCIONAL -el registro de la
           inversión- y ningún obligatorio, así que si la guarda no
           estuviera, sus tres tarjetas se irían detrás de un botón. */
        var f5 = document.querySelector('[data-fase="4"]');
        igual('fases: la que no tiene obligatorios se queda entera',
          f5 ? f5.querySelectorAll('.opc-caja').length : -1, 0);

        var f3 = document.querySelector('[data-fase="3"]');
        igual('fases: la 03 aparta, pero no lo que depende del ramo',
          f3 ? f3.querySelectorAll('.opc-caja').length : -1, 0);
        var colados = [];
        document.querySelectorAll('.opc-rejilla .tcard[data-tr]').forEach(function(c){
          var ref = c.getAttribute('data-tr');
          var t = cat[ref];
          if (t && t.nivel === 'actividad') colados.push(ref);
        });
        igual('fases: lo que depende del ramo nunca se aparta', colados.join(' '), '');
      })();
    })();

    /* El renglón contaba las tarjetas del catálogo —decía cuántos trámites
       EXISTEN, que es justo lo que "Mis" no significa—. Ahora cuenta los
       TUYOS en marcha, como hace el renglón de las citas: así los dos
       números de la barra significan lo mismo.

       En el expediente 'lleno' hay tres: uno devuelto, un borrador y uno
       recién enviado. Ninguno resuelto, así que los tres están en marcha. */
    (function(){
      var n = document.getElementById('navTramitesN');
      /* Solo donde el renglón ES «Mis trámites». Al equipo del CIIP ese
         mismo renglón se llama «Trámites por atender» y su chapa cuenta la
         COLA, que no tiene por qué parecerse a los trámites que ese gestor
         haya pedido para sí —normalmente ninguno—. Se mira el rótulo, que es
         como lo distingue una persona. */
      var rot = document.querySelector('#navTramites [data-i18n]');
      if (rot && rot.getAttribute('data-i18n') === 'nav.queue') return;
      /* Se cuenta contra lo que la propia lista dibuja, no contra un número
         escrito: cada expediente de prueba trae los suyos, y el expediente
         "vacío" no es "sin filas" sino "sin nada que anunciar". Una cifra a
         mano aquí rompería cada vez que alguien toque un fixture. */
      var vivos = 0;
      document.querySelectorAll('#mtCuerpo tr').forEach(function(f){
        /* Ni las pasadas ni la fila de «no hay ninguno», que desde que la
           tabla ya no se esconde vive dentro del cuerpo y no es un tramite. */
        if (!f.classList.contains('pasada') && !f.classList.contains('sin-nada')) vivos++;
      });
      igual('barra: "Mis trámites" cuenta los tuyos en marcha, no el catálogo',
            n.hidden ? '0' : n.textContent, String(vivos));
      ok('barra: y solo se ve si hay alguno',
         n.hidden === (vivos === 0),
         'oculto=' + n.hidden + ' con ' + vivos + ' en marcha',
         vivos ? 'oculto=false' : 'oculto=true');
    })();

    /* ── Y EL NÚMERO EN LA PESTAÑA ──
       La chapa del renglón sólo se ve con el panel delante, y una consulta se
       pierde justo en el otro caso: el gestor trabajando en otra pestaña.
       Como de aquí no sale ni un correo -no hay quien lance el mensajero-,
       el título del navegador es lo único que llega hasta donde está.

       Se comprueba contra la CHAPA y no contra un número escrito: los doce
       expedientes traen colas distintas, y una cifra a mano aquí se rompe
       en cuanto alguien toque un fixture. Lo que se prueba es que los dos
       digan lo mismo, que es lo que de verdad importa: dos números
       distintos para una sola cosa hacen dudar de los dos.

       La chapa era la del botón «Por atender» de arriba, que ya no está, y
       ahora es la del renglón de la barra. Con una diferencia que hay que
       tener en cuenta o esto se pone rojo en varios expedientes: esa chapa
       la comparten los dos roles y NO cuenta lo mismo en cada uno. Al equipo
       le cuenta la cola —y eso sí va a la pestaña—; a un inversionista le
       cuenta sus propios trámites en marcha, y ese número no sale ni tiene
       que salir en el título: le estaría contando trabajo de otro.

       Cuál de los dos es se lee en el RÓTULO del renglón, que es como lo
       distingue una persona: si dice «Trámites por atender», la chapa es la
       cola. No se pregunta CIIP_ES_EQUIPO() ni se mira el nombre del pase:
       lo primero sería comprobar el panel con el panel, y lo segundo se
       equivoca —hay cuatro pases del equipo que no se llaman 'gestor'—.

       Sin expresión regular a propósito. Ya nos ha pasado que el escapado
       se coma una barra y quede un patrón que corre, no encuentra nada y
       deja la prueba en verde para siempre. */
    (function(){
      var t = document.title;
      var chapa = document.getElementById('navTramitesN');
      var rot = document.querySelector('#navTramites [data-i18n]');
      var esCola = !!rot && rot.getAttribute('data-i18n') === 'nav.queue';
      var seVe = esCola &&
                 !!(chapa && !chapa.hidden && (chapa.textContent || '').trim());

      if (seVe){
        var pref = '(' + chapa.textContent.trim() + ') ';
        /* Y detrás del prefijo NO puede venir otro. Si el título se
           compusiera leyéndose a sí mismo, la segunda pasada dejaría
           «(3) (3) CIIP …» y el indexOf de arriba seguiría diciendo que
           sí. Es el fallo que tiene esto si se escribe mal, así que es el
           que hay que mirar. */
        ok('pestaña: el título lleva el número de la cola',
           t.indexOf(pref) === 0 && t.charAt(pref.length) !== '(',
           JSON.stringify(t), 'empieza por ' + JSON.stringify(pref) + ' y una sola vez');
      } else {
        /* El rótulo y la chapa van en el detalle: si esto se pone rojo, lo
           primero que hay que saber es CUÁL de los dos renglones se estaba
           mirando, y sin eso son diez minutos de ir a buscarlo. */
        ok('pestaña: y sin cola no lleva número',
           t.charAt(0) !== '(',
           JSON.stringify(t) + ' — renglón=' +
           (rot ? rot.getAttribute('data-i18n') : 'sin rótulo') +
           ' chapa=' + (chapa ? (chapa.hidden ? '(oculta)' : chapa.textContent) : 'no hay'),
           'sin "(...)" delante');
      }
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
         en === n + ' of 11 done' && es === n + ' de 11 listos',
         'en="' + en + '" es="' + es + '"',
         'en="' + n + ' of 11 done" es="' + n + ' de 11 listos"');
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
      /* Eran cinco verbos del mismo tipo -Llegar, Constituir, Operar,
         Crecer, Invertir- y la fase 1 dejo de serlo el 3 de septiembre de
         2026, por decision del CIIP: «Llegar» describia el viaje y el
         nombre nuevo describe el TRAMITE, que es lo que hay dentro.

         Se pierde la simetria y se gana precision; el cambio esta
         argumentado en su commit. Lo que la prueba sujeta ahora no es que
         rimen, sino que sean EXACTAMENTE estos cinco: cambiar el nombre de
         una fase es cambiar como se llama el producto por dentro, y no
         puede pasar sin que nadie se entere. */
      /* ── y las cuatro cajas, cuadradas ──
         Lo que se mide es que las cuatro BARRAS esten a la misma altura, no
         que el nombre ocupe tres renglones. El alto del nombre es como se
         consigue hoy -un numero fijo en el CSS- y es fragil: el dia que un
         nombre envuelva a cuatro renglones, su barra cae y esto se pone
         rojo, que es exactamente lo que se quiere. Ya paso dos veces: con
         la fase 01 al dejar de llamarse «Llegar» y con la 04 al fundirse
         con la 05. */
      (function(){
        /* La distancia DENTRO de su caja, no la altura en la pantalla: en
           los pases estrechos el carril se parte en dos filas y comparar la
           Y absoluta daba 232 px de diferencia con todo bien puesto. Lo que
           tiene que ser igual es cuanto baja la barra desde el borde de su
           propia caja. */
        /* ── Y CON LAS CUATRO BARRAS PUESTAS ──
           Las etapas POSTERIORES a la elegida cambian su barra por «cuando
           te toca», asi que en la portada recien abierta solo hay una barra
           que medir y esto no medía nada: daba 105 / -139 / -139 / -139,
           que son tres barras escondidas leidas como si estuvieran en el
           borde de la pantalla.

           Se les quita la clase «luego» a mano mientras dura la medida. Lo
           que se mide es la CAJA -a que altura cae la barra cuando el nombre
           envuelve a tres renglones-, y eso es CSS: pulsar la ultima etapa
           dejaria las cuatro barras puestas igual, pero le dejaria al panel
           una eleccion hecha por una persona, y tres pruebas mas abajo miden
           justo eso. Se devuelve como estaba al terminar. */
        function conLasCuatro(fn){
          var puestas = [].filter.call(etapas(), function(e){
            return e.classList.contains('luego');
          });
          puestas.forEach(function(e){ e.classList.remove('luego'); });
          try { return fn(); }
          finally { puestas.forEach(function(e){ e.classList.add('luego'); }); }
        }
        function desnivel(){
          return conLasCuatro(function(){
            var v = [];
            etapas().forEach(function(e){
              var b = e.querySelector('.jbar');
              if (b) v.push(Math.round(b.getBoundingClientRect().top -
                                       e.getBoundingClientRect().top));
            });
            return {lista:v, dif: v.length ? Math.max.apply(null,v) - Math.min.apply(null,v) : -1};
          });
        }
        var d = desnivel();
        ok('camino: las cuatro barras quedan a la misma altura',
           d.lista.length >= 4 && d.dif <= 1,
           d.lista.join(' / ') + '  (' + d.dif + ' px de diferencia)',
           'todas iguales');

        /* Y APRETANDO el carril, que es donde de verdad se rompe.

           A la anchura de la tanda -1400- no envuelve nada y esta prueba
           pasaba con el hueco del nombre puesto a dos renglones, o sea sin
           medir nada: el descuadre lo vio el CIIP en su pantalla, no aqui.
           Se estrecha el carril hasta donde el nombre mas largo envuelve a
           tres y se vuelve a medir. */
        (function(){
          var carril = document.querySelector('.journey');
          if (!carril) return;
          var era = carril.style.width;
          carril.style.width = '830px';
          void carril.offsetWidth;
          var e = desnivel();
          ok('camino: y también cuando el carril se estrecha',
             e.lista.length >= 4 && e.dif <= 1,
             e.lista.join(' / ') + '  (' + e.dif + ' px de diferencia)',
             'todas iguales');
          carril.style.width = era;
        })();
      })();

      igual('camino: las cuatro etapas se llaman como deben',
            nombres.join(' → '),
            'Acreditación de identidad y legitimación → Estructuración corporativa → Habilitación operativa y cumplimiento → Expansión y consolidación de inversión');
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

    /* ── LA PORTADA ABRE CON UNA ETAPA ELEGIDA, Y NO SALE POR SORTEO ──
       Esto se ha escrito cuatro veces y conviene que quede el recorrido. La 2
       nacía con .active desde la maqueta, así que cada recarga plantaba el
       «Estás aquí» sobre «Estructuración corporativa» sin haber hecho ni el
       primer trámite. Se cambió por una cuenta -la primera sin terminar-. El
       CIIP lo quiso de otra manera: al abrir NINGUNA. Y el 9 de septiembre lo
       volvió a querer elegida, porque «ninguna» dejaba debajo las cuatro
       cabeceras de fase repetidas: el mismo índice dos veces, una en tarjetas
       y otra en renglones.

       Así que ahora hay UNA, y cuál importa, y son dos reglas por orden: la
       etapa donde algo espera por ti -devuelto o a medias-, y si no te
       reclama nada, la primera que no esté terminada. Fijarla siempre en la
       01 sería recibir con una lista de cosas hechas a quien ya va por la
       tercera. Y la primera regla es de hoy: la franja ámbar que anunciaba
       los devueltos se retiró, y sin ella quien tenía dos en la 02 abría en
       la 01 y leía «Requiere acción 0».

       Se prueba en tres mitades -valga-: que al abrir hay una y sólo una; que
       cuando llegan los estados de la base se corrige sola, que es el momento
       en que antes se colaba y ahora es cuando tiene que moverse; y que una
       elegida a mano no se la mueve nadie por debajo. */
    (function(){
      function marcadas(){ return document.querySelectorAll('.jp.active'); }
      function cual(){
        var m = document.querySelector('.jp.active[data-ir]');
        return m ? m.getAttribute('data-ir') : '(ninguna)';
      }
      /* Se devuelve la eleccion AUTOMATICA, no un borrado: quitar el .active
         y marcharse dejaria la portada sin etapa y sin lista debajo para todo
         lo que viene despues. Borrarla y volver a pedirla es lo que apaga la
         marca de «esto lo eligio una persona». */
      function comoEstaban(){
        etapas().forEach(function(e){
          e.classList.remove('active');
          e.removeAttribute('data-aqui');
          e.setAttribute('aria-pressed', 'false');
        });
        if (window.CIIP_ELIGE_SOLA) window.CIIP_ELIGE_SOLA();
      }

      igual('camino: al abrir hay una etapa elegida, y sólo una', marcadas().length, 1);

      /* CUÁL, y se escribe el número a pelo en vez de recalcular la regla
         aquí: una prueba que repite el cálculo del panel comprueba que sigue
         igual, no que esté bien.

         En 'lleno' es la 02, y no por ser la segunda: ahí están el RIF de
         empresa devuelto y la constitución a medias, y lo que espera por ti
         va antes que lo que sigue en el camino. En los demás expedientes no
         te reclama nada dentro de una etapa terminada, así que sale la
         primera sin terminar, que es la 01. */
      igual('camino: y es la que te reclama, o la primera sin terminar',
            cual(), (CASO === 'lleno') ? '2' : '1');

      /* Y SE CORRIGE cuando contesta la base. Al cargar no se sabe todavía
         qué hay hecho -los estados llegan después-, así que la primera pasada
         da la 01; si resulta que la 01 está entera, la elegida tiene que
         moverse sola a la siguiente. Antes este era el momento en que una
         etapa se encendía sola y estaba mal; ahora es cuando tiene que
         moverse, y es el mismo sitio el que lo prueba. */
      var laUna  = document.querySelector('[data-fase="1"]');
      var suyas  = laUna ? [].slice.call(laUna.querySelectorAll('.tcard')) : [];
      var antes  = suyas.map(function(c){ return c.getAttribute('data-st'); });
      /* Sólo donde la elegida es la 01, que es de donde tiene que moverse.
         En 'lleno' ya está en la 02 porque allí te reclaman, y terminar la
         01 no la mueve de sitio: no habría nada que ver. */
      if (suyas.length && window.CIIP_REPINTA_ETAPAS && cual() === '1'){
        suyas.forEach(function(c){ c.setAttribute('data-st', 'listo'); });
        window.CIIP_REPINTA_ETAPAS();
        ok('camino: con la 01 terminada, la elegida se mueve a la 02',
           marcadas().length === 1 && cual() === '2',
           marcadas().length + ' marcada(s) — la ' + cual(), '1 marcada — la 2');
        suyas.forEach(function(c, k){
          if (antes[k] === null) c.removeAttribute('data-st');
          else c.setAttribute('data-st', antes[k]);
        });
        window.CIIP_REPINTA_ETAPAS();
      }


      /* La otra mitad: elegida, se marca ESA y ninguna más. Se pulsa de
         verdad en vez de ponerle la clase a mano, que probaría el CSS y no el
         panel. */
      var tercera = document.querySelector('.jp[data-ir="3"]');
      if (tercera){
        tercera.click();
        var m = marcadas();
        ok('camino: al elegir una se marca esa, y sólo esa',
           m.length === 1 && m[0] === tercera,
           m.length + ' marcada(s)' + (m.length ? ' — la ' + m[0].getAttribute('data-ir') : ''),
           '1 marcada — la 3');

        /* El punto azul solo no bastaba para encontrarla con las cuatro cajas
           separadas: se marca también el borde.

           Antes hay que ADELANTAR la transición. La caja tiene 140 ms de
           desvanecido de borde, y ahí está bien -lo acabas de pulsar, y el
           cambio se sigue con la vista-; pero leer el color recién pulsada
           devuelve el de PARTIDA, o sea el gris, y la prueba se ponía roja en
           las doce pasadas con el panel correcto. Esperar 140 ms tampoco vale:
           bajo el reloj del arnés no hay forma de esperar de verdad. Se le
           dice a la transición que termine y se lee el destino, que es lo que
           la prueba quiere saber: a dónde llega el borde, no por dónde va. */
        etapas().forEach(function(e){
          (e.getAnimations ? e.getAnimations() : []).forEach(function(t){
            if (t.transitionProperty) t.finish();
          });
        });
        var otra = document.querySelector('.jp[data-ir]:not(.active)');
        var ca = window.getComputedStyle(tercera).borderTopColor;
        var co = otra ? window.getComputedStyle(otra).borderTopColor : '';
        ok('camino: y se distingue por el borde', !!ca && ca !== co,
           'elegida=' + ca + ' otra=' + co, 'colores distintos');

        /* Y el rótulo, que va en un atributo y lo pinta el CSS con ::after. */
        ok('camino: y le sale su «Estás aquí»',
           !!(tercera.getAttribute('data-aqui') || '').trim(),
           JSON.stringify(tercera.getAttribute('data-aqui')), 'un rótulo con texto');

        /* Y AHÍ SE QUEDA. Es la otra mitad de «se corrige sola»: si la
           elección se recalculara en cada repintado, la 3 volvería a la 01 en
           cuanto la base contestara y la lista se te cambiaría sola mientras
           la miras. Aquí no ha cambiado ningún estado, así que la automática
           querría la 01 y no la 3. */
        if (window.CIIP_REPINTA_ETAPAS){
          window.CIIP_REPINTA_ETAPAS();
          igual('camino: y a la elegida a mano no se la mueve la base', cual(), '3');
        }

        comoEstaban();
      }
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

      /* El aviso de «datos de ejemplo» se retiró. Vigilaba que nadie se
         creyera las cifras mientras las 24 tarjetas llevaban el estado
         escrito a mano; hoy ese estado sale de la base -pintaEstadoTarjetas-
         y el recuento de cada etapa se compone contándolas, así que no queda
         cifra inventada de la que avisar.

         La comprobación no se borra: se le da la vuelta. Antes vigilaba que
         el aviso siguiera encendido; ahora, que no vuelva sin querer y que
         no vuelva tampoco la razón por la que hacía falta. */
      (function(){
        var d = document.getElementById('avisoDemo');
        ok('sesión: el aviso de datos de ejemplo ya no está',
           !d, d ? 'sigue en el marcado' : '(no existe)', 'retirado');
        var aMano = document.querySelectorAll('.tcard[data-estado]').length;
        ok('sesión: ninguna tarjeta lleva el estado escrito a mano',
           aMano === 0, aMano, 0);
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
           g === String((Date.parse('2026-08-14T10:00:00Z') + (window.CIIP_MENTIRA_DESLIZ || 0))),
           'guardado=' + g, String((Date.parse('2026-08-14T10:00:00Z') + (window.CIIP_MENTIRA_DESLIZ || 0))));
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
        /* La fecha se CALCULA con el mismo desliz que lleva el expediente, en
           vez de escribir «26 ago 2026» a mano. Lo que hay que ver es que la
           plantilla se rellenó -que no quedó un {cuando} a la vista- y que lo
           que puso es la fecha de la cita; el día del calendario en que se
           corra la tanda no pinta nada. */
        (function(){
          var q = cita.querySelector('.av-q').textContent;
          var d = new Date(Date.parse('2026-08-26T10:00:00Z') +
                           (window.CIIP_MENTIRA_DESLIZ || 0));
          ok('buzón: y dice para cuándo quedó, con su hora',
             /Confirmada para el/.test(q) &&
             q.indexOf(String(d.getDate())) >= 0 &&
             q.indexOf(String(d.getFullYear())) >= 0 &&
             q.indexOf('{') < 0,
             q, 'la fecha de la cita, sin llaves');
        })();
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

      /* Y se vuelve a la portada. Pulsar un aviso deja la dirección en
         #tramite-c6, y quien viene detrás -el reloj del plazo legal, el
         catálogo- busca tarjetas que con el detalle abierto no están.
         Antes lo dejaba limpio la prueba de la franja, que iba después;
         al retirarla, tres pruebas se pusieron rojas sin haberlas tocado. */
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
        /* Los ENCENDIDOS, no todo el catalogo: lo apagado no se ofrece ni
           como tarjeta ni como asunto de una cita. */
        var deberian = (window.PRUEBA_TIPOS_ON || 0) + 1;
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

    /* ── EL CALENDARIO, EL NUESTRO ──
       El del navegador no se puede maquillar y se salia del dialogo. Este
       vive dentro y empuja lo de abajo, asi que no hay nada que recortar.
       Aqui SI va un calendario y no las tres listas de los tramites: "que
       dias te vienen bien" es "el jueves" o "el 26". */
    igual('citas: ya no hay calendario del navegador',
          document.querySelectorAll('#ctForm input[type="date"]').length, 0);
    ok('citas: y el valor sigue en un campo escondido con su id',
       d.type === 'hidden' && h.type === 'hidden',
       d.type + '/' + h.type, 'hidden/hidden');

    var btD = document.getElementById('ctDesdeBtn');
    var btH = document.getElementById('ctHastaBtn');
    ok('citas: cada punta del rango tiene su boton', !!btD && !!btH,
       (btD ? 'desde ' : 'sin desde ') + (btH ? 'y hasta' : 'y sin hasta'), 'los dos');
    if (!btD || !btH) return;

    /* El boton dice la fecha que lleva, no "elegir fecha". Un boton que no
       ensena lo que guarda obliga a abrirlo para saber que hay dentro. */
    ok('citas: y el boton ensena la fecha que lleva',
       btD.textContent.trim().length > 3 &&
       btD.textContent.indexOf(d.value.slice(8, 10).replace(/^0/, '')) >= 0,
       '"' + btD.textContent.trim() + '" para ' + d.value, 'la fecha puesta');

    /* Cerrado hasta que lo abres: si naciera abierto, la ventana saldria
       con un mes entero encima de la nota. */
    var panel = document.querySelector('#ctForm .cal');
    ok('citas: el calendario nace cerrado',
       !!panel && !panel.classList.contains('open'),
       panel ? panel.className : 'no hay panel', 'cerrado');

    btD.click();
    ok('citas: y se abre al pulsar el boton', panel.classList.contains('open'),
       panel.className, 'abierto');
    igual('citas: y el boton lo dice', btD.getAttribute('aria-expanded'), 'true');

    /* Un mes de verdad: siete rotulos de dia y los dias del mes que toca.
       Se cuenta el mes de la fecha puesta, no uno cualquiera. */
    igual('citas: con los siete dias de la semana',
          panel.querySelectorAll('.cal-sem span').length, 7);
    var mesPuesto = new Date(parseInt(d.value.slice(0, 4), 10),
                             parseInt(d.value.slice(5, 7), 10), 0).getDate();
    igual('citas: y los dias que tiene ese mes',
          panel.querySelectorAll('.cal-dias button[data-iso]').length, mesPuesto);
    ok('citas: y se abre por el mes de la fecha que lleva',
       !!panel.querySelector('.cal-dias button[data-iso^="' + d.value.slice(0, 7) + '"]'),
       (panel.querySelector('.cal-dias button[data-iso]') || {}).getAttribute
         ? panel.querySelector('.cal-dias button[data-iso]').getAttribute('data-iso')
         : 'sin dias',
       'el de ' + d.value.slice(0, 7));

    /* El que lleva puesto sale marcado: sin eso hay que leerse el boton de
       arriba para saber cual de los treinta es el tuyo. */
    var elegido = panel.querySelector('.cal-dias button.puesto');
    igual('citas: y el dia elegido sale marcado',
          elegido ? elegido.getAttribute('data-iso') : 'ninguno', d.value);

    /* Lo que ya paso no se puede elegir: sale apagado, no desaparece. Una
       rejilla con huecos deja de parecer un mes. */
    var hoyISO = (function(){
      var x = new Date();
      return x.getFullYear() + '-' + String(x.getMonth() + 1).padStart(2, '0') +
             '-' + String(x.getDate()).padStart(2, '0');
    })();
    var viejos = [].filter.call(panel.querySelectorAll('.cal-dias button[data-iso]'),
      function(b){ return b.getAttribute('data-iso') < hoyISO; });
    ok('citas: los dias que ya pasaron salen apagados',
       viejos.every(function(b){ return b.disabled; }),
       viejos.length + ' anteriores a hoy, ' +
       viejos.filter(function(b){ return b.disabled; }).length + ' apagados',
       'todos apagados');

    /* Y elegir mueve el campo escondido, que es lo unico que se envia. */
    var libre = [].filter.call(panel.querySelectorAll('.cal-dias button[data-iso]'),
      function(b){ return !b.disabled; })[0];
    var queDia = libre.getAttribute('data-iso');
    libre.click();
    igual('citas: al elegir un dia se guarda', d.value, queDia);
    ok('citas: y el calendario se cierra solo', !panel.classList.contains('open'),
       panel.className, 'cerrado');
    ok('citas: y el boton se entera', btD.textContent.indexOf(
         String(parseInt(queDia.slice(8, 10), 10))) >= 0,
       '"' + btD.textContent.trim() + '"', 'con el dia elegido');

    /* La otra punta acota a esta: el ultimo dia no puede ser anterior al
       primero, y en vez de dejarlo elegir y renir despues, sale apagado. */
    btH.click();
    var antesDelPrimero = [].filter.call(panel.querySelectorAll('.cal-dias button[data-iso]'),
      function(b){ return b.getAttribute('data-iso') < d.value; });
    ok('citas: y el ultimo dia no ofrece nada anterior al primero',
       antesDelPrimero.every(function(b){ return b.disabled; }),
       antesDelPrimero.length + ' antes del ' + d.value + ', ' +
       antesDelPrimero.filter(function(b){ return b.disabled; }).length + ' apagados',
       'todos apagados');
    igual('citas: y el panel dice cual de las dos esta poniendo',
          (panel.querySelector('.cal-h .cual') || {}).textContent, 'Último día');
    btH.click();   /* se cierra, que lo de abajo mide el formulario entero */

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

  /* ═══════════ LA CONVERSACIÓN DE UNA CITA ═══════════
     La tabla existía desde el 2 de septiembre —con sus disparadores, sus
     políticas y sus comprobaciones en el SQL— y no la usaba nadie: era una
     conversación que la base sabía guardar y la pantalla no sabía pedir.

     Es lo que contesta a quien todavía no ha empezado nada. El hilo del
     expediente cuelga de una solicitud y quien acaba de entrar no tiene
     ninguna; sus primeras preguntas salían por correo y no quedaban en
     ninguna parte.

     Se mira en el expediente «lleno», que es el que trae una cita ya
     pedida. En los demás no hay cita en marcha, y eso también se comprueba:
     sin cita no hay hilo que colgar de ningún sitio. */
  /* ── UNA CITA ES UNA CITA ──
     Llevaba su propia conversación dentro. Se quita el 8 de septiembre de
     2026 por decisión del CIIP: fecha, modo y estado por un lado; hablar por
     otro. Estaban mezclados, y eso repartía las conversaciones en tres
     sitios —una cita, un expediente, y sueltas—. Con tres, ninguno es EL
     sitio.

     Estas pruebas medían el hilo; ahora fijan que NO está y que en su lugar
     queda la puerta al chat. Lo segundo importa tanto como lo primero: quien
     tiene una cita pedida es justo quien quiere preguntar algo antes de que
     llegue el día, y quitarle el hilo sin darle a dónde ir es dejarlo con la
     ventana delante y sin salida. */
  function hiloCitaMira(){
    if (CASO === 'gestor') return;
    var caja = document.getElementById('ctHilo');
    ok('cita: la cita ya no lleva conversación dentro',
       !!caja && !caja.querySelector('.hilo'),
       caja ? (caja.querySelector('.hilo') ? 'sigue puesta' : 'fuera') : 'no existe',
       'fuera');

    /* Se pide el BOTÓN y no sólo el cuadro: un cartel que dice «escríbenos»
       sin nada que pulsar deja al inversionista buscando dónde. */
    ok('cita: y en su lugar hay por dónde hablar con el CIIP',
       !!caja && !!caja.querySelector('.ct-hablar .btn'),
       caja && caja.querySelector('.ct-hablar') ? 'con su botón' : 'no hay puerta',
       'la puerta al chat');
  }

  /* hiloCitaEscribe y hiloCitaTrasEscribir se van con el hilo: escribían en
     una caja que ya no existe. Escribir sigue probado en la conversación de
     una consulta, que es la MISMA función de pintar con otra tabla. */

  function citasAnula(){
    if (CASO === 'gestor') return;
    document.getElementById('ctCancelar').click();
  }

  /* ═══════════ EL RNC, RECIEN ACTIVADO ═══════════
     Era una ficha de solo lectura: decía "Ver detalle" y no se podía
     solicitar. Sus recaudos son PROVISIONALES —la hoja los trae en blanco—
     pero el circuito tiene que funcionar igual. */
  /* ═══════════ LOS NOMBRES DE PAÍS, AL ESCRIBIR ═══════════
     Escribir "País emisor del pasaporte" a mano son doscientas maneras de
     escribir lo mismo. Con <datalist> se sugieren, y a propósito no con
     un desplegable: una lista cerrada deja fuera a quien escriba "Reino
     Unido" donde nosotros pusimos otra cosa, y ese trata con un
     formulario, no con nosotros. */
  function paisesMira(){
    /* En 'lleno' el c1 esta RESUELTO y ensena el expediente, no el
       formulario: el campo no existe alli. En 'vacio' no hay tramites y
       la tarjeta abre la solicitud en blanco, que es donde vive. */
    if (CASO !== 'vacio') return;
    location.hash = 'tramite-c1';
  }

  function paisesTrasAbrir(){
    if (CASO !== 'vacio') return;

    var campo = document.querySelector('.sol-campo[data-campo="pais_emisor"]');
    ok('países: el campo del pasaporte trae el buscador', !!campo &&
       !!campo.querySelector('.combo .combo-list'),
       campo ? (campo.querySelector('.combo') ? 'con combo' : 'sin combo') : 'no está',
       'el mismo del perfil');
    var ent = campo.querySelector('input[type="text"]');
    var ocu = campo.querySelector('input[type="hidden"]');
    var lis = campo.querySelector('.combo-list');
    ok('países: y sigue siendo un campo de texto',
       !!ent, ent ? 'input de texto' : 'no lo es', 'texto');

    /* Escribir tres letras y que salga: es todo lo que se le pide. */
    ent.focus();
    ent.value = 'ven';
    ent.dispatchEvent(new Event('input'));
    ok('países: al escribir se despliega la lista',
       lis.classList.contains('open'), lis.className, 'con la clase open');
    igual('países: y el primero es el que empieza por ahí',
          lis.querySelector('li[role="option"] span:last-child').textContent, 'Venezuela');

    /* Sin tildes, que es lo que uno teclea de verdad. */
    ent.value = 'peru';
    ent.dispatchEvent(new Event('input'));
    igual('países: y busca sin tildes',
          lis.querySelector('li[role="option"] span:last-child').textContent, 'Perú');

    /* Elegir guarda el CÓDIGO, que es lo que un ente va a querer el día
       que pregunte, y el nombre en ESPAÑOL aparte: lo que se ve en
       pantalla está en el idioma de turno, y guardar eso metera el mismo
       país en la base de seis maneras distintas. */
    lis.querySelector('li[role="option"]').dispatchEvent(new MouseEvent('mousedown', {bubbles:true}));
    igual('países: elegir rellena el campo', ent.value, 'Perú');
    igual('países: y guarda el código ISO', ocu.value, 'PE');
    igual('países: y el nombre en español, que es lo que va a la base',
          campo.getAttribute('data-es'), 'Perú');
    ok('países: y la lista se cierra',
       !lis.classList.contains('open'), lis.className, 'sin open');

    /* Escribir encima descarta el código viejo: si no, uno de una
       elección anterior daría por bueno lo que sea que se teclee. */
    ent.value = 'País que no existe';
    ent.dispatchEvent(new Event('input'));
    igual('países: escribir encima suelta el código anterior', ocu.value, '');
    igual('países: y el nombre en español con él',
          campo.getAttribute('data-es'), null);
    /* Pero se admite igual: una lista cerrada deja fuera a quien escriba
       "Reino Unido" donde nosotros pusimos otra cosa. */
    igual('países: pero lo escrito a mano no se borra', ent.value, 'País que no existe');

    ent.value = '';
    ent.dispatchEvent(new Event('input'));
    location.hash = '';
  }

  /* ═══════════ NI UNA SOLICITUD DE MAS ═══════════
     Pasaron cuatro de la misma visa. La tarjeta ya lo evitaba —pide la
     más reciente y, si no es borrador, enseña el estado y no el
     formulario— pero eso es una LECTURA, y entre leer y escribir cabe
     otra pestaña, una recarga o un doble clic en Enviar. Y esas cuatro
     las recibe el CIIP y alguien las revisa una por una. */
  /* ── LA CONVERSACIÓN DEL EXPEDIENTE ──
     Se abre el c6 de 'lleno', que es el trámite DEVUELTO: es donde la
     conversación tiene sentido, porque el CIIP dijo que falta algo y el
     inversionista necesita preguntar qué exactamente. */
  function hiloAbre(){
    if (CASO !== 'lleno') return;
    location.hash = 'tramite-c6';
  }

  function hiloMira(){
    if (CASO !== 'lleno') return;

    /* ── LA CONVERSACIÓN YA NO VIVE AQUÍ ──
       Estuvo al final de esta pantalla y se quitó el 8 de septiembre de 2026
       por decisión del CIIP: hablar con el equipo pasa a estar en un solo
       sitio, la burbuja. Esto lo fija, porque una pantalla no vuelve sola
       pero un parche descuidado sí la puede devolver.

       ACOTADO a #trReal, y no es un detalle: escrito como
       document.querySelector('.hilo-lista') estas pruebas seguían VERDES
       después de quitar el hilo, porque encontraban el de la ventana de
       consultas —que se queda en el árbol aunque esté cerrada—. Tres de las
       cuatro medían una conversación que no era la suya y no se notó; la
       cuarta se puso roja solo porque aquel ejemplo no lleva adjunto. */
    var ficha = document.getElementById('trReal');
    ok('hilo: la conversación ya no está en la ficha del trámite',
       !!ficha && !ficha.querySelector('.hilo-lista'),
       ficha ? (ficha.querySelector('.hilo-lista') ? 'sigue puesta' : 'fuera') : '(no hay ficha)',
       'fuera');

    /* Lo que NO se puede perder: leer por qué te lo devolvieron. Esa nota no
       sale del hilo sino de tramite_eventos, y tenía que seguir estando. Sin
       esta prueba, quitar el hilo podía llevarse por delante la explicación
       y nadie se enteraría hasta que un inversionista preguntara por qué le
       devolvieron algo sin decirle qué falta. */
    var texto = ficha ? ficha.textContent : '';
    ok('hilo: pero la nota con la que te lo devolvieron sigue a la vista',
       /ilegible|escaneado/i.test(texto),
       texto.replace(/\s+/g, ' ').slice(0, 70), 'la nota del gestor');

    /* Y sigue habiendo por dónde contestar: el cuadro que abre la consulta. */
    ok('hilo: y queda por dónde hablar con el CIIP',
       !!ficha && !!ficha.querySelector('.sol-gestion .btn'),
       ficha && ficha.querySelector('.sol-gestion') ? 'está el cuadro' : 'no hay',
       'el cuadro que abre la consulta');
  }

  function dupeAbre(){
    /* 'vacio' trae un borrador de RIF personal Y su envio posterior: el
       tramite tiene una EN MARCHA. Es el expediente donde este caso
       existe de verdad. */
    if (CASO !== 'vacio') return;
    location.hash = 'tramite-c3';
  }

  function dupeMira(){
    if (CASO !== 'vacio') return;
    var enviar = document.getElementById('solEnviar') ||
                 document.querySelector('.sol-enviar');
    if (!enviar) return;   /* si ya ensena el estado, no hay que probar nada */
    enviar.click();
  }

  function dupeTrasEnviar(){
    if (CASO !== 'vacio') return;
    var av = document.querySelector('.sol-aviso');
    if (!av) return;
    ok('duplicados: no se manda otra si ya hay una en marcha',
       /Ya tienes una solicitud de este trámite en marcha/.test(av.textContent),
       av.textContent.trim().slice(0, 60), 'lo dice y no la crea');
    ok('duplicados: y lo dice como un error, no como un aviso suelto',
       /err/.test(av.className), av.className, 'sol-aviso err');
    location.hash = '';
  }

  /* ═══════════ NO PEDIR DOS VECES LO MISMO ═══════════
     El pasaporte se pide en tres formularios y la fecha de nacimiento en
     otros tres. El dato esta guardado desde la primera vez; hasta ahora
     nadie iba a buscarlo. La visa de dependientes pregunta las tres cosas
     que la visa de inversionista ya contesto. */
  function antesAbre(){
    if (CASO !== 'lleno') return;
    location.hash = 'tramite-c20';
  }

  function antesMira(){
    if (CASO !== 'lleno') return;
    var pas = document.querySelector('#trReal [name="numero_pasaporte"]');
    ok('antes: el formulario sale', !!pas,
       pas ? 'con su campo' : 'sin campo de pasaporte', 'con su campo');
    if (!pas) return;

    igual('antes: el pasaporte viene de la visa', pas.value, 'YB1234567');
    var nac = document.querySelector('#trReal [name="fecha_nacimiento"]');
    igual('antes: y la fecha de nacimiento tambien',
          nac ? nac.value : 'sin campo', '1979-04-11');

    /* Y se DICE de donde salio. Un campo que aparece relleno sin explicar
       por que parece que el panel se invento el dato. */
    var sello = pas.closest('.sol-campo').querySelector('.de-antes');
    ok('antes: y el campo dice que ya lo escribiste', !!sello,
       sello ? sello.textContent.trim() : 'sin sello', 'con sello');
    ok('antes: y al pasar por encima dice donde',
       !!(sello && /visa/i.test(sello.title || '')),
       (sello && sello.title) || 'sin titulo', 'nombra el tramite');

    /* Lo que NO se ha escrito nunca sigue vacio: si saliera con algo, el
       panel estaria inventando. Se mira 'nombre_familiar', que es una caja
       de texto: un desplegable nunca vale cadena vacia -vale su primera
       opcion- y la prueba daria roja sin que hubiera nada mal. */
    var con = document.querySelector('#trReal [name="nombre_familiar"]');
    ok('antes: y lo que nunca escribiste sigue vacio',
       !!con && con.value === '', con ? ('"' + con.value + '"') : 'no hay campo', 'vacio');
  }

  /* ═══════════ LA FECHA, EN TRES LISTAS ═══════════
     El calendario del navegador se fue de la ficha de empresa hace tres
     semanas y se quedó en los formularios de trámite, que son 21 fechas.
     Se mide sobre el c20, que sigue abierto del paso de antes y trae la
     fecha de nacimiento ya rellena: así se comprueba de paso que un dato
     que viene de otro sitio LLEGA a las tres listas y no solo al campo
     escondido. */
  function fecha3Mira(){
    if (CASO !== 'lleno') return;
    var nac = document.querySelector('#trReal [name="fecha_nacimiento"]');
    ok('fecha3: el formulario sigue abierto', !!nac,
       nac ? 'con la fecha' : 'sin campo de fecha', 'con la fecha');
    if (!nac) return;

    /* Ni uno. Este es el fallo que se venía a arreglar. */
    var nativos = document.querySelectorAll('#trReal input[type="date"]').length;
    igual('fecha3: no queda ningun calendario del navegador', nativos, 0);

    var casilla = nac.closest('.sol-campo');
    var listas  = casilla.querySelectorAll('.fecha3 select');
    igual('fecha3: hay tres listas', listas.length, 3);

    /* Lo que lee el que valida es el PRIMER input o select de la casilla.
       Si las listas se colaran delante, cogeria el dia suelto -"11"- y lo
       enviaria como si fuera la fecha entera. */
    var primero = casilla.querySelector('input, select');
    ok('fecha3: y lo primero de la casilla es el campo escondido',
       primero === nac, primero ? (primero.tagName + ' ' + (primero.type || '')) : 'nada',
       'INPUT hidden');

    igual('fecha3: el escondido conserva la fecha', nac.value, '1979-04-11');
    var d = casilla.querySelector('.fecha3 select.d');
    var m = casilla.querySelector('.fecha3 select.m');
    var a = casilla.querySelector('.fecha3 select.a');
    igual('fecha3: y el ano se ve en su lista',  a ? a.value : 'sin lista', '1979');
    igual('fecha3: y el mes tambien',            m ? m.value : 'sin lista', '04');
    igual('fecha3: y el dia tambien',            d ? d.value : 'sin lista', '11');

    /* Una fecha de nacimiento no tiene años por delante: el tope de quien
       no está en la tabla es "hoy". */
    var futuro = false, ahora = new Date().getFullYear();
    [].forEach.call(a ? a.options : [], function(o){
      if (o.value && parseInt(o.value, 10) > ahora) futuro = true;
    });
    ok('fecha3: y no ofrece anos que no han llegado', !futuro,
       futuro ? 'ofrece futuro' : 'hasta ' + ahora, 'hasta ' + ahora);

    /* Y febrero no tiene 31. La lista de dias se rehace con el mes. */
    if (m && d){
      m.value = '02'; m.dispatchEvent(new Event('change'));
      igual('fecha3: febrero de 1979 tiene 28 dias', d.options.length - 1, 28);
    }
  }

  /* Cambiar una lista tiene que mover el campo escondido: es lo unico que
     se guarda. Sin esto las tres listas serian un adorno. */
  function fecha3Cambia(){
    if (CASO !== 'lleno') return;
    var nac = document.querySelector('#trReal [name="fecha_nacimiento"]');
    if (!nac) return;
    var casilla = nac.closest('.sol-campo');
    var d = casilla.querySelector('.fecha3 select.d');
    if (!d) return;
    d.value = '07'; d.dispatchEvent(new Event('change'));
    igual('fecha3: al elegir, el campo escondido se entera', nac.value, '1979-02-07');
  }

  /* ═══════════ LA FIRMA EN EL REGISTRO DE EXTRANJEROS ═══════════
     El c32 se añadió con sus recaudos y SIN formulario: la tarjeta se
     abría, decía «Tus datos» y debajo no había nada. Se vio abriéndola en
     pantalla, no aquí, porque aquí no había nada que lo mirara.

     Y los recaudos que tenía estaban copiados de otra tarjeta: pedían una
     «Traducción certificada de la licencia» en un trámite del SAREN que no
     tiene que ver con conducir. Reusar una clave de rótulo sin mirar qué
     dice no rompe nada y no sale en ninguna cuenta; sólo se ve leyendo la
     pantalla. Por eso aquí se mira el TEXTO y no sólo el número.

     Los nueve campos salen del portal, https://sisref.saren.gob.ve/. */
  /* ═══════════ EL GLOBO DE «CÓMO DEBE VENIR CADA RECAUDO» ═══════════
     Primera pieza de los instrumentos guía para operadores jurídicos: que
     el apoderado suba los papeles igual siempre y dejen de rechazárselos
     por vicios de forma.

     Llegó sin pruebas, y es de las cosas que MÁS las necesitan: no es un
     texto que se lee, es un trozo de interfaz con estado -se abre, se
     cierra, se reancla, devuelve el foco- y cada una de esas cuatro cosas
     se rompe por su cuenta sin que se note en las otras.

     Se mira en el FORMULARIO, que es donde se sube el papel de verdad. */
  function pistaAbre(){
    if (CASO !== 'vacio') return;
    location.hash = 'tramite-c1';
  }

  function pistaMira(){
    if (CASO !== 'vacio') return;
    var caja = document.getElementById('trReal');
    /* Los recaudos viven en el SEGUNDO paso de la solicitud, y la hoja nace
       recogida. Un boton que no esta a la vista no puede coger el foco, asi
       que la comprobacion del Escape contestaba BODY sin que hubiera nada
       roto. Se abre esa hoja por la misma puerta que usa el envio. */
    if (caja && caja.CIIP_VE_PASO) caja.CIIP_VE_PASO(2);
    var envs = caja.querySelectorAll('.sol-doc .pista-env');

    ok('pista: cada recaudo trae su «i»',
       envs.length === caja.querySelectorAll('.sol-doc').length && envs.length > 0,
       envs.length + ' de ' + caja.querySelectorAll('.sol-doc').length + ' recaudos',
       'una por recaudo');
    if (!envs.length) return;

    var btn = envs[0].querySelector('.pista');
    var glo = envs[0].querySelector('.pista-caja');

    /* Cerrado al entrar. Un globo abierto de salida tapa el formulario y
       no lo ha pedido nadie. */
    igual('pista: empieza cerrada', glo.hidden, true);
    igual('pista: y el botón lo declara', btn.getAttribute('aria-expanded'), 'false');

    /* El rótulo del botón dice DE QUÉ recaudo es. Con doce «i» iguales en
       la misma pantalla, un lector de pantalla que anuncie doce veces «más
       información» deja sin saber de cuál es cada una. */
    var etiq = btn.getAttribute('aria-label') || '';
    ok('pista: el botón dice de qué recaudo es',
       etiq.length > 3 && etiq !== 'i',
       etiq || 'sin etiqueta', 'algo con el nombre del recaudo');

    /* SE PUEDE PULSAR CON EL DEDO. Veinticuatro píxeles es el mínimo de un
       blanco, y este botón se hizo pensando en quien entra desde el móvil
       —es la razón de que no sea un title=—, así que quedarse corto aquí
       era fallar justo donde más falta hacía. Estuvo en quince.

       Se mide el ÁREA y no el círculo, que son dos cosas distintas a
       propósito: el círculo se queda en 20 para no poner doce pelotas
       compitiendo con los nombres de los recaudos, y el área sube a 24 con
       un ::after transparente. Por eso se suma el pseudoelemento en vez de
       leer el alto del botón, que diría 20 y se daría por bueno. */
    (function(){
      var r  = btn.getBoundingClientRect();
      var cs = window.getComputedStyle(btn, '::after');
      var ancho = Math.max(r.width,  parseFloat(cs.width)  || 0);
      var alto  = Math.max(r.height, parseFloat(cs.height) || 0);
      ok('pista: se puede pulsar con el dedo',
         ancho >= 24 && alto >= 24,
         Math.round(ancho) + 'x' + Math.round(alto) + ' px', '24x24 o más');
    })();

    /* Y NO es un title=. Es la mitad del trabajo de ayer: el atributo
       nativo no sale en táctil, se va solo mientras lo lees, no admite
       lista y el lector lo anuncia o no según el navegador. */
    ok('pista: no es un title del navegador', !btn.hasAttribute('title'),
       btn.getAttribute('title') || 'sin title', 'sin title');

    btn.click();
    igual('pista: al pulsarla se abre', glo.hidden, false);
    igual('pista: y el botón lo declara abierto', btn.getAttribute('aria-expanded'), 'true');

    /* Lo que hay dentro son REGLAS, en lista y no en un renglón corrido.
       Y las propias del documento van ANTES que las generales: quien abre
       la del pasaporte viene a saber qué tiene el pasaporte de particular,
       no que los papeles se suben legibles. */
    ok('pista: dentro hay reglas, en lista',
       glo.querySelectorAll('li').length >= 2,
       glo.querySelectorAll('li').length + ' renglones', '2 o más');
    ok('pista: y lleva su título',
       ((glo.querySelector('.pc-t') || {}).textContent || '').trim() !== '',
       (glo.querySelector('.pc-t') || {}).textContent || 'sin título', 'un título');

    /* Se cierra sola al abrir otra: dos globos abiertos a la vez se tapan
       entre ellos, y el segundo sale encima del primero sin decirlo. */
    if (envs.length > 1){
      var btn2 = envs[1].querySelector('.pista');
      btn2.click();
      ok('pista: abrir otra cierra la primera',
         glo.hidden === true && envs[1].querySelector('.pista-caja').hidden === false,
         'primera ' + (glo.hidden ? 'cerrada' : 'ABIERTA'), 'solo una abierta');
      btn2.click();
    }

    /* Pulsar el mismo botón otra vez la cierra. */
    btn.click();
    igual('pista: vuelve a abrirse', glo.hidden, false);
    btn.click();
    igual('pista: y la segunda pulsación la recoge', glo.hidden, true);

    /* Escape la cierra Y DEVUELVE EL FOCO al botón. Si se quedara suelto,
       quien navega con teclado tendría que recorrer la página entera para
       volver donde estaba. */
    btn.click();
    document.dispatchEvent(new KeyboardEvent('keydown', {key:'Escape'}));
    igual('pista: Escape la cierra', glo.hidden, true);
    ok('pista: y devuelve el foco al botón', document.activeElement === btn,
       document.activeElement ? (document.activeElement.className || document.activeElement.tagName) : 'nada',
       'el botón de la pista');

    /* Un clic fuera también la cierra; uno DENTRO no, que si no no se
       podría seleccionar el texto para copiarlo, que es justo lo que hace
       quien prepara un expediente.

       Lo de dentro lo guardan DOS cosas a la vez -el stopPropagation de la
       caja y el closest('.pista-env') del manejador del documento- y se
       comprobó: quitar cualquiera de las dos por separado no rompe nada,
       porque la otra sigue. Rompiendo las dos, esta prueba se pone roja.
       O sea que mide, aunque haga falta quitar las dos para verlo. */
    btn.click();
    glo.dispatchEvent(new MouseEvent('click', {bubbles:true}));
    igual('pista: un clic dentro no la cierra', glo.hidden, false);
    document.body.dispatchEvent(new MouseEvent('click', {bubbles:true}));
    igual('pista: pero uno fuera sí', glo.hidden, true);
  }

  function sisrefAbre(){
    if (CASO !== 'vacio') return;
    location.hash = 'tramite-c32';
  }

  function sisrefTrasAbrir(){
    if (CASO !== 'vacio') return;
    igual('sisref: se abre su detalle', document.body.getAttribute('data-vista'), 'tramite');

    /* ── EL PLAZO, DEBAJO DE LA DESCRIPCIÓN ──
       La pantalla del trámite no calcula el plazo: lo CLONA de la tarjeta.
       Y ese renglón de la tarjeta no está escrito en el marcado -lo pone
       pintaCuando cuando la base contesta-, así que la copia se hacía
       antes de que existiera el texto y se traía el reloj MUDO: un icono
       suelto debajo de la descripción y el plazo sin verse por ninguna
       parte.

       Abriendo desde la portada no se notaba, porque para cuando pulsas
       una tarjeta la base ya contestó. Solo pasaba entrando por la
       dirección directa -que es justo lo que hace esta prueba-, o
       recargando con el trámite abierto. Se vio en pantalla, no aquí:
       ninguna prueba miraba este renglón.

       Se exige TEXTO, no que el hueco exista: el hueco existía siempre y
       es lo que hacía el fallo invisible. */
    var plazo = document.getElementById('trPlazo');
    var dice  = ((plazo && plazo.textContent) || '').trim();

    /* Con el estimado apagado, el c32 sin solicitud no tiene nada que decir
       en ese renglon. El riesgo de fondo sigue siendo el mismo -el reloj
       mudo, un icono suelto debajo de la descripcion-, asi que eso es lo
       que se mira: o dice algo, o la copia llega escondida. */
    function mudoALaVista(){
      var r = plazo && plazo.querySelector('.t-time');
      return !!r && !r.hidden && !(r.textContent || '').trim();
    }
    var CON_ESTIMADO = !!window.CIIP_ESTIMADO_EN_FICHA;

    if (CON_ESTIMADO){
      ok('sisref: el plazo se ve en la pantalla del trámite',
         dice.length > 0, dice ? ('«' + dice + '»') : '(el reloj, mudo)',
         'el estimado, escrito');
    } else {
      ok('sisref: sin estimado, la pantalla del trámite no deja el reloj mudo',
         !!plazo && !mudoALaVista(),
         dice ? ('«' + dice + '»') : (mudoALaVista() ? '(el reloj, mudo)' : 'escondido'),
         'escondido, o con algo que decir');
    }

    /* ── Y AHORA LA QUE DE VERDAD PILLA EL FALLO ──
       La de arriba pasaba también SIN el arreglo, y se comprobó quitándolo:
       aquí la cadena lleva medio arnés corrido cuando abre el trámite, así
       que la base ya contestó y la copia nunca sale muda. La prueba miraba
       una pantalla que no puede fallar, que es la manera más cara de estar
       en verde.

       Lo que falla en producción es el ORDEN, no el contenido: la copia
       hecha antes de que llegara el texto. Se reproduce dejando el renglón
       vacío -que es exactamente como queda esa copia temprana- y pidiendo
       el repintado que hace la base al contestar. Si nadie rehace la copia,
       se queda vacío para siempre, que es lo que se veía al recargar. */
    if (plazo && window.CIIP_REPINTA_ESTADOS){
      plazo.textContent = '';
      window.CIIP_REPINTA_ESTADOS();
      var vuelve = (plazo.textContent || '').trim();
      if (CON_ESTIMADO){
        ok('sisref: y si llega vacío, el repintado lo rellena',
           vuelve.length > 0,
           vuelve ? ('«' + vuelve + '»') : '(sigue mudo tras repintar)',
           'el estimado, escrito');
      } else {
        /* Vaciado a mano no queda ni el reloj: lo que se pide es que el
           repintado vuelva a poner la copia, y que llegue escondida. */
        ok('sisref: y si llega vacío, el repintado rehace la copia sin dejarla muda',
           !!plazo.querySelector('.t-time') && !mudoALaVista(),
           !plazo.querySelector('.t-time') ? '(no rehizo la copia)'
             : (mudoALaVista() ? '(el reloj, mudo)' : (vuelve ? '«' + vuelve + '»' : 'escondido')),
           'la copia, escondida o con algo que decir');
      }
    }

    /* Y donde se pidió: pegado a la descripción, encima de los pasos. Si
       mañana alguien lo mueve al pie o al final, esto lo dice. */
    var desc = document.getElementById('trDesc');
    var pasos = document.getElementById('trProceso') ||
                document.getElementById('trReal');
    if (plazo && desc && pasos){
      var trasLaDesc = (desc.compareDocumentPosition(plazo) &
                        Node.DOCUMENT_POSITION_FOLLOWING) !== 0;
      var antesDeLosPasos = (pasos.compareDocumentPosition(plazo) &
                             Node.DOCUMENT_POSITION_PRECEDING) !== 0;
      ok('sisref: y va entre la descripción y los pasos',
         trasLaDesc && antesDeLosPasos,
         'tras la descripción: ' + trasLaDesc + ', antes de los pasos: ' + antesDeLosPasos,
         'las dos ciertas');
    }

    var caja   = document.getElementById('trReal');
    var campos = caja.querySelectorAll('.sol-campo');
    var docs   = caja.querySelectorAll('.sol-doc');

    /* Esto es lo que estaba mal y no lo veía nadie: cero campos. */
    ok('sisref: «Tus datos» no está vacío', campos.length > 0,
       campos.length + ' campos', 'los nueve del portal');
    igual('sisref: pide los nueve datos', campos.length, 9);
    igual('sisref: y sus tres recaudos', docs.length, 3);

    /* Los tres que pide el portal, por su tipo de la bóveda. */
    var tipos = [];
    docs.forEach(function(d){ tipos.push(d.getAttribute('data-doc')); });
    igual('sisref: identidad, documento del trámite y poder',
      tipos.join(' '), 'pasaporte otro poder');

    /* Ni una palabra de la licencia de conducir. Es la comprobación que
       habría cazado el rótulo copiado, y la única que lo habría hecho. */
    var letra = caja.textContent.toLowerCase();
    ok('sisref: no habla de la licencia de conducir',
       letra.indexOf('licencia') === -1,
       letra.indexOf('licencia') === -1 ? 'limpio' : 'dice «licencia»',
       'sin rótulos de otra tarjeta');

    /* El del trámite es el que de verdad faltaba, y va OBLIGATORIO: sin él
       la solicitud no dice qué se va a otorgar, que es lo que el SAREN
       mira. El poder va opcional, que sólo le hace falta al apoderado. */
    var doc = caja.querySelector('.sol-doc[data-doc="otro"]');
    ok('sisref: el documento del trámite es obligatorio',
       !!doc && !doc.hasAttribute('data-opcional'),
       doc ? (doc.hasAttribute('data-opcional') ? 'opcional' : 'obligatorio') : 'no está',
       'obligatorio');
    var pod = caja.querySelector('.sol-doc[data-doc="poder"]');
    ok('sisref: y el poder, opcional',
       !!pod && pod.hasAttribute('data-opcional'),
       pod ? (pod.hasAttribute('data-opcional') ? 'opcional' : 'obligatorio') : 'no está',
       'opcional');

    /* Y que las opciones son las del portal, no unas parecidas. Se mira la
       de «cómo actúas», que es la lista corta y literal: si alguien la
       traduce, el gestor tiene que deshacer la traducción para
       transcribirla al SAREN. */
    var acc = caja.querySelector('.sol-campo[data-campo="accion_tramite"] select');
    var ops = [];
    if (acc) acc.querySelectorAll('option').forEach(function(o){
      if (o.value) ops.push(o.value);
    });
    igual('sisref: las opciones son las del portal, sin traducir',
      ops.join(' '), 'Solicitante Otorgante Accionista Director Comprador Vendedor');
  }

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
    /* Y se puede CAMBIAR. Al elegir otro archivo, el de la boveda deja de
       contar: sin esto la fila ensenaba el nombre nuevo con el visto bueno
       del viejo al lado y el boton de abrir apuntando al viejo, y no habia
       forma de saber cual de los dos se iba a enviar. */
    (function(){
      var fila = caja.querySelector('.sol-doc[data-ya]');
      if (!fila){ ok('recaudos: hay uno reutilizado que cambiar', false, 'ninguno', 'uno'); return; }
      var inp = fila.querySelector('input[type=file]');
      var dt = new DataTransfer();
      dt.items.add(new File([new Uint8Array(8)], 'el-nuevo.png', {type:'image/png'}));
      inp.files = dt.files;
      inp.dispatchEvent(new Event('change'));
      igual('recaudos: al elegir otro archivo, la fila dice el nuevo',
            (fila.querySelector('.sd-e') || {}).textContent, 'el-nuevo.png');
      ok('recaudos: y deja de decir que ya estaba en tu expediente',
         !fila.hasAttribute('data-ya') && !fila.querySelector('.sd-ya'),
         (fila.hasAttribute('data-ya') ? 'sigue con data-ya ' : '') +
         (fila.querySelector('.sd-ya') ? 'y con el visto' : 'sin marca'),
         'sin marca de reutilizado');
      ok('recaudos: y se va el boton que abria el viejo',
         !fila.querySelector('.sd-ver'),
         fila.querySelector('.sd-ver') ? 'sigue el boton' : 'se fue', 'se fue');
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

  /* ═══════════ CUÁL DE LAS VARIAS ═══════════
     La tarjeta pedía "la última creada". Con varias solicitudes del
     mismo trámite eso no es la que importa: quien avanzaba una en la cola
     del equipo volvía aquí y seguía viendo otra, y pensaba que el panel
     no se había actualizado. */
  function variasAbre(){
    if (CASO !== 'lleno') return;
    /* La c1 -la visa- es la que tiene DOS solicitudes. escaleraAbre abre
       la c3, que solo tiene una: mirar alli era medir un caso que no
       existe, y la prueba pasaba por casualidad. */
    location.hash = 'tramite-c1';
  }

  function variasMira(){
    if (CASO !== 'lleno') return;
    var caja = document.getElementById('trReal');
    if (!caja) return;

    /* Hay dos visas: una RESUELTA de julio y un BORRADOR de agosto. Con
       "la última creada" la tarjeta enseñaba el formulario en blanco
       sobre un trámite que ya está resuelto: las dos pantallas del mismo
       trámite decían cosas distintas. */
    var chip = document.querySelector('#trChip .chip');
    ok('varias: manda la que va más adelante, no la más reciente',
       chip && !/Iniciar|Guardad/i.test(chip.textContent),
       chip ? chip.textContent.trim() : 'sin distintivo',
       'el estado de la resuelta, no el formulario');
    ok('varias: y no enseña un formulario en blanco sobre algo resuelto',
       !document.querySelector('#trReal .sol-campos'),
       document.querySelector('#trReal .sol-campos') ? 'hay formulario' : 'sin formulario',
       'sin formulario');

    /* Y se dice que hay más de una: enseñar una sin avisar es justo lo
       que hace pensar que la pantalla no se actualiza. */
    var av = document.getElementById('trVarias');
    if (av && av.hidden) av = null;
    ok('varias: y avisa de que hay más de una',
       av && /2 solicitudes de este trámite/.test(av.textContent),
       av ? av.textContent.trim().slice(0, 52) : 'no lo dice', 'lo dice');
    ok('varias: y ofrece verlas todas',
       av && !!av.querySelector('button'),
       (av && av.querySelector('button')) ? 'con botón' : 'sin botón', 'con botón');
    /* Arriba del todo: es lo que hay que saber ANTES de leer la escalera
       de abajo, no después. */
    /* Arriba de la tarjeta y FUERA de ella: lo de dentro se rehace en
       dos tiempos -primero el estado, luego el historial- y un aviso
       metido ahi lo barria el segundo repintado. */
    ok('varias: y el aviso va encima de la tarjeta',
       av && av.compareDocumentPosition(caja) & Node.DOCUMENT_POSITION_FOLLOWING,
       av ? 'encima' : 'no hay aviso', 'encima');
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
  /* "Vas por aquí" tenía forma de píldora —borde, fondo, esquinas
     redondas—, la misma que los filtros de la portada, que esos sí se
     pulsan. Es un RÓTULO: la forma prometía un clic que no existe. */
      /* DENTRO de #trReal: hay otro .tr-aqui en la escalera de maqueta -la
       de un tramite que nadie ha empezado- y es el primero del documento.
       Mirar ese era medir una etiqueta escondida, sin tiempo y sin alto. */
    var eti = document.querySelector('#trReal .tr-aqui');
    if (!eti) return;
    var css = getComputedStyle(eti);
    ok('escalera: "vas por aquí" no finge ser un botón',
       css.borderTopWidth === '0px' &&
       parseFloat(css.borderTopLeftRadius) < 10,
       'borde ' + css.borderTopWidth + ', radio ' + css.borderTopLeftRadius,
       'sin borde y sin forma de píldora');
    /* Y sigue viéndose: quitarle el marco no puede volverlo invisible. */
    ok('escalera: pero se sigue viendo', eti.offsetHeight > 0 && css.color !== css.backgroundColor,
       'alto ' + eti.offsetHeight + ', color ' + css.color, 'visible');

    /* Lo que pedía el CIIP: que diga cuánto llevas parado ahí. Es un
       HECHO y no un plazo; cuánto DEBERÍA tardar no lo ha dicho nadie. */
    var desde = eti.querySelector('.tr-desde');
    ok('escalera: y dice desde cuándo llevas en ese paso',
       desde && /hace|día|mes|semana/.test(desde.textContent),
       desde ? desde.textContent.trim() : 'no lo dice', 'algo como "desde hace 6 días"');
    ok('escalera: sin inventarse un plazo',
       !/deber|plazo|tarda/i.test(eti.textContent), eti.textContent.trim(),
       'ninguna promesa');

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

    /* Los cinco EN UNA FILA. El quinto se caía solo abajo y leído así
       parecía de otra cosa, no el quinto de la misma serie. */
    (function(){
      var filas = {};
      [].forEach.call(m, function(x){
        var y = Math.round(x.getBoundingClientRect().top);
        filas[y] = (filas[y] || 0) + 1;
      });
      var cuantas = Object.keys(filas).length;
      igual('usuarios: los cinco números van en una sola fila', cuantas, 1);
      /* Y "Citas por confirmar" pegado a "Esperando por el CIIP", que es
         lo que se pidió: mismo alto y el siguiente por la izquierda. */
      var esp = m[3].getBoundingClientRect();
      var cit = m[4].getBoundingClientRect();
      ok('usuarios: y las citas quedan al lado de lo que espera el CIIP',
         Math.abs(esp.top - cit.top) < 2 && cit.left > esp.left,
         'esperando en ' + Math.round(esp.left) + ', citas en ' + Math.round(cit.left),
         'a la derecha y a la misma altura');
    })();

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
  /* Lo mismo del lado del inversionista, salvo en los resueltos: ahí
     "lleva veinte días" no dice nada, ya terminó. */
  function mtLleva(){
    if (CASO !== 'lleno') return;
    /* #tramites, NO #mistramites. La segunda no es ninguna ruta: el enrutador
       la ignora y la vista se queda en la portada. Aquí llevaba tiempo
       puesta, y las comprobaciones de abajo pasaban igual porque sólo cuentan
       filas del árbol —que existen aunque la pantalla esté escondida—. Se vio
       al medir el ALTO de un reloj: cero, porque nada estaba a la vista. */
    location.hash = 'tramites';
  }

  function mtLlevaMira(){
    if (CASO !== 'lleno') return;
    var fichas = document.querySelectorAll('#mtCuerpo tr');
    ok('mis trámites: los vivos dicen desde cuándo están así',
       [].filter.call(fichas, function(f){ return f.querySelector('.lleva'); }).length >= 3,
       [].filter.call(fichas, function(f){ return f.querySelector('.lleva'); }).length +
       ' de ' + fichas.length + ' con reloj', '3 o más');
    /* ── Y EL RELOJ VA EN UNA SOLA LÍNEA ──
       El reloj de «lleva N días» es un inline-flex: su icono y su texto van
       uno al lado del otro. Una regla de la tabla lo bajaba a su propio
       renglón —bien— pero con display:block, y eso le quitaba el inline-flex:
       el icono se iba solo a una línea y el texto a la siguiente, como si
       algo se hubiera roto. No lo vio ninguna prueba; se vio en un pantallazo
       de la tabla con trámites dentro.

       Se mide el ALTO, que es lo que delata dos líneas, y que el icono esté a
       la misma altura que su texto. Comprobar que existe el elemento no
       distingue una línea de dos. */
    var reloj = document.querySelector('#mtCuerpo .lleva');
    if (reloj){
      var r = reloj.getBoundingClientRect();
      ok('mis trámites: y el reloj cabe en una sola línea',
         r.height > 0 && r.height <= 20, Math.round(r.height) + 'px de alto', 'como mucho 20');
      var svg = reloj.querySelector('svg');
      if (svg){
        var sr = svg.getBoundingClientRect();
        ok('mis trámites: con su icono a la altura del texto, no encima',
           Math.abs((sr.top + sr.height / 2) - (r.top + r.height / 2)) < 3,
           'centro del icono a ' + Math.round(Math.abs((sr.top + sr.height/2) - (r.top + r.height/2))) + 'px',
           'al mismo nivel');
      }
    }

    /* El resuelto no: ya terminó, y "lleva veinte días" ahí sobra. */
    var hecho = [].filter.call(fichas, function(f){
      return f.classList.contains('pasada'); })[0];
    ok('mis trámites: y el resuelto no, que ya terminó',
       hecho && !hecho.querySelector('.lleva'),
       hecho ? (hecho.querySelector('.lleva') ? 'lo lleva' : 'sin reloj') : 'no hay resuelto',
       'sin reloj');
    /* ── LOS CUATRO MONTONES ── Con seis solicitudes del mismo trámite
       la lista no dice nada; separadas por estado, sí. Y con las MISMAS
       palabras que la portada: quien ya sabe filtrar allí no tiene que
       aprender otra cosa aquí. */
    (function(){
      var fil = document.querySelectorAll('#mtFiltros button');
      ok('mis trámites: hay filtros por estado', fil.length >= 2,
         fil.length + ' botones', '2 o más');
      igual('mis trámites: con las palabras de la portada',
            fil[0].textContent.replace(/[0-9]/g, '').trim(), 'Todos');

      /* El montón vacío no se ofrece: un botón que lleva a una lista en
         blanco es una promesa que no se cumple. */
      var vacios = [].filter.call(fil, function(b){
        return b.querySelector('.n').textContent === '0'; });
      igual('mis trámites: y ninguno lleva a una lista vacía', vacios.length, 0);

      /* Filtrar de verdad enseña menos de las que hay. */
      var todas = document.querySelectorAll('#mtCuerpo tr').length;
      var otro = [].filter.call(fil, function(b){ return !b.classList.contains('aqui'); })[0];
      if (otro){
        var cuantas = parseInt(otro.querySelector('.n').textContent, 10);
        otro.click();
        igual('mis trámites: y filtrar enseña solo las de ese montón',
              document.querySelectorAll('#mtCuerpo tr').length, cuantas);
        ok('mis trámites: que son menos que todas', cuantas < todas,
           cuantas + ' de ' + todas, 'menos');
        /* Y volver las devuelve: un filtro que no se limpia deja la vista
           coja para el resto de la sesión. */
        document.querySelectorAll('#mtFiltros button')[0].click();
        igual('mis trámites: y "Todos" las devuelve',
              document.querySelectorAll('#mtCuerpo tr').length, todas);
      }
    })();

    /* ── EN TABLA ──
       Esto medía una REJILLA de fichas: que dos compartieran fila y que
       ninguna se saliera por la derecha. Ya no hay rejilla, hay tabla.

       Y no dieron rojo al cambiar, que es lo peor que podían hacer: el bloque
       empezaba con «if (f.length < 2) return;», así que al quedarse el
       selector sin encontrar nada se saltaba entero y las dos comprobaciones
       DESAPARECÍAN de la cuenta. Ni verdes ni rojas: sin correr. El total
       bajaba dos y no había ninguna línea roja que lo explicara.

       Ahora se mide lo que una tabla puede romper: que tenga sus cinco
       columnas —cabecera sin cuerpo, o al revés, parece una pantalla a medio
       cargar—, que haya una fila por solicitud, y que ninguna se salga por la
       derecha, que es la misma preocupación de antes con otra forma. */
    (function(){
      igual('mis trámites: la tabla tiene sus cinco columnas',
            document.querySelectorAll('#mtCab th').length, 5);

      var filas = document.querySelectorAll('#mtCuerpo tr');
      ok('mis trámites: y una fila por cada solicitud tuya',
         filas.length >= 3, filas.length + ' filas', 'tres o más');

      var caja = document.getElementById('mtTabla');
      if (caja && filas.length){
        var r = caja.getBoundingClientRect();
        var fuera = [].filter.call(filas, function(x){
          return x.getBoundingClientRect().right > r.right + 1; });
        igual('mis trámites: y ninguna fila se sale por la derecha', fuera.length, 0);
      }
    })();

    location.hash = '';
  }

  /* ═════ EL RENGLON DE "MIS TRAMITES", PARA EL EQUIPO ═════
     La politica de la base deja al equipo del CIIP leer los tramites de
     TODOS, y la consulta de "Mis tramites" no filtra por dueno porque no
     le hace falta. Asi que ese renglon le traia la oficina entera bajo un
     rotulo que dice "mis". Ahora se llama como el boton de arriba y abre
     lo mismo: un solo sitio donde llegan las solicitudes, con dos
     puertas. */
  function colaRenglon(){
    var fila = document.getElementById('navTramites');
    if (!fila) return;
    var et = fila.querySelector('[data-i18n]');
    if (CASO !== 'gestor'){
      igual('barra: al inversionista le sigue diciendo Mis tramites',
            et ? et.getAttribute('data-i18n') : 'sin etiqueta', 'nav.procedures');
      fila.click();
      return;
    }
    igual('barra: al equipo del CIIP el renglon pasa a ser la cola',
          et ? et.getAttribute('data-i18n') : 'sin etiqueta', 'nav.queue');
    igual('barra: y lo dice con todas las letras',
          et ? et.textContent.trim() : '', 'Trámites por atender');
    /* Y el numero es el de la COLA, no el de sus tramites. Antes esto se
       comprobaba contra la chapa del boton «Por atender» de arriba -que los
       dos dijeran lo mismo-; el boton se retiro y esta chapa se quedo sola,
       asi que ahora se compara contra lo que la propia cola dibuja: la
       ventana ya esta pintada a estas alturas de la tanda. */
    igual('barra: y el numero es el de la cola, no el de sus tramites',
          (document.getElementById('navTramitesN') || {}).textContent,
          String(document.querySelectorAll('#colaLista .co-ficha').length +
                 document.querySelectorAll('#colaTram .co-ficha').length +
                 document.querySelectorAll('#colaCons .co-ficha').length));
    /* Su panel no cuenta lo de los demas: de esa misma consulta salen los
       estados de las 31 tarjetas y las cuentas de las cinco fases. */
    igual('barra: y su panel no cuenta los tramites de otros',
          deEtapa(0, '.jcount'), '0 de 11 listos');
    fila.click();
  }

  function colaRenglonAbre(){
    if (CASO !== 'gestor'){
      /* Al inversionista el renglon le lleva a su lista de siempre. */
      igual('barra: y al inversionista le abre su lista',
            document.body.getAttribute('data-vista'), 'mistramites');
      /* Se sale por la direccion y no pulsando el boton de volver: desde
         que esa pantalla empieza por la tabla, ese boton ya no esta. Pulsar
         un elemento escondido funciona en JS y no funciona para una persona:
         una prueba que lo hiciera seguiria verde con la salida tapada. */
      location.hash = '';
      /* Y la tabla del equipo no es suya: el hash a mano no le entra. */
      location.hash = 'poratender';
      return;
    }
    igual('barra: y al equipo le abre la cola en tabla',
          document.body.getAttribute('data-vista'), 'poratender');
  }

  /* ═════ LA COLA EN TABLA ═════
     La ventana es para ACTUAR sobre un tramite. Esto es para ver la cola
     entera de un vistazo -quien espera, desde cuando y quien la lleva- en
     columnas que se comparan; una pila de fichas se lee una por una. */
  function tablaMira(){
    if (CASO !== 'gestor'){
      igual('tabla: al inversionista la cola del equipo no le entra',
            document.body.getAttribute('data-vista') === 'poratender', false);
      if (location.hash) location.hash = '';
      return;
    }
    var filas = document.querySelectorAll('#paCuerpo tr');
    /* Cuantos hay depende de lo que hayan hecho los pasos de arriba -uno
       se devolvio y otro se presento-, asi que el numero exacto no se
       escribe: lo que se mide es que haya cola y que sea la MISMA que la
       de la ventana. Si tuviera su propia consulta, los dos numeros
       dejarian de cuadrar el dia que una se quedara vieja. */
    ok('tabla: hay un renglon por cada tramite que espera', filas.length > 0,
       filas.length + ' renglones', 'al menos uno');
    igual('tabla: y son los mismos que ensena la ventana',
          filas.length, document.querySelectorAll('#colaTram .co-ficha').length);
    igual('tabla: con sus siete columnas',
          document.querySelectorAll('#paCab th').length, 7);
    if (!filas.length) return;

    var celdas = filas[0].querySelectorAll('td');
    ok('tabla: el renglon dice de quien es', celdas[0].textContent.trim().length > 0,
       '"' + celdas[0].textContent.trim() + '"', 'un nombre');
    ok('tabla: y que tramite es', celdas[1].textContent.trim().length > 0,
       '"' + celdas[1].textContent.trim() + '"', 'un tramite');
    /* Quien lo lleva es la columna que convierte la lista en reparto. */
    ok('tabla: y quien lo lleva', celdas[5].textContent.trim().length > 0,
       '"' + celdas[5].textContent.trim() + '"', 'alguien o "sin asignar"');
    /* El reloj: es lo que decide a quien se atiende primero. */
    ok('tabla: y cuanto lleva esperando',
       /día|hora|semana|minuto|giorn|ora|settiman/i.test(celdas[4].textContent),
       '"' + celdas[4].textContent.trim() + '"', 'un tiempo');
  }

  /* Y no duplica ni una accion: el renglon abre la ventana por SU tramite.
     Dos sitios donde tomar la misma solicitud se desincronizan el primer
     dia. */
  function tablaAbre(){
    if (CASO !== 'gestor') return;
    var back = document.getElementById('colaBack');
    if (back) back.classList.remove('open');   /* que la medida sea de esto */
    var filas = document.querySelectorAll('#paCuerpo tr');
    if (!filas.length){ window.PRUEBA_TR = null; return; }
    /* El ultimo, que es el que menos posibilidades tiene de ser tambien
       el primero de la ventana: asi "se abrio por el que pulsaste" mide
       algo y no coincide por casualidad. */
    var cual = filas[filas.length - 1];
    window.PRUEBA_TR = cual.getAttribute('data-tr');
    cual.click();
  }

  function tablaTrasAbrir(){
    if (CASO !== 'gestor' || !window.PRUEBA_TR) return;
    var back = document.getElementById('colaBack');
    ok('tabla: al pulsar un renglon se abre la ventana',
       !!back && back.classList.contains('open'),
       back ? back.className : 'no hay ventana', 'abierta');
    /* Y por el que pulsaste. Abrirla por arriba obliga a buscar otra vez
       el que acabas de senalar, y con quince en la cola eso es volver a
       empezar. */
    var suya = document.querySelector('#colaTram [data-tr="' + window.PRUEBA_TR + '"]');
    ok('tabla: y senalando el que pulsaste',
       !!suya && suya.classList.contains('recien'),
       suya ? suya.className : 'no esta esa ficha', 'marcada');
    if (document.getElementById('colaCerrar')) document.getElementById('colaCerrar').click();
    if (location.hash) location.hash = '';
  }

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
    /* offsetHeight y no .hidden: [hidden] del navegador es display:none,
       pero cualquier display de la hoja de estilos le gana, y .pf-campo
       trae display:flex. Con .hidden esta prueba daba verde mientras los
       doce campos seguian pintados en pantalla. Preguntarle al DOM por
       la propiedad es preguntarle por lo que uno le dijo; preguntarle por
       el alto es preguntarle por lo que hizo. */
    var visibles = function(){
      return [].filter.call(document.querySelectorAll('#emCampos .pf-campo'),
                            function(c){ return c.offsetHeight > 0; });
    };
    igual('empresa: pero solo se ven los cinco del primer paso', visibles().length, 5);
    /* Por su nombre, que es como se nota: "Actividad economica" es del
       paso 2 y asomaba al final del 1. */
    ok('empresa: y ningun campo del paso 2 asoma en el 1',
       visibles().every(function(c){
         return !/Actividad económica/.test(c.textContent); }),
       visibles().map(function(c){ return c.querySelector('label').textContent; }).join(' / '),
       'sin Actividad económica');
    /* Y el aviso de que basta con la razon social se ve DE VERDAD: si el
       cuerpo llega rodado, lo primero que hay que leer queda arriba y
       fuera. */
    (function(){
      var mn = document.getElementById('emMinimo');
      var caja = document.getElementById('emCampos');
      ok('empresa: y el aviso de arriba se ve, no llega rodado',
         mn.getBoundingClientRect().top >= caja.getBoundingClientRect().top - 1,
         'aviso en ' + Math.round(mn.getBoundingClientRect().top) +
         ', caja en ' + Math.round(caja.getBoundingClientRect().top), 'dentro');
      igual('empresa: y la etiqueta del primer campo también',
            caja.scrollTop, 0);
    })();

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

    /* ── LA FECHA, EN TRES LISTAS ── Un calendario sirve para fechas
       cercanas. Nadie elige mayo de 2020 pulsando sesenta veces la flecha
       del mes, y el del navegador ademas se salía del diálogo. */
    (function(){
      var f3 = document.querySelectorAll('#em_fecha_constitucion_a, #em_fecha_constitucion_m, #em_fecha_constitucion_d');
      igual('fecha: la constitución se elige en tres listas', f3.length, 3);
      ok('fecha: y ya no hay calendario del navegador',
         document.getElementById('em_fecha_constitucion').type === 'hidden',
         document.getElementById('em_fecha_constitucion').type, 'hidden');

      var selA = document.getElementById('em_fecha_constitucion_a');
      var selM = document.getElementById('em_fecha_constitucion_m');
      var selD = document.getElementById('em_fecha_constitucion_d');
      var hoy = new Date();

      /* Del más reciente al más viejo: una empresa de hace dos años no
         debería recorrer un siglo para encontrarse. */
      igual('fecha: los años empiezan por el de este año',
            selA.options[1].value, String(hoy.getFullYear()));
      igual('fecha: y llegan hasta 1900',
            selA.options[selA.options.length - 1].value, '1900');
      ok('fecha: y ninguno es del futuro',
         [].every.call(selA.options, function(o){
           return !o.value || parseInt(o.value, 10) <= hoy.getFullYear(); }),
         'el mayor es ' + selA.options[1].value, 'como mucho ' + hoy.getFullYear());

      /* Los meses con su nombre: "03" obliga a contar con los dedos. */
      igual('fecha: los meses van con su nombre', selM.options[1].textContent, 'enero');

      /* Febrero tiene 28 o 29 según el año: una lista fija de 31 deja
         elegir el 31 de febrero. */
      selA.value = '2021'; selA.dispatchEvent(new Event('change'));
      selM.value = '02';   selM.dispatchEvent(new Event('change'));
      igual('fecha: febrero de 2021 tiene 28 días', selD.options.length - 1, 28);
      selA.value = '2020'; selA.dispatchEvent(new Event('change'));
      selM.value = '02';   selM.dispatchEvent(new Event('change'));
      igual('fecha: y el de 2020, que fue bisiesto, 29', selD.options.length - 1, 29);

      /* Y del mes en curso no se ofrecen días que no han llegado. */
      selA.value = String(hoy.getFullYear()); selA.dispatchEvent(new Event('change'));
      selM.value = String(hoy.getMonth() + 1).padStart(2, '0');
      selM.dispatchEvent(new Event('change'));
      igual('fecha: de este mes solo se ofrecen los días ya vividos',
            selD.options.length - 1, hoy.getDate());
      var mesesVivos = [].filter.call(selM.options, function(o){ return o.value && !o.hidden; });
      igual('fecha: y de este año, solo los meses ya pasados',
            mesesVivos.length, hoy.getMonth() + 1);

      /* Las tres juntas escriben la fecha; con una suelta no hay fecha. */
      selD.value = '01'; selD.dispatchEvent(new Event('change'));
      igual('fecha: las tres juntas componen el dato',
            document.getElementById('em_fecha_constitucion').value,
            String(hoy.getFullYear()) + '-' +
            String(hoy.getMonth() + 1).padStart(2, '0') + '-01');
      selM.value = ''; selM.dispatchEvent(new Event('change'));
      igual('fecha: y a medias no compone nada',
            document.getElementById('em_fecha_constitucion').value, '');
      selA.value = ''; selA.dispatchEvent(new Event('change'));
      selD.value = ''; selD.dispatchEvent(new Event('change'));
    })();

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

    /* Las listas no ofrecen una fecha imposible, pero la comprobación al
       guardar se queda: es la que protege de un dato que entre por otro
       lado —una fila vieja, una carga a mano— y la que dice POR QUÉ. */
    (function(){
      var fc = document.getElementById('em_fecha_constitucion');
      fc.value = '2087-01-01';
      document.getElementById('emGuardar').click();
      igual('empresa: una fecha del futuro no pasa, venga de donde venga',
            document.getElementById('emAviso').textContent,
            'Una empresa no se constituye en el futuro. Revisa la fecha.');
      ok('empresa: y el campo se marca',
         fc.closest('.pf-campo').classList.contains('mal'),
         fc.closest('.pf-campo').className, 'con la clase mal');
      fc.value = '';
      fc.dispatchEvent(new Event('input', {bubbles:true}));
    })();

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
    var n = document.getElementById('navDocs');
    if (n && !n.hidden) n.click();
  }

  function docsMira(){
    /* Al equipo del CIIP no le sale. La politica de la base le deja leer
       los documentos de TODOS, asi que esta lista, vista por un gestor,
       era la de la oficina entera bajo un titulo que dice "todo lo que HAS
       subido" y sin decir de quien es cada papel. Los recaudos los ve
       donde le sirven: dentro del expediente que esta revisando. */
    if (CASO === 'gestor'){
      var n = document.getElementById('navDocs');
      /* Se mide que NO SE VE, no que lleve el atributo. Con solo mirar
         'hidden' esto pasaba en verde mientras el renglon seguia a la
         vista: .sb-item lleva display:flex, y cualquier display de la
         hoja de estilos le gana a [hidden]. */
      ok('bóveda: al equipo del CIIP no se le ofrece',
         !!n && n.hidden && n.offsetParent === null,
         n ? ('hidden=' + n.hidden + ' visible=' + (n.offsetParent !== null)) : 'no hay renglón',
         'escondido y sin pintar');
      ok('bóveda: y no se le traen los papeles de nadie',
         document.querySelectorAll('#dcLista tr[data-doc]').length === 0,
         document.querySelectorAll('#dcLista tr[data-doc]').length + ' renglones', 'ninguno');
      /* Y si llega por el hash escrito a mano, se le devuelve a la
         portada en vez de dejarle una pantalla en blanco. */
      location.hash = 'documentos';
      return;
    }
    igual('bóveda: el renglón abre su vista', document.body.getAttribute('data-vista'), 'documentos');

    /* Renglones, no fichas: una pila de fichas no se compara, y para
       saber cual vence antes habia que leerlas una a una. */
    var filas = document.querySelectorAll('#dcLista tr[data-doc]');
    igual('bóveda: están los tres documentos', filas.length, 3);
    igual('bóveda: con sus siete columnas',
          document.querySelectorAll('#dcCab th').length, 7);
    igual('bóveda: y el renglón los cuenta',
          document.getElementById('navDocsN').textContent, '3');

    /* Lo caducado primero: es lo único de esta lista sobre lo que hay algo
       que hacer. */
    igual('bóveda: el vencido va el primero',
          filas[0].querySelector('.ct-chip').textContent.trim(), 'Vencido');
    /* La franja va a la izquierda del renglon y no de fondo: un renglon
       entero en color se lee como un error de la pantalla y no como un
       aviso sobre el papel. */
    ok('bóveda: y el renglon lo avisa',
       filas[0].classList.contains('mal'), filas[0].className, 'con la marca');
    /* Y su distintivo NO puede salir en verde. comoEsta() devuelve clase
       VACIA para el vencido -su color lo pone .ct-chip a secas- y un
       "|| 'listo'" al pintarlo le ponia el verde de vigente: decia
       "Vencido" en el color de "todo en orden". */
    ok('bóveda: y su distintivo no sale en verde',
       !filas[0].querySelector('.ct-chip').classList.contains('listo'),
       filas[0].querySelector('.ct-chip').className, 'sin la clase listo');
    /* El que no caduca SI va en verde: no tener vencimiento es un estado,
       no un hueco, y en una columna donde dos llevan distintivo el tercero
       en texto pelado parece que le falta el dato. */
    var ultimo = filas[filas.length - 1].querySelector('.ct-chip');
    ok('bóveda: y el que no caduca lo dice, en verde',
       !!ultimo && ultimo.classList.contains('listo'),
       ultimo ? ultimo.className + ' "' + ultimo.textContent.trim() + '"' : 'sin distintivo',
       'con la clase listo');

    /* Treinta días de aviso: el que vence dentro de doce ya lo dice. */
    var textos = document.getElementById('dcLista').textContent;
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

    /* El de ABRIR, que ahora hay dos por ficha: desde que se puede cambiar
       un papel, contar '.btn' a secas contaba los dos y esto media otra
       cosa. */
    (function(){
      /* Uno por renglon. Se cuentan los de ABRIR y no '.t-btn' a secas,
         que desde que se puede cambiar hay dos por renglon. */
      var abren = [].filter.call(document.querySelectorAll('#dcLista .t-btn'),
        function(b){ return b.textContent.trim() === 'Abrir'; }).length;
      ok('bóveda: cada uno se puede abrir', filas.length === abren,
         abren + ' botones de abrir para ' + filas.length + ' renglones',
         filas.length + ' botones');
    })();

    document.getElementById('dcVolver').click();
  }

  /* ═══════════ AYUDA Y GUÍA ═══════════
     El renglón se iluminaba y no llevaba a ninguna parte. Lo que faltaba no
     eran más preguntas sobre invertir en Venezuela —esas ya están en la
     portada— sino quién explica cómo funciona el panel. */
  /* ═══════ CAMBIAR UN PAPEL DE LA BOVEDA ═══════
     Abrirlo servia para comprobar que el que hay no es el que vale
     -"pasaporte.pdf" puede ser el vencido- y hasta ahi llegaba: mirabas,
     veias que estaba mal y no habia nada que hacer sin entrar en un
     tramite que a lo mejor no ibas a enviar. */
  function docsCambia(){
    if (CASO === 'gestor'){
      ok('bóveda: y el hash a mano le devuelve a la portada',
         document.body.getAttribute('data-vista') !== 'documentos',
         document.body.getAttribute('data-vista') || 'inicio', 'no es documentos');
      return;
    }
    var f = document.querySelector('#dcLista tr[data-doc]');
    function elCambiar(fila){
      return [].filter.call(fila.querySelectorAll('.t-btn'), function(b){
        return b.textContent.trim() === 'Cambiar';
      })[0];
    }
    ok('docs: el renglon ofrece cambiar el papel', !!(f && elCambiar(f)),
       f ? (elCambiar(f) ? 'con boton' : 'solo abrir') : 'no hay renglon',
       'con boton de cambiar');
    if (!f) return;
    var arch = f.querySelector('input[type=file]');
    if (!arch) return;
    /* Cuantos hay ANTES, para medir que el nuevo se suma y el viejo no se
       borra: va adjunto a solicitudes ya enviadas. */
    window.PRUEBA_DOCS_ANTES = document.querySelectorAll('#dcLista tr[data-doc]').length;
    var dt = new DataTransfer();
    dt.items.add(new File([new Uint8Array(8)], 'el-bueno.pdf', {type:'application/pdf'}));
    arch.files = dt.files;
    arch.dispatchEvent(new Event('change'));
  }

  function docsEsperaCambio(sigue){
    if (CASO === 'gestor') return sigue();
    esperaFilas('#dcLista tr[data-doc]', (window.PRUEBA_DOCS_ANTES || 0) + 1, sigue);
  }

  function docsTrasCambiar(){
    if (CASO === 'gestor') return;
    var fichas = document.querySelectorAll('#dcLista tr[data-doc]');
    igual('docs: al cambiarlo, el nuevo se suma y el viejo se queda',
          fichas.length, (window.PRUEBA_DOCS_ANTES || 0) + 1);
    ok('docs: y el nuevo lleva su nombre',
       /el-bueno\.pdf/.test(document.getElementById('dcLista').textContent),
       'busca el-bueno.pdf', 'esta en la lista');
    /* Y se dice cual ya no vale: dos pasaportes sin decir cual se usa es
       peor que uno solo equivocado. */
    var marcas = document.querySelectorAll('#dcLista .dc-viejo');
    ok('docs: y el de antes queda marcado como reemplazado', marcas.length >= 1,
       marcas.length + ' marcados', 'al menos uno');
    /* Al reemplazado no se le ofrece cambiarlo: seria subir un tercero
       para dejarlo igual. */
    var vieja = marcas[0] ? marcas[0].closest('tr') : null;
    var sigue = vieja && [].filter.call(vieja.querySelectorAll('.t-btn'), function(b){
      return b.textContent.trim() === 'Cambiar';
    })[0];
    ok('docs: y al reemplazado ya no se le ofrece cambiar',
       !!vieja && !sigue,
       vieja ? (sigue ? 'sigue el boton' : 'sin boton') : 'no hay renglon viejo',
       'sin boton');
  }

  /* ═════ SUBIR UN DOCUMENTO QUE YA TIENES ═════
     Un papel solo entraba DENTRO de un tramite: si ya tenias el pasaporte
     apostillado, para guardarlo habia que empezar una solicitud que a lo
     mejor no ibas a mandar. */
  function docsNuevoMira(){
    var bt = document.getElementById('dcSubir');
    if (CASO === 'gestor'){
      /* Esta boveda no es suya, y sube() firma con quien esta dentro. */
      ok('subir: al equipo del CIIP no se le ofrece',
         !!bt && bt.hidden, bt ? ('hidden=' + bt.hidden) : 'no hay boton', 'escondido');
      return;
    }
    ok('subir: la boveda ofrece subir uno nuevo', !!bt && !bt.hidden,
       bt ? ('hidden=' + bt.hidden) : 'no hay boton', 'a la vista');
    if (!bt) return;
    igual('subir: y lo dice con todas las letras', bt.textContent.trim(), 'Subir un documento');

    /* Vive en la ULTIMA celda de la cabecera, que es la de las acciones:
       en linea con el "Cambiar" y el "Abrir" de cada renglon, que es lo
       mismo que hace. */
    ok('subir: y va en la celda de las acciones de la cabecera',
       !!document.querySelector('#dcCab th:last-child #dcSubir'),
       document.querySelector('#dcCab th:last-child #dcSubir') ? 'ahi esta' : 'no esta ahi',
       'en la ultima celda');

    /* Y sigue ahi despues de repintar. pintaDocs vacia la cabecera en cada
       repintado, asi que el boton se queda FUERA del documento entre uno y
       otro: hay que mover el mismo nodo de vuelta, no buscarlo por id ni
       crear otro. Cuando la boveda se quedaba vacia se limpiaba la
       cabecera y no se volvia a construir: el boton desaparecia del todo,
       justo cuando mas falta hace -no tienes ninguno-. */
    if (window.CIIP_REPINTA_DOCS) window.CIIP_REPINTA_DOCS();
    var trasPintar = document.querySelector('#dcCab #dcSubir');
    ok('subir: y sigue ahi tras repintar la tabla', !!trasPintar,
       trasPintar ? 'sigue' : 'se quedo fuera del documento', 'sigue');
    ok('subir: con su escuchador intacto, que es el mismo nodo',
       trasPintar === bt, trasPintar === bt ? 'el mismo' : 'otro nodo', 'el mismo');

    /* En una VENTANA y no desplegandose dentro de la tabla: desplegado
       empujaba la lista hacia abajo, y lo que estabas mirando -para no
       subir dos veces el mismo papel- se movia justo al ir a subirlo. */
    var caja = document.getElementById('docBack');
    ok('subir: la ventana nace cerrada',
       !!caja && !caja.classList.contains('open'),
       caja ? caja.className : 'no hay ventana', 'cerrada');

    /* Y la tabla no se mueve al abrirla: es lo que se venia a arreglar. */
    var antesY = document.querySelector('#dcLista tr').getBoundingClientRect().top;
    bt.click();
    ok('subir: y se abre al pulsar', caja.classList.contains('open'),
       caja.className, 'abierta');
    var despuesY = document.querySelector('#dcLista tr').getBoundingClientRect().top;
    igual('subir: y la lista no se mueve de sitio', Math.round(despuesY), Math.round(antesY));

    /* Los tipos que se ofrecen son los que PIDE algun tramite: los
       nombres traducidos ya estan escritos ahi, y un tipo que nadie pide
       seria guardar un papel que ningun formulario va a buscar. */
    var sel = document.getElementById('dcTipo');
    ok('subir: con los tipos que piden los tramites',
       !!sel && sel.options.length > 40,
       sel ? (sel.options.length + ' opciones') : 'no hay lista', 'mas de 40');
    igual('subir: la primera invita a elegir', sel.options[0].textContent.trim(),
          'Elígelo de la lista');
    /* Y dice cuales ya tienes: en una lista de cincuenta, sin eso se sube
       por segunda vez el que esta tres centimetros mas abajo. */
    var yaEsta = [].filter.call(sel.options, function(o){
      return /ya lo tienes/.test(o.textContent);
    });
    ok('subir: y marca los que ya tienes', yaEsta.length >= 1,
       yaEsta.length + ' marcados', 'al menos uno');
    /* Por nombre y en el idioma de turno, no por el codigo interno. */
    var nombres = [].slice.call(sel.options, 1).map(function(o){
      return o.textContent.split(' · ')[0];
    });
    var ordenados = nombres.slice().sort(function(a, b){ return a.localeCompare(b); });
    ok('subir: y en orden alfabetico por su nombre',
       nombres.join('|') === ordenados.join('|'),
       nombres.slice(0, 3).join(', '), 'ordenados');
  }

  /* Los dos campos se piden a la vez: decir "falta el tipo", arreglarlo y
     que entonces salga "falta el archivo" son dos viajes por un
     formulario de dos campos. */
  function docsNuevoFalta(){
    if (CASO === 'gestor') return;
    var g = document.getElementById('dcGuarda');
    if (!g) return;
    g.click();
    igual('subir: sin decir que es y sin archivo, no se sube',
          (document.getElementById('dcAviso') || {}).textContent,
          'Dinos qué documento es y elige el archivo.');
    ok('subir: y el desplegable se marca',
       !!document.querySelector('#docBack .pf-campo.mal'),
       document.querySelector('#docBack .pf-campo.mal') ? 'marcado' : 'sin marcar',
       'marcado');
  }

  function docsNuevoSube(){
    if (CASO === 'gestor') return;
    var sel = document.getElementById('dcTipo');
    var arc = document.getElementById('dcArchivo');
    if (!sel || !arc) return;
    /* Uno que NO se tenga: asi se mide que se suma, y no que se reemplaza. */
    var libre = [].filter.call(sel.options, function(o){
      return o.value && !/ya lo tienes/.test(o.textContent);
    })[0];
    if (!libre) return;
    sel.value = libre.value;
    var dt = new DataTransfer();
    dt.items.add(new File([new Uint8Array(16)], 'lo-que-ya-tenia.pdf', {type:'application/pdf'}));
    arc.files = dt.files;
    arc.dispatchEvent(new Event('change'));
    igual('subir: el nombre del archivo se ve antes de mandarlo',
          (document.getElementById('dcNombre') || {}).textContent, 'lo-que-ya-tenia.pdf');
    window.PRUEBA_DOCS_ANTES2 = document.querySelectorAll('#dcLista tr[data-doc]').length;
    document.getElementById('dcGuarda').click();
  }

  /* Con la misma guarda que el paso al que acompaña: al equipo del CIIP
     no se le pinta la bóveda, así que aquí no va a aparecer nunca una
     fila y esperarla es gastar el presupuesto de tiempo del navegador en
     algo que no puede ocurrir. */
  function docsEsperaSubida(sigue){
    if (CASO === 'gestor') return sigue();
    esperaFilas('#dcLista tr[data-doc]', (window.PRUEBA_DOCS_ANTES2 || 0) + 1, sigue);
  }

  function docsTrasSubir(){
    if (CASO === 'gestor') return;
    igual('subir: al guardarlo, la boveda tiene uno mas',
          document.querySelectorAll('#dcLista tr[data-doc]').length,
          (window.PRUEBA_DOCS_ANTES2 || 0) + 1);
    ok('subir: y con su nombre de archivo',
       /lo-que-ya-tenia\.pdf/.test(document.getElementById('dcLista').textContent),
       'busca lo-que-ya-tenia.pdf', 'esta en la lista');
    /* La ventana se cierra sola: dejarla abierta con lo de antes dentro
       invita a mandarlo dos veces. */
    var caja = document.getElementById('docBack');
    ok('subir: y la ventana se cierra sola',
       !!caja && !caja.classList.contains('open'), caja.className, 'cerrada');
    /* Y el "guardado" se dice FUERA, con la ficha nueva ya delante. */
    igual('subir: y lo dice con la ficha ya puesta',
          (document.getElementById('dcAvisoFuera') || {}).textContent,
          'Guardado. Ya lo tienen los trámites que lo piden.');
  }

  /* ═════ LA FICHA, ANTES DEL FORMULARIO ═════
     Al pulsar una tarjeta ya no salen doce casillas de golpe: primero la
     ficha -cuanto tarda, de que depende, si te toca y que recaudos pide- y
     el formulario cuando lo pidas. Asi que todo lo que mide un formulario
     tiene que pasar antes por aqui. */
  function empiezaSolicitud(){
    var caja = document.getElementById('trReal');
    if (!caja) return;
    /* Por su enganche y no por el texto ni por la caja que lo envuelve:
       al pasar la ficha de una columna a dos, buscarlo por '.ft-pie' dejo
       de encontrarlo y treinta pruebas de formularios se cayeron sin que
       hubiera nada roto. */
    var bt = caja.querySelector('.ft-ir');
    if (bt) bt.click();
  }
  /* ═════ SE ENTRA DIRECTO AL FORMULARIO ═════
     Aqui habia veinte comprobaciones de la FICHA: el plazo legal, de que
     depende, cuando aplica, como se presenta. La ficha se quito -decision del
     CIIP, con el dato delante de que 16 de los 33 tramites la tenian con
     plazos y 17 salian casi vacios-, asi que ya no hay nada de eso que medir.

     No se borran sin mas: lo que la ficha resolvia sigue teniendo que estar,
     solo que repartido. Eso es lo que se comprueba ahora.

     Y ojo con como estaba escrito: el bloque empezaba mirando los tiempos y
     seguia con «if (!tiempos.length) return;». Al desaparecer la ficha, las
     otras diecinueve se habrian saltado en silencio -ni verdes ni rojas- y el
     total habria bajado veinte sin una sola linea roja que lo explicara. Es
     el tercer sitio esta semana donde una guarda de «si no hay datos, no
     midas» convierte una prueba rota en una prueba invisible. */
  function fichaAbre(){
    if (CASO !== 'vacio') return;
    location.hash = 'tramite-c14';
  }

  function fichaMira(){
    if (CASO !== 'vacio') return;
    var caja = document.getElementById('trReal');

    /* SIN PULSAR NADA: el formulario esta puesto al abrir la tarjeta. */
    var campos = caja.querySelectorAll('.sol-campo');
    ok('directo: al abrir un tramite ya esta el formulario, sin pulsar nada',
       campos.length > 0, campos.length + ' casillas', 'las casillas puestas');

    /* Y NO queda rastro de la ficha. Sin esto, las de arriba se cumplirian
       igual con la ficha todavia delante y el formulario debajo. */
    igual('directo: y la ficha ya no se pinta',
          caja.querySelectorAll('.ft-hoja').length, 0);

    /* ── LA COLUMNA DE LOS PAPELES ──
       Es lo que sustituye a la ficha: sin ella, el que rellena no sabria que
       papeles le van a pedir hasta llegar al final. */
    var lado = caja.querySelector('.sol-lado');
    ok('directo: y al lado, los papeles que te van a pedir',
       !!lado, lado ? 'esta' : 'no esta', 'la columna de recaudos');
    if (!lado) return;

    /* HIJOS DIRECTOS. Con '.ft-rec li' salian 52: cada recaudo lleva dentro
     su globo de ayuda, y el globo lleva su propia lista de li. Se contaban
     los renglones de las ayudas junto con los papeles. */
    var recs = lado.querySelectorAll('.sol-doc');
    igual('directo: los seis papeles del trámite, ni uno menos', recs.length, 6);

    /* Y son los de SUBIR, no una copia para leer.

       Aqui hubo un fallo de bulto: la primera version puso al lado una lista
       de referencia y dejo abajo la seccion de subir, asi que los mismos
       tres papeles salian DOS VECES en la misma pantalla. Se vio en una
       captura, no en la tanda: ninguna comprobacion miraba si algo aparecia
       repetido, y contar dos listas que salen bien por separado da verde. */
    var subir = lado.querySelectorAll('.sol-doc input[type="file"]');
    igual('directo: y son los de subir, no una copia para leer',
          subir.length, recs.length);
    igual('directo: y no queda ningun papel suelto fuera de la columna',
          caja.querySelectorAll('.sol-col .sol-doc').length, 0);

    /* Y cada uno con su «i»: leer alli como debe venir cada papel evita el
       viaje de subirlo mal, que es el rechazo que se quiere quitar de en
       medio. En la ficha estaban; al mover la lista no se podian perder. */
    var pistas = lado.querySelectorAll('.pista');
    igual('directo: y cada papel con su ayuda', pistas.length, recs.length);

    /* Y se dice de que es: sin rotulo, unas cajas sueltas no se sabe si son
       requisitos, avisos o adjuntos ya subidos.

       El rotulo ya NO va dentro de la columna. Los papeles tienen ahora su
       propia hoja, y quien la titula es el renglon de los pasos -«Paso 2 de
       3 · Recaudos»- mas el tramo de la barra. Escribirlo otra vez dentro
       seria decir lo mismo dos veces con dos centimetros de por medio, que
       es lo que se le quito a la pantalla al partirla. Asi que se mide donde
       vive: en el tramo de la barra que le toca a esa hoja. */
    var hojaPap = lado.closest('.pa-hoja');
    var tramo = hojaPap && caja.querySelectorAll('.pa-seg')[
                  (+hojaPap.getAttribute('data-paso') || 1) - 1];
    var rotulo = tramo && (tramo.querySelector('.pa-l') || {}).textContent;
    ok('directo: y la hoja de los papeles dice de que es',
       /\S/.test(rotulo || ''), rotulo || '(sin rotulo)', 'su rotulo');
  }

  /* El plazo y la descripcion NO se fueron con la ficha: estaban y siguen en
     la cabecera del tramite, que es la otra mitad de lo que la ficha decia. */
  function fichaTrasEmpezar(){
    if (CASO !== 'vacio') return;
    var d = document.getElementById('trDesc');
    var p = document.getElementById('trPlazo');
    ok('directo: la cabecera sigue diciendo de que va el tramite',
       !!d && /\S/.test(d.textContent), d ? d.textContent.slice(0, 50) : '(no hay)',
       'la descripcion');
    ok('directo: y el plazo se ve, que la ficha lo escondia',
       !!p && !p.hidden, p ? ('oculto=' + p.hidden) : '(no hay)', 'a la vista');
  }

  /* ═════ SUBIR UN PAPEL Y QUE LA FICHA SE ENTERE ═════
     La ficha guarda los tipos que ya tienes -una consulta por sesion, que
     son treinta y una tarjetas-. Sin borrar esa memoria al subir, el papel
     que acabas de guardar seguia saliendo como que te falta hasta que
     recargabas la pagina: subias la solvencia del IVSS y el tramite que la
     pide seguia diciendo que no la tenias. */
  function cacheAbre(){
    if (CASO !== 'vacio') return;
    /* El c13 -RNC- es el unico que pide la solvencia del IVSS. */
    location.hash = 'tramite-c13';
  }

  function cacheMira(){
    if (CASO !== 'vacio') return;
    var caja = document.getElementById('trReal');
    /* En la columna de subir, que es donde vive ahora la lista. */
    var fila = [].filter.call(caja.querySelectorAll('.sol-lado .sol-doc'), function(d){
      return /Solvencia del IVSS/.test(d.textContent);
    })[0];
    ok('cache: el tramite pide la solvencia del IVSS', !!fila,
       fila ? 'la pide' : 'no la pide', 'la pide');
    if (!fila) return;
    /* Sin marca de reusado: todavia no esta en la boveda. */
    ok('cache: y de momento dice que no la tienes',
       !fila.querySelector('.sd-ya'), fila.className, 'sin la marca de ya lo tienes');
    window.PRUEBA_CACHE = true;
  }

  /* Se sube desde la boveda, que es el camino nuevo. */
  function cacheSube(){
    if (CASO !== 'vacio' || !window.PRUEBA_CACHE) return;
    location.hash = 'documentos';
  }

  function cacheSube2(){
    if (CASO !== 'vacio' || !window.PRUEBA_CACHE) return;
    var bt = document.getElementById('dcSubir');
    if (bt) bt.click();
    var sel = document.getElementById('dcTipo');
    var arc = document.getElementById('dcArchivo');
    if (!sel || !arc) return;
    sel.value = 'solvencia_ivss';
    var dt = new DataTransfer();
    dt.items.add(new File([new Uint8Array(8)], 'solvencia-ivss.pdf', {type:'application/pdf'}));
    arc.files = dt.files;
    arc.dispatchEvent(new Event('change'));
    document.getElementById('dcGuarda').click();
  }

  function cacheVuelve(){
    if (CASO !== 'vacio' || !window.PRUEBA_CACHE) return;
    location.hash = 'tramite-c13';
  }

  function cacheTrasVolver(){
    if (CASO !== 'vacio' || !window.PRUEBA_CACHE) return;
    var caja = document.getElementById('trReal');
    /* En la columna de subir, que es donde vive ahora la lista. */
    var fila = [].filter.call(caja.querySelectorAll('.sol-lado .sol-doc'), function(d){
      return /Solvencia del IVSS/.test(d.textContent);
    })[0];
    /* SIN recargar la pagina. Es lo unico que se mide aqui. */
    ok('cache: al subirla, el tramite se entera sin recargar',
       !!fila && !!fila.querySelector('.sd-ya'),
       fila ? fila.className : 'no esta la fila', 'con visto');
  }

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
          pasos[0].querySelector('.ay-paso-q').textContent.trim(),
          'Solicitud recibida por el CIIP');

    /* Y cada uno dice QUE PASA en el. Enumerarlos sin explicarlos dejaba
       sin contestar la unica pregunta que se viene a hacer aqui: quien
       tiene ahora la pelota. */
    var expl = document.querySelectorAll('#ayLista .ay-paso-e');
    igual('ayuda: los cuatro con su explicaci\u00f3n', expl.length, 4);
    var vacias = [].filter.call(expl, function(e){
      return e.textContent.trim().length < 40;
    });
    igual('ayuda: y ninguna se queda en una frase suelta', vacias.length, 0);
    /* Cuatro distintas: si dos dijeran lo mismo, una de las dos sobra. */
    var distintas = {};
    [].forEach.call(expl, function(e){ distintas[e.textContent.trim()] = 1; });
    igual('ayuda: y las cuatro dicen cosas distintas',
          Object.keys(distintas).length, 4);
    /* Las dos que hay que decir con cuidado: entregar no es decidir, y
       resuelta no es aprobada. Si alguien las suaviza, esto se entera. */
    ok('ayuda: el paso 3 dice que el CIIP no decide',
       /no decide/i.test(expl[2].textContent),
       expl[2].textContent.trim().slice(0, 60), 'lo dice');
    ok('ayuda: y el 4 que resuelta no es aprobada',
       /no quiere decir aprobada/i.test(expl[3].textContent),
       expl[3].textContent.trim().slice(0, 60), 'lo dice');

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

    /* Y volver por la otra puerta las devuelve todas: filtrar por un tema
       no puede dejar el asistente mutilado para el resto de la sesión.

       Antes esto lo comprobaba 'supAsk', el botón genérico de preguntar al
       asistente. Ya no existe: las dos puertas -CIIP e invertir- llevan al
       mismo sitio, así que un tercer botón para lo mismo sobraba. Lo que se
       vigila no ha cambiado, solo por dónde se vuelve. */
    document.getElementById('asstClose').click();
    document.getElementById('supFab').click();
    document.getElementById('supInv').click();
    var todos = [].filter.call(document.querySelectorAll('#asstSug .sug-chips button'),
                               function(b){ return !b.hidden; });
    igual('burbuja: y volver por invertir las devuelve todas', todos.length, 7);
    document.getElementById('asstClose').click();
  }

  /* ═══════════ EL ASISTENTE ESCRIBIENDO A MANO ═══════════
     Los chips de arriba son la cabeza vieja: siete respuestas escritas y
     traducidas, elegidas por palabras clave. Lo que se prueba aquí es la
     OTRA, la que sale a /api/asistente.

     Esto llevaba sin probarse desde que se escribió, y no por descuido:
     el arnés pulsaba chips y nunca escribía en el campo. Un camino que
     ninguna prueba recorre es un camino que nadie sabe si existe.

     Se comprueban los dos finales, y el segundo importa más que el
     primero: mientras la clave de Anthropic no esté puesta, el segundo
     es el ÚNICO que ocurre en producción. */

  function esperaBurbuja(dice, sigue){
    var n = 0;
    (function mira(){
      var burbujas = document.querySelectorAll('#asstBody .bub.a');
      var ultima = burbujas[burbujas.length - 1];
      if ((ultima && dice(ultima.textContent)) || ++n > 60) return sigue();
      setTimeout(mira, 40);
    })();
  }

  var fetchDeVerdad = window.fetch;

  function asstConServidor(sigue){
    var visto = null;
    window.fetch = function(url, opciones){
      visto = { url: url, opciones: opciones };
      return Promise.resolve({
        ok: true, status: 200,
        json: function(){ return Promise.resolve({ respuesta: 'Contesta el servidor.' }); }
      });
    };

    document.getElementById('supFab').click();
    document.getElementById('supInv').click();
    var campo = document.getElementById('asstInput');
    campo.value = '¿me hace falta un socio venezolano?';
    document.getElementById('asstSend').click();

    esperaBurbuja(function(t){ return t === 'Contesta el servidor.'; }, function(){
      var burbujas = document.querySelectorAll('#asstBody .bub.a');
      var ultima = burbujas[burbujas.length - 1];
      ok('asistente: lo escrito a mano lo contesta el servidor',
         !!ultima && ultima.textContent === 'Contesta el servidor.',
         ultima ? ultima.textContent.slice(0, 40) : '(nada)', 'Contesta el servidor.');

      ok('asistente: va a /api/asistente',
         !!visto && String(visto.url).indexOf('/api/asistente') >= 0,
         visto ? String(visto.url) : '(no llamó)', '/api/asistente');

      /* Sin esto la dirección quedaría abierta a internet entero, y
         cualquiera podría gastar la cuenta del CIIP desde una terminal. */
      ok('asistente: y lleva la sesión, para que el servidor sepa quién pregunta',
         !!visto && visto.opciones.headers.Authorization === 'Bearer token-de-mentira',
         visto ? visto.opciones.headers.Authorization : '(sin cabecera)',
         'Bearer token-de-mentira');

      var mandado = visto ? JSON.parse(visto.opciones.body) : null;
      ok('asistente: manda la pregunta, y solo la pregunta',
         !!mandado && mandado.mensajes.length === 1 &&
         mandado.mensajes[0].papel === 'usuario' &&
         /socio venezolano/.test(mandado.mensajes[0].texto),
         mandado ? JSON.stringify(mandado.mensajes) : '(nada)', 'un turno de usuario');

      /* La clave de Anthropic no puede salir de aquí porque aquí no está.
         Se mira igual: es lo único de todo esto que no tiene arreglo si se
         escapa una vez. */
      ok('asistente: no se manda ninguna clave desde el navegador',
         !!visto && visto.opciones.body.indexOf('sk-ant') < 0,
         'sin claves', 'sin claves');

      /* Y la segunda pregunta lleva la conversación, para que un «¿y ese
         cuánto tarda?» se entienda.

         Aquí se espera a la PETICIÓN, no a la burbuja. Esperando a la
         burbuja esto daba rojo con razones falsas: la burbuja de los
         puntos suspensivos aparece en cuanto se pulsa, o sea antes de que
         salga la petición, así que se miraba el envío anterior y salía un
         turno donde tenía que haber tres. */
      campo.value = '¿y cuánto tarda?';
      var deLaPrimera = visto.opciones.body;
      document.getElementById('asstSend').click();
      var n = 0;
      (function esperaSegunda(){
        if (visto.opciones.body === deLaPrimera && ++n <= 60){
          return setTimeout(esperaSegunda, 40);
        }
        var seg = JSON.parse(visto.opciones.body);
        ok('asistente: la segunda pregunta lleva lo ya dicho',
           seg.mensajes.length === 3 && seg.mensajes[1].papel === 'asistente',
           seg.mensajes.length + ' turnos (' +
             seg.mensajes.map(function(m){ return m.papel; }).join(', ') + ')',
           '3 turnos (usuario, asistente, usuario)');
        document.getElementById('asstClose').click();
        sigue();
      })();
    });
  }

  function asstSinServidor(sigue){
    /* Y AHORA LO QUE PASA HOY EN PRODUCCIÓN. Sin clave de Anthropic
       puesta, el servidor contesta 'sin-clave' y el asistente tiene que
       volver a las respuestas de siempre sin que el usuario note que
       hubo un plan A. Si esto falla, encender la IA a medias deja el
       asistente mudo, que es peor que no haberlo tocado. */
    window.fetch = function(){
      return Promise.resolve({
        ok: false, status: 503,
        json: function(){ return Promise.resolve({ motivo:'sin-clave', error:'no configurado' }); }
      });
    };

    document.getElementById('supFab').click();
    document.getElementById('supInv').click();
    var campo = document.getElementById('asstInput');
    /* 'taxes' está en la lista de palabras clave, así que la cabeza vieja
       sabe contestar esto: se comprueba que contesta ELLA, no un hueco. */
    campo.value = 'what about taxes?';
    document.getElementById('asstSend').click();

    esperaBurbuja(function(t){ return t !== '· · ·'; }, function(){
      var burbujas = document.querySelectorAll('#asstBody .bub.a');
      var ultima = burbujas[burbujas.length - 1];
      var esperada = (I18N[curLang] || I18N.en)['faq.q7.a'];
      ok('asistente: sin servidor, contesta la respuesta de siempre',
         !!ultima && ultima.textContent === esperada,
         ultima ? ultima.textContent.slice(0, 40) : '(nada)',
         String(esperada).slice(0, 40));
      ok('asistente: y no se queda con los puntos suspensivos puestos',
         !!ultima && ultima.textContent !== '· · ·',
         ultima ? ultima.textContent.slice(0, 20) : '(nada)', 'algo escrito');

      document.getElementById('asstClose').click();
      window.fetch = fetchDeVerdad;
      sigue();
    });
  }

  /* ═══════════ LA FOTO TIPO CARNET ═══════════
     La piden tres tramites y hasta ahora solo se podia subir DENTRO de
     uno: para tener la foto guardada habia que empezar una solicitud que
     a lo mejor no ibas a mandar. Ahora se sube desde la ficha y cae en la
     misma boveda con el mismo tipo, asi que los formularios que la piden
     la encuentran ya cargada. */
  function fotoAbre(){
    var chip = document.querySelector('.user');
    if (chip) chip.click();
  }

  function fotoMira(){
    var campo = document.getElementById('pfCampoFoto');
    var av = document.querySelector('.avatar');
    /* El equipo del CIIP no tiene recaudos que subir: pedirle una foto de
       carnet es pedirle algo que no le toca. */
    if (CASO === 'gestor'){
      ok('foto: al equipo del CIIP no se le pide', !!campo && campo.hidden,
         campo ? ('hidden=' + campo.hidden) : 'no hay campo', 'escondido');
      ok('foto: y su circulo sigue con las iniciales',
         !!av && !av.querySelector('img'),
         av ? ('"' + av.textContent.trim() + '"') : 'no hay circulo', 'las iniciales');
      return;
    }
    /* Y mientras no hay foto, el circulo tampoco se la inventa. */
    ok('foto: sin foto, el circulo lleva las iniciales',
       !!av && !av.querySelector('img') && av.textContent.trim().length > 0,
       av ? ('"' + av.textContent.trim() + '"') : 'no hay circulo', 'las iniciales');
    ok('foto: la ficha ofrece subirla', !!campo && !campo.hidden,
       campo ? ('hidden=' + campo.hidden) : 'no hay campo', 'a la vista');
    if (!campo || campo.hidden) return;

    igual('foto: y el boton invita a subir la primera',
          (document.getElementById('pfFotoBtn') || {}).textContent, 'Subir una foto');
    igual('foto: y dice que no es la de los tramites',
          (document.getElementById('pfFotoPista') || {}).textContent,
          'Solo para reconocerte en el panel. No es la foto tipo carnet de los trámites: esa va en Documentos.');

    /* Mientras no hay ninguna, las iniciales. Un hueco vacio no dice si
       falta la foto o si es la pantalla la que no la trae. */
    var vista = document.getElementById('pfFotoVista');
    ok('foto: y mientras no hay ninguna salen tus iniciales',
       !!vista && !vista.querySelector('img') && vista.textContent.trim().length > 0,
       vista ? ('"' + vista.textContent.trim() + '"') : 'no hay hueco', 'las iniciales');
  }

  /* Se comprueba ANTES de subir: hacer esperar por un error que se sabia
     desde el principio es el peor sitio donde decirlo. */
  function fotoMala(){
    if (CASO === 'gestor') return;
    var inp = document.getElementById('pfFotoArchivo');
    if (!inp) return;
    var dt = new DataTransfer();
    dt.items.add(new File(['%PDF-1.4'], 'contrato.pdf', {type:'application/pdf'}));
    inp.files = dt.files;
    inp.dispatchEvent(new Event('change'));
    var pista = document.getElementById('pfFotoPista');
    igual('foto: un archivo que no es imagen no se sube, y lo dice',
          pista.textContent, 'Tiene que ser una imagen de menos de 5 MB.');
    ok('foto: y el aviso sale en rojo', /mal/.test(pista.className),
       pista.className, 'con la marca de error');
  }

  function fotoSube(){
    if (CASO === 'gestor') return;
    /* Cuantos papeles hay ANTES: la foto del perfil no puede sumar uno. */
    window.PRUEBA_DOCS_N = (document.getElementById('navDocsN') || {}).textContent;
    var inp = document.getElementById('pfFotoArchivo');
    if (!inp) return;
    var dt = new DataTransfer();
    dt.items.add(new File([new Uint8Array(64)], 'yo.png', {type:'image/png'}));
    inp.files = dt.files;
    inp.dispatchEvent(new Event('change'));
    /* Y el campo se vacia solo: sin eso, elegir DOS VECES el mismo archivo
       no lanza 'change' la segunda y el boton parece muerto. */
    igual('foto: y el campo se vacia para poder repetir el mismo archivo',
          inp.value, '');
  }

  function fotoTrasSubir(){
    if (CASO === 'gestor') return;
    var pista = document.getElementById('pfFotoPista');
    if (!pista) return;
    igual('foto: al subirla se guarda, y lo dice',
          pista.textContent, 'Guardada.');
    ok('foto: y el aviso sale en verde', /ok/.test(pista.className),
       pista.className, 'con la marca de hecho');
    ok('foto: y el boton vuelve a estar vivo',
       !document.getElementById('pfFotoBtn').disabled, 'vivo', 'vivo');

    /* Y sale en los DOS sitios. Una foto que solo se ve abriendo la ficha
       esta guardada en un cajon. */
    var vista = document.getElementById('pfFotoVista');
    ok('foto: y ya se ve en la ficha', !!vista && !!vista.querySelector('img'),
       vista && vista.querySelector('img') ? 'con foto' : 'sin foto', 'con foto');
    var av = document.querySelector('.avatar');
    ok('foto: y tambien en el circulo de la cabecera',
       !!av && !!av.querySelector('img'),
       av && av.querySelector('img') ? 'con foto' : ('"' + (av ? av.textContent.trim() : '') + '"'),
       'con foto');
    /* Y NO entra en la boveda. Es lo que se venia a separar: antes este
       campo subia el recaudo 'foto', asi que la foto del panel acababa
       enviada al SAIME. Ahora vive suelta en Storage, sin ficha en
       'documentos', y el renglon de Documentos no la cuenta. */
    igual('foto: y no se cuela en la boveda como un recaudo',
          (document.getElementById('navDocsN') || {}).textContent,
          window.PRUEBA_DOCS_N);

    ok('foto: y el circulo la recorta en vez de deformarla',
       !!av && av.classList.contains('con-foto'),
       av ? av.className : 'no hay circulo', 'con-foto');

    /* El boton ya no invita a subir la primera: ahora se cambia. */
    igual('foto: y el boton pasa a ofrecer cambiarla',
          document.getElementById('pfFotoBtn').textContent, 'Cambiar la foto');
  }

  function fotoCierra(){
    var x = document.getElementById('pfCerrar');
    if (x) x.click();
  }

  /* ═══════════ SIN PULSAR F5 ═══════════
     «Y no tengo que pisar F5 para ver trámites nuevos.» (CIIP)

     El catálogo y las solicitudes se pedían UNA vez, al cargar. Un trámite
     que el CIIP acaba de encender, o una solicitud que cambió de estado, no
     se veían hasta recargar — y nadie recarga una página que ya está
     abierta: se queda mirando algo viejo creyendo que es lo de ahora.

     El doble estrena un trámite a partir de la SEGUNDA lectura, que es lo
     único que distingue «se puso al día» de «no hizo nada»: las dos dejan
     la pantalla igual si no hay nada nuevo que traer.

     Va al final de la cadena a propósito. La guarda pide veinte segundos
     entre puestas al día, y aquí ya han pasado de sobra. */
  function alDiaAntes(){
    if (CASO !== 'vacio') return;
    var c2 = document.querySelector('.tcard[data-tr="c31"]');
    igual('al día: antes, el registro de inversión está por iniciar',
          c2 ? c2.getAttribute('data-st') : '(no hay tarjeta)', 'pendiente');
    /* Y el registro de marca, apagado: todavía no se puede solicitar.
       Son dos cosas distintas y hacen falta las dos: una SOLICITUD nueva se
       ve releyendo trámites, pero uno que el CIIP acaba de ENCENDER sólo se
       ve si además se tira la copia del catálogo, que se guarda una vez. */
    var cat0 = window.CIIP_TIPOS_POR_REF || {};
    igual('al día: y el registro de marca está apagado',
          !!(cat0.c8 && cat0.c8.activo), false);
  }

  function alDiaVuelve(){
    if (CASO !== 'vacio') return;
    /* Ahora sí hay algo nuevo que traer: el doble lo estrena cuando se le
       pide, y no por su cuenta. */
    window.CIIP_MENTIRA_TARDIO = true;
    /* Como cuando vuelves a la pestaña después de un rato. */
    document.dispatchEvent(new Event('visibilitychange'));
  }

  function alDiaDespues(){
    if (CASO !== 'vacio') return;
    var c2 = document.querySelector('.tcard[data-tr="c31"]');
    ok('al día: al volver a la pestaña aparece lo nuevo, sin recargar',
       !!c2 && c2.getAttribute('data-st') !== 'pendiente',
       c2 ? c2.getAttribute('data-st') : '(no hay tarjeta)',
       'algo distinto de pendiente');

    /* Y NO se recargó la página: si se hubiera recargado, el arnés habría
       empezado de cero y no estaríamos aquí. Se comprueba que sigue siendo
       la misma sesión de la tanda. */
    ok('al día: y sin recargar la página',
       typeof R !== 'undefined' && R.length > 0,
       (typeof R !== 'undefined' ? R.length : 0) + ' comprobaciones ya hechas',
       'la misma página');

    /* Y el CATÁLOGO también, que es la otra mitad y se olvida aparte: una
       solicitud nueva se ve releyendo trámites, pero uno que el CIIP acaba
       de encender sólo se ve si además se tira la copia guardada. */
    var cat = window.CIIP_TIPOS_POR_REF || {};
    igual('al día: y un trámite recién encendido ya se puede solicitar',
          !!(cat.c8 && cat.c8.activo), true);

      /* Y SU TARJETA VUELVE A LA PORTADA. Es la otra mitad de «lo apagado no
         se ve»: apagar la quita del documento, y encender tiene que
         devolverla, sin recargar y a su fase.

         Sin esta comprobación, quitarlas podría ser un viaje de ida —fuera
         para siempre hasta que alguien pulse F5— y en pantalla se vería
         igual de bien, porque nadie echa de menos lo que nunca estuvo. */
      var vuelta = document.querySelector('#trs-2 > .tcard[data-tr="c8"]');
      ok('al día: y su tarjeta vuelve a la portada, a su fase',
         !!vuelta, vuelta ? 'está' : 'no volvió', 'la tarjeta c8 en la fase 02');
      igual('al día: y la fase 02 vuelve a contar sus ocho',
            deEtapa(1, '.jcount'), '0 de 8 listos');
  }

  /* EL FRENO. Cambiar de pestaña y volver es lo que más se hace en una
     oficina; sin esto, cada ida y vuelta son dos consultas. Se mide justo
     después de una puesta al día, que es cuando tiene que decir que no. */
  function alDiaFreno(){
    if (CASO !== 'vacio' || !window.CIIP_AL_DIA) return;
    igual('al día: y no se repite a cada ida y vuelta',
          window.CIIP_AL_DIA(), false);
  }

  /* Y las dos guardas que impiden repintar por debajo de alguien.
     La función devuelve si hizo algo, que es lo que se mide. */
  /* LAS GUARDAS VAN PRIMERO EN LA CADENA, y el orden no es capricho: cada
     puesta al día rearma el freno de veinte segundos, así que probándolas
     DESPUÉS del refresco salían verdes por el freno y no por la guarda. Se
     vio quitándolas: la tanda seguía pasando.

     Aquí todavía no se ha refrescado nada y del arranque han pasado setenta
     segundos de sobra, así que lo único que puede decir «no» es la guarda
     que se está midiendo. Y decir «no» no gasta el turno: el reloj sólo se
     rearma cuando de verdad se pone al día. */
  function alDiaGuardas(){
    if (CASO !== 'vacio' || !window.CIIP_AL_DIA) return;

    var era = document.body.getAttribute('data-vista');
    document.body.setAttribute('data-vista', 'tramite');
    igual('al día: con un trámite abierto no se repinta por debajo',
          window.CIIP_AL_DIA(), false);
    if (era) document.body.setAttribute('data-vista', era);
    else document.body.removeAttribute('data-vista');

    document.body.classList.add('con-puerta');
    igual('al día: ni con una puerta abierta delante',
          window.CIIP_AL_DIA(), false);
    document.body.classList.remove('con-puerta');
  }

  /* ═══════════ EL RASTRO ═══════════
     No tenía NI UNA prueba, y por eso llegó a producción una pantalla que
     enseñaba los contadores y una tabla sin cabecera ni filas. Lo vio el
     CIIP el 3 de septiembre entrando por la dirección directa.

     Y no había error a la vista: pintaRastro se llamaba dentro de la cadena
     que carga, así que un fallo AL PINTAR lo cazaba el .catch del que CARGA,
     que lo degradaba a aviso, tiraba el historial de trámites culpando a los
     datos, y volvía a pintar. El propio código se comía la prueba del fallo.

     Lo que se sujeta aquí es lo que se veía roto: que la tabla tenga sus
     cinco títulos y una fila por apunte. */
  /* ═══════════ LO QUE CUESTA ABRIR UN TRAMITE ═══════════
     «Verifica que la velocidad de carga de la página sea la correcta en
     todos los trámites.» (CIIP)

     Se midió antes de escribir esto, con el doble contestando 100 ms tarde
     para que los viajes encadenados se pudieran ver en el reloj. Lo que
     salió: cada tarjeta hacía DOS viajes en fila, auth.getUser y detrás la
     consulta de la solicitud. El primero no servía para nada —quien decide
     qué filas se ven es RLS, en el servidor— y se pagaba entero, cada vez,
     también al volver a abrir la misma tarjeta.

     Aquí no se mide el reloj, y es a propósito: el doble contesta al
     instante y el navegador sin ventana lleva un reloj virtual que salta.
     Un número de milisegundos sería un adorno. Lo que sí es verdad y no
     depende de ninguna máquina es CUÁNTAS veces se sale a la red. */
  function velocidadArranque(){
    if (CASO !== 'vacio') return;
    if (VIAJES_ARRANQUE === null)
      return ok('velocidad: el doble cuenta los viajes', false,
                'no hay contador', 'window.CIIP_VIAJES');
    igual('velocidad: arrancar el panel no gasta ningún viaje en preguntar quién eres',
          VIAJES_ARRANQUE, 0);
  }

  function velocidadAbre(){
    if (CASO !== 'vacio' || !window.CIIP_VIAJES) return;
    location.hash = '';
    var V = window.CIIP_VIAJES;
    V.getUser = 0; V.consultas = 0; V.tablas.length = 0;
    location.hash = 'tramite-c31';
  }

  function velocidadMira(){
    if (CASO !== 'vacio' || !window.CIIP_VIAJES) return;
    var V = window.CIIP_VIAJES;

    /* ESTA PRIMERO, y sostiene a las demás: una tarjeta que no cargara
       nada tampoco preguntaría quién eres, y las tres de abajo saldrían
       verdes por no hacer nada. Aquí se comprueba que sí fue a buscar la
       solicitud, que es el viaje que de verdad hace falta. */
    ok('velocidad: abrir un trámite va a buscar la solicitud',
       V.tablas.indexOf('tramites') >= 0,
       V.tablas.join(' > ') || '(ningún viaje)', 'una consulta a tramites');

    igual('velocidad: y no gasta otro viaje en preguntar quién eres',
          V.getUser, 0);

    /* El catálogo se pide UNA vez y se guarda. Volver a pedirlo en cada
       tarjeta serían 33 viajes por una lista que no cambia. */
    ok('velocidad: y no vuelve a pedir el catálogo',
       V.tablas.indexOf('tipos_tramite') < 0,
       V.tablas.join(' > '), 'sin tipos_tramite');

    /* EL TECHO SE MIDE CONTRA LOS RECAUDOS, no contra un numero a mano.

       Antes eran tres y bastaba: abrir una tarjeta pintaba la ficha, y la
       ficha no pedia nada. Desde que se entra directo al formulario, abrir
       una tarjeta ES cargar el formulario, y el formulario pregunta por cada
       recaudo si ya lo tienes en la boveda para ofrecerte reusarlo. O sea
       que el numero crece con el tramite: uno de seis papeles pide mas que
       uno de dos, y eso es correcto.

       Lo que NO puede pasar es que pida DOS por papel, o que empiece a
       pedir cosas que no dependen de cuantos recaudos haya. Por eso el techo
       es «uno por recaudo, mas un par de sitio», y no una cifra fija que
       habria que subir cada vez que alguien añade un papel.

       Y lo que de verdad cuesta -si van en fila o en paralelo- no se mide
       aqui: el doble contesta al instante. Se midio aparte, con 100 ms de
       retardo por viaje, y van EN PARALELO: abrir una tarjeta paso de un
       salto encadenado a dos, no a siete. */
    var papeles = document.querySelectorAll("#trReal .sol-lado .sol-doc").length;
    var techo = papeles + 3;
    ok("velocidad: y no pide mas de una consulta por recaudo",
       V.consultas <= techo,
       V.consultas + " consultas para " + papeles + " recaudos: " + V.tablas.join(" > "),
       techo + " o menos");
  }

  function velocidadRepite(){
    if (CASO !== 'vacio' || !window.CIIP_VIAJES) return;
    location.hash = '';
    var V = window.CIIP_VIAJES;
    V.getUser = 0; V.tablas.length = 0;
    location.hash = 'tramite-c31';
  }

  function velocidadTrasRepetir(){
    if (CASO !== 'vacio' || !window.CIIP_VIAJES) return;
    var V = window.CIIP_VIAJES;
    ok('velocidad: y abrirlo otra vez sigue sin preguntar quién eres',
       V.getUser === 0 && V.tablas.indexOf('tramites') >= 0,
       'getUser=' + V.getUser + ', ' + (V.tablas.join(' > ') || '(nada)'),
       'cero getUser, y la solicitud sí');
    location.hash = '';
  }

  /* ═══════════ SIN CATALOGO NO SE ESCONDE NADA ═══════════
     Desde que lo apagado se quita de la portada, hay una linea que decide si
     se quita algo o no: la que se planta cuando el catalogo viene vacio.

     Y viene vacio mas a menudo de lo que parece. No hace falta que la base
     se caiga: basta con que la consulta salga antes de que la sesion este
     puesta, porque entonces las politicas contestan CERO FILAS y SIN ERROR.
     Es indistinguible de «no hay ningun tramite en el catalogo». Sin la
     guarda, eso significa apagarlos todos: la portada en blanco, sin una
     sola tarjeta, y sin nada en la consola que lo explique.

     Se prueba llamando a la funcion a mano y contando las tarjetas antes y
     despues. Montar una pasada entera del arnes para esto costaria doce
     segundos de reloj en cada tanda; esto cuesta dos lineas. */
  /* ═══════════ LA PORTADA VUELVE A SER EL INDICE ═══════════
     «Quedan abiertas al cambiar de panel y volver.» (CIIP)

     Las cuatro etapas se plegaban UNA vez, al cargar la pagina. En cuanto
     alguien desplegaba una, se quedaba desplegada para el resto de la
     sesion: se iba a la boveda, volvia, y la portada seguia siendo la lista
     larga en vez del indice de cuatro renglones.

     Y la otra mitad, que es la que hace que esto no sea molesto: volviendo
     de un TRAMITE no se pliega. Ahi se esta volviendo al mismo sitio con el
     boton de atras, y plegar le quitaria de debajo del cursor la tarjeta que
     acaba de mirar. Las dos se comprueban, porque arreglar la primera
     rompiendo la segunda se ve igual de bien en una captura. */
  function pliegaAbre(){
    if (CASO !== 'vacio') return;
    location.hash = '';
    var f = document.querySelector('.phase[data-fase="2"] .phase-h');
    if (f) f.click();
  }

  function pliegaMira(){
    if (CASO !== 'vacio') return;
    var f2 = document.querySelector('.phase[data-fase="2"]');
    ok('plegado: al pulsar la cabecera, la etapa se despliega',
       !!f2 && !f2.classList.contains('plegada'),
       f2 ? f2.className : '(no hay fase 02)', 'sin la clase plegada');
    /* A otra seccion. La boveda vale: es una vista entera y distinta. */
    location.hash = 'documentos';
  }

  function pliegaVuelve(){
    if (CASO !== 'vacio') return;
    location.hash = '';
  }

  function pliegaTrasVolver(){
    if (CASO !== 'vacio') return;
    var f2 = document.querySelector('.phase[data-fase="2"]');
    ok('plegado: y al volver de otra seccion, la portada vuelve a estar plegada',
       !!f2 && f2.classList.contains('plegada'),
       f2 ? f2.className : '(no hay fase 02)', 'con la clase plegada');
    /* Y ahora la otra mitad: se despliega, se abre un TRAMITE suyo y se
       vuelve. Eso no es cambiar de seccion, es el boton de atras.

       Se despliega SIN pulsar la cabecera, y a proposito: pulsando, esto era
       un interruptor. Si la comprobacion de arriba fallaba -si la etapa ya
       venia desplegada- el clic la PLEGABA, y el paso siguiente salia rojo
       arrastrado por este en vez de por lo suyo. Se vio saboteando: quitar el
       plegado ponia rojas las dos, y solo una de las dos lo era de verdad.
       Un rojo prestado cuesta mas de leer que uno propio. */
    if (window.CIIP_ABRE_FASE)
      window.CIIP_ABRE_FASE(document.querySelector('.phase[data-fase="2"]'));
  }

  function pliegaTramite(){
    if (CASO !== 'vacio') return;
    location.hash = 'tramite-c3';
  }

  function pliegaVuelveDeTramite(){
    if (CASO !== 'vacio') return;
    location.hash = '';
  }

  function pliegaTrasTramite(){
    if (CASO !== 'vacio') return;
    var f2 = document.querySelector('.phase[data-fase="2"]');
    ok('plegado: pero volviendo de un tramite se queda donde estabas',
       !!f2 && !f2.classList.contains('plegada'),
       f2 ? f2.className : '(no hay fase 02)', 'sin la clase plegada');
  }

  /* ═══════════ NINGUNA FICHA SE APAGA ENTERA ═══════════
     «Por que se ve mas opaco?» (CIIP, preguntado dos veces)

     Habia tres reglas que bajaban la opacidad de una ficha COMPLETA: el
     tramite que espera a otro al 72%, el activo reservado al 72% y el
     cerrado al 55%. Con la caja se apagaba tambien la letra, y eso es el
     gris volviendo por otro camino cuatro dias despues de haberlo quitado
     de todo el panel.

     Y con opacity no hay arreglo a medias: puesta en la caja, ningun hijo
     puede recuperar su tinta. O no se pone, o el texto se apaga.

     Lo que se mide es la opacidad CALCULADA, no que la regla no este
     escrita: da igual de donde venga -una clase nueva, un tema, algo
     heredado-; si una ficha con texto dentro se queda por debajo de 1, esto
     se pone rojo. Los botones desactivados no cuentan: apagarlos es la
     convencion de siempre y ahi no hay nada que leer. */
  function opacidadMira(){
    if (CASO !== 'lleno') return;
    var malas = [];
    document.querySelectorAll('.tcard, .ci-ficha, #mtCuerpo tr, #paCuerpo tr')
      .forEach(function(f){
        var o = parseFloat(getComputedStyle(f).opacity);
        if (!isNaN(o) && o < 1) malas.push((f.getAttribute('data-tr') || f.className || 'fila') + '=' + o);
      });
    ok('opacidad: ninguna ficha con texto se apaga entera',
       malas.length === 0, malas.join(', ') || 'ninguna', 'todas a 1');
  }

  /* Y la señal NO se pierde: el tramite que espera sigue diciendolo con
     letras. Sin esto, quitar la opacidad se cumpliria igual habiendo
     borrado tambien el aviso, y la ficha quedaria sin decir que no te toca. */
  /* Y LAS FICHAS DE ACTIVOS, que no estaban cubiertas y no se veia.

     La comprobacion de arriba corre en el expediente 'lleno', donde la vista
     de activos no esta pintada: no hay ni una .ci-ficha en el documento. Se
     descubrio saboteando -devolver el apagado del activo cerrado salia
     VERDE- y no mirando el codigo, porque desde fuera una comprobacion que
     recorre cero elementos y una que recorre veinte se ven igual.

     El activo cerrado solo existe en el expediente 'gestor', asi que esto va
     donde su vista esta abierta y no donde estaba lo demas. */
  function opacidadActivos(){
    var fichas = document.querySelectorAll('#acLista .ci-ficha');
    if (!fichas.length) return;

    var malas = [];
    [].forEach.call(fichas, function(f){
      var o = parseFloat(getComputedStyle(f).opacity);
      if (!isNaN(o) && o < 1) malas.push(f.className + '=' + o);
    });
    ok('opacidad: ninguna ficha de activos se apaga entera',
       malas.length === 0,
       malas.join(', ') || fichas.length + ' fichas, todas a 1', 'todas a 1');

    /* Y su estado se sigue diciendo con letras: cada ficha lleva su
       distintivo. Sin esto, quitar el apagado dejaria al reservado y al
       cerrado sin nada que los distinga del disponible. */
    var sinChip = [].filter.call(fichas, function(f){
      var ch = f.querySelector('.ct-chip');
      return !ch || !/\S/.test(ch.textContent);
    });
    igual('opacidad: y cada activo dice su estado con letras', sinChip.length, 0);
  }

  function opacidadSenal(){
    if (CASO !== 'lleno') return;
    var esperan = document.querySelectorAll('.tcard.espera');
    ok('opacidad: pero las que esperan siguen siendo las que esperan',
       esperan.length > 0, esperan.length + ' en espera', 'al menos una');
    if (!esperan.length) return;

    var t = esperan[0];
    var pie = t.querySelector('.t-time');
    /* Lo que decia con letras era el estimado. Apagado, la que espera y aun
       no has empezado no tiene nada que decir en ese renglon: lo que se
       mira entonces es que no quede el reloj con el icono solo. */
    if (window.CIIP_ESTIMADO_EN_FICHA){
      ok('opacidad: y lo dicen con letras, no solo apagandose',
         !!pie && /\S/.test(pie.textContent),
         pie ? '"' + pie.textContent.trim().slice(0, 40) + '"' : '(sin pie)',
         'el renglon de a quien espera');
    } else {
      ok('opacidad: y sin estimado el reloj no se queda con el icono solo',
         !!pie && (pie.hidden || /\S/.test(pie.textContent)),
         pie ? (pie.hidden ? 'escondido' : '"' + pie.textContent.trim().slice(0, 40) + '"') : '(sin pie)',
         'escondido, o con algo que decir');
    }

      /* Y LA PLACA TAMPOCO se atenua, que es lo contrario de lo que decia
         esta comprobacion hace un rato.

         El primer arreglo dejo el texto entero y bajo el logo del organismo
         al 45%, por no quedarse sin señal. La pregunta volvio igual: «ahora
         estos logos por que se ven opacos?», con el SAREN y el SENIAT medio
         borrados. Un logo a medio pintar no se lee como «esto todavia no te
         toca»; se lee como que la imagen no ha cargado.

         Asi que no se atenua nada, y lo que queda sujetando la señal es la
         comprobacion de aqui arriba: que lo diga con letras. */
      /* La placa dejo de ser una columna y es el recuadro de siempre; lo que
         se mide -que se vea entera y no a medio pintar- no cambia. */
      var marca = t.querySelector('.t-ico.placa') || t.querySelector('.t-ico');
      ok('opacidad: y la placa del organismo se ve entera, como en las demas',
         !!marca && parseFloat(getComputedStyle(marca).opacity) === 1,
         marca ? String(getComputedStyle(marca).opacity) : '(no hay placa)', '1');
  }

  /* ═══════════ EL AVISO DE VERSION NUEVA ═══════════
     «Uncaught ReferenceError: T is not defined, at avisa» (consola del CIIP,
     en produccion).

     El panel se pregunta cada minuto y medio si el archivo del que salio
     sigue siendo el mismo, y cuando cambia avisa para que quien tenga la
     pestaña abierta recargue. Ese aviso llamaba a T() -los textos- desde un
     bloque que NO ve a T: son dos bloques hermanos.

     Reventaba justo al hablar. O sea que el aviso no salia NUNCA y quien
     tuviera la pestaña abierta seguia mirando JavaScript viejo sin
     enterarse. Con tres personas conectadas, cada una con una version
     distinta y las diferencias achacadas al panel. Es exactamente lo que ese
     bloque existe para evitar.

     NO LO CAZABA NADIE, y eso es lo de fondo: el bloque se planta en su
     primera linea si el protocolo no es http, y la tanda corre sobre file:.
     Estaba entero fuera de alcance. Ahora se llama a mano. */
  function nuevaVersionMira(){
    if (CASO !== 'lleno' || !window.CIIP_AVISA_NUEVA) return;
    var caja = document.getElementById('nuevaV');
    if (!caja) return ok('version: hay donde avisar', false, 'no existe #nuevaV', 'la caja');

    var salto = null;
    try { window.CIIP_AVISA_NUEVA(); }
    catch(e){ salto = e && e.message; }
    ok('version: avisar de una version nueva no revienta',
       salto === null, salto || 'sin excepcion', 'sin excepcion');

    /* Y con los textos PUESTOS. Sin esto, un aviso que no lanzara pero
       dejara los tres huecos en blanco pasaria por bueno: una caja vacia
       avisando de nada. */
    var t = ['nuevaVtxt', 'nuevaVsi', 'nuevaVno'].map(function(id){
      var e = document.getElementById(id);
      return e ? e.textContent.trim() : '';
    });
    ok('version: y deja escritos los tres textos del aviso',
       t.every(function(x){ return x.length > 0; }),
       t.join(' / ') || '(los tres en blanco)', 'los tres con texto');

    ok('version: y la caja se ve', caja.classList.contains('se-ve'),
       caja.className, 'con la clase se-ve');

    /* Y SE CIERRA. Dejarla puesta tapaba media tanda: es una franja fija que
       se pone delante, asi que los pasos siguientes pulsaban sobre ella y
       cuarenta comprobaciones se pusieron rojas por un aviso abierto. Una
       prueba que deja la pantalla tocada no prueba una cosa: estropea las
       de despues. */
    caja.classList.remove("se-ve");
  }

  /* ═══════════ LOS DOS CUADROS, CUADRADOS ═══════════
     «Podemos verificar que todo este cuadrado tanto en esto como en las
     otras solicitudes?» (CIIP)

     Se midieron los TREINTA tramites que tienen formulario y los treinta
     salian a cero: el cuadro de los papeles empieza y acaba donde el de los
     datos, los 300 px de ancho son iguales en todos y ninguno se sale.

     Aqui se miran tres, no los treinta: cada uno cuesta setecientos
     milisegundos de reloj y la cadena ya va cargada. Se eligen los que
     rompen por sitios distintos -el formulario mas largo, el que mas
     papeles pide, y uno corto-, que es donde un alto mal puesto se nota
     antes que en el termino medio.

     Y se mide la CAJA de verdad, con getBoundingClientRect, no la regla de
     CSS: lo que hay que saber es si en pantalla acaban a la misma altura,
     no si alguien escribio align-items en algun sitio. */
  /* De los ENCENDIDOS en el expediente de pruebas. Puse c21 -que es corto- y
     salio rojo diciendo «sin datos, sin papeles»: no esta en el catalogo del
     doble, asi que no llega a pintar formulario. La prueba tenia razon y el
     equivocado era yo eligiendo. c17 es corto y si esta. */
  var CUADRA = ['c31', 'c13', 'c17'];
  var cuadraQueda = null;

  /* ═══════════ LA MIGAJA DICE DONDE ESTAS ═══════════
     «Necesito que cambie el nombre de mi panel al sitio seleccionado: ahí
     está Mis trámites y sale Mi expediente · Mi panel.» (CIIP)

     Estaba escrita a mano en el marcado, asi que anunciaba el panel
     estuvieras donde estuvieras. Con la barra lateral plegada es lo unico
     que dice en que pantalla estas, y decia otra cosa.

     Se comprueba contra el RENGLON ENCENDIDO y no contra una lista de
     nombres escrita aqui: si la prueba llevara su propia tabla, el dia que
     alguien añada una vista habria que acordarse de tres sitios en vez de
     dos. Lo que se mide es que los dos digan lo MISMO, que es la propiedad
     que importa; cual sea ese texto es cosa del diccionario. */
  /* ═══════════ QUE LO HAGA EL CIIP ═══════════
     «¿Podemos dar clic y que nos diga que nosotros podemos realizar la
     gestión por ti?» (CIIP)

     Debajo del formulario, y el boton no promete: ABRE LA CITA con este
     tramite ya elegido en el asunto. Un boton que dijera «nos encargamos» y
     no hiciera nada seria peor que no ponerlo, porque promete el CIIP y lo
     cumple nadie.

     Por eso lo que se mide no es que el texto este ahi -eso lo cumple
     cualquier cartel- sino que al pulsarlo pase algo y que ese algo lleve el
     tramite del que venias. */
  /* ═══════════ EL RENGLON DE «COMO SE HACE», PULSABLE ═══════════
     «Quiero que al comentario de 'se pide en el consulado' pueda darle clic
     y decirle al inversionista que el tramite lo puede realizar el CIIP.»

     Ese renglon es donde a alguien le aparece la pregunta -¿tengo que ir yo
     al consulado?- asi que es donde tiene que estar la respuesta.

     Lo que se mide no es que el texto exista: es que al pulsarlo se ABRA
     algo, que ese algo hable de que lo puede hacer el CIIP, y -esto es lo
     que se rompio al montarlo- que el clic NO abra el tramite entero. Un
     control dentro de otro control se lleva el clic si nadie lo para. */
  /* ═══════════ LA ESCALERA DE MUESTRA NO PARPADEA ═══════════
     «¿Por que al darle clic a la plantilla me sale esto un segundo?» (CIIP,
     con «El proceso» y sus cuatro pasos delante).

     Esos cuatro pasos son de MUESTRA: los enseña un tramite que todavia no
     esta hecho. Se pintaban nada mas pulsar y se quitaban al llegar los
     datos; mientras habia una ficha por delante eso era un parpadeo, pero
     desde que se entra directo al formulario hay dos consultas por medio y
     dio tiempo a leerlos.

     Contar algo falso durante un segundo y luego cambiarlo es peor que no
     contar nada, y aqui lo falso era nada menos que «este tramite todavia no
     esta hecho» sobre uno que si lo esta.

     Se miran las DOS mitades: en un tramite encendido la escalera no llega a
     salir, y en uno apagado si sale. Sin la segunda, esconderla siempre
     pasaria por bueno y los que de verdad son maqueta se quedarian mudos. */
  function escaleraNoParpadea(){
    if (CASO !== 'vacio') return;
    var esc = document.getElementById('trProceso');
    ok('parpadeo: en un tramite encendido no se enseña la escalera de muestra',
       !!esc && esc.classList.contains('oculto'),
       esc ? esc.className : '(no hay escalera)', 'oculta');

    /* Y la cabecera SI esta puesta: si no, el hueco de la espera seria una
       pantalla en blanco, que tampoco vale. */
    var nom = document.getElementById('trNombre');
    ok('parpadeo: pero la cabecera del tramite si esta',
       !!nom && /\S/.test(nom.textContent),
       nom ? nom.textContent.trim().slice(0, 34) : '(vacia)', 'su nombre');
  }

  function escaleraApagadoAbre(){
    if (CASO !== 'vacio') return;
    location.hash = 'tramite-c33';
  }

  function escaleraApagadoMira(){
    if (CASO !== 'vacio') return;
    var esc = document.getElementById('trProceso');
    ok('parpadeo: y en uno que aun no esta hecho, si se enseña',
       !!esc && !esc.classList.contains('oculto'),
       esc ? esc.className : '(no hay escalera)', 'a la vista');
    location.hash = '';
  }

  function loHacemosMira(){
    if (CASO !== 'vacio') return;
    /* Cuelga de «Ver detalles» y ya no del renglón del reloj. El reloj no
       parecía pulsable —era un texto con un icono al lado— así que había que
       descubrirlo por casualidad; «Ver detalles» es donde alguien busca
       justamente eso, y lo llevan las treinta y tres fichas igual. */
    var pie = document.querySelector('.tcard[data-tr="c1"] .t-foot .go[data-globo]');
    ok('lo hacemos: «Ver detalles» se puede pulsar',
       !!pie, pie ? 'pulsable' : 'no lleva globo', 'con su globo');

    /* ── EL PLAZO LEGAL, EN EL RELOJ ──
       El reloj dice el estimado; al pulsarlo sale lo que dice la norma.
       Son datos distintos y por eso van separados: el estimado no obliga
       a nadie, y el legal no describe lo que pasa.

       SOLO donde hay norma leída. Hoy dos de treinta y tres, y por eso se
       comprueban las DOS caras: que la c1 -que la tiene- lo lleva, y que
       una sin ella NO lo lleva. Sin la segunda, esto pasaría igual con un
       globo colgado de las treinta y tres prometiendo un dato que no hay.

       Y que se VEA pulsable, que es por lo que se quitó de aquí la vez
       anterior: el reloj era texto con un icono y había que dar con él de
       casualidad. Se mide el subrayado, no la clase: la clase se puede
       poner sin que pinte nada. */
    (function(){
      /* ── Y AHORA MISMO ESTÁ APAGADO ──
         Decisión del CIIP: que «Los plazos de este trámite» no salga, por
         ahora. El panel lo apaga con un interruptor y NO borra el bloque,
         así que estas pruebas hacen lo mismo: siguen al interruptor.

         Leerlo y no adivinarlo es lo importante. Mirar sólo si algún reloj
         lleva globo no distingue «apagado a propósito» de «roto», y las dos
         salidas fáciles son malas: dejarlas rojas convierte una decisión en
         un fallo, y borrarlas deja sin nada que se ponga rojo el día que el
         interruptor vuelva a true y el globo no aparezca. */
      var reloj = document.querySelector('.tcard[data-tr="c1"] .t-time[data-globo]');

      if (!window.CIIP_GLOBO_DE_PLAZOS){
        /* Se mira el SUBRAYADO y el papel de botón, no el cursor: la ficha
           entera se pulsa y lleva su cursor de mano, así que ahí el reloj
           apagado y el encendido se ven igual. */
        var c1 = document.querySelector('.tcard[data-tr="c1"] .t-time');
        var deco = c1 ? window.getComputedStyle(c1).textDecorationLine : '?';
        ok('plazo legal: apagado, el reloj de la c1 es texto y ya',
           !!c1 && !reloj && !c1.getAttribute('role') && !c1.hasAttribute('tabindex') &&
           deco.indexOf('underline') < 0,
           c1 ? (reloj ? 'lleva globo'
                       : 'papel=' + (c1.getAttribute('role') || 'ninguno') +
                         ' subrayado=' + deco)
              : '(no hay reloj)',
           'sin globo, sin papel de botón y sin subrayado');
        return;
      }

      ok('plazo legal: el reloj de la c1 se puede pulsar',
         !!reloj, reloj ? 'con globo' : 'sin globo', 'con su globo');

      if (reloj){
        var e = window.getComputedStyle(reloj);
        ok('plazo legal: y se nota que se puede pulsar',
           e.cursor === 'pointer' && e.textDecorationLine.indexOf('underline') >= 0,
           'cursor=' + e.cursor + ' subrayado=' + e.textDecorationLine,
           'pointer y subrayado');
      }

      /* ── Y ABIERTO, LA FICHA SE PONE POR DELANTE ──
         Pasó y se vio en pantalla: el globo del reloj sale hacia la
         izquierda, se mete en la columna vecina, y la ficha de al lado se
         dibujaba encima. El globo quedaba cortado por la mitad.

         LO QUE ESTA PRUEBA NO HACE, y conviene decirlo: no comprueba que
         el globo se vea. Se intentó, midiendo con elementFromPoint quién
         está delante en un punto de dentro del globo, y esa prueba pasaba
         con el arreglo Y SIN ÉL: en la ventana del arnés ese solape no
         llega a ocurrir. Se comprobó quitando los dos arreglos, uno por
         uno, y salió verde las dos veces. Una prueba que no puede
         ponerse roja no protege nada, así que se quitó.

         Lo que sí se sujeta es que la REGLA se aplique: con el globo
         abierto la ficha es su propio contexto de apilado, y al cerrarlo
         deja de serlo. Eso sí se pone rojo si alguien quita la regla, y
         es la mitad del arreglo que se puede comprobar sin ojos. */
      if (reloj){
        var ficha = reloj.closest('.tcard');
        var antes = ficha ? window.getComputedStyle(ficha).zIndex : '?';
        reloj.click();
        var durante = ficha ? window.getComputedStyle(ficha).zIndex : '?';
        reloj.click();
        var luego = ficha ? window.getComputedStyle(ficha).zIndex : '?';

        ok('plazo legal: con el globo abierto la ficha se pone por delante',
           durante !== 'auto' && parseInt(durante, 10) > 0,
           'cerrada=' + antes + '  abierta=' + durante,
           'un z-index por encima de cero');
        /* Y vuelve. Una ficha elevada para siempre se come la sombra de
           las de al lado y le gana a cualquier cosa que se ponga encima
           mañana. */
        ok('plazo legal: y al cerrarlo vuelve a su sitio',
           luego === antes,
           'antes=' + antes + '  después=' + luego,
           'como estaba');
      }

      /* Una sin norma leída: su reloj se queda como estaba.
         LA c13, y elegirla tiene su historia de dos pasos. Primero fue la
         c4, que NO está en el catálogo: su reloj se quedaba mudo porque no
         hay ficha que mirar, no porque falte el dato, y la prueba pasaba
         igual con el panel roto. Luego la c5, que sí está y no tiene norma
         leída; valió hasta que el globo pasó a salir también donde sólo
         hay días del CIIP, y la c5 tiene 21. La c13 no tiene ninguno de
         los dos, que es el único caso que de verdad no promete nada. */
      var mudo = document.querySelector('.tcard[data-tr="c13"] .t-time');
      ok('plazo legal: y sin norma leída el reloj no promete nada',
         !!mudo && !mudo.getAttribute('data-globo'),
         mudo ? (mudo.getAttribute('data-globo') ? 'lleva globo' : 'texto y ya') : '(no hay c4)',
         'texto y ya');
    })();

    /* ── QUE EL CIIP TE ACOMPAÑA, EN TODAS ──
       El CIIP lo pidió así: siempre y sin abrir nada. Se cuenta contra el
       número de fichas y no contra un número escrito: el catálogo crece.
       Y se mira el TEXTO, no que exista el hueco: un renglón vacío está
       igual de presente y no dice nada. */
    (function(){
      /* Las que son TRÁMITE. En el camino hay una que no lo es —el banco
         de activos: se mira, no se solicita— y ofrecerle acompañamiento
         para «realizar este trámite» sería ofrecer algo que no existe.
         Se descarta con LA LISTA DEL PANEL, no con una copia: el día que
         entre otra ficha de mirar, una copia se quedaría vieja y esta
         prueba pediría acompañamiento para algo que no se pide. */
      var noSon = window.CIIP_NO_ES_TRAMITE || [];
      var fichas = [].filter.call(
        document.querySelectorAll('.tcard[data-tr]'),
        function(c){ return noSon.indexOf(c.getAttribute('data-tr')) < 0; });
      var mudas = [];
      [].forEach.call(fichas, function(c){
        var x = c.querySelector('.t-acomp');
        if (!x || !(x.textContent || '').trim()) mudas.push(c.getAttribute('data-tr'));
      });
      /* Se nombran las que faltan, no se cuentan: «31 de 32» obliga a
         salir a buscar cuál, y eso son diez minutos cada vez. */
      ok('acompaña: las fichas dicen que el CIIP puede acompañarte',
         fichas.length > 0 && mudas.length === 0,
         mudas.length ? ('callan: ' + mudas.join(', ')) : (fichas.length + ' fichas'),
         'todas');

      /* Y va LO ÚLTIMO del cuerpo, detrás de la descripción. Estuvo
         debajo del organismo y el CIIP lo movió: ahí se colaba entre el
         nombre del ente y la descripción del trámite, que se leen
         seguidas. Esto no describe el trámite, se ofrece después de
         haberlo entendido.
         Se compara la posición real en el documento, no la clase del
         hermano: con compareDocumentPosition da igual cuántas cosas se
         metan en medio mañana. */
      var fuera = [];
      fichas.forEach(function(c){
        var acomp = c.querySelector('.t-acomp');
        var desc  = c.querySelector('.t-desc');
        if (!acomp || !desc) return;          /* sin descripción no hay orden que comprobar */
        var despues = (desc.compareDocumentPosition(acomp) &
                       Node.DOCUMENT_POSITION_FOLLOWING) !== 0;
        if (!despues) fuera.push(c.getAttribute('data-tr'));
      });
      ok('acompaña: y va detrás de la descripción, no antes',
         fuera.length === 0,
         fuera.length ? ('antes en: ' + fuera.join(', ')) : 'todas detrás',
         'todas detrás');
    })();

    /* Y SE VE que se puede pulsar. Esto no es cosmética: cuando el globo se
       mudó del reloj al enlace, la regla que lo vestía se quedó apuntando al
       reloj, y «Ver detalles» pasó a abrir un globo sin ninguna señal de que
       hiciera nada. Encima, al recibir el foco le salía el recuadro azul de
       fábrica del navegador, que parecía un fallo. Nada de eso rompió una
       sola prueba: todas miraban que el globo se abriera, no que se notara
       que hay algo que pulsar. */
    if (pie){
      var cs = window.getComputedStyle(pie);
      igual('lo hacemos: el enlace se ve pulsable', cs.cursor, 'pointer');
      ok('lo hacemos: y lleva su señal de que abre algo',
         cs.textDecorationLine !== 'none' && /\S/.test(cs.textDecorationStyle),
         cs.textDecorationLine + ' ' + cs.textDecorationStyle, 'algún subrayado');
    }

    /* AQUÍ DECÍA QUE EL RELOJ NO ABRE NADA, Y AHORA SÍ ABRE.
       No es que la prueba estuviera mal: aquel globo se quitó del reloj
       porque duplicaba éste —dos sitios para lo mismo— y porque el reloj
       no parecía pulsable. Lo que abre ahora es OTRA COSA: lo que dice la
       norma sobre el plazo, que no está en ningún otro sitio. Y va vestido
       de pulsable, que era la otra mitad de aquella queja.
       Que sean dos cosas distintas y no la misma dos veces lo sujetan las
       pruebas de «plazo legal», más arriba. */
    if (!pie) return;

    /* EL GLOBO DE ESTE ENLACE, no el primero del pie. Desde que el reloj
       tiene el suyo hay DOS en la misma caja, y pie.parentNode.querySelector
       devolvía el del reloj: se pulsaba «Ver detalles» y esta prueba miraba
       si se había abierto el otro, que seguía cerrado. Tres pruebas en rojo
       sin que el panel tuviera nada malo.
       Es la misma trampa que ocultó Trazabilidad: un selector que ayer
       encontraba una cosa y hoy encuentra dos. Se ata al hermano siguiente,
       que es donde el panel lo inserta. */
    var caja = pie.nextElementSibling &&
               pie.nextElementSibling.querySelector('.pista-caja');
    igual('lo hacemos: y llega cerrado', !!caja && caja.hidden, true);

    var vista = document.body.getAttribute('data-vista');
    pie.click();

    ok('lo hacemos: al pulsarlo se abre', !!caja && !caja.hidden,
       caja ? ('oculto=' + caja.hidden) : '(no hay globo)', 'abierto');
    /* Lo que cuenta son LOS PASOS del trámite —los mismos de pasos.js que
       la ficha enseña bajo «El proceso»—, no un texto escrito aparte. Se
       comprueba contra el diccionario y no contra una frase copiada aquí:
       copiada, esta prueba se rompería cada vez que el CIIP retoque una
       palabra, y peor, pasaría a medir la copia en vez de lo que hay. */
    var Dp = (window.CIIP_PASOS && window.CIIP_PASOS.pasos) || {};
    var suyos = (Dp[curLang] || Dp.en || {})['c1'] || [];
    ok('lo hacemos: y cuenta los pasos del trámite, no un texto aparte',
       suyos.length > 0 && caja &&
         suyos.every(function(p){ return caja.textContent.indexOf(p) >= 0; }),
       caja ? caja.textContent.trim().slice(0, 60) : '(vacio)',
       suyos.length + ' pasos del trámite');

    /* Y al final, aparte de la lista, lo que estaba en el reloj: que el CIIP
       puede llevarlo contigo. APARTE y no como una viñeta más, que dentro de
       la lista se leía como un quinto paso. */
    var suelta = caja && caja.querySelector('.pc-ciip');
    ok('lo hacemos: y que el CIIP puede hacerlo contigo, separado de los pasos',
       !!suelta && /CIIP/.test(suelta.textContent),
       suelta ? suelta.textContent.slice(0, 50) : '(no esta aparte)',
       'fuera de la lista de pasos');

    /* Y lo dice CONTIGO, no POR TI. No es matiz de redacción: «por ti» suena
       a delegar y desentenderse, y no es verdad —hay papeles que solo puede
       firmar el inversionista—. Prometer lo primero hace que alguien se
       lleve la sorpresa a mitad de camino, que es cuando peor sienta.

       Se mira en el diccionario y no en la pantalla: el pase corre en un
       idioma y esto tiene que valer para los seis. */
    /* Aquí NO se comprueba la frase palabra por palabra, y es a propósito.
       Esta línea ya se ha reescrito tres veces —«por ti», «contigo»,
       «acompañarte»— y cada vez que el CIIP la afina, una prueba que llevara
       la copia dentro se pondría roja sin que nada estuviera mal. Peor: la
       forma rápida de arreglarla es pegar la frase nueva, y entonces la
       prueba mide su propia copia y ya no protege nada.

       Lo que sí se sujeta es lo que la decisión significa: que existe en los
       seis, y que en ninguno se promete hacerlo POR TI —esa promesa es falsa,
       hay papeles que solo puede firmar el inversionista, y descubrirlo a
       mitad de camino es la peor forma de enterarse—. */
    var D = (window.CIIP_PASOS && window.CIIP_PASOS.ui) || {};
    var sin = Object.keys(D).filter(function(l){
      return !/\S/.test(String((D[l] || {}).lh_uno || ''));
    });
    ok('lo hacemos: la frase está escrita en los seis idiomas',
       Object.keys(D).length === 6 && sin.length === 0,
       sin.length ? ('faltan en: ' + sin.join(', ')) : (Object.keys(D).length + ' idiomas'),
       'los seis');

    /* Y ninguna de las otras cinco se quedó con la promesa de antes. Cambiar
       solo el español es la forma silenciosa de que un inversionista italiano
       siga leyendo algo que ya no decimos. */
    var promete = Object.keys(D).filter(function(l){
      return /por ti|for you|por si|per te|за вас|为您代办/.test(String((D[l] || {}).lh_uno || ''));
    });
    ok('lo hacemos: y en ningún idioma se quedó el «por ti»',
       promete.length === 0, promete.length ? promete.join(', ') : 'ninguno', 'ninguno');

    /* ── Y SIGUE AL IDIOMA DEL PANEL ──
       Este globo se monta con la tarjeta y una guarda impide rehacerlo, asi
       que su texto se quedaba congelado en el idioma que hubiera en ese
       momento. applyLang repinta a mano las piezas sin data-i18n -los pasos,
       las etapas, los avisos- y los globos no estaban en la lista:
       el panel entero pasaba a italiano y este seguia en español. Se vio en
       una pantalla, no aqui: ninguna prueba miraba en QUE idioma habla algo
       que ya estaba pintado. */
    (function(){
      var era = curLang;
      applyLang('it');
      /* Se cierra y se vuelve a abrir, que es lo que hace una persona. */
      pie.click(); pie.click();
      var d = ((window.CIIP_PASOS || {}).ui || {}).it || {};
      var ahora = caja ? caja.textContent : '';
      ok('lo hacemos: y habla en el idioma del panel, no en el de cuando se montó',
         !!d.lh_uno && ahora.indexOf(d.lh_uno) >= 0,
         ahora.trim().slice(0, 60), (d.lh_uno || '').slice(0, 60));
      applyLang(era || 'es');
      pie.click(); pie.click();
    })();

    /* Y NO se ha abierto el tramite: el clic se queda en el renglon. */
    igual('lo hacemos: y no se lleva por delante la tarjeta',
          document.body.getAttribute('data-vista'), vista);

    pie.click();
  }


  /* ── HABLAR CON EL CIIP SIN PEDIR CITA ────────────────────────────────────
     La cita era la unica puerta. Estas miden la otra: que se abre, que se
     ve lo que ya hay, que se puede escribir una nueva, y que lo escrito
     llega. Corren sobre el inversionista; la parte del equipo va aparte. */
  /* ── EL CATALOGO DEL ADMIN, Y SUS DIAS ──
     De los tres numeros que puede llevar un tramite, el de «lo que suele
     tardar» es el unico que el CIIP puede afirmar: lo ve pasar. El legal
     lo dice la norma y la vigencia la Gaceta. Hasta ahora no habia forma
     de tocarlo sin entrar a la base.

     Solo el admin: la pantalla es suya y la politica de la base tambien.
     En las demas pasadas estas cuatro no hacen nada. */
  function catalogoAbre(){
    if (!ES_ADMIN) return;
    location.hash = "catalogo";
  }

  /* Se ESPERA a que la lista llegue. La primera version miraba en la
     misma vuelta y contaba cero filas: el catalogo lo pide el enrutador
     al entrar y eso es un viaje a la base. Contar cero y darlo por bueno
     habria sido una prueba que pasa con la pantalla vacia. */
  function catalogoEspera(sigue){
    if (!ES_ADMIN) return sigue();
    /* Y hay que ABRIR una fase. La lista nace con las cuatro plegadas, y
       una fase plegada no pinta sus filas: no las esconde, no las crea.
       La primera version esperaba filas que no iban a llegar nunca y
       contaba cero. */
    esperaFilas("#cgLista .cg-fase", 1, function(){
      var cab = document.querySelector("#cgLista .cg-fase");
      if (cab && cab.getAttribute("aria-expanded") !== "true") cab.click();
      esperaFilas("#cgLista .cg-fila", 1, sigue);
    });
  }

  function catalogoMira(){
    if (!ES_ADMIN) return;
    igual("catalogo: se abre la vista", document.body.getAttribute("data-vista"), "catalogo");
    var filas = document.querySelectorAll("#cgLista .cg-fila");
    ok("catalogo: y lista los tramites", filas.length > 0,
       filas.length + " filas", "alguna");

    /* El campo va en TODAS, tambien en las que hoy no tienen numero: es
       donde se pone el primero. Si solo saliera donde ya hay dato, no
       habria manera de estrenar uno. */
    var sin = [];
    [].forEach.call(filas, function(f){
      if (!f.querySelector(".cg-plazo-n")) sin.push((f.querySelector(".cg-nombre") || {}).textContent || "?");
    });
    ok("catalogo: todas las filas dejan poner los dias",
       filas.length > 0 && sin.length === 0,
       sin.length ? ("sin campo: " + sin.slice(0, 3).join(", ")) : (filas.length + " filas"),
       "todas");
  }

  /* Se escribe un numero y se sale del campo, que es como se guarda: al
     salir y no en cada tecla. Escribiendo «21» se pasa por «2», y guardar
     el 2 dejaria el dato mal un instante y una escritura de mas por cada
     digito. */
  /* LA FILA DEL c1 y no la primera que caiga: hace falta que sea una
     ficha con globo en el reloj para poder ir a mirarla despues, y la del
     c1 lo tiene. Se busca por data-cg -el ref del panel- y no por su
     nombre, que se traduce y se retoca. */
  var CAT_ANTES = null;
  function catalogoGuarda(){
    if (!ES_ADMIN) return;
    var campo = document.querySelector('#cgLista .cg-fila[data-cg="c1"] .cg-plazo-n');
    ok("catalogo: la fila dice de que ficha es", !!campo,
       campo ? "c1 localizada" : "no encontre la fila del c1", "con su data-cg");
    if (!campo) return;
    CAT_ANTES = campo.value;
    campo.value = "77";
    campo.dispatchEvent(new Event("change", {bubbles:true}));
  }

  function catalogoTrasGuardar(){
    if (!ES_ADMIN) return;
    var campo = document.querySelector("#cgLista .cg-fila .cg-plazo-n");
    ok("catalogo: el numero se guarda y vuelve de la base",
       !!campo && campo.value === "77",
       campo ? ("dice " + campo.value) : "(no hay campo)", "77");

    /* Y LO QUE DE VERDAD IMPORTA: que se note en la ficha. Sin esto, el
       admin cambia el numero, la base lo guarda, y la portada sigue
       diciendo lo de antes hasta que alguien recargue. Es el mismo olvido
       que ya tuvo el interruptor de encender un tramite. */
    ok("catalogo: y el panel se entera, sin recargar",
       typeof window.CIIP_OLVIDA_CATALOGO === "function",
       typeof window.CIIP_OLVIDA_CATALOGO, "una funcion que tira la copia");

    location.hash = "";
  }

  /* Y AHORA LO QUE DE VERDAD SE PEDIA: que se vea en la ficha.

     Entre «la base lo guardo» y «la persona lo ve» hay tres cosas que
     pueden fallar, y una fallaba: el globo del reloj se monta UNA vez y
     se quedaba con el catalogo de aquel momento, asi que seguia diciendo
     el numero viejo hasta recargar la pagina. Ahora lo relee al abrirse.

     Se espera a que la portada vuelva: el cambio de vista es asincrono y
     mirar en la misma vuelta mide la pantalla anterior. */
  function catalogoVuelveEspera(sigue){
    if (!ES_ADMIN) return sigue();
    esperaFilas('.tcard[data-tr="c1"] .t-time', 1, sigue);
  }

  function catalogoSeVeEnLaFicha(){
    if (!ES_ADMIN) return;
    /* El globo del reloj es el UNICO sitio donde ese numero se ve, y ahora
       mismo esta apagado por decision del CIIP. Sin globo no hay nada que
       mirar: comprobar aqui otra cosa seria inventarse una pantalla. Lo de
       arriba -que la base lo guarda y que el panel tira su copia- sigue
       comprobandose igual, y esto vuelve solo cuando vuelva el globo. */
    if (!window.CIIP_GLOBO_DE_PLAZOS) return;
    var reloj = document.querySelector('.tcard[data-tr="c1"] .t-time[data-globo]');
    if (!reloj){
      ok("catalogo: el numero nuevo llega a la ficha", false,
         "el reloj de la c1 no abre nada", "con su globo");
      return;
    }
    var cab = document.querySelector('.phase-h[aria-controls="trs-1"]');
    var estabaAbierta = cab && cab.getAttribute("aria-expanded") === "true";
    if (cab && !estabaAbierta) cab.click();

    reloj.click();
    var glob = reloj.nextElementSibling &&
               reloj.nextElementSibling.querySelector(".pista-caja");
    var dice = glob ? (glob.textContent || "") : "";
    ok("catalogo: el numero nuevo llega a la ficha",
       dice.indexOf("77") >= 0,
       dice.replace(/\s+/g, " ").trim().slice(0, 90) || "(el globo no dijo nada)",
       "el globo dice 77");
    reloj.click();
    if (cab && !estabaAbierta) cab.click();
  }

  /* Y se devuelve el catalogo como estaba. Una prueba que lo cambia y no
     lo deja igual le mueve el suelo a las de despues. */
  function catalogoDeshace(){
    if (!ES_ADMIN || CAT_ANTES === null) return;
    location.hash = "catalogo";
  }

  function catalogoDeshaceEspera(sigue){
    if (!ES_ADMIN || CAT_ANTES === null) return sigue();
    esperaFilas("#cgLista .cg-fase", 1, function(){
      var c = document.querySelector("#cgLista .cg-fase");
      if (c && c.getAttribute("aria-expanded") !== "true") c.click();
      esperaFilas('#cgLista .cg-fila[data-cg="c1"] .cg-plazo-n', 1, sigue);
    });
  }

  function catalogoDeshacePonlo(){
    if (!ES_ADMIN || CAT_ANTES === null) return;
    var campo = document.querySelector('#cgLista .cg-fila[data-cg="c1"] .cg-plazo-n');
    if (campo){
      campo.value = CAT_ANTES;
      campo.dispatchEvent(new Event("change", {bubbles:true}));
    }
    location.hash = "";
  }

  function consultaAbre(){
    if (CASO === 'gestor') return;
    if (window.CIIP_ABRE_CONSULTA) window.CIIP_ABRE_CONSULTA();
  }

  function consultaMira(){
    if (CASO === 'gestor') return;
    var back = document.getElementById('consBack');
    ok('consulta: la ventana se abre',
       !!back && back.classList.contains('open'),
       back ? back.className : '(no hay ventana)', 'abierta');
    if (!back) return;

    /* LA LINEA HONRADA. Es la que separa esto de un chat: un chat promete
       que hay alguien AHORA, y el equipo del CIIP no esta las veinticuatro
       horas. Sin esta frase, quien escribe un domingo se encuentra el
       silencio y concluye que la ventanilla no funciona. Que este puesta es
       parte de lo que la funcion hace, no decoracion. */
    var sub = document.getElementById('consSub');
    ok('consulta: y dice cuando responde el equipo, que no es un chat en vivo',
       !!sub && /\S/.test(sub.textContent),
       sub ? sub.textContent : '(no hay)', 'una frase sobre cuando se responde');

    /* DOS: las dos tuyas del ejemplo. La tercera es de otra persona y no
       puede salir aqui —eso es lo que hace la RLS, y el doble la imita—.
       Y una de las dos esta RESUELTA: tu lista son todas, no solo las
       vivas, que es justo lo contrario de la cola del equipo. Si el filtro
       de "solo las mias" desapareciera, esto pasaria a tres. */
    var suyas = document.querySelectorAll('#consCuerpo .cons-i');
    igual('consulta: salen las tuyas, resueltas incluidas', suyas.length, 2);

    /* Y dicho al reves, que es lo que de verdad importa: la de otra persona
       NO esta. Contar dos se cumpliria igual enseñando la ajena y
       escondiendo una tuya. */
    var textos = [].map.call(suyas, function(x){ return x.textContent; }).join(' | ');
    ok('consulta: y ninguna de otra persona',
       textos.indexOf('visa para constituir') < 0,
       textos.slice(0, 70), 'sin la de otro');

    /* Y con su estado a la vista. Sin el, una lista de tres es tres
       renglones iguales y no se sabe cual espera respuesta. */
    var conEstado = 0;
    [].forEach.call(suyas, function(x){
      var e = x.querySelector('.cons-est');
      if (e && /\S/.test(e.textContent)) conEstado++;
    });
    igual('consulta: cada una dice en que estado esta', conEstado, suyas.length);
  }

  function consultaEntra(){
    if (CASO === 'gestor') return;
    var uno = document.querySelector('#consCuerpo .cons-i');
    if (uno) uno.click();
  }

  function consultaDentro(){
    if (CASO === 'gestor') return;
    /* La conversacion, con la MISMA funcion que el expediente y la cita. */
    var hilo = document.querySelector('#consCuerpo .hilo');
    ok('consulta: dentro esta la conversacion',
       !!hilo, hilo ? 'esta' : '(no hay hilo)', 'el hilo');
    if (!hilo) return;

    var dichos = hilo.querySelectorAll('.hilo-m');
    igual('consulta: con lo que ya se hablo', dichos.length, 2);

    /* Y se distingue quien habla. Es la mitad de lo que hace un hilo: sin
       esto son dos parrafos seguidos y no una conversacion. */
    var mio = hilo.querySelector('.hilo-m.mio'), suyo = hilo.querySelector('.hilo-m.suyo');
    ok('consulta: y se ve quien dijo cada cosa',
       !!mio && !!suyo,
       (mio ? 'tuyo ' : '') + (suyo ? 'del CIIP' : ''), 'los dos');
  }

  /* ── LOS ROTULOS TIENEN LETRA ─────────────────────────────────────────────
     Esta nace de un fallo que ninguna de las cuatro mil pruebas veia. El
     panel tiene DOS diccionarios -el I18N de la pagina y el CIIP_PASOS.ui de
     pasos.js- y T() devolvia solo el segundo. pintaHilo pide sus rotulos con
     u['hilo.t'], u['hilo.env']... y esas claves viven en el primero: no
     resolvia ninguna. La conversacion salia con el titulo en blanco, el
     boton de enviar en blanco y la caja sin placeholder.

     Nadie lo vio porque ninguna prueba miraba que un rotulo TUVIERA LETRA, y
     el comprobador de claves tampoco: escanea el texto del archivo, ve
     escrito 'hilo.t' y da la clave por usada sin mirar de que diccionario se
     lee. Un boton vacio pasa todos los selectores del mundo. */
  function rotulosMiran(){
    if (CASO === 'gestor') return;
    var hilo = document.querySelector('#consCuerpo .hilo');
    if (!hilo) { ok('rotulos: hay un hilo que mirar', false, '(no hay)', 'un hilo'); return; }

    var caso = [
      ['el titulo de la conversacion', hilo.querySelector('.sol-h')],
      ['el boton de enviar',           hilo.querySelector('.btn.navy')],
      ['el de adjuntar',               hilo.querySelector('.hilo-clip')]
    ];
    caso.forEach(function(c){
      var e = c[1];
      ok('rotulos: ' + c[0] + ' tiene letra',
         !!e && /\S/.test(e.textContent),
         e ? ('"' + e.textContent + '"') : '(no esta)', 'algo escrito');
    });

    var caja = hilo.querySelector('.hilo-txt');
    ok('rotulos: y la caja de escribir dice que poner',
       !!caja && /\S/.test(caja.placeholder || ''),
       caja ? ('"' + (caja.placeholder || '') + '"') : '(no esta)', 'algo escrito');

    /* Y la ventana entera, no solo el hilo: el mismo agujero se llevaba por
       delante el titulo y el boton de abrir una nueva. */
    var t = document.getElementById('consTitulo');
    ok('rotulos: la ventana de la consulta tiene titulo',
       !!t && /\S/.test(t.textContent),
       t ? ('"' + t.textContent + '"') : '(no esta)', 'algo escrito');
  }

  function consultaNueva(){
    if (CASO === 'gestor') return;
    var v = document.querySelector('#consCuerpo .cons-volver');
    if (v) v.click();
  }

  function consultaNuevaMira(){
    if (CASO === 'gestor') return;
    /* Se vuelve a la lista, y de ahi al formulario. */
    var b = document.querySelector('#consCuerpo .btn.navy');
    if (b) b.click();
    var campo = document.getElementById('consAsunto');
    ok('consulta: se puede abrir una nueva',
       !!campo, campo ? 'con su campo' : '(no hay formulario)', 'el formulario');
    if (!campo) return;

    /* Sin asunto no se abre. Una consulta sin asunto llega a la cola del
       equipo como un renglon en blanco: hay que abrirla para saber que
       pide, y con quince encima eso es quince veces. */
    var crear = document.getElementById('consCrear');
    if (crear) crear.click();
    var aviso = document.querySelector('#consCuerpo .cons-aviso');
    ok('consulta: sin decir de que va no se abre, y lo dice',
       !!aviso && /\S/.test(aviso.textContent),
       aviso ? aviso.textContent : '(sin aviso)', 'que falta el asunto');

    campo.value = 'Cuanto tarda el registro mercantil?';
    if (crear) crear.click();
  }

  function consultaTrasCrear(){
    if (CASO === 'gestor') return;
    /* Al abrirla se entra en ella: quien acaba de escribir de que va, lo
       siguiente que quiere es contarlo, no volver a una lista. */
    var hilo = document.querySelector('#consCuerpo .hilo');
    ok('consulta: al abrirla se entra en su conversacion',
       !!hilo, hilo ? 'dentro' : '(sigue el formulario)', 'la conversacion');

    var cab = document.querySelector('#consCuerpo .sol-h');
    ok('consulta: y con el asunto que escribiste',
       !!cab && cab.textContent.indexOf('registro mercantil') >= 0,
       cab ? cab.textContent : '(no hay)', 'Cuanto tarda el registro mercantil?');

    var cerrar = document.getElementById('consCerrar');
    if (cerrar) cerrar.click();
  }

  /* ── Y LA OTRA PUNTA: LA COLA DEL EQUIPO ──
     Una consulta que el inversionista abre y el equipo no ve es un buzon sin
     fondo. Estas corren sobre el gestor. */
  function consultaCola(){
    if (CASO !== 'gestor') return;
    var caja = document.getElementById('colaCons');
    ok('consulta: el equipo las ve en su cola',
       !!caja, caja ? 'esta la seccion' : '(no hay seccion)', 'la seccion');
    if (!caja) return;

    /* Las DOS vivas. La tercera del ejemplo esta resuelta y no es cola: sin
       ella en la mesa, este filtro pasaria aunque no filtrara nada. */
    var fichas = caja.querySelectorAll('.co-ficha');
    igual('consulta: y solo las que siguen vivas, no las resueltas', fichas.length, 2);
    if (!fichas.length) return;

    /* CON EL NOMBRE de quien pregunta. Una pregunta sin nombre obliga a
       abrir el expediente para saber a quien se le contesta. */
    var quien = fichas[0].querySelector('.co-quien');
    ok('consulta: y con el nombre de quien pregunta',
       !!quien && /\S/.test(quien.textContent),
       quien ? quien.textContent : '(no hay)', 'un nombre');

    /* Y la conversacion dentro: tomar una consulta sin poder leerla antes es
       aceptar un trabajo sin saber cual. */
    ok('consulta: y su conversacion, para poder leerla antes de tomarla',
       !!fichas[0].querySelector('.hilo'),
       fichas[0].querySelector('.hilo') ? 'esta' : '(no hay hilo)', 'el hilo');
  }

  function consultaToma(){
    if (CASO !== 'gestor') return;
    /* La segunda es la que nadie lleva: la primera ya tiene gestor y por eso
       no trae boton de tomar. */
    var fichas = document.querySelectorAll('#colaCons .co-ficha');
    if (fichas.length < 2) { ok('consulta: hay una libre que tomar', false,
                                fichas.length + ' fichas', '2'); return; }
    var b = fichas[1].querySelector('.co-botones .btn');
    ok('consulta: la que no lleva nadie se puede tomar',
       !!b, b ? b.textContent : '(sin boton)', 'un boton de tomarla');
    if (b) b.click();
  }

  function consultaTrasTomar(){
    if (CASO !== 'gestor') return;
    var fichas = document.querySelectorAll('#colaCons .co-ficha');
    if (fichas.length < 2) { ok('consulta: sigue habiendo dos', false,
                                fichas.length + ' fichas', '2'); return; }
    /* Tomarla NO la saca de la cola -sigue siendo trabajo- pero cambia su
       estado. Sin esto, el boton podria no hacer nada y la prueba de arriba
       -que solo mira que se pueda pulsar- seguiria verde. */
    var est = fichas[1].querySelector('.cons-est');
    ok('consulta: al tomarla pasa a en curso',
       !!est && est.classList.contains('en_curso'),
       est ? est.className : '(no hay)', 'en_curso');

    /* Y ya no se puede volver a tomar: dos gestores llevando la misma
       conversacion es la forma de que conteste uno y el otro no se entere. */
    var botones = fichas[1].querySelectorAll('.co-botones .btn');
    igual('consulta: y ya nadie mas la puede tomar', botones.length, 1);
  }

  function consultaResuelve(){
    if (CASO !== 'gestor') return;
    var fichas = document.querySelectorAll('#colaCons .co-ficha');
    if (fichas.length < 2) return;
    var bs = fichas[1].querySelectorAll('.co-botones .btn');
    if (bs.length) bs[bs.length - 1].click();
  }

  function consultaTrasResolver(){
    if (CASO !== 'gestor') return;
    /* Resuelta SALE de la cola: dejarla puesta hace que el numero de arriba
       mienta, y el numero es lo que el equipo mira para saber si puede irse
       a casa. */
    igual('consulta: al resolverla sale de la cola',
          document.querySelectorAll('#colaCons .co-ficha').length, 1);
    igual('consulta: y el contador baja',
          (document.getElementById('navTramitesN') || {}).textContent, '3');
  }


  /* ── DESDE CADA TRÁMITE SE PUEDE HABLAR CON EL CIIP ───────────────────────
     Un paso ASÍNCRONO -declara «sigue»- porque entra en las treinta y tres
     fichas una por una y cada una tarda en pintarse. Corre en un solo pase:
     lo que comprueba no depende del expediente, y repetirlo doce veces son
     doce navegaciones de treinta y tres pantallas por el mismo resultado.

     LO QUE SE AFIRMA es «donde hay solicitud, hay puerta», y no «las treinta
     y tres tienen puerta». La diferencia no es de matiz: escrito de la
     segunda forma, esta prueba medía el CATÁLOGO del doble en vez del panel
     —el doble sólo enciende trece trámites, así que veinte ni llegan a tener
     formulario— y salían veinte rojos que no eran fallos de nada. Un trámite
     que la base no conoce no puede enseñar una solicitud, y exigirle una
     puerta es exigirle algo que no existe.

     Así además no depende de cuántos trámites traiga el ejemplo: el día que
     el CIIP encienda diez más, la prueba los cubre sola. */
  function puertaTodos(sigue){
    if (CASO !== 'vacio') return sigue();

    var refs = [].map.call(document.querySelectorAll('.tcard[data-tr]'), function(c){
      return c.getAttribute('data-tr');
    });
    ok('puerta: hay fichas que recorrer', refs.length >= 30,
       refs.length + ' fichas', '30 o más');
    if (!refs.length) return sigue();

    var conSolicitud = [], sinPuerta = [];
    (function mira(i){
      if (i >= refs.length){
        location.hash = '';
        /* Sin este contador, la prueba de abajo pasaría con CERO solicitudes
           miradas: si un cambio dejara de pintar formularios, «ninguno sin
           puerta» seguiría siendo cierto y el verde no significaría nada. */
        /* Se DICEN cuáles y no cuántas: cuando esto falle, «3 con solicitud»
           no dice nada y «c1,c5,c6» dice exactamente dónde mirar. */
        ok('puerta: y varias de ellas llevan a una solicitud',
           conSolicitud.length >= 5, conSolicitud.join(',') || '(ninguna)', '5 o más');
        igual('puerta: y desde toda solicitud se puede hablar con el CIIP',
              sinPuerta.join(',') || '(ninguna sin puerta)', '(ninguna sin puerta)');
        return sigue();
      }
      location.hash = 'tramite-' + refs[i];
      /* SE ESPERA A QUE APAREZCA, no un rato fijo. Con 420 ms clavados, dos
         trámites -los de formulario más largo- no llegaban a tiempo y se
         contaban como «sin solicitud»: quedaban fuera de la comprobación sin
         que nada lo dijera. Se vio quitándole la puerta a uno de ellos a
         propósito y comprobando que la prueba seguía verde.

         Se rinde a los dos segundos y sigue: rendirse es correcto porque el
         que no apareció se queda fuera de la lista de «con solicitud», y esa
         lista se enseña entera cuando algo falla. */
      var vueltas = 0;
      (function espera(){
        var ficha = document.getElementById('trReal');
        var hay = ficha && ficha.querySelector('.sol-col');
        if (!hay && ++vueltas < 50) return setTimeout(espera, 40);
        /* Sólo cuentan las que de verdad enseñan una solicitud: sin
           formulario no hay «etapa de enviar la solicitud» que mirar. */
        if (hay){
          conSolicitud.push(refs[i]);
          /* El cuadro Y su botón: un cartel sin nada que pulsar deja a quien
             lo lee buscando dónde, que es igual de malo que no tenerlo. */
          if (!ficha.querySelector('.sol-gestion .btn')) sinPuerta.push(refs[i]);
        }
        mira(i + 1);
      })();
    })(0);
  }



  /* ── LA «i» DE LAS FASES ──
     Las cabeceras de fase llevaban una «i» con la lista de trámites de esa
     etapa. El CIIP la quitó: lo que contaba está justo debajo, desplegando la
     propia fase, y un globo que repite lo de abajo hace pulsar para leer lo
     que ya se iba a ver.

     Se comprueban las DOS mitades. Sólo la primera se cumpliría igual con una
     regla que borrara todas las «i» del panel —incluida la del camino, que sí
     cuenta algo que no está escrito en ninguna otra parte—, y eso es un
     estropicio mucho mayor que pasaría por arreglo. */
  /* ── NINGUNA TABLA SE ESCONDE A SÍ MISMA ─────────────────────────────────
     «Mis trámites» era la única de las cinco tablas del panel que, al
     quedarse sin filas, se escondía entera y sacaba el aviso suelto debajo:
     una frase flotando entre dos rayas, que se lee como una página a medio
     cargar. Ahora el aviso va dentro, en una celda que ocupa las columnas —lo
     que ya hacía Documentos— y el marco y las cabeceras se quedan.

     SE COMPRUEBA LEYENDO EL CÓDIGO y no la pantalla, y es una decisión, no
     pereza: para ver el estado vacío hace falta un expediente sin ningún
     trámite, y ninguno de los tres ejemplos lo es. Se intentó con un gancho
     que vaciaba el doble, y no sirve —la lista está cacheada, así que
     vaciarla no repinta nada— y quedaba una prueba que decía mirar el estado
     vacío sin llegar a verlo nunca. Eso es peor que no tenerla.

     Lo que sí es cierto y comprobable: en el código no debe quedar ni una
     línea que esconda una tabla por estar vacía. */
  function tablasMiran(){
    var texto = '';
    [].forEach.call(document.querySelectorAll('script'), function(h){ texto += h.textContent; });
    /* Se busca el texto tal cual, sin expresión regular: una barra invertida
       de menos aquí daría una prueba que corre y no encuentra nada. */
    var malo = texto.indexOf('tabla.hidden = true') >= 0 ||
               texto.indexOf('Tabla.hidden = true') >= 0;
    ok('tablas: hay código que mirar', texto.length > 50000,
       texto.length + ' caracteres de script', 'el panel entero');
    ok('tablas: ninguna se esconde a sí misma por quedarse vacía',
       !malo, malo ? 'alguna se esconde' : 'ninguna', 'ninguna');
  }

  function iFasesMira(){
    var fases = document.querySelectorAll('.phase[data-fase]');
    ok('fases: hay fases que mirar', fases.length >= 3,
       fases.length + ' fases', '3 o más');
    if (!fases.length) return;

    var conI = [].filter.call(fases, function(f){
      return !!f.querySelector('.phase-cab .pista');
    }).length;
    igual('fases: ninguna cabecera de fase lleva ya la «i»', conI, 0);

    /* Y la del camino NO se ha ido con ellas. Se mira que SE VEA y no sólo
       que exista: escondida con un display:none esta comprobación pasaba
       igual, y una «i» que está en el árbol pero no en la pantalla es una «i»
       que no tiene nadie. Se vio sabotéandolo. */
    var iCamino = document.querySelector('.sec-h .pista');
    ok('fases: pero la del camino sigue a la vista, que ésa sí cuenta algo aparte',
       !!iCamino && window.getComputedStyle(iCamino).display !== 'none' &&
         iCamino.getBoundingClientRect().width > 0,
       iCamino ? ('display ' + window.getComputedStyle(iCamino).display) : 'no está',
       'a la vista');
  }


  /* ── EL TIEMPO ESTIMADO SE CUENTA EN HÁBILES ──
     Decisión del CIIP: los números se quedan en semanas y meses, y se dice
     que el conteo excluye fines de semana y feriados. Un inversionista que
     lee «2–3 semanas» y cuenta días de calendario se planta en el CIIP tres
     días antes de tiempo.

     Se comprueban las DOS caras, y la segunda es la que de verdad cuesta:

       · toda línea que es una ESTIMACIÓN lo dice;
       · y ninguna de las que NO lo son lo dice. De las 33 del catálogo, 8 no
         son estimaciones —«Se pide en el consulado», «Abierto para ti»— y un
         parche descuidado que añada la palabra a todas escribiría tonterías
         sin que nada se pusiera rojo.

     Se mira el diccionario y no la pantalla: el pase corre en un idioma y
     esto tiene que valer para los seis. */
  function habilesMira(){
    var I = (typeof I18N !== 'undefined') ? I18N : null;
    if (!I){ ok('hábiles: hay diccionario que mirar', false, '(no hay)', 'el I18N'); return; }

    /* SI ES ESTIMACIÓN LO DECIDE LA CLAVE, no cómo empieza cada traducción,
       y ese detalle no es teórico: la primera versión de esto miraba el
       prefijo de cada idioma, el portugués usa «Estimativa:» además de
       «Estimado:» y el italiano «Stima:» además de «Stimato:», y cuatro
       líneas se quedaron sin la aclaración SIN que esta prueba dijera nada
       —porque compartía la lista de prefijos con el parche, así que las dos
       tenían el mismo punto ciego—. Se vio en un pantallazo.

       Mirando el castellano, que no varía, la pregunta se contesta una sola
       vez por clave y vale para los seis. */
    /* Eran 33 renglones escritos a mano, uno por ficha, y ahora son SEIS
       moldes: el plazo sale de la base y se dice en dias, semanas o meses.
       La decision del CIIP no cambia -el conteo excluye fines de semana y
       feriados, y hay que decirlo-, cambia cuantos sitios hay que mirar.

       Y la otra cara sigue haciendo falta: t.sinestimado NO es una
       estimacion y no puede decirlo. Un parche descuidado que añadiera la
       palabra a todo escribiria «sin plazo estimado hábil». */
    var DICE = /hábil|útil|úteis|working|lavorativ|工作|рабоч/;
    var claves = ['t.est1', 't.estN', 't.estsem', 't.estsemN', 't.estmes', 't.estmesN'];
    var otras  = ['t.sinestimado'];
    var todas  = claves.concat(otras);
    ok('hábiles: hay tiempos que mirar',
       todas.every(function(k){ return I.es[k]; }),
       todas.filter(function(k){ return !I.es[k]; }).join(', ') || 'los siete moldes',
       'los seis del plazo y el de sin plazo');
    ok('hábiles: y las hay de los dos tipos, estimación y no',
       claves.length === 6 && otras.length === 1,
       claves.length + ' estimaciones y ' + otras.length + ' que no lo es',
       'de las dos');

    var sinDecir = [], loDicenSinSerlo = [];
    ['es','en','pt','it','zh','ru'].forEach(function(idi){
      claves.forEach(function(k){
        if (!DICE.test(String((I[idi] || {})[k] || ''))) sinDecir.push(idi + ' ' + k);
      });
      otras.forEach(function(k){
        if (DICE.test(String((I[idi] || {})[k] || ''))) loDicenSinSerlo.push(idi + ' ' + k);
      });
    });

    igual('hábiles: toda estimación dice que se cuenta en días hábiles',
          sinDecir.length ? sinDecir.slice(0, 4).join(', ') : '(todas lo dicen)',
          '(todas lo dicen)');
    igual('hábiles: y ninguna línea que no es estimación lo dice',
          loDicenSinSerlo.length ? loDicenSinSerlo.slice(0, 4).join(', ') : '(ninguna)',
          '(ninguna)');
  }


  /* ── NINGUNA LETRA AL TAMAÑO DE FÁBRICA ──────────────────────────────────
     Nace de un fallo que no daba error ni se veía en ninguna prueba: el botón
     de volver decía «font:700 12.5px/1 inherit», y eso es CSS inválido —dentro
     del atajo «font», la familia no admite palabras como inherit—. El
     navegador tira la declaración ENTERA, así que el botón se quedaba sin
     tamaño Y sin negrita, y caía a 13,33px, que es lo que Chrome le pone por
     defecto a un <button>. Se descubrió contando los tamaños de letra de la
     página, no probándola.

     Se comprueban las dos puntas:

       · LA CAUSA, leyendo la hoja: ningún atajo «font:» puede llevar una
         palabra clave de CSS donde va la familia. Es estático y no depende de
         qué pantalla esté abierta.

       · EL SÍNTOMA, en pantalla: nada con letra propia puede salir a 13,33px.
         Ese número no lo ha elegido nadie; si aparece, es que algo se quedó
         sin tamaño. */
  function letraMira(){
    var texto = '';
    [].forEach.call(document.querySelectorAll('style'), function(h){ texto += h.textContent; });

    /* Sin expresión regular: se parte por «font:» y se mira lo que hay hasta
       el punto y coma. Una barra invertida de menos en un patrón aquí daría
       una prueba que corre y no encuentra nada, que ya ha pasado. */
    var malos = [], trozos = texto.split('font:');
    for (var i = 1; i < trozos.length; i++){
      var fin = trozos[i].indexOf(';');
      if (fin < 0) fin = trozos[i].indexOf('}');
      var d = trozos[i].slice(0, fin < 0 ? 60 : fin).trim();
      /* «font:inherit» a secas es válido: es el valor entero. Lo inválido es
         llevar la palabra al final, detrás de un tamaño. */
      if (d === 'inherit' || d === 'initial' || d === 'unset' || d === 'revert') continue;
      ['inherit', 'initial', 'unset', 'revert'].forEach(function(p){
        if (d.length > p.length && d.slice(-p.length) === p) malos.push(d.slice(0, 40));
      });
    }
    igual('letra: ningún atajo «font:» lleva una palabra de CSS como familia',
          malos.length ? malos[0] : '(ninguno)', '(ninguno)');

    /* AQUÍ HABÍA una segunda mitad que miraba la PANTALLA: que nada saliera
       a 13,33px. Se quitó porque en el punto de la cadena donde corre esto la
       vista tiene cinco elementos con letra —lo dijo un contador puesto a
       propósito— así que no tenía nada que cazar y pasaba en verde siempre.
       Una comprobación que no examina nada es peor que ninguna: ocupa el
       sitio de la que sí haría falta.

       Lo de arriba no depende de la pantalla: lee la hoja entera y encuentra
       la CAUSA esté donde esté el fallo. Con eso basta. */
  }



  /* ── LOS COMENTARIOS DE LA HOJA, CUADRADOS ───────────────────────────────
     Tercera vez que esto muerde, y las tres iguales: alguien amplía un
     comentario y el texto nuevo cae DETRÁS del cierre que ya lo terminaba
     -las dos letras que aqui no se pueden ni escribir, porque cerrarian este
     mismo comentario-. Lo que
     queda suelto no da error —el navegador lo lee como si fuera un selector—
     y se traga la regla siguiente entera.

     La primera vez se comió la línea de --navy y todos los botones azules del
     panel salieron blancos sobre blanco. La tercera se comió
     «.grid-tr{align-items:stretch}», una de las tres piezas que cuadran las
     fichas: seguía cuadrando por las otras dos, así que ni se notaba.

     Contar aperturas y cierres cuesta una milésima y lo caza siempre. */
  /* ── NADIE BUSCA POR UNA CLASE QUE SE REPITE ──
     El pintor de «Por atender» buscaba la caja de su tabla por la clase
     a secas, en todo el documento, y le ponia hidden segun tuviera filas
     o no.

     Y hay CINCO cajas de tabla. La primera del marcado es la de
     Trazabilidad, asi que cuando la cola del equipo se quedaba vacia
     -que es lo normal- aquella linea le ponia hidden al rastro.

     Lo que se veia: entrabas en Trazabilidad, los contadores decian 17 y
     debajo no habia nada; con F5 aparecia. Y ni un error en la consola,
     porque no habia ninguno: la tabla estaba entera -cinco titulos,
     diecisiete filas- midiendo cero de alto dentro de un padre oculto.
     Costo tres pantallazos de consola encontrarlo.

     Esto no vigila ese caso: vigila la FAMILIA. Se lee el guion entero
     buscando cada document.querySelector('.algo') y se cuenta cuantos
     elementos tienen esa clase AHORA MISMO. Si hay mas de uno, la linea
     esta cogiendo el primero del documento, que casi nunca es el que
     quiere. Con id no pasa: un id no se repite.

     Se busca el texto tal cual, sin expresion regular. Ya nos ha comido
     el escapado una barra mas de una vez, y un patron que corre sin
     encontrar nada deja esto en verde para siempre.

     Y OJO AL ESCRIBIR COMENTARIOS: esto lee el guion ENTERO, comentarios
     incluidos, asi que dejar la linea mala escrita como ejemplo la vuelve
     a encontrar. Paso nada mas estrenarla, con el arreglo ya puesto. Es
     el mismo tropiezo que escribir un cierre de comentario dentro de otro
     comentario: el texto de al lado del codigo cuenta como codigo.

     Y ese cierre NO se escribe aqui ni de ejemplo, porque cerraria este
     mismo bloque en seco. Acaba de pasar, escribiendo esta linea. */
  function cajasConDueño(){
    var codigo = '';
    [].forEach.call(document.querySelectorAll('script'), function(s){ codigo += s.textContent; });
    ok('cajas con dueño: hay guion que mirar', codigo.length > 100000,
       codigo.length + ' caracteres de guion', 'el guion entero');

    var marca = "document.querySelector('.";
    var malas = [], mirados = {}, desde = 0;
    while (true){
      var i = codigo.indexOf(marca, desde);
      if (i < 0) break;
      desde = i + marca.length;
      var fin = codigo.indexOf("'", desde);
      if (fin < 0) break;
      var clase = codigo.slice(desde, fin);
      /* Solo clases a secas. Un selector con espacios o combinadores ya
         dice de donde cuelga, y ese es justamente el arreglo. */
      if (clase.indexOf(' ') >= 0 || clase.indexOf('.') >= 0 ||
          clase.indexOf('[') >= 0 || clase.indexOf('>') >= 0) continue;
      if (mirados[clase]) continue;
      mirados[clase] = true;
      var cuantos = document.querySelectorAll('.' + clase).length;
      if (cuantos > 1) malas.push('.' + clase + ' (' + cuantos + ')');
    }

    ok('cajas con dueño: ninguna búsqueda global de una clase repetida',
       malas.length === 0,
       malas.join(', ') || 'ninguna',
       'ninguna');
  }

  function comentariosMiran(){
    var texto = '';
    [].forEach.call(document.querySelectorAll('style'), function(h){ texto += h.textContent; });
    ok('comentarios: hay hoja que mirar', texto.length > 20000,
       texto.length + ' caracteres de estilos', 'la hoja entera');

    var i = 0, prof = 0, sobran = 0, dentro = 0;
    while (i < texto.length){
      if (texto.charAt(i) === '/' && texto.charAt(i + 1) === '*'){
        if (prof > 0) dentro++;
        prof++; i += 2; continue;
      }
      if (texto.charAt(i) === '*' && texto.charAt(i + 1) === '/'){
        prof--;
        if (prof < 0){ sobran++; prof = 0; }
        i += 2; continue;
      }
      i++;
    }
    igual('comentarios: ninguno se queda sin cerrar', prof, 0);
    igual('comentarios: y ningún cierre sobra, que se lleva la regla de al lado', sobran, 0);
    igual('comentarios: ni se abre uno dentro de otro', dentro, 0);
  }


  /* ── LAS PANTALLAS EMPIEZAN POR SU CONTENIDO ─────────────────────────────
     Cada vista llevaba arriba un botón de volver, un título y un subtítulo.
     Fuera los tres. Se comprueba en el ÁRBOL y sin navegar: las quince
     pantallas están todas en el documento, sólo se enseña una.

     Y se comprueban las DOS caras. La segunda es la que importa: dentro de
     esas cabeceras vivían tres BOTONES DE ACCIÓN —«Editar» en Mi empresa,
     «Publicar» en Activos, «Pedir cita» en Citas— y llevárselos por delante
     al quitar la cabecera sería quitar funciones, no adorno. Un borrado
     alegre habría pasado la primera mitad y roto tres pantallas. */
  function cabecerasMiran(){
    var vistas = document.querySelectorAll('[class$="-vista"]');
    ok('cabeceras: hay pantallas que mirar', vistas.length >= 10,
       vistas.length + ' pantallas', '10 o más');

    var conTitulo = [];
    [].forEach.call(vistas, function(v){
      /* El pliego se queda con el suyo: es un documento legal. */
      if (v.className.indexOf('pliego') >= 0) return;
      var h = v.querySelector('.sec-h .t');
      if (h) conTitulo.push(v.className);
    });
    igual('cabeceras: ninguna pantalla lleva ya su título arriba',
          conTitulo.length ? conTitulo.slice(0, 3).join(', ') : '(ninguna)', '(ninguna)');

    /* Los tres botones que vivían ahí dentro siguen existiendo. */
    var faltan = ['emBoton', 'acNuevo', 'ciPedir'].filter(function(id){
      return !document.getElementById(id);
    });
    igual('cabeceras: pero los botones que había dentro siguen',
          faltan.length ? faltan.join(', ') : '(están los tres)', '(están los tres)');
  }

  function gestionAbre(){
    if (CASO !== 'vacio') return;
    location.hash = 'tramite-c14';
  }

  function gestionMira(){
    if (CASO !== 'vacio') return;
    var caja = document.getElementById('trReal');
    var of = caja && caja.querySelector('.sol-gestion');
    ok('gestion: el tramite ofrece que lo lleve el CIIP',
       !!of && /\S/.test(of.textContent),
       of ? of.textContent.trim().slice(0, 45) : '(no esta)', 'el ofrecimiento');
    if (!of) return;

    /* Y VIVE FUERA del formulario, en su propio cuadro. Esto se pide aparte
       porque la prueba de arriba lo encuentra en cualquier sitio de la
       pantalla: cuando el bloque estaba metido dentro de la tarjeta de «Tus
       datos» pasaba igual de verde, y ahi dentro se leia como el ultimo paso
       de rellenarla, que es justo lo contrario de lo que es. */
    ok('gestion: y en su propio cuadro, no dentro del formulario',
       !of.closest('.sol-col') && !of.closest('.sol-lado'),
       of.closest('.sol-col') ? 'dentro de «Tus datos»'
         : of.closest('.sol-lado') ? 'dentro de los recaudos' : 'fuera de los dos',
       'fuera de los dos');

    /* Con el mismo marco que sus hermanos. Sin esto, sacarlo fuera lo dejaria
       suelto sobre el fondo, que es peor que donde estaba. */
    var formu = document.querySelector('#trReal .sol-col');
    if (formu) {
      var a = window.getComputedStyle(of), b = window.getComputedStyle(formu);
      igual('gestion: con el mismo borde que el formulario',
            a.borderTopColor + ' / ' + a.borderTopWidth,
            b.borderTopColor + ' / ' + b.borderTopWidth);
      igual('gestion: y el mismo redondeo', a.borderRadius, b.borderRadius);
    }

    /* AQUÍ SE INTENTÓ comprobar que el cartel no promete una cita —decía
       «Pide una cita y lo hablamos» mucho después de que el botón dejara de
       pedirla— buscando esas palabras en los seis idiomas. No sirve, y se
       quita: el texto nuevo dice «sin pedir cita», o sea que nombra la cita
       precisamente para descartarla, y el buscador de palabras no distingue
       prometer de negar. Daba rojo sobre el texto correcto.

       Lo que de verdad importa ya está probado, y por comportamiento y no
       por palabras: en gestionTrasPulsar se comprueba que el botón abre la
       consulta Y que la ventana de la cita se queda cerrada. Una prueba de
       palabras encima de esa no añade protección; solo añade rojos falsos
       cada vez que el CIIP retoca la frase. */

    /* Y no compite con el de enviar: el de verdad de esta pantalla es
       «Enviar solicitud», y dos botones iguales no dicen cual es cual. */
    var bt = of.querySelector('button');
    ok('gestion: con su boton, y aparte del de enviar',
       !!bt && !bt.classList.contains('navy'),
       bt ? bt.className : '(sin boton)', 'un boton que no es el principal');
    if (!bt) return;

    bt.click();
  }

  function gestionTrasPulsar(){
    if (CASO !== 'vacio') return;
    /* Abre una CONSULTA, no una cita. Antes llevaba a reservar una hora, y
       eso obligaba a esperar al día de la reunión para algo que se contesta
       por escrito: hasta entonces el equipo ni sabía que se lo habían
       pedido. La cita sigue existiendo, en la burbuja, para cuando de verdad
       haga falta hablar. */
    var back = document.getElementById('consBack');
    ok('gestion: al pulsarlo se abre una consulta, sin pedir cita',
       !!back && back.classList.contains('open'),
       back ? back.className : '(no hay ventana)', 'la ventana abierta');

    /* Y no la de la cita. Se pide aparte porque las dos ventanas son
       distintas y podrían abrirse las dos: eso dejaría al inversionista
       reservando una hora igualmente. */
    var cita = document.getElementById('citaBack');
    ok('gestion: y la ventana de la cita se queda cerrada',
       !cita || !cita.classList.contains('open'),
       cita ? cita.className : '(no hay ventana)', 'cerrada');

    /* CON EL ASUNTO YA ESCRITO. Sin esto, abrir la ventana se cumpliría
       igual con el campo en blanco, y quien acaba de estar mirando un
       trámite tendría que volver a contar de cuál habla. */
    var as = document.getElementById('consAsunto');
    ok('gestion: y con el trámite del que venías ya escrito',
       !!as && /\S/.test(as.value),
       as ? ('"' + as.value + '"') : '(no hay asunto)', 'el nombre del trámite');

    /* Se cierra: una prueba que deja una ventana abierta le tapa la
       pantalla a las de despues. */
    var cerrar = document.getElementById('consCerrar');
    if (cerrar) cerrar.click();
    location.hash = '';
  }

  function migajaAbre(){
    if (CASO !== 'lleno') return;
    /* Se PULSA el renglon, no se escribe la direccion. Con el hash puesto a
       mano la vista no llegaba a cambiar -para un inversionista la direccion
       es #tramites y no #mistramites- y la comprobacion salia verde
       comparando el panel consigo mismo. Pulsar es ademas lo que hace una
       persona, asi que se prueba el camino de verdad. */
    var nav = document.getElementById('navTramites');
    if (nav) nav.click();
  }

  function migajaMira(){
    if (CASO !== 'lleno') return;
    var mig = document.querySelector('.tb-crumb');
    var don = mig && mig.querySelector('b');
    var enc = document.querySelector('.sb-item.active [data-i18n]');

    ok('migaja: hay migaja y hay renglon encendido',
       !!don && !!enc, (don ? 'migaja' : 'sin migaja') + ', ' +
       (enc ? 'encendido' : 'sin encendido'), 'los dos');
    if (!don || !enc) return;

    igual('migaja: dice el sitio donde estas, no siempre el panel',
          don.textContent.trim(), enc.textContent.trim());

    /* Y NO es «Mi panel»: sin esto, la comprobacion de arriba se cumpliria
       igual si la barra se hubiera quedado encendida tambien en el panel. */
    ok('migaja: y aqui eso no es «Mi panel»',
       don.textContent.trim() !== 'Mi panel' && /\S/.test(don.textContent),
       '"' + don.textContent.trim() + '"', 'el nombre de esta vista');

    /* Se lleva su data-i18n: sin el, el cambio de idioma la dejaria atras
       diciendo el nombre viejo en el idioma viejo. */
    ok('migaja: y se traducira con el resto',
       don.getAttribute('data-i18n') === enc.getAttribute('data-i18n'),
       don.getAttribute('data-i18n') + ' vs ' + enc.getAttribute('data-i18n'),
       'la misma clave');

    location.hash = '';
  }

  function migajaVuelve(){
    if (CASO !== 'lleno') return;
    var don = document.querySelector('.tb-crumb b');
    var enc = document.querySelector('.sb-item.active [data-i18n]');
    /* Y al volver a la portada vuelve a decir el panel: una migaja que se
       queda con el nombre de donde estuviste es peor que una fija. */
    ok('migaja: y al volver a la portada vuelve a decir el panel',
       !!don && !!enc && don.textContent.trim() === enc.textContent.trim(),
       don ? '"' + don.textContent.trim() + '"' : '(no hay)', 'lo que diga el renglon');
  }

  function cuadraAbre(){
    if (CASO !== 'vacio') return;
    cuadraQueda = CUADRA.slice();
    location.hash = 'tramite-' + cuadraQueda[0];
  }

  function cuadraMira(){
    if (CASO !== 'vacio' || !cuadraQueda || !cuadraQueda.length) return;
    var ref = cuadraQueda.shift();
    var caja = document.getElementById('trReal');
    var pa = caja && caja.querySelector('.pa');
    var hojas = pa ? pa.querySelectorAll('.pa-hoja') : [];
    var tramos = pa ? pa.querySelectorAll('.pa-seg') : [];
    var col = caja && caja.querySelector('.sol-col');

    ok('cuadre: ' + ref + ' abre en el primer paso, con su barra',
       hojas.length >= 2 && tramos.length === hojas.length && !!col,
       hojas.length + ' hojas y ' + tramos.length + ' tramos',
       'los mismos, y dos por lo menos');
    if (!pa || !hojas.length) {
      location.hash = cuadraQueda.length ? ('tramite-' + cuadraQueda[0]) : '';
      return;
    }

    /* UNA sola a la vista. Partir la solicitud y luego enseñarla entera es
       no haberla partido. */
    var vistas = [].filter.call(hojas, function(h){ return !h.hidden; });
    ok('cuadre: ' + ref + ' enseña una hoja y no dos',
       vistas.length === 1, vistas.length + ' a la vista', 'una');
    ok('cuadre: ' + ref + ' empieza por «Tus datos»',
       vistas.length === 1 && vistas[0].getAttribute('data-paso') === '1',
       vistas.length === 1 ? 'la ' + vistas[0].getAttribute('data-paso') : '(ninguna)',
       'la 1');

    /* El primer tramo encendido, y el botón de enviar guardado: enviar desde
       la primera hoja sería mandar la solicitud sin ver los recaudos. */
    ok('cuadre: ' + ref + ' enciende el primer tramo de la barra',
       tramos[0].classList.contains('ahora'),
       tramos[0].className, 'pa-seg ahora');
    var enviar = caja.querySelector('.sol-pie');
    ok('cuadre: ' + ref + ' no ofrece enviar todavía',
       !!enviar && enviar.hidden,
       enviar ? (enviar.hidden ? 'guardado' : 'a la vista') : '(no hay)', 'guardado');

    if (vistas.length === 1){
      var v = vistas[0].getBoundingClientRect();
      var d = pa.getBoundingClientRect();
      ok('cuadre: ' + ref + ' no se sale por los lados',
         v.right - d.right <= 1 && v.left - d.left >= -1,
         'derecha ' + Math.round(v.right - d.right) +
         ', izquierda ' + Math.round(v.left - d.left), 'dentro');
    }

    location.hash = cuadraQueda.length ? ('tramite-' + cuadraQueda[0]) : '';
  }

  function guardaCatalogo(){
    if (CASO !== 'lleno' || !window.CIIP_ENCENDIDAS) return;
    var antes = document.querySelectorAll('.tcard[data-tr]').length;

    /* Vacio, nulo y sin definir: las tres formas en que puede no llegar. */
    window.CIIP_ENCENDIDAS({});
    window.CIIP_ENCENDIDAS(null);
    window.CIIP_ENCENDIDAS(undefined);

    var despues = document.querySelectorAll('.tcard[data-tr]').length;
    ok('apagadas: con el catalogo vacio no se esconde ni una tarjeta',
       despues === antes && antes > 0,
       antes + ' antes, ' + despues + ' despues', 'las mismas, y no cero');
  }

  /* ═══════════ Y ENTRANDO DESDE UN TRAMITE ═══════════
     «Fue cuando entre a solicitud de RIF y desde ese apartado le di a
     trazabilidad.» (CIIP, mirando la de produccion)

     La tabla salia otra vez sin cabecera y sin filas, con los contadores de
     arriba puestos —Todos 10, Roles 1, Catalogo 6, Citas 3—. O sea que los
     datos llegaron y lo que fallo fue pintar, igual que la primera vez.

     Pero las comprobaciones de aqui abajo abren Trazabilidad DESDE DONDE
     ESTUVIERA la cadena, y ese no es el camino que la rompe. Un trámite
     abierto deja cosas puestas —el detalle montado, trAbierto, la vista en
     'tramite'— y el paso de ahi a otra vista es distinto del paso desde la
     portada. Por eso la tanda seguia verde con el fallo delante.

     Esto reproduce el camino entero, que es lo primero que habia que hacer
     y no se hizo la vez anterior. */
  function rastroDesdeTramiteAbre(){
    if (!ES_ADMIN) return;
    location.hash = '';
  }

  function rastroDesdeTramiteEntra(){
    if (!ES_ADMIN) return;
    /* Un tramite de verdad, de los encendidos: el RIF personal. */
    location.hash = 'tramite-c3';
  }

  function rastroDesdeTramiteSalta(){
    if (!ES_ADMIN) return;
    igual('trazabilidad: primero se esta en un tramite',
          document.body.getAttribute('data-vista'), 'tramite');
    location.hash = 'rastro';
  }

  function rastroDesdeTramiteMira(){
    if (!ES_ADMIN) return;
    igual('trazabilidad: viniendo de un tramite, la vista se abre igual',
          document.body.getAttribute('data-vista'), 'rastro');

    var cab = document.querySelectorAll('#raCab th');
    igual('trazabilidad: y viniendo de un tramite la tabla trae sus titulos',
          cab.length, 5);

    var filas = document.querySelectorAll('#raLista tr');
    ok('trazabilidad: y sus filas, no solo los contadores de arriba',
       filas.length >= 7 && !document.querySelector('#raLista .ra-vacio'),
       filas.length + ' filas', 'siete o mas, y con contenido');

    /* Y que el contador de arriba cuadre con lo de abajo, que es
       exactamente lo que se vio descuadrado en produccion: 10 arriba y
       nada debajo. */
      /* El selector es button y NO .ftab: estos filtros no llevan esa clase,
         que es la de la portada. Lo escribi mal aqui a pesar de que la
         comprobacion de unas lineas mas arriba lleva ese mismo aviso puesto
         desde que se corrigio la primera vez. Copiar el bloque de al lado
         copia tambien sus erratas si no se lee el comentario. */
      var todos = document.querySelector("#raFiltros button");
    var num = todos && todos.querySelector('.n');
    ok('trazabilidad: y el contador cuadra con lo que se ve',
       !!num && Number(num.textContent) === filas.length,
       (num ? num.textContent : '(sin contador)') + ' contadas, ' + filas.length + ' pintadas',
       'las mismas');
    location.hash = '';
  }

  function rastroAbre(){
    if (!ES_ADMIN) return;
    location.hash = 'rastro';
  }

  function rastroMira(){
    if (!ES_ADMIN) return;
    igual('rastro: se abre la vista', document.body.getAttribute('data-vista'), 'rastro');

    /* La CABECERA. Se monta siempre, también sin apuntes: una tabla sin
       títulos parece rota y no vacía. Y era lo primero que faltaba. */
    var cab = document.querySelectorAll('#raCab th');
    igual('rastro: la tabla tiene sus cinco títulos', cab.length, 5);

    /* Y una fila por apunte. El doble trae siete. */
    var filas = document.querySelectorAll('#raLista tr');
    ok('rastro: y una fila por cada cosa apuntada', filas.length >= 7,
       filas.length + ' filas', 'siete o más');

    /* Que no sea una fila suelta diciendo que no hay nada: eso también
       cuenta como «una fila» y se vería casi igual de vacío. */
    ok('rastro: y no es el aviso de que no hay nada',
       !document.querySelector('#raLista .ra-vacio'),
       document.querySelector('#raLista .ra-vacio') ? 'dice que no hay nada' : 'hay apuntes',
       'apuntes de verdad');

    /* El contador de arriba y las filas de abajo salen de la MISMA lista.
       Cuando esto se rompió, el de arriba decía cinco y abajo no había
       ninguna: son las dos mitades de la misma cuenta y tienen que cuadrar. */
    /* La ficha de «Todos» es el primer botón del grupo; el número va en un
       .n dentro. Aquí estaba escrito .ftab, que es la clase de los filtros de
       la portada y no la de éstos: el selector no encontraba nada y la
       comprobación se quedaba en «(sin contador)», o sea sin medir. */
    var todos = document.querySelector('#raFiltros button');
    var num = todos && todos.querySelector('.n');
    ok('rastro: el contador cuadra con lo que se ve',
       !!num && Number(num.textContent) === filas.length,
       (num ? num.textContent : '(sin contador)') + ' contadas, ' + filas.length + ' pintadas',
       'las mismas');
  }

  /* La placa dejo de ser una columna con la sigla debajo: es el mismo
     recuadro que ya usaban las fichas sin logo, y la sigla se fue al renglon
     del organismo, en su etiqueta. Es la forma de la maqueta.

     Lo que estas comprobaciones piden NO cambia; cambia donde mirarlo. */
  function logosMiran(){
    var placas = document.querySelectorAll('.t-ico.placa img.ilogo');
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
    /* Dentro de las FICHAS: la cabecera del tramite abierto clona la placa
       con su clase, y alli la sigla la pone el renglon que se clona aparte. */
    var sinSigla = [];
    [].forEach.call(document.querySelectorAll('.tcard .t-ico.placa'), function(m){
      var c = m.closest('.tcard');
      var e = c && c.querySelector('.t-ente .ebadge');
      if (!e || !e.textContent.trim()) sinSigla.push(c ? c.getAttribute('data-tr') : '?');
    });
    ok('logos: y cada uno dice de quién es', sinSigla.length === 0,
       sinSigla.length ? sinSigla.join(', ') : 'ninguna sin sigla', 'ninguna sin sigla');

    /* Y ninguna ficha se quedo con la placa en columna. Sin esto, dejarse la
       mitad sin convertir pasaria igual de verde. */
    igual('logos: y ninguna se quedo con la placa en columna',
          document.querySelectorAll('.t-marca, .t-sigla').length, 0);

    /* Donde la sigla ya lo dice, el renglon no lo repite. Antes de esto,
       "SUSCERTE" salia dos veces en la misma tarjeta. La etiqueta y la sigla
       son ya la misma cosa, asi que lo que se mira es lo que la acompaña: el
       renglon entero menos la etiqueta tiene que ser el NOMBRE. */
    var repes = [];
    [].forEach.call(document.querySelectorAll('.tcard'), function(c){
      var b = c.querySelector('.t-ente .ebadge');
      var sig = b ? b.textContent.trim() : '';
      if (!sig) return;
      var e = c.querySelector('.t-ente');
      var resto = e ? e.textContent.replace(sig, '').replace(/\s+/g, ' ').trim() : '';
      if (!resto || resto === sig) repes.push(c.getAttribute('data-tr'));
    });
    ok('logos: y no repite la sigla al lado del nombre', repes.length === 0,
       repes.length ? repes.join(', ') : 'ninguna repetida', 'ninguna repetida');

    /* UNA sola etiqueta por renglon. Al bajar la sigla de la placa se colo
       este fallo: dos fichas -la c13 y la c27- ya llevaban la suya, la del
       REGISTRO al que se solicita -RNC, RNET-, y se quedaron con dos seguidas
       diciendo cosas distintas, «SNC RNC Servicio Nacional de
       Contrataciones». Se ve en cuanto se mira la pantalla y no lo cazaba
       nada: la comprobacion de arriba se queda con la primera etiqueta y da
       por bueno lo que venga detras. */
    var conDos = [];
    [].forEach.call(document.querySelectorAll('.tcard .t-ente'), function(e){
      if (e.querySelectorAll('.ebadge').length > 1){
        var c = e.closest('.tcard');
        conDos.push((c ? c.getAttribute('data-tr') : '?') + ': ' +
                    e.textContent.replace(/\s+/g, ' ').trim().slice(0, 34));
      }
    });
    igual('logos: y una sola etiqueta por renglon, no dos seguidas',
          conDos.length ? conDos.join(' | ') : '(ninguna)', '(ninguna)');

    /* ── LA MARCA DE AGUA, RETIRADA ──
       Cada tarjeta llevaba detras del texto el logo de su organismo, grande
       y al 7%. Lo quito el CIIP: el logo ya esta en su placa arriba con su
       sigla debajo, asi que el del fondo no añadia un dato -era el mismo- y
       ensuciaba el sitio por donde pasa la vista al leer la descripcion.

       Esta comprobacion exigia lo contrario: que TODAS lo llevaran. Se le da
       la vuelta en vez de borrarla, y se sigue mirando el fondo CALCULADO y
       no la ausencia de la regla: la regla se puede volver a colar desde
       otro sitio -un tema, una hoja de mas- y lo que hay que saber es que la
       tarjeta no lo pinta, venga de donde venga.

       Lo que SI se sigue exigiendo es que la placa de arriba y el atributo
       digan el mismo organismo. Ese emparejamiento no se ha retirado, y sin
       el una tarjeta podria llevar el logo del SAIME y decir SENIAT. */
    var conFondo = [], desparejas = [];
    [].forEach.call(document.querySelectorAll('.tcard'), function(c){
      var im = c.querySelector('.t-ico.placa img.ilogo');
      var marca = c.getAttribute('data-marca');
      if (!im && !marca) return;                 /* sin organismo: ni logo ni fondo */
      if (!im || !marca){ desparejas.push(c.getAttribute('data-tr')); return; }
      if (im.getAttribute('src').indexOf('logos/' + marca + '.') !== 0)
        desparejas.push(c.getAttribute('data-tr'));
      var fondo = window.getComputedStyle(c, '::before').backgroundImage || '';
      if (fondo.indexOf('logos/') >= 0) conFondo.push(c.getAttribute('data-tr'));
    });
    ok('marca: ninguna tarjeta lleva el logo detras del texto',
       conFondo.length === 0,
       conFondo.length ? conFondo.join(', ') : 'ninguna con fondo', 'ninguna con fondo');
    ok('marca: pero la placa de arriba sigue siendo la de su organismo',
       desparejas.length === 0,
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
    /* ── LA AGENDA, EN TABLA ──
       Eran tres montones de fichas, uno debajo de otro, y las canceladas
       plegadas al final. Ahora es una tabla como la cola, la boveda y Mis
       tramites: los montones pasan a ser filtros con su cuenta arriba, y cada
       cita es un renglon.

       La ficha NO desaparecio: baja debajo de su renglon cuando se pulsa «Ver
       la cita», porque la conversacion con el CIIP vive dentro de ella. Por eso
       las comprobaciones del hilo, mas abajo, empiezan desplegando una. */
    if (CASO === 'lleno'){
      igual('agenda: la tabla tiene sus cinco columnas',
            document.querySelectorAll('#ciCab th').length, 5);

      var filas = document.querySelectorAll('#ciCuerpo tr');
      igual('agenda: y un renglon por cada cita, tambien las canceladas',
            filas.length, 5);

      /* Los montones, con su cuenta. El de «todas» primero y encendido. */
      var mont = [].map.call(document.querySelectorAll('#ciFiltros button'),
        function(b){ return b.textContent.trim(); });
      igual('agenda: se reparte en marcha, pasadas y canceladas',
            mont.join(' | '), 'Todas5 | En marcha1 | Ya pasaron1 | Canceladas3');

      /* La viva se distingue del historial, y sigue siendo una sola. */
      igual('agenda: la viva se distingue del historial',
            document.querySelectorAll('#ciCuerpo tr.viva').length, 1);

      /* Cada renglon dice de que cita es: sin eso no hay forma de señalar una
         concreta ni de comprobar que su conversacion es la suya. */
      var conId = [].filter.call(filas, function(f){ return !!f.getAttribute('data-cita'); });
      igual('agenda: y cada renglon dice de que cita es', conId.length, filas.length);

      /* ── filtrar de verdad enseña menos ── */
      var canc = [].filter.call(document.querySelectorAll('#ciFiltros button'),
        function(b){ return /Cancelada/.test(b.textContent); })[0];
      if (canc){
        canc.click();
        igual('agenda: y filtrar por canceladas deja solo las tres',
              document.querySelectorAll('#ciCuerpo tr').length, 3);
        document.querySelectorAll('#ciFiltros button')[0].click();
        igual('agenda: y «Todas» las devuelve',
              document.querySelectorAll('#ciCuerpo tr').length, 5);
      }

      /* ── la ficha, desplegada bajo su renglon ── */
      var viva = document.querySelector('#ciCuerpo tr.viva');
      var ver = viva && viva.querySelector('button');
      ok('agenda: cada renglon ofrece abrir la cita', !!ver,
         ver ? ver.textContent.trim() : 'no hay boton', 'un boton');
      if (ver){
        igual('agenda: y llega recogida', document.querySelectorAll('#ciCuerpo tr.ci-detalle').length, 0);
        ver.click();
        var det = document.querySelector('#ciCuerpo tr.ci-detalle');
        ok('agenda: al pulsar se despliega debajo, no en otra pantalla',
           !!det && !!det.querySelector('.ci-ficha'),
           det ? (det.querySelector('.ci-ficha') ? 'con su ficha' : 'sin ficha') : 'no se desplego',
           'la ficha debajo del renglon');

        if (det && det.querySelector('.ci-ficha')){
          var fi = det.querySelector('.ci-ficha');
          ok('agenda: con su fecha puesta, no un hueco',
             /Confirmada para el/.test(fi.querySelector('.ci-linea').textContent) &&
             fi.querySelector('.ci-linea').textContent.indexOf('{') < 0,
             fi.querySelector('.ci-linea').textContent, 'la fecha, sin llaves');

          /* Como es la cita -verse, llamarse o ir- decide si tienes que salir de
             casa, asi que va con el estado y no perdido en el renglon gris. */
          var mo = fi.querySelector('.ci-cab .ct-chip.modo');
          ok('agenda: el modo lleva su propio distintivo', !!mo,
             mo ? mo.textContent : 'no existe', 'un distintivo aparte');
          if (mo){
            igual('agenda: y dice cual de los tres es', mo.textContent, 'Presencial');
            ok('agenda: con su dibujo, no solo la palabra', !!mo.querySelector('svg'),
               mo.querySelector('svg') ? 'lo lleva' : 'sin dibujo', 'con dibujo');
          }
          ok('agenda: y no se repite abajo',
             !/Presencial/.test(fi.querySelector('.ci-que').textContent),
             fi.querySelector('.ci-que').textContent, 'sin el modo');
        }
        /* Se vuelve a recoger: dejarla abierta cambiaria lo que miran los
           pasos de despues. */
        ver = document.querySelector('#ciCuerpo tr.viva button');
        if (ver) ver.click();
      }

      /* Con una cita viva no se ofrece pedir otra: la ventana no dejaria. */
      igual('agenda: y no ofrece pedir otra',
            document.getElementById('ciPedir').style.display, 'none');
    } else {
      igual('agenda: sin ninguna, lo dice en vez de dejarlo en blanco',
            (document.getElementById('ciVacia') || {}).textContent,
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

  /* ── y el CIIP contesta ──
     Es la mitad que faltaba. El equipo veía la cita y de qué era, y no
     tenía dónde responder: la política de la base ya se lo permitía y era
     la pantalla la que no lo ofrecía. Un hilo donde sólo una parte puede
     escribir no es una conversación, y eso ya estaba dicho en
     supabase-hilo.sql sobre los adjuntos.

     Se mira en la AGENDA, que es la lista de citas, y que ven los dos: el
     inversionista con las suyas y el equipo con todas. */
  function agendaHilo(){
    /* Sólo el pase 'lleno' tiene una cita en la agenda; en los demás no hay
       ninguna que desplegar. La guarda es por el CASO y no por «si no hay
       fichas, me callo»: lo segundo también se cumple cuando SÍ debería
       haberlas y algo se rompió, y entonces la prueba desaparece en vez de
       ponerse roja. Atada al caso, el rojo llega donde tiene que llegar. */
    if (CASO !== 'lleno') return;
    /* DESPLEGAR PRIMERO. Desde que la agenda es una tabla, la ficha -y con
       ella la conversacion- solo existe cuando se pulsa «Ver la cita».

       Y esto es lo que antes hacia que el bloque entero se saltara en
       silencio: empieza con «if (!fichas.length) return;», asi que sin
       desplegar nada no habria ni una ficha, no habria ningun rojo y las
       nueve comprobaciones de la conversacion DESAPARECERIAN de la cuenta.
       Es el mismo agujero que dejo la tabla de Mis tramites, visto a tiempo
       esta vez. */
    var reng = document.querySelector("#ciCuerpo tr[data-cita=\"k1\"]")
           || document.querySelector("#ciCuerpo tr");
    if (reng && !document.querySelector("#ciCuerpo tr.ci-detalle")){
      var abre = reng.querySelector("button");
      if (abre) abre.click();
    }

    var fichas = document.querySelectorAll('#ciLista .ci-ficha');
    /* SIN «if (!fichas.length) return»: esa guarda hacía desaparecer de la
       cuenta todo lo que viene detrás en vez de ponerlo rojo. Si la agenda
       no se desplegó, eso ES el fallo y hay que decirlo. */
    ok('agenda: al desplegar sale la ficha de la cita',
       fichas.length > 0, fichas.length + ' fichas', 'al menos una');
    if (!fichas.length) return;

    /* Y NINGUNA lleva ya botón de conversar: una cita es fecha, modo y
       estado. Antes se comprobaba lo contrario —que todas lo tuvieran—. */
    igual('agenda: y ninguna lleva ya botón de conversar',
          document.querySelectorAll('#ciLista .ci-habla').length, 0);
  }

  /* El contenido se mira en un paso APARTE, y no es manía: pintaHilo pinta
     la caja al momento pero los mensajes llegan de la base, o sea un tick
     después. Comprobándolo en el mismo instante del clic salía «no hay
     mensajes» con todo bien puesto. La cadena espera medio segundo entre
     pasos, que es justo para esto. */
  function agendaHiloMira(){
    /* Sólo el pase 'lleno' tiene una cita en la agenda; en los demás no hay
       ninguna que desplegar. La guarda es por el CASO y no por «si no hay
       fichas, me callo»: lo segundo también se cumple cuando SÍ debería
       haberlas y algo se rompió, y entonces la prueba desaparece en vez de
       ponerse roja. Atada al caso, el rojo llega donde tiene que llegar. */
    if (CASO !== 'lleno') return;
    /* SIN el «if (!caja || caja.hidden) return» que había aquí: con el hilo
       quitado, esa guarda hacía DESAPARECER estas comprobaciones de la cuenta
       en vez de ponerlas rojas. Es el agujero que este arnés ya se ha comido
       dos veces —una prueba que no corre no es una prueba que pasa—. */
    var ficha = document.querySelector('#ciLista .ci-ficha[data-cita="k1"]');
    ok('agenda: la ficha de la cita se despliega',
       !!ficha, ficha ? 'está' : 'no hay ficha', 'está');
    if (!ficha) return;

    /* Y tampoco lleva conversación del lado del equipo. Lo que el
       inversionista escriba llega a la cola de consultas, que es donde ahora
       llega todo. */
    ok('agenda: y la cita del equipo tampoco lleva conversación',
       !ficha.querySelector('.ci-hilo') && !ficha.querySelector('.hilo'),
       ficha.querySelector('.ci-hilo') ? 'sigue puesta' : 'fuera', 'fuera');
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
  /* ── POR DÓNDE SE ENTRA ──
     Aquí se pulsaba «Por atender», el botón de la barra de arriba. Se retiró:
     el renglón de la barra lateral llevaba a la misma cola y llevaba el mismo
     número, y la ventana se abría por lo alto, obligando a buscar otra vez el
     trámite que ibas a atender.

     Así que este paso entra por donde entra una persona: el renglón de la
     barra abre la cola EN TABLA, y el renglón de un trámite abre la ventana
     por ese trámite. Es asíncrono —declara «sigue»— porque la tabla pide su
     cola al entrar y las filas llegan después.

     Que al inversionista no se le ofrezca esto ya no se mira aquí, y no se
     ha perdido: su renglón dice «Mis trámites» y le lleva a su lista -eso lo
     miran 'barra: y al inversionista le abre su lista'- y la dirección
     #poratender no le entra -'tabla: al inversionista la cola del equipo no
     le entra'-. */
  function colaAbre(sigue){
    if (CASO !== 'gestor') return sigue();

    /* Dos citas, dos trámites y dos consultas: el contador es "cuánto tienes
       encima", y desde que se puede hablar con el CIIP sin pedir cita, las
       consultas son trabajo igual que lo demás. La tercera del ejemplo está
       resuelta y por eso NO cuenta: resuelta ya no es cola.

       Se mira en el renglón de la barra, que desde que no hay botón arriba
       es el único sitio donde el equipo ve esto sin entrar. */
    igual('cola: el renglón de la barra lleva cuántas esperan',
          (document.getElementById('navTramitesN') || {}).textContent, '6');

    document.getElementById('navTramites').click();
    esperaFilas('#paCuerpo tr', 1, function(){
      var filas = document.querySelectorAll('#paCuerpo tr');
      ok('cola: la tabla trae los que esperan', filas.length > 0,
         filas.length + ' renglones', 'al menos uno');
      if (filas.length) filas[0].click();
      var caja = document.getElementById('colaBack');
      ok('cola: y el renglón de un trámite abre su ventana',
         caja.classList.contains('open'), caja.className, 'con la clase open');
      /* Se vuelve a la portada por debajo de la ventana: los pasos de la
         cola que vienen detrás trabajan sobre la ventana, y dejarlos con la
         tabla puesta detrás cambiaría el suelo de los que van después. */
      if (location.hash) location.hash = '';
      sigue();
    });
  }

  function colaConfirma(){
    if (CASO !== 'gestor') return;
    var fichas = document.querySelectorAll('#colaLista .co-ficha');
    igual('cola: enseña las dos que esperan', fichas.length, 2);

    /* La más vieja primero: una cola que empieza por lo recién llegado deja
       lo de hace un mes al final para siempre.

       Se mira el IDENTIFICADOR y no la fecha escrita. Antes ponía
       indexOf('10 ago'), y eso no comprobaba el orden: comprobaba el
       almanaque. El día que las fechas del expediente dejaron de estar
       clavadas, esta se puso roja sin que el orden hubiera cambiado. q1 es la
       vieja y q2 la nueva, y eso es verdad se corra el día que se corra. */
    igual('cola: la más vieja va primero',
          fichas[0].getAttribute('data-cita'), 'q1');

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

  /* ── la conversación, del lado del equipo ──
     En su propio paso porque el hilo se carga DESPUÉS de desplegar el
     expediente, y colaTramites despliega y comprueba en el mismo. Los
     datos se pintan a la vez; la conversación llega de la base. */
  function colaHiloEspera(sigue){
    if (CASO !== 'gestor') return sigue();
    esperaFilas('#colaTram .co-ficha .co-exp .hilo-m', 2, sigue);
  }

  function colaHiloMira(){
    if (CASO !== 'gestor') return;
    var exp = document.querySelectorAll('#colaTram .co-ficha')[0].querySelector('.co-exp');
    if (!exp) return;

    /* El equipo podía escribir desde el primer día —la política se lo
       permitía y hay prueba de ello en Postgres— pero no tenía dónde: la
       cola enseñaba el expediente sin el hilo, así que la mitad de la
       conversación era una función sin pantalla. */
    ok('cola: el expediente termina con la conversación',
       !!exp.querySelector('.hilo-lista'),
       exp.querySelector('.hilo-lista') ? 'está' : 'no hay hilo', 'está');

    /* Y CON lo que ya se había dicho. Un hilo vacío del lado del gestor
       sería peor que ninguno: parecería que el inversionista no ha
       preguntado nada. */
    ok('cola: y con lo que ya se había dicho, no en blanco',
       exp.querySelectorAll('.hilo-m').length >= 2,
       exp.querySelectorAll('.hilo-m').length + ' líneas', 'al menos 2');

    ok('cola: con la caja para contestar',
       !!exp.querySelector('.hilo-txt'),
       exp.querySelector('.hilo-txt') ? 'está' : 'no hay caja', 'está');
  }

  function colaTramites(){
    if (CASO !== 'gestor') return;
    var fichas = document.querySelectorAll('#colaTram .co-ficha');
    igual('cola: enseña los trámites que esperan por el CIIP', fichas.length, 2);

    /* El contador es "cuánto tienes encima", no "cuántas citas": dos citas,
       dos trámites y dos consultas. */
    igual('cola: y el contador suma las tres colas',
          (document.getElementById('navTramitesN') || {}).textContent, '6');

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

  /* ═══════════ CUÁNTO LLEVA PARADO ═══════════
     La cola ya venía del más viejo al más nuevo, pero ese orden no decía
     por qué. Un número al lado lo convierte en una razón.

     Es un HECHO y no un plazo: el CIIP no ha dicho todavía cuánto debería
     tardar cada trámite, y pintar de rojo a los ocho días sería inventar
     una promesa que nadie hizo. Por eso va en gris. */
  function colaLleva(){
    if (CASO !== 'gestor') return;
    var f = document.querySelectorAll('#colaTram .co-ficha')[0];
    var r = f.querySelector('.lleva');
    ok('cola: cada trámite dice cuánto lleva parado', !!r,
       r ? r.textContent.trim() : 'no hay reloj', 'un reloj');
    ok('cola: y lo dice en días, no en una fecha que hay que restar',
       /días|día|mes|hora/.test(r.textContent),
       r.textContent.trim(), 'algo como "hace 12 días"');
    /* Sin color de alarma: en cuanto se pinte de rojo deja de ser un dato
       y pasa a ser un juicio, y ese juicio no lo hemos pedido a nadie. */
    ok('cola: y sin color de alarma, que sería una promesa',
       !/warn|mal|rust|alarma/.test(r.className), r.className, 'solo "lleva"');

    /* NUNCA hacia el futuro. La hora la pone el servidor y el navegador
       puede ir unos segundos por detras: este trámite trae la suya 37
       segundos adelantada, y salía como "esperando desde dentro de 37
       segundos". Un trámite que lleva esperando desde dentro de medio
       minuto no existe. */
    ok('cola: y nunca dice que lleva esperando desde el futuro',
       !/dentro de|in \d/.test(r.textContent), r.textContent.trim(),
       'algo en pasado, o "ahora"');
  }

  /* ═══════════ QUIÉN LLEVA CADA TRÁMITE ═══════════
     La cola era un montón común: todos veían todo y nadie era responsable
     de nada en concreto. La columna estaba en la base desde el principio
     y no la usaba nadie. */
  function colaReparto(){
    if (CASO !== 'gestor') return;
    var fichas = document.querySelectorAll('#colaTram .co-ficha');
    igual('reparto: cada trámite dice quién lo lleva',
          [].filter.call(fichas, function(f){ return f.querySelector('.co-duenio'); }).length, 2);
    ok('reparto: el que no lleva nadie lo dice',
       /Sin asignar/.test(fichas[0].textContent),
       fichas[0].querySelector('.co-duenio').textContent.trim(), 'Sin asignar');
    /* Y el de otro dice SU NOMBRE, no un identificador. Una cola de
       trabajo con códigos dentro no la lee nadie. */
    ok('reparto: y el de otro dice su nombre',
       /Saskia Calderon/.test(fichas[1].textContent),
       fichas[1].querySelector('.co-duenio').textContent.trim(), 'Lo lleva Saskia Calderon');

    /* Los tres montones, con su cuenta. */
    var fil = document.querySelectorAll('#colaFiltros button');
    igual('reparto: hay tres montones', fil.length, 3);
    igual('reparto: y cada uno dice cuántos tiene',
          [].map.call(fil, function(b){ return b.textContent.trim(); }).join(' | '),
          'Todos2 | Sin asignar1 | Míos0');

    /* Tomar uno. NO es un cerrojo: lo único que cambia es el nombre. */
    fichas[0].querySelector('.co-duenio button').click();
  }

  function colaTrasTomar(){
    if (CASO !== 'gestor') return;
    var fichas = document.querySelectorAll('#colaTram .co-ficha');
    ok('reparto: al tomarlo pasa a ser tuyo',
       /Lo llevas tú/.test(fichas[0].textContent),
       fichas[0].querySelector('.co-duenio').textContent.trim(), 'Lo llevas tú');
    ok('reparto: y el botón pasa a ofrecer soltarlo',
       /Soltarlo/.test(fichas[0].querySelector('.co-duenio button').textContent),
       fichas[0].querySelector('.co-duenio button').textContent, 'Soltarlo');
    /* Y sigue en la cola: tomar no es resolver. Con la regla vieja del
       falso -que saca el tramite al actualizarlo- habria desaparecido. */
    igual('reparto: y sigue en la cola, que tomar no es resolver', fichas.length, 2);
    /* La cuenta de los montones se mueve con él. */
    var fil = document.querySelectorAll('#colaFiltros button');
    igual('reparto: y las cuentas se mueven con él',
          [].map.call(fil, function(b){ return b.textContent.trim(); }).join(' | '),
          'Todos2 | Sin asignar0 | Míos1');

    /* Filtrar por "Míos" deja solo el tuyo. */
    fil[2].click();
    igual('reparto: "Míos" enseña solo el tuyo',
          document.querySelectorAll('#colaTram .co-ficha').length, 1);
    /* Un filtro que deja la lista vacía tiene que decirlo: si no, "Sin
       asignar" sin ninguno se lee como "la cola está vacía" y alguien se
       va a casa creyendo que no hay nada que hacer. */
    fil[1].click();
    ok('reparto: y un montón vacío lo dice, no finge una cola vacía',
       document.querySelectorAll('#colaTram .co-vacia').length === 1,
       document.querySelectorAll('#colaTram .co-ficha').length + ' fichas', 'el aviso');
    fil[0].click();
    igual('reparto: y "Todos" los devuelve',
          document.querySelectorAll('#colaTram .co-ficha').length, 2);
    /* Se suelta para dejarlo como estaba: los pasos que vienen después
       devuelven y confirman, y una cola filtrada los descolocaría. */
    document.querySelectorAll('#colaTram .co-ficha')[0]
      .querySelector('.co-duenio button').click();
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
    igual('cola: el contador baja', (document.getElementById('navTramitesN') || {}).textContent, '5');
  }


  /* ── LOS TOKENS, Y QUE LA HOJA DE SHADCN SEA LA QUE MANDA ──────────────
     Esta tanda nace de un fallo que las otras 4116 pruebas no vieron: un
     comentario nuevo se metio DENTRO de otro comentario, su cierre remato
     el de fuera antes de tiempo, y el texto que quedaba suelto se comio la
     linea de --navy. Resultado: todos los botones azules del panel pasaron
     a ser blancos sobre blanco -invisibles- y el arnes siguio en verde,
     porque nadie miraba el COLOR con el que sale nada.

     Y de un segundo fallo: el bloque de forma se escribio al final del
     primer <style>, pero la hoja de verdad es el segundo. Todas sus reglas
     de la misma fuerza perdian contra las de abajo y no hacian nada, sin
     un solo error en la consola. */
  /* ── EL TEMA SE ELIGE UNA VEZ, NO CADA VEZ ──
     El interruptor cambiaba el tema y no lo guardaba: al recargar no
     quedaba nada escrito y se caía en lo que dijera el sistema operativo.
     En una máquina en oscuro, el panel amanecía en negro por más veces
     que lo pusieras en claro.

     Y abre en CLARO por decisión del CIIP, no siguiendo al sistema: la
     ventanilla se enseña, se proyecta y se imprime.

     No se puede recargar la página desde aquí, así que se comprueban las
     dos mitades por separado: que el atributo esté puesto al arrancar
     -que es lo que decide el primer color- y que pulsar deje escrito lo
     elegido, que es lo que leerá la próxima carga. */
  function temaMira(){
    var root = document.documentElement;
    var btn = document.getElementById('themeBtn');

    ok('tema: el panel arranca con un tema decidido, no al azar',
       root.getAttribute('data-theme') === 'light',
       JSON.stringify(root.getAttribute('data-theme')), '"light"');

    if (!btn){
      ok('tema: y la elección se guarda para la próxima vez', false,
         'no hay botón de tema', 'con su botón');
      return;
    }

    var antes = root.getAttribute('data-theme');
    var guardadoAntes = null;
    try { guardadoAntes = window.localStorage.getItem('ciip_tema'); } catch(e){}

    btn.click();
    var ahora = root.getAttribute('data-theme');
    var enDisco = null;
    try { enDisco = window.localStorage.getItem('ciip_tema'); } catch(e){}

    ok('tema: al pulsar cambia',
       ahora !== antes && (ahora === 'dark' || ahora === 'light'),
       antes + ' → ' + ahora, 'el otro');
    /* LO QUE FALTABA: que quede ESCRITO. Sin esto el botón funcionaba y
       la siguiente carga se lo comía. */
    ok('tema: y la elección se guarda para la próxima vez',
       enDisco === ahora,
       'en pantalla ' + ahora + ', guardado ' + JSON.stringify(enDisco),
       'los dos iguales');

    /* Se deja como estaba: el resto de la tanda mide colores. */
    btn.click();
    try {
      if (guardadoAntes === null) window.localStorage.removeItem('ciip_tema');
      else window.localStorage.setItem('ciip_tema', guardadoAntes);
    } catch(e){}
    root.setAttribute('data-theme', antes);
  }

  function tokensMiran(){
    /* Uno: ninguna variable que la hoja usa puede estar sin declarar. Si
       una se pierde, var(--x) se queda en nada y lo que dependia de ella
       cae al valor de fabrica, casi siempre transparente. */
    var texto = '';
    [].forEach.call(document.querySelectorAll('style'), function(h){ texto += h.textContent; });
    /* A mano y sin expresión regular: la hoja es un archivo enorme y una
       barra invertida de menos aquí no da error, da una regla que corre y
       no encuentra nada. Buscando el texto tal cual, eso no puede pasar. */
    var usados = {}, trozos = texto.split('var(');
    for (var k = 1; k < trozos.length; k++){
      var t = trozos[k], i = 0;
      while (i < t.length && t.charCodeAt(i) <= 32) i++;
      if (t.charAt(i) !== '-' || t.charAt(i + 1) !== '-') continue;
      var f = i;
      while (f < t.length && t.charCodeAt(f) > 32 && ',)('.indexOf(t.charAt(f)) < 0) f++;
      /* Sólo cuentan las que NO llevan valor de reserva: var(--x, algo)
         sigue pintando aunque --x se pierda, así que exigirle que exista
         daría rojos que no son fallos. */
      var resto = f, hueco = 0;
      while (resto < t.length && t.charCodeAt(resto) <= 32) { resto++; hueco++; }
      if (t.charAt(resto) !== ')') continue;
      usados[t.slice(i, f)] = 1;
    }
    var raiz = window.getComputedStyle(document.documentElement), sueltas = [];
    Object.keys(usados).forEach(function(n){
      if (!raiz.getPropertyValue(n).trim()) sueltas.push(n);
    });
    var cuantas = Object.keys(usados).length;
    ok('tokens: la hoja usa variables de verdad, no dos sueltas',
       cuantas >= 20, cuantas + ' variables', '20 o mas');
    ok('tokens: y todas las que usa estan declaradas',
       sueltas.length === 0, sueltas.length ? sueltas.join(', ') : 'ninguna suelta',
       'ninguna suelta');

    /* Dos: el azul del CIIP, medido donde se ve. Que --navy exista no basta;
       lo que importa es que el boton salga azul. */
    /* Se mira un botón AZUL de verdad y ya no el de la etapa: ése pasó a ser
       un enlace -sin fondo- al bajar la altura de las cuatro tarjetas, y
       seguir midiéndolo aquí habría convertido esta prueba en un rojo fijo
       sobre algo que está bien. Lo que tiene que seguir siendo cierto es
       que el azul del CIIP llega a la pantalla, y eso lo dice cualquier
       botón principal. */
    var btn = document.querySelector('.btn.navy') || document.querySelector('.btn');
    igual('tokens: el botón principal sale del azul del CIIP',
          btn ? window.getComputedStyle(btn).backgroundColor : '(no hay botón)',
          'rgb(0, 64, 144)');

    /* Tres: la capa de shadcn manda. .t-name lo trae la hoja en 700 y el
       bloque de shadcn lo baja a 600; si el bloque volviera a caer en un
       <style> que no manda, esto sale 700 y no 600. */
    var nom = document.querySelector('.t-name') || document.querySelector('.jname');
    igual('tokens: y el bloque de shadcn es el que manda, no el de arriba',
          nom ? window.getComputedStyle(nom).fontWeight : '(no hay título)', '600');

    /* Cuatro: el contador de la pestaña encendida. Era blanco porque la
       pestaña era azul; al volverse blanca la pestaña, el numero se
       borraba. Se mira que su letra NO sea blanca. */
    var enc = document.querySelector('#filters .ftab.on .n');
    var col = enc ? window.getComputedStyle(enc).color : '(no hay)';
    ok('tokens: el contador de la pestaña encendida se ve',
       col !== 'rgb(255, 255, 255)' && col !== '(no hay)', col, 'un color que no sea blanco');
  }
  function colaTrasConfirmar(){
    if (CASO !== 'gestor') return;
    igual('cola: confirmada, sale de la cola', document.querySelectorAll('#colaLista .co-ficha').length, 1);
    /* Quedan una cita y un trámite: se devolvió uno antes y ahora se
       confirmó una. El contador cuenta las dos colas juntas. */
    igual('cola: y el contador baja', (document.getElementById('navTramitesN') || {}).textContent, '4');
  }

  /* Al cancelar, la caja se queda limpia del todo: ni conversación —que ya
     no hay— ni la puerta, que sin cita no lleva a ningún sitio con sentido. */
  function hiloCitaTrasAnular(){
    if (CASO === 'gestor') return;
    var caja = document.getElementById('ctHilo');
    ok('cita: al cancelarla, la caja se queda limpia',
       !!caja && !caja.querySelector('.ct-hablar') && !caja.querySelector('.hilo'),
       caja ? (caja.textContent.trim() ? 'queda algo' : 'limpia') : 'no existe',
       'limpia');
    ok('cita: y no se queda apuntando a la cita cancelada',
       !!caja && !caja.hasAttribute('data-cita'),
       caja ? (caja.getAttribute('data-cita') || 'sin apuntar') : 'no existe',
       'sin apuntar');
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
