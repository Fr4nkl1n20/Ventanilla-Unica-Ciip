-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · Ventanilla Única del Inversionista
--  Esquema de trámites y bóveda de documentos
-- ═══════════════════════════════════════════════════════════════════════
--
--  CÓMO SUBIRLO:
--    Panel de Supabase → SQL Editor → New query → pega todo esto → Run
--    Requiere que supabase-setup.sql ya esté aplicado (usa public.perfiles).
--
--  Es idempotente: puedes ejecutarlo varias veces sin romper nada.
--
--  ─────────────────────────────────────────────────────────────────────
--  LA IDEA
--  ─────────────────────────────────────────────────────────────────────
--  Lo que hace lento un trámite no es la falta de un panel: es que al
--  inversionista le piden la cédula, el pasaporte y el acta constitutiva
--  UNA Y OTRA VEZ, en cada ente, y cada vez llegan incompletos.
--
--  Por eso los documentos NO cuelgan del trámite. Cuelgan del
--  inversionista, en una bóveda, y cada trámite los toma prestados. El
--  acta que se subió para el SAREN es la misma que pide el SENIAT: se
--  sube una vez, se valida una vez, se reutiliza siempre.
--
--  ─────────────────────────────────────────────────────────────────────
--  LO QUE ESTE ESQUEMA **NO** PRETENDE
--  ─────────────────────────────────────────────────────────────────────
--  El SENIAT no expone una API. Ninguna tabla de aquí "envía" nada a
--  ningún ente. El estado 'ante_el_ente' significa que una persona del
--  CIIP fue y lo presentó. Lo que se gana es que llegue completo,
--  ordenado y sin perseguir a nadie — no que se automatice el trámite.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 0. ¿ESTÁ PUESTO EL PRIMER ARCHIVO?
-- ───────────────────────────────────────────────────────────────────────
-- Sin esto, el primer fallo sería "relation public.perfiles does not
-- exist" en mitad de una función, que no le dice a nadie qué hacer.

do $$
begin
  if to_regclass('public.perfiles') is null then
    raise exception using
      message = 'Falta la tabla public.perfiles',
      hint    = 'Ejecuta primero supabase-setup.sql en este mismo proyecto, y luego vuelve a correr este archivo.';
  end if;
end;
$$;


-- ───────────────────────────────────────────────────────────────────────
-- 0.1 QUIÉN ES DEL EQUIPO
-- ───────────────────────────────────────────────────────────────────────
-- Varias políticas necesitan saber si quien pregunta es del CIIP. Si lo
-- consultaran leyendo public.perfiles directamente, RLS se llamaría a sí
-- mismo en bucle. security definer se salta RLS y corta la recursión.
--
-- stable = Postgres puede cachearla dentro de la misma consulta, así no
-- se repite la lectura del perfil por cada fila evaluada.

create or replace function public.es_gestor()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles
    where id = auth.uid() and rol in ('gestor','admin')
  );
$$;

comment on function public.es_gestor is 'true si quien consulta es del equipo del CIIP (gestor o admin)';


-- ───────────────────────────────────────────────────────────────────────
-- 1. CATÁLOGO DE TIPOS DE DOCUMENTO
-- ───────────────────────────────────────────────────────────────────────
-- Los tipos son datos, no cadenas sueltas repartidas por el código. Así
-- se añade un recaudo nuevo con un INSERT, sin tocar la aplicación.

create table if not exists public.tipos_documento (
  codigo    text primary key,
  nombre    text    not null,
  vence     boolean not null default false,
  creado_en timestamptz not null default now()
);

comment on table  public.tipos_documento       is 'Recaudos que la ventanilla sabe recibir';
comment on column public.tipos_documento.vence is 'true si el documento caduca; obliga a pedir fecha de vencimiento';

