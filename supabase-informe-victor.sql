-- ═══════════════════════════════════════════════════════════════════════
--  LO QUE PIDIÓ LA REVISIÓN DEL 2 DE SEPTIEMBRE DE 2026
--  Va DESPUÉS de supabase-tramites.sql y de supabase-encadenado.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE ESTE ARCHIVO
--  ─────────────────────────────────────────────────────────────────────
--  Del informe «Portal CIIP · Primer avance» de Víctor A. J. Corredor
--  Suárez, del 2 de septiembre de 2026. Se recoge aquí lo que se puede
--  ejecutar; lo que necesita una decisión del CIIP —los plazos legales de
--  Gaceta, la matriz de sector a permisos, el pliego de datos— no está y
--  está dicho al final, para que no parezca hecho.
--
--  Cada cambio lleva la frase del informe que lo pide. Sin eso, dentro de
--  seis meses nadie sabrá por qué el RNC cambió de fase.
-- ═══════════════════════════════════════════════════════════════════════


-- ═══════════════════════════════════════════════════════════════════════
--  CUÁLES SON LOS OBLIGATORIOS
-- ═══════════════════════════════════════════════════════════════════════
--  Los UPDATE de más abajo van repartidos, cada uno pegado a la frase del
--  informe que lo justifica, que es como tiene que estar. Pero entonces
--  para contestar «cuáles son los obligatorios» hay que leerse el archivo
--  entero y sumar de cabeza. Aquí están juntos.
--
--  Esta lista NO ejecuta nada: es el resumen de lo que hacen los UPDATE.
--  Si alguna vez no cuadran, mandan los UPDATE y esta lista está vieja;
--  la comprobación 1 del final los cuenta contra la base.
--
--  OBLIGATORIO quiere decir una cosa concreta y sólo una: **sin esto el
--  CIIP no puede seguir contigo**. No quiere decir que sea importante, ni
--  que lo exija la ley. El registro de marca lo exige la ley y no es
--  obligatorio aquí, porque el CIIP puede reconocer a la empresa sin él.
--
--
--  FASE 1 · TÚ  ──  cinco, y son los cinco que pide el informe
--  ─────────────────────────────────────────────────────────────────────
--    c1   visa_inversionista      Visa de inversionista (TR-I)   punto 1
--    c2   cedula_residencia       Cédula de extranjería          punto 4
--    c3   rif_personal            RIF personal                   punto 4
--    c17  apostilla_documentos    Documentación apostillada      punto 3
--    c33  poder_representacion    Acreditación del apoderado     puntos 2 y 5
--
--  El punto 3 del informe —«Partidas, antecedentes y credenciales
--  básicas»— cae sobre DOS tarjetas nuestras, y el CIIP escogió la
--  apostilla: es el servicio que deja cualquier papel personal en regla.
--  Los antecedentes penales (c16) se quedan opcionales porque no todos
--  los consulados los exigen igual. Está contado abajo, en su UPDATE.
--
--  Y el c33 no existía: sale del punto 4 de este archivo, el módulo de
--  apoderados. Es obligatorio porque, según el propio informe, el panel
--  «será utilizado por sus asistentes, administradores, abogados en la
--  mayoría de los casos» —y sin poder acreditado el CIIP no sabe con
--  quién está hablando.
--
--
--  FASE 2 · TU EMPRESA  ──  cinco
--  ─────────────────────────────────────────────────────────────────────
--    c32  registro_extranjeros    Firma en Registro de Extranjeros (SISREF)
--    c5   constitucion            Constitución de la empresa
--    c22  protocolizacion_acta    Protocolización del documento
--    c23  publicacion_acta        Publicación en prensa
--    c6   rif_empresa             RIF jurídico
--
--  El informe lo resume en una frase: «Al tener el documento otorgado en
--  Registro Mercantil y tramitar el RIF, lo demás no es obligatorio para
--  seguir los procesos con el CIIP». Los otros tres —c22, c23 y c32— no
--  son trámites aparte de ése: son las tres condiciones sin las cuales
--  ese documento no queda otorgado. El c32 va primero de todos porque es
--  «condición previa de estricto cumplimiento» para que un extranjero
--  pueda siquiera comparecer a firmar.
--
--
--  FASES 3, 4 y 5  ──  NINGUNO, y es a propósito
--  ─────────────────────────────────────────────────────────────────────
--  Ni un solo obligatorio, y no es un olvido. Los once de la fase 3 son
--  todos 'actividad': dependen del ramo, y el informe avisa de que
--  «cargar de oficio permisos ambientales o sanitarios a inversiones del
--  sector tecnológico crea confusión innecesaria». Marcar uno como
--  obligatorio sería decirle a una empresa de software que necesita
--  permiso sanitario.
--
--  El día que exista la matriz de sector a permisos —punto 2 de lo que
--  falta, al final de este archivo— serán obligatorios para unos sectores
--  y no para otros. Hasta entonces, ninguno lo es para todos.
--
--  Consecuencia visible: en esas tres fases el panel no pinta el renglón
--  de «te faltan N obligatorios». No es que falte código; es que no hay
--  nada que contar, y un «te faltan 0 de 0» sería ruido con cara de aviso.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL RNC PASA DE «CRECER» A «OPERAR»
-- ───────────────────────────────────────────────────────────────────────
--  «Actualmente visible en la Fase 4 ("Crecer"), el RNC (Servicio Nacional
--   de Contrataciones) debe figurar en esta Fase 3 ("Operar"). Gran parte
--   de las inversiones canalizadas por el CIIP conllevan contratos marco
--   de producción compartida, alianzas estratégicas o contratación de
--   bienes y servicios con entidades estatales, siendo la calificación en
--   el RNC un requerimiento operativo habilitante desde el primer momento
--   contractual.»
--
--  Va aparte del INSERT del catálogo y no dentro: aquel lleva ON CONFLICT
--  DO NOTHING y en una base que ya existe no tocaría nada.
update public.tipos_tramite set fase = 3 where codigo = 'rnc';