insert into public.tipos_documento (codigo, nombre, vence) values
  ('cedula',            'Cédula de identidad',                    true),
  ('pasaporte',         'Pasaporte',                              true),
  ('visa',              'Visa',                                   true),
  ('domicilio',         'Comprobante de domicilio',               false),
  ('foto',              'Fotografía tipo carnet',                 false),
  ('acta_constitutiva', 'Acta constitutiva',                      false),
  ('rif_personal',      'RIF personal',                           true),
  ('rif_empresa',       'RIF de la empresa',                      true),
  ('poder',             'Poder / carta de representación',        true),
  ('traduccion',        'Traducción certificada',                 false),
  ('domicilio_empresa', 'Domicilio fiscal de la empresa',         false),
  -- Recaudos de la visa de inversionista. Los antecedentes penales caducan
  -- (los consulados suelen pedirlos recientes), la constancia de inversión no.
  ('antecedentes',      'Antecedentes penales apostillados',      true),
  ('inversion',         'Constancia de la inversión',             false),
  -- Recaudos de la homologación de licencia. La licencia extranjera y el
  -- certificado médico caducan; la traducción acompaña al documento.
  ('licencia_extranjera','Licencia de conducir extranjera',       true),
  ('certificado_medico','Certificado médico',                     true),
  -- Recaudo de la constitución. Es UNO solo y no dos porque la compañía se
  -- puede constituir aportando dinero (depósito en cuenta) o bienes
  -- (inventario certificado por un contador): son alternativas, y el
  -- formulario exige todos los recaudos que enumera. No caduca: acredita
  -- un hecho de una fecha concreta, no una situación vigente.
  ('comprobante_capital','Comprobante del capital (depósito o inventario)', false),
  -- Recaudo del registro de marca. Se pide siempre, también cuando el
  -- signo es denominativo: el SAPI publica una representación de la marca
  -- en el Boletín de la Propiedad Industrial en todos los casos, así que
  -- una imagen con la palabra escrita también sirve. No caduca.
  ('logo_marca',        'Logotipo o diseño de la marca',          false),
  -- Recaudo de los registros laborales. Es el único de todo el catálogo
  -- que el panel marca como OPCIONAL: una empresa recién constituida se
  -- inscribe en el IVSS, el INCES y el FAOV antes de contratar a nadie,
  -- y todavía no tiene nómina que entregar.
  --
  -- vence = false aunque la nómina cambie cada mes: 'vence' sirve para
  -- documentos con fecha de caducidad impresa, no para los que envejecen.
  -- Que la nómina esté al día es cosa del gestor, no de una fecha.
  ('nomina',            'Nómina de trabajadores',                 false),
  -- Recaudos de la licencia municipal. El del inmueble es UNO solo
  -- aunque el título de propiedad y el contrato de arrendamiento sean
  -- papeles distintos: son alternativas, y cuál de las dos es lo dice el
  -- campo `tenencia` del formulario. Caduca porque un arrendamiento
  -- vence, y una licencia apoyada en un contrato muerto no se renueva.
  --
  -- La conformidad de bomberos va OPCIONAL en el panel: casi todas las
  -- alcaldías la exigen, pero quien acaba de alquilar todavía no ha
  -- pasado la inspección y no podría ni enviar la solicitud.
  --
  -- La conformidad de USO no está en esta lista a propósito: es el primer
  -- paso del c10, no un requisito para empezarlo.
  ('titulo_inmueble',   'Título de propiedad o contrato de arrendamiento', true),
  ('bomberos',          'Conformidad de bomberos',                true),
  -- Recaudos de los seis trámites de la Fase 03 que faltaban frente a la
  -- hoja. La conformidad de uso pasa a ser también un tipo de DOCUMENTO,
  -- no solo un trámite: la produce el c28 y la piden el c10 y el c29.
  -- Caduca porque va atada a un inmueble y a una actividad declarados;
  -- mudarse o cambiar de giro la deja sin valor.
  ('conformidad_uso',   'Conformidad de uso del inmueble',        true),
  -- El plano no caduca: describe el local tal como está construido. Si se
  -- reforma hace falta un plano nuevo, que no es lo mismo que renovarlo.
  ('plano_local',       'Plano o croquis del local',              false),
  -- El contrato de mantenimiento sí caduca, y esa es justo su razón de
  -- ser: bomberos lo pide para saber que los extintores siguen cargados.
  ('mantenimiento_extintores', 'Contrato de mantenimiento de extintores', true),
  -- El estudio de impacto no caduca por fecha sino cuando cambia el
  -- proceso, y eso lo sabe el gestor, no una columna.
  ('impacto_ambiental', 'Estudio de impacto ambiental',           false),
  -- Recaudos del registro de la inversion extranjera (Fase 05).
  --
  -- El comprobante del aporte y el soporte de su origen son DOS tipos y
  -- no uno: el primero acredita que el dinero entro y el segundo de
  -- donde venia. Esa distincion es de lo que vive el tramite, porque de
  -- ella depende poder repatriar despues las utilidades y el capital.
  -- Ninguno de los dos caduca: acreditan un hecho con fecha, no una
  -- situacion vigente.
  ('comprobante_aporte', 'Comprobante del aporte de la inversión',  false),
  ('soporte_fondos',     'Soporte del origen de los fondos',        false),
  -- El proyecto va aparte del acta porque la hoja admite presentarlo EN
  -- LUGAR del documento constitutivo, para quien registra la inversion
  -- antes de constituir. En el panel el acta ya existe cuando se llega a
  -- esta fase, asi que aqui el proyecto entra como recaudo opcional.
  ('proyecto_inversion', 'Proyecto de inversión',                   false),
  -- Recaudos de los seis trámites que faltaban de la Fase 01.
  --
  -- El certificado en bruto que emite el país de origen NO es el mismo
  -- documento que 'antecedentes': aquel es el papel tal como sale de la
  -- policía de allá, y este el mismo ya apostillado y traducido. Uno
  -- ENTRA al trámite y el otro SALE, así que son dos tipos y no uno.
  -- Caduca porque los consulados los piden recientes.
  ('antecedentes_origen','Antecedentes penales del país de origen', true),
  -- Lo mismo con la apostilla: entra el original y sale traducido.
  -- No caduca: una partida de nacimiento acredita un hecho, no una
  -- situación vigente.
  ('documento_original', 'Documento personal original',            false),
  -- Recaudos de la constancia de domicilio. Van los dos: el contrato
  -- dice qué casa es y el recibo dice que alguien vive en ella. El
  -- arrendamiento caduca —un contrato vencido no prueba dónde vives—;
  -- el recibo no lleva fecha de caducidad impresa, así que no.
  ('arrendamiento',     'Contrato de arrendamiento o carta de residencia', true),
  ('recibo_servicio',   'Recibo de un servicio público',          false),
  -- Recaudos de la visa de dependientes. La foto es la DEL FAMILIAR:
  -- reutilizar la del inversionista, que ya está en la bóveda, mandaría
  -- la cara equivocada al consulado.
  ('pasaporte_dependiente','Pasaporte del familiar',              true),
  ('vinculo_familiar',  'Acta que acredita el vínculo familiar',  false),
  ('foto_dependiente',  'Fotografía tipo carnet del familiar',    false),
  -- Recaudos de la Fase 02. El acta protocolizada NO es 'acta_constitutiva':
  -- aquella es el documento que redacta el abogado y esta el mismo ya
  -- inscrito y con nota del registrador. El c22 recibe la primera y
  -- devuelve la segunda, y de ahí la toman el c23 y el c24.
  -- No caduca: acredita un acto de una fecha concreta.
  ('acta_protocolizada','Acta constitutiva protocolizada',        false),
  ('pago_aranceles',    'Comprobante del pago de aranceles',      false),
  -- Recaudos del RNC, para PERSONA JURIDICA. La hoja de tramites por fase
  -- trae esa fila en blanco; esta lista sale de los requisitos publicados
  -- del Servicio Nacional de Contrataciones.
  --
  -- Que caduque o no sigue el criterio del resto del catalogo: caduca lo
  -- que acredita una situacion VIGENTE -solvencias, declaracion del
  -- ejercicio, estados financieros del ultimo cierre- y no caduca lo que
  -- acredita un hecho de una fecha concreta -actas, relaciones-.
  ('estados_financieros','Estados financieros auditados',           true),
  ('acta_asamblea',      'Ultima acta de asamblea',                 false),
  ('declaracion_islr',   'Declaracion del ISLR del ultimo ejercicio', true),
  ('solvencia_seniat',   'Solvencia del SENIAT',                    true),
  ('solvencia_ivss',     'Solvencia del IVSS',                      true),
  ('relacion_experiencia','Relacion de experiencia',                false),
  ('relacion_equipos',   'Relacion de equipos',                     false),
  -- Recaudo de las solvencias. La licencia municipal la EMITE el c10 y la
  -- consume el c14 para pedir la solvencia de la alcaldia: es la misma
  -- cadena que va del c5 al c22. Caduca porque una licencia vence, y una
  -- solvencia apoyada en una licencia muerta no se emite.
  ('licencia_actividades','Licencia de actividades economicas',      true),
  -- La nomina del RNC NO es la del RNET. Alli se entrega la de
  -- trabajadores; aqui, la de personal TECNICO con sus titulos, porque lo
  -- que el registro mide es capacidad tecnica y no tamaño de plantilla.
  ('nomina_tecnica',     'Nomina de personal tecnico con titulos',  false),
  -- La solvencia laboral exige estar inscrito en el Registro Nacional de
  -- Entidades de Trabajo. Lo emite el c27 y se consume en el c14: otra
  -- cadena, como la licencia municipal del c10.
  ('registro_rnet',      'Constancia de inscripcion en el RNET',    false),
  -- Recaudos de comercio exterior, según la hoja CIIP_Tramites_por_Fase.
  -- Caducan todos: la inscripción aduanera se renueva, y los certificados de
  -- origen y sanitarios se emiten por embarque o por campaña.
  ('inscripcion_aduanera','Inscripción en el registro aduanero',   true),
  ('cert_origen',        'Certificado de origen',                  true),
  ('cert_sanitario',     'Certificado sanitario o fitosanitario',  true),
  ('permiso_rubro',      'Permiso específico del rubro',           true),
  ('otro',              'Otro documento',                         false)
on conflict (codigo) do nothing;


-- ───────────────────────────────────────────────────────────────────────
-- 2. CATÁLOGO DE TIPOS DE TRÁMITE
-- ───────────────────────────────────────────────────────────────────────
-- ref_panel enlaza con los identificadores que ya usa el panel (c1…c31) y
-- con las listas de pasos de pasos.js. Sin esa columna habría que
-- mantener dos numeraciones en paralelo, que es como se desincronizan.

create table if not exists public.tipos_tramite (
  codigo    text primary key,
  ref_panel text    not null unique,
  nombre    text    not null,
  ente      text    not null,
  fase      smallint not null,
  activo    boolean not null default false,
  creado_en timestamptz not null default now(),

  constraint tipos_tramite_fase_valida check (fase between 1 and 5)
);

-- El CREATE de arriba lleva IF NOT EXISTS, asi que en una base donde la
-- tabla ya existe no toca nada y la restriccion se quedaria en 1..4: el
-- registro de la inversion extranjera, que es fase 5, no entraria y el
-- INSERT de mas abajo fallaria entero. Por eso se rehace aparte.
alter table public.tipos_tramite
  drop constraint if exists tipos_tramite_fase_valida;
alter table public.tipos_tramite
  add  constraint tipos_tramite_fase_valida check (fase between 1 and 5);

comment on table  public.tipos_tramite        is 'El catálogo de trámites de la ventanilla, uno por fila';
comment on column public.tipos_tramite.ref_panel is 'Identificador que usa el panel y pasos.js (c1…c31)';
comment on column public.tipos_tramite.activo is 'false = solo se muestra; todavía no se puede solicitar de verdad';

-- El c12 cambia de codigo: de 'registro_sanitario' a 'permiso_sanitario'.
--
-- Esto tiene que correr ANTES del INSERT de abajo y no despues. Aquel
-- lleva ON CONFLICT (codigo) DO NOTHING, que solo cubre choques de
-- codigo; pero ref_panel tambien es UNIQUE y 'c12' seguiria ocupado por
-- la fila vieja, asi que en una base que ya existe el INSERT entero
-- reventaria con una violacion de unicidad en ref_panel.
--
-- El orden de dentro tambien importa: primero se mudan los tramites que
-- hubiera —la clave foranea de tramites.tipo lo exige— y solo despues se
-- borra el tipo viejo. La guarda de to_regclass es para que esto corra
-- igual en una base recien creada, donde public.tramites aun no existe.
do $$
begin
  if to_regclass('public.tramites') is not null then
    update public.tramites
       set tipo = 'permiso_sanitario'
     where tipo = 'registro_sanitario';
  end if;
  delete from public.tipos_tramite where codigo = 'registro_sanitario';
end $$;

insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('visa_inversionista',  'c1',  'Visa de inversionista',            'SAIME',               1, false),
  ('cedula_residencia',   'c2',  'Cédula de residencia',             'SAIME',               1, false),
  ('rif_personal',        'c3',  'RIF personal',                     'SENIAT',              1, true ),
  ('licencia_conducir',   'c4',  'Homologación de licencia',         'INTT',                1, false),
  ('constitucion',        'c5',  'Constitución de empresa',          'SAREN',               2, false),
  ('rif_empresa',         'c6',  'RIF de la empresa',                'SENIAT',              2, false),
  ('cuenta_bancaria',     'c7',  'Cuenta bancaria corporativa',      'Banca aliada',        2, false),
  ('marca',               'c8',  'Registro de marca',                'SAPI',                2, false),
  -- El c9 se queda SOLO con el IVSS: ver la nota de la Fase 03, abajo.
  -- El codigo no se renombra a proposito. Es la llave con la que estan
  -- guardados los tramites que ya existan en la base, y cambiarlo los
  -- dejaria huerfanos; ref_panel y nombre si dicen ya lo que es.
  ('registros_laborales', 'c9',  'Inscripción en el IVSS',           'IVSS',                3, false),
  ('licencia_municipal',  'c10', 'Licencia de funcionamiento',       'Alcaldía',            3, false),
  ('comercio_exterior',   'c11', 'Permisos de importación',          'VUCE',                3, false),
  -- El c12 estaba mal atribuido. La hoja, en la Fase 03, pide el PERMISO
  -- SANITARIO DEL ESTABLECIMIENTO, que lo da la contraloria sanitaria
  -- (SACS) y mira el LOCAL. Aqui decia "Registro sanitario" con SENCAMER
  -- e INSAI, que son otra cosa: SENCAMER normaliza y mide, e INSAI ve
  -- sanidad agricola y guias de movilizacion. Ninguno de los dos otorga
  -- este permiso.
  --
  -- El registro sanitario DEL PRODUCTO existe y tambien lo da el SACS,
  -- pero es un tramite distinto y la hoja solo lo cuenta en la pestaña de
  -- permisos sectoriales. No esta en el panel todavia; cuando entre, el
  -- codigo 'registro_sanitario' queda libre para el, que es su nombre.
  ('permiso_sanitario',   'c12', 'Permiso sanitario del establecimiento','SACS',              3, false),
  ('rnc',                 'c13', 'Registro Nacional de Contratistas','RNC',                 4, false),
  ('solvencias',          'c14', 'Solvencias laborales y municipales','Entes varios',       4, false),
  ('banco_activos',       'c15', 'Banco de activos y oportunidades', 'CIIP',                4, false),
  -- Fase 01, los seis que faltaban frente a la hoja de trámites por fase.
  -- Siguen la numeración por donde iba (c16…c21) en vez de renumerar del
  -- c5 en adelante: ref_panel es la llave que une esta tabla con las
  -- tarjetas y con pasos.js, y correrla dejaría los tres desalineados.
  -- El orden en pantalla lo da el panel, no este número.
  ('antecedentes_penales','c16', 'Antecedentes penales apostillados','MPPRIJP',            1, false),
  ('apostilla_documentos','c17', 'Apostilla y traducción de documentos','MPPRE',           1, false),
  ('constancia_domicilio','c18', 'Constancia de domicilio',          'Registro Civil',     1, false),
  ('firma_electronica',   'c19', 'Firma electrónica',                'SUSCERTE',           1, false),
  ('visa_dependientes',   'c20', 'Visa y cédula de dependientes',    'SAIME',              1, false),
  ('cert_medico',         'c21', 'Certificado médico',               'Centro de salud',    1, false),
  -- Fase 02. Protocolizar y publicar eran hasta ahora dos PASOS del c5;
  -- la hoja de trámites por fase los cuenta como trámites propios, y de
  -- hecho lo son: cada uno tiene sus recaudos y su plazo. Al separarlos,
  -- los pasos del c5 se recortaron para que no reclamen un trabajo que
  -- ya no hace: dos tarjetas no pueden decir que hacen lo mismo.
  ('protocolizacion_acta','c22', 'Protocolización del acta',         'SAREN',              2, false),
  ('publicacion_acta',    'c23', 'Publicación del acta',             'Prensa mercantil',   2, false),
  ('libros_contables',    'c24', 'Libros contables y facturación',   'SENIAT',             2, false),
  -- Fase 03. La hoja cuenta diez trámites en esta fase y el panel tenía
  -- cuatro. El c9 hacía de una vez el IVSS, el INCES y el FAOV: se quedó
  -- con el IVSS —que es el que abre el número patronal del que cuelgan
  -- los otros dos— y el FAOV y el INCES salieron a trámites propios,
  -- igual que la protocolización salió del c5.
  --
  -- La conformidad de uso y la de bomberos eran, respectivamente, el
  -- paso 1 y un recaudo opcional del c10. La hoja las cuenta aparte y de
  -- hecho lo son: cada una tiene su ente, sus recaudos y su plazo. Ahora
  -- son el c28 y el c29, y el c10 pide la conformidad de uso como
  -- recaudo en vez de fingir que la tramita él.
  ('faov_banavih',        'c25', 'Inscripción en el FAOV',           'BANAVIH',             3, false),
  ('inces',               'c26', 'Inscripción en el INCES',          'INCES',               3, false),
  ('rnet',                'c27', 'Registro Nacional de Entidades de Trabajo', 'MPPPST',     3, false),
  ('conformidad_uso',     'c28', 'Conformidad de uso del inmueble',  'Alcaldía',            3, false),
  ('permiso_bomberos',    'c29', 'Permiso de bomberos',              'Cuerpo de Bomberos',  3, false),
  ('permiso_ambiental',   'c30', 'Permiso ambiental',                'MINEC',               3, false),
  -- Fase 05. Es el unico de esta fase y va aparte de "Crecer" a
  -- proposito: no es un paso mas del negocio sino lo que separa a un
  -- inversionista extranjero de cualquier comerciante local. Sin este
  -- registro se puede recorrer las cuatro fases anteriores enteras,
  -- montar la empresa y descubrir al final que no hay por donde sacar
  -- ni las utilidades ni el capital.
  --
  -- El ente va sin siglas a proposito: la hoja de tramites por fase dice
  -- "Organo rector de inversiones extranjeras" y no lo nombra, porque la
  -- competencia ha cambiado de manos mas de una vez. Poner aqui un
  -- acronimo que envejezca seria peor que no ponerlo.
  ('registro_inversion',  'c31', 'Registro de inversión extranjera',  'Órgano rector de inversiones extranjeras', 5, false)