-- ───────────────────────────────────────────────────────────────────────
-- 2. TRES NIVELES DONDE HABÍA UNO
-- ───────────────────────────────────────────────────────────────────────
--  «La idea es que a la vista el inversionista no sienta que debe
--   concretar todos los trámites para poder iniciar un proceso de
--   negociación ante el CIIP.»
--
--  «Algunos ítems deberán ser plasmados como obligatorios y otros como
--   requisitos indispensables o esenciales.»
--
--  Hoy las treinta y una tarjetas se ven iguales, y eso es lo que hace
--  que la primera pantalla parezca un muro. La columna no cambia lo que
--  se puede solicitar —eso lo sigue diciendo `activo`— sino lo que se
--  ANUNCIA de cada trámite.
--
--  Los tres niveles son los tres que nombra el informe:
--
--    obligatorio   sin esto el CIIP no puede seguir contigo
--    esencial      indispensable para comerciar, pero NO bloquea al CIIP
--    actividad     depende del ramo; puede que a ti no te toque
--    opcional      solo si te hace falta a ti
--
--  El tercero sale de: «las empresas dependen del rubro al que pertenezcan
--  y su modelo comercial requerirán más o menos permisos».
--
--  El cuarto es distinto del tercero y por eso no se juntan. «Según tu
--  actividad» habla del RAMO —una empresa de software no necesita permiso
--  sanitario— y «opcional» habla de TI: la homologación de la licencia de
--  conducir sólo le hace falta a quien va a conducir, y la visa de
--  dependientes a quien trae familia. Decirle «según tu actividad» a quien
--  no trae familia sería mandarle a averiguar algo que no depende de su
--  sector, y quedarse mirando la tarjeta.