on conflict (codigo) do nothing;

-- Cuáles se pueden solicitar de verdad HOY.
--
-- Va aparte del INSERT de arriba y no dentro: aquel lleva ON CONFLICT DO
-- NOTHING, así que en una base donde el catálogo ya existe no toca nada y
-- activar un trámite nuevo no surtiría efecto por más veces que se corra.
-- Aquí se dice en positivo y en negativo, para que la lista de activos sea
-- exactamente esta y no se quede uno encendido de una prueba anterior.
update public.tipos_tramite set activo = true
  where codigo in ('rif_personal', 'rif_empresa', 'visa_inversionista', 'cedula_residencia', 'licencia_conducir', 'constitucion', 'cuenta_bancaria', 'marca', 'registros_laborales', 'licencia_municipal', 'antecedentes_penales', 'apostilla_documentos', 'constancia_domicilio', 'firma_electronica', 'visa_dependientes', 'cert_medico', 'protocolizacion_acta', 'publicacion_acta', 'libros_contables', 'comercio_exterior', 'faov_banavih', 'inces', 'rnet', 'conformidad_uso', 'permiso_bomberos', 'permiso_ambiental', 'registro_inversion', 'permiso_sanitario', 'rnc', 'solvencias');
update public.tipos_tramite set activo = false
  where codigo not in ('rif_personal', 'rif_empresa', 'visa_inversionista', 'cedula_residencia', 'licencia_conducir', 'constitucion', 'cuenta_bancaria', 'marca', 'registros_laborales', 'licencia_municipal', 'antecedentes_penales', 'apostilla_documentos', 'constancia_domicilio', 'firma_electronica', 'visa_dependientes', 'cert_medico', 'protocolizacion_acta', 'publicacion_acta', 'libros_contables', 'comercio_exterior', 'faov_banavih', 'inces', 'rnet', 'conformidad_uso', 'permiso_bomberos', 'permiso_ambiental', 'registro_inversion', 'permiso_sanitario', 'rnc', 'solvencias');


-- (La mudanza del c12 va ANTES del INSERT del catalogo, mas arriba.)

-- ───────────────────────────────────────────────────────────────────────
-- 2.1 LOS BANCOS ALIADOS
-- ───────────────────────────────────────────────────────────────────────
-- La red de bancos con los que el CIIP abre cuentas. Es una tabla y no una
-- lista en el código por la misma razón que tipos_documento: la red cambia
-- —entra un banco, sale otro— y eso no debería obligar a tocar el panel ni
-- a volver a publicarlo.
--
-- NACE VACÍA A PROPÓSITO. Aquí no se inventan nombres: los pone el CIIP
-- cuando los acuerdos estén firmados. Mientras esté vacía, el trámite c7
-- funciona igual; simplemente dice que el banco está por asignar.
--
-- Para añadir uno:
--
--   insert into public.bancos_aliados (codigo, nombre, orden) values
--     ('banesco', 'Banesco', 10)
--   on conflict (codigo) do nothing;
--
-- Para retirar uno sin perder el historial de quién abrió cuenta allí,
-- NO lo borres: apágalo. Las cuentas ya abiertas siguen apuntando a él.
--
--   update public.bancos_aliados set activo = false where codigo = 'banesco';

create table if not exists public.bancos_aliados (
  codigo    text primary key,
  nombre    text    not null,
  activo    boolean not null default true,
  orden     smallint not null default 100,
  creado_en timestamptz not null default now()
);

comment on table  public.bancos_aliados        is 'Red de bancos con los que el CIIP abre cuentas corporativas';
comment on column public.bancos_aliados.activo is 'false = ya no se asignan cuentas nuevas, pero las abiertas lo conservan';
comment on column public.bancos_aliados.orden  is 'Para mandar en cómo se listan sin depender del alfabeto';


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA BÓVEDA DE DOCUMENTOS
-- ───────────────────────────────────────────────────────────────────────
-- Cuelga del inversionista, NO del trámite. Ese es todo el truco: un
-- documento subido una vez sirve para los quince.
--
-- El archivo en sí vive en Storage (bucket 'recaudos'); aquí se guarda
-- solo su ruta. Nunca metas binarios en una tabla.

create table if not exists public.documentos (
  id              uuid primary key default gen_random_uuid(),
  inversionista   uuid not null references auth.users(id) on delete cascade,
  tipo            text not null references public.tipos_documento(codigo),
  archivo         text not null,
  nombre_original text not null default '',
  vence_el        date,
  estado          text not null default 'cargado',
  nota_revision   text not null default '',
  revisado_por    uuid references auth.users(id) on delete set null,
  creado_en       timestamptz not null default now(),
  actualizado_en  timestamptz not null default now(),

  constraint documentos_estado_valido check (estado in ('cargado','validado','rechazado'))
);

comment on table  public.documentos               is 'Bóveda: los recaudos del inversionista, reutilizables entre trámites';
comment on column public.documentos.archivo       is 'Ruta dentro del bucket recaudos: {uid}/{uuid}-{nombre}';
comment on column public.documentos.estado        is 'cargado = recién subido; validado = el CIIP lo dio por bueno';
comment on column public.documentos.nota_revision is 'Por qué se rechazó. Es lo que lee el inversionista para corregir';

create index if not exists documentos_por_inversionista on public.documentos (inversionista, tipo);


-- ───────────────────────────────────────────────────────────────────────
-- 4. LOS TRÁMITES
-- ───────────────────────────────────────────────────────────────────────
-- Los cinco estados son el circuito REAL del CIIP, no el del ente. La
-- ventanilla solo puede saber lo que pasa por sus manos:
--
--   borrador      el inversionista lo está rellenando; aún puede editarlo
--   enviado       lo mandó; a partir de aquí queda congelado para él
--   en_revision   un gestor está comprobando los recaudos
--   devuelto      falta algo; vuelve a ser editable, con la nota del gestor
--   ante_el_ente  alguien del CIIP lo presentó ante el SENIAT
--   resuelto      terminado
--
-- El texto de cada paso NO se guarda aquí: vive en pasos.js, que ya está
-- en los seis idiomas. La base dice EN QUÉ paso va; el navegador dice
-- cómo se llama en tu idioma. Meter 366 traducciones en Postgres sería
-- duplicar lo que ya funciona.

create table if not exists public.tramites (
  id             uuid primary key default gen_random_uuid(),
  inversionista  uuid not null references auth.users(id) on delete cascade,
  tipo           text not null references public.tipos_tramite(codigo),
  estado         text not null default 'borrador',
  datos          jsonb not null default '{}'::jsonb,
  gestor         uuid references auth.users(id) on delete set null,
  creado_en      timestamptz not null default now(),
  enviado_en     timestamptz,
  resuelto_en    timestamptz,
  actualizado_en timestamptz not null default now(),

  constraint tramites_estado_valido
    check (estado in ('borrador','enviado','en_revision','devuelto','ante_el_ente','resuelto')),
  constraint tramites_datos_es_objeto
    check (jsonb_typeof(datos) = 'object')
);

-- El banco NO se pregunta en el formulario: la tarjeta del c7 promete que
-- la cita la coordina el CIIP. Se apunta aquí cuando se sabe, que casi
-- nunca es el día en que se envía la solicitud. Por eso admite null: null
-- significa "todavía sin asignar", y es lo que el panel le dice al
-- inversionista mientras tanto.
--
-- Va como columna y no dentro de datos porque apunta a un catálogo: así la
-- base impide asignar un banco que no está en la red, y se puede preguntar
-- "cuántas cuentas hemos abierto en cada banco" sin escarbar en un jsonb.
alter table public.tramites
  add column if not exists banco text references public.bancos_aliados(codigo);

comment on table  public.tramites        is 'Una solicitud concreta de un inversionista';
comment on column public.tramites.banco  is 'Banco aliado asignado (solo cuenta_bancaria). Null = todavía sin asignar';
comment on column public.tramites.datos  is 'Campos del formulario, distintos por tipo. rif_personal: numero_documento, tipo_documento, fecha_nacimiento, direccion_fiscal, telefono, profesion. visa_inversionista: numero_pasaporte, pais_emisor, vence_pasaporte, consulado, monto_inversion, motivo_inversion. cedula_residencia: numero_visa, fecha_ingreso, estado_civil, ocupacion, telefono_local, direccion_vzla. licencia_conducir: numero_licencia, pais_licencia, categoria, fecha_emision, vence_licencia, direccion_vzla. rif_empresa: razon_social, numero_registro, fecha_constitucion, capital_social, actividad_economica, direccion_fiscal. constitucion: denominacion, denominacion_alt, tipo_sociedad, capital_social, objeto_social, domicilio_social, socios. cuenta_bancaria: razon_social, rif_empresa, tipo_cuenta, moneda, ciudad_agencia, movimiento_estimado, firmantes, origen_fondos. marca: signo, tipo_signo, titular, en_uso, productos. registros_laborales: razon_social, rif_empresa, representante, actividad_economica, inicio_actividades, num_trabajadores, telefono, direccion_fiscal. licencia_municipal: razon_social, rif_empresa, municipio, tenencia, actividad_economica, metros, inicio_actividades, direccion_local. comercio_exterior: razon_social, rif_empresa, operacion, rubro, arancel, paises, aduana, mercancia. faov_banavih: razon_social, rif_empresa, representante, num_trabajadores, inicio_actividades, telefono, direccion_fiscal. inces: razon_social, rif_empresa, representante, actividad_economica, num_trabajadores, telefono, direccion_fiscal. rnet: razon_social, rif_empresa, representante, actividad_economica, num_trabajadores, inicio_actividades, direccion_fiscal. conformidad_uso: razon_social, rif_empresa, municipio, tenencia, actividad_economica, metros, direccion_local. permiso_bomberos: razon_social, rif_empresa, municipio, actividad_economica, metros, aforo, direccion_local. permiso_ambiental: razon_social, rif_empresa, impacto, municipio, actividad_economica, direccion_local, proceso. registro_inversion: razon_social, rif_empresa, modalidad, monto_inversion, moneda, pais_origen_fondos, fecha_aporte, financiamiento_interno, actividad_economica, destino_inversion. permiso_sanitario: razon_social, rif_empresa, tipo_establecimiento, rubro_sanitario, municipio, metros, num_trabajadores, direccion_local. rnc: razon_social, rif_empresa, numero_registro, representante, actividad_economica, clasificacion, capital_social, fecha_constitucion. solvencias: razon_social, rif_empresa, numero_patronal, nil_inces, nrc_faov, municipio, representante';
comment on column public.tramites.gestor is 'Quién del CIIP lo lleva. Null = sin asignar, que es justo lo que la cola debe mostrar primero';

create index if not exists tramites_por_inversionista on public.tramites (inversionista, estado);
create index if not exists tramites_cola on public.tramites (estado, creado_en) where estado in ('enviado','en_revision');


-- ───────────────────────────────────────────────────────────────────────
-- 5. QUÉ DOCUMENTOS LLEVA CADA TRÁMITE
-- ───────────────────────────────────────────────────────────────────────
-- Tabla puente, no una columna en documentos: un mismo documento va en
-- varios trámites a la vez. Esa es la razón de ser de la bóveda.

create table if not exists public.tramite_documentos (
  tramite   uuid not null references public.tramites(id)   on delete cascade,
  documento uuid not null references public.documentos(id) on delete cascade,
  creado_en timestamptz not null default now(),
  primary key (tramite, documento)
);

comment on table public.tramite_documentos is 'Qué recaudos de la bóveda se adjuntaron a qué solicitud';