--  QUÉ HACE EL PANEL CON CADA NIVEL
--  ─────────────────────────────────────────────────────────────────────
--  Una columna que nadie mira no arregla ninguna pantalla. Esto es lo que
--  el panel hace con ella, decidido por el CIIP el 2 de septiembre:
--
--    obligatorio   se ve siempre, con su galón, y se cuenta en el renglón
--                  «te faltan N de T obligatorios» de la cabecera de la fase
--    esencial      no lleva galón, y se queda A LA VISTA
--    opcional      galón suave; se va detrás de «Ver los N opcionales»
--    actividad     galón «según tu actividad», y NO se aparta nunca
--
--  Lo 'esencial' llegó a apartarse, apoyándose en la frase del informe
--  sobre la marca, la cuenta bancaria y los libros —«no representan
--  trabas bloqueantes»—, y la fase 2 se quedó enseñando cinco de ocho.
--  El CIIP lo deshizo el mismo día: «dicha etapa es la más importante en
--  el panel [...] quiero que tenga estas 8 opciones». Constituir la
--  empresa es lo que la ventanilla viene a hacer, y ahí un trámite detrás
--  de un botón es un trámite que no se ve.
--
--  O sea que hoy el botón sale en la fase 1 y sólo en ella, que es donde
--  hay opcionales de verdad.
--
--  Las dos reglas que no son obvias, y las dos son por lo mismo:
--
--  1. Una fase sin ningún obligatorio no aparta NADA. Las once tarjetas de
--     la fase 3 dependen del ramo; con la regla ingenua se irían las once
--     detrás de un botón y la fase quedaría vacía. Eso no es apartar, es
--     esconder once permisos.
--
--  2. Lo de 'actividad' no se aparta ni cuando la fase sí aparta. «Según tu
--     actividad» avisa de que puede que a ti no te toque; esconderle el
--     permiso sanitario a quien sí lo necesita es peor que enseñárselo de
--     más. Con el catálogo de hoy esa regla no llega a usarse —las doce de
--     'actividad' están en fases sin obligatorios—, pero el día que exista
--     la matriz de sector a permisos sí, y entonces es la que importa.
--
--  Nada de esto filtra ni impide solicitar: lo que se puede solicitar lo
--  sigue diciendo la columna `activo`, y todo trámite apartado sigue
--  estando a un clic.
--
alter table public.tipos_tramite
  add column if not exists nivel text not null default 'esencial';

alter table public.tipos_tramite
  drop constraint if exists tipos_tramite_nivel_valido;
alter table public.tipos_tramite
  add  constraint tipos_tramite_nivel_valido
  check (nivel in ('obligatorio', 'esencial', 'actividad', 'opcional'));

comment on column public.tipos_tramite.nivel is
  'obligatorio = el CIIP no sigue sin el; esencial = hace falta para comerciar pero no bloquea; actividad = segun el ramo; opcional = solo si te hace falta a ti. Del informe del 2 de septiembre de 2026';


-- ── los obligatorios de la fase 1 ──
--  «Recomiendo colocar trámites obligatorios para este proceso como lo
--   pueden ser: 1. Visa de Inversionista (TR-I) [...] 2. Documento de
--   Identidad y Poder de Representación Legal [...] 3. Documentación
--   Personal Apostillada / Legalizada: Partidas, antecedentes y
--   credenciales básicas [...] 4. Cédula de Extranjería / Transeúnte y
--   RIF Personal [...] 5. Poder de Representación Legal.»
--  Son CINCO y no seis, y la diferencia la decidio el CIIP el 2 de
--  septiembre: el punto 3 del informe -«Partidas, antecedentes y
--  credenciales basicas»- cae sobre DOS tarjetas nuestras, la de
--  antecedentes penales y la de apostilla. Se queda obligatoria la de
--  APOSTILLA, que es el servicio que deja cualquier papel personal en
--  regla; los antecedentes pasan a opcional porque no todos los
--  consulados los exigen igual.
update public.tipos_tramite set nivel = 'obligatorio'
 where codigo in ('visa_inversionista',      -- 1
                  'cedula_residencia',       -- 4, "cedula de extranjeria / transeunte"
                  'rif_personal',            -- 4
                  'apostilla_documentos',    -- 3, "documentacion personal apostillada"
                  'poder_representacion');   -- 2 y 5, el modulo nuevo de mas abajo

-- ── y los obligatorios de la fase 2 ──
--  «Al tener el documento otorgado en Registro Mercantil y tramitar el
--   RIF, lo demás no es obligatorio para seguir los procesos con el CIIP
--   para concretar la inversión.»
--
--  O sea: lo que el CIIP necesita para reconocer a la empresa es el
--  documento constitutivo protocolizado y el RIF jurídico. La publicación
--  en prensa entra porque sin ella la protocolización no está completa.
update public.tipos_tramite set nivel = 'obligatorio'
 where codigo in ('registro_extranjeros_saren',  -- condicion previa, ver abajo
                  'constitucion',
                  'protocolizacion_acta',
                  'publicacion_acta',
                  'rif_empresa');

-- ── los que son esenciales pero NO bloquean ──
--  «Se debe delimitar claramente que el Registro de Marca, la apertura de
--   la Cuenta Bancaria Empresarial y el sellado de Libros Contables /
--   Facturación corresponden a condiciones indispensables para el
--   comercio, más no representan trabas bloqueantes para que el CIIP
--   reconozca la personalidad jurídica de la empresa una vez
--   protocolizado el documento e inscrito el RIF Jurídico.»
update public.tipos_tramite set nivel = 'esencial'
 where codigo in ('marca', 'cuenta_bancaria', 'libros_contables');