-- ───────────────────────────────────────────────────────────────────────
-- 6. HISTORIAL
-- ───────────────────────────────────────────────────────────────────────
-- Esto es lo que hace que "El proceso" del panel deje de ser un dibujo:
-- cada línea de la escalera sale de un evento con su fecha y su autor.
-- Solo se inserta; no se edita ni se borra.

create table if not exists public.tramite_eventos (
  id        bigint generated always as identity primary key,
  tramite   uuid not null references public.tramites(id) on delete cascade,
  de_estado text,
  a_estado  text not null,
  nota      text not null default '',
  autor     uuid references auth.users(id) on delete set null,
  creado_en timestamptz not null default now()
);

comment on table  public.tramite_eventos      is 'Cada cambio de estado, con fecha y autor. Es el historial que ve el inversionista';
comment on column public.tramite_eventos.nota is 'Explicación del gestor. En "devuelto" es lo que dice qué falta';

create index if not exists eventos_por_tramite on public.tramite_eventos (tramite, creado_en);


-- ───────────────────────────────────────────────────────────────────────
-- 7. EL HISTORIAL SE ESCRIBE SOLO
-- ───────────────────────────────────────────────────────────────────────
-- Si dependiera de que la aplicación se acuerde de insertar el evento,
-- tarde o temprano se olvidaría y el historial mentiría. Lo hace la base.
-- De paso mantiene enviado_en y resuelto_en, que si no se calculan aquí
-- acaban desincronizados del estado.

create or replace function public.registrar_evento_tramite()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.tramite_eventos (tramite, de_estado, a_estado, autor)
    values (new.id, null, new.estado, auth.uid());
    return new;
  end if;

  if new.estado is distinct from old.estado then
    insert into public.tramite_eventos (tramite, de_estado, a_estado, autor)
    values (new.id, old.estado, new.estado, auth.uid());

    if new.estado = 'enviado'  and new.enviado_en  is null then new.enviado_en  = now(); end if;
    if new.estado = 'resuelto' and new.resuelto_en is null then new.resuelto_en = now(); end if;
  end if;

  return new;
end;
$$;

drop trigger if exists tramite_historial_insert on public.tramites;
create trigger tramite_historial_insert
  after insert on public.tramites
  for each row execute function public.registrar_evento_tramite();

drop trigger if exists tramite_historial_update on public.tramites;
create trigger tramite_historial_update
  before update on public.tramites
  for each row execute function public.registrar_evento_tramite();

drop trigger if exists tramites_marca_tiempo on public.tramites;
create trigger tramites_marca_tiempo
  before update on public.tramites
  for each row execute function public.tocar_actualizado_en();

drop trigger if exists documentos_marca_tiempo on public.documentos;
create trigger documentos_marca_tiempo
  before update on public.documentos
  for each row execute function public.tocar_actualizado_en();


-- ───────────────────────────────────────────────────────────────────────
-- 8. SEGURIDAD A NIVEL DE FILA
-- ───────────────────────────────────────────────────────────────────────
-- Igual que con perfiles: la clave anon es pública, así que esto es lo
-- único que impide que un inversionista lea los recaudos de otro.

alter table public.documentos         enable row level security;
alter table public.tramites           enable row level security;
alter table public.tramite_documentos enable row level security;
alter table public.tramite_eventos    enable row level security;
alter table public.tipos_documento    enable row level security;
alter table public.tipos_tramite      enable row level security;
alter table public.bancos_aliados     enable row level security;

-- --- catálogos: los lee cualquiera que haya entrado, nadie los escribe ---
drop policy if exists "tipos_documento: leer" on public.tipos_documento;
create policy "tipos_documento: leer" on public.tipos_documento
  for select to authenticated using (true);

drop policy if exists "tipos_tramite: leer" on public.tipos_tramite;
create policy "tipos_tramite: leer" on public.tipos_tramite
  for select to authenticated using (true);

-- La red de bancos se lee entera, apagados incluidos: un inversionista con
-- una cuenta en un banco que ya salió de la red tiene que seguir viendo su
-- nombre en el expediente. Filtrar por activo es cosa de quien la muestre.
drop policy if exists "bancos_aliados: leer" on public.bancos_aliados;
create policy "bancos_aliados: leer" on public.bancos_aliados
  for select to authenticated using (true);

-- --- bóveda ---
drop policy if exists "documentos: leer los propios" on public.documentos;
create policy "documentos: leer los propios" on public.documentos
  for select using (inversionista = auth.uid() or public.es_gestor());

drop policy if exists "documentos: subir los propios" on public.documentos;
create policy "documentos: subir los propios" on public.documentos
  for insert with check (inversionista = auth.uid());

-- El inversionista puede corregir un documento suyo mientras no esté
-- validado; el gestor puede revisarlo siempre. Se comprueba en USING (la
-- fila de antes) y en WITH CHECK (la de después) para que no pueda
-- moverla a otro dueño por el camino.
drop policy if exists "documentos: editar los propios" on public.documentos;
create policy "documentos: editar los propios" on public.documentos
  for update
  using      ((inversionista = auth.uid() and estado <> 'validado') or public.es_gestor())
  with check ((inversionista = auth.uid() and estado <> 'validado') or public.es_gestor());

drop policy if exists "documentos: borrar los no validados" on public.documentos;
create policy "documentos: borrar los no validados" on public.documentos
  for delete using (inversionista = auth.uid() and estado <> 'validado');

-- --- trámites ---
drop policy if exists "tramites: leer los propios" on public.tramites;
create policy "tramites: leer los propios" on public.tramites
  for select using (inversionista = auth.uid() or public.es_gestor());

-- Solo se puede crear en borrador y sobre un tipo que esté activo: así un
-- tipo que aún no existe de verdad no puede recibir solicitudes reales.
drop policy if exists "tramites: crear los propios" on public.tramites;
create policy "tramites: crear los propios" on public.tramites
  for insert with check (
    inversionista = auth.uid()
    and estado = 'borrador'
    and exists (select 1 from public.tipos_tramite t where t.codigo = tipo and t.activo)
  );

-- El inversionista solo toca lo suyo mientras sea editable. En cuanto lo
-- envía, deja de poder cambiarlo: si no, podría alterar la solicitud
-- después de que el gestor la haya revisado.
drop policy if exists "tramites: editar el borrador propio" on public.tramites;
create policy "tramites: editar el borrador propio" on public.tramites
  for update
  using      ((inversionista = auth.uid() and estado in ('borrador','devuelto')) or public.es_gestor())
  with check ((inversionista = auth.uid() and estado in ('borrador','enviado')) or public.es_gestor());

-- Descartar un borrador que se empezó y no se quiere seguir. Solo mientras
-- sea borrador: en cuanto se envía, el trámite es historia y no se borra.
--
-- Sin esta política el DELETE no fallaba: borraba CERO filas y PostgREST
-- devolvía 204, o sea "hecho". El borrador seguía ahí y nadie se enteraba.
-- Un permiso que falta se nota; uno que falla en silencio, no.
drop policy if exists "tramites: descartar el borrador propio" on public.tramites;
create policy "tramites: descartar el borrador propio" on public.tramites
  for delete using (inversionista = auth.uid() and estado = 'borrador');

-- --- adjuntos ---
drop policy if exists "adjuntos: leer los propios" on public.tramite_documentos;
create policy "adjuntos: leer los propios" on public.tramite_documentos
  for select using (
    public.es_gestor() or exists (
      select 1 from public.tramites t where t.id = tramite and t.inversionista = auth.uid()
    )
  );

drop policy if exists "adjuntos: adjuntar a lo propio" on public.tramite_documentos;
create policy "adjuntos: adjuntar a lo propio" on public.tramite_documentos
  for insert with check (
    exists (select 1 from public.tramites   t where t.id = tramite   and t.inversionista = auth.uid() and t.estado in ('borrador','devuelto'))
    and
    exists (select 1 from public.documentos d where d.id = documento and d.inversionista = auth.uid())
  );

drop policy if exists "adjuntos: quitar de lo propio" on public.tramite_documentos;
create policy "adjuntos: quitar de lo propio" on public.tramite_documentos
  for delete using (
    exists (select 1 from public.tramites t where t.id = tramite and t.inversionista = auth.uid() and t.estado in ('borrador','devuelto'))
  );

-- --- historial: se lee, no se escribe a mano ---
-- No hay política de INSERT a propósito: las filas las pone el trigger,
-- que es security definer y por tanto se salta RLS.
drop policy if exists "eventos: leer los propios" on public.tramite_eventos;
create policy "eventos: leer los propios" on public.tramite_eventos
  for select using (
    public.es_gestor() or exists (
      select 1 from public.tramites t where t.id = tramite and t.inversionista = auth.uid()
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- 9. ALMACÉN DE ARCHIVOS
-- ───────────────────────────────────────────────────────────────────────
-- Bucket privado: los recaudos no se sirven por URL pública nunca. Para
-- enseñarlos se pide una URL firmada, que caduca.
--
-- La convención de rutas es {uid}/{lo-que-sea} y las políticas se apoyan
-- en ella: la primera carpeta ES el dueño. Si se cambia la convención,
-- hay que cambiar estas cuatro políticas.

insert into storage.buckets (id, name, public)
values ('recaudos', 'recaudos', false)
on conflict (id) do nothing;

drop policy if exists "recaudos: subir a su carpeta" on storage.objects;
create policy "recaudos: subir a su carpeta" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'recaudos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "recaudos: leer su carpeta" on storage.objects;
create policy "recaudos: leer su carpeta" on storage.objects
  for select to authenticated
  using (bucket_id = 'recaudos' and ((storage.foldername(name))[1] = auth.uid()::text or public.es_gestor()));

drop policy if exists "recaudos: reemplazar en su carpeta" on storage.objects;
create policy "recaudos: reemplazar en su carpeta" on storage.objects
  for update to authenticated
  using (bucket_id = 'recaudos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "recaudos: borrar de su carpeta" on storage.objects;
create policy "recaudos: borrar de su carpeta" on storage.objects
  for delete to authenticated
  using (bucket_id = 'recaudos' and (storage.foldername(name))[1] = auth.uid()::text);


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) RLS activo en las siete tablas. Las siete deben salir con true:
--
--   select relname, relrowsecurity
--   from pg_class
--   where relname in ('documentos','tramites','tramite_documentos',
--                     'tramite_eventos','tipos_documento','tipos_tramite',
--                     'bancos_aliados');
--
-- 2) Los activos deben ser exactamente los que nombran los dos UPDATE de
--    la sección 2 de este fichero, y ninguno más. Se comprueba contando,
--    no repitiendo aquí la lista: una lista copiada envejece en cuanto se
--    activa un trámite y acaba contradiciendo al UPDATE que sí manda.
--
--   select count(*) filter (where activo) as activos,
--          count(*)                       as total
--   from public.tipos_tramite;
--
--    Y para verlos uno a uno, en el orden en que salen en el panel:
--
--   select codigo, activo from public.tipos_tramite order by ref_panel;
--
-- 3) La red de bancos empieza VACÍA, y sale vacía de esta consulta hasta
--    que el CIIP la llene. No es un fallo: el c7 funciona igual y le dice
--    al inversionista que el banco está por asignar.
--
--   select codigo, nombre, activo from public.bancos_aliados order by orden;
--
-- 4) Prueba del aislamiento, que es lo único que de verdad importa.
--    Entra en la aplicación con DOS cuentas distintas y comprueba que la
--    segunda no ve ni un documento ni un trámite de la primera. Hacerlo
--    desde el SQL Editor no vale: ahí auth.uid() es null y RLS no aplica.