-- ── y los que dependen del ramo ──
--  «Todos esos requisitos son esenciales para algunos procesos sin embargo
--   acá no están todos los que se requieren según ciertas actividades de
--   comercio.»
--
--  «Cargar de oficio permisos ambientales o sanitarios a inversiones del
--   sector tecnológico o servicios financieros crea confusión
--   innecesaria.»
--
--  Marcarlos NO es filtrarlos: se siguen viendo todos. Lo único que
--  cambia es que la tarjeta avisa de que puede que a ti no te toque, que
--  es lo contrario de esconder un trámite que sí hacía falta.
update public.tipos_tramite set nivel = 'actividad'
 where codigo in ('permiso_sanitario', 'permiso_ambiental', 'permiso_bomberos',
                  'conformidad_uso', 'licencia_municipal', 'comercio_exterior',
                  'registros_laborales', 'faov_banavih', 'inces', 'rnet',
                  'rnc', 'solvencias');

-- ── y los cinco de la fase 1 que no son obligatorios ──
--  «Estos trámites quiero ponerlos como obligatorios en la fase uno y los
--   demás como opcionales.»  (CIIP, 2 de septiembre de 2026)
--
--  Van a 'opcional' y no a 'actividad' a proposito. Los cinco dependen de
--  la persona y no del ramo: la homologacion de la licencia solo le hace
--  falta a quien va a conducir, la visa de dependientes a quien trae
--  familia, y el certificado medico y la constancia de domicilio solo
--  cuando se los pida el tramite que los use.
--
--  Es lo que arregla la primera pantalla: de once tarjetas iguales pasa a
--  CINCO que hacen falta y SEIS que dicen «solo si te toca». Que era
--  exactamente lo que pedia el informe -«que a la vista el inversionista
--  no sienta que debe concretar todos los tramites»- y que marcarlas como
--  «segun tu actividad» no conseguia: eso manda a averiguar algo que no
--  depende del sector.
update public.tipos_tramite set nivel = 'opcional'
 where codigo in ('licencia_conducir',      -- c4   solo si vas a conducir
                  'antecedentes_penales',   -- c16  ver la nota de los obligatorios
                  'constancia_domicilio',   -- c18
                  'firma_electronica',      -- c19
                  'visa_dependientes',      -- c20  solo si traes familia
                  'cert_medico');           -- c21


-- ───────────────────────────────────────────────────────────────────────
-- 3. EL TRÁMITE QUE FALTABA: LA FIRMA EN EL REGISTRO DE EXTRANJEROS
-- ───────────────────────────────────────────────────────────────────────
--  «Se evidencia la ausencia crítica de la "Solicitud de Firma en Registro
--   de Extranjeros" a través del sistema SISREF del SAREN. Este paso
--   constituye una condición previa de estricto cumplimiento para que
--   personas naturales extranjeras puedan comparecer al otorgamiento del
--   documento constitutivo ante el Registro Mercantil.»
--
--  Se comprobó antes de escribir esto: no estaba, ni en tipos_tramite ni
--  en pasos.js. Y no es un trámite más de la lista. Sin él, el panel deja
--  empezar la constitución y el Registro Mercantil no deja firmar,
--  después de haber pagado el abogado y redactado el documento.
--
--  Por eso entra encadenado: EMITE la constancia de firma, y la
--  constitución la PIDE. Así la tarjeta del c5 dirá «esperando a» en vez
--  de dejar entrar a ciegas. Ver supabase-encadenado.sql.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('constancia_sisref', 'Constancia de firma en el Registro de Extranjeros (SISREF)', false)
on conflict (codigo) do update set nombre = excluded.nombre;

insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('registro_extranjeros_saren', 'c32',
   'Solicitud de firma en el Registro de Extranjeros',
   'SAREN · SISREF', 2, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite      = 'constancia_sisref',
       -- Es una solicitud en linea con cita; el plazo sale del mismo sitio
       -- que los otros veintitres: de lo que promete la tarjeta.
       plazo_dias = 14,
       nivel      = 'obligatorio',
       activo     = true
 where codigo = 'registro_extranjeros_saren';


-- ───────────────────────────────────────────────────────────────────────
-- 4. EL MÓDULO QUE PIDE PARA LOS APODERADOS
-- ───────────────────────────────────────────────────────────────────────
--  «Siendo que la plataforma será operada mayormente por intermediarios
--   legales, es imperativo habilitar de entrada un módulo para la carga
--   del Poder (General o Especial) debidamente notariado y apostillado, a
--   fin de legitimar la actuación del gestor frente al CIIP.»
--
--  Y antes lo dice más claro todavía, y es la observación de fondo del
--  informe entero: «este panel no será utilizado por los inversionistas,
--  accionistas, comerciantes; será utilizado por sus asistentes,
--  administradores, abogados en la mayoría de los casos».
--
--  El tipo de documento 'poder' ya existía en la bóveda desde el primer
--  día. Lo que no existía era el trámite: un sitio donde el CIIP MIRE ese
--  poder y lo dé por bueno. Subir un papel no es acreditar a nadie.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('poder_representacion', 'c33',
   'Acreditación de representación legal',
   'CIIP', 1, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite      = 'poder',
       plazo_dias = 7,
       nivel      = 'obligatorio',
       activo     = true
 where codigo = 'poder_representacion';


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE EL INFORME PIDE Y AQUÍ **NO** ESTÁ
-- ───────────────────────────────────────────────────────────────────────
--  Se deja escrito para que no se dé por hecho. Ninguna de las cuatro es
--  código: las cuatro necesitan que el CIIP decida algo.
--
--  1. LOS PLAZOS LEGALES.
--     «Se recomienda suprimir de la vista del usuario el plazo en la
--      práctica y conservar de manera exclusiva el plazo legal
--      regulatorio.»
--     El panel NO enseña dos plazos: se comprobó buscándolo. Enseña UN
--     estimado por trámite, y esos números salen del texto de cada
--     tarjeta, no de Gaceta. Para hacer lo que pide hay que sustituir los
--     veinticinco números de supabase-plazos.sql por los legales. Los
--     tiene el CIIP; aquí inventarlos sería peor que no tenerlos.
--
--  2. LA MATRIZ DE SECTOR A PERMISOS.
--     «La plataforma debe condicionar dinámicamente los recaudos según el
--      ramo de actividad.»
--     La columna `perfiles.sector` está puesta y los ocho sectores
--     cargados desde supabase-sectores.sql, que ya avisaba de que no
--     decide qué trámites tocan porque «eso lo dice la normativa, y la
--     normativa la tiene el CIIP». Falta esa matriz. El `nivel =
--     'actividad'` de arriba es lo más honesto que se puede hacer sin
--     ella: avisar de que depende, sin esconder nada.
--
--  3. EL PLIEGO DE DATOS (HABEAS DATA).
--     «Resulta mandatorio redactar y vincular formalmente en la plataforma
--      un pliego de Términos, Condiciones y Políticas de Tratamiento de
--      Datos Personales y Confidenciales.»
--     Es un texto legal. Se puede enlazar y exigir su aceptación en
--     cuanto exista; redactarlo no es cosa de este archivo.
--
--  4. LOS PERMISOS QUE FALTAN EN LA FASE 3.
--     «Acá no están todos los que se requieren según ciertas actividades
--      de comercio.»
--     No dice cuáles. Hasta saberlo no se puede añadir ninguno sin
--     inventarlo.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) El catálogo con su nivel, por fase:
--
--   select fase, nivel, count(*), string_agg(ref_panel, ' ' order by ref_panel)
--   from public.tipos_tramite group by fase, nivel order by fase, nivel;
--
-- 2) Los dos nuevos, con lo que emiten:
--
--   select ref_panel, codigo, nombre, ente, fase, nivel, emite, plazo_dias, activo
--   from public.tipos_tramite where ref_panel in ('c32','c33');
--
-- 3) Los obligatorios, contra la lista de arriba. Tienen que salir DIEZ:
--    cinco en la fase 1 y cinco en la fase 2, y ninguno en las demás.
--
--   select fase, count(*), string_agg(ref_panel, ' ' order by ref_panel)
--   from public.tipos_tramite where nivel = 'obligatorio' group by fase;
--
-- 4) Y el RNC, que tiene que salir en la fase 3:
--
--   select ref_panel, nombre, fase, nivel from public.tipos_tramite where codigo = 'rnc';
