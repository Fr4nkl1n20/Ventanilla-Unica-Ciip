-- ====================================================================
--  LOS 105 ARCHIVOS, EN EL ORDEN QUE PRUEBA PROBAR-SQL.bat
-- ====================================================================
--  Esto es la union literal de los 105 supabase-*.sql, sin cambiar una
--  coma, pegados en el orden que ejecuta el arnes contra un Postgres de
--  usar y tirar. Ese orden no esta deducido leyendo cabeceras: si uno
--  usara algo que otro define despues, la tanda se caeria diciendo cual.
--
--  Se pega ENTERO en el SQL Editor de Supabase y se pulsa Run una vez.
--  Todos son idempotentes -create if not exists, create or replace, drop
--  policy if exists-, asi que volver a correrlo no rompe nada y es la
--  forma de poner al dia un proyecto que ya tenia la mitad.
--
--  Generado el 2026-11-05. Si cambia un archivo, se vuelve a generar:
--  no se edita a mano, que entonces son 105 sitios donde mirar.
-- ====================================================================


-- ====================================================================
--  01 / 105   supabase-setup.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · Ventanilla Única del Inversionista
--  Esquema de base de datos para el acceso (acceso.html)
-- ═══════════════════════════════════════════════════════════════════════
--
--  CÓMO SUBIRLO:
--    Panel de Supabase → SQL Editor → New query → pega todo esto → Run
--
--  Es idempotente: puedes ejecutarlo varias veces sin romper nada.
--
--  QUÉ HACE:
--    1. Crea la tabla public.perfiles, ligada 1 a 1 con auth.users
--    2. Activa RLS para que cada usuario solo vea y edite SU perfil
--    3. Crea un trigger que rellena el perfil solo al registrarse
--    4. Mantiene actualizado_en al día
--
--  QUÉ **NO** HACE (y no debe hacer):
--    No guarda claves. Supabase ya las almacena cifradas en auth.users.
--    Nunca crees una columna de contraseña en tus propias tablas.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. TABLA DE PERFILES
-- ───────────────────────────────────────────────────────────────────────
-- auth.users la gestiona Supabase y no se debe tocar. Todo dato propio
-- del inversionista (nombre, país, rol…) vive aquí, enlazado por id.
-- Al borrar el usuario en auth.users, su perfil se borra en cascada.

create table if not exists public.perfiles (
  id               uuid        primary key references auth.users(id) on delete cascade,
  nombre_completo  text        not null default '',
  pais             text        not null default '',
  rol              text        not null default 'inversionista',
  creado_en        timestamptz not null default now(),
  actualizado_en   timestamptz not null default now(),

  constraint perfiles_rol_valido check (rol in ('inversionista','gestor','admin'))
);

comment on table  public.perfiles                 is 'Datos de perfil de cada usuario, 1 a 1 con auth.users';
comment on column public.perfiles.rol             is 'inversionista = usuario final; gestor = equipo CIIP; admin = total';
comment on column public.perfiles.nombre_completo is 'Se rellena solo desde el registro (acceso.html)';


-- ───────────────────────────────────────────────────────────────────────
-- 2. SEGURIDAD A NIVEL DE FILA (RLS)
-- ───────────────────────────────────────────────────────────────────────
-- ESTO ES LO QUE REALMENTE PROTEGE LOS DATOS.
-- La clave anon del navegador es pública; sin RLS, cualquiera podría leer
-- la tabla entera. Con RLS, Postgres filtra por el usuario autenticado.

alter table public.perfiles enable row level security;

-- Cada quien lee únicamente su propio perfil
drop policy if exists "perfiles: leer el propio" on public.perfiles;
create policy "perfiles: leer el propio"
  on public.perfiles for select
  using (auth.uid() = id);

-- Cada quien edita únicamente su propio perfil…
drop policy if exists "perfiles: actualizar el propio" on public.perfiles;
create policy "perfiles: actualizar el propio"
  on public.perfiles for update
  using      (auth.uid() = id)
  with check (auth.uid() = id);

-- …pero NO puede cambiarse el rol a sí mismo (evita autoascenso a admin).
-- auth.uid() es null cuando la conexión usa la clave service_role o se
-- ejecuta desde el SQL Editor, así que el equipo del CIIP sí puede
-- ascender a alguien a 'gestor'; el usuario desde el navegador, no.
create or replace function public.bloquear_cambio_de_rol()
returns trigger
language plpgsql
as $$
begin
  if new.rol is distinct from old.rol and auth.uid() is not null then
    raise exception 'El rol solo puede cambiarse desde el servidor';
  end if;
  return new;
end;
$$;

drop trigger if exists proteger_rol on public.perfiles;
create trigger proteger_rol
  before update on public.perfiles
  for each row execute function public.bloquear_cambio_de_rol();

-- Nota: no hay política de INSERT ni de DELETE a propósito.
-- El alta la hace el trigger de más abajo (security definer) y las bajas
-- se gestionan borrando el usuario en auth.users.


-- ───────────────────────────────────────────────────────────────────────
-- 3. ALTA AUTOMÁTICA DEL PERFIL AL REGISTRARSE
-- ───────────────────────────────────────────────────────────────────────
-- acceso.html envía nombre_completo y pais dentro de options.data al
-- llamar a signUp(). Supabase los guarda en auth.users.raw_user_meta_data
-- y este trigger los copia a public.perfiles.
--
-- security definer = corre con permisos del dueño, saltándose RLS, que es
-- justo lo que hace falta para poder insertar la fila del usuario nuevo.

create or replace function public.manejar_usuario_nuevo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.perfiles (id, nombre_completo, pais)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'nombre_completo', ''),
    coalesce(new.raw_user_meta_data ->> 'pais', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists al_crear_usuario on auth.users;
create trigger al_crear_usuario
  after insert on auth.users
  for each row execute function public.manejar_usuario_nuevo();


-- ───────────────────────────────────────────────────────────────────────
-- 4. MARCA DE TIEMPO DE ACTUALIZACIÓN
-- ───────────────────────────────────────────────────────────────────────

create or replace function public.tocar_actualizado_en()
returns trigger
language plpgsql
as $$
begin
  new.actualizado_en = now();
  return new;
end;
$$;

drop trigger if exists actualizar_marca_tiempo on public.perfiles;
create trigger actualizar_marca_tiempo
  before update on public.perfiles
  for each row execute function public.tocar_actualizado_en();


-- ───────────────────────────────────────────────────────────────────────
-- 5. PERFILES PARA USUARIOS YA EXISTENTES
-- ───────────────────────────────────────────────────────────────────────
-- Si ya habías creado usuarios antes de instalar el trigger, esto les
-- genera el perfil que les falta. Inofensivo si no hay ninguno.

insert into public.perfiles (id, nombre_completo, pais)
select u.id,
       coalesce(u.raw_user_meta_data ->> 'nombre_completo', ''),
       coalesce(u.raw_user_meta_data ->> 'pais', '')
from auth.users u
left join public.perfiles p on p.id = u.id
where p.id is null;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
-- Ejecuta esto después para verificar que RLS quedó activo.
-- Debe devolver una fila con rowsecurity = true.
--
--   select relname, relrowsecurity as rowsecurity
--   from pg_class where relname = 'perfiles';

-- ====================================================================
--  02 / 105   supabase-tramites.sql
-- ====================================================================

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

-- SOLO SI NO EXISTE (8-10-2026, auditoría de seguridad). La versión que
-- vale es la de supabase-qa-admin.sql, que además mira «bloqueado» (QA-05).
-- Esta columna aún no existe cuando este archivo corre en una base nueva,
-- así que aquí no se puede poner la definición final; pero volver a correr
-- este archivo suelto en una base que ya la tiene NO debe pisarla: un
-- gestor bloqueado recuperaría todos sus permisos.
do $solo$
begin
  if to_regprocedure('public.es_gestor()') is null then
    execute $f$
      create function public.es_gestor()
      returns boolean
      language sql
      stable
      security definer
      set search_path = public
      as $q$
        select exists (
          select 1 from public.perfiles
          where id = auth.uid() and rol in ('gestor','admin')
        );
      $q$
    $f$;
  end if;
end
$solo$;

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
  ('domicilio_empresa', 'Contrato de servicios o constancia que acredite la dirección fiscal', false),
  -- Los siete de Pendientes FRANK.pdf (24 de septiembre de 2026). La
  -- solvencia es una constancia de trabajo y envejece; las demás, no.
  ('cedula_apoderado',        'Cédula de identidad del apoderado',           false),
  ('rif_apoderado',           'RIF del apoderado',                           false),
  ('carta_solicitud_empresa', 'Carta de solicitud de la empresa',            false),
  ('planilla_visa',           'Planilla de solicitud de la visa',            false),
  ('solvencia_economica',     'Solvencia económica (constancia de trabajo)', true),
  ('carta_residencia',        'Carta de residencia',                         false),
  ('declaracion_fondos',      'Declaración jurada de origen de fondos',      false),
  -- La apostilla o legalización que el papel YA trae (25-9-2026, venía en
  -- CORRER-HOY-2026-09-25.sql). No caduca: es un sello sobre otro papel.
  ('apostilla_previa',        'Apostilla o legalización que ya tiene el documento', false),
  -- Eran los recaudos de la visa de inversionista (TR-I). Los antecedentes
  -- penales caducan (los consulados suelen pedirlos recientes), la
  -- constancia de inversión no. La c1 pasó a ser la TR-N el 15-9-2026 y
  -- los dos se QUEDAN: puede haberlos ya en alguna bóveda, y
  -- documentos.tipo apunta aquí.
  ('antecedentes',      'Antecedentes penales apostillados',      true),
  ('inversion',         'Constancia de la inversión',             false),
  -- Recaudos de la visa de negocios (TR-N), los que publica el MPPRE en
  -- https://mppre.gob.ve/descripcion/28. Tipos PROPIOS y no los que se
  -- parecen: el certificado médico del país de origen no es el que pide el
  -- INTT, ni el arancel consular el del registro, y con el mismo tipo la
  -- bóveda daría el uno por el otro. Caduca el certificado médico; la
  -- carta, el registro y el comprobante acreditan algo de una fecha dada.
  ('carta_motivo_viaje',        'Carta con el motivo del viaje',        false),
  ('registro_comercio',         'Registro Mercantil o carta de la Cámara', false),
  ('certificado_medico_origen', 'Certificado médico del país de origen', true),
  ('arancel_consular',          'Comprobante del arancel consular',     false),
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
  -- La pide el formulario de constitución del SAREN a todos los tipos de
  -- empresa menos la firma personal. Acredita que el comisario aceptó el
  -- cargo en una fecha: no caduca.
  ('carta_comisario',   'Carta de aceptación del comisario',      false),
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
  ('visa_negocios',  'c1',  'Visa de negocios (TR-N)',          'MPPRE',               1, false),
  ('cedula_residencia',   'c2',  'Cédula de residencia',             'SAIME',               1, false),
  ('rif_personal',        'c3',  'RIF personal',                     'SENIAT',              1, true ),
  ('licencia_conducir',   'c4',  'Homologación de licencia',         'INTT',                1, false),
  ('constitucion',        'c5',  'Constitución de empresa',          'SAREN',               2, false),
  ('rif_empresa',         'c6',  'RIF de la empresa',                'SENIAT',              2, false),
  ('cuenta_bancaria',     'c7',  'Cuenta bancaria corporativa',      'Banca aliada',        2, false),
  ('marca',               'c8',  'Registro de marca',                'SAPI',                2, false),
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
  ('apostilla_documentos','c17', 'Apostilla y traducción de documentos','MPPRE',           1, false),
  ('firma_electronica',   'c19', 'Firma electrónica',                'SUSCERTE',           1, false),
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
  -- con el IVSS, y el FAOV y el INCES salieron a trámites propios, igual
  -- que la protocolización salió del c5.
  --
  -- Y EL IVSS SE FUE DEL CATÁLOGO el 22 de septiembre de 2026: «elimina
  -- la casilla de IVSS», y fuera de la ventanilla, no dentro del c37. Su
  -- fila ya no se crea aquí. El codigo 'registros_laborales' NO se
  -- reutiliza para otra cosa: es la llave con la que estan guardadas las
  -- solicitudes que ya existan, y darselo a otro tramite las renombraria.
  -- Para una base que ya tenga la fila, QUITAR-IVSS.sql.
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
-- Sin licencia_conducir (c4) ni cert_medico (c21): se quitaron del panel
-- el 25-9-2026 (CORRER-HOY-2026-09-25.sql) y la segunda lista los apaga.
-- Ni comercio_exterior (c11), que el CIIP quitó el 28-9-2026
-- (supabase-quitar-importador.sql).
update public.tipos_tramite set activo = true
  where codigo in ('rif_personal', 'rif_empresa', 'visa_negocios', 'cedula_residencia', 'constitucion', 'cuenta_bancaria', 'marca', 'licencia_municipal', 'apostilla_documentos', 'firma_electronica', 'protocolizacion_acta', 'publicacion_acta', 'libros_contables', 'faov_banavih', 'inces', 'rnet', 'conformidad_uso', 'permiso_bomberos', 'permiso_ambiental', 'registro_inversion', 'permiso_sanitario', 'rnc', 'solvencias');
update public.tipos_tramite set activo = false
  where codigo not in ('rif_personal', 'rif_empresa', 'visa_negocios', 'cedula_residencia', 'constitucion', 'cuenta_bancaria', 'marca', 'licencia_municipal', 'apostilla_documentos', 'firma_electronica', 'protocolizacion_acta', 'publicacion_acta', 'libros_contables', 'faov_banavih', 'inces', 'rnet', 'conformidad_uso', 'permiso_bomberos', 'permiso_ambiental', 'registro_inversion', 'permiso_sanitario', 'rnc', 'solvencias');


-- La c1 era la visa de inversionista (TR-I), ante el SAIME. Desde el 15 de
-- septiembre de 2026 es la de negocios (TR-N), que se pide en el consulado
-- y publica el MPPRE. El CODIGO se queda: hay solicitudes con el, y
-- cambiarlo las dejaria huerfanas. Va con UPDATE por lo mismo que lo de
-- arriba: el INSERT no toca una base que ya tiene la fila.
update public.tipos_tramite
   set nombre = 'Visa de negocios (TR-N)', ente = 'MPPRE'
 where codigo = 'visa_negocios';

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

-- La bóveda se abre siempre con lo vencido primero, y ese orden no lo
-- servía ningún índice: el de arriba ordena por tipo. Parcial porque un
-- documento que no caduca -un título, un acta- deja vence_el en null y no
-- pinta nada en esa pantalla; así el índice ocupa lo que ocupan los que sí.
create index if not exists documentos_por_vencer
  on public.documentos (inversionista, vence_el)
  where vence_el is not null;


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
    check (estado in ('borrador','enviado','en_revision','devuelto','ante_el_ente','resuelto','cancelado')),
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

-- DE QUÉ SOLICITUD SALIÓ ESTE TRAMO (24 de septiembre de 2026)
-- ───────────────────────────────────────────────────────────────────────
-- La constitución abre la protocolización y ésta la publicación. Hasta hoy
-- esos tramos no colgaban de nada: los triggers miraban si el INVERSIONISTA
-- ya tenía uno, así que la cadena daba por hecho una empresa por persona.
-- Quien constituía una segunda empresa no volvía a tener tramos, y su
-- solicitud nueva aparecía debajo de los de la primera, con las fechas y
-- las marcas de hecho de aquélla (Franklin Reyes: «es un formulario nuevo,
-- debería rehacer el proceso, ¿no?»).
--
-- Con esto cada tramo sabe de dónde salió, y las dos preguntas que antes no
-- se podían hacer tienen respuesta: cuáles son los tramos DE ESTA
-- constitución, y si ESTA solicitud ya abrió el suyo.
--
-- Null es lo normal: lo tienen los treinta y pico trámites que no vienen de
-- ninguno, y los tramos creados antes de hoy, que no se pueden atar hacia
-- atrás porque nadie guardó de dónde venían.
--
-- ON DELETE SET NULL y no CASCADE: borrar una constitución no puede
-- llevarse por delante una protocolización que el registro ya tramitó. Se
-- queda huérfana, que es la verdad, y no desaparece.
alter table public.tramites
  add column if not exists viene_de uuid references public.tramites(id) on delete set null;

create index if not exists tramites_por_origen on public.tramites (viene_de)
  where viene_de is not null;

comment on table  public.tramites        is 'Una solicitud concreta de un inversionista';
comment on column public.tramites.banco  is 'Banco aliado asignado (solo cuenta_bancaria). Null = todavía sin asignar';
comment on column public.tramites.datos  is 'Campos del formulario, distintos por tipo. rif_personal: numero_documento, tipo_documento, fecha_nacimiento, direccion_fiscal, telefono, profesion. visa_negocios (la TR-N): numero_pasaporte, pais_emisor, vence_pasaporte, consulado, motivo_viaje, contacto_venezuela. cedula_residencia: numero_visa, fecha_ingreso, estado_civil, ocupacion, telefono_local, direccion_vzla. licencia_conducir: numero_licencia, pais_licencia, categoria, fecha_emision, vence_licencia, direccion_vzla. rif_empresa: razon_social, numero_registro, fecha_constitucion, capital_social, actividad_economica, direccion_fiscal. constitucion: denominacion, denominacion_alt, estado_solicitud, oficina_registro, capital_social (el suscrito, en bolivares), seccion_actividad, tipo_sociedad (el tipo de empresa del SAREN), objeto_social, domicilio_social, socios. cuenta_bancaria: razon_social, rif_empresa, tipo_cuenta, moneda, ciudad_agencia, movimiento_estimado, firmantes, origen_fondos. marca: signo, tipo_signo, titular, en_uso, productos. registros_laborales: razon_social, rif_empresa, representante, actividad_economica, inicio_actividades, num_trabajadores, telefono, direccion_fiscal. licencia_municipal: razon_social, rif_empresa, municipio, tenencia, actividad_economica, inicio_actividades, direccion_local (las viejas pueden traer metros). comercio_exterior: razon_social, rif_empresa, operacion, rubro, arancel, paises, aduana, mercancia. faov_banavih: razon_social, rif_empresa, representante, num_trabajadores, inicio_actividades, telefono, direccion_fiscal. inces: razon_social, rif_empresa, representante, actividad_economica, num_trabajadores, telefono, direccion_fiscal. rnet: razon_social, rif_empresa, representante, actividad_economica, num_trabajadores, inicio_actividades, direccion_fiscal. conformidad_uso: razon_social, rif_empresa, municipio, tenencia, actividad_economica, metros, direccion_local. permiso_bomberos: razon_social, rif_empresa, municipio, actividad_economica, metros, aforo, direccion_local. permiso_ambiental: razon_social, rif_empresa, impacto, municipio, actividad_economica, direccion_local, proceso. registro_inversion: razon_social, rif_empresa, modalidad, monto_inversion, moneda, pais_origen_fondos, fecha_aporte, financiamiento_interno, actividad_economica, destino_inversion. permiso_sanitario: razon_social, rif_empresa, tipo_establecimiento, rubro_sanitario, municipio, metros, num_trabajadores, direccion_local. rnc: razon_social, rif_empresa, numero_registro, representante, actividad_economica, clasificacion, capital_social, fecha_constitucion. solvencias: razon_social, rif_empresa, numero_patronal, nil_inces, nrc_faov, municipio, representante';
comment on column public.tramites.viene_de is 'La solicitud que abrio este tramo. Null = no viene de ninguna';
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

-- La clave primaria ya sirve para "qué papeles lleva este trámite", que es
-- por donde se lee. Falta el otro sentido: Postgres NO indexa solo la
-- columna de una clave foránea, así que borrar un documento recorría la
-- tabla entera para comprobar que no cuelga de ningún trámite.
create index if not exists adjuntos_por_documento
  on public.tramite_documentos (documento);

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

-- ── el estado sube por la escalera, no salta ──
-- El check de la tabla dice qué estados EXISTEN; no dice en qué orden se
-- pasa de uno a otro. Con las políticas de arriba, un gestor podía llevar
-- un trámite de 'borrador' a 'resuelto' de un tirón: el historial lo
-- anotaba fielmente, pero anotar no es impedir, y lo que quedaba era un
-- expediente resuelto que nadie revisó ni presentó ante nadie.
--
-- Los pasos son los que el panel ofrece de verdad -su tabla está en la
-- pantalla de la cola- más los dos del inversionista: enviar un borrador y
-- reenviar lo que le devolvieron. Si mañana el panel ofrece uno nuevo, se
-- añade aquí; que salga un error es mejor que un salto silencioso.
--
-- 'resuelto' no aparece a la izquierda a propósito: de ahí no se vuelve.
create or replace function public.tramites_solo_la_escalera()
returns trigger
language plpgsql
as $$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;

  -- Desde el SQL Editor y desde una clave de servidor auth.uid() es null.
  -- Ahí no se estorba: quien entra por esa puerta ya se salta el RLS
  -- entero, y hace falta poder enderezar a mano un expediente atascado sin
  -- quitar el trigger y tener que acordarse de volver a ponerlo.
  if auth.uid() is null then
    return new;
  end if;

  if not (
       (old.estado = 'borrador'     and new.estado = 'enviado')
    or (old.estado = 'devuelto'     and new.estado = 'enviado')
    or (old.estado = 'enviado'      and new.estado in ('en_revision','devuelto'))
    or (old.estado = 'en_revision'  and new.estado in ('ante_el_ente','devuelto'))
    or (old.estado = 'ante_el_ente' and new.estado in ('resuelto','devuelto'))
    -- Cancelar: el inversionista, con cancela_tramite(), antes de que llegue al ente
    -- (supabase-cancelar.sql). Sin esta línea, volver a correr este archivo rompe el botón.
    or (old.estado in ('borrador','enviado','en_revision','devuelto')
        and new.estado = 'cancelado')
  ) then
    raise exception 'Un trámite no pasa de "%" a "%"', old.estado, new.estado
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists tramites_proteger on public.tramites;
create trigger tramites_proteger
  before update on public.tramites
  for each row execute function public.tramites_solo_la_escalera();

drop trigger if exists tramites_marca_tiempo on public.tramites;
create trigger tramites_marca_tiempo
  before update on public.tramites
  for each row execute function public.tocar_actualizado_en();

-- ── el archivo se va con su ficha ──
-- documentos guarda la RUTA; el archivo vive en el cubo. Al borrar la
-- cuenta, el cascade desde auth.users se lleva la fila y dejaría el
-- archivo en el cubo para siempre, sin nada que dijera de quién fue.
--
-- Va en la base y no en el panel porque el panel no borra documentos
-- -«cambiar» guarda el viejo como historial- y porque el cascade de una
-- cuenta borrada ocurre aquí, donde no corre código de cliente.
--
-- POR QUÉ NO SE BORRA AQUÍ MISMO
-- ─────────────────────────────────────────────────────────────────────
-- Esto empezó siendo un `delete from storage.objects`. Parecía suficiente
-- y no lo era, por dos razones que sólo se ven de dos maneras distintas:
--
--  1. No borra el archivo. storage.objects es el ÍNDICE del cubo; los
--     bytes viven en el almacén de detrás y de allí sólo los saca la API
--     de Storage. Borrando la fila el archivo deja de poder pedirse pero
--     sigue ocupando -y costando-, y ya no queda ni el nombre para ir a
--     buscarlo. Un huérfano invisible es peor que uno visible.
--     Esto se sabía leyendo la documentación.
--
--  2. Ni siquiera borraba la fila. En un Supabase de verdad el trigger se
--     va en silencio sin tocar nada: storage.objects es de otro esquema y
--     de otro dueño, y `security definer` corre como el dueño de la
--     función -postgres-, que ahí tampoco manda. Cero filas, ningún
--     error, y la prueba local en verde porque en el doble esa tabla es
--     nuestra. Esto NO se sabía: lo dijo PROBAR-CERRADURAS.bat la primera
--     vez que se corrió contra un proyecto de verdad.
--
-- ASÍ QUE SE APUNTA Y LO RECOGE QUIEN PUEDE
-- ─────────────────────────────────────────────────────────────────────
-- El trigger escribe la ruta en una lista y sale. El barrendero
-- -avisos/barrendero.js, con la clave de servidor- la lee y llama a la
-- API de Storage, que es la única que se lleva las dos cosas: el índice y
-- los bytes.
--
-- Es el mismo trato que con los avisos: la base APUNTA lo que hay que
-- hacer fuera, y lo de fuera no puede hacer fallar el borrado. Si el
-- barrendero no corre esta noche, el archivo sigue apuntado y se va
-- mañana; si reventara dentro de la transacción, borrar una cuenta
-- fallaría por no poder limpiar el cubo, que es exactamente al revés de
-- lo que interesa.
--
-- Y a diferencia del delete, esto deja rastro: la lista dice qué quedó
-- sin recoger y desde cuándo.

create table if not exists public.archivos_huerfanos (
  id   uuid primary key default gen_random_uuid(),
  cubo text not null default 'recaudos',
  ruta text not null,

  -- De quién FUE. Sin llave foránea a propósito: el caso que más importa
  -- es justamente el de la cuenta que ya no existe, y una foránea con
  -- cascade borraría la fila que hace falta para limpiar.
  de_quien uuid,

  estado   text not null default 'pendiente',
  intentos smallint not null default 0,
  ultimo_error text,

  creado_en timestamptz not null default now(),
  barrido_en timestamptz,

  constraint archivos_huerfanos_estado_valido
    check (estado in ('pendiente', 'barrido', 'fallido')),
  -- Un archivo se apunta una vez. Sin esto, borrar la ficha y después la
  -- cuenta lo apuntaría dos veces y el barrendero pediría a la API que
  -- borrase algo que ya no está, que contesta error y parecería un fallo.
  constraint archivos_huerfanos_una_vez unique (cubo, ruta)
);

comment on table  public.archivos_huerfanos        is 'Archivos que se quedaron sin ficha. Los recoge el barrendero con la API de Storage';
comment on column public.archivos_huerfanos.de_quien is 'De quien fue, aunque su cuenta ya no exista. Sin foranea: si la hubiera, el cascade borraria justo esto';

create index if not exists archivos_huerfanos_por_barrer
  on public.archivos_huerfanos (creado_en)
  where estado = 'pendiente';

-- security definer porque el borrado que más importa -el cascade de una
-- cuenta- ocurre sin que haya nadie conectado a quien pedirle permiso.
create or replace function public.apuntar_el_huerfano()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.archivo is null or old.archivo = '' then
    return old;
  end if;

  insert into public.archivos_huerfanos (cubo, ruta, de_quien)
  values ('recaudos', old.archivo, old.inversionista)
  on conflict (cubo, ruta) do nothing;

  return old;
end;
$$;

-- El trigger viejo se llamaba distinto y hacía otra cosa. Se quita por su
-- nombre para que este archivo, al correrlo encima de una base que ya lo
-- tenía, no deje los dos puestos.
drop trigger if exists documentos_borra_el_archivo on public.documentos;
drop function if exists public.borrar_el_archivo();

drop trigger if exists documentos_apunta_el_huerfano on public.documentos;
create trigger documentos_apunta_el_huerfano
  after delete on public.documentos
  for each row execute function public.apuntar_el_huerfano();

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
alter table public.archivos_huerfanos enable row level security;

-- --- la lista de huerfanos: de nadie ---
-- RLS encendido y ni una politica. Con eso, para cualquiera que entre
-- por la clave publica -haya iniciado sesion o no- la tabla contesta
-- vacia y no acepta nada. El unico que la ve es el barrendero, que va
-- con la clave de servidor y no pasa por aqui.
--
-- No es paranoia: cada fila es la ruta de un archivo dentro del cubo,
-- y las rutas empiezan por el uuid de su dueño. Poder leerlas seria
-- poder listar recaudos ajenos por nombre, incluidos los de cuentas ya
-- borradas, que es justo lo que se venia a limpiar.

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
--
-- EL TOPE Y LOS TIPOS LOS PONE EL CUBO, NO EL NAVEGADOR
-- ─────────────────────────────────────────────────────
-- Las cuatro políticas de abajo deciden DÓNDE escribe cada quien. No dicen
-- nada de QUÉ ni de CUÁNTO, y sin eso cualquier autenticado podía dejar 50
-- GB o un .exe en su propia carpeta y estar en su derecho. El panel ya mira
-- el tamaño antes de subir, pero eso es cortesía para no hacer esperar por
-- un error que se sabía desde el principio: quien llame a la API de frente
-- se la salta entera.
--
-- Los 10 MB son el doble de lo que el panel deja pasar para la foto de
-- perfil, que es el archivo grande del sitio. La lista de tipos es la del
-- accept del formulario de subir un recaudo -imágenes y PDF- escrita uno a
-- uno en vez de con el comodín 'image/*', por dos razones: el comodín
-- depende de una versión de storage-api que no se puede dar por supuesta, y
-- escribirlos permite dejar fuera image/svg+xml, que es un documento con
-- guion dentro y nadie escanea un papel a SVG. Van heic y heif porque un
-- iPhone fotografía en eso y rechazarlo sería rechazar media sala de espera.
--
-- do update y no do nothing: en un proyecto que ya existía el cubo estaba
-- creado, y con do nothing este archivo se ejecutaba entero sin llegar a
-- ponerle el tope nunca.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'recaudos', 'recaudos', false,
  10485760,
  array['image/jpeg','image/png','image/webp','image/heic','image/heif',
        'image/tiff','image/bmp','application/pdf']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Subir, reemplazar y borrar: SOLO SI NO EXISTEN (8-10-2026, auditoría de
-- seguridad). Las que valen son las de supabase-tramites-y-bloqueo.sql,
-- que cierran emitidos/, los papeles validados y las cuentas bloqueadas.
-- Antes este archivo hacía drop + create, y volver a correrlo suelto dejaba
-- a un inversionista sustituir con x-upsert una resolución del CIIP.
do $solo$
begin
  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects'
                  and policyname = 'recaudos: subir a su carpeta') then
    create policy "recaudos: subir a su carpeta" on storage.objects
      for insert to authenticated
      with check (bucket_id = 'recaudos' and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects'
                  and policyname = 'recaudos: reemplazar en su carpeta') then
    create policy "recaudos: reemplazar en su carpeta" on storage.objects
      for update to authenticated
      using (bucket_id = 'recaudos' and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
  if not exists (select 1 from pg_policies where schemaname = 'storage' and tablename = 'objects'
                  and policyname = 'recaudos: borrar de su carpeta') then
    create policy "recaudos: borrar de su carpeta" on storage.objects
      for delete to authenticated
      using (bucket_id = 'recaudos' and (storage.foldername(name))[1] = auth.uid()::text);
  end if;
end
$solo$;

drop policy if exists "recaudos: leer su carpeta" on storage.objects;
create policy "recaudos: leer su carpeta" on storage.objects
  for select to authenticated
  using (bucket_id = 'recaudos' and ((storage.foldername(name))[1] = auth.uid()::text or public.es_gestor()));


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
-- 4) El cubo tiene que salir privado, con su tope y su lista de tipos. Si
--    file_size_limit sale en null, este archivo se ejecutó cuando el cubo
--    ya existía y con la versión vieja, la del `do nothing`: vuelve a
--    correrlo entero.
--
--   select id, public, file_size_limit, allowed_mime_types
--   from storage.buckets where id = 'recaudos';
--
-- 5) La escalera de estados. Este salto tiene que fallar, entrando con
--    una cuenta del equipo desde la aplicación (desde el SQL Editor no
--    prueba nada: allí auth.uid() es null y el trigger se aparta a
--    propósito). Coge un trámite en 'enviado' y trata de resolverlo:
--
--   update public.tramites set estado = 'resuelto' where id = '…';
--
--    Debe responder: Un trámite no pasa de "enviado" a "resuelto".
--
-- 6) Prueba del aislamiento, que es lo único que de verdad importa.
--    Entra en la aplicación con DOS cuentas distintas y comprueba que la
--    segunda no ve ni un documento ni un trámite de la primera. Hacerlo
--    desde el SQL Editor no vale: ahí auth.uid() es null y RLS no aplica.

-- ====================================================================
--  03 / 105   supabase-admin.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — USUARIOS Y ROLES
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-setup.sql y de supabase-gestor.sql.
-- ═══════════════════════════════════════════════════════════════════════
--
--  LO QUE CAMBIA, Y LO QUE NO
--  ─────────────────────────────────────────────────────────────────────
--  Hasta ahora NADIE podía cambiar un rol desde el navegador: el
--  disparador lo rechazaba en cuanto la petición traía sesión de usuario.
--  Para hacer gestor a alguien había que entrar a Supabase y escribir un
--  update a mano. Seguro, y también un cuello de botella de una persona.
--
--  Ahora puede hacerlo un admin desde el panel. Se afloja UNA cosa y se
--  mantienen las otras tres:
--
--    SE AFLOJA   un admin con sesión abierta puede cambiar roles.
--
--    SE MANTIENE que la comprobación vive en la BASE, no en la pantalla.
--                Esconder el botón nunca fue la cerradura.
--    SE MANTIENE que NADIE puede cambiar su propio rol. Un gestor no se
--                asciende a admin, y un admin no se degrada por error
--                dejando al CIIP sin ninguno.
--    SE MANTIENE que el primer admin solo se hace desde aquí. Sin eso,
--                una cuenta cualquiera podría empezar la cadena.
--
--  Y se añade rastro: quién lo cambió y cuándo. Lo escribe el disparador,
--  así que no se puede falsear desde el navegador.
--
--  EL RIESGO QUE ASUMES, DICHO CLARO
--  ─────────────────────────────────────────────────────────────────────
--  Antes, para repartir roles hacía falta ser admin Y tener acceso al
--  panel de Supabase. Ahora basta una sesión de admin. Si alguien roba esa
--  sesión, puede hacer gestor a una cuenta suya y leer todos los
--  expedientes.
--
--  A cambio, el CIIP deja de depender de una sola persona con la llave de
--  la base de datos. Es un intercambio razonable mientras los admin sean
--  pocos y conocidos; deja de serlo el día que haya diez.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
--  1 · ¿ES ADMIN?
-- ───────────────────────────────────────────────────────────────────────
-- Hermana de es_gestor(), pero solo admin. security definer para poder
-- leer perfiles sin entrar en el bucle de sus propias políticas.
-- SOLO SI NO EXISTE (8-10-2026, auditoría de seguridad). La versión que
-- vale es la de supabase-qa-admin.sql, que además mira «bloqueado» (QA-05).
-- Esta columna aún no existe cuando este archivo corre en una base nueva,
-- así que aquí no se puede poner la definición final; pero volver a correr
-- este archivo suelto en una base que ya la tiene NO debe pisarla: un
-- admin bloqueado recuperaría todos sus permisos.
do $solo$
begin
  if to_regprocedure('public.es_admin()') is null then
    execute $f$
      create function public.es_admin()
      returns boolean
      language sql
      stable
      security definer
      set search_path = public
      as $q$
        select exists (
          select 1 from public.perfiles p
          where p.id = auth.uid() and p.rol = 'admin'
        );
      $q$
    $f$;
  end if;
end
$solo$;


-- ───────────────────────────────────────────────────────────────────────
--  2 · RASTRO DE QUIÉN REPARTE LOS ROLES
-- ───────────────────────────────────────────────────────────────────────
alter table public.perfiles
  add column if not exists rol_cambiado_por uuid references auth.users(id) on delete set null,
  add column if not exists rol_cambiado_en  timestamptz;

comment on column public.perfiles.rol_cambiado_por is
  'Quién cambió el rol la última vez. Lo escribe el disparador: no llega del navegador';


-- ───────────────────────────────────────────────────────────────────────
--  3 · EL DISPARADOR, CON LA REGLA NUEVA
-- ───────────────────────────────────────────────────────────────────────
create or replace function public.bloquear_cambio_de_rol()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.rol is not distinct from old.rol then
    return new;
  end if;

  -- Sin sesión: viene del editor de SQL o de un proceso del servidor. Es
  -- como se hace el primer admin, y sigue permitido.
  if auth.uid() is null then
    return new;
  end if;

  if not public.es_admin() then
    raise exception 'Solo un administrador puede cambiar roles';
  end if;

  -- Ni el propio. Un gestor no se asciende, y un admin no se queda sin
  -- serlo por un descuido dejando al CIIP sin ninguno.
  if new.id = auth.uid() then
    raise exception 'Nadie puede cambiar su propio rol';
  end if;

  new.rol_cambiado_por := auth.uid();
  new.rol_cambiado_en  := now();
  return new;
end;
$$;

drop trigger if exists proteger_rol on public.perfiles;
create trigger proteger_rol
  before update on public.perfiles
  for each row execute function public.bloquear_cambio_de_rol();


-- ───────────────────────────────────────────────────────────────────────
--  4 · Y EL PERMISO PARA ESCRIBIR EN LA FILA DE OTRO
-- ───────────────────────────────────────────────────────────────────────
-- El disparador decide QUÉ se puede cambiar; la política decide QUIÉN
-- puede tocar la fila. Hacen falta las dos: sin política, el update no
-- llega a ejecutarse y el disparador no se entera de nada.
--
-- El admin solo puede tocar el rol de otro, no su nombre ni su país: eso
-- lo garantiza el disparador comparando el resto de columnas.
drop policy if exists "perfiles: el admin reparte roles" on public.perfiles;
create policy "perfiles: el admin reparte roles" on public.perfiles
  for update
  using      (public.es_admin())
  with check (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
--  EL PRIMER ADMIN
-- ───────────────────────────────────────────────────────────────────────
-- Sigue haciéndose aquí, sin sesión, y es a propósito: si se pudiera desde
-- el panel, una cuenta cualquiera podría empezar la cadena.
--
--   update public.perfiles set rol = 'admin'
--    where id = (select id from auth.users where email = 'tu@correo');
--
-- COMPROBACIÓN — las dos deben decir true:
--   select public.es_admin();
--   select relrowsecurity from pg_class where relname = 'perfiles';

-- ====================================================================
--  04 / 105   supabase-citas.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LAS CITAS
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable: todo va con "if not exists" o con "drop ... if exists",
--  así que volver a pasarlo no rompe lo que ya esté.
--
--  ORDEN: va DESPUÉS de supabase-setup.sql y de supabase-tramites.sql.
--  De ahí salen public.es_gestor() y public.tocar_actualizado_en(), que
--  este archivo usa y no vuelve a definir.
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ES UNA CITA AQUÍ
--  ─────────────────────────────────────────────────────────────────────
--  Una PETICIÓN, no una reserva. El inversionista dice de qué quiere
--  hablar, cómo prefiere verse y qué días le vienen bien; el CIIP pone la
--  fecha. No hay agenda con huecos libres, y por eso no hay tabla de
--  disponibilidad: publicar huecos que nadie mantiene es enseñar horas
--  que no existen, y la tarjeta del c7 ya promete lo contrario —"la cita
--  la coordina el CIIP"—.
--
--  Por eso la hora exacta (cuando) nace en null: no la sabe quien pide.
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.citas (
  id             uuid primary key default gen_random_uuid(),
  inversionista  uuid not null references auth.users(id) on delete cascade,

  -- De qué trámite se quiere hablar. Null = una consulta general, que es
  -- un caso legítimo y no un dato que falte: no toda cita es de un trámite.
  tipo_tramite   text references public.tipos_tramite(codigo),

  modo           text not null,
  -- La ventana que le viene bien a quien pide. Dos fechas y no una: pedir
  -- un día exacto obliga a acertar con la agenda del CIIP a ciegas, y la
  -- respuesta sería "ese no, dime otro" la mitad de las veces.
  desde          date not null,
  hasta          date not null,
  nota           text not null default '',

  estado         text not null default 'solicitada',
  gestor         uuid references auth.users(id) on delete set null,

  -- Lo que pone el CIIP al confirmar. Nacen vacíos a propósito.
  cuando         timestamptz,
  lugar          text not null default '',

  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),

  constraint citas_modo_valido
    check (modo in ('presencial','video','telefono')),

  constraint citas_estado_valido
    check (estado in ('solicitada','confirmada','hecha','cancelada')),

  -- Una ventana al revés no es un error del usuario que haya que tolerar:
  -- es una fila que ningún gestor podría atender.
  constraint citas_ventana_valida
    check (hasta >= desde),

  -- Una cita confirmada SIN fecha es una promesa vacía, y el panel la
  -- enseñaría como "confirmada para el —". La base no la deja existir.
  constraint citas_confirmada_con_fecha
    check (estado <> 'confirmada' or cuando is not null)
);

comment on table  public.citas               is 'Peticiones de cita del inversionista. El CIIP pone la fecha';
comment on column public.citas.tipo_tramite  is 'De qué trámite se quiere hablar. Null = consulta general';
comment on column public.citas.modo          is 'presencial, video o telefono. Lo elige quien pide';
comment on column public.citas.desde         is 'Primer día que le viene bien';
comment on column public.citas.hasta         is 'Último día que le viene bien';
comment on column public.citas.cuando        is 'Fecha y hora que fija el CIIP. Null mientras esté solicitada';
comment on column public.citas.lugar         is 'Dirección si es presencial, o el enlace si es por video';
comment on column public.citas.estado        is 'solicitada = pedida; confirmada = con fecha; hecha; cancelada';

-- La cola del gestor: lo que nadie ha atendido todavía, primero lo viejo.
create index if not exists citas_cola
  on public.citas (estado, creado_en) where estado = 'solicitada';

create index if not exists citas_por_inversionista
  on public.citas (inversionista, estado);


-- ───────────────────────────────────────────────────────────────────────
--  QUIÉN PUEDE QUÉ
-- ───────────────────────────────────────────────────────────────────────
alter table public.citas enable row level security;

drop policy if exists "citas: leer las propias" on public.citas;
create policy "citas: leer las propias" on public.citas
  for select using (inversionista = auth.uid() or public.es_gestor());

-- Se pide SIEMPRE en estado 'solicitada' y sin fecha. Sin esto, cualquiera
-- podría insertarse una cita ya "confirmada" para el martes a las nueve y
-- presentarse en la oficina con una captura de pantalla como prueba.
drop policy if exists "citas: pedir las propias" on public.citas;
create policy "citas: pedir las propias" on public.citas
  for insert with check (
    inversionista = auth.uid()
    and estado = 'solicitada'
    and cuando is null
    and gestor is null
    and lugar = ''
  );

-- El inversionista solo puede CANCELAR, y solo lo que aún no ha pasado.
-- Cambiar el asunto o las fechas de una cita ya confirmada dejaría al
-- gestor con una reunión que no es la que aceptó.
drop policy if exists "citas: cancelar las propias" on public.citas;
create policy "citas: cancelar las propias" on public.citas
  for update
  using      ((inversionista = auth.uid() and estado in ('solicitada','confirmada')) or public.es_gestor())
  with check ((inversionista = auth.uid() and estado in ('solicitada','confirmada','cancelada')) or public.es_gestor());

-- Que la política deje pasar el UPDATE no basta: dentro de esa fila el
-- inversionista podría cambiar el estado a 'hecha', ponerse fecha o
-- adjudicarse un gestor. Eso se corta aquí, campo por campo.
create or replace function public.citas_solo_cancelar()
returns trigger
language plpgsql
as $$
begin
  -- auth.uid() es null desde el SQL Editor o con la clave service_role:
  -- el equipo del CIIP sí puede confirmar, mover y cerrar citas.
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;

  if new.estado is distinct from old.estado and new.estado <> 'cancelada' then
    raise exception 'Una cita solo se puede cancelar desde el panel';
  end if;

  if new.cuando        is distinct from old.cuando
  or new.lugar         is distinct from old.lugar
  or new.gestor        is distinct from old.gestor
  or new.tipo_tramite  is distinct from old.tipo_tramite
  or new.desde         is distinct from old.desde
  or new.hasta         is distinct from old.hasta
  or new.inversionista is distinct from old.inversionista then
    raise exception 'Esos datos de la cita los fija el CIIP';
  end if;

  return new;
end;
$$;

drop trigger if exists citas_proteger on public.citas;
create trigger citas_proteger
  before update on public.citas
  for each row execute function public.citas_solo_cancelar();

drop trigger if exists citas_marca_tiempo on public.citas;
create trigger citas_marca_tiempo
  before update on public.citas
  for each row execute function public.tocar_actualizado_en();

-- Nadie borra una cita: cancelarla deja constancia de que se pidió, y
-- borrarla haría desaparecer esa conversación del expediente.
-- (No se crea ninguna política de DELETE, así que RLS lo impide.)

-- ====================================================================
--  05 / 105   supabase-empresa.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — MI EMPRESA
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-setup.sql y de supabase-tramites.sql.
--  De ahí salen public.es_gestor() y public.tocar_actualizado_en().
-- ═══════════════════════════════════════════════════════════════════════
--
--  POR QUÉ HACE FALTA
--  ─────────────────────────────────────────────────────────────────────
--  La razón social se escribe a mano en OCHO formularios distintos. El RIF
--  de la empresa en seis. La dirección fiscal en cinco. El teléfono, la
--  actividad económica y el representante en cuatro cada uno.
--
--  Es el mismo problema que ya resolvió la bóveda con los recaudos —subes
--  el acta una vez y el siguiente trámite te la ofrece cargada—, pero un
--  piso más arriba: con los DATOS en vez de con los archivos.
--
--  Y no es solo tiempo. Escribir ocho veces "Bianchi Agroindustrias, C.A."
--  es escribirla ocho veces distintas: una con punto, otra sin la coma,
--  otra en mayúsculas. El ente devuelve el trámite por eso.
--
--  UNA POR INVERSIONISTA
--  ─────────────────────────────────────────────────────────────────────
--  La llave primaria ES el inversionista, no un id aparte. Quien vaya a
--  constituir dos compañías tendrá que esperar: hacerlo genérico ahora
--  obligaría a elegir empresa en cada formulario, y hoy no hay nadie con
--  dos. Cuando lo haya, esto se convierte en tabla con id propio y los
--  formularios ganan un selector.
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.empresas (
  inversionista uuid primary key references auth.users(id) on delete cascade,

  -- Lo que piden los formularios, con los mismos nombres que usan ellos:
  -- así el panel rellena por coincidencia de nombre y no hay una tabla de
  -- equivalencias que mantener.
  razon_social        text not null default '',
  rif_empresa         text not null default '',
  numero_registro     text not null default '',
  fecha_constitucion  date,
  capital_social      text not null default '',
  actividad_economica text not null default '',
  direccion_fiscal    text not null default '',
  municipio           text not null default '',
  telefono            text not null default '',
  representante       text not null default '',
  inicio_actividades  date,
  -- Texto y no número: los formularios lo piden como texto y algunos
  -- inversionistas responden "12 fijos y 4 por temporada".
  num_trabajadores    text not null default '',

  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),

  -- Sin razón social no hay empresa que rellenar en ningún sitio.
  constraint empresas_con_nombre check (length(trim(razon_social)) > 0)
);

comment on table public.empresas is
  'Los datos de la compañía del inversionista, para no volver a escribirlos en cada formulario';


-- ───────────────────────────────────────────────────────────────────────
--  QUIÉN PUEDE QUÉ
-- ───────────────────────────────────────────────────────────────────────
alter table public.empresas enable row level security;

-- La tuya, y solo la tuya.
drop policy if exists "empresas: la mia" on public.empresas;
create policy "empresas: la mia" on public.empresas
  for all to authenticated
  using      (inversionista = auth.uid())
  with check (inversionista = auth.uid());

-- El equipo la lee para revisar un trámite: los datos que llegan en la
-- solicitud salen de aquí, y sin poder verlos la revisión es a ciegas.
-- LEER, no escribir: la empresa es del inversionista.
drop policy if exists "empresas: el equipo las lee" on public.empresas;
create policy "empresas: el equipo las lee" on public.empresas
  for select
  using (public.es_gestor());

drop trigger if exists empresas_marca_tiempo on public.empresas;
create trigger empresas_marca_tiempo
  before update on public.empresas
  for each row execute function public.tocar_actualizado_en();


-- ───────────────────────────────────────────────────────────────────────
--  COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
-- Que la protección quedó puesta. Tiene que decir true:
--   select relname, relrowsecurity from pg_class where relname = 'empresas';

-- ====================================================================
--  06 / 105   supabase-activos.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL BANCO DE ACTIVOS Y OPORTUNIDADES
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-setup.sql y de supabase-tramites.sql.
--  De ahí sale public.es_gestor(), que este archivo usa.
-- ═══════════════════════════════════════════════════════════════════════
--
--  POR QUÉ NO ES UN TRÁMITE
--  ─────────────────────────────────────────────────────────────────────
--  Las otras treinta tarjetas del panel son solicitudes ante un organismo:
--  se piden, se revisan y se resuelven. Esta no. El banco de activos es el
--  catálogo del propio CIIP —lo que hay disponible para invertir— y lo que
--  el inversionista hace con él es MIRARLO.
--
--  Meterlo en el circuito de solicitudes le habría puesto estados que no
--  significan nada: "enviado", "ante el ente", "devuelto". Por eso es una
--  tabla aparte y una pantalla de listado, no un formulario.
--
--  Lo que sí es una solicitud es el INTERÉS en uno concreto, y eso ya
--  existe: se pide una cita sobre él.
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.activos (
  id          uuid primary key default gen_random_uuid(),

  titulo      text not null,
  sector      text not null default '',
  -- Dónde está. Sin normalizar a propósito: los activos del CIIP no caben
  -- en una lista cerrada de estados, y forzarla ahora obligaría a elegir
  -- entre "Zulia" y "Maracaibo, Zulia" sin saber cuál usa el catálogo.
  ubicacion   text not null default '',

  -- El monto es un rango, no una cifra: casi ninguna oportunidad se
  -- publica con precio cerrado, y poner uno exacto donde no lo hay
  -- ahuyenta a quien podría negociarlo.
  monto_desde numeric(14,2),
  monto_hasta numeric(14,2),
  moneda      text not null default 'USD',

  resumen     text not null default '',
  detalle     text not null default '',

  estado      text not null default 'disponible',
  -- Los que el CIIP quiere enseñar primero. Es lo unico que ordena el
  -- listado por encima de la fecha.
  destacado   boolean not null default false,

  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),

  constraint activos_estado_valido
    check (estado in ('disponible','reservado','cerrado')),

  -- Un rango al revés no es un dato que haya que tolerar: es una ficha que
  -- nadie podría leer.
  constraint activos_rango_valido
    check (monto_hasta is null or monto_desde is null or monto_hasta >= monto_desde)
);

comment on table  public.activos           is 'Catálogo del CIIP: activos y proyectos abiertos a inversión';
comment on column public.activos.estado    is 'disponible = abierto; reservado = con alguien en conversaciones; cerrado = ya no se ofrece';
comment on column public.activos.destacado is 'true = el CIIP lo quiere arriba del listado';

create index if not exists activos_visibles
  on public.activos (estado, destacado desc, creado_en desc);


-- ───────────────────────────────────────────────────────────────────────
--  QUIÉN PUEDE QUÉ
-- ───────────────────────────────────────────────────────────────────────
alter table public.activos enable row level security;

-- Lo ve cualquiera que haya entrado, sea inversionista o del equipo. Los
-- CERRADOS no: enseñar lo que ya no se ofrece es hacer perder el tiempo.
-- El equipo sí los ve, que para eso los administra.
drop policy if exists "activos: leer los abiertos" on public.activos;
create policy "activos: leer los abiertos" on public.activos
  for select to authenticated
  using (estado <> 'cerrado' or public.es_gestor());

-- Solo el equipo publica, corrige y retira. No hay política de insert ni de
-- update para el inversionista, así que RLS se las niega.
drop policy if exists "activos: el equipo los administra" on public.activos;
create policy "activos: el equipo los administra" on public.activos
  for all
  using      (public.es_gestor())
  with check (public.es_gestor());

drop trigger if exists activos_marca_tiempo on public.activos;
create trigger activos_marca_tiempo
  before update on public.activos
  for each row execute function public.tocar_actualizado_en();


-- ───────────────────────────────────────────────────────────────────────
--  CÓMO SE PUBLICA UNO
-- ───────────────────────────────────────────────────────────────────────
-- Desde el PANEL: quien tenga rol de gestor o admin ve un boton "Publicar un
-- activo" en la vista de Activos y proyectos, y otro de "Editar" en cada ficha.
-- Es la via normal, y evita que haya que entrar a la base de datos cada vez
-- que hay algo que ofrecer.
--
-- O desde aqui, si se van a cargar varios de golpe. Quita el comentario y
-- cambia lo que haga falta:

-- insert into public.activos (titulo, sector, ubicacion, monto_desde, monto_hasta, resumen, detalle, destacado)
-- values
--   ('Planta procesadora de cacao', 'Agroindustria', 'Miranda',
--    250000, 400000,
--    'Instalada y con permisos al día; busca socio para ampliar capacidad.',
--    'Capacidad actual de 12 t/mes con posibilidad de llegar a 30. Cuenta con licencia municipal, permiso sanitario y registro sanitario vigentes.',
--    true),
--   ('Desarrollo turístico costero', 'Turismo', 'Nueva Esparta',
--    800000, null,
--    'Terreno de 4 ha con vialidad y servicios, apto para hotelería.',
--    'Zonificado para uso turístico. Conformidad de uso obtenida.',
--    false);

-- Para retirar uno sin borrarlo -y sin perder de vista que existió-:
--   update public.activos set estado = 'cerrado' where id = '...';
-- Es lo que conviene casi siempre.
--
-- Borrarlo de verdad tambien se puede, y desde la propia ficha del panel:
-- editar el activo y pulsar Borrar dos veces. Entonces no queda rastro. La
-- politica de arriba -for all- ya deja el delete al equipo y a nadie mas,
-- asi que no hay nada que añadir aqui.

-- ====================================================================
--  07 / 105   supabase-identidad.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — QUIÉN COMPROBÓ LA IDENTIDAD, Y CUÁNDO
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-tramites.sql y de supabase-gestor.sql.
-- ═══════════════════════════════════════════════════════════════════════
--
--  LO QUE ESTO ES, Y LO QUE NO ES
--  ─────────────────────────────────────────────────────────────────────
--  NO valida la identidad contra nadie. No le pregunta al SAIME si esa
--  cédula existe, ni a migración si ese pasaporte es válido. Eso es la
--  capa de interoperabilidad y necesita que un organismo conteste.
--
--  Lo que hace es dejar CONSTANCIA de una comprobación que ya ocurre y
--  que hoy no se escribe en ninguna parte: el gestor abre el expediente,
--  mira la cédula escaneada, decide que está bien... y de eso no queda
--  rastro. Mañana nadie puede responder "¿quién comprobó que esta
--  persona es quien dice ser, y cuándo?".
--
--  Convertir un acto informal en un registro con nombre y fecha no es
--  automatizar la verificación. Es poder auditarla. Y es la pieza que
--  migra intacta el día que exista la plataforma: entonces cambiará
--  QUIÉN firma la comprobación, no que quede registrada.
--
--  APPEND-ONLY, Y AHÍ ESTÁ TODO EL VALOR
--  ─────────────────────────────────────────────────────────────────────
--  No hay política de update ni de delete. Ninguna. Una comprobación de
--  identidad que se puede reescribir después no prueba nada: quien la
--  firmó podría cambiarla el día que le convenga, y entonces la traza no
--  vale ni el disco que ocupa.
--
--  Si un gestor se equivoca, no corrige: escribe otra encima, con su
--  nota. Las dos quedan. Que se vea que hubo una rectificación es parte
--  de lo que se está auditando.
--
--  Es el mismo criterio de tramite_eventos, donde de la nota para abajo
--  no se toca nada.
--
--  Y EL AUTOR LO PONE LA BASE
--  ─────────────────────────────────────────────────────────────────────
--  El campo 'gestor' no se acepta de quien escribe: lo pone un disparador
--  con auth.uid(). Todo el valor de esto es saber QUIÉN lo comprobó; si
--  alguien pudiera poner el nombre de otro, el registro seria peor que no
--  tenerlo, porque parecería fiable.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
--  1. LA TABLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.identidad_comprobaciones (
  id             bigint generated always as identity primary key,
  inversionista  uuid not null references auth.users(id)      on delete cascade,
  -- contra qué se comprobó. El documento puede borrarse mañana; la
  -- comprobación no, así que el tipo y el número se guardan aquí y no
  -- solo por referencia.
  documento      uuid references public.documentos(id)        on delete set null,
  tipo_documento text not null references public.tipos_documento(codigo),
  numero         text not null default '',
  resultado      text not null,
  nota           text not null default '',
  gestor         uuid not null references auth.users(id),
  creado_en      timestamptz not null default now(),

  constraint identidad_resultado_valido
    check (resultado in ('comprobada','rechazada')),
  -- Rechazar sin decir por qué deja al inversionista sin saber qué
  -- arreglar, igual que una devolución sin nota.
  constraint identidad_rechazo_con_motivo
    check (resultado <> 'rechazada' or length(trim(nota)) > 0)
);

comment on table  public.identidad_comprobaciones is
  'Constancia de que alguien del CIIP miró el documento de identidad. NO es validación contra ningún organismo';
comment on column public.identidad_comprobaciones.gestor is
  'Quién lo comprobó. Lo pone la base con auth.uid(), no quien escribe';
comment on column public.identidad_comprobaciones.numero is
  'El número leído del documento. Es lo que hace la constancia concreta: "comprobé que la cédula V-12345678 es de esta persona"';

create index if not exists identidad_por_persona
  on public.identidad_comprobaciones (inversionista, creado_en desc);


-- ───────────────────────────────────────────────────────────────────────
--  2. EL AUTOR Y LA HORA LOS PONE LA BASE
-- ───────────────────────────────────────────────────────────────────────
create or replace function public.identidad_firma()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Sin sesión (editor de SQL, proceso del servidor) se respeta lo que
  -- venga: es la única forma de cargar un histórico si algún día hace
  -- falta, y ahí no hay a quién atribuírselo.
  if auth.uid() is not null then
    new.gestor    := auth.uid();
    new.creado_en := now();
  end if;
  return new;
end;
$$;

drop trigger if exists identidad_la_firma_la_base on public.identidad_comprobaciones;
create trigger identidad_la_firma_la_base
  before insert on public.identidad_comprobaciones
  for each row execute function public.identidad_firma();


-- ───────────────────────────────────────────────────────────────────────
--  3. QUIÉN VE Y QUIÉN ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
alter table public.identidad_comprobaciones enable row level security;

-- El inversionista ve las suyas. Tiene derecho a saber que alguien
-- revisó su documento, y cuándo: es información sobre él.
drop policy if exists "identidad: cada quien ve la suya" on public.identidad_comprobaciones;
create policy "identidad: cada quien ve la suya"
  on public.identidad_comprobaciones for select
  using (inversionista = auth.uid() or public.es_gestor());

-- Y solo el equipo escribe. El 'gestor = auth.uid()' del with check es
-- cinturón sobre tirantes: el disparador ya lo fuerza, pero si algún día
-- alguien toca el disparador, la política sigue en pie.
drop policy if exists "identidad: solo el equipo la firma" on public.identidad_comprobaciones;
create policy "identidad: solo el equipo la firma"
  on public.identidad_comprobaciones for insert
  with check (public.es_gestor() and gestor = auth.uid());

-- No hay política de update ni de delete, y es a propósito. Sin política
-- que lo permita, el RLS lo niega: nadie reescribe una comprobación de
-- identidad, ni siquiera quien la firmó.


-- ───────────────────────────────────────────────────────────────────────
--  COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--  La última comprobación de cada persona:
--
--    select distinct on (inversionista)
--           inversionista, resultado, tipo_documento, numero, creado_en, gestor
--      from public.identidad_comprobaciones
--     order by inversionista, creado_en desc;
--
--  Que de verdad no se pueda reescribir (tiene que dar 0 filas tocadas):
--
--    update public.identidad_comprobaciones set resultado = 'comprobada';
--
--  Ojo: desde el SQL Editor eso SÍ pasa, porque ahí se corre como dueño
--  y el RLS no se aplica. La prueba de verdad es pruebas/rls.js, que lo
--  intenta con una sesión de gestor, que es como llegaría de fuera.

-- ====================================================================
--  08 / 105   supabase-emision.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — ENTREGAR LO EMITIDO
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-tramites.sql y de supabase-gestor.sql.
-- ═══════════════════════════════════════════════════════════════════════
--
--  LA MITAD QUE FALTABA
--  ─────────────────────────────────────────────────────────────────────
--  El circuito terminaba en el aire. El gestor pulsaba "Resuelta", el
--  estado cambiaba, el inversionista recibía un aviso… y nada más. El RIF,
--  la licencia, la solvencia —lo único que la persona vino a buscar— se
--  entregaban por fuera: un correo, un WhatsApp, una carpeta compartida.
--
--  Con esto, el documento que emitió el organismo entra por el panel:
--  queda en la bóveda del inversionista, colgado de su trámite, y se abre
--  con una URL firmada como todo lo demás.
--
--  LO QUE NO ES
--  ─────────────────────────────────────────────────────────────────────
--  Esto NO es emisión con validez legal. No hay firma electrónica
--  avanzada, ni sellado de tiempo, ni código de verificación. Es la
--  ENTREGA de un documento que emitió el ente por su cuenta. Un PDF que
--  llega por el canal correcto, no un certificado que este sistema expide.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
--  1 · UN TIPO DE DOCUMENTO PARA LO EMITIDO
-- ───────────────────────────────────────────────────────────────────────
-- No caduca por sí mismo: unos vencen y otros no, y eso lo pone el gestor
-- al entregarlo, que es quien tiene el papel delante.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('resolucion', 'Documento emitido por el organismo', false)
on conflict (codigo) do update set nombre = excluded.nombre;


-- ───────────────────────────────────────────────────────────────────────
--  2 · EL EQUIPO PUEDE DEJAR UN DOCUMENTO EN LA BÓVEDA DE OTRO
-- ───────────────────────────────────────────────────────────────────────
-- Y SOLO de este tipo. Un gestor no puede plantarle a nadie un pasaporte
-- ni un acta: solo lo que el organismo emitió y él está entregando.
--
-- Entra como 'validado' a propósito: lo emitió el ente, no hay nada que
-- revisar, y de paso la política "documentos: borrar los no validados"
-- impide que el inversionista lo borre sin querer.
drop policy if exists "documentos: el equipo entrega lo emitido" on public.documentos;
create policy "documentos: el equipo entrega lo emitido" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'resolucion' and estado = 'validado');

-- Y colgarlo del trámite. Sin esto el documento estaría en la bóveda pero
-- suelto, sin decir de qué solicitud salió.
drop policy if exists "adjuntos: el equipo cuelga lo emitido" on public.tramite_documentos;
create policy "adjuntos: el equipo cuelga lo emitido" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1 from public.documentos d
      where d.id = documento and d.tipo = 'resolucion'
    )
  );


-- ───────────────────────────────────────────────────────────────────────
--  3 · Y SUBIR EL ARCHIVO A LA CARPETA DEL INVERSIONISTA
-- ───────────────────────────────────────────────────────────────────────
-- El equipo ya podía LEER cualquier carpeta del cubo —para revisar los
-- recaudos—, pero solo escribir en la suya. Aquí necesita dejar el archivo
-- en la del inversionista, que es donde vive su expediente.
--
-- Se limita a la subcarpeta 'emitidos': así lo que el equipo deja queda
-- separado de lo que subió la persona, y una ruta lo dice sin consultar
-- nada.
drop policy if exists "recaudos: el equipo deja lo emitido" on storage.objects;
create policy "recaudos: el equipo deja lo emitido" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'recaudos'
    and public.es_gestor()
    and (storage.foldername(name))[2] = 'emitidos'
  );


-- ───────────────────────────────────────────────────────────────────────
--  COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
-- Las tres políticas nuevas tienen que aparecer:
--   select policyname from pg_policies
--    where policyname like '%emitido%' or policyname like '%entrega%';
--
-- Y el tipo de documento:
--   select * from public.tipos_documento where codigo = 'resolucion';

-- ====================================================================
--  09 / 105   supabase-presencia.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — QUIÉN ESTÁ Y QUIÉN NO
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-setup.sql.
-- ═══════════════════════════════════════════════════════════════════════
--
--  LO QUE ESTO MIDE, Y LO QUE NO
--  ─────────────────────────────────────────────────────────────────────
--  No mide si alguien está conectado: eso no se puede saber. Un navegador
--  no avisa cuando se cierra, ni cuando se va la luz, ni cuando alguien
--  cierra la tapa del portátil.
--
--  Mide la ÚLTIMA VEZ QUE EL PANEL ESTUVO ABIERTO. El panel lo apunta al
--  entrar y cada dos minutos mientras la pestaña esté a la vista. De ahí
--  sale el "en línea": no es una conexión, es "hace menos de tres
--  minutos". Alguien con la pestaña abierta de fondo cuenta como presente,
--  y es correcto: el panel está abierto.
--
--  Lo que sí resuelve, y era lo que faltaba: saber quién del equipo lleva
--  un mes sin entrar, o si un inversionista abrió el panel alguna vez.
--
--  LA HORA LA PONE EL SERVIDOR
--  ─────────────────────────────────────────────────────────────────────
--  Y no el navegador. Si la escribiera el navegador, un reloj mal puesto
--  dejaría a alguien "en línea" desde mañana o desaparecido desde 2019, y
--  cualquiera podría escribir la hora que quisiera.
-- ═══════════════════════════════════════════════════════════════════════

alter table public.perfiles
  add column if not exists visto_en timestamptz;

comment on column public.perfiles.visto_en is
  'Ultima vez que el panel estuvo abierto. La escribe tocar_visto() con la hora del servidor';


-- ───────────────────────────────────────────────────────────────────────
--  APUNTAR QUE SIGO AQUÍ
-- ───────────────────────────────────────────────────────────────────────
-- security definer para poner la hora del SERVIDOR y para no depender de
-- que la política de update de perfiles cambie mañana. Solo toca tu propia
-- fila y solo esa columna: no hay forma de escribir la de otro.
create or replace function public.tocar_visto()
returns void
language sql
security definer
set search_path = public
as $$
  update public.perfiles set visto_en = now() where id = auth.uid();
$$;

-- OJO CON EL 'revoke ... from public': EN SUPABASE NO BASTA.
--
-- Supabase tiene puesto un 'alter default privileges' que concede EXECUTE
-- sobre toda funcion nueva del esquema public a anon, authenticated y
-- service_role. Eso es un grant NOMINAL a cada rol, no el de PUBLIC, asi
-- que revocarle a PUBLIC no lo quita: anon se queda con el suyo.
--
-- Se vio corriendo PROBAR-CERRADURAS.bat contra un Supabase de verdad: la
-- clave anonima llamaba a esta funcion y le contestaban 200. No hacia
-- daño -con auth.uid() nulo no toca ninguna fila- pero una puerta que
-- acepta a quien no deberia es una puerta abierta. En un Postgres normal
-- esto no pasa, asi que ningun arnes local podia verlo.
revoke all on function public.tocar_visto() from public;
revoke all on function public.tocar_visto() from anon;
grant execute on function public.tocar_visto() to authenticated;


-- ───────────────────────────────────────────────────────────────────────
--  COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--   select public.tocar_visto();
--   select nombre_completo, visto_en from public.perfiles order by visto_en desc nulls last;

-- ====================================================================
--  10 / 105   supabase-sectores.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL SECTOR EN EL QUE SE VA A INVERTIR
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-admin.sql, de donde sale es_admin().
-- ═══════════════════════════════════════════════════════════════════════
--
--  LO QUE ESTO ES, Y LO QUE NO ES
--  ─────────────────────────────────────────────────────────────────────
--  Guarda UNA respuesta: en qué sector va a invertir cada inversionista.
--  El panel la pide una sola vez, antes de dejar entrar, y a partir de
--  ahí la lleva en el expediente.
--
--  NO decide qué trámites le tocan. Eso lo dice la normativa, y la
--  normativa la tiene el CIIP, no este archivo. El día que llegue esa
--  matriz —qué sector exige qué permisos ante qué organismo— se apoyará
--  en esta columna; hasta entonces el sector se guarda, se enseña y se
--  puede cambiar, y los treinta y un trámites se siguen viendo todos.
--
--  Decirlo importa: un filtro inventado que esconda un trámite que sí
--  hacía falta es peor que no filtrar nada. El inversionista no sabría
--  que le falta algo hasta que el organismo se lo diga.
--
--  EL CATÁLOGO VIVE EN LA BASE, NO EN EL CÓDIGO
--  ─────────────────────────────────────────────────────────────────────
--  Igual que tipos_tramite. Añadir, quitar o renombrar un sector es un
--  INSERT o un UPDATE que hace el CIIP, no una versión nueva del panel.
--  ref_panel ('s1', 's2'…) es el enganche para traducirlo a los seis
--  idiomas en pasos.js; mientras no haya traducción se enseña el nombre
--  en español que esté aquí, que es honesto y no deja el hueco vacío.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL CATÁLOGO
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.sectores (
  codigo    text        primary key,
  ref_panel text        not null unique,
  nombre    text        not null,
  orden     smallint    not null default 0,
  activo    boolean     not null default true,
  creado_en timestamptz not null default now(),

  constraint sectores_nombre_no_vacio check (length(trim(nombre)) > 0)
);

comment on table  public.sectores           is 'Los sectores económicos que puede elegir un inversionista';
comment on column public.sectores.ref_panel is 'Identificador para traducir el nombre en pasos.js (s1…sN)';
comment on column public.sectores.orden     is 'Orden en que se ofrecen; a igual orden, alfabético';
comment on column public.sectores.activo    is 'false = ya no se ofrece, pero quien lo eligió lo conserva';

alter table public.sectores enable row level security;

-- Lo lee cualquiera que haya entrado: es el catálogo que hay que elegir.
drop policy if exists "sectores: leerlos" on public.sectores;
create policy "sectores: leerlos"
  on public.sectores for select
  to authenticated
  using (true);

-- Y solo el equipo lo toca. Sin esto, un inversionista podría inventarse
-- un sector y el catálogo dejaría de ser un catálogo.
drop policy if exists "sectores: solo el admin escribe" on public.sectores;
create policy "sectores: solo el admin escribe"
  on public.sectores for all
  using      (public.es_admin())
  with check (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 2. LA RESPUESTA, EN EL PERFIL
-- ───────────────────────────────────────────────────────────────────────
-- on delete set null y no cascade: si el CIIP borra un sector del
-- catálogo, el inversionista se queda sin sector —y el panel se lo vuelve
-- a preguntar—, pero NO se borra su perfil con él.
alter table public.perfiles
  add column if not exists sector text
  references public.sectores(codigo) on delete set null;

alter table public.perfiles
  add column if not exists sector_elegido_en timestamptz;

comment on column public.perfiles.sector is 'Sector en el que declara que va a invertir; null = todavía no ha contestado';

-- La fecha la pone la base y no el navegador, por lo mismo de siempre: el
-- reloj del navegador lo mueve quien quiera.
create or replace function public.sellar_sector()
returns trigger
language plpgsql
as $$
begin
  if new.sector is distinct from old.sector then
    new.sector_elegido_en := case when new.sector is null then null else now() end;
  end if;
  return new;
end;
$$;

drop trigger if exists sellar_sector on public.perfiles;
create trigger sellar_sector
  before update on public.perfiles
  for each row execute function public.sellar_sector();

-- El equipo necesita verlo para atender: saber en qué sector está quien
-- escribe es la mitad del contexto. La política de lectura del gestor ya
-- existe en supabase-gestor.sql y alcanza a la fila entera.


-- ───────────────────────────────────────────────────────────────────────
-- 3. EL CATÁLOGO DEL CIIP
-- ───────────────────────────────────────────────────────────────────────
--  AQUÍ VA LA LISTA. Es lo único de este archivo que hay que rellenar, y
--  el único sitio donde se toca: ni el panel ni pasos.js llevan sectores
--  escritos dentro.
--
--  Mientras esté vacía el panel NO bloquea a nadie. Es a propósito: una
--  puerta cerrada con una lista vacía detrás es una puerta sin llave, y
--  dejaría fuera a todo el mundo hasta que alguien corriera este archivo.
--
--  Los ocho motores productivos, en el orden en que los presenta el CIIP.
--  El on conflict ACTUALIZA en vez de fallar, así que corregir un nombre
--  es cambiarlo aquí y volver a correr el archivo entero.
insert into public.sectores (codigo, ref_panel, nombre, orden) values
  ('hidrocarburos',      's1', 'Hidrocarburos',        10),
  ('mineria',            's2', 'Minería',              20),
  ('industrial',         's3', 'Industrial',           30),
  ('turismo',            's4', 'Turismo',              40),
  ('agroindustrial',     's5', 'Agroindustrial',       50),
  ('salud',              's6', 'Salud',                60),
  ('pesca_acuicultura',  's7', 'Pesca y acuicultura',  70),
  ('forestal',           's8', 'Forestal',             80)
on conflict (codigo) do update
  set ref_panel = excluded.ref_panel,
      nombre    = excluded.nombre,
      orden     = excluded.orden,
      activo    = true;

-- Para retirar uno NO lo borres: quien ya lo eligió perdería su respuesta,
-- y el panel se lo volvería a preguntar al entrar.
--
--   update public.sectores set activo = false where codigo = 'forestal';
--
-- Los nombres en los otros cinco idiomas están en pasos.js, colgados de
-- ref_panel. Si añades un sector nuevo aquí y no allí, se enseña este
-- nombre en español: se ve raro, pero se ve, que es mejor que un hueco.


-- ───────────────────────────────────────────────────────────────────────
-- 4. COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
do $$
declare n integer;
begin
  select count(*) into n from public.sectores where activo;
  if n = 0 then
    raise notice 'Sectores: la tabla está creada y VACÍA. El panel no pedirá el sector hasta que haya al menos uno (apartado 3 de este archivo).';
  else
    raise notice 'Sectores: % activos en el catálogo.', n;
  end if;
end $$;

-- ====================================================================
--  11 / 105   supabase-catalogos.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS CATÁLOGOS, EN MANOS DEL ADMIN
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable: se puede volver a lanzar sin romper nada.
--
--  ORDEN: va después de supabase-tramites.sql, supabase-admin.sql y
--  supabase-sectores.sql. Necesita que public.es_admin() ya exista.
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ARREGLA
--  ─────────────────────────────────────────────────────────────────────
--  Tres catálogos de la ventanilla eran de SOLO LECTURA desde el
--  navegador. Nadie podía tocarlos, tampoco un admin:
--
--    tipos_tramite     qué trámites están encendidos. 31 en el catálogo,
--                      y 'activo' decide si cada uno enseña su formulario
--                      de verdad o solo la escalera decorativa. Es el
--                      interruptor más importante del producto.
--    bancos_aliados    la red de bancos con los que se abren cuentas.
--    tipos_documento   qué recaudos sabe recibir la ventanilla, y cuáles
--                      caducan —de eso depende que el formulario pida la
--                      fecha de vencimiento—.
--
--  Para cambiar cualquiera de las tres había que entrar aquí, a Supabase,
--  y escribir un update a mano. Es decir: encender un trámite dependía de
--  que estuviera disponible quien supiera SQL.
--
--  (sectores ya tenía su política de admin desde supabase-sectores.sql;
--  aquí no se toca.)
--
--  POR QUÉ ESTO NO ES COSMÉTICO
--  ─────────────────────────────────────────────────────────────────────
--  RLS no da error cuando bloquea: un update sin política contesta que
--  todo fue bien y no cambia ni una fila. Si el panel enseñara un
--  interruptor sin esto puesto, se encendería en pantalla, no haría nada,
--  y no avisaría a nadie. Un botón que miente es peor que un botón que
--  falta.
--
--  Por eso el panel, además, comprueba que la fila vuelva: pide .select()
--  después de escribir y, si no vuelve nada, lo dice. Las dos mitades del
--  mismo cuidado.
--
--  EL RIESGO QUE ASUMES, DICHO CLARO
--  ─────────────────────────────────────────────────────────────────────
--  Un admin con la sesión abierta puede apagar un trámite que está en uso.
--  Los expedientes ya enviados NO se tocan —siguen en 'tramites' con su
--  historial— pero el trámite deja de ofrecerse a quien no lo haya
--  empezado, y quien lo tenga a medias deja de ver el formulario.
--
--  Apagar no borra. Es la diferencia que hace que esto se pueda dar a un
--  admin sin miedo: lo peor que puede hacer es esconder algo, y se
--  vuelve a encender con el mismo botón.
--
--  LO QUE NO SE AFLOJA
--  ─────────────────────────────────────────────────────────────────────
--  · Leer sigue abierto a cualquier sesión: el catálogo lo necesita el
--    panel de todo el mundo para pintar las tarjetas.
--  · Escribir es SOLO para admin. Ni el gestor ni el inversionista.
--  · La comprobación vive en la BASE. Esconder el botón nunca fue la
--    cerradura, y esta vez tampoco.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────
-- Sin es_admin() esto no se sostiene, y fallar aquí con un mensaje claro
-- es mejor que crear políticas que llaman a una función que no existe.
do $$
begin
  if not exists (
    select 1 from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'es_admin'
  ) then
    raise exception 'Falta public.es_admin(). Pasa antes supabase-admin.sql.';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LOS TRÁMITES: EL INTERRUPTOR
-- ───────────────────────────────────────────────────────────────────────
-- Se permite UPDATE y no 'for all' a propósito. Un admin enciende y apaga
-- lo que hay; inventarse un trámite nuevo o borrar uno del catálogo es
-- otra cosa —arrastra su ref_panel, su tarjeta y sus recaudos— y esa sigue
-- pidiendo pasar por aquí, que es donde se ve el estropicio antes de
-- hacerlo.
alter table public.tipos_tramite enable row level security;

drop policy if exists "tipos_tramite: el admin enciende y apaga" on public.tipos_tramite;
create policy "tipos_tramite: el admin enciende y apaga"
  on public.tipos_tramite for update to authenticated
  using      (public.es_admin())
  with check (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 2. LOS BANCOS ALIADOS
-- ───────────────────────────────────────────────────────────────────────
-- Aquí sí va 'for all': la red de bancos cambia —entra uno, sale otro— y
-- eso es mantenimiento de lista, no cirugía. Un banco de más en el
-- desplegable no rompe ningún expediente.
alter table public.bancos_aliados enable row level security;

drop policy if exists "bancos_aliados: solo el admin escribe" on public.bancos_aliados;
create policy "bancos_aliados: solo el admin escribe"
  on public.bancos_aliados for all to authenticated
  using      (public.es_admin())
  with check (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 3. LOS RECAUDOS QUE SABE RECIBIR LA VENTANILLA
-- ───────────────────────────────────────────────────────────────────────
-- Solo UPDATE, y por la misma razón que en los trámites: el código de un
-- recaudo lo referencian los documentos ya subidos —documentos.tipo apunta
-- aquí— y borrar uno se llevaría por delante papeles de gente. Cambiar su
-- nombre, o si caduca, no le hace daño a nadie.
alter table public.tipos_documento enable row level security;

drop policy if exists "tipos_documento: el admin lo mantiene" on public.tipos_documento;
create policy "tipos_documento: el admin lo mantiene"
  on public.tipos_documento for update to authenticated
  using      (public.es_admin())
  with check (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. Las políticas. Esto es lo que de verdad dice si funcionó: tiene que
--    salir una línea por cada una de las nuevas —UPDATE en tipos_tramite,
--    ALL en bancos_aliados, UPDATE en tipos_documento— y las de leer
--    intactas al lado. Si falta alguna, el interruptor del panel se
--    encenderá sin cambiar nada.
select tablename, cmd, policyname
from   pg_policies
where  schemaname = 'public'
  and  tablename in ('tipos_tramite', 'bancos_aliados', 'tipos_documento', 'sectores')
order  by tablename, cmd, policyname;

-- 2. Quién es admin. Las políticas de arriba no sirven de nada si tu
--    cuenta no lo es: el panel te enseñaría la lista y cada botón diría
--    que la base no dejó.
--
--    Si aquí no sale tu cuenta, el primer admin se hace desde este mismo
--    editor —está explicado en supabase-admin.sql—; desde el navegador no
--    se puede empezar la cadena, y eso es a propósito.
select p.rol, p.nombre_completo, u.email
from   public.perfiles p
join   auth.users u on u.id = p.id
where  p.rol in ('admin', 'gestor')
order  by p.rol, u.email;

-- NO se pregunta aquí por public.es_admin(). Esa función mira auth.uid()
-- —quién tiene la sesión abierta— y este editor no corre como un usuario:
-- corre como postgres, sin sesión. Devolvería false siempre, también con
-- todo bien puesto, y una comprobación que solo sabe decir que no es peor
-- que ninguna. Donde sí vale es en el navegador, y ahí la hace la propia
-- política cada vez que el panel escribe.


-- ───────────────────────────────────────────────────────────────────────
-- 4. Y QUE EL INTERRUPTOR DEJE RASTRO
-- ───────────────────────────────────────────────────────────────────────
-- Encender o apagar un trámite es de las cosas más consecuentes que puede
-- hacer un admin —cambia lo que la ventanilla ofrece a todo el mundo— y
-- hasta ahora no quedaba constancia de quién lo hizo. La pantalla de
-- Rastro lo decía en voz alta, que es mejor que callarlo, pero decirlo no
-- es arreglarlo.
--
-- Se copia lo que ya hace supabase-admin.sql con los roles: lo escribe un
-- DISPARADOR y no el navegador. Un campo que rellena quien escribe es un
-- campo que quien escribe puede mentir.
alter table public.tipos_tramite
  add column if not exists activo_por uuid references auth.users(id) on delete set null,
  add column if not exists activo_en  timestamptz;

comment on column public.tipos_tramite.activo_por is
  'Quién encendió o apagó este trámite. Lo pone el disparador, no el cliente';
comment on column public.tipos_tramite.activo_en is
  'Cuándo se movió el interruptor por última vez';

-- Solo cuando CAMBIA 'activo'. Sin esta guarda, cualquier update sobre la
-- fila —renombrar el trámite, corregir el ente— reescribiría la fecha y el
-- rastro diría que alguien lo encendió cuando solo le arreglaron una tilde.
create or replace function public.marca_quien_movio_el_interruptor()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.activo is distinct from old.activo then
    new.activo_por := auth.uid();
    new.activo_en  := now();
  end if;
  return new;
end $$;

drop trigger if exists tipos_tramite_rastro on public.tipos_tramite;
create trigger tipos_tramite_rastro
  before update on public.tipos_tramite
  for each row execute function public.marca_quien_movio_el_interruptor();

-- Lo que ESTO no resuelve, dicho para que no se dé por resuelto: se guarda
-- el ÚLTIMO movimiento de cada trámite, no su historial. Igual que los
-- roles. Si algún día hace falta saber que se encendió y se apagó tres
-- veces en una semana, eso pide una tabla de bitácora, no una columna.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN DEL RASTRO
-- ───────────────────────────────────────────────────────────────────────
-- Tiene que salir el disparador. Si no está, el panel seguirá enseñando
-- los trámites sin autor y nadie sabrá por qué.
select tgname as disparador, tgrelid::regclass as tabla
from   pg_trigger
where  not tgisinternal and tgrelid = 'public.tipos_tramite'::regclass;

-- ====================================================================
--  12 / 105   supabase-bitacora.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA BITÁCORA
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: después de supabase-tramites.sql, supabase-admin.sql y
--  supabase-catalogos.sql. Necesita public.es_gestor() y public.es_admin().
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ARREGLA
--  ─────────────────────────────────────────────────────────────────────
--  El Rastro se componía rebuscando en tres sitios que no se hicieron
--  para llevar un registro:
--
--    tramite_eventos            sí es un historial, pero solo de trámites.
--    perfiles.rol_cambiado_*    una columna en la ficha de la persona.
--    tipos_tramite.activo_*     una columna en la ficha del trámite.
--
--  Las dos columnas guardan el ÚLTIMO movimiento y pisan el anterior.
--  Apagar un trámite y volver a encenderlo dejaba UN apunte, no dos: el
--  segundo borraba al primero, y el registro decía que nunca se apagó.
--
--  Un registro que se sobrescribe no es un registro. Esto es una tabla
--  donde cada movimiento es UNA FILA NUEVA, y nada pisa a nada.
--
--  Y de paso entran los dos que no dejaban rastro de ninguna manera: los
--  papeles de las bóvedas y las citas.
--
--  POR QUÉ 'sobre' ES TEXTO Y NO UNA REFERENCIA
--  ─────────────────────────────────────────────────────────────────────
--  Se guarda el NOMBRE de la cosa tal como era en ese momento, no un
--  puntero a ella. Si mañana se renombra el trámite, o se borra el papel,
--  la bitácora tiene que seguir contando lo que pasó con las palabras de
--  entonces. Un registro que cambia cuando cambia el presente no sirve
--  para saber qué pasó en el pasado, que es su único trabajo.
--
--  NADIE PUEDE ESCRIBIR AQUÍ
--  ─────────────────────────────────────────────────────────────────────
--  No hay política de INSERT. Ninguna. Las filas las ponen los
--  disparadores, que corren como dueños de la tabla y se saltan RLS.
--
--  Eso quiere decir que desde el navegador —con sesión de admin, de
--  gestor o de quien sea— NO se puede añadir un apunte, ni cambiarlo, ni
--  borrarlo. Un registro que quien actúa puede editar no prueba nada.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'es_gestor'
  ) then
    raise exception 'Falta public.es_gestor(). Pasa antes supabase-gestor.sql.';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA TABLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.bitacora (
  id       bigint generated always as identity primary key,
  cuando   timestamptz not null default now(),
  -- Quién lo hizo. Null cuando no lo hizo nadie desde el panel: un update
  -- escrito aquí, en el editor, no tiene auth.uid(). La pantalla lo dice
  -- como "Desde la base" y no como "Alguien", que son cosas distintas.
  quien    uuid references auth.users(id) on delete set null,
  fuente   text not null,
  accion   text not null,
  -- El nombre de la cosa, congelado. Ver la cabecera.
  sobre    text not null default '',
  detalle  text not null default '',

  constraint bitacora_fuente_valida
    check (fuente in ('catalogo','roles','papeles','citas'))
);

comment on table  public.bitacora        is 'Quién hizo qué y cuándo. Una fila por movimiento; nada se sobrescribe';
comment on column public.bitacora.quien  is 'Null = no se hizo desde el panel (sin sesión)';
comment on column public.bitacora.sobre  is 'El nombre de la cosa EN ESE MOMENTO, no una referencia viva';

-- Se lee siempre de lo más nuevo a lo más viejo y con tope. El índice va
-- por 'cuando' descendente porque esa es la única consulta que existe.
create index if not exists bitacora_reciente on public.bitacora (cuando desc);

alter table public.bitacora enable row level security;

-- Leer: el equipo. Un inversionista no tiene por qué ver quién movió los
-- roles ni qué papeles subieron los demás.
drop policy if exists "bitacora: la lee el equipo" on public.bitacora;
create policy "bitacora: la lee el equipo" on public.bitacora
  for select to authenticated using (public.es_gestor());

-- Y NO hay política de insert, update ni delete. A propósito. Ver la
-- cabecera: si quien actúa pudiera escribir aquí, esto no probaría nada.


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIEN APUNTA
-- ───────────────────────────────────────────────────────────────────────
-- Una sola función para las cuatro tablas. security definer para que
-- pueda escribir donde nadie más puede.
create or replace function public.apunta(
  p_fuente text, p_accion text, p_sobre text, p_detalle text default ''
) returns void
language sql
security definer
set search_path = public
as $$
  insert into public.bitacora (quien, fuente, accion, sobre, detalle)
  values (auth.uid(), p_fuente, p_accion, coalesce(p_sobre, ''), coalesce(p_detalle, ''));
$$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. EL CATÁLOGO
-- ───────────────────────────────────────────────────────────────────────
-- Solo cuando CAMBIA 'activo': renombrar un trámite no es encenderlo.
create or replace function public.bit_catalogo()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.activo is distinct from old.activo then
    perform public.apunta('catalogo',
      case when new.activo then 'encendio' else 'apago' end,
      new.nombre);
  end if;
  return null;
end $$;

drop trigger if exists bitacora_catalogo on public.tipos_tramite;
create trigger bitacora_catalogo
  after update on public.tipos_tramite
  for each row execute function public.bit_catalogo();


-- ───────────────────────────────────────────────────────────────────────
-- 4. LOS ROLES
-- ───────────────────────────────────────────────────────────────────────
create or replace function public.bit_roles()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.rol is distinct from old.rol then
    -- El nombre puede venir vacío; la pantalla lo dice como "Sin nombre".
    perform public.apunta('roles', 'rol', new.nombre_completo, new.rol);
  end if;
  return null;
end $$;

drop trigger if exists bitacora_roles on public.perfiles;
create trigger bitacora_roles
  after update on public.perfiles
  for each row execute function public.bit_roles();


-- ───────────────────────────────────────────────────────────────────────
-- 5. LOS PAPELES
-- ───────────────────────────────────────────────────────────────────────
-- Al borrar se apunta con OLD, que es lo último que se supo del papel. Es
-- el caso que más falta hace: de un papel que ya no está, la bitácora es
-- lo único que queda.
create or replace function public.bit_papeles()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.apunta('papeles', 'subio', new.nombre_original, new.tipo);
    return null;
  end if;
  perform public.apunta('papeles', 'borro', old.nombre_original, old.tipo);
  return null;
end $$;

drop trigger if exists bitacora_papeles_alta on public.documentos;
create trigger bitacora_papeles_alta
  after insert on public.documentos
  for each row execute function public.bit_papeles();

drop trigger if exists bitacora_papeles_baja on public.documentos;
create trigger bitacora_papeles_baja
  after delete on public.documentos
  for each row execute function public.bit_papeles();


-- ───────────────────────────────────────────────────────────────────────
-- 6. LAS CITAS
-- ───────────────────────────────────────────────────────────────────────
-- Se apunta el alta y cada cambio de estado. El estado va en 'detalle'
-- porque la pantalla lo traduce: guardar aquí "Confirmada" en castellano
-- dejaría la bitácora en un idioma para siempre.
create or replace function public.bit_citas()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.apunta('citas', 'pidio', coalesce(new.tipo_tramite, ''), new.estado);
    return null;
  end if;
  if new.estado is distinct from old.estado then
    perform public.apunta('citas', 'movio', coalesce(new.tipo_tramite, ''), new.estado);
  end if;
  return null;
end $$;

drop trigger if exists bitacora_citas_alta on public.citas;
create trigger bitacora_citas_alta
  after insert on public.citas
  for each row execute function public.bit_citas();

drop trigger if exists bitacora_citas_cambio on public.citas;
create trigger bitacora_citas_cambio
  after update on public.citas
  for each row execute function public.bit_citas();


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE, DICHO PARA QUE NO SE DÉ POR HECHO
-- ───────────────────────────────────────────────────────────────────────
-- · La bitácora empieza HOY. Lo que pasó antes de correr esto no está, y
--   no se puede reconstruir. Las dos columnas viejas —rol_cambiado_* y
--   activo_*— se quedan donde están: son lo único que queda de antes.
-- · Los cambios de estado de un trámite siguen en tramite_eventos, que ya
--   era un historial de verdad y no hacía falta duplicar. La pantalla lee
--   de los dos sitios.
-- · Nadie limpia esto. Con el tiempo crece; el día que estorbe, se borra
--   por fecha, y eso es una decisión que se toma entonces y no ahora.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. Los cinco disparadores.
select tgrelid::regclass as tabla, tgname as disparador
from   pg_trigger
where  not tgisinternal
  and  tgname like 'bitacora_%'
order  by tabla, disparador;

-- 2. Que solo se pueda LEER. Tiene que salir una fila, y con cmd SELECT.
--    Si aparece un INSERT, alguien podría inventarse apuntes.
select policyname, cmd from pg_policies
where  schemaname = 'public' and tablename = 'bitacora';

-- 3. Y la prueba de verdad: enciende y apaga un trámite desde el panel, y
--    mira que salgan DOS filas y no una.
select cuando, fuente, accion, sobre, detalle
from   public.bitacora
order  by cuando desc
limit  20;

-- ====================================================================
--  13 / 105   supabase-bloqueo.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — BLOQUEAR UNA CUENTA
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: después de supabase-admin.sql. Necesita public.es_admin().
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ES Y QUÉ NO ES
--  ─────────────────────────────────────────────────────────────────────
--  Bloquear NO borra. Los trámites de esa persona, sus papeles y su
--  historial siguen donde estaban: el CIIP recibió esas solicitudes y
--  borrarlas sería reescribir lo que pasó. Lo que se cierra es la puerta.
--
--  Es lo que hace falta el día que alguien se va de la oficina, o cuando
--  hay que parar una cuenta mientras se aclara algo.
--
--  UN BLOQUEO QUE SOLO ESCONDE BOTONES NO ES UN BLOQUEO
--  ─────────────────────────────────────────────────────────────────────
--  Se podría haber hecho solo en la pantalla: que el panel eche a quien
--  esté bloqueado. Eso para a quien entra por la puerta, y a nadie más:
--  la clave anónima está en el código de la página, a la vista de
--  cualquiera, y con ella se puede hablar con la base sin pasar por el
--  panel.
--
--  Así que el bloqueo vive AQUÍ, en tres disparadores que rechazan
--  cualquier escritura de una cuenta bloqueada sobre lo suyo: trámites,
--  papeles y citas. El panel además le cierra la puerta, pero eso es
--  cortesía —para que vea un mensaje en vez de errores—, no la cerradura.
--
--  LO QUE SIGUE PUDIENDO HACER
--  ─────────────────────────────────────────────────────────────────────
--  Leer lo suyo. No se le quita el acceso a su propio expediente, porque
--  bloquear no es castigar: es impedir que siga metiendo cosas. Si algún
--  día hace falta que tampoco lea, eso se hace en las políticas de
--  lectura y es otra decisión.
--
--  NADIE SE BLOQUEA A SÍ MISMO
--  ─────────────────────────────────────────────────────────────────────
--  Igual que con los roles. Un admin que se bloquea deja al CIIP sin
--  quien desbloquee, y eso solo se arregla volviendo aquí.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'es_admin'
  ) then
    raise exception 'Falta public.es_admin(). Pasa antes supabase-admin.sql.';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA COLUMNA
-- ───────────────────────────────────────────────────────────────────────
alter table public.perfiles
  add column if not exists bloqueado      boolean not null default false,
  add column if not exists bloqueado_por  uuid references auth.users(id) on delete set null,
  add column if not exists bloqueado_en   timestamptz;

comment on column public.perfiles.bloqueado is
  'true = no puede escribir nada. Sigue pudiendo leer lo suyo';
comment on column public.perfiles.bloqueado_por is
  'Quién lo bloqueó. Lo pone el disparador, no el cliente';


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN PUEDE BLOQUEAR
-- ───────────────────────────────────────────────────────────────────────
-- Copiado del disparador de los roles: la comprobación vive en la BASE.
-- Esconder el interruptor nunca fue la cerradura.
create or replace function public.guarda_el_bloqueo()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.bloqueado is distinct from old.bloqueado then
    if not public.es_admin() then
      raise exception 'Solo un administrador puede bloquear cuentas';
    end if;
    if new.id = auth.uid() then
      raise exception 'Nadie se bloquea a sí mismo';
    end if;
    new.bloqueado_por := auth.uid();
    new.bloqueado_en  := now();
  end if;
  return new;
end $$;

drop trigger if exists perfiles_bloqueo on public.perfiles;
create trigger perfiles_bloqueo
  before update on public.perfiles
  for each row execute function public.guarda_el_bloqueo();


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA CERRADURA DE VERDAD
-- ───────────────────────────────────────────────────────────────────────
-- stable y no volatile: dentro de una misma sentencia se pregunta una vez
-- y se reusa, en vez de una consulta por fila.
create or replace function public.esta_bloqueado()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.bloqueado from public.perfiles p where p.id = auth.uid()),
    false);
$$;

-- Un disparador por tabla, y el mismo para las tres. Va en BEFORE: si
-- fuera AFTER, la fila ya estaría escrita cuando salta el error y habría
-- que confiar en que la transacción se deshaga.
create or replace function public.corta_si_bloqueado()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if public.esta_bloqueado() then
    raise exception 'Esta cuenta está bloqueada';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;

drop trigger if exists tramites_bloqueo   on public.tramites;
create trigger tramites_bloqueo
  before insert or update or delete on public.tramites
  for each row execute function public.corta_si_bloqueado();

drop trigger if exists documentos_bloqueo on public.documentos;
create trigger documentos_bloqueo
  before insert or update or delete on public.documentos
  for each row execute function public.corta_si_bloqueado();

drop trigger if exists citas_bloqueo      on public.citas;
create trigger citas_bloqueo
  before insert or update or delete on public.citas
  for each row execute function public.corta_si_bloqueado();


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE
-- ───────────────────────────────────────────────────────────────────────
-- · No cierra la sesión que ya esté abierta en ese momento. La próxima
--   escritura le fallará y el panel le echará al recargar, pero mientras
--   tanto sigue viendo lo que tenía en pantalla.
-- · No le impide LEER lo suyo. Ver la cabecera.
-- · No toca auth.users. Bloquear ahí -banned_until- solo se puede con la
--   clave de servicio, que no puede vivir en una página web.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. Los cuatro disparadores.
select tgrelid::regclass as tabla, tgname as disparador
from   pg_trigger
where  not tgisinternal and tgname like '%bloqueo%'
order  by tabla;

-- 2. Quién está bloqueado ahora mismo. Recién puesto esto, ninguno.
select p.nombre_completo, u.email, p.bloqueado, p.bloqueado_en
from   public.perfiles p join auth.users u on u.id = p.id
where  p.bloqueado
order  by p.bloqueado_en desc;

-- ====================================================================
--  14 / 105   supabase-acompanamiento.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL ACOMPAÑAMIENTO, GOBERNADO DESDE EL PANEL
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: después de supabase-admin.sql. Necesita public.es_admin().
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ARREGLA
--  ─────────────────────────────────────────────────────────────────────
--  La burbuja de acompañamiento, su nube y los tres botones del panel
--  vivían enteros en el código: el marcado fijo, los tiempos en tres
--  constantes y las frases en el diccionario. Cambiar cualquiera de esas
--  cosas era editar el archivo y volver a publicarlo.
--
--  Ahora se gobiernan desde Administración.
--
--  UNA SOLA FILA, Y LA BASE LO GARANTIZA
--  ─────────────────────────────────────────────────────────────────────
--  Esto no es una lista: es LA configuración. Con una tabla normal, el
--  día que dos pestañas guarden a la vez habría dos filas y el panel
--  leería una de las dos según le diera.
--
--  El truco es la clave primaria: una columna booleana que solo admite
--  'true'. Una segunda fila chocaría con la clave primaria y Postgres la
--  rechaza. No hay que acordarse de nada al escribir.
--
--  LOS TEXTOS SON RETOQUES, NO SUSTITUTOS
--  ─────────────────────────────────────────────────────────────────────
--  Las frases siguen viviendo en el diccionario, en los seis idiomas, con
--  su vigilante comprobando que ninguna se quede coja. Lo que se guarda
--  aquí son RETOQUES: si hay uno para tu idioma, manda; si no, se usa el
--  del diccionario.
--
--  Eso contesta la pregunta incómoda —«¿y si alguien escribe la española
--  y deja las otras cinco?»—: las otras cinco siguen diciendo lo que
--  decían. Nunca puede quedar un rótulo en blanco, que es lo que pasaría
--  si esto sustituyera al diccionario en vez de retocarlo.
--
--  LOS TIEMPOS VAN EN MILISEGUNDOS
--  ─────────────────────────────────────────────────────────────────────
--  Como en el código, que es quien los usa. La pantalla los enseña en
--  segundos porque nadie piensa en milisegundos, y hace la cuenta al
--  guardar. Guardar segundos obligaría a multiplicar en cada lectura y
--  el primer olvido daría una nube que sale a los tres milisegundos.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'es_admin'
  ) then
    raise exception 'Falta public.es_admin(). Pasa antes supabase-admin.sql.';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA TABLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.acompanamiento (
  -- Ver la cabecera: esto garantiza que solo haya una fila.
  id            boolean primary key default true,

  -- Qué se enseña.
  burbuja       boolean not null default true,
  nube          boolean not null default true,
  b_ciip        boolean not null default true,
  b_invertir    boolean not null default true,
  b_cita        boolean not null default true,

  -- Los tiempos de la nube, en milisegundos.
  nube_espera   integer not null default 3200,
  nube_dura     integer not null default 8400,
  nube_vuelve   integer not null default 180000,

  -- Retoques de texto por idioma. {"es": {"nube": "...", "titulo": "..."}}
  -- Lo que no esté aquí lo pone el diccionario.
  textos        jsonb   not null default '{}'::jsonb,

  actualizado_en  timestamptz not null default now(),
  actualizado_por uuid references auth.users(id) on delete set null,

  constraint acompanamiento_una_fila check (id),
  -- Topes con sentido, no arbitrarios: una nube que asoma antes de medio
  -- segundo aparece encima de una pantalla que todavía se está pintando, y
  -- una que dura menos de dos segundos no da tiempo a leerla. El máximo de
  -- 'vuelve' es una hora: más que eso es no volver.
  constraint acompanamiento_espera_sensata check (nube_espera between 500 and 60000),
  constraint acompanamiento_dura_sensata   check (nube_dura   between 2000 and 60000),
  constraint acompanamiento_vuelve_sensata check (nube_vuelve between 30000 and 3600000),
  constraint acompanamiento_textos_objeto  check (jsonb_typeof(textos) = 'object')
);

comment on table  public.acompanamiento is 'LA configuración del acompañamiento. Una sola fila, garantizada por la clave primaria';
comment on column public.acompanamiento.textos is 'Retoques por idioma. Lo que falte lo pone el diccionario del panel';

-- La fila, si no está. Sin ella el panel no tiene qué leer y se queda con
-- sus valores de siempre, que es correcto pero deja la pantalla de
-- Administración sin nada que enseñar.
insert into public.acompanamiento (id) values (true)
on conflict (id) do nothing;

alter table public.acompanamiento enable row level security;

-- Leer: cualquiera con sesión. La burbuja la ve todo el mundo, así que
-- todo el mundo necesita saber si está encendida.
drop policy if exists "acompanamiento: lo lee cualquiera" on public.acompanamiento;
create policy "acompanamiento: lo lee cualquiera" on public.acompanamiento
  for select to authenticated using (true);

-- Escribir: solo admin, y solo UPDATE. No hay insert ni delete: la fila
-- ya existe y no debe haber otra ni ninguna.
drop policy if exists "acompanamiento: solo el admin lo cambia" on public.acompanamiento;
create policy "acompanamiento: solo el admin lo cambia" on public.acompanamiento
  for update to authenticated
  using      (public.es_admin())
  with check (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN LO TOCÓ
-- ───────────────────────────────────────────────────────────────────────
-- Lo escribe un disparador, como en los roles y en el catálogo: un campo
-- que rellena quien escribe es un campo que quien escribe puede mentir.
create or replace function public.marca_acompanamiento()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.actualizado_por := auth.uid();
  new.actualizado_en  := now();
  return new;
end $$;

drop trigger if exists acompanamiento_quien on public.acompanamiento;
create trigger acompanamiento_quien
  before update on public.acompanamiento
  for each row execute function public.marca_acompanamiento();


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE
-- ───────────────────────────────────────────────────────────────────────
-- · No entra en la bitácora. Cambiar un tiempo de la nube no es un acto
--   que haya que auditar, y llenaría el Rastro de ruido. Quién lo tocó
--   por última vez queda en la propia fila, que para esto basta.
-- · No valida los textos. Si alguien escribe una frase de trescientas
--   letras, la nube se hará grande. La base comprueba tipos y rangos, no
--   buen gusto.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. La fila, con sus valores de fábrica.
select burbuja, nube, b_ciip, b_invertir, b_cita,
       nube_espera, nube_dura, nube_vuelve, textos
from   public.acompanamiento;

-- 2. Las dos políticas: una de leer y una de cambiar. Si falta la de
--    cambiar, la pantalla guardará sin guardar y no dirá nada.
select policyname, cmd from pg_policies
where  schemaname = 'public' and tablename = 'acompanamiento';

-- 3. Y que de verdad no quepa una segunda fila. Esto TIENE que fallar:
--    si te deja insertarla, la garantía de una sola fila no está puesta.
--    Descomenta para probarlo.
-- insert into public.acompanamiento (id) values (true);

-- ====================================================================
--  15 / 105   supabase-gestor.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL EQUIPO DEL CIIP
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va DESPUÉS de supabase-setup.sql, supabase-tramites.sql y
--  supabase-citas.sql.
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ARREGLA
--  ─────────────────────────────────────────────────────────────────────
--  La cola de citas del panel enseña QUIÉN pidió cada una. Hasta ahora no
--  podía: la única política de lectura sobre public.perfiles es "cada quien
--  lee únicamente su propio perfil", sin excepción para el equipo. Un
--  gestor veía la cita pero no el nombre de quien la pidió, así que la cola
--  habría sido una lista de peticiones anónimas.
-- ═══════════════════════════════════════════════════════════════════════

-- El equipo del CIIP lee los perfiles de todos. No los EDITA: la política
-- de actualización sigue siendo solo la propia, y el trigger proteger_rol
-- impide que nadie se ascienda desde el navegador.
--
-- es_gestor() es security definer y se salta RLS, así que no hay recursión
-- al consultar perfiles desde una política de perfiles.
drop policy if exists "perfiles: el equipo los lee todos" on public.perfiles;
create policy "perfiles: el equipo los lee todos"
  on public.perfiles for select
  using (public.es_gestor());


-- ───────────────────────────────────────────────────────────────────────
--  CÓMO SE NOMBRA UN GESTOR
-- ───────────────────────────────────────────────────────────────────────
-- Desde aquí y solo desde aquí. El trigger proteger_rol deja pasar el
-- cambio porque auth.uid() es null en el SQL Editor; desde el navegador,
-- con sesión, lo rechaza. Es lo que impide que alguien se ascienda solo.
--
-- Quita el comentario, pon el correo y ejecútalo:

-- update public.perfiles
--    set rol = 'gestor'
--  where id = (select id from auth.users where email = 'TU-CORREO');

-- Para volver atrás:

-- update public.perfiles
--    set rol = 'inversionista'
--  where id = (select id from auth.users where email = 'TU-CORREO');


-- ───────────────────────────────────────────────────────────────────────
--  COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
-- Quién es del equipo ahora mismo:

--   select u.email, p.nombre_completo, p.rol
--     from public.perfiles p
--     join auth.users u on u.id = p.id
--    where p.rol in ('gestor','admin');


-- ───────────────────────────────────────────────────────────────────────
--  LA NOTA DE UNA DEVOLUCIÓN
-- ───────────────────────────────────────────────────────────────────────
-- Cuando un gestor devuelve un trámite, el trigger de supabase-tramites.sql
-- escribe el evento solo, pero con la nota VACÍA. La nota es justo lo que
-- el inversionista necesita leer para corregir, y sin esta política no hay
-- forma de ponerla desde el panel: sobre tramite_eventos solo existe la de
-- lectura, así que un UPDATE desde el navegador no afecta a ninguna fila.
--
-- Solo el equipo, y solo la nota: lo segundo no lo puede decir una política
-- —RLS trabaja por filas, no por columnas— así que lo corta un trigger.
drop policy if exists "eventos: el equipo anota" on public.tramite_eventos;
create policy "eventos: el equipo anota" on public.tramite_eventos
  for update
  using      (public.es_gestor())
  with check (public.es_gestor());

create or replace function public.eventos_solo_la_nota()
returns trigger
language plpgsql
as $$
begin
  -- Desde el SQL Editor auth.uid() es null y se deja pasar todo: es la
  -- puerta de servicio del equipo, igual que en las demás tablas.
  if auth.uid() is null then
    return new;
  end if;

  if new.tramite   is distinct from old.tramite
  or new.de_estado is distinct from old.de_estado
  or new.a_estado  is distinct from old.a_estado
  or new.autor     is distinct from old.autor
  or new.creado_en is distinct from old.creado_en then
    raise exception 'De un evento solo se puede cambiar la nota';
  end if;

  return new;
end;
$$;

drop trigger if exists eventos_proteger on public.tramite_eventos;
create trigger eventos_proteger
  before update on public.tramite_eventos
  for each row execute function public.eventos_solo_la_nota();

-- ====================================================================
--  16 / 105   supabase-cola.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  LA COLA DE ENVÍOS
--  Va DESPUÉS de supabase-tramites.sql y de supabase-gestor.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  Hasta aquí el panel entero ocurre en el navegador del inversionista.
--  Cuando cierra la pestaña, el sistema se para. Y una ventanilla única
--  es sobre todo trabajo que sucede MIENTRAS TANTO: presentar un
--  expediente, volver a preguntar por él, reintentar cuando el ente no
--  contesta. Eso lo hacía una persona del CIIP a mano, moviendo estados
--  desde la cola del gestor.
--
--  Esta tabla es la lista de lo que hay que hacer cuando nadie mira. No
--  la escribe nadie a mano: la llena un trigger cuando un trámite llega
--  al estado que toca, y la vacía el trabajador
--  (interoperabilidad/trabajador.js).
--
--  DÓNDE ENTRA LA MÁQUINA, Y POR QUÉ AHÍ
--  ─────────────────────────────────────────────────────────────────────
--  En 'en_revision', no en 'enviado'. Lo manda la escalera de estados de
--  supabase-tramites.sql, que sólo deja pasar a 'ante_el_ente' desde
--  'en_revision'. O sea: una persona mira el expediente y lo da por
--  bueno, y ENTONCES la máquina lo presenta. No es una limitación que
--  haya que rodear, es la política correcta escrita en un sitio: lo que
--  se manda a un organismo lo ha visto alguien antes.
--
--  QUÉ NO HACE
--  ─────────────────────────────────────────────────────────────────────
--  No decide nada. Guarda qué hay que hacer, cuándo se puede volver a
--  intentar y cuántas veces se ha intentado ya. Qué significa cada
--  respuesta del organismo lo decide el conector, que se prueba sin base
--  de datos; y qué hacer con esa decisión, el trabajador. Tres piezas y
--  cada una se prueba sola.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. QUÉ TRÁMITES SABE PRESENTAR LA MÁQUINA
-- ───────────────────────────────────────────────────────────────────────
-- Una columna en el catálogo y no una lista en el código: así añadir un
-- conector nuevo es un UPDATE, y un trámite sin conector sigue yendo a
-- mano sin que nada se rompa ni haya que acordarse de excluirlo.
--
-- null = no hay conector todavía. Son 29 de 31 hoy, y está bien que lo
-- sean: escribir el conector de un ente es lo caro, y hasta que exista
-- el trámite se atiende como se ha atendido siempre.

alter table public.tipos_tramite
  add column if not exists conector text;

comment on column public.tipos_tramite.conector is
  'Qué conector lo presenta. null = a mano, como hasta ahora';

-- Los escritos hasta ahora. Se activan con UPDATE y no en el INSERT del
-- catálogo, que lleva ON CONFLICT DO NOTHING y en una base que ya existe
-- no tocaría nada.
--
-- El de constitución va con el del RIF y no después: es el trámite del
-- que cuelgan casi todos los demás —sin acta registrada no hay compañía,
-- sin compañía no hay RIF de empresa, sin RIF no hay cuenta bancaria—,
-- así que automatizar el RIF y dejar la constitución a mano sería poner
-- el motor detrás del atasco.
update public.tipos_tramite set conector = 'rif_empresa'
 where codigo = 'rif_empresa';
update public.tipos_tramite set conector = 'constitucion'
 where codigo = 'constitucion';


-- ───────────────────────────────────────────────────────────────────────
-- 2. EL NÚMERO QUE DA EL ORGANISMO
-- ───────────────────────────────────────────────────────────────────────
-- Sin esto no hay forma de volver a preguntar por un expediente: el ente
-- responde por SU número, no por el nuestro. Se guarda en el trámite y no
-- en la cola porque sobrevive a la cola: el trabajo se cierra y el número
-- sigue siendo la referencia del expediente para siempre.

alter table public.tramites
  add column if not exists expediente_ente text;

comment on column public.tramites.expediente_ente is
  'El número que dio el organismo al recibirlo. Es por el que se le pregunta después';


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA COLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.trabajos (
  id        uuid primary key default gen_random_uuid(),
  tramite   uuid not null references public.tramites(id) on delete cascade,

  tarea     text not null,
  estado    text not null default 'pendiente',

  -- No antes de esta hora. Es lo que convierte "reintentar dentro de un
  -- rato" en un dato en vez de en una espera dentro del trabajador: si el
  -- proceso se cae, la espera sigue escrita y la retoma el siguiente.
  cuando    timestamptz not null default now(),
  intentos  smallint not null default 0,

  -- La misma con la que se presentó. Reintentar con ella no abre un
  -- expediente nuevo: el ente devuelve el que ya tenía. Es el id del
  -- trámite, y se copia aquí para que el trabajador no tenga que
  -- deducirla y para que quede escrito con qué llave se mandó.
  llave     text not null,

  ultimo_error   text,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),

  constraint trabajos_tarea_valida
    check (tarea in ('presentar', 'consultar')),

  -- 'alertado' es distinto de 'fallido' a propósito: quiere decir que el
  -- problema es NUESTRO -credenciales, contrato incumplido- y que no lo
  -- arregla reintentar. Un trabajo alertado espera a una persona.
  constraint trabajos_estado_valido
    check (estado in ('pendiente', 'haciendose', 'hecho', 'alertado'))
);

comment on table  public.trabajos       is 'Lo que hay que hacer con los organismos cuando nadie mira';
comment on column public.trabajos.tarea is 'presentar = mandarlo; consultar = preguntar en qué quedó';

-- Sin esto, dos triggers seguidos -o dos trabajadores a la vez- dejaban
-- el mismo trámite dos veces en la cola y se presentaba dos veces. La
-- llave de idempotencia lo salvaría en el ente, pero no hay por qué
-- llegar hasta ahí: se impide aquí.
create unique index if not exists trabajos_sin_repetir
  on public.trabajos (tramite, tarea)
  where estado in ('pendiente', 'haciendose');

-- Por donde lee el trabajador: lo pendiente cuya hora ya pasó, lo más
-- viejo primero.
create index if not exists trabajos_por_hacer
  on public.trabajos (cuando)
  where estado = 'pendiente';

drop trigger if exists trabajos_marca_tiempo on public.trabajos;
create trigger trabajos_marca_tiempo
  before update on public.trabajos
  for each row execute function public.tocar_actualizado_en();


-- ───────────────────────────────────────────────────────────────────────
-- 4. LA COLA SE LLENA SOLA
-- ───────────────────────────────────────────────────────────────────────
-- Igual que el historial, y por la misma razón: si dependiera de que la
-- aplicación se acuerde de encolar, algún día se olvidaría y un trámite
-- se quedaría parado sin que nadie supiera por qué. Lo hace la base, en
-- el mismo sitio donde el estado cambia.

create or replace function public.encolar_trabajo()
returns trigger
language plpgsql
security definer
set search_path = public
as $cola$
declare
  quien text;
  cual  text;
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;

  select conector into quien from public.tipos_tramite where codigo = new.tipo;
  if quien is null then
    return new;   -- se atiende a mano, como siempre
  end if;

  if    new.estado = 'en_revision'  then cual := 'presentar';
  elsif new.estado = 'ante_el_ente' then cual := 'consultar';
  else  return new;
  end if;

  -- ON CONFLICT y no una comprobación previa: entre el select y el
  -- insert cabe otro trigger, y el índice de arriba es quien de verdad
  -- lo impide. Comprobar antes sería creerlo resuelto sin estarlo.
  insert into public.trabajos (tramite, tarea, llave)
  values (new.id, cual, new.id::text)
  on conflict do nothing;

  return new;
end
$cola$;

drop trigger if exists tramites_encolar on public.tramites;
create trigger tramites_encolar
  after update on public.tramites
  for each row execute function public.encolar_trabajo();


-- ───────────────────────────────────────────────────────────────────────
-- 5. QUIÉN LA VE
-- ───────────────────────────────────────────────────────────────────────
-- El trabajador entra con la clave de servidor, que se salta el RLS: no
-- necesita política ninguna. Estas son para las personas.
--
-- El inversionista NO la ve, y es a propósito. No le dice nada que no le
-- diga ya el historial de su trámite -y ese sí está en su idioma-, y en
-- cambio le enseñaría los reintentos y los errores de un organismo, que
-- es ruido nuestro y parece un problema suyo.

alter table public.trabajos enable row level security;

drop policy if exists "trabajos: el equipo los ve" on public.trabajos;
create policy "trabajos: el equipo los ve" on public.trabajos
  for select using (public.es_gestor());

-- Y nadie los escribe a mano, ni el equipo. Los pone el trigger -que es
-- security definer y se salta el RLS- y los mueve el trabajador con la
-- clave de servidor. Un trabajo escrito a mano es un expediente
-- presentado dos veces, o uno que nunca se presenta.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) El trámite con conector, y ningún otro:
--
--   select codigo, conector from public.tipos_tramite where conector is not null;
--
-- 2) La cola, con lo que espera y desde cuándo:
--
--   select tarea, estado, intentos, cuando, ultimo_error
--   from public.trabajos order by cuando;
--
-- 3) Que se llena sola: mueve un rif_empresa a 'en_revision' desde el
--    panel y mira que aparezca su 'presentar'. Si no aparece, el trámite
--    no tenía conector o el trigger no está.

-- ====================================================================
--  17 / 105   supabase-avisos.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  LOS AVISOS
--  Va DESPUÉS de supabase-tramites.sql y de supabase-gestor.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  Hoy no sale ni un aviso del sistema. Ninguno. Un trámite devuelto se
--  queda esperando a que el inversionista, por su cuenta, decida entrar a
--  mirar; y un documento que vence no avisa hasta que un organismo lo
--  rechaza. El buzón del panel existe, pero hay que abrir el panel para
--  verlo, y eso es exactamente lo que no se puede dar por hecho.
--
--  UN BUZÓN DE SALIDA, NO UN ENVÍO
--  ─────────────────────────────────────────────────────────────────────
--  Aquí no se manda nada: se APUNTA lo que hay que mandar. Mandarlo es
--  cosa de avisos/mensajero.js, que corre fuera.
--
--  La diferencia importa. Si el envío se hiciera dentro de la
--  transacción que cambia el estado, un SMTP lento o caído dejaría al
--  gestor esperando —o, peor, haría fallar la devolución del trámite por
--  no haber podido avisar de ella—. Escribiendo la fila y saliendo, el
--  cambio de estado no depende nunca de que el correo salga.
--
--  Y al revés: como la fila se escribe en la MISMA transacción que el
--  evento, no hay forma de que un trámite se devuelva y el aviso se
--  pierda. O pasan las dos cosas o no pasa ninguna.
--
--  QUÉ SE AVISA Y QUÉ NO
--  ─────────────────────────────────────────────────────────────────────
--  Sólo tres estados, y los tres son noticias para el inversionista:
--
--    devuelto      te toca a ti, y esto es lo único urgente de la lista
--    resuelto      ya está, y el papel está en tu bóveda
--    ante_el_ente  se presentó, ya no depende del CIIP
--
--  'enviado' no se avisa: lo acaba de hacer él y avisarle de su propio
--  clic es la forma más rápida de que mande el remitente a la basura.
--  'en_revision' tampoco: es trabajo interno nuestro, y contarlo sólo
--  añade un correo entre la solicitud y la respuesta de verdad.
--
--  Un buzón que avisa de todo se ignora entero, y entonces el aviso de
--  'devuelto' —el único que pide una acción— se pierde con los demás.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL BUZÓN
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.avisos (
  id       uuid primary key default gen_random_uuid(),
  tramite  uuid references public.tramites(id) on delete cascade,

  -- A quién, y en qué idioma. Se copian AQUÍ, en el momento de escribir
  -- el aviso, y no se leen después de perfiles: si la persona cambia de
  -- correo mañana, el aviso de hoy tiene que salir al de hoy. Un buzón de
  -- salida guarda a dónde iba la carta, no a dónde iría ahora.
  destinatario text not null,
  pais         text not null default '',

  motivo   text not null,
  a_estado text,
  nota     text not null default '',
  dato     text not null default '',

  estado   text not null default 'pendiente',
  intentos smallint not null default 0,
  cuando   timestamptz not null default now(),
  ultimo_error text,

  creado_en  timestamptz not null default now(),
  enviado_en timestamptz,

  constraint avisos_motivo_valido
    check (motivo in ('cambio_estado', 'documento_vence')),
  constraint avisos_estado_valido
    check (estado in ('pendiente', 'enviado', 'fallido'))
);

comment on table  public.avisos              is 'Lo que hay que decirle a alguien. Se apunta aquí y lo manda el mensajero';
comment on column public.avisos.destinatario is 'El correo AL QUE IBA, congelado. No se relee del perfil';
comment on column public.avisos.pais         is 'Para saber en qué idioma escribirle. Mismo criterio que usa el panel';
comment on column public.avisos.dato         is 'Lo que hace falta además del estado: el nombre del documento que vence, por ejemplo';

create index if not exists avisos_por_mandar
  on public.avisos (cuando)
  where estado = 'pendiente';


-- ───────────────────────────────────────────────────────────────────────
-- 2. EL AVISO SE ESCRIBE SOLO
-- ───────────────────────────────────────────────────────────────────────
-- Cuelga de tramite_eventos y no de tramites, y no es un detalle: el
-- historial ya se escribe solo desde un trigger, y es la única fila que
-- existe siempre que ha pasado algo digno de contarse. Colgar de ahí
-- significa que no hay ningún cambio de estado que pueda escaparse.
--
-- security definer para poder leer auth.users, que es de otro esquema y
-- nadie tiene permiso para mirar.

create or replace function public.avisar_del_cambio()
returns trigger
language plpgsql
security definer
set search_path = public
as $avisos$
declare
  duenio  uuid;
  correo  text;
  suPais  text;
begin
  if new.a_estado not in ('devuelto', 'resuelto', 'ante_el_ente') then
    return new;
  end if;

  select t.inversionista into duenio
    from public.tramites t where t.id = new.tramite;
  if duenio is null then
    return new;
  end if;

  select u.email into correo from auth.users u where u.id = duenio;
  select p.pais  into suPais from public.perfiles p where p.id = duenio;

  -- Sin correo no hay aviso, y tampoco hay error: una cuenta puede estar
  -- a medio crear. Reventar aquí haría fallar el cambio de estado, que es
  -- lo importante, por no poder hacer lo accesorio.
  if correo is null or correo = '' then
    return new;
  end if;

  insert into public.avisos (tramite, destinatario, pais, motivo, a_estado, nota)
  values (new.tramite, correo, coalesce(suPais, ''), 'cambio_estado',
          new.a_estado, coalesce(new.nota, ''));

  return new;
end
$avisos$;

drop trigger if exists eventos_avisar on public.tramite_eventos;
create trigger eventos_avisar
  after insert on public.tramite_eventos
  for each row execute function public.avisar_del_cambio();


-- ── y la nota llega DESPUÉS ──
-- Esto no se ve leyendo el esquema, sólo ejecutándolo. El historial lo
-- escribe un trigger en el momento del cambio de estado, cuando la nota
-- todavía no existe: el gestor la escribe justo después, con un UPDATE
-- sobre el evento ya creado (ver `eventos_solo_la_nota` en
-- supabase-gestor.sql, que sólo le deja tocar esa columna).
--
-- O sea que el aviso de arriba nacía con la nota VACÍA. Y precisamente en
-- 'devuelto', que es el único de los tres que pide una acción, la nota
-- ES el aviso: sin ella el correo dice «hay algo que corregir» y no dice
-- qué, que es peor que no mandarlo.
--
-- Se copia cuando llega, y sólo mientras el aviso siga sin salir. Si ya
-- salió no se toca: reescribir un correo que la persona ya tiene en la
-- bandeja no lo cambia, sólo hace que la base mienta sobre lo que se
-- mandó.

create or replace function public.avisar_de_la_nota()
returns trigger
language plpgsql
security definer
set search_path = public
as $avisos$
begin
  if new.nota is not distinct from old.nota then
    return new;
  end if;

  update public.avisos
     set nota = coalesce(new.nota, '')
   where tramite  = new.tramite
     and motivo   = 'cambio_estado'
     and a_estado = new.a_estado
     and estado   = 'pendiente';

  return new;
end
$avisos$;

drop trigger if exists eventos_avisar_nota on public.tramite_eventos;
create trigger eventos_avisar_nota
  after update on public.tramite_eventos
  for each row execute function public.avisar_de_la_nota();


-- ───────────────────────────────────────────────────────────────────────
-- 3. LO QUE VENCE
-- ───────────────────────────────────────────────────────────────────────
-- Esto no lo puede disparar ningún trigger: no ocurre porque alguien haga
-- algo, ocurre porque pasa el tiempo. Es el ejemplo más claro de por qué
-- hacía falta un proceso que corra sin que nadie mire.
--
-- La llama el mensajero una vez al día. Devuelve cuántos escribió, para
-- que quien la llame pueda decirlo en voz alta en vez de suponerlo.
--
-- Treinta días es el plazo: menos no da tiempo a pedir un documento en un
-- consulado, y más hace que el aviso llegue cuando aún no se puede hacer
-- nada y se olvide.

create or replace function public.avisar_de_lo_que_vence(dias int default 30)
returns int
language plpgsql
security definer
set search_path = public
as $avisos$
declare
  cuantos int := 0;
begin
  insert into public.avisos (tramite, destinatario, pais, motivo, nota, dato)
  select null,
         u.email,
         coalesce(p.pais, ''),
         'documento_vence',
         to_char(d.vence_el, 'YYYY-MM-DD'),
         coalesce(td.nombre, d.tipo)
    from public.documentos d
    join auth.users     u  on u.id  = d.inversionista
    left join public.perfiles p on p.id = d.inversionista
    left join public.tipos_documento td on td.codigo = d.tipo
   where d.vence_el is not null
     and d.estado <> 'rechazado'
     and d.vence_el between current_date and current_date + dias
     and u.email is not null
     -- Una vez por documento y por vencimiento, no una vez al día. Sin
     -- esto, un documento que vence en tres semanas manda veintiún
     -- correos iguales y la persona deja de leerlos.
     and not exists (
       select 1 from public.avisos a
        where a.motivo = 'documento_vence'
          and a.destinatario = u.email
          and a.dato = coalesce(td.nombre, d.tipo)
          and a.nota = to_char(d.vence_el, 'YYYY-MM-DD')
     );

  get diagnostics cuantos = row_count;
  return cuantos;
end
$avisos$;

-- Esta la llama el mensajero con la clave de servidor, una vez al dia.
-- Nadie mas tiene por que poder llamarla: es security definer y ESCRIBE.
--
-- Y hay que revocarsela a anon y a authenticated POR SU NOMBRE. Supabase
-- concede EXECUTE a los tres roles sobre toda funcion nueva de public, y
-- ese grant es nominal: quitarselo a PUBLIC no se lo quita a ellos. Se vio
-- con tocar_visto() al correr las cerraduras contra un Supabase de verdad.
--
-- Sin esto, un desconocido con la clave anonima -que es publica por
-- diseño- puede disparar el barrido de avisos del CIIP. No se lleva
-- ningun dato -devuelve un numero- pero escribe.
revoke all on function public.avisar_de_lo_que_vence(int) from public;
revoke all on function public.avisar_de_lo_que_vence(int) from anon;
revoke all on function public.avisar_de_lo_que_vence(int) from authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- 4. QUIÉN LO VE
-- ───────────────────────────────────────────────────────────────────────
-- El mensajero entra con la clave de servidor y se salta el RLS. Esto es
-- para las personas.
--
-- El inversionista NO ve su propio buzón de salida, y puede sonar raro.
-- La razón: aquí está su correo escrito en claro junto al de nadie más,
-- pero también los intentos fallidos y los errores del SMTP, que no
-- significan nada para él y parecen un problema suyo. Lo que sí le
-- interesa —qué pasó con su trámite— ya lo tiene en el historial, en su
-- idioma y sin ruido.

alter table public.avisos enable row level security;

drop policy if exists "avisos: el equipo los ve" on public.avisos;
create policy "avisos: el equipo los ve" on public.avisos
  for select using (public.es_gestor());


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Lo que está esperando salir:
--
--   select motivo, a_estado, destinatario, estado, intentos, ultimo_error
--   from public.avisos order by cuando;
--
-- 2) Que se escribe solo: devuelve un trámite desde la cola del gestor y
--    mira que aparezca su aviso. Si no aparece, o el trámite no tiene
--    dueño con correo, o el trigger no está.
--
-- 3) Los vencimientos, a mano, para ver qué haría el mensajero de noche:
--
--   select public.avisar_de_lo_que_vence(30);
--
--    Devuelve cuántos escribió. Llamarla dos veces seguidas tiene que
--    devolver 0 la segunda: no se avisa dos veces del mismo vencimiento.

-- ====================================================================
--  18 / 105   supabase-aranceles.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  LOS ARANCELES Y LAS ÓRDENES DE PAGO
--  Va DESPUÉS de supabase-cola.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  No hay trámite real sin tasa. Hasta aquí el panel se comporta como si
--  todo fuera gratis: el inversionista rellena, manda, y en algún momento
--  alguien le dice por otro canal que hay que pagar algo. Eso es
--  exactamente lo que una ventanilla única viene a quitar.
--
--  LA TABLA NACE VACÍA, A PROPÓSITO
--  ─────────────────────────────────────────────────────────────────────
--  Igual que `bancos_aliados`. Aquí NO se inventan cifras: un arancel es
--  un monto oficial, publicado en Gaceta, que cambia. Escribir aquí una
--  cantidad plausible sería peor que no tener nada, porque parecería
--  buena y alguien la creería.
--
--  Mientras esté vacía todo funciona igual que hasta ahora: sin arancel
--  no se crea orden de pago, y sin orden de pago el trámite sigue su
--  camino sin que nada le estorbe. Se llena cuando el CIIP tenga los
--  montos, y desde ese momento el trámite los pide.
--
--  LO QUE ESTO NO ES
--  ─────────────────────────────────────────────────────────────────────
--  No es una pasarela de pago. Aquí se guarda QUÉ se debe, CUÁNTO y si
--  está pagado. Cobrarlo de verdad necesita convenio bancario, y eso no
--  depende de nosotros; lo que sí depende es que el modelo esté bien y
--  probado, que es lo que hay aquí.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL CATÁLOGO DE TASAS
-- ───────────────────────────────────────────────────────────────────────
-- Con vigencia, y no un monto suelto por trámite. Un arancel cambia por
-- Gaceta, y una orden de pago emitida en marzo tiene que seguir diciendo
-- lo que decía en marzo aunque en abril suba: si se guardara sólo el
-- monto actual, el historial de lo cobrado se reescribiría solo.

create table if not exists public.aranceles (
  id       uuid primary key default gen_random_uuid(),
  tramite  text not null references public.tipos_tramite(codigo) on delete cascade,

  concepto text not null,
  monto    numeric(14,2) not null,
  moneda   text not null default 'USD',

  -- Abierto por la derecha = el que rige hoy. Cerrarlo es poner la fecha
  -- en que dejó de valer, nunca borrar la fila: lo cobrado bajo el
  -- arancel viejo tiene que seguir explicándose.
  desde    date not null default current_date,
  hasta    date,

  creado_en timestamptz not null default now(),

  constraint aranceles_monto_positivo check (monto > 0),
  constraint aranceles_vigencia_valida check (hasta is null or hasta >= desde)
);

comment on table  public.aranceles       is 'Cuánto cuesta cada trámite, con la vigencia de cada monto';
comment on column public.aranceles.hasta is 'null = es el que rige hoy. Se cierra, no se borra';

-- Un solo arancel vigente por trámite. Sin esto, dos filas abiertas
-- hacen que la orden de pago dependa de cuál lea primero la consulta, y
-- eso es un cobro distinto según el día.
create unique index if not exists aranceles_uno_vigente
  on public.aranceles (tramite)
  where hasta is null;

-- NACE VACÍA. Para poner uno:
--
--   insert into public.aranceles (tramite, concepto, monto, moneda) values
--     ('rif_empresa', 'Tasa de inscripción', 0.00, 'USD');
--
-- Para cambiarlo cuando salga en Gaceta, NO se edita la fila: se cierra
-- la vieja y se abre una nueva, en la misma transacción.
--
--   update public.aranceles set hasta = current_date
--    where tramite = 'rif_empresa' and hasta is null;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LO QUE SE DEBE
-- ───────────────────────────────────────────────────────────────────────
-- El monto se COPIA aquí, no se lee del catálogo cada vez. Es la misma
-- razón que en los avisos: una orden de pago dice lo que se debía el día
-- que se emitió. Si leyera el catálogo, subir un arancel cambiaría
-- retroactivamente lo que debe alguien que solicitó hace un mes.

create table if not exists public.ordenes_pago (
  id            uuid primary key default gen_random_uuid(),
  tramite       uuid not null references public.tramites(id) on delete cascade,
  inversionista uuid not null references auth.users(id) on delete cascade,

  concepto text not null,
  monto    numeric(14,2) not null,
  moneda   text not null default 'USD',

  estado   text not null default 'pendiente',

  -- La que da el banco o la pasarela. Es por lo que se reclama si algo
  -- no cuadra, así que se guarda aunque el pago falle.
  referencia  text,
  comprobante uuid references public.documentos(id) on delete set null,

  creado_en   timestamptz not null default now(),
  pagado_en   timestamptz,
  actualizado_en timestamptz not null default now(),

  constraint ordenes_estado_valido
    check (estado in ('pendiente', 'pagada', 'anulada')),
  constraint ordenes_monto_positivo check (monto > 0),
  -- Una orden pagada sin fecha de pago es una orden que no se puede
  -- conciliar con el banco. O las dos cosas o ninguna.
  constraint ordenes_pagada_con_fecha
    check (estado <> 'pagada' or pagado_en is not null)
);

comment on table  public.ordenes_pago        is 'Lo que debe un inversionista por un trámite concreto';
comment on column public.ordenes_pago.monto  is 'Copiado del arancel el día que se emitió. No se relee del catálogo';

create index if not exists ordenes_por_inversionista
  on public.ordenes_pago (inversionista, estado);

-- Una orden viva por trámite. Dos serían cobrar dos veces lo mismo.
create unique index if not exists ordenes_una_viva
  on public.ordenes_pago (tramite)
  where estado = 'pendiente';

drop trigger if exists ordenes_marca_tiempo on public.ordenes_pago;
create trigger ordenes_marca_tiempo
  before update on public.ordenes_pago
  for each row execute function public.tocar_actualizado_en();


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA ORDEN SE EMITE SOLA
-- ───────────────────────────────────────────────────────────────────────
-- Al enviar la solicitud, no antes. Emitirla al abrir el borrador sería
-- cobrarle a quien todavía está mirando; emitirla más tarde le daría la
-- noticia cuando ya cree que ha terminado.

create or replace function public.emitir_orden_de_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $aran$
declare
  tasa record;
begin
  if new.estado is not distinct from old.estado or new.estado <> 'enviado' then
    return new;
  end if;

  select concepto, monto, moneda into tasa
    from public.aranceles
   where tramite = new.tipo and hasta is null;

  -- Sin arancel no hay nada que cobrar, y el trámite sigue su camino sin
  -- que nada le estorbe. Es el caso de los treinta y uno hoy.
  if tasa is null then
    return new;
  end if;

  insert into public.ordenes_pago (tramite, inversionista, concepto, monto, moneda)
  values (new.id, new.inversionista, tasa.concepto, tasa.monto, tasa.moneda)
  on conflict do nothing;

  return new;
end
$aran$;

drop trigger if exists tramites_cobrar on public.tramites;
create trigger tramites_cobrar
  after update on public.tramites
  for each row execute function public.emitir_orden_de_pago();


-- ───────────────────────────────────────────────────────────────────────
-- 4. NO SE PRESENTA LO QUE NO ESTÁ PAGADO
-- ───────────────────────────────────────────────────────────────────────
-- Aquí está lo que de verdad hace esto útil, y es una sola línea de
-- lógica: si hay una orden pendiente, el trabajo de 'presentar' no se
-- encola. Presentar un expediente sin la tasa pagada es que el organismo
-- lo devuelva por un motivo administrativo, después de que una persona
-- del CIIP lo haya revisado. Trabajo perdido de los dos lados.
--
-- Se hace envolviendo `encolar_trabajo` en vez de tocándolo: la cola no
-- tiene por qué saber que existen los aranceles, y si mañana se quita
-- este archivo, aquella sigue funcionando como antes.

create or replace function public.encolar_trabajo()
returns trigger
language plpgsql
security definer
set search_path = public
as $aran$
declare
  quien text;
  cual  text;
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;

  select conector into quien from public.tipos_tramite where codigo = new.tipo;
  if quien is null then
    return new;
  end if;

  if    new.estado = 'en_revision'  then cual := 'presentar';
  elsif new.estado = 'ante_el_ente' then cual := 'consultar';
  else  return new;
  end if;

  -- Lo único que este archivo añade a la versión de supabase-cola.sql.
  -- Sólo estorba a 'presentar': una consulta sobre algo YA presentado no
  -- tiene nada que ver con lo que se deba.
  if cual = 'presentar' and exists (
       select 1 from public.ordenes_pago
        where tramite = new.id and estado = 'pendiente') then
    return new;
  end if;

  insert into public.trabajos (tramite, tarea, llave)
  values (new.id, cual, new.id::text)
  on conflict do nothing;

  return new;
end
$aran$;


-- ───────────────────────────────────────────────────────────────────────
-- 5. Y AL PAGAR, SE SUELTA
-- ───────────────────────────────────────────────────────────────────────
-- Si no, un trámite pagado después de la revisión se quedaría esperando
-- para siempre: el momento de encolar ya pasó y nadie volvería a mirarlo.

create or replace function public.soltar_al_pagar()
returns trigger
language plpgsql
security definer
set search_path = public
as $aran$
declare
  t record;
begin
  if new.estado <> 'pagada' or old.estado = 'pagada' then
    return new;
  end if;

  select id, tipo, estado into t from public.tramites where id = new.tramite;
  if t is null or t.estado <> 'en_revision' then
    return new;   -- todavía no le toca, o ya pasó de ahí
  end if;

  if (select conector from public.tipos_tramite where codigo = t.tipo) is null then
    return new;
  end if;

  insert into public.trabajos (tramite, tarea, llave)
  values (t.id, 'presentar', t.id::text)
  on conflict do nothing;

  return new;
end
$aran$;

drop trigger if exists ordenes_soltar on public.ordenes_pago;
create trigger ordenes_soltar
  after update on public.ordenes_pago
  for each row execute function public.soltar_al_pagar();


-- ───────────────────────────────────────────────────────────────────────
-- 6. QUIÉN LO VE
-- ───────────────────────────────────────────────────────────────────────
alter table public.aranceles    enable row level security;
alter table public.ordenes_pago enable row level security;

-- El catálogo es público para quien haya entrado: saber cuánto cuesta un
-- trámite ANTES de empezarlo es la mitad de lo que se viene a buscar.
drop policy if exists "aranceles: leerlos" on public.aranceles;
create policy "aranceles: leerlos" on public.aranceles
  for select to authenticated using (true);

drop policy if exists "aranceles: solo el admin escribe" on public.aranceles;
create policy "aranceles: solo el admin escribe" on public.aranceles
  for all
  using      (public.es_admin())
  with check (public.es_admin());

drop policy if exists "ordenes: la mia" on public.ordenes_pago;
create policy "ordenes: la mia" on public.ordenes_pago
  for select using (inversionista = auth.uid() or public.es_gestor());

-- Y NADIE la marca pagada desde el navegador, ni el equipo. No hay
-- política de update a propósito: eso lo escribe el cobrador con la clave
-- de servidor, después de que la pasarela lo confirme. Una orden que se
-- pueda dar por pagada desde el cliente no es una orden de pago.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) El catálogo sale VACÍO hasta que el CIIP lo llene. No es un fallo:
--    sin arancel, el trámite funciona como siempre.
--
--   select tramite, concepto, monto, moneda, desde, hasta
--   from public.aranceles order by tramite;
--
-- 2) Lo que se debe hoy:
--
--   select o.estado, o.concepto, o.monto, o.moneda, t.tipo
--   from public.ordenes_pago o join public.tramites t on t.id = o.tramite
--   order by o.creado_en;
--
-- 3) Que la orden frena la presentación: pon un arancel a un trámite con
--    conector, envíalo y revísalo. NO tiene que aparecer su 'presentar'
--    en public.trabajos hasta que la orden quede 'pagada'.

-- ====================================================================
--  19 / 105   supabase-huellas.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  LA HUELLA DE CADA DOCUMENTO
--  Va DESPUÉS de supabase-tramites.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  Dos agujeros que se tapan con la misma columna.
--
--  EL PRIMERO, y el que lo hace urgente: el conector del RIF ya manda el
--  `sha256` de cada recaudo al organismo —está en `armaExpediente`, con
--  su comentario explicando que es lo que deja probar después que lo que
--  recibieron es lo que el inversionista subió—. Pero NADA lo produce. Se
--  manda vacío. Es una promesa escrita en el contrato que hoy no se
--  cumple, y no se nota hasta el día en que hay que probar algo.
--
--  EL SEGUNDO: un documento que emite un ente y entra en la bóveda no se
--  puede verificar. Si un banco o un registro quiere comprobar que el
--  papel que le enseñan salió de verdad de aquí, no hay forma. Con la
--  huella la hay, y sin enseñarle a nadie de quién es el documento.
--
--  QUÉ NO ES
--  ─────────────────────────────────────────────────────────────────────
--  No es una firma electrónica. Una firma dice QUIÉN lo firmó y tiene
--  valor legal; esto sólo dice que dos archivos son el mismo. La firma
--  con validez legal necesita a SUSCERTE, que además es el trámite c19 de
--  esta misma ventanilla. Esto es lo que sí se puede hacer sin depender
--  de nadie.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA COLUMNA
-- ───────────────────────────────────────────────────────────────────────
-- Nullable, y no `not null`, por dos razones que no se pueden rodear:
--
--   1. Los documentos que ya están subidos no la tienen. Ponerla
--      obligatoria haría fallar este archivo en cualquier base con datos.
--   2. La huella la calcula el NAVEGADOR, y crypto.subtle sólo existe en
--      contexto seguro. Con ABRIR-LOCAL.bat lo hay; con ABRIR-EN-RED.bat,
--      que sirve por IP y sin https, no. Exigirla dejaría el panel sin
--      poder subir nada desde la red de la oficina.
--
-- O sea: null significa "no se pudo calcular", no "no vale". Un documento
-- sin huella sigue sirviendo para todo menos para verificarse.

alter table public.documentos
  add column if not exists huella text;

comment on column public.documentos.huella is
  'SHA-256 del archivo en minúsculas. null = no se pudo calcular al subirlo';

-- 64 caracteres hexadecimales, o nada. Sin esto, cualquier cadena entra y
-- la verificación empieza a devolver resultados a preguntas que no son
-- huellas.
alter table public.documentos
  drop constraint if exists documentos_huella_valida;
alter table public.documentos
  add  constraint documentos_huella_valida
  check (huella is null or huella ~ '^[0-9a-f]{64}$');

-- Por donde busca la verificación. No es único a propósito: el mismo
-- archivo subido por dos personas distintas tiene la misma huella, y eso
-- es correcto —son el mismo documento—; impedirlo dejaría al segundo sin
-- poder subir su copia de un acta que comparten.
create index if not exists documentos_por_huella
  on public.documentos (huella)
  where huella is not null;


-- ───────────────────────────────────────────────────────────────────────
-- 2. VERIFICAR, SIN ENSEÑAR DE QUIÉN ES
-- ───────────────────────────────────────────────────────────────────────
-- Aquí está todo el cuidado de este archivo. Quien verifica —un banco, un
-- registro, el propio organismo— tiene el papel delante: ya sabe de quién
-- es. Lo que no puede es preguntar por una huella cualquiera y averiguar
-- a quién pertenece, porque entonces esto sería un buscador de personas
-- por documento.
--
-- Así que devuelve lo que hace falta para creerle al papel y NADA que
-- identifique a nadie: qué tipo de documento es, si el CIIP lo dio por
-- bueno, cuándo, y si sigue vigente. Ni nombre, ni correo, ni id, ni
-- cuántos hay iguales.
--
-- Y sólo lo VALIDADO. Un documento recién subido y sin revisar no es
-- verificable: decir que sí lo es sería avalar un papel que aquí no ha
-- mirado nadie.

create or replace function public.verificar_documento(huella_hex text)
returns table (
  consta       boolean,
  tipo         text,
  validado_el  timestamptz,
  vence_el     date,
  vigente      boolean
)
language sql
stable
security definer
set search_path = public
as $huellas$
  select
    true,
    coalesce(td.nombre, d.tipo),
    d.actualizado_en,
    d.vence_el,
    (d.vence_el is null or d.vence_el >= current_date)
  from public.documentos d
  left join public.tipos_documento td on td.codigo = d.tipo
  where d.huella = lower(trim(huella_hex))
    and d.estado = 'validado'
  -- Uno solo aunque haya varios iguales. Cuántas copias existen de un
  -- documento no es asunto de quien verifica, y decirlo sería contar algo
  -- de otras personas.
  limit 1;
$huellas$;

comment on function public.verificar_documento(text) is
  'Dice si un documento validado consta, sin revelar de quién es';

-- Abierta a cualquiera, incluso sin entrar. Es el punto: quien verifica
-- no es usuario de la ventanilla, es un tercero con un papel en la mano.
-- Una verificación que exija cuenta no la usa nadie.
revoke all on function public.verificar_documento(text) from public;
grant execute on function public.verificar_documento(text) to anon, authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA HUELLA NO SE REESCRIBE
-- ───────────────────────────────────────────────────────────────────────
-- Es lo único que hace que sirva de algo. Si el dueño de un documento
-- pudiera cambiarle la huella, podría hacer que un archivo cualquiera
-- pasara por uno validado: sube algo, espera a que se lo validen, y luego
-- le pone la huella de otro archivo distinto.
--
-- Se puede escribir una vez —de null a un valor, al subirlo— y ya no.
-- Cambiar el archivo es subir un documento nuevo, que es exactamente lo
-- que hace el botón de «cambiar» del panel.

create or replace function public.huella_de_una_vez()
returns trigger
language plpgsql
as $huellas$
begin
  if auth.uid() is null then
    return new;   -- la puerta de servicio, como en las demás tablas
  end if;

  if old.huella is not null and new.huella is distinct from old.huella then
    raise exception 'La huella de un documento no se cambia. Sube uno nuevo.'
      using errcode = 'check_violation';
  end if;

  return new;
end
$huellas$;

drop trigger if exists documentos_huella_fija on public.documentos;
create trigger documentos_huella_fija
  before update on public.documentos
  for each row execute function public.huella_de_una_vez();


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Cuántos documentos tienen huella y cuántos no. Los viejos no la
--    tienen y está bien; lo que no puede pasar es que los NUEVOS tampoco.
--
--   select count(*) filter (where huella is not null) as con,
--          count(*) filter (where huella is null)     as sin
--   from public.documentos;
--
-- 2) Verificar uno a mano, con la huella de un archivo validado:
--
--   select * from public.verificar_documento('...64 hex...');
--
--    Sin fila = no consta. Con fila = consta, y dice qué es y si vigente,
--    sin decir de quién.
--
-- 3) Y que una huella inventada no devuelve nada:
--
--   select count(*) from public.verificar_documento(repeat('a', 64));

-- ====================================================================
--  20 / 105   supabase-encadenado.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  QUÉ PAPEL SALE DE CADA TRÁMITE
--  Va DESPUÉS de supabase-tramites.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  La tarjeta del RIF de la empresa dice «Se habilita tras la firma». La
--  de la cédula de residencia dice «Después de la visa». Están traducidas
--  a los seis idiomas.
--
--  Y no son ciertas. Son texto: no hay una sola línea de código que mire
--  si la constitución está resuelta antes de dejarte empezar el RIF. La
--  ventanilla DICE el orden pero no lo SABE, así que un inversionista
--  puede pedir el RIF de una empresa que todavía no existe y enterarse
--  cuando el SENIAT se lo devuelva.
--
--  LA CADENA NO SE ESCRIBE: SE DEDUCE
--  ─────────────────────────────────────────────────────────────────────
--  Escribir a mano «el c7 depende del c6» sería una segunda lista que
--  mantener, y que envejecería en cuanto alguien cambiara los recaudos de
--  un trámite sin acordarse de tocarla.
--
--  No hace falta, porque el dato ya está, repartido en dos sitios:
--
--    · qué papeles PIDE cada trámite  → RECAUDOS, en el panel
--    · qué papel SALE de cada trámite → esta columna, que es lo único
--                                        que faltaba
--
--  Con las dos, la cadena se calcula sola: si el c7 pide el acta y el
--  acta sale del c5, el c7 viene después del c5. Cambia un recaudo y la
--  cadena se recoloca sin que nadie la toque.
--
--  Lo dice tu propio comentario en el panel, escrito antes que este
--  archivo: «La constitución NO pide el acta: el acta es lo que SALE de
--  aquí, y de ahí pasa a la bóveda para que el c6 la tome».
--
--  Y OJO CON QUÉ ES LO QUE BLOQUEA
--  ─────────────────────────────────────────────────────────────────────
--  No te bloquea el TRÁMITE anterior: te bloquea no tener el PAPEL. Si ya
--  traes el acta de tu país, o constituiste la compañía antes de llegar
--  al CIIP, el acta está en tu bóveda y no tienes que pedirle nada a
--  nadie. Esa distinción es la ventanilla única entera: se pide una vez,
--  y da igual por dónde llegó.
-- ═══════════════════════════════════════════════════════════════════════


alter table public.tipos_tramite
  add column if not exists emite text references public.tipos_documento(codigo);

comment on column public.tipos_tramite.emite is
  'Qué tipo de documento produce este trámite. null = todavía no se sabe';


-- ───────────────────────────────────────────────────────────────────────
-- LOS QUE SE SABEN DE CIERTO
-- ───────────────────────────────────────────────────────────────────────
-- Seis, y ninguno inventado: cuatro porque el código del trámite y el del
-- documento son EL MISMO o el nombre no admite otra lectura, y el del
-- acta porque lo dice el comentario del panel.
--
-- Se activan con UPDATE y no en el INSERT del catálogo, que lleva ON
-- CONFLICT DO NOTHING y en una base que ya existe no tocaría nada.

-- La visa ya NO. La c1 era la TR-I, que abría la cédula de residencia, y
-- desde el 15 de septiembre de 2026 es la TR-N, de transeúnte: estampa una
-- visa, pero no la que pide la cédula, así que emitir 'visa' pondría a la
-- cédula a esperar por un trámite que no le sirve. Se pone a null con
-- UPDATE y no se borra la línea sin más: en una base que ya existe, el
-- 'visa' de antes seguiría puesto.
update public.tipos_tramite set emite = null                 where codigo = 'visa_negocios';
update public.tipos_tramite set emite = 'cedula'             where codigo = 'cedula_residencia';
update public.tipos_tramite set emite = 'rif_personal'       where codigo = 'rif_personal';
update public.tipos_tramite set emite = 'acta_constitutiva'  where codigo = 'constitucion';
update public.tipos_tramite set emite = 'rif_empresa'        where codigo = 'rif_empresa';
update public.tipos_tramite set emite = 'acta_protocolizada' where codigo = 'protocolizacion_acta';
update public.tipos_tramite set emite = 'conformidad_uso'    where codigo = 'conformidad_uso';

-- ───────────────────────────────────────────────────────────────────────
-- LOS QUE HAY QUE MIRAR ANTES DE PONER
-- ───────────────────────────────────────────────────────────────────────
-- Estos PARECEN evidentes y por eso mismo no van puestos: cada uno es una
-- afirmación sobre qué papel entrega un organismo venezolano, y eso lo
-- sabe el CIIP, no este archivo. Cuando alguien los confirme, se
-- descomenta la línea que toque.
--
-- Un trámite sin `emite` no estorba: simplemente no encadena nada, y todo
-- sigue funcionando como hasta hoy.
--
--   update public.tipos_tramite set emite = 'certificado_medico' where codigo = 'cert_medico';
--   update public.tipos_tramite set emite = 'bomberos'           where codigo = 'permiso_bomberos';
--   update public.tipos_tramite set emite = 'registro_rnet'      where codigo = 'rnet';
--   update public.tipos_tramite set emite = 'inversion'          where codigo = 'registro_inversion';
--   update public.tipos_tramite set emite = 'antecedentes'       where codigo = 'antecedentes_penales';
--
-- El de antecedentes es el mejor ejemplo de por qué van comentados: hay
-- DOS tipos de documento que podrían ser -'antecedentes' y
-- 'antecedentes_origen'- y elegir mal encadenaría el trámite equivocado.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Qué trámites emiten algo, y qué:
--
--   select ref_panel, codigo, emite from public.tipos_tramite
--    where emite is not null order by ref_panel;
--
-- 2) Y que ningún `emite` apunte a un tipo de documento que no existe.
--    La clave foránea ya lo impide al escribir; esto es para leerlo:
--
--   select t.codigo, t.emite from public.tipos_tramite t
--    left join public.tipos_documento d on d.codigo = t.emite
--    where t.emite is not null and d.codigo is null;
--
--    Tiene que salir vacío.
--
-- 3) La cadena que sale de ahí NO se consulta aquí: la calcula el panel
--    cruzando esto con los recaudos de cada trámite. Se mira en pantalla,
--    en la tarjeta que diga «esperando a».

-- ====================================================================
--  21 / 105   supabase-plazos.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CUÁNTO DEBERÍA TARDAR CADA TRÁMITE
--  Va DESPUÉS de supabase-tramites.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  El panel ya enseña las dos mitades del dato, una al lado de la otra, y
--  no las junta nunca:
--
--    · la tarjeta dice «Estimado: 2–3 semanas»
--    · el reloj dice «lleva 40 días esperando»
--
--  La resta la tiene que hacer la persona. Y esa resta es la mitad de por
--  qué alguien abre el panel: no «en qué va», sino «¿esto va tarde?».
--
--  De dónde salen los números: de la propia tarjeta, no de ningún sitio
--  nuevo. Aquí no se inventa un plazo legal —eso sale en Gaceta y lo sabe
--  el CIIP—: se pasa a número lo que el panel ya venía prometiendo en
--  seis idiomas.
--
--  SE TOMA EL TOPE, NO EL SUELO
--  ─────────────────────────────────────────────────────────────────────
--  De «2–3 semanas» se guarda 21 días, no 14. Avisar al llegar al suelo
--  del estimado sería avisar de casi todo casi siempre, y un aviso que
--  salta siempre se aprende a ignorar. Con el tope, que salte significa
--  algo.
--
--  OCHO SIN PLAZO, Y ESTÁ BIEN
--  ─────────────────────────────────────────────────────────────────────
--  Son los que no prometen ninguno: «Se pide en el consulado»,
--  «Disponible cuando quieras», «Se activan al operar». Un trámite sin
--  `plazo_dias` no se marca nunca, que es lo correcto: no se puede llegar
--  tarde a algo que no tenía hora.
--
--  Y DESDE CUÁNDO SE CUENTA
--  ─────────────────────────────────────────────────────────────────────
--  Eso NO se decide aquí, se decide en el panel, pero conviene dejarlo
--  escrito: desde que lo enviaste, no desde que empezaste el borrador. Un
--  borrador parado en tu bandeja no es la administración tardando. Y un
--  trámite devuelto tampoco cuenta: ahí la pelota la tienes tú.
-- ═══════════════════════════════════════════════════════════════════════


alter table public.tipos_tramite
  add column if not exists plazo_dias smallint;

comment on column public.tipos_tramite.plazo_dias is
  'Tope del estimado que promete la tarjeta, en días. null = no promete ninguno';

alter table public.tipos_tramite
  drop constraint if exists tipos_tramite_plazo_valido;
alter table public.tipos_tramite
  add  constraint tipos_tramite_plazo_valido
  check (plazo_dias is null or plazo_dias > 0);


-- ───────────────────────────────────────────────────────────────────────
-- LOS VEINTITRÉS QUE PROMETEN UN PLAZO
-- ───────────────────────────────────────────────────────────────────────
-- Sacados de lo que dice cada tarjeta hoy, en español, tomando el tope
-- del rango. El comentario de cada línea lleva el texto del que salió,
-- para poder comprobarlo sin abrir el panel.
--
-- Si mañana el CIIP tiene los plazos legales de verdad, se cambian estos
-- números y el panel deja de estimar y empieza a decir la ley. La forma
-- no cambia.

update public.tipos_tramite set plazo_dias =  28 where codigo = 'licencia_conducir';                 -- c4  Estimado: 3–4 semanas
update public.tipos_tramite set plazo_dias =  21 where codigo = 'constitucion';                      -- c5  Estimado: 2–3 semanas
update public.tipos_tramite set plazo_dias =  14 where codigo = 'cuenta_bancaria';                   -- c7  Estimado: 1–2 semanas
update public.tipos_tramite set plazo_dias = 240 where codigo = 'marca';                             -- c8  Estimado: 4–8 meses
update public.tipos_tramite set plazo_dias =  28 where codigo = 'registros_laborales';               -- c9  Estimado: 2–4 semanas
update public.tipos_tramite set plazo_dias =  42 where codigo = 'licencia_municipal';                -- c10  Estimado: 3–6 semanas
update public.tipos_tramite set plazo_dias =  90 where codigo = 'permiso_sanitario';                 -- c12  Estimado: 1–3 meses
update public.tipos_tramite set plazo_dias =  42 where codigo = 'antecedentes_penales';              -- c16  Estimado: 3–6 semanas
update public.tipos_tramite set plazo_dias =  28 where codigo = 'apostilla_documentos';              -- c17  Estimado: 2–4 semanas
update public.tipos_tramite set plazo_dias =  14 where codigo = 'constancia_domicilio';              -- c18  Estimado: 1–2 semanas
update public.tipos_tramite set plazo_dias =  21 where codigo = 'firma_electronica';                 -- c19  Estimado: 2–3 semanas
update public.tipos_tramite set plazo_dias =  70 where codigo = 'visa_dependientes';                 -- c20  Estimado: 6–10 semanas
update public.tipos_tramite set plazo_dias =   7 where codigo = 'cert_medico';                       -- c21  Estimado: 1 semana
update public.tipos_tramite set plazo_dias =  42 where codigo = 'protocolizacion_acta';              -- c22  Estimado: 2–6 semanas
update public.tipos_tramite set plazo_dias =  14 where codigo = 'publicacion_acta';                  -- c23  Estimado: 1–2 semanas
update public.tipos_tramite set plazo_dias =  28 where codigo = 'libros_contables';                  -- c24  Estimado: 2–4 semanas
update public.tipos_tramite set plazo_dias =  21 where codigo = 'faov_banavih';                      -- c25  Estimado: 2–3 semanas
update public.tipos_tramite set plazo_dias =  21 where codigo = 'inces';                             -- c26  Estimado: 2–3 semanas
update public.tipos_tramite set plazo_dias =  28 where codigo = 'rnet';                              -- c27  Estimado: 3–4 semanas
update public.tipos_tramite set plazo_dias =  60 where codigo = 'conformidad_uso';                   -- c28  Estimado: 1–2 meses
update public.tipos_tramite set plazo_dias =  42 where codigo = 'permiso_bomberos';                  -- c29  Estimado: 3–6 semanas
update public.tipos_tramite set plazo_dias = 180 where codigo = 'permiso_ambiental';                 -- c30  Estimado: 2–6 meses
update public.tipos_tramite set plazo_dias = 120 where codigo = 'registro_inversion';                -- c31  Estimado: 2–4 meses

-- ───────────────────────────────────────────────────────────────────────
-- LAS DOS QUE FALTABAN
-- ───────────────────────────────────────────────────────────────────────
-- La c32 y la c33 SÍ prometían un plazo en su tarjeta y no tenían fila
-- aquí. Mientras el renglón del reloj salía del diccionario no se notaba;
-- desde que sale de esta columna, sin fila no hay reloj, y estas dos lo
-- perderían diciendo un tiempo que sí tienen.
--
-- Salen del mismo sitio y por el mismo método que las veintitrés de
-- arriba: el texto que llevaba su propia tarjeta, tomando el tope del
-- rango. Ese texto ya no está en el panel —las 33 claves cN.time se
-- retiraron al dejar una sola cifra—, así que queda escrito aquí, que es
-- ahora el único sitio donde vive el dato.
update public.tipos_tramite set plazo_dias =  14 where codigo = 'registro_extranjeros_saren';        -- c32  Estimado: 1–2 semanas
update public.tipos_tramite set plazo_dias =   7 where codigo = 'poder_representacion';              -- c33  Estimado: 1 semana

-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Veintitrés con plazo y ocho sin él:
--
--   select count(*) filter (where plazo_dias is not null) as con,
--          count(*) filter (where plazo_dias is null)     as sin
--   from public.tipos_tramite;
--
-- 2) Y lo que de verdad se quiere ver: qué está tardando más de lo que se
--    prometió. Esto es la consulta que el panel hace en pantalla, escrita
--    aquí para poder mirarla desde el SQL Editor.
--
--   select t.id, t.tipo, tt.plazo_dias,
--          (current_date - t.enviado_en::date) as lleva
--   from public.tramites t
--   join public.tipos_tramite tt on tt.codigo = t.tipo
--   where t.estado in ('enviado','en_revision','ante_el_ente')
--     and tt.plazo_dias is not null
--     and t.enviado_en is not null
--     and (current_date - t.enviado_en::date) > tt.plazo_dias
--   order by lleva desc;
--
--    Fíjate en los tres estados: un borrador o un devuelto NO salen, y no
--    es un olvido. Ahí la pelota la tiene el inversionista, y contar ese
--    tiempo como retraso del organismo sería echarle la culpa al de
--    enfrente de lo que uno no ha hecho.


-- ═══════════════════════════════════════════════════════════════════════
--  Y EL PLAZO LEGAL, QUE NO ES EL ESTIMADO
-- ═══════════════════════════════════════════════════════════════════════
--  Los veintitrés números de arriba salen del texto de las tarjetas: son
--  lo que se TARDA, o lo que el CIIP calcula que se tarda. Esto es otra
--  cosa: lo que dice la NORMA. Van aparte porque casi nunca coinciden y
--  porque enseñar uno en lugar del otro engaña de las dos maneras.
--
--  EL INFORME PEDÍA SUSTITUIR UNO POR OTRO, Y ES PEOR
--  ─────────────────────────────────────────────────────────────────────
--  «Se recomienda suprimir de la vista del usuario el plazo en la
--   práctica y conservar de manera exclusiva el plazo legal regulatorio.»
--
--  Al ir a buscarlos aparece por qué eso no se puede hacer así. De las
--  dos normas leídas hasta hoy, NINGUNA fija plazo de respuesta: regulan
--  lo que debe hacer el ciudadano y cuánto vale el documento, no cuánto
--  tarda el organismo. Si no hay plazo propio, lo que queda es el
--  supletorio de la LOPA -cuatro meses, artículo 60-, y entonces la
--  tarjeta del RIF pasaría de «2–3 semanas» a «4 meses». Cierto, y mucho
--  peor para quien lo lee.
--
--  Así que se guardan los DOS, cada uno con su nombre.
--
--  CÓMO SE LEEN ESTAS DOS COLUMNAS
--  ─────────────────────────────────────────────────────────────────────
--  plazo_legal_norma es la que manda, y sirve de marca de comprobado:
--
--    norma NULL                  nadie lo ha mirado todavía. El panel no
--                                dice nada. Es el caso de 31 de 33.
--    norma puesta, días NULL     mirado, y su norma NO fija plazo de
--                                respuesta. El panel lo dice con esas
--                                palabras, que es la verdad y es útil.
--    norma puesta, días puestos  la norma fija plazo. Los días son suyos.
--
--  La cita va en castellano y no se traduce: «Gaceta Oficial
--  Extraordinaria 5.427» se llama igual en los seis idiomas. Lo que sí se
--  traduce -el rótulo y la frase de «no fija plazo»- vive en pasos.js.
--
--  NO SE INVENTA NINGUNO
--  ─────────────────────────────────────────────────────────────────────
--  Sólo entran los que se han leído en su fuente. Poner aquí el supletorio
--  de la LOPA en los treinta y tres sería escribir treinta y tres veces
--  una interpretación jurídica que no ha hecho ningún abogado, y con la
--  cara de dato comprobado. Los que faltan se van añadiendo con un UPDATE
--  cada vez que se confirme uno.
-- ═══════════════════════════════════════════════════════════════════════

alter table public.tipos_tramite
  add column if not exists plazo_legal_dias  smallint,
  add column if not exists plazo_legal_norma text;

comment on column public.tipos_tramite.plazo_legal_dias is
  'Plazo que fija la norma, en dias. Null con norma puesta = la norma no fija plazo';
comment on column public.tipos_tramite.plazo_legal_norma is
  'La norma leida, citada. Null = todavia no lo ha mirado nadie';

alter table public.tipos_tramite
  drop constraint if exists tipos_tramite_plazo_legal_valido;
alter table public.tipos_tramite
  add  constraint tipos_tramite_plazo_legal_valido
  check (plazo_legal_dias is null or plazo_legal_dias > 0);

-- Un plazo sin norma que lo respalde es justo lo que este archivo viene a
-- evitar: un numero con cara de ley y sin ley detras.
alter table public.tipos_tramite
  drop constraint if exists tipos_tramite_plazo_legal_con_fuente;
alter table public.tipos_tramite
  add  constraint tipos_tramite_plazo_legal_con_fuente
  check (plazo_legal_dias is null or plazo_legal_norma is not null);


-- ───────────────────────────────────────────────────────────────────────
-- LOS COMPROBADOS. HOY, DOS DE TREINTA Y TRES.
-- ───────────────────────────────────────────────────────────────────────
-- c1 · Visa de negocios (TR-N). Hasta el 15-9-2026, la de inversionista (TR-I)
--   Normas de Procedimiento para la Expedicion de Visados, Gaceta Oficial
--   Extraordinaria 5.427 del 5 de enero de 2000. Se leyo entera cuando la
--   c1 era la TR-I: sus articulos 11 y 12 dicen a quien se otorga y cuanto
--   VALE aquella visa -tres años, prorrogables dos-, y no fijan plazo para
--   decidirla. Lo que vale igual para la TR-N es lo general: el articulo 1
--   dice que los consulados «atenderan y decidiran» las solicitudes, sin
--   plazo. El articulo propio de la TR-N NO se ha vuelto a leer.
update public.tipos_tramite
   set plazo_legal_norma = 'Normas de Procedimiento para la Expedición de Visados, Gaceta Oficial Extraordinaria 5.427 del 5-1-2000',
       plazo_legal_dias  = null
 where codigo = 'visa_negocios';

-- c3 · RIF personal
--   Providencia SNAT/2026/00080, Gaceta Oficial 43.435 del 12 de agosto
--   de 2026, que deroga la SNAT/2013/0048. Es la vigente. No fija plazo
--   para que el SENIAT emita el RIF.
--
--   OJO CON EL DATO QUE CORRE POR AHI: los «30 dias habiles» que aparecen
--   en todas partes son el plazo que tiene el CONTRIBUYENTE para
--   inscribirse -articulo 5-, no el que tiene la administracion para
--   atenderle. Es la obligacion al reves, y meterla aqui seria mentir
--   con un dato verdadero.
update public.tipos_tramite
   set plazo_legal_norma = 'Providencia SNAT/2026/00080, Gaceta Oficial 43.435 del 12-8-2026',
       plazo_legal_dias  = null
 where codigo = 'rif_personal';


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Cuantos llevan norma leida. Hoy dos; que suba es el trabajo.
--
--   select count(*) filter (where plazo_legal_norma is not null) as mirados,
--          count(*)                                              as total
--   from public.tipos_tramite;
--
-- 2) Y cuales, con lo que se encontro:
--
--   select ref_panel, codigo, plazo_legal_dias, plazo_legal_norma
--   from public.tipos_tramite
--   where plazo_legal_norma is not null
--   order by ref_panel;
--
-- 3) Que no haya dias sin norma. Tiene que salir vacio; ademas lo impide
--    la restriccion de arriba, asi que esto es para leerlo:
--
--   select ref_panel from public.tipos_tramite
--   where plazo_legal_dias is not null and plazo_legal_norma is null;

-- ====================================================================
--  22 / 105   supabase-una-viva.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  UNA SOLA SOLICITUD VIVA POR TRÁMITE
--  Va DESPUÉS de supabase-tramites.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  El panel ya lo comprueba antes de enviar, y su propio comentario dice
--  lo que le falta:
--
--    «Es una comprobación del panel, no una cerradura. La de verdad sería
--     un índice único en la base, y esa es otra decisión.»
--
--  Esto es esa cerradura. La regla vivía sólo en el navegador, así que
--  cualquiera que llamara a la API de frente —o el propio panel con una
--  carrera muy justa entre dos pestañas— podía crear dos en marcha y la
--  base no decía nada. Es el mismo agujero que tenía la escalera de
--  estados: el panel decía la regla y la base no la sabía.
--
--  Y ya se sabe cómo acaba, porque pasó: aparecieron cuatro solicitudes
--  de la misma visa, y esas cuatro las recibe el CIIP y alguien tiene que
--  revisarlas una por una.
--
--  LO QUE **SÍ** SE PUEDE SEGUIR HACIENDO
--  ─────────────────────────────────────────────────────────────────────
--  Dos solicitudes del mismo trámite, mientras no estén vivas a la vez.
--  El índice es PARCIAL a propósito, y eso es toda la decisión:
--
--    · una RESUELTA no estorba. Hay trámites que se piden otra vez de
--      verdad —una solvencia caduca al año—, y bloquearlos para siempre
--      sería impedir el trámite normal, no el duplicado.
--    · una DEVUELTA tampoco. Volver a mandarla es exactamente lo que se
--      le está pidiendo al inversionista.
--    · un BORRADOR tampoco: todavía no ha pedido nada.
--
--  Lo único que se impide es que el CIIP reciba dos veces lo mismo sin
--  haber contestado a la primera.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. PRIMERO MIRAR SI YA HAY ALGUNO
-- ───────────────────────────────────────────────────────────────────────
-- Un CREATE UNIQUE INDEX sobre datos que ya incumplen la regla falla con
-- un mensaje que no dice cuáles son. Mejor mirarlo antes y decirlo, que
-- es lo que hay que arreglar a mano de todas formas.

do $viva$
declare
  cuantos int;
  ejemplo text;
begin
  select count(*), min(inversionista::text || ' / ' || tipo)
    into cuantos, ejemplo
  from (
    select inversionista, tipo
    from public.tramites
    where estado in ('enviado', 'en_revision', 'ante_el_ente')
    group by inversionista, tipo
    having count(*) > 1
  ) repetidos;

  if cuantos > 0 then
    raise exception
      'Hay % pares (persona, trámite) con más de una solicitud viva. El primero: %. Resuélvelos o descártalos antes de poner la cerradura.',
      cuantos, ejemplo;
  end if;
end
$viva$;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LA CERRADURA
-- ───────────────────────────────────────────────────────────────────────
-- Por (inversionista, tipo) y no sólo por tipo: dos personas distintas
-- pidiendo la misma visa a la vez es lo normal, no un duplicado.

create unique index if not exists tramites_una_viva
  on public.tramites (inversionista, tipo)
  where estado in ('enviado', 'en_revision', 'ante_el_ente');

comment on index public.tramites_una_viva is
  'Una sola solicitud en manos del CIIP por persona y trámite. Las resueltas y las devueltas no cuentan';


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Que está puesto:
--
--   select indexname from pg_indexes
--    where tablename = 'tramites' and indexname = 'tramites_una_viva';
--
-- 2) Que muerde. Con una solicitud tuya ya enviada, manda otra del mismo
--    trámite desde el panel: la base la rechaza aunque el aviso del
--    navegador no llegue a salir.
--
-- 3) Y que NO muerde donde no debe. Con una resuelta del año pasado,
--    pedir la del año siguiente tiene que entrar sin queja. Si no entra,
--    el índice se puso sin el WHERE y hay que rehacerlo.
--
--   select estado, count(*) from public.tramites
--    where tipo = 'solvencias' group by estado;

-- ====================================================================
--  23 / 105   supabase-hilo.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  EL HILO DEL EXPEDIENTE
--  Va DESPUÉS de supabase-tramites.sql y de supabase-gestor.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  Cuando el CIIP devuelve una solicitud escribe una nota: «El
--  comprobante del capital está ilegible: vuelve a subirlo escaneado».
--  Esa nota es de UNA SOLA DIRECCIÓN. El inversionista la lee y no tiene
--  dónde preguntar «¿el escaneado del banco vale, o tiene que ir
--  sellado?». Hoy la única salida es el correo o el teléfono, y lo que se
--  responda por ahí no queda en ningún expediente.
--
--  Esto es esa conversación, y va PEGADA al trámite. No es un chat del
--  panel: es el expediente hablando. Cada línea sabe de qué solicitud es,
--  y por eso «me dijeron que bastaba con el pasaporte» deja de ser una
--  frase suelta.
--
--  POR QUÉ UNA TABLA NUEVA Y NO tramite_eventos
--  ─────────────────────────────────────────────────────────────────────
--  El historial es un registro de CAMBIOS DE ESTADO: cada fila lleva
--  `a_estado`, y la escribe un trigger cuando el estado cambia. Meter ahí
--  los mensajes obligaría a inventarse un estado para cada frase, y el
--  historial —que hoy es exacto— empezaría a contar transiciones que no
--  ocurrieron. Son dos cosas distintas y se guardan aparte.
--
--  LOS ADJUNTOS VAN A LA BÓVEDA
--  ─────────────────────────────────────────────────────────────────────
--  Un mensaje puede llevar un documento, y ese documento es una fila de
--  `documentos` como cualquier otra, con tipo 'otro'. No hay un almacén
--  nuevo ni políticas nuevas: hereda el tope de 10 MB del cubo, la lista
--  de tipos permitidos, la huella SHA-256 y las cuatro políticas de
--  storage que ya existen.
--
--  Y de paso hace lo que hace una ventanilla única: la foto que mandas
--  para aclarar una duda queda en TU bóveda, y si mañana sirve de recaudo
--  no hay que volver a subirla.
-- ═══════════════════════════════════════════════════════════════════════


create table if not exists public.tramite_mensajes (
  id      uuid primary key default gen_random_uuid(),
  tramite uuid not null references public.tramites(id) on delete cascade,

  -- Lo pone el trigger con auth.uid(). Sobrevive a la cuenta borrada
  -- -on delete set null- porque un hilo con un hueco donde había una
  -- frase se lee peor que uno con una frase sin nombre.
  autor uuid references auth.users(id) on delete set null,

  -- Copiado al escribir, no releído del perfil. Quien escribió era del
  -- equipo ESE día; que mañana deje de serlo no cambia lo que dijo, y
  -- releerlo haría que el hilo se reescribiera solo al cambiar un rol.
  del_equipo boolean not null default false,

  texto     text not null default '',
  documento uuid references public.documentos(id) on delete set null,

  creado_en timestamptz not null default now(),

  -- Una de las dos cosas, al menos. Un mensaje vacío sin adjunto no dice
  -- nada y ensucia el hilo.
  constraint mensaje_dice_algo
    check (length(trim(texto)) > 0 or documento is not null),
  -- Límite generoso pero límite: sin él esto es un sitio donde pegar un
  -- libro, y el hilo deja de poder leerse.
  constraint mensaje_cabe check (length(texto) <= 4000)
);

comment on table  public.tramite_mensajes            is 'La conversación sobre una solicitud, entre el inversionista y el CIIP';
comment on column public.tramite_mensajes.del_equipo is 'Si lo escribió el CIIP. Copiado al escribir: el rol de mañana no cambia lo de ayer';
comment on column public.tramite_mensajes.documento  is 'Adjunto, que es una fila de la bóveda como cualquier otra';

create index if not exists mensajes_por_tramite
  on public.tramite_mensajes (tramite, creado_en);


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA FIRMA LA PONE LA BASE
-- ───────────────────────────────────────────────────────────────────────
-- Igual que en la constancia de identidad y por lo mismo: un mensaje que
-- se puede atribuir a otro es peor que no tener mensajes, porque parece
-- fiable. Una política podría comprobar `autor = auth.uid()`, pero
-- entonces habría que acordarse de mandarlo bien desde el panel. Así no
-- hay nada que acordarse: se ignora lo que venga y se pone lo que es.

create or replace function public.mensaje_lo_firma_la_base()
returns trigger
language plpgsql
security definer
set search_path = public
as $hilo$
begin
  new.autor      := auth.uid();
  new.del_equipo := public.es_gestor();
  new.creado_en  := now();
  return new;
end
$hilo$;

drop trigger if exists mensajes_firma on public.tramite_mensajes;
create trigger mensajes_firma
  before insert on public.tramite_mensajes
  for each row execute function public.mensaje_lo_firma_la_base();


-- ───────────────────────────────────────────────────────────────────────
-- 2. NI EL ADJUNTO SE PUEDE FALSEAR
-- ───────────────────────────────────────────────────────────────────────
-- Sin esto, se podría colgar de un mensaje el documento de OTRA persona,
-- y como el hilo enseña sus adjuntos, eso sería una forma de leer la
-- bóveda ajena: adjunta un id cualquiera y mira qué sale.
--
-- El adjunto tiene que pertenecer al dueño del trámite. Vale tanto si lo
-- subió él como si lo dejó el equipo en su carpeta —una resolución, por
-- ejemplo—, porque en los dos casos es SUYO.

create or replace function public.adjunto_del_mismo_expediente()
returns trigger
language plpgsql
security definer
set search_path = public
as $hilo$
declare
  duenio uuid;
  deQuien uuid;
begin
  if new.documento is null then
    return new;
  end if;

  select inversionista into duenio  from public.tramites   where id = new.tramite;
  select inversionista into deQuien from public.documentos where id = new.documento;

  if deQuien is null or duenio is null or deQuien <> duenio then
    raise exception 'Ese documento no es de este expediente.'
      using errcode = 'check_violation';
  end if;

  return new;
end
$hilo$;

drop trigger if exists mensajes_adjunto on public.tramite_mensajes;
create trigger mensajes_adjunto
  before insert on public.tramite_mensajes
  for each row execute function public.adjunto_del_mismo_expediente();


-- ───────────────────────────────────────────────────────────────────────
-- 3. LO DICHO NO SE REESCRIBE
-- ───────────────────────────────────────────────────────────────────────
-- No hay política de UPDATE ni de DELETE, y esto lo cierra además por si
-- mañana alguien añade una. Con la puerta de servicio abierta —auth.uid()
-- nulo— para poder quitar a mano algo que no debería estar ahí: eso es
-- una decisión de persona, no de código.

-- Desde el 15-10-2026 la redefine supabase-borrado-admin.sql: la misma, con
-- la puerta del borrado del administrador (solo para borrar).
create or replace function public.mensaje_no_se_toca()
returns trigger
language plpgsql
as $hilo$
begin
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  raise exception 'Un mensaje no se cambia ni se borra. Escribe otro.'
    using errcode = 'check_violation';
end
$hilo$;

drop trigger if exists mensajes_inmutable on public.tramite_mensajes;
create trigger mensajes_inmutable
  before update or delete on public.tramite_mensajes
  for each row execute function public.mensaje_no_se_toca();


-- ───────────────────────────────────────────────────────────────────────
-- 4. QUIÉN LEE Y QUIÉN ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
alter table public.tramite_mensajes enable row level security;

-- El dueño del expediente, y el equipo, que atiende a todos.
drop policy if exists "mensajes: los de mi expediente" on public.tramite_mensajes;
create policy "mensajes: los de mi expediente" on public.tramite_mensajes
  for select using (
    public.es_gestor() or exists (
      select 1 from public.tramites t
      where t.id = tramite and t.inversionista = auth.uid()
    )
  );

-- Escribir: los dos, en los dos sentidos. Eso es todo el punto.
--
-- Y en CUALQUIER estado, incluido un borrador o un trámite ya resuelto.
-- Se pensó en cerrarlo al resolverse y es peor: la pregunta más común
-- llega justo después —«me llegó el RIF, ¿ya puedo abrir la cuenta?»— y
-- mandarla por otro canal es exactamente lo que esto viene a quitar. Lo
-- que ata el hilo no es el estado, es el expediente.
drop policy if exists "mensajes: escribir en mi expediente" on public.tramite_mensajes;
create policy "mensajes: escribir en mi expediente" on public.tramite_mensajes
  for insert with check (
    public.es_gestor() or exists (
      select 1 from public.tramites t
      where t.id = tramite and t.inversionista = auth.uid()
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- 5. Y EL EQUIPO TAMBIÉN PUEDE ADJUNTAR
-- ───────────────────────────────────────────────────────────────────────
-- Un hilo donde sólo una parte puede mandar una foto no es una
-- conversación. Y el adjunto tiene que ser del DUEÑO del expediente —lo
-- exige el trigger de arriba, y con razón—, así que el equipo necesita
-- poder dejar un documento en la bóveda de otro.
--
-- Ya podía, pero sólo uno: `supabase-emision.sql` le deja meter el
-- documento que emitió el ente, con tipo 'resolucion' y estado
-- 'validado'. Una foto aclaratoria no es ninguna de las dos cosas.
--
-- Esta política añade el otro caso, y es deliberadamente estrecha:
--
--   · sólo tipo 'otro'. No puede dejar un pasaporte ni un RIF: si un
--     recaudo con nombre propio apareciera en tu bóveda sin haberlo
--     subido tú, el trámite que lo pide lo daría por presentado.
--   · sólo 'cargado', nunca 'validado'. Lo que manda el CIIP en una
--     conversación es una aclaración, no un papel dado por bueno.
--   · y en la subcarpeta 'emitidos', que es donde el cubo ya le deja
--     escribir dentro de la carpeta de otro.

drop policy if exists "documentos: el equipo adjunta en un hilo" on public.documentos;
create policy "documentos: el equipo adjunta en un hilo" on public.documentos
  for insert
  with check (
    public.es_gestor()
    and tipo = 'otro'
    and estado = 'cargado'
  );


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) El hilo de una solicitud, en orden y diciendo quién habla:
--
--   select creado_en, del_equipo, texto, documento
--   from public.tramite_mensajes where tramite = '…' order by creado_en;
--
-- 2) Que el autor no se puede falsear: manda uno con `autor` de otra
--    persona. Tiene que quedar guardado con el TUYO.
--
-- 3) Que el adjunto ajeno no entra: manda uno con el `documento` de otra
--    persona. La base lo rechaza con «Ese documento no es de este
--    expediente».
--
-- 4) Y que nadie ve el hilo de otro. Eso no se comprueba desde el SQL
--    Editor —ahí auth.uid() es null y RLS no aplica—: hay que entrar con
--    dos cuentas, y es lo que hace PROBAR-CERRADURAS.bat.

-- ====================================================================
--  24 / 105   supabase-hilo-citas.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  EL HILO DE UNA CITA
--  Va DESPUÉS de supabase-citas.sql y de supabase-hilo.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  POR QUÉ EXISTE
--  ─────────────────────────────────────────────────────────────────────
--  Quien acaba de entrar y no ha empezado ningún trámite no tiene dónde
--  preguntar. El hilo del expediente cuelga de una solicitud, y él no
--  tiene ninguna. Así que sus primeras preguntas —«¿por dónde empiezo?»,
--  «¿mi caso califica?»— salen por correo o por teléfono, y lo que se
--  responda ahí no queda en ninguna parte.
--
--  Es justo el momento en que una ventanilla única se gana o se pierde.
--
--  POR QUÉ AQUÍ Y NO EN UN CHAT SUELTO
--  ─────────────────────────────────────────────────────────────────────
--  Se pensó en un canal general, sin colgar de nada, y es peor por tres
--  razones:
--
--   1. En cuanto hay dos sitios donde escribir, la gente escribe en el que
--      tiene delante. Las preguntas de un trámite acabarían en el general
--      y el hilo del expediente perdería lo único que lo hace valioso: que
--      cada línea sabe de qué solicitud habla.
--   2. Una bandeja sin fondo no tiene cola, ni dueño, ni forma de saber
--      qué está sin contestar. El hilo del expediente funciona porque
--      cuelga de trabajo en marcha que alguien ya tiene abierto.
--   3. Con adjuntos, lo primero que llega en un primer contacto son
--      pasaportes. Sin nada detrás que los sostenga, son papeles sueltos.
--
--  Y no hacía falta inventar nada, porque el sitio ya estaba previsto.
--  supabase-citas.sql lo dice de su propia columna:
--
--    «tipo_tramite — Null = una consulta general, que es un caso legítimo
--     y no un dato que falte: no toda cita es de un trámite.»
--
--  O sea: una cita general YA ES la conversación general. Lo que le
--  faltaba era la vuelta. La cita tiene una nota de ida y ninguna de
--  regreso, así que la conversación se moría ahí y seguía por fuera.
--
--  Esto es esa vuelta. Y cada mensaje sigue colgando de algo que tiene
--  ESTADO y DUEÑO —solicitada, confirmada, hecha, cancelada—, que es lo
--  que convierte «un mensaje» en «algo que alguien tiene que atender».
--
--  LO QUE SE REPITE DE supabase-hilo.sql, Y POR QUÉ SE REPITE
--  ─────────────────────────────────────────────────────────────────────
--  La forma es la misma: la firma la pone la base, el adjunto tiene que
--  ser del dueño, y lo dicho no se reescribe. Son dos tablas y no una
--  porque las llaves foráneas apuntan a sitios distintos —una a tramites
--  y otra a citas— y meterlas juntas obligaría a una columna nula en cada
--  fila y a un check que vigile que exactamente una de las dos está
--  puesta. Más código para ahorrar una tabla.
--
--  Lo que NO se repite es la política que deja al equipo dejar un
--  documento en la bóveda de otro: la de supabase-hilo.sql no menciona
--  trámites, así que vale igual aquí.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────
do $$
begin
  if to_regclass('public.citas') is null then
    raise exception using
      message = 'Falta la tabla public.citas',
      hint    = 'Ejecuta antes supabase-citas.sql en este mismo proyecto.';
  end if;
end $$;


create table if not exists public.cita_mensajes (
  id   uuid primary key default gen_random_uuid(),
  cita uuid not null references public.citas(id) on delete cascade,

  -- Lo pone el trigger con auth.uid(). Sobrevive a la cuenta borrada
  -- -on delete set null- porque un hilo con un hueco donde había una
  -- frase se lee peor que uno con una frase sin nombre.
  autor uuid references auth.users(id) on delete set null,

  -- Copiado al escribir, no releído del perfil. Quien escribió era del
  -- equipo ESE día; que mañana deje de serlo no cambia lo que dijo.
  del_equipo boolean not null default false,

  texto     text not null default '',
  documento uuid references public.documentos(id) on delete set null,

  creado_en timestamptz not null default now(),

  constraint cita_mensaje_dice_algo
    check (length(trim(texto)) > 0 or documento is not null),
  constraint cita_mensaje_cabe check (length(texto) <= 4000)
);

comment on table  public.cita_mensajes            is 'La conversación sobre una cita. Con tipo_tramite null, es la consulta general de quien aún no ha empezado nada';
comment on column public.cita_mensajes.del_equipo is 'Si lo escribió el CIIP. Copiado al escribir: el rol de mañana no cambia lo de ayer';

create index if not exists cita_mensajes_por_cita
  on public.cita_mensajes (cita, creado_en);


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA FIRMA LA PONE LA BASE
-- ───────────────────────────────────────────────────────────────────────
-- Igual que en el hilo del expediente y por lo mismo: un mensaje que se
-- puede atribuir a otro es peor que no tener mensajes, porque parece
-- fiable. Se ignora lo que venga y se pone lo que es.
create or replace function public.cita_mensaje_lo_firma_la_base()
returns trigger
language plpgsql
security definer
set search_path = public
as $hilo$
begin
  new.autor      := auth.uid();
  new.del_equipo := public.es_gestor();
  new.creado_en  := now();
  return new;
end
$hilo$;

drop trigger if exists cita_mensajes_firma on public.cita_mensajes;
create trigger cita_mensajes_firma
  before insert on public.cita_mensajes
  for each row execute function public.cita_mensaje_lo_firma_la_base();


-- ───────────────────────────────────────────────────────────────────────
-- 2. NI EL ADJUNTO SE PUEDE FALSEAR
-- ───────────────────────────────────────────────────────────────────────
-- Sin esto se podría colgar de un mensaje el documento de OTRA persona, y
-- como el hilo enseña sus adjuntos, eso sería una forma de leer la bóveda
-- ajena: adjunta un id cualquiera y mira qué sale.
create or replace function public.adjunto_de_la_misma_cita()
returns trigger
language plpgsql
security definer
set search_path = public
as $hilo$
declare
  duenio  uuid;
  deQuien uuid;
begin
  if new.documento is null then
    return new;
  end if;

  select inversionista into duenio  from public.citas      where id = new.cita;
  select inversionista into deQuien from public.documentos where id = new.documento;

  if deQuien is null or duenio is null or deQuien <> duenio then
    raise exception 'Ese documento no es de esta cita.'
      using errcode = 'check_violation';
  end if;

  return new;
end
$hilo$;

drop trigger if exists cita_mensajes_adjunto on public.cita_mensajes;
create trigger cita_mensajes_adjunto
  before insert on public.cita_mensajes
  for each row execute function public.adjunto_de_la_misma_cita();


-- ───────────────────────────────────────────────────────────────────────
-- 3. LO DICHO NO SE REESCRIBE
-- ───────────────────────────────────────────────────────────────────────
-- No hay política de UPDATE ni de DELETE, y esto lo cierra además por si
-- mañana alguien añade una. Con la puerta de servicio abierta -auth.uid()
-- nulo- para poder quitar a mano algo que no debería estar ahí.
create or replace function public.cita_mensaje_no_se_toca()
returns trigger
language plpgsql
as $hilo$
begin
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  raise exception 'Un mensaje no se cambia ni se borra. Escribe otro.'
    using errcode = 'check_violation';
end
$hilo$;

drop trigger if exists cita_mensajes_inmutable on public.cita_mensajes;
create trigger cita_mensajes_inmutable
  before update or delete on public.cita_mensajes
  for each row execute function public.cita_mensaje_no_se_toca();


-- ───────────────────────────────────────────────────────────────────────
-- 4. QUIÉN LEE Y QUIÉN ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
alter table public.cita_mensajes enable row level security;

drop policy if exists "cita_mensajes: los de mi cita" on public.cita_mensajes;
create policy "cita_mensajes: los de mi cita" on public.cita_mensajes
  for select using (
    public.es_gestor() or exists (
      select 1 from public.citas c
      where c.id = cita and c.inversionista = auth.uid()
    )
  );

-- Escribir: los dos, en los dos sentidos. Eso es todo el punto.
--
-- Y en CUALQUIER estado, cancelada incluida. Se pensó en cerrarlo al
-- cancelar y es peor: «¿por qué se canceló?» y «¿la pedimos para otro
-- día?» son exactamente las dos preguntas que llegan justo después, y
-- mandarlas por otro canal es lo que esto viene a quitar. Lo que ata el
-- hilo no es el estado, es la cita.
drop policy if exists "cita_mensajes: escribir en mi cita" on public.cita_mensajes;
create policy "cita_mensajes: escribir en mi cita" on public.cita_mensajes
  for insert with check (
    public.es_gestor() or exists (
      select 1 from public.citas c
      where c.id = cita and c.inversionista = auth.uid()
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) El hilo de una cita, en orden y diciendo quién habla:
--
--   select creado_en, del_equipo, texto, documento
--   from public.cita_mensajes where cita = '…' order by creado_en;
--
-- 2) Las consultas GENERALES, que son la razón de este archivo: citas sin
--    trámite detrás, con cuántas veces se ha hablado en cada una.
--
--   select c.id, c.estado, c.creado_en,
--          (select count(*) from public.cita_mensajes m where m.cita = c.id) as mensajes
--   from public.citas c
--   where c.tipo_tramite is null
--   order by c.creado_en desc;
--
-- 3) Y que nadie ve el hilo de otro. Eso no se comprueba desde el SQL
--    Editor -ahí auth.uid() es null y RLS no aplica-: hay que entrar con
--    dos cuentas, y es lo que hace PROBAR-CERRADURAS.bat.

-- ====================================================================
--  25 / 105   supabase-consultas.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════════
--  LA CONSULTA: HABLAR CON EL CIIP SIN PEDIR CITA
-- ═══════════════════════════════════════════════════════════════════════════
--
--  QUÉ PROBLEMA RESUELVE
--
--  Hasta ahora, un inversionista que quería que el CIIP le llevara un trámite
--  —o que simplemente tenía una duda— sólo tenía una puerta: agendar una cita.
--  Eso obliga a reservar una hora para preguntar algo que se contesta en dos
--  líneas, y deja al equipo sin enterarse de la petición hasta que llega el
--  día. La cita es cara para las dos partes y no debería ser la única entrada.
--
--  Esto abre la otra: una CONSULTA. El inversionista la abre, el equipo la ve
--  en su cola, y se habla por escrito. La cita se queda para cuando de verdad
--  haga falta hablar, que es lo que siempre debió ser.
--
--
--  POR QUÉ UNA TABLA NUEVA Y NO UN ESTADO MÁS EN 'tramites'
--
--  Se pensó en meterlo en tramites con un estado 'consulta'. No sirve, y la
--  razón es la misma que hace que esto funcione: una consulta puede NO tener
--  trámite. «¿Necesito visa para esto?» no es una solicitud de nada. Metida
--  en tramites obligaría a inventar un tipo falso y a que 'tipo' —que hoy
--  apunta al catálogo con una clave foránea de verdad— dejara de significar
--  lo que significa.
--
--  Y al revés: una consulta SÍ puede colgar de un trámite, y por eso está la
--  columna. El botón «que lo hagan ustedes» de una ficha abre la consulta con
--  ese trámite dentro; la burbuja la abre suelta. Son la misma cosa entrando
--  por dos sitios, y por eso comparten cola: si fueran dos tablas, el equipo
--  tendría que mirar en dos bandejas y una de las dos se quedaría sin mirar.
--
--
--  LO QUE ESTO NO ES
--
--  No es un chat en vivo, y la diferencia importa. Un chat promete que hay
--  alguien AHORA; el equipo del CIIP no está las veinticuatro horas, y un
--  inversionista en Italia escribiendo a medianoche se encontraría el silencio
--  y sacaría la conclusión de que la ventanilla no funciona. Esto es un
--  ticket con forma de conversación: se escribe cuando sea, se responde en
--  horario, y la respuesta llega por el aviso que ya existe.
--
--  Por eso NO hay aquí nada de Realtime. La pantalla relee mientras está
--  abierta y ya está. Si algún día el CIIP quiere el socket, esta tabla vale
--  igual: lo que cambia es quién avisa, no lo que se guarda.
-- ═══════════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────────
-- Las políticas de aquí abajo se apoyan en es_gestor(), y los disparadores en
-- funciones que crea la sección del hilo del expediente. Sin eso, esto se
-- crearía a medias y con las puertas abiertas: mejor que no pase nada.
do $$
begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'es_gestor'
  ) then
    raise exception 'Falta public.es_gestor(). Pasa antes las secciones de arriba.';
  end if;

  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'mensaje_lo_firma_la_base'
  ) then
    raise exception 'Falta public.mensaje_lo_firma_la_base(). Pasa antes la sección del hilo.';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────────
-- 1. LA CONSULTA
-- ───────────────────────────────────────────────────────────────────────────
create table if not exists public.consultas (
  id            uuid primary key default gen_random_uuid(),
  inversionista uuid not null references auth.users(id) on delete cascade,

  -- De qué trámite habla, si habla de alguno. Nula a propósito: media razón
  -- de existir de esta tabla son las consultas que no cuelgan de nada.
  --
  -- 'set null' y no 'cascade': si el trámite se borra, la conversación no se
  -- va con él. Lo que se dijo se dijo, y el equipo puede necesitar releerlo
  -- justamente porque el expediente ya no está.
  tramite       uuid references public.tramites(id) on delete set null,

  -- De qué CLASE de trámite habla, que no es lo mismo. Cuando alguien pulsa
  -- «que lo hagan ustedes» en una ficha todavía no hay expediente: no ha
  -- rellenado nada, que es justamente por lo que pide ayuda. Lo único que
  -- hay es el código del catálogo, y sin esta columna se perdería —el equipo
  -- vería «Acreditación de representación legal» escrito en el asunto y no
  -- tendría forma de enlazarlo con el trámite de verdad—.
  tipo          text references public.tipos_tramite(codigo),

  -- De qué va, en una línea. Lo escribe el inversionista o lo pone el panel
  -- cuando nace desde una ficha ("Acreditación de representación legal").
  asunto        text not null default '',

  -- Los mismos tres momentos que tiene cualquier cola: nadie la ha cogido,
  -- alguien la lleva, se acabó. Deliberadamente NO se copian los seis estados
  -- de un trámite: una consulta no va a ningún organismo.
  estado        text not null default 'abierta',

  -- Quién del CIIP la lleva. Null = sin asignar, que es lo que la hace salir
  -- en la cola. Igual que en tramites.gestor.
  gestor        uuid references auth.users(id) on delete set null,

  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),
  resuelto_en    timestamptz,

  constraint consultas_estado_valido
    check (estado in ('abierta','en_curso','resuelta')),

  -- Un asunto de tres letras no dice nada, y uno de mil no cabe en la cola.
  constraint consultas_asunto_cabe
    check (length(asunto) <= 200)
);

comment on table  public.consultas         is 'Una conversación con el CIIP, con o sin trámite detrás. La alternativa a pedir cita';
comment on column public.consultas.tramite is 'De qué trámite habla. Null = consulta suelta, que es la mitad del motivo de esta tabla';
comment on column public.consultas.tipo    is 'De qué clase de trámite habla. Lo pone la ficha, que sabe el código pero todavía no tiene expediente';
comment on column public.consultas.gestor  is 'Quién del CIIP la lleva. Null = sin asignar, que es lo que la cola busca';

-- La cola del equipo: las que nadie lleva, las más viejas primero.
create index if not exists consultas_cola
  on public.consultas (estado, creado_en)
  where estado in ('abierta','en_curso');

create index if not exists consultas_por_inversionista
  on public.consultas (inversionista, creado_en);


-- ───────────────────────────────────────────────────────────────────────────
-- 2. LO QUE NO DECIDE QUIEN LA ABRE
-- ───────────────────────────────────────────────────────────────────────────
-- Igual que la firma de un mensaje: de quién es, en qué estado nace y quién
-- la lleva NO se mandan desde el navegador. Si se aceptaran, cualquiera con
-- la clave anon podría abrir una consulta a nombre de otro, o nacerla ya
-- 'resuelta' —que es la forma más limpia de que el equipo no la vea nunca—.
create or replace function public.consulta_la_firma_la_base()
returns trigger
language plpgsql
security definer
set search_path = public
as $con$
begin
  -- Desde el SQL Editor auth.uid() es null, y ahí se entra a propósito por la
  -- puerta de servicio: sembrar datos de ejemplo tiene que seguir siendo
  -- posible. Con sesión, manda la sesión.
  if auth.uid() is not null then
    new.inversionista := auth.uid();
    new.estado        := 'abierta';
    new.gestor        := null;
    new.resuelto_en   := null;
  end if;
  new.creado_en      := now();
  new.actualizado_en := now();
  return new;
end
$con$;

drop trigger if exists consultas_firma on public.consultas;
create trigger consultas_firma
  before insert on public.consultas
  for each row execute function public.consulta_la_firma_la_base();


-- Y al cambiarla: la hora se pone sola, y 'resuelto_en' cuadra con el estado.
-- Sin esto, una consulta puede quedar 'resuelta' sin fecha o con la fecha de
-- cuando se resolvió la vez anterior, y el informe de cuánto tarda el equipo
-- en contestar mide humo.
create or replace function public.consulta_al_cambiar()
returns trigger
language plpgsql
as $con$
begin
  new.actualizado_en := now();

  if new.estado = 'resuelta' and old.estado <> 'resuelta' then
    new.resuelto_en := now();
  elsif new.estado <> 'resuelta' then
    new.resuelto_en := null;
  end if;

  -- De quién es no se cambia nunca. Una consulta que cambia de dueño es una
  -- conversación privada que aparece en la pantalla de otro.
  new.inversionista := old.inversionista;
  return new;
end
$con$;

drop trigger if exists consultas_cambio on public.consultas;
create trigger consultas_cambio
  before update on public.consultas
  for each row execute function public.consulta_al_cambiar();


-- ───────────────────────────────────────────────────────────────────────────
-- 3. LA CONVERSACIÓN
-- ───────────────────────────────────────────────────────────────────────────
-- Calcada de tramite_mensajes, y a propósito: el panel pinta los hilos con
-- una sola función que recibe la tabla y la columna. Una forma distinta aquí
-- obligaría a una segunda función casi igual, que es de donde salen los dos
-- comportamientos que se separan sin que nadie lo note.
create table if not exists public.consulta_mensajes (
  id       uuid primary key default gen_random_uuid(),
  consulta uuid not null references public.consultas(id) on delete cascade,

  autor uuid references auth.users(id) on delete set null,

  del_equipo boolean not null default false,

  texto     text not null default '',
  documento uuid references public.documentos(id) on delete set null,

  creado_en timestamptz not null default now(),

  constraint consulta_mensaje_dice_algo
    check (length(trim(texto)) > 0 or documento is not null),
  constraint consulta_mensaje_cabe check (length(texto) <= 4000)
);

comment on table public.consulta_mensajes is 'La conversación de una consulta. Misma forma que la de un expediente, a propósito';

create index if not exists consulta_mensajes_por_consulta
  on public.consulta_mensajes (consulta, creado_en);

-- La firma la pone la base, con la MISMA función que el hilo del expediente:
-- pone autor, del_equipo y la hora, y no mira de qué tabla viene. Copiarla
-- habría sido dejar dos sitios donde arreglar el mismo fallo.
drop trigger if exists consulta_mensajes_firma on public.consulta_mensajes;
create trigger consulta_mensajes_firma
  before insert on public.consulta_mensajes
  for each row execute function public.mensaje_lo_firma_la_base();

-- Y lo dicho no se reescribe, también con la de allí.
drop trigger if exists consulta_mensajes_inmutable on public.consulta_mensajes;
create trigger consulta_mensajes_inmutable
  before update or delete on public.consulta_mensajes
  for each row execute function public.mensaje_no_se_toca();


-- El adjunto tiene que ser de la bóveda del dueño de la consulta. La función
-- del expediente mira public.tramites y aquí no vale: ésta mira consultas.
create or replace function public.adjunto_de_la_misma_consulta()
returns trigger
language plpgsql
security definer
set search_path = public
as $con$
declare
  duenio  uuid;
  deQuien uuid;
begin
  if new.documento is null then
    return new;
  end if;

  select inversionista into duenio  from public.consultas  where id = new.consulta;
  select inversionista into deQuien from public.documentos where id = new.documento;

  if deQuien is null or duenio is null or deQuien <> duenio then
    raise exception 'Ese documento no es de esta consulta.'
      using errcode = 'check_violation';
  end if;

  return new;
end
$con$;

drop trigger if exists consulta_mensajes_adjunto on public.consulta_mensajes;
create trigger consulta_mensajes_adjunto
  before insert on public.consulta_mensajes
  for each row execute function public.adjunto_de_la_misma_consulta();


-- ───────────────────────────────────────────────────────────────────────────
-- 4. QUIÉN LEE Y QUIÉN ESCRIBE
-- ───────────────────────────────────────────────────────────────────────────
alter table public.consultas         enable row level security;
alter table public.consulta_mensajes enable row level security;

-- LAS CONSULTAS ────────────────────────────────────────────────────────────
drop policy if exists "consultas: las mias" on public.consultas;
create policy "consultas: las mias" on public.consultas
  for select using (
    public.es_gestor() or inversionista = auth.uid()
  );

-- Abrir una es de cualquiera con sesión, y sólo a su nombre. El 'with check'
-- parece redundante con el disparador que ya pone auth.uid(); no lo es: el
-- disparador se salta cuando auth.uid() es null —la puerta de servicio— y la
-- política es la que se queda cerrada de todas formas.
drop policy if exists "consultas: abrir la mia" on public.consultas;
create policy "consultas: abrir la mia" on public.consultas
  for insert with check (
    inversionista = auth.uid()
  );

-- Cambiarla es del equipo: tomarla, ponerla en curso, cerrarla. El
-- inversionista no la cierra —cerrarla es decir «esto ya está contestado», y
-- eso lo dice quien contesta—; lo que puede hacer siempre es escribir otro
-- mensaje, que es lo que la reabre en la práctica.
drop policy if exists "consultas: las lleva el equipo" on public.consultas;
create policy "consultas: las lleva el equipo" on public.consultas
  for update using (public.es_gestor()) with check (public.es_gestor());

-- Nadie borra una consulta. La conversación con un inversionista es registro.
-- No hay política de delete, y sin política no se borra.

-- LOS MENSAJES ─────────────────────────────────────────────────────────────
drop policy if exists "consulta_mensajes: los de mi consulta" on public.consulta_mensajes;
create policy "consulta_mensajes: los de mi consulta" on public.consulta_mensajes
  for select using (
    public.es_gestor() or exists (
      select 1 from public.consultas c
      where c.id = consulta and c.inversionista = auth.uid()
    )
  );

drop policy if exists "consulta_mensajes: escribir en mi consulta" on public.consulta_mensajes;
-- En una consulta resuelta no escribe nadie: ni el inversionista ni el
-- equipo (Franklin Reyes, 5-10-2026, «al colocar una solicitud como resuelta
-- se bloquee el chat»). Reabrirla es cosa del equipo, con «Reabrir».
create policy "consulta_mensajes: escribir en mi consulta" on public.consulta_mensajes
  for insert with check (
    exists (
      select 1 from public.consultas c
       where c.id = consulta
         and c.estado <> 'resuelta'
         and (public.es_gestor() or c.inversionista = auth.uid())
    )
  );


-- ───────────────────────────────────────────────────────────────────────────
-- 5. CÓMO COMPROBAR QUE QUEDÓ BIEN
-- ───────────────────────────────────────────────────────────────────────────
-- Desde el SQL Editor NO sirve para probar las cerraduras: ahí auth.uid() es
-- null y la puerta de servicio está abierta a propósito. Estas dos sí valen
-- desde aquí, porque miran la forma y no el permiso:
--
--   1) Que las dos tablas están cerradas:
--
--      select relname, relrowsecurity
--        from pg_class
--       where relname in ('consultas','consulta_mensajes');
--      -- las dos tienen que decir 't'
--
--   2) Que ningún estado se coló:
--
--      select estado, count(*) from public.consultas group by estado;
--
-- Lo que hay que probar CON SESIÓN, y es lo que de verdad importa:
--
--   3) Que un inversionista no ve la consulta de otro. Entrando con la cuenta
--      de prueba A, 'select * from consultas' tiene que devolver sólo las
--      suyas —cero filas de B, no un error—.
--
--   4) Que no puede cerrarse una consulta él mismo: un update poniendo
--      estado='resuelta' tiene que no cambiar nada.
--
--   5) Que no puede abrir una a nombre de otro: un insert con
--      inversionista = <el id de B> tiene que ser rechazado.

-- ====================================================================
--  26 / 105   supabase-informe-victor.sql
-- ====================================================================

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
--    c1   visa_negocios           Visa de negocios (TR-N)        punto 1
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
-- 1.1 Y LAS FASES 4 Y 5 SE FUNDEN EN UNA
-- ───────────────────────────────────────────────────────────────────────
--  «4.4. Fases 4 y 5: Crecer e Invertir -> Expansión y Consolidación de
--   Inversión.»
--
--  El registro de la inversión extranjera tenía una etapa para él solo, con
--  una sola tarjeta dentro. Sigue siendo lo que separa a un inversionista
--  extranjero de cualquier comerciante local -sin él no hay por dónde sacar
--  ni las utilidades ni el capital- pero eso no pedía una fase entera.
--
--  El panel pasa de cinco etapas a cuatro, y esta línea es para que el
--  catálogo diga lo mismo que la pantalla. La restricción de la tabla sigue
--  admitiendo hasta 5 y se deja así: apretarla a 4 no gana nada y haría
--  fallar el archivo en cualquier base donde quede una fila con 5.
update public.tipos_tramite set fase = 4 where codigo = 'registro_inversion';


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
 where codigo in ('visa_negocios',      -- 1
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
--  Y el papel que se ENTREGA, que es otro: el documento del trámite que
--  se va a otorgar. El panel lo pedía con el tipo 'otro' -el cajón del
--  catálogo- y así la bóveda le colgaba encima el último papel suelto que
--  hubiera, con su ✓ de «ya lo tienes». Aquí eso no es un adorno: es el
--  papel que dice qué se va a firmar, y con el equivocado el portal
--  rechaza la solicitud entera. No vence: es el documento de una fecha.
--  Y el tercero, el PUB (22 de septiembre de 2026): la Planilla Única
--  Bancaria con la que el SAREN cobra. El portal la admite y no la
--  exige, y en el panel va igual, OPCIONAL: quien ya pagó la trae y se
--  ahorra una vuelta, y a quien viene a que el CIIP le diga cuánto
--  cuesta no se le puede pedir el comprobante de lo que aún no ha
--  pagado. Con tipo propio por lo mismo que el de arriba: en el cajón
--  'otro' la bóveda le cuelga encima cualquier papel suelto. Tampoco
--  vence: es el recibo de un pago con fecha.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('constancia_sisref',         'Constancia de firma en el Registro de Extranjeros (SISREF)', false),
  ('documento_tramite_sisref',  'Documento del trámite que se va a otorgar',                  false),
  ('pub_saren',                 'Planilla Única Bancaria (PUB) del pago al SAREN',            false)
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

-- ====================================================================
--  27 / 105   supabase-pliego.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  EL PLIEGO DE DATOS, Y QUIÉN LO ACEPTÓ
--  Va DESPUÉS de supabase-admin.sql y de supabase-gestor.sql.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Del punto 3 del informe del 2 de septiembre de 2026:
--
--    «Protocolo de Protección y Reserva de Datos (Habeas Data): siendo el
--     CIIP depositario de balances contables, composiciones accionarias y
--     transferencias de activos internacionales protegidos bajo el régimen
--     especial de la Ley Constitucional Antibloqueo, resulta mandatorio
--     redactar y vincular formalmente en la plataforma un pliego de
--     Términos, Condiciones y Políticas de Tratamiento de Datos Personales
--     y Confidenciales.»
--
--  LO QUE HABÍA, Y POR QUÉ NO BASTABA
--  ─────────────────────────────────────────────────────────────────────
--  La casilla existía desde el primer día, en acceso.html y en el login:
--
--    «Acepto el tratamiento de mis datos para la gestión de trámites.»
--
--  Y era una casilla, no un consentimiento. Tres agujeros, y ninguno se ve
--  mirando la pantalla:
--
--   1. NO ENLAZABA A NADA. Se aceptaba una frase de doce palabras; no había
--      documento que leer. Consentir requiere saber a qué.
--
--   2. NO QUEDABA REGISTRADO. Ni qué se aceptó, ni cuándo. A la pregunta
--      «¿este inversionista consintió el tratamiento de sus balances?» la
--      respuesta era «no se sabe», que es la peor de las tres posibles.
--
--   3. Y CASI NADIE LA VEÍA. El acceso del CIIP dejó de tener registro
--      propio: las cuentas las crea el equipo. Quien entra por ahí nunca
--      llegaba a marcar nada.
--
--  QUÉ HACE ESTE ARCHIVO, Y QUÉ NO
--  ─────────────────────────────────────────────────────────────────────
--  Hace la MAQUINARIA: versiones del pliego, constancia de quién aceptó
--  cuál y cuándo, y una función que dice si a alguien le falta aceptar.
--
--  NO trae el texto. La tabla nace VACÍA, igual que bancos_aliados y que
--  sectores, y por la misma razón llevada un paso más lejos: un pliego que
--  regula datos protegidos por la Ley Antibloqueo es un instrumento
--  jurídico, y uno redactado sin abogado que llegara a producción dejaría
--  al CIIP respaldado por un texto que no ha firmado nadie.
--
--  Hay un borrador en PLIEGO-BORRADOR.md para que el abogado del CIIP
--  corrija en vez de empezar en blanco. No es el pliego: es la materia
--  prima. Al final de este archivo está el INSERT para publicarlo cuando
--  esté aprobado.
--
--  Mientras la tabla esté vacía NO SE BLOQUEA A NADIE. Una puerta cerrada
--  con nada detrás deja fuera a todo el mundo, y eso ya estaba dicho en
--  supabase-sectores.sql antes de este informe.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────
do $$
begin
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'es_admin'
  ) then
    raise exception 'Falta public.es_admin(). Pasa antes supabase-admin.sql.';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LAS VERSIONES DEL PLIEGO
-- ───────────────────────────────────────────────────────────────────────
-- Versiones y no un texto suelto, y esa es toda la decisión de diseño.
--
-- El pliego va a cambiar: cambia la ley, cambia lo que la ventanilla
-- recoge, entra un organismo nuevo. Si hubiera un solo texto que se
-- reescribe, una aceptación de marzo pasaría a decir que se aceptó lo que
-- el pliego dice HOY, que es exactamente lo que un consentimiento no puede
-- hacer. Es el mismo criterio de ordenes_pago con el monto y de avisos con
-- el destinatario: se guarda lo que valía ENTONCES.

create table if not exists public.pliegos (
  version  integer primary key,
  titulo   text not null,

  -- El texto por idioma: {"es": "...", "en": "..."}.
  --
  -- El castellano es OBLIGATORIO y los demás no, y no es comodidad: el
  -- instrumento que obliga es el venezolano. Los otros idiomas son
  -- cortesía para que el inversionista entienda lo que firma, y la
  -- pantalla lo dice al pie. Un pliego que sólo existiera traducido
  -- dejaría sin saber cuál de las seis versiones es la que vale.
  texto    jsonb not null default '{}'::jsonb,

  vigente  boolean not null default false,

  publicado_en  timestamptz,
  publicado_por uuid references auth.users(id) on delete set null,
  creado_en     timestamptz not null default now(),

  constraint pliegos_texto_es_objeto check (jsonb_typeof(texto) = 'object'),
  -- Sin castellano no hay pliego. Ver arriba.
  constraint pliegos_con_castellano  check (texto ? 'es'),
  constraint pliegos_castellano_no_vacio
    check (length(trim(texto ->> 'es')) > 0),
  -- Uno vigente sin fecha de publicación es un pliego que nadie sabe desde
  -- cuándo obliga.
  constraint pliegos_vigente_con_fecha
    check (not vigente or publicado_en is not null)
);

comment on table  public.pliegos         is 'Las versiones del pliego de tratamiento de datos. Se añaden; no se reescriben';
comment on column public.pliegos.texto   is 'Por idioma. El castellano es el que obliga; los demás son cortesía';
comment on column public.pliegos.vigente is 'La que hay que aceptar hoy. Solo puede haber una';

-- UNA sola vigente. Con dos, la función de abajo devolvería una u otra
-- según le diera, y habría gente aceptando pliegos distintos el mismo día.
create unique index if not exists pliegos_uno_vigente
  on public.pliegos ((true)) where vigente;


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN ACEPTÓ QUÉ, Y CUÁNDO
-- ───────────────────────────────────────────────────────────────────────
-- Append-only, como la constancia de identidad y por lo mismo: un
-- consentimiento que quien lo pide puede reescribir después no prueba
-- nada. No hay política de update ni de delete, y además lo corta un
-- disparador por si mañana alguien añade una.

create table if not exists public.pliego_aceptaciones (
  id      bigint generated always as identity primary key,
  persona uuid    not null references auth.users(id) on delete cascade,
  version integer not null references public.pliegos(version),
  cuando  timestamptz not null default now(),

  -- Una vez por persona y versión. Volver a pulsar no escribe otra fila:
  -- la fecha que importa es la PRIMERA vez que se aceptó.
  constraint pliego_aceptaciones_una_vez unique (persona, version)
);

comment on table public.pliego_aceptaciones is
  'Constancia de que alguien aceptó una version concreta del pliego. Solo se inserta';

create index if not exists pliego_aceptaciones_por_persona
  on public.pliego_aceptaciones (persona, version);

-- La firma la pone la base, igual que en identidad_comprobaciones y en los
-- dos hilos: se ignora lo que venga y se escribe lo que es. Un
-- consentimiento que se puede atribuir a otro es peor que no tenerlo,
-- porque parece fiable.
create or replace function public.pliego_lo_firma_la_base()
returns trigger
language plpgsql
security definer
set search_path = public
as $pliego$
begin
  if auth.uid() is not null then
    new.persona := auth.uid();
    new.cuando  := now();
  end if;
  return new;
end
$pliego$;

drop trigger if exists pliego_aceptacion_firma on public.pliego_aceptaciones;
create trigger pliego_aceptacion_firma
  before insert on public.pliego_aceptaciones
  for each row execute function public.pliego_lo_firma_la_base();

create or replace function public.pliego_aceptacion_no_se_toca()
returns trigger
language plpgsql
as $pliego$
begin
  -- La puerta de servicio, como en las demás tablas: desde el SQL Editor
  -- se puede enderezar a mano lo que haga falta.
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  raise exception 'Un consentimiento no se cambia ni se borra.'
    using errcode = 'check_violation';
end
$pliego$;

drop trigger if exists pliego_aceptacion_inmutable on public.pliego_aceptaciones;
create trigger pliego_aceptacion_inmutable
  before update or delete on public.pliego_aceptaciones
  for each row execute function public.pliego_aceptacion_no_se_toca();


-- ───────────────────────────────────────────────────────────────────────
-- 3. ¿LE FALTA A ALGUIEN ACEPTAR?
-- ───────────────────────────────────────────────────────────────────────
-- Devuelve la versión vigente si quien pregunta no la ha aceptado, y null
-- si no hay nada que aceptar. Null significa las dos cosas —«ya aceptaste»
-- y «todavía no hay pliego»— y está bien que signifique las dos: en los
-- dos casos la respuesta del panel es la misma, dejar pasar.
--
-- Es la pieza que hace que la tabla vacía no bloquee a nadie.

create or replace function public.pliego_pendiente()
returns integer
language sql
stable
security definer
set search_path = public
as $pliego$
  select p.version
    from public.pliegos p
   where p.vigente
     and auth.uid() is not null
     and not exists (
       select 1 from public.pliego_aceptaciones a
        where a.persona = auth.uid() and a.version = p.version
     )
   limit 1;
$pliego$;

-- Y se le quita a anon POR SU NOMBRE.
--
-- Supabase tiene puesto un 'alter default privileges' que concede EXECUTE
-- sobre toda función nueva del esquema public a anon, authenticated y
-- service_role. Ese grant es NOMINAL a cada rol, así que revocárselo a
-- PUBLIC no se lo quita: anon se queda con el suyo. Se vio con
-- tocar_visto() al correr PROBAR-CERRADURAS.bat contra un Supabase de
-- verdad, y en un Postgres normal no pasa, así que ningún arnés local lo
-- veía.
--
-- Aquí anon no se llevaría gran cosa —con auth.uid() nulo devuelve null—
-- pero una puerta que acepta a quien no debería es una puerta abierta.
revoke all on function public.pliego_pendiente() from public;
revoke all on function public.pliego_pendiente() from anon;
grant execute on function public.pliego_pendiente() to authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- 4. QUIÉN LEE Y QUIÉN ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
alter table public.pliegos             enable row level security;
alter table public.pliego_aceptaciones enable row level security;

-- El pliego lo lee cualquiera que haya entrado, incluidas las versiones
-- viejas: quien aceptó la 1 tiene derecho a releer lo que aceptó, aunque
-- hoy rija la 3. Ese es medio habeas data.
drop policy if exists "pliegos: leerlos" on public.pliegos;
create policy "pliegos: leerlos" on public.pliegos
  for select to authenticated using (true);

-- Y solo el admin los publica. Ni el gestor: cambiar el pliego vigente es
-- cambiar a qué está consintiendo todo el mundo.
drop policy if exists "pliegos: solo el admin los publica" on public.pliegos;
create policy "pliegos: solo el admin los publica" on public.pliegos
  for all to authenticated
  using      (public.es_admin())
  with check (public.es_admin());

-- Cada quien ve lo que aceptó. El equipo también: atender un expediente
-- sin poder comprobar si esa persona consintió es atender a ciegas.
drop policy if exists "pliego: cada quien ve lo suyo" on public.pliego_aceptaciones;
create policy "pliego: cada quien ve lo suyo" on public.pliego_aceptaciones
  for select using (persona = auth.uid() or public.es_gestor());

-- Y solo se acepta lo VIGENTE, y solo por uno mismo. Sin lo primero se
-- podría aceptar una versión vieja y más floja que siguiera en la tabla;
-- sin lo segundo, aceptar en nombre de otro.
drop policy if exists "pliego: aceptar el propio" on public.pliego_aceptaciones;
create policy "pliego: aceptar el propio" on public.pliego_aceptaciones
  for insert with check (
    persona = auth.uid()
    -- pliego_aceptaciones.version, ENTERO y no «version» a secas.
    --
    -- Sin cualificar, dentro de la subconsulta «version» se resuelve a la
    -- columna de pliegos -que tambien se llama asi- y la condicion queda
    -- en p.version = p.version: cierta siempre. O sea que la politica
    -- decia comprobar que ESA version fuera la vigente y solo comprobaba
    -- que hubiera alguna vigente, que no es lo mismo.
    --
    -- Lo encontro el sabotaje: quitar esta linea entera no ponia ninguna
    -- prueba en rojo, porque no hacia nada.
    and exists (select 1 from public.pliegos p
                 where p.version = pliego_aceptaciones.version and p.vigente)
  );

-- No hay política de update ni de delete, a propósito. Ver el apartado 2.


-- ───────────────────────────────────────────────────────────────────────
-- 5. CÓMO SE PUBLICA EL PLIEGO CUANDO EL ABOGADO LO APRUEBE
-- ───────────────────────────────────────────────────────────────────────
--  ESTO NO SE EJECUTA SOLO. Está comentado a propósito: mientras nadie lo
--  descomente, la tabla sigue vacía y el panel no le pide nada a nadie.
--
--  El texto sale de PLIEGO-BORRADOR.md, con las correcciones del abogado.
--  Se pega tal cual entre las comillas dobles del jsonb, escapando sólo
--  las comillas dobles que lleve dentro.
--
--    insert into public.pliegos (version, titulo, texto, vigente, publicado_en)
--    values (
--      1,
--      'Términos, Condiciones y Políticas de Tratamiento de Datos',
--      jsonb_build_object('es', $texto$
--    ... aquí el pliego entero, tal como lo aprobó el abogado ...
--    $texto$),
--      true,
--      now()
--    );
--
--  El $texto$ ... $texto$ evita tener que escapar nada: se pega el
--  documento con sus comillas, sus tildes y sus saltos de línea.
--
--  PARA PUBLICAR UNA VERSIÓN NUEVA, más adelante: se apaga la vieja y se
--  inserta la nueva EN LA MISMA transacción, o el índice de arriba rechaza
--  la segunda por haber dos vigentes a la vez.
--
--    begin;
--      update public.pliegos set vigente = false where vigente;
--      insert into public.pliegos (version, titulo, texto, vigente, publicado_en)
--      values (2, '...', jsonb_build_object('es', $texto$...$texto$), true, now());
--    commit;
--
--  La versión vieja NO se borra: quien la aceptó tiene derecho a releerla,
--  y su constancia apunta a ella.
--
--  PARA AÑADIR UNA TRADUCCIÓN a una versión ya publicada —eso sí se puede,
--  porque no cambia lo que obliga—:
--
--    update public.pliegos
--       set texto = texto || jsonb_build_object('en', $texto$...$texto$)
--     where version = 1;


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE, DICHO PARA QUE NO SE DÉ POR HECHO
-- ───────────────────────────────────────────────────────────────────────
-- · No redacta el pliego. Ver la cabecera.
-- · No guarda la IP ni el navegador desde donde se aceptó. Se pensó y se
--   dejó fuera: es un dato personal más que habría que justificar en el
--   propio pliego, y para acreditar el consentimiento bastan quién, qué
--   versión y cuándo. Si el abogado lo pide, se añade.
-- · No borra los datos de nadie. El derecho de supresión que el pliego
--   reconozca se ejerce borrando la cuenta, que ya arrastra en cascada el
--   expediente entero y apunta sus archivos para el barrendero. Que eso
--   funcione ya está probado; que el pliego lo prometa es cosa del texto.
-- · Y la aceptación se va con la cuenta -on delete cascade-, como la
--   constancia de identidad. Es coherente con borrar de verdad cuando a
--   alguien se le borra: guardar la prueba de un consentimiento de quien
--   ya no está sería guardar justo lo que se dijo que se borraba.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Recién puesto esto, la tabla sale VACÍA y no es un fallo: el panel no
--    le pide nada a nadie hasta que haya un pliego aprobado.
--
--   select version, titulo, vigente, publicado_en from public.pliegos;
--
-- 2) Que no quepan dos vigentes. Con uno ya publicado, esto TIENE que
--    fallar; si te deja, el índice no está puesto:
--
--   insert into public.pliegos (version, titulo, texto, vigente, publicado_en)
--   values (99, 'prueba', '{"es":"x"}'::jsonb, true, now());
--
-- 3) Quién ha aceptado y qué versión:
--
--   select u.email, a.version, a.cuando
--   from public.pliego_aceptaciones a join auth.users u on u.id = a.persona
--   order by a.cuando desc;
--
-- 4) Y a quién le falta. Ojo: esta consulta es del EQUIPO y mira a todos;
--    la función pliego_pendiente() mira solo a quien pregunta.
--
--   select u.email
--   from auth.users u
--   where exists (select 1 from public.pliegos p where p.vigente)
--     and not exists (
--       select 1 from public.pliego_aceptaciones a
--        join public.pliegos p on p.version = a.version and p.vigente
--       where a.persona = u.id);
--
-- 5) Que no se pueda reescribir un consentimiento. Desde el SQL Editor SÍ
--    pasa —ahí auth.uid() es null y la puerta de servicio está abierta a
--    propósito—, así que esto se prueba con sesión, y es lo que hace
--    PROBAR-CERRADURAS.bat.

-- ====================================================================
--  28 / 105   supabase-disponibilidad.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL HORARIO DE CITAS DEL CIIP
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable: todo va con "if not exists", "create or replace" o
--  "drop ... if exists".
--
--  ORDEN: va DESPUÉS de supabase-citas.sql (añade una columna a citas) y
--  de supabase-tramites.sql, de donde sale public.es_gestor().
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ CAMBIA, Y POR QUÉ
--  ─────────────────────────────────────────────────────────────────────
--  supabase-citas.sql dejó escrito que aquí no habría agenda con huecos:
--  «publicar huecos que nadie mantiene es enseñar horas que no existen».
--  El 11 de septiembre de 2026 el CIIP decidió lo contrario: es el CIIP
--  quien pone los días en que hay citas, y el inversionista elige uno.
--
--  Lo que aquel comentario temía sigue siendo verdad, y por eso esto no es
--  solo una tabla de huecos:
--
--    · El horario es SEMANAL (lunes de 9 a 12, cada 30 minutos...). Se
--      mantiene solo: no hay que acordarse de publicar la semana que viene.
--    · Los días que no se atiende -feriados, vacaciones- se CIERRAN aparte.
--      Sin eso el horario enseñaría el 24 de diciembre como un lunes más.
--    · Un hueco reservado lo es para todos a la vez: un índice único impide
--      que dos personas se queden con el mismo, aunque pulsen en el mismo
--      segundo.
--    · Reservar lo hace la BASE, no el navegador: comprueba que el hueco
--      existe en el horario, que no está cerrado, que está libre y que es
--      futuro. Desde el navegador se podría mandar cualquier hora.
--
--  Y lo que NO cambia: una cita pedida a la antigua -una ventana de días,
--  y el CIIP pone la hora- sigue siendo válida. Mientras el CIIP no
--  publique horario, el panel pide así, como hasta ahora.
--
--  LA HORA ES LA DE VENEZUELA. El horario se escribe en hora de Caracas
--  (America/Caracas, UTC-4) y la cita se guarda como timestamptz: quien la
--  mire desde Italia la verá traducida a su hora, pero el hueco es el del
--  CIIP.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL HORARIO SEMANAL
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.horario_citas (
  id        uuid primary key default gen_random_uuid(),

  -- 1 = lunes ... 7 = domingo, como isodow de Postgres. Así el mismo
  -- número vale en la base y en la pantalla, sin traducir domingos.
  dia       smallint not null,
  desde     time not null,
  hasta     time not null,
  -- Cada cuántos minutos empieza un hueco. Un hueco de 30 minutos que
  -- empieza a las 11:45 no cabe en un tramo que acaba a las 12:00, y no se
  -- ofrece.
  cada_min  smallint not null default 30,

  creado_en timestamptz not null default now(),

  -- De lunes a viernes. El CIIP no atiende fines de semana, y un tramo en
  -- sabado seria un hueco que el panel ofreceria a los inversionistas sin
  -- que nadie lo hubiera decidido. La numeracion sigue siendo la de
  -- isodow -1 lunes, 7 domingo- para no traducir dias entre la base y la
  -- pantalla; lo que cambia es cuales valen.
  constraint horario_dia_valido   check (dia between 1 and 5),
  constraint horario_tramo_valido check (hasta > desde),
  constraint horario_cada_valido  check (cada_min between 10 and 240)
);

comment on table  public.horario_citas          is 'Cuándo atiende el CIIP, semana a semana. Lo edita el equipo desde el panel';
comment on column public.horario_citas.dia      is '1 lunes ... 5 viernes (isodow). Sin fines de semana';
comment on column public.horario_citas.desde    is 'Hora de Caracas en que empieza el tramo';
comment on column public.horario_citas.hasta    is 'Hora de Caracas en que acaba: el último hueco tiene que caber antes';
comment on column public.horario_citas.cada_min is 'Duración de cada hueco, en minutos';


-- ───────────────────────────────────────────────────────────────────────
-- 2. LOS DÍAS QUE NO SE ATIENDE
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.cierres_citas (
  fecha     date primary key,
  motivo    text not null default '',
  creado_en timestamptz not null default now(),

  constraint cierre_motivo_cabe check (length(motivo) <= 200),
  -- Cerrar un sabado no significa nada: ese dia ya no hay citas. Dejarlo
  -- pasar llena la lista de cierres de dias que nunca estuvieron abiertos,
  -- y al mirarla ya no se distingue el feriado de verdad.
  constraint cierre_dia_laborable check (extract(isodow from fecha) between 1 and 5)
);

comment on table public.cierres_citas is 'Días sin citas aunque el horario diga lo contrario: feriados, vacaciones';


-- ───────────────────────────────────────────────────────────────────────
-- 3. QUIÉN PUEDE QUÉ
-- ───────────────────────────────────────────────────────────────────────
-- Leerlos, cualquiera con sesión: el inversionista necesita el horario para
-- saber qué ofrecerse. Tocarlos, solo el equipo.
alter table public.horario_citas enable row level security;
alter table public.cierres_citas enable row level security;

drop policy if exists "horario: lo lee quien entra" on public.horario_citas;
create policy "horario: lo lee quien entra" on public.horario_citas
  for select using (auth.uid() is not null);

drop policy if exists "horario: lo edita el equipo" on public.horario_citas;
create policy "horario: lo edita el equipo" on public.horario_citas
  for all using (public.es_gestor()) with check (public.es_gestor());

drop policy if exists "cierres: los lee quien entra" on public.cierres_citas;
create policy "cierres: los lee quien entra" on public.cierres_citas
  for select using (auth.uid() is not null);

drop policy if exists "cierres: los edita el equipo" on public.cierres_citas;
create policy "cierres: los edita el equipo" on public.cierres_citas
  for all using (public.es_gestor()) with check (public.es_gestor());


-- ───────────────────────────────────────────────────────────────────────
-- 4. LA CITA RESERVADA DESDE EL HORARIO
-- ───────────────────────────────────────────────────────────────────────
-- hueco = true: nació de un hueco del horario, no de una petición. Es lo
-- que distingue las nuevas de las antiguas, y lo que acota el índice de
-- abajo: las citas confirmadas a mano antes de hoy pueden coincidir en la
-- hora -dos gestores, dos salas- y el índice no debe tropezar con ellas al
-- crearse, que haría fallar este archivo entero en la base real.
alter table public.citas add column if not exists hueco boolean not null default false;

comment on column public.citas.hueco is 'true = reservada desde el horario del CIIP; false = pedida con una ventana de días';

-- Un hueco, una cita. Solo cuentan las vivas: una cancelada lo libera.
create unique index if not exists citas_un_hueco_una_cita
  on public.citas (cuando)
  where hueco and estado in ('solicitada','confirmada');


-- ───────────────────────────────────────────────────────────────────────
-- 5. QUÉ HORAS ESTÁN YA TOMADAS
-- ───────────────────────────────────────────────────────────────────────
-- El inversionista solo ve SUS citas (RLS de citas), así que no puede saber
-- por su cuenta qué huecos están ocupados. Esto se lo dice sin decirle de
-- quién: solo la hora. security definer para poder mirar todas.
--
-- Cuentan todas las vivas con hora, también las confirmadas a mano: una
-- reunión ya puesta a las diez ocupa las diez aunque no naciera del horario.
create or replace function public.huecos_ocupados(p_desde date, p_hasta date)
returns table (cuando timestamptz)
language plpgsql
stable
security definer
set search_path = public
as $hue$
begin
  if auth.uid() is null then
    return;
  end if;
  -- Un rango sin tope es una forma de pedir el calendario entero del CIIP.
  if p_hasta < p_desde or p_hasta - p_desde > 92 then
    raise exception 'Rango de fechas no válido'
      using errcode = 'check_violation';
  end if;

  return query
    select c.cuando
      from public.citas c
     where c.estado in ('solicitada','confirmada')
       and c.cuando is not null
       and c.cuando >= (p_desde::timestamp at time zone 'America/Caracas')
       and c.cuando <  ((p_hasta + 1)::timestamp at time zone 'America/Caracas')
     order by c.cuando;
end
$hue$;

revoke all on function public.huecos_ocupados(date, date) from public;
grant execute on function public.huecos_ocupados(date, date) to authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- 6. RESERVAR UN HUECO
-- ───────────────────────────────────────────────────────────────────────
-- La única puerta para una cita que nace confirmada. La política de citas
-- sigue exigiendo 'solicitada' y sin hora a quien inserte desde el
-- navegador -y hace bien-; esto entra por detrás, pero solo después de
-- comprobar todo lo que un navegador podría inventarse.
create or replace function public.reserva_cita(
  p_cuando timestamptz,
  p_modo   text,
  p_tipo   text default null,
  p_nota   text default ''
)
returns public.citas
language plpgsql
security definer
set search_path = public
as $res$
declare
  yo     uuid := auth.uid();
  local  timestamp;
  dia_l  date;
  hora_l time;
  fila   public.citas;
begin
  if yo is null then
    raise exception 'Hace falta haber entrado para reservar'
      using errcode = 'insufficient_privilege';
  end if;

  if p_modo is null or p_modo not in ('presencial','video','telefono') then
    raise exception 'Modo de cita no válido'
      using errcode = 'check_violation';
  end if;

  if length(coalesce(p_nota, '')) > 500 then
    raise exception 'La nota es demasiado larga'
      using errcode = 'check_violation';
  end if;

  if p_cuando is null or p_cuando <= now() then
    raise exception 'Ese hueco ya pasó'
      using errcode = 'check_violation';
  end if;

  if p_cuando > now() + interval '92 days' then
    raise exception 'Ese hueco está demasiado lejos'
      using errcode = 'check_violation';
  end if;

  local  := p_cuando at time zone 'America/Caracas';
  dia_l  := local::date;
  hora_l := local::time;

  if exists (select 1 from public.cierres_citas where fecha = dia_l) then
    raise exception 'Ese día el CIIP no atiende'
      using errcode = 'check_violation';
  end if;

  -- El hueco tiene que ESTAR en el horario: el día de la semana, dentro del
  -- tramo, cabiendo entero antes de que acabe y en punto con su intervalo.
  if not exists (
    select 1
      from public.horario_citas h
     where h.dia = extract(isodow from local)::int
       and hora_l >= h.desde
       and hora_l + make_interval(mins => h.cada_min) <= h.hasta
       and (extract(epoch from (hora_l - h.desde))::int % (h.cada_min * 60)) = 0
  ) then
    raise exception 'Ese hueco no está en el horario del CIIP'
      using errcode = 'check_violation';
  end if;

  -- Una cita viva por persona, como ya hace la pantalla: con una en marcha
  -- no se ofrece el formulario. Aquí se asegura también por detrás.
  if exists (
    select 1 from public.citas
     where inversionista = yo and estado in ('solicitada','confirmada')
  ) then
    raise exception 'Ya tienes una cita en marcha'
      using errcode = 'check_violation';
  end if;

  -- Libre de verdad, contando también las confirmadas a mano a esa hora.
  if exists (
    select 1 from public.citas
     where cuando = p_cuando and estado in ('solicitada','confirmada')
  ) then
    raise exception 'Ese hueco se acaba de ocupar'
      using errcode = 'unique_violation';
  end if;

  insert into public.citas
    (inversionista, tipo_tramite, modo, desde, hasta, nota, estado, cuando, hueco)
  values
    (yo, nullif(p_tipo, ''), p_modo, dia_l, dia_l, coalesce(trim(p_nota), ''),
     'confirmada', p_cuando, true)
  returning * into fila;

  return fila;

-- Dos que pulsan en el mismo segundo pasan las dos el "libre de verdad" de
-- arriba; el índice único deja entrar a uno y aquí el otro recibe la misma
-- frase que si hubiera llegado tarde.
exception when unique_violation then
  raise exception 'Ese hueco se acaba de ocupar'
    using errcode = 'unique_violation';
end
$res$;

revoke all on function public.reserva_cita(timestamptz, text, text, text) from public;
grant execute on function public.reserva_cita(timestamptz, text, text, text) to authenticated;

-- ───────────────────────────────────────────────────────────────────────
-- SIN FINES DE SEMANA, TAMBIEN EN UNA BASE QUE YA TENIA LAS TABLAS
-- ───────────────────────────────────────────────────────────────────────
-- Arriba la regla va dentro del create table, y eso solo sirve en una base
-- nueva: si la tabla ya existe, «create table if not exists» no la toca.
-- Asi que aqui se pone otra vez, por su nombre, para que tambien la tenga
-- la base donde este archivo ya se habia pasado.
--
-- Si hay tramos o cierres en fin de semana, se para y lo dice. No se
-- borran solos: son datos que alguien escribio, y decidir tirarlos no le
-- toca a un archivo de SQL.
do $$
begin
  if exists (select 1 from public.horario_citas where dia > 5) then
    raise exception using message =
      'Hay tramos en sabado o domingo en horario_citas. El CIIP no atiende ' ||
      'fines de semana: borralos desde el panel y vuelve a pasar este archivo.';
  end if;
  if exists (select 1 from public.cierres_citas
             where extract(isodow from fecha) > 5) then
    raise exception using message =
      'Hay dias cerrados que caen en sabado o domingo en cierres_citas. ' ||
      'Esos dias ya no tenian citas: borralos y vuelve a pasar este archivo.';
  end if;
end $$;

alter table public.horario_citas drop constraint if exists horario_dia_valido;
alter table public.horario_citas add  constraint horario_dia_valido
  check (dia between 1 and 5);

alter table public.cierres_citas drop constraint if exists cierre_dia_laborable;
alter table public.cierres_citas add  constraint cierre_dia_laborable
  check (extract(isodow from fecha) between 1 and 5);

-- ====================================================================
--  29 / 105   supabase-textos.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  LOS TEXTOS DEL PANEL, EDITABLES POR EL ADMINISTRADOR
-- ═══════════════════════════════════════════════════════════════════════
--  «quiero tener la opcion de como administrador poder editar titulos de la
--   pagina y de los que dicen las fichas» (Franklin Reyes, 14 de septiembre
--   de 2026).
--
--  Los textos del panel viven en el diccionario del propio HTML, en seis
--  idiomas, y cambiar uno era cambiar el archivo y volver a publicarlo. Esta
--  tabla guarda SOLO lo que el administrador ha cambiado: una fila por texto
--  y por idioma. Lo que no esté aquí lo sigue poniendo el diccionario, así
--  que la tabla vacía deja el panel exactamente como estaba.
--
--  Por idioma, y no un texto para todos: cambiar el español no toca las
--  otras cinco traducciones. Lo decidió Franklin el mismo día: «Edita cada
--  idioma».
--
--  QUÉ ES LA CLAVE
--  La misma que usa el panel, sin inventar otra:
--    · las del diccionario, con punto:     'c33.name', 'tsec.title'
--    · las de pasos.js, sin punto:          'lh_uno'
--    · las del organismo de cada tarjeta:   'c33.sigla', 'c33.ente'
--  El panel decide a cuál de los tres corresponde. La base no lo valida
--  contra el diccionario porque el diccionario no está en la base: una clave
--  que ya no exista simplemente no se pinta en ningún sitio.
--
--  Mismo patrón que acompanamiento.textos, pero en filas y no en un jsonb:
--  aquí hay cientos de textos posibles, y una fila por texto deja ver quién
--  cambió cuál y cuándo.
--
--  Depende de: supabase-setup.sql (perfiles) y supabase-admin.sql (es_admin).
-- ═══════════════════════════════════════════════════════════════════════

do $$
begin
  if to_regprocedure('public.es_admin()') is null then
    raise exception 'Falta public.es_admin(): corre antes supabase-admin.sql';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA TABLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.textos_panel (
  clave           text        not null,
  idioma          text        not null,
  texto           text        not null,
  actualizado_en  timestamptz not null default now(),
  actualizado_por uuid references auth.users(id) on delete set null,

  primary key (clave, idioma),
  -- Los ocho idiomas del panel, ni uno más: un 'ES' o un 'spa' guardaría
  -- una fila que no se pinta nunca y nadie sabría por qué.
  constraint textos_panel_idioma_valido check (idioma in ('es', 'en', 'pt', 'it', 'zh', 'ru', 'fr', 'ja')),
  -- Una clave con forma de clave: letras, números, punto, guion y guion
  -- bajo. Así no cabe un texto pegado por error en el sitio de la clave.
  constraint textos_panel_clave_valida  check (clave ~ '^[A-Za-z0-9_.-]{1,80}$'),
  -- Un texto vacío no es «sin texto»: es un hueco en la pantalla. Para
  -- volver al original se BORRA la fila, que es lo que hace el panel.
  constraint textos_panel_texto_lleno   check (length(btrim(texto)) > 0),
  -- Tope generoso: la descripción más larga del diccionario ronda las
  -- doscientas letras. Mil deja sitio de sobra y corta un pegado accidental.
  constraint textos_panel_texto_tope    check (length(texto) <= 1000)
);

comment on table  public.textos_panel        is 'Textos del panel cambiados por el administrador, por idioma. Lo que falte lo pone el diccionario';
comment on column public.textos_panel.clave  is 'La clave del panel: la del diccionario (c33.name), la de pasos.js (lh_uno) o la del organismo (c33.ente)';
comment on column public.textos_panel.idioma is 'es, en, pt, it, zh, ru, fr o ja';

alter table public.textos_panel enable row level security;

-- Leer: cualquiera con sesión. El inversionista ve los textos cambiados, así
-- que tiene que poder leerlos.
drop policy if exists "textos_panel: lo lee cualquiera" on public.textos_panel;
create policy "textos_panel: lo lee cualquiera" on public.textos_panel
  for select to authenticated using (true);

-- Escribir: solo el admin. Insertar y cambiar (el panel hace upsert) y
-- borrar (volver al original).
drop policy if exists "textos_panel: el admin lo escribe" on public.textos_panel;
create policy "textos_panel: el admin lo escribe" on public.textos_panel
  for insert to authenticated
  with check (public.es_admin());

drop policy if exists "textos_panel: el admin lo cambia" on public.textos_panel;
create policy "textos_panel: el admin lo cambia" on public.textos_panel
  for update to authenticated
  using      (public.es_admin())
  with check (public.es_admin());

drop policy if exists "textos_panel: el admin lo borra" on public.textos_panel;
create policy "textos_panel: el admin lo borra" on public.textos_panel
  for delete to authenticated
  using (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN LO TOCÓ
-- ───────────────────────────────────────────────────────────────────────
-- Lo escribe un disparador, como en acompanamiento: un campo que rellena
-- quien escribe es un campo que quien escribe puede mentir.
create or replace function public.marca_textos_panel()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.actualizado_por := auth.uid();
  new.actualizado_en  := now();
  return new;
end $$;

drop trigger if exists textos_panel_quien on public.textos_panel;
create trigger textos_panel_quien
  before insert or update on public.textos_panel
  for each row execute function public.marca_textos_panel();


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE
-- ───────────────────────────────────────────────────────────────────────
-- · No entra en la bitácora. Quién cambió cada texto por última vez queda
--   en su propia fila, igual que en acompanamiento.
-- · No toca tipos_tramite.nombre. Ese nombre es el de la pantalla de
--   Catálogo y del filtro; el que ve el inversionista en la tarjeta sale
--   del diccionario, y es el que se cambia aquí.
-- · No guarda el texto original. El original está en el HTML; borrar la
--   fila es volver a él.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. Las cuatro políticas: leer, escribir, cambiar y borrar.
select policyname, cmd from pg_policies
where  schemaname = 'public' and tablename = 'textos_panel'
order  by cmd;

-- 2. Lo que hay cambiado, por idioma.
select idioma, count(*) from public.textos_panel group by idioma order by idioma;

-- ====================================================================
--  30 / 105   supabase-bitacora-ajustes.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA BITÁCORA, CON LO QUE VINO DESPUÉS
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: el ÚLTIMO. Se engancha a tablas que crean archivos posteriores a
--  supabase-bitacora.sql: bloqueo (13), acompañamiento (14), plazos (21),
--  disponibilidad (28) y textos (29). Si en la base falta alguna de esas
--  tablas no se cae: se salta ese disparador y lo dice al final. Pasado el
--  archivo que falte, se vuelve a correr este.
-- ═══════════════════════════════════════════════════════════════════════
--
--  QUÉ ARREGLA
--  ─────────────────────────────────────────────────────────────────────
--  La bitácora se hizo cuando el panel solo tocaba cuatro cosas: el
--  interruptor del catálogo, los roles, los papeles y las citas. Luego
--  llegaron el plazo de cada ficha, bloquear cuentas, los activos, el
--  horario de citas, el acompañamiento y «Editar textos», y ninguno dejaba
--  apunte. Trazabilidad seguía enseñando lo de hace cinco días como si
--  desde entonces nadie hubiera tocado nada.
--
--  Dónde sale cada uno en la pantalla:
--    · el plazo de una ficha          → Catálogo
--    · bloquear y desbloquear         → Roles (es quién puede qué)
--    · el horario y los días cerrados → Citas
--    · textos, activos, acompañamiento → una ficha nueva cada uno
--
--  Y UN AGUJERO QUE SE CIERRA DE PASO
--  ─────────────────────────────────────────────────────────────────────
--  supabase-bitacora.sql promete que nadie puede escribir en la bitácora.
--  Pero apunta() es security definer y no llevaba revoke, y Supabase da
--  EXECUTE sobre toda función nueva a anon y a authenticated. Desde el
--  navegador, sb.rpc('apunta', ...) escribía el apunte que uno quisiera.
--  Los disparadores la siguen llamando: corren como su dueño, que conserva
--  el permiso.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 0. QUE ESTÉ LO QUE HACE FALTA
-- ───────────────────────────────────────────────────────────────────────
do $$
begin
  if to_regclass('public.bitacora') is null then
    raise exception 'Falta la tabla bitacora. Pasa antes supabase-bitacora.sql.';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LAS FUENTES NUEVAS, Y NADIE MÁS ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
alter table public.bitacora drop constraint if exists bitacora_fuente_valida;
alter table public.bitacora add constraint bitacora_fuente_valida
  check (fuente in ('catalogo','roles','papeles','citas',
                    'textos','activos','acompanamiento'));

revoke execute on function public.apunta(text, text, text, text)
  from public, anon, authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LAS FUNCIONES
-- ───────────────────────────────────────────────────────────────────────
-- Se crean aunque falte su tabla: plpgsql no mira las columnas hasta que
-- corre. Lo que depende de la tabla es el disparador, más abajo.

-- El plazo. Solo cuando CAMBIA: guardar el mismo número no es un apunte.
-- 'detalle' vacío es quitar el plazo.
create or replace function public.bit_catalogo_plazo()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.plazo_dias is distinct from old.plazo_dias then
    perform public.apunta('catalogo', 'plazo', new.nombre,
                          coalesce(new.plazo_dias::text, ''));
  end if;
  return null;
end $$;

create or replace function public.bit_bloqueo()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.bloqueado is distinct from old.bloqueado then
    perform public.apunta('roles',
      case when new.bloqueado then 'bloqueo' else 'desbloqueo' end,
      new.nombre_completo);
  end if;
  return null;
end $$;

-- Un activo. Guardar la ficha sin tocar nada no es editarla: se compara la
-- fila entera menos la marca de tiempo, que la pone otro disparador.
create or replace function public.bit_activos()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.apunta('activos', 'creo', new.titulo, new.estado);
  elsif tg_op = 'DELETE' then
    perform public.apunta('activos', 'borro', old.titulo, old.estado);
  elsif (to_jsonb(new) - 'actualizado_en') is distinct from
        (to_jsonb(old) - 'actualizado_en') then
    perform public.apunta('activos', 'edito', new.titulo, new.estado);
  end if;
  return null;
end $$;

-- Un tramo del horario. 'sobre' lleva las horas y 'detalle' el día en
-- número (1 lunes): el nombre del día lo pone la pantalla en su idioma.
create or replace function public.bit_horario()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.apunta('citas', 'puso_tramo',
      to_char(new.desde, 'HH24:MI') || '-' || to_char(new.hasta, 'HH24:MI'), new.dia::text);
  else
    perform public.apunta('citas', 'quito_tramo',
      to_char(old.desde, 'HH24:MI') || '-' || to_char(old.hasta, 'HH24:MI'), old.dia::text);
  end if;
  return null;
end $$;

-- Un día cerrado. La fecha va como 2026-12-24, y la pantalla la escribe.
create or replace function public.bit_cierres()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    perform public.apunta('citas', 'cerro_dia', new.fecha::text, new.motivo);
  else
    perform public.apunta('citas', 'abrio_dia', old.fecha::text, old.motivo);
  end if;
  return null;
end $$;

-- Los textos. Se guarda el TEXTO y no la clave: «c33.name» no le dice nada
-- a quien lee la bitácora, y el texto sí. Al volver al original se apunta
-- el texto que se quitó, que es lo único que ya no está en ningún sitio.
create or replace function public.bit_textos()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    perform public.apunta('textos', 'original', left(old.texto, 160), old.idioma);
  elsif tg_op = 'INSERT' or new.texto is distinct from old.texto then
    perform public.apunta('textos', 'cambio', left(new.texto, 160), new.idioma);
  end if;
  return null;
end $$;

create or replace function public.bit_acompanamiento()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (to_jsonb(new) - 'actualizado_en' - 'actualizado_por') is distinct from
     (to_jsonb(old) - 'actualizado_en' - 'actualizado_por') then
    perform public.apunta('acompanamiento', 'ajusto', '', '');
  end if;
  return null;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. LOS DISPARADORES, SOLO DONDE HAY TABLA
-- ───────────────────────────────────────────────────────────────────────
do $$
declare
  d record;
begin
  for d in
    select * from (values
      ('bitacora_catalogo_plazo', 'tipos_tramite',  'plazo_dias', 'after update of plazo_dias',          'bit_catalogo_plazo'),
      ('bitacora_bloqueo',        'perfiles',       'bloqueado',  'after update of bloqueado',           'bit_bloqueo'),
      ('bitacora_activos',        'activos',        null,         'after insert or update or delete',    'bit_activos'),
      ('bitacora_horario',        'horario_citas',  null,         'after insert or delete',              'bit_horario'),
      ('bitacora_cierres',        'cierres_citas',  null,         'after insert or delete',              'bit_cierres'),
      ('bitacora_textos',         'textos_panel',   null,         'after insert or update or delete',    'bit_textos'),
      ('bitacora_acompanamiento', 'acompanamiento', null,         'after update',                        'bit_acompanamiento')
    ) as t(disparador, tabla, columna, cuando, funcion)
  loop
    if to_regclass('public.' || d.tabla) is null
       or (d.columna is not null and not exists (
             select 1 from information_schema.columns
             where table_schema = 'public' and table_name = d.tabla and column_name = d.columna))
    then
      raise notice 'Sin %: falta public.%', d.disparador,
        d.tabla || case when d.columna is null then '' else '.' || d.columna end;
      continue;
    end if;
    execute format('drop trigger if exists %I on public.%I', d.disparador, d.tabla);
    execute format('create trigger %I %s on public.%I for each row execute function public.%I()',
                   d.disparador, d.cuando, d.tabla, d.funcion);
  end loop;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE
-- ───────────────────────────────────────────────────────────────────────
-- · Lo de antes de correrlo sigue sin estar. Un plazo cambiado ayer no
--   aparece: la bitácora empieza a contar lo nuevo desde hoy.
-- · No apunta lo que hace el inversionista con lo suyo (su empresa, sus
--   consultas). Esto es el registro de lo que hace el equipo.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. Doce disparadores 'bitacora_%': los cinco de antes y los siete de
--    ahora. Si falta alguno de los nuevos, falta su tabla: ver arriba.
select tgrelid::regclass as tabla, tgname as disparador
from   pg_trigger
where  not tgisinternal
  and  tgname like 'bitacora_%'
order  by tabla, disparador;

-- 2. apunta() cerrada. Las dos columnas tienen que salir en false.
select has_function_privilege('anon', 'public.apunta(text,text,text,text)', 'execute')          as anon_puede,
       has_function_privilege('authenticated', 'public.apunta(text,text,text,text)', 'execute') as con_sesion_puede;

-- ====================================================================
--  31 / 105   supabase-zodi.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA OPINIÓN FAVORABLE DE LA ZODI (c34)
--  Va DESPUÉS de supabase-informe-victor.sql: usa las columnas `nivel`
--  (de aquel) y `emite` (de supabase-encadenado.sql).
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  De un mensaje de Milagros Torres (Tecnología), del 15 de septiembre de
--  2026: para constituir en Venezuela con accionistas que son empresas
--  extranjeras, la Zona Operativa de Defensa Integral de la región tiene
--  que dar su opinión favorable -o «no objeción»- ANTES del Registro
--  Mercantil, cuando la empresa se instala en zona fronteriza o de
--  seguridad, o su actividad toca la seguridad y la defensa.
--
--  No estaba: ni en tipos_tramite ni en pasos.js. Y pasa lo mismo que con
--  el SISREF (c32): sin él, el panel deja llegar al Registro Mercantil y
--  es allí donde se descubre que falta un papel de otro organismo.
--
--  POR QUÉ 'actividad' Y NO 'obligatorio'
--  ─────────────────────────────────────────────────────────────────────
--  El propio mensaje lo dice condicionado: «especialmente si la empresa
--  operará en zonas fronterizas, áreas estratégicas o sectores
--  regulados». A una tienda en Caracas no le toca. 'actividad' es lo que
--  el catálogo ya usa para «puede que a ti no te toque»: la tarjeta se
--  queda a la vista en la fase 2 -lo de 'actividad' no se aparta nunca- y
--  no se cuenta entre los obligatorios.
--
--  Y por lo mismo el c22 la pide como recaudo OPCIONAL: a quien le toca,
--  la protocolización le recuerda el papel; a quien no, no le cierra el
--  paso. Eso vive en el panel, en RECAUDOS.
--
--  ENCADENADO
--  ─────────────────────────────────────────────────────────────────────
--  EMITE la opinión favorable, que el c22 pide. Y PIDE el proyecto del
--  acta, que sale del c5, y el poder, que sale del c33: la cadena
--  c5 → c34 → c22 se deduce sola de los recaudos, sin escribirla.
--
--  LO QUE ESTÁ POR CONFIRMAR CON EL CIIP, Y POR ESO NO ESTÁ
--  ─────────────────────────────────────────────────────────────────────
--  1. EN QUÉ CASOS TOCA. Qué zonas y qué sectores. Mientras no se sepa, el
--     formulario deja elegir «No lo sé: que lo revise el CIIP».
--  2. EL PLAZO. El mensaje no da ninguno y aquí no se inventa: plazo_dias
--     se queda en null, como los ocho que no prometen ninguno. Sin plazo,
--     el panel no marca nunca la solicitud como tardía.
--  3. LA BASE LEGAL. El mensaje cita una «Ley Orgánica de las Zonas
--     Fronterizas» que no aparece con ese nombre; lo más cercano son la
--     Ley Orgánica de Fronteras y las zonas de seguridad de la Ley
--     Orgánica de Seguridad de la Nación. Ninguna de las dos se cita en
--     la ficha hasta que el CIIP lo diga.
--  4. SI CADUCA LA OPINIÓN. No se sabe, así que vence = false.
--
--  Si alguien corre supabase-tramites.sql SOLO, después de este, el c34
--  se apaga: aquel deja encendidos exactamente los de su lista. Es lo
--  mismo que le pasa al c32 y al c33. TODO-EN-ORDEN.sql lo corre detrás y
--  lo vuelve a encender.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LOS PAPELES NUEVOS
-- ───────────────────────────────────────────────────────────────────────
--  Tres son la cadena corporativa: sin ellos no se puede demostrar quién
--  está detrás de una empresa accionista extranjera. El cuarto es lo que
--  sale del trámite.
--
--  Que caduque o no sigue el criterio del resto del catálogo: caduca lo
--  que acredita una situación VIGENTE -el certificado de existencia legal,
--  como una solvencia- y no lo que acredita un hecho de una fecha -los
--  estatutos, la lista firmada-.
--  Y el PROYECTO del acta es un tipo propio, no el acta. El panel lo pedía
--  con 'acta_constitutiva' -lo que emite el c5- y por ahí la bóveda le
--  colgaba el acta ya registrada con su ✓ de «ya lo tienes». Es imposible
--  por fechas: esta opinión va ANTES del Registro Mercantil, así que
--  cuando se pide, el acta registrada no existe; si existe, es de otra
--  empresa. No vence: es el borrador de una fecha.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('proyecto_acta',         'Proyecto del documento constitutivo',                                      false),
  ('estatutos_accionista',  'Documento constitutivo y estatutos de la empresa accionista y de su matriz', false),
  ('good_standing',         'Certificado de existencia legal (Good Standing)',                         true),
  ('beneficiarios_finales', 'Lista de accionistas y directores hasta los beneficiarios finales',         false),
  ('no_objecion_zodi',      'Opinión favorable (no objeción) de la ZODI',                                false)
on conflict (codigo) do update set nombre = excluded.nombre;

--  La lista de Franklin del 23-9-2026: los directores van aparte de los
--  accionistas, y se piden la identidad de los socios y la matriz.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('identidad_accionistas', 'Cédula o pasaporte de los accionistas de la empresa a constituir',          false),
  ('juridico_matriz',       'Información jurídica de la empresa matriz',                                 false),
  ('directores_accionista', 'Lista de directores del accionista jurídico, con copia de sus pasaportes',  false),
  ('beneficiarios_finales', 'Lista de accionistas hasta el beneficiario final, con copia de sus pasaportes', false)
on conflict (codigo) do update set nombre = excluded.nombre;


-- ───────────────────────────────────────────────────────────────────────
-- 2. EL TRÁMITE
-- ───────────────────────────────────────────────────────────────────────
--  Fase 2, entre la constitución (c5) y la protocolización (c22): necesita
--  el proyecto del acta y tiene que estar antes de protocolizar.
--
--  El ente va como 'ZODI' y no con la región: hay una por región, y cuál
--  es lo dice el estado que se escribe en el formulario.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('opinion_zodi', 'c34', 'Opinión favorable de la ZODI', 'ZODI', 2, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite      = 'no_objecion_zodi',
       plazo_dias = null,
       nivel      = 'actividad',
       activo     = true
 where codigo = 'opinion_zodi';


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Una fila: c34 · ZODI · fase 2 · actividad · emite la no objeción ·
--    sin plazo · encendido.
--
--   select ref_panel, codigo, nombre, ente, fase, nivel, emite, plazo_dias, activo
--   from public.tipos_tramite where ref_panel = 'c34';
--
-- 2) Los cinco papeles nuevos:
--
--   select codigo, nombre, vence from public.tipos_documento
--   where codigo in ('proyecto_acta','estatutos_accionista','good_standing',
--                    'beneficiarios_finales','no_objecion_zodi');
--
-- 3) Los obligatorios siguen siendo DIEZ, cinco y cinco: el c34 no suma.
--
--   select fase, count(*) from public.tipos_tramite
--   where nivel = 'obligatorio' group by fase;

-- ====================================================================
--  32 / 105   supabase-rupdae-rum.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL RUPDAE (c35) Y EL REGISTRO ÚNICO MINERO (c36)
--  Va DESPUÉS de supabase-informe-victor.sql: usa las columnas `nivel`
--  (de aquel) y `emite` (de supabase-encadenado.sql).
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Del encargo del 15 de septiembre de 2026: incorporar a «Habilitación
--  operativa y cumplimiento» (la fase 3) el RUPDAE ante la SUNDDE y el
--  Registro Único Minero. Ninguno de los dos estaba.
--
--  EL RUPDAE (c35)
--  ─────────────────────────────────────────────────────────────────────
--  · Ley Orgánica de Precios Justos, Decreto 2.092, G.O. 6.202 Ext. del
--    8-11-2015, artículos 18 a 20: toda persona que fabrica, importa,
--    distribuye, comercializa o presta servicios se inscribe, y la
--    inscripción es «requisito indispensable» para operar. El artículo 46.4
--    sanciona no inscribirse con multa de 500 a 10.000 UT o cierre de 48 h.
--  · Se hace en línea, en rupdae.sundde.gob.ve. La SUNDDE da de cinco a
--    diez días hábiles para revisarlo: plazo_dias = 14.
--  · El certificado NO caduca desde el 2 de septiembre de 2026 (Ley de
--    Celeridad de Trámites, G.O. 7.018): sólo se actualiza si cambian la
--    razón social, la directiva o el domicilio fiscal. Por eso vence = false.
--    OJO: eso sale de prensa regional; falta verlo en la web de la SUNDDE.
--
--  POR QUÉ 'esencial' Y NO 'obligatorio'
--  La ley se lo pide a todas las empresas, así que por fondo sería
--  obligatorio. Pero los obligatorios son los diez del informe del 2 de
--  septiembre -cinco y cinco- y el número lo decidió el CIIP. 'esencial' es
--  el caso corriente: le toca a todos, no lleva distintivo y no se aparta.
--  Si el CIIP lo quiere obligatorio es cambiar esta palabra, y la prueba de
--  los diez obligatorios avisará.
--
--  EL REGISTRO ÚNICO MINERO (c36)
--  ─────────────────────────────────────────────────────────────────────
--  · Resolución 0010 del Ministerio de Desarrollo Minero Ecológico, G.O.
--    41.396 del 14-05-2018 (deroga la 0009 de marzo). Obligatorio para
--    quien ejerza o pretenda ejercer actividades primarias, conexas o
--    auxiliares a la minería, y requisito para cualquier trámite ante el
--    ministerio: autorizaciones, alianzas, empresas mixtas, contratos.
--  · Se hace en el SIGDME 2.0 (sigdme2-0.desarrollominero.gob.ve). Los
--    recaudos salen de su formulario de alta para «empresa conformada»:
--    cédula, RIF y acta constitutiva, y el acta de asamblea como opcional.
--  · El certificado electrónico dura TRES años (artículo 3): vence = true.
--  · 'actividad': sólo le toca al sector minero.
--  · Sin plazo: la resolución no da ninguno y aquí no se inventa.
--
--  LO QUE ESTÁ POR CONFIRMAR CON EL CIIP, Y POR ESO ESTÁ DICHO AQUÍ
--  ─────────────────────────────────────────────────────────────────────
--  1. El nivel del RUPDAE: 'esencial' u 'obligatorio' (ver arriba).
--  2. Si la patente municipal (c10) es recaudo del RUPDAE: la lista de la
--     SUNDDE de 2022 la pedía y el formulario de registro de hoy no.
--  3. El RUM para una empresa TODAVÍA NO CONSTITUIDA. El SIGDME la acepta
--     con el proyecto del acta y una carta explicativa, y ofrece una
--     «autorización del SAREN»: parece que para minería el ministerio va
--     antes del Registro Mercantil, como la ZODI. Aquí sólo está el caso de
--     la empresa ya constituida, que es el de la fase 3.
--  4. Qué pide el SIGDME DENTRO, después de crear la cuenta: sólo se ha
--     visto el formulario de alta.
--
--  Si alguien corre supabase-tramites.sql SOLO, después de este, el c35 y
--  el c36 se apagan: aquel deja encendidos exactamente los de su lista. Es
--  lo mismo que le pasa al c32, al c33 y al c34. TODO-EN-ORDEN.sql lo corre
--  detrás y los vuelve a encender.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LOS PAPELES NUEVOS
-- ───────────────────────────────────────────────────────────────────────
--  Sólo lo que sale de cada trámite: lo que piden -acta, RIF, cédula- ya
--  estaba en la bóveda.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('certificado_rupdae', 'Certificado de inscripción en el RUPDAE',          false),
  ('certificado_rum',    'Certificado electrónico del Registro Único Minero', true)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LOS TRÁMITES
-- ───────────────────────────────────────────────────────────────────────
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('rupdae',          'c35', 'Inscripción en el RUPDAE',     'SUNDDE',                           3, true),
  ('registro_minero', 'c36', 'Registro Único Minero (RUM)',  'Ministerio de Desarrollo Minero',  3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite      = 'certificado_rupdae',
       plazo_dias = 14,
       nivel      = 'esencial',
       activo     = true
 where codigo = 'rupdae';

update public.tipos_tramite
   set emite      = 'certificado_rum',
       plazo_dias = null,
       nivel      = 'actividad',
       activo     = true
 where codigo = 'registro_minero';


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Dos filas: c35 · SUNDDE · fase 3 · esencial · 14 días, y c36 ·
--    ministerio · fase 3 · actividad · sin plazo. Las dos encendidas.
--
--   select ref_panel, codigo, nombre, ente, fase, nivel, emite, plazo_dias, activo
--   from public.tipos_tramite where ref_panel in ('c35','c36');
--
-- 2) Los dos papeles nuevos, y sólo el del RUM caduca:
--
--   select codigo, nombre, vence from public.tipos_documento
--   where codigo in ('certificado_rupdae','certificado_rum');
--
-- 3) Los obligatorios siguen siendo DIEZ, cinco y cinco: ninguno suma.
--
--   select fase, count(*) from public.tipos_tramite
--   where nivel = 'obligatorio' group by fase;

-- ====================================================================
--  33 / 105   supabase-junta.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS PAPELES DE LA JUNTA DIRECTIVA (c5)
--  Va DESPUÉS de supabase-tramites.sql: toca documentos y tipos_documento.
--  No usa nada de los demás, así que va al final para no mover el número
--  de ninguno.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 16 de septiembre de 2026: en la constitución de la
--  compañía, por cada miembro de la junta directiva que se registre, su
--  cédula o pasaporte y su RIF. Y además la certificación de inventario por
--  contador público, si aplica.
--
--  POR QUÉ UNA COLUMNA NUEVA, Y NO SÓLO DOS TIPOS
--  ───────────────────────────────────────────────────────────────────────
--  La bóveda guardaba un papel por TIPO: para reutilizarlo, el panel pide
--  «el más reciente de este tipo» y se queda con uno. Con cinco miembros de
--  la junta serían cinco cédulas del mismo tipo, y el panel enseñaría la
--  última a los cinco -y en el siguiente trámite ofrecería reutilizar la de
--  otra persona-. `titular` dice de quién es cada una.
--
--  NO TOCA LOS PERMISOS
--  ───────────────────────────────────────────────────────────────────────
--  Las políticas de documentos dicen «el papel es tuyo» -inversionista =
--  auth.uid()- sin enumerar columnas: la nueva queda cubierta tal cual. Un
--  papel de un miembro de tu junta lo subes TÚ y es TUYO; lo que dice el
--  titular es de quién es la cara que sale en él.
--
--  LA CERTIFICACIÓN DE INVENTARIO
--  ───────────────────────────────────────────────────────────────────────
--  El comprobante del capital ya decía «depósito o inventario»: eran
--  alternativas en un solo recaudo. Se pidió aparte y OPCIONAL, y convive
--  con él. El panel la pide en la hoja de recaudos del c5.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE
--  ───────────────────────────────────────────────────────────────────────
--  Todo lo que ya existe sigue igual. Lo único que no se puede es enviar
--  una constitución con miembros de la junta -sus papeles llevan titular- o
--  con la certificación de inventario.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. DE QUIÉN ES CADA PAPEL
-- ───────────────────────────────────────────────────────────────────────
--  Null para todo lo que ya está guardado: sigue siendo de quien lo subió,
--  como hasta hoy. Sólo lo lleva un papel que es de OTRA persona -un
--  miembro de la junta directiva-, y entonces lleva su nombre.
alter table public.documentos add column if not exists titular text;

comment on column public.documentos.titular is
  'De quién es el papel cuando no es del dueño de la cuenta (un miembro de la junta directiva). Null: de quien lo subió.';

--  Un nombre en blanco no es un titular: sería un papel de nadie, y en el
--  visor del equipo saldría como si fuera tuyo.
do $junta$
begin
  if not exists (select 1 from pg_constraint where conname = 'documentos_titular_no_vacio') then
    alter table public.documentos add constraint documentos_titular_no_vacio
      check (titular is null or length(btrim(titular)) > 0);
  end if;
end
$junta$;

--  La bóveda busca «el más reciente de este tipo» para reutilizarlo. Con
--  titular, busca «de este tipo y de esta persona».
create index if not exists documentos_por_titular
  on public.documentos (inversionista, tipo, titular);


-- ───────────────────────────────────────────────────────────────────────
-- 2. LOS PAPELES NUEVOS
-- ───────────────────────────────────────────────────────────────────────
--  Ninguno caduca en el catálogo. La cédula y el RIF de un miembro van en
--  UN solo papel, y cada uno vence en su fecha: pedir una sola fecha de
--  vencimiento para los dos no diría nada cierto. La certificación de
--  inventario acredita un hecho de una fecha, como el comprobante del
--  capital.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('cedula_rif_junta',         'Cédula o pasaporte y RIF de un miembro de la junta directiva', false),
  ('certificacion_inventario', 'Certificación de inventario por contador público',            false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

--  16-9-2026, el mismo día: la cédula y el RIF de cada miembro pasan a ser
--  DOS papeles, y no uno con los dos dentro. Se piden, se revisan y caducan
--  cada uno por su lado. El tipo de arriba, cedula_rif_junta, ya no lo usa
--  el panel y se queda: puede que alguien subiera algo con él, y
--  documentos.tipo apunta aquí.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('cedula_pasaporte_junta', 'Cédula o pasaporte de un miembro de la junta directiva', false),
  ('rif_junta',              'RIF de un miembro de la junta directiva',               false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) La columna existe y admite vacío (lo guardado antes no tiene titular):
--
--   select column_name, is_nullable from information_schema.columns
--   where table_schema = 'public' and table_name = 'documentos'
--     and column_name = 'titular';
--
-- 2) Los dos papeles nuevos, ninguno caduca:
--
--   select codigo, nombre, vence from public.tipos_documento
--   where codigo in ('cedula_pasaporte_junta', 'rif_junta', 'certificacion_inventario');
--
-- 3) Nada de lo guardado cambió de dueño: tiene que salir 0.
--
--   select count(*) from public.documentos where titular is not null;

-- ====================================================================
--  34 / 105   supabase-textos-rastro.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — QUIÉN CAMBIÓ QUÉ TEXTO, Y QUÉ DECÍA ANTES
--  Va DESPUÉS de supabase-textos.sql y de supabase-bitacora.sql. No mueve
--  el número de nadie: va al final.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 16 de septiembre de 2026, al pedir que el editor llegue
--  a todos los textos de la página: «y que en trazabilidad salga quien los
--  haya editado».
--
--  Quién ya salía: la bitácora apunta auth.uid() en cada cambio. Lo que no
--  salía era QUÉ texto -solo el nuevo y el idioma-, así que en Trazabilidad
--  se leía «cambió un texto (ES): Guardar» sin saber de qué pantalla era ni
--  qué ponía antes. Esto guarda la clave y lo de antes.
--
--  NO TOCA PERMISOS NI BORRA NADA. Los apuntes viejos se siguen leyendo.
-- ═══════════════════════════════════════════════════════════════════════


do $comprueba$
begin
  if to_regclass('public.textos_panel') is null then
    raise exception 'Falta la tabla textos_panel: corre antes supabase-textos.sql';
  end if;
end
$comprueba$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LO QUE DECÍA ANTES, AL LADO DEL CAMBIO
-- ───────────────────────────────────────────────────────────────────────
--  El texto original está en el panel -en su diccionario-, no en la base,
--  así que la base no podía decir qué se cambió. El panel lo manda al
--  guardar. Null en lo guardado antes de esto: de eso no se sabe.
alter table public.textos_panel add column if not exists original text;

comment on column public.textos_panel.original is
  'Lo que decía el texto antes del primer cambio, en ese idioma. Lo manda el panel; la bitácora lo apunta.';

do $tope$
begin
  if not exists (select 1 from pg_constraint where conname = 'textos_panel_original_tope') then
    alter table public.textos_panel add constraint textos_panel_original_tope
      check (original is null or length(original) <= 1000);
  end if;
end
$tope$;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LA BITÁCORA APUNTA QUÉ TEXTO ERA
-- ───────────────────────────────────────────────────────────────────────
--  Antes guardaba el texto nuevo y el idioma, y en Trazabilidad salía
--  «cambió un texto» sin decir cuál. Ahora el detalle es un JSON con el
--  idioma, la CLAVE y lo que decía ANTES; y «sobre» sigue siendo lo que
--  dice después. Los apuntes viejos -solo el idioma- se siguen leyendo.
--
--    · cambiar por primera vez   antes = el original que manda el panel
--    · volver a cambiarlo        antes = el cambio anterior
--    · volver al original        antes = el cambio; sobre = el original
create or replace function public.bit_textos()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    perform public.apunta('textos', 'original', left(coalesce(old.original, ''), 160),
      json_build_object('idioma', old.idioma, 'clave', old.clave,
                        'antes', left(old.texto, 160))::text);
  elsif tg_op = 'INSERT' then
    perform public.apunta('textos', 'cambio', left(new.texto, 160),
      json_build_object('idioma', new.idioma, 'clave', new.clave,
                        'antes', left(coalesce(new.original, ''), 160))::text);
  elsif new.texto is distinct from old.texto then
    perform public.apunta('textos', 'cambio', left(new.texto, 160),
      json_build_object('idioma', new.idioma, 'clave', new.clave,
                        'antes', left(old.texto, 160))::text);
  end if;
  return null;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. EL DISPARADOR, Y QUE LA BITÁCORA ADMITA LOS TEXTOS
-- ───────────────────────────────────────────────────────────────────────
--  Lo pone también supabase-bitacora-ajustes.sql; se repite aquí para que
--  este archivo baste solo. Y con cuidado con la regla de las fuentes: si
--  no admitiera 'textos', cada guardado del editor fallaría ENTERO -el
--  disparador corre dentro del mismo guardado-.
--
--  Sin bitácora no se cae: los textos se siguen guardando, sin apunte.
do $bitacora$
begin
  if to_regclass('public.bitacora') is null
     or to_regprocedure('public.apunta(text, text, text, text)') is null then
    raise notice 'Sin bitácora: los textos se guardan pero no se apuntan. Corre supabase-bitacora.sql y vuelve a pasar este.';
    return;
  end if;

  if not exists (select 1 from pg_constraint
                  where conname = 'bitacora_fuente_valida'
                    and pg_get_constraintdef(oid) like '%textos%') then
    alter table public.bitacora drop constraint if exists bitacora_fuente_valida;
    alter table public.bitacora add constraint bitacora_fuente_valida
      check (fuente in ('catalogo','roles','papeles','citas',
                        'textos','activos','acompanamiento'));
  end if;

  drop trigger if exists bitacora_textos on public.textos_panel;
  create trigger bitacora_textos
    after insert or update or delete on public.textos_panel
    for each row execute function public.bit_textos();
end
$bitacora$;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) La columna nueva:
--
--   select column_name from information_schema.columns
--   where table_schema = 'public' and table_name = 'textos_panel'
--     and column_name = 'original';
--
-- 2) El disparador puesto (una fila):
--
--   select tgname from pg_trigger where tgname = 'bitacora_textos';
--
-- 3) Cambia un texto desde el panel y mira el último apunte: el detalle
--    tiene que traer la clave y lo que decía antes.
--
--   select cuando, sobre, detalle from public.bitacora
--   where fuente = 'textos' order by id desc limit 3;

-- ====================================================================
--  35 / 105   supabase-revision-papeles.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA REVISIÓN DE LOS DOCUMENTOS
--  Va DESPUÉS de supabase-tramites.sql y de supabase-bitacora.sql. No mueve
--  el número de nadie: va al final.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 16 de septiembre de 2026: «¿cómo sería la opción para
--  que el CIIP pueda confirmar que el documento está bien?». Se eligió,
--  sobre una maqueta, una bandeja del equipo -«Documentos por revisar»- con
--  todos los papeles pendientes, y una columna en Documentos que le dice al
--  inversionista en qué punto está cada uno.
--
--  Para revisar no hacía falta nada: documentos ya tenía estado,
--  nota_revision y revisado_por, y es_gestor() ya deja cambiarlos. Esto
--  añade CUÁNDO, y que la bitácora apunte quién validó o rechazó.
--
--  NO TOCA PERMISOS NI BORRA NADA.
-- ═══════════════════════════════════════════════════════════════════════


do $comprueba$
begin
  if to_regclass('public.documentos') is null then
    raise exception 'Falta la tabla documentos: corre antes supabase-tramites.sql';
  end if;
end
$comprueba$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. CUÁNDO SE REVISÓ
-- ───────────────────────────────────────────────────────────────────────
--  Para poder decir «validado el 16 de septiembre». actualizado_en no
--  sirve: cambia con cualquier retoque del papel, no solo con la revisión.
--  Null en lo revisado antes de esto.
alter table public.documentos add column if not exists revisado_en timestamptz;

comment on column public.documentos.revisado_en is
  'Cuándo lo validó o rechazó el equipo del CIIP. Lo pone el panel al revisar.';


-- ───────────────────────────────────────────────────────────────────────
-- 2. LA BITÁCORA APUNTA CADA REVISIÓN
-- ───────────────────────────────────────────────────────────────────────
--  Hasta ahora apuntaba subir y borrar un papel, pero no validarlo ni
--  rechazarlo: en Trazabilidad no se sabía quién había dado un papel por
--  bueno. Solo cuando CAMBIA el estado a validado o rechazado.
--
--    sobre    el nombre del archivo, congelado
--    detalle  JSON con el tipo de papel, DE QUIÉN es y el motivo del rechazo
--
--  «De quién» se congela con el nombre de hoy: si mañana cambia su perfil,
--  el apunte sigue diciendo de quién era cuando se revisó.
create or replace function public.bit_papeles_revision()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  dueno text;
begin
  if new.estado is not distinct from old.estado
     or new.estado not in ('validado', 'rechazado') then
    return null;
  end if;
  select nombre_completo into dueno from public.perfiles where id = new.inversionista;
  perform public.apunta('papeles',
    case when new.estado = 'validado' then 'valido' else 'rechazo' end,
    new.nombre_original,
    json_build_object('tipo', new.tipo,
                      'de', coalesce(dueno, ''),
                      'motivo', case when new.estado = 'rechazado'
                                     then left(coalesce(new.nota_revision, ''), 200)
                                     else '' end)::text);
  return null;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. EL DISPARADOR
-- ───────────────────────────────────────────────────────────────────────
--  Sin bitácora no se cae: los papeles se revisan igual, sin apunte.
do $bitacora$
begin
  if to_regclass('public.bitacora') is null
     or to_regprocedure('public.apunta(text, text, text, text)') is null then
    raise notice 'Sin bitácora: los papeles se revisan pero no se apuntan. Corre supabase-bitacora.sql y vuelve a pasar este.';
    return;
  end if;
  drop trigger if exists bitacora_papeles_revision on public.documentos;
  create trigger bitacora_papeles_revision
    after update of estado on public.documentos
    for each row execute function public.bit_papeles_revision();
end
$bitacora$;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) La columna nueva:
--
--   select column_name from information_schema.columns
--   where table_schema = 'public' and table_name = 'documentos'
--     and column_name = 'revisado_en';
--
-- 2) El disparador puesto (una fila):
--
--   select tgname from pg_trigger where tgname = 'bitacora_papeles_revision';
--
-- 3) Valida o rechaza un papel desde «Documentos por revisar» y mira el
--    último apunte:
--
--   select cuando, accion, sobre, detalle from public.bitacora
--   where fuente = 'papeles' order by id desc limit 3;

-- ====================================================================
--  36 / 105   supabase-accionista-juridica.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA ACCIONISTA JURÍDICA (c5)
--  Va DESPUÉS de supabase-tramites.sql: solo toca tipos_documento. Va al
--  final para no mover el número de nadie.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 16 de septiembre de 2026: en la constitución, la opción
--  «Accionista jurídica», para cuando uno de los accionistas de la empresa
--  a constituir es a su vez otra empresa. Si se marca, se piden de esa
--  empresa su documento constitutivo con la última acta de asamblea, y el
--  documento de identidad de sus accionistas.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: solo no se puede enviar una
--  constitución con la casilla marcada, porque sus dos papeles no caben
--  en documentos.tipo.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- LOS DOS PAPELES DE LA EMPRESA ACCIONISTA
-- ───────────────────────────────────────────────────────────────────────
--  Tipos PROPIOS y no los de la ficha de la ZODI (estatutos_accionista…):
--  aquellos son de una empresa extranjera -estatutos de la matriz, Good
--  Standing- y estos de cualquier empresa accionista. Con el mismo tipo, la
--  bóveda daría el uno por el otro. Ninguno caduca: acreditan un hecho de
--  una fecha, como el acta constitutiva.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('constitutivo_accionista',     'Documento constitutivo y última acta de asamblea de la empresa accionista', false),
  ('identidad_socios_accionista', 'Documento de identidad de los accionistas de la empresa accionista',        false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN: dos filas, las dos con vence = false.
-- ───────────────────────────────────────────────────────────────────────
--   select codigo, nombre, vence from public.tipos_documento
--   where codigo in ('constitutivo_accionista', 'identidad_socios_accionista');

-- ====================================================================
--  37 / 105   supabase-reserva-nombre.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL COMPROBANTE DE LA RESERVA DEL NOMBRE (c5)
--  Va DESPUÉS de supabase-tramites.sql: toca tipos_documento y tres
--  políticas. Va al final para no mover el número de nadie.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 16 de septiembre de 2026: la constitución de la
--  compañía gana un paso entre «Reserva de nombre» y «Resuelta», donde va
--  el comprobante de la reserva del nombre.
--
--  CÓMO ES EL CIRCUITO (Franklin Reyes, 18 de septiembre de 2026)
--  ───────────────────────────────────────────────────────────────────────
--  El CIIP manda al inversionista el documento con los datos para pagar,
--  el inversionista paga, y DESPUÉS sube el comprobante. Así que el papel
--  llega tarde por definición, y no puede cerrarle el paso a nadie: el
--  trigger que impedía resolver sin él estuvo puesto dos días y se quitó
--  (apartado 3).
--
--  Y de paso lo mismo para el pago de los aranceles de la protocolización
--  (c22): ese papel se sube desde su paso, con el trámite ya en marcha, y
--  hasta hoy la base solo dejaba adjuntar a una solicitud en borrador o
--  devuelta.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE, pero el paso se queda cojo: el
--  inversionista ve el botón de subir y la subida falla al engancharla.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL PAPEL
-- ───────────────────────────────────────────────────────────────────────
--  No caduca: acredita que el nombre quedó reservado en una fecha, como el
--  acta constitutiva acredita un acto. El pago de aranceles ya existe en el
--  catálogo (supabase-tramites.sql) y no se toca.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('reserva_nombre',          'Comprobante de la reserva del nombre',       false),
  ('planilla_reserva_nombre', 'Documento para pagar la reserva del nombre', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. ADJUNTARLO CON EL TRÁMITE EN MARCHA
-- ───────────────────────────────────────────────────────────────────────
--  «adjuntos: adjuntar a lo propio» deja adjuntar solo a una solicitud en
--  borrador o devuelta, y está bien: lo que se envió no se toca por debajo.
--  Estos dos papeles son la excepción porque NO EXISTEN cuando se envía:
--  el comprobante de la reserva sale cuando el nombre se reserva, y el del
--  pago cuando se paga.
--
--  Se abre lo justo, y por eso va en su propia política en vez de ensanchar
--  la de arriba: cada papel, solo en SU trámite y solo en los estados en
--  los que el paso se ofrece. Las políticas se suman: basta con que una
--  deje pasar la fila.
drop policy if exists "adjuntos: papeles de un paso, con el tramite en marcha" on public.tramite_documentos;
create policy "adjuntos: papeles de un paso, con el tramite en marcha" on public.tramite_documentos
  for insert with check (
    exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and t.inversionista = auth.uid()
         and d.inversionista = auth.uid()
         and (
              (t.tipo = 'constitucion'         and d.tipo = 'reserva_nombre'
                                               and t.estado = 'ante_el_ente')
           or (t.tipo = 'protocolizacion_acta' and d.tipo = 'pago_aranceles'
                                               and t.estado in ('enviado','en_revision','ante_el_ente'))
           --  Y LA PUBLICACIÓN, QUE FALTABA (23 de septiembre de 2026).
           --  El tramo de la publicación nace 'enviado' -lo abre la base al
           --  resolverse la protocolización- y su comprobante se sube desde
           --  ese paso, con el trámite ya en marcha. Ninguna política lo
           --  cubría: ni ésta, que nombraba dos casos, ni la general, que
           --  solo deja adjuntar en 'borrador' y 'devuelto'.
           --
           --  Sin error. El insert cambiaba CERO filas y PostgREST contesta
           --  que sí, así que el inversionista veía su comprobante subido y
           --  al volver ya no estaba. Y detrás quedaba el cepo:
           --  tramites_publicacion_con_pago no deja resolver la publicación
           --  sin ese papel, de modo que el trámite no lo podía cerrar
           --  nadie, ni él ni el CIIP.
           or (t.tipo = 'publicacion_acta'     and d.tipo = 'pago_publicacion'
                                               and t.estado in ('enviado','en_revision','ante_el_ente'))
         )
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- 2b. EL EQUIPO DEJA EL DOCUMENTO PARA PAGARLA
-- ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 17 de septiembre de 2026, por la tarde: el CIIP no
--  sube el comprobante de la reserva. Envía un documento para que el
--  inversionista pague, y el comprobante lo sube él. Subido, el requisito
--  queda cumplido.
--
--  Por la mañana esta sección dejaba al equipo subir el propio comprobante
--  (reserva_nombre). Esas dos políticas se quitan: con ellas puestas el
--  equipo podría seguir haciéndolo desde fuera de la pantalla.
drop policy if exists "documentos: el equipo sube la reserva del nombre" on public.documentos;
drop policy if exists "adjuntos: el equipo engancha la reserva del nombre" on public.tramite_documentos;

--  «documentos: el equipo entrega lo emitido» (supabase-emision.sql) solo
--  deja al gestor dejar papeles de tipo 'resolucion'. Se abre este otro al
--  lado, con su propia política, y con el mismo cerrojo que aquella: entra
--  'validado', que es lo que impide al inversionista borrarlo sin querer.
--  El archivo va a la carpeta 'emitidos', que el cubo ya le deja al equipo.
drop policy if exists "documentos: el equipo sube el documento para pagar la reserva" on public.documentos;
create policy "documentos: el equipo sube el documento para pagar la reserva" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_reserva_nombre' and estado = 'validado');

--  Y engancharlo: solo a una constitución, y solo ante el ente, que es
--  cuando el paso se ofrece. El papel tiene que ser de la bóveda del mismo
--  inversionista del trámite, para no colgarle a alguien el de otro.
drop policy if exists "adjuntos: el equipo engancha el documento para pagar la reserva" on public.tramite_documentos;
create policy "adjuntos: el equipo engancha el documento para pagar la reserva" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_reserva_nombre'
         and t.tipo = 'constitucion'
         and t.estado = 'ante_el_ente'
    )
  );

-- ───────────────────────────────────────────────────────────────────────
-- 3. AQUÍ HUBO UN CANDADO, Y SE QUITÓ
-- ───────────────────────────────────────────────────────────────────────
--  El 16 de septiembre esto era «sin comprobante no hay resuelta»: un
--  trigger que impedía marcar resuelta una constitución sin el comprobante
--  de la reserva del nombre.
--
--  Se quita el 18 de septiembre de 2026, con el circuito ya contado por el
--  CIIP: el equipo manda al inversionista el documento con los datos para
--  pagar, el inversionista paga, y SÓLO DESPUÉS sube el comprobante. Entre
--  una cosa y otra pasan días que no dependen del CIIP, y el candado dejaba
--  la constitución parada sin que nadie del equipo pudiera destrabarla.
--
--  El paso NO desaparece: sigue en la escalera del inversionista, con su
--  casilla para subir el comprobante, y las políticas de arriba siguen
--  dejando que lo adjunte con el trámite en marcha. Lo único que se va es
--  el cierre a quien todavía no tiene el papel en la mano.
--
--  Se borra aquí, y no en un archivo nuevo, para que una base que ya lo
--  tenía puesto se quede sin él al volver a pasar este archivo.
drop trigger if exists tramites_reserva_nombre on public.tramites;
drop function if exists public.tramites_constitucion_con_reserva();


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--   select codigo, nombre, vence from public.tipos_documento
--    where codigo in ('reserva_nombre', 'planilla_reserva_nombre');  -- dos filas
--
--   select polname from pg_policy
--    where polname in ('adjuntos: papeles de un paso, con el tramite en marcha',
--                      'documentos: el equipo sube el documento para pagar la reserva',
--                      'adjuntos: el equipo engancha el documento para pagar la reserva');
--                                                          -- tres filas
--
--   select polname from pg_policy
--    where polname in ('documentos: el equipo sube la reserva del nombre',
--                      'adjuntos: el equipo engancha la reserva del nombre');
--                                                          -- ninguna
--
--   select tgname from pg_trigger where tgname = 'tramites_reserva_nombre';
--                                                          -- NINGUNA fila

-- ====================================================================
--  38 / 105   supabase-logos-fichas.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL LOGO DE CADA FICHA, DESDE EL PANEL
--  Va DESPUÉS de supabase-catalogos.sql (el admin ya puede escribir en
--  tipos_tramite) y de supabase-bitacora.sql (apunta()). Va al final para
--  no mover el número de nadie.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 17 de septiembre de 2026: que el administrador pueda
--  cambiar o poner el logo de las fichas del catálogo sin tocar el código.
--  Hasta hoy el icono iba escrito a mano en el HTML de cada tarjeta.
--
--  CÓMO QUEDA
--  ───────────────────────────────────────────────────────────────────────
--  · tipos_tramite.logo guarda la RUTA dentro del cubo 'logos-fichas'.
--    null = la ficha enseña el icono de siempre, el del código. Así quitar
--    un logo subido es volver atrás, no quedarse sin nada.
--  · El cubo es PÚBLICO de lectura: un logo no es un dato de nadie, lo ve
--    cualquiera que abra la portada, y una URL pública se cachea. Escribir
--    y borrar, solo el admin.
--  · Sin SVG, por lo mismo que en 'recaudos': un SVG puede llevar script.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: las fichas siguen con sus iconos
--  de siempre y la pantalla del catálogo no enseña el mando del logo.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA COLUMNA
-- ───────────────────────────────────────────────────────────────────────
alter table public.tipos_tramite
  add column if not exists logo text;

comment on column public.tipos_tramite.logo is
  'Ruta del logo subido por el admin en el cubo logos-fichas. null = el icono de siempre';


-- ───────────────────────────────────────────────────────────────────────
-- 2. EL CUBO
-- ───────────────────────────────────────────────────────────────────────
-- 1 MB sobra para un logo de 48 px de ancho, y deja fuera la foto de 8 MB
-- que alguien sube sin mirar.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('logos-fichas', 'logos-fichas', true, 1048576,
        array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update set
  public             = excluded.public,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

-- La lectura de un cubo público por su URL no pasa por estas políticas;
-- esta hace falta para que el admin pueda BORRAR, que Storage consulta la
-- fila antes de quitarla.
drop policy if exists "logos-fichas: se leen" on storage.objects;
create policy "logos-fichas: se leen" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'logos-fichas');

drop policy if exists "logos-fichas: el admin sube" on storage.objects;
create policy "logos-fichas: el admin sube" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'logos-fichas' and public.es_admin());

drop policy if exists "logos-fichas: el admin reemplaza" on storage.objects;
create policy "logos-fichas: el admin reemplaza" on storage.objects
  for update to authenticated
  using      (bucket_id = 'logos-fichas' and public.es_admin())
  with check (bucket_id = 'logos-fichas' and public.es_admin());

drop policy if exists "logos-fichas: el admin borra" on storage.objects;
create policy "logos-fichas: el admin borra" on storage.objects
  for delete to authenticated
  using (bucket_id = 'logos-fichas' and public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA BITÁCORA
-- ───────────────────────────────────────────────────────────────────────
-- Solo cuando CAMBIA. 'detalle' vacío es volver al icono de siempre.
create or replace function public.bit_catalogo_logo()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.logo is distinct from old.logo then
    perform public.apunta('catalogo', 'logo', new.nombre, coalesce(new.logo, ''));
  end if;
  return null;
end $$;

revoke execute on function public.bit_catalogo_logo() from public, anon, authenticated;

drop trigger if exists bitacora_catalogo_logo on public.tipos_tramite;
create trigger bitacora_catalogo_logo
  after update of logo on public.tipos_tramite
  for each row execute function public.bit_catalogo_logo();

-- ====================================================================
--  39 / 105   supabase-protocolizacion.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA PROTOCOLIZACIÓN NACE SOLA (c5 → c22)
--  Va DESPUÉS de supabase-reserva-nombre.sql: repite su patrón un piso
--  más abajo y usa sus mismas tablas.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 17 de septiembre de 2026: «al finalizar la fase de
--  constitución de la empresa, automáticamente se inicia esta solicitud,
--  porque hay que aplicar el mismo paso que la de arriba: el CIIP envía lo
--  que el inversionista debe pagar y después el inversionista sube el
--  comprobante».
--
--  Así que son tres cosas:
--
--   1. Resuelta la constitución, la protocolización del acta se crea sola,
--      ya enviada, con lo que la constitución ya decía.
--   2. El equipo deja en ella el DOCUMENTO PARA PAGAR los aranceles del
--      registro, igual que deja el de la reserva del nombre.
--   3. Sin el comprobante de ese pago, la protocolización no se resuelve.
--
--  Lo que este archivo NO toca: qué fichas se pueden pedir y cuáles no.
--  Se quedan como están, todas abiertas, por decisión suya del mismo día.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: la protocolización sigue naciendo
--  a mano —el inversionista la crea al subir su comprobante, como hasta
--  hoy— y la casilla del equipo falla al enganchar el documento.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL PAPEL QUE DEJA EL EQUIPO
-- ───────────────────────────────────────────────────────────────────────
--  No caduca: es la orden de pago de un expediente concreto, no una
--  constancia con fecha de vencimiento. El comprobante del pago
--  ('pago_aranceles') ya existe en supabase-tramites.sql y no se toca.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_aranceles', 'PUB para pagar los aranceles del registro', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. EL EQUIPO DEJA EL DOCUMENTO PARA PAGAR
-- ───────────────────────────────────────────────────────────────────────
--  Las dos políticas gemelas de las de la reserva del nombre. Entra
--  'validado', que es lo que impide al inversionista borrarlo sin querer,
--  y el archivo va a la carpeta 'emitidos', que el cubo ya le deja al
--  equipo.
drop policy if exists "documentos: el equipo sube el documento para pagar los aranceles" on public.documentos;
create policy "documentos: el equipo sube el documento para pagar los aranceles" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_aranceles' and estado = 'validado');

--  Y engancharlo: solo a una protocolización, y solo mientras está en
--  marcha, que es cuando el paso del pago se ofrece. El papel tiene que
--  ser de la bóveda del mismo inversionista del trámite, para no colgarle
--  a alguien el de otro.
drop policy if exists "adjuntos: el equipo engancha el documento para pagar los aranceles" on public.tramite_documentos;
create policy "adjuntos: el equipo engancha el documento para pagar los aranceles" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_aranceles'
         and t.tipo = 'protocolizacion_acta'
         and t.estado in ('enviado','en_revision','ante_el_ente')
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- 3. RESUELTA LA CONSTITUCIÓN, NACE LA PROTOCOLIZACIÓN
-- ───────────────────────────────────────────────────────────────────────
--  Aquí y no en el panel: el trámite tiene que nacer lo resuelva quien lo
--  resuelva y desde donde lo resuelva —la cola, «Lo que toca hoy» o este
--  mismo editor—. En el navegador, un cierre de pestaña a destiempo dejaba
--  la constitución resuelta y ninguna protocolización, y nadie se
--  enteraría hasta que el inversionista preguntara.
--
--  AFTER UPDATE y no BEFORE: lo que se inserta no depende de la fila que
--  se está escribiendo, y a estas alturas la escalera de estados y la
--  guarda de la reserva ya dijeron que sí.
--
--  security definer para poder insertar por encima del RLS: el gestor que
--  resuelve no tiene permiso para crear un trámite de otra persona, y es
--  justo lo que hay que hacer aquí.
--
--  QUÉ SE COPIA. La protocolización pregunta cinco cosas y la
--  constitución ya sabe cuatro:
--    · razón social        ← la denominación que se reservó
--    · capital social      ← el mismo
--    · registro mercantil  ← la oficina del SAREN donde se constituyó
--    · representante       ← el primero de la junta directiva, que se
--                            guarda como «Nombre (CARGO); Nombre (CARGO)»
--  La fecha de firma del acta NO se copia: no existía todavía. La rellena
--  quien la tenga delante.
--
--  Y si ya hay una protocolización de esa persona no se crea otra: ni
--  aunque esté resuelta. Volver a resolver la constitución de alguien
--  —enderezando un expediente a mano, por ejemplo— no tiene por qué
--  abrirle un trámite repetido, y el índice de «una sola solicitud viva»
--  rechazaría la fila de todas formas.
create or replace function public.constitucion_abre_la_protocolizacion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  copia     jsonb := '{}'::jsonb;
  junta     text;
  quien     text;
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'constitucion' then
    return new;
  end if;

  --  Sin el trámite en el catálogo —o apagado— no hay nada que crear: la
  --  llave foránea lo rechazaría y se llevaría por delante el «resuelto»
  --  que el gestor acaba de dar.
  if not exists (
    select 1 from public.tipos_tramite
     where codigo = 'protocolizacion_acta' and coalesce(activo, true)
  ) then
    return new;
  end if;

  --  UNA POR CONSTITUCIÓN, NO UNA POR PERSONA (24 de septiembre de 2026).
  --  Esto miraba si el inversionista YA tenía una protocolización, de
  --  cualquier constitución. Con eso, quien constituía una segunda empresa
  --  no volvía a tener tramos: la cadena entera daba por hecho una empresa
  --  por persona, y la segunda constitución quedaba colgando debajo de los
  --  tramos de la primera, con sus fechas y sus marcas de hecho.
  --
  --  Ahora la guarda es por SOLICITUD: se mira si ESTA constitución ya
  --  abrió la suya. Sigue impidiendo lo que vino a impedir -que un mismo
  --  trámite abra dos tramos si se resuelve dos veces- y deja de impedir
  --  lo que nunca quiso.
  if exists (
    select 1 from public.tramites
     where viene_de = new.id
       and tipo = 'protocolizacion_acta'
  ) then
    return new;
  end if;

  if coalesce(new.datos->>'denominacion', '') <> '' then
    copia := copia || jsonb_build_object('razon_social', new.datos->>'denominacion');
  end if;
  if coalesce(new.datos->>'capital_social', '') <> '' then
    copia := copia || jsonb_build_object('capital_social', new.datos->>'capital_social');
  end if;
  if coalesce(new.datos->>'oficina_registro', '') <> '' then
    copia := copia || jsonb_build_object('registro_mercantil', new.datos->>'oficina_registro');
  end if;

  junta := coalesce(new.datos->>'junta_directiva', '');
  if junta <> '' then
    --  «Ana Pérez (PRESIDENTE); Luis Mora (TESORERO)» → «Ana Pérez»
    quien := btrim(split_part(split_part(junta, ';', 1), '(', 1));
    if quien <> '' then
      copia := copia || jsonb_build_object('representante', quien);
    end if;
  end if;

  --  Y NACE EN MANOS DE QUIEN RESOLVIÓ LA CONSTITUCIÓN (Franklin Reyes,
  --  18-9-2026). Sin esto nacía sin dueño, y un trámite sin dueño solo
  --  ofrece «Tómalo» en la cola: la casilla donde el equipo deja el
  --  documento con que pagar los aranceles vive un paso más adentro, y no
  --  aparecía sola. El gestor esperaba a que apareciera y el
  --  inversionista, a un papel que nadie le mandaba —y sin ese papel no
  --  tiene con qué pagar ni, por tanto, qué comprobante subir—.
  --
  --  Es el mismo que acaba de llevar la constitución, así que la
  --  protocolización le cae en «Míos» y ve la casilla en cuanto la abre.
  --  Si la constitución se resolvió desde el SQL Editor no hay gestor que
  --  copiar: queda null, sin asignar, como antes.
  insert into public.tramites (inversionista, tipo, estado, datos, enviado_en, gestor, viene_de)
  values (new.inversionista, 'protocolizacion_acta', 'enviado', copia, now(), new.gestor, new.id);

  return new;
end;
$$;

drop trigger if exists tramites_abre_protocolizacion on public.tramites;
create trigger tramites_abre_protocolizacion
  after update on public.tramites
  for each row execute function public.constitucion_abre_la_protocolizacion();


--  LAS QUE YA NACIERON SIN DUEÑO (Franklin Reyes, 18-9-2026)
--  ─────────────────────────────────────────────────────────────────────
--  El disparador solo mira las que nacen, así que las protocolizaciones
--  creadas antes de este cambio se quedarían sin gestor para siempre:
--  nadie las vería en «Míos» y la casilla del documento para pagar los
--  aranceles no aparecería sola en ninguna de ellas. Habría que tomarlas
--  a mano, una por una, sabiendo que existen.
--
--  Se les pone el gestor de SU constitución, que es de quien habrían
--  heredado si el disparador ya fuera éste. Solo a las que no tienen
--  ninguno: si alguien ya la tomó a mano, esa decisión manda.
--
--  Va aquí y no en un apaño suelto para que corra también en la base de
--  pruebas y en cualquiera que se levante de cero. Correrlo dos veces no
--  hace nada la segunda: después ya no queda ninguna sin gestor.
update public.tramites c22
   set gestor = c5.gestor
  from public.tramites c5
 where c22.tipo   = 'protocolizacion_acta'
   and c22.gestor is null
   and c5.inversionista = c22.inversionista
   and c5.tipo   = 'constitucion'
   and c5.gestor is not null;


--  Y LAS QUE NO LLEGARON A NACER (Franklin Reyes, 18-9-2026)
--  ──────────────────────────────────
--  Quien tuvo su constitución resuelta ANTES de que existiera el
--  disparador se quedó sin protocolización y sin forma de conseguirla: en
--  su paso del pago el panel dice que el CIIP le enviará el documento, y el
--  CIIP no puede dejárselo porque no hay solicitud donde colgarlo. Los dos
--  esperando al otro, para siempre.
--
--  Así que aquí nacen, igual que habrían nacido: enviadas, con el gestor de
--  su constitución y con lo que aquélla decía. La copia es la misma que la
--  del disparador —razón social, capital, registro, representante—, escrita
--  con jsonb_strip_nulls para no repetir cuatro `if`.
--
--  Correrlo dos veces no hace nada la segunda: el `not exists` ya no
--  encuentra a nadie.
insert into public.tramites (inversionista, tipo, estado, datos, enviado_en, gestor)
select c5.inversionista, 'protocolizacion_acta', 'enviado',
       jsonb_strip_nulls(jsonb_build_object(
         'razon_social',       nullif(c5.datos->>'denominacion', ''),
         'capital_social',     nullif(c5.datos->>'capital_social', ''),
         'registro_mercantil', nullif(c5.datos->>'oficina_registro', ''),
         'representante',      nullif(btrim(split_part(
                                 split_part(coalesce(c5.datos->>'junta_directiva', ''), ';', 1),
                                 '(', 1)), '')
       )),
       now(), c5.gestor
  from public.tramites c5
 where c5.tipo   = 'constitucion'
   and c5.estado = 'resuelto'
   and exists (select 1 from public.tipos_tramite
                where codigo = 'protocolizacion_acta' and activo)
   and not exists (
     select 1 from public.tramites otra
      where otra.inversionista = c5.inversionista
        and otra.tipo = 'protocolizacion_acta');


-- ───────────────────────────────────────────────────────────────────────
-- 4. SIN EL COMPROBANTE DEL PAGO, NO HAY «RESUELTA»
-- ───────────────────────────────────────────────────────────────────────
--  La misma regla que protege a la constitución, en la protocolización:
--  el registro no protocoliza nada sin arancel pagado, así que un
--  expediente resuelto sin ese papel estaría mintiendo.
--
--  Los BEFORE UPDATE corren por orden alfabético, y 'tramites_proteger'
--  va antes que 'tramites_protocolizacion_pago': un salto que la escalera
--  no deja no llega aquí. Desde el SQL Editor (auth.uid() nulo) no
--  estorba, para poder enderezar a mano un expediente atascado.
create or replace function public.tramites_protocolizacion_con_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'protocolizacion_acta' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;

  if not exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
     where td.tramite = new.id
       and d.tipo = 'pago_aranceles'
  ) then
    raise exception 'La protocolización no se resuelve sin el comprobante del pago de los aranceles'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists tramites_protocolizacion_pago on public.tramites;
create trigger tramites_protocolizacion_pago
  before update on public.tramites
  for each row execute function public.tramites_protocolizacion_con_pago();


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--   select codigo, nombre, vence from public.tipos_documento
--    where codigo = 'planilla_aranceles';                      -- una fila
--
--   select polname from pg_policy
--    where polname in ('documentos: el equipo sube el documento para pagar los aranceles',
--                      'adjuntos: el equipo engancha el documento para pagar los aranceles');
--                                                              -- dos filas
--
--   select tgname from pg_trigger
--    where tgname in ('tramites_abre_protocolizacion', 'tramites_protocolizacion_pago');
--                                                              -- dos filas
--
--  Y el camino entero, con una cuenta del equipo (no desde el SQL Editor,
--  que no estorba):
--    · resolver una constitución que tenga su comprobante de la reserva
--      tiene que dejar una protocolización nueva, en 'enviado', con la
--      razón social ya puesta:
--        select tipo, estado, datos from public.tramites
--         where inversionista = '<uuid>' order by creado_en desc limit 2;
--    · y marcarla resuelta sin el comprobante del pago tiene que responder
--        La protocolización no se resuelve sin el comprobante del pago de
--        los aranceles

-- ====================================================================
--  40 / 105   supabase-publicacion.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA PUBLICACIÓN NACE SOLA (c22 → c23)
--  Va DESPUÉS de supabase-protocolizacion.sql: repite su patrón un piso
--  más abajo y usa sus mismas tablas.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 20 de septiembre de 2026: la publicación del acta tiene
--  que llevar lo mismo que la protocolización y trabajarse igual. Y lo
--  mismo es esto: el primer paso del tramo es la emisión del PUB, el CIIP
--  lo deja en la solicitud, el inversionista paga con él y sube el
--  comprobante en el paso siguiente.
--
--  Para que el equipo tenga DÓNDE dejarlo hace falta una solicitud abierta,
--  y la publicación no nacía sola: la protocolización sí —la abre la
--  constitución—, pero ahí se acababa la cadena. Sin esto, el paso del PUB
--  saldría con su rótulo y sin nada dentro, y el inversionista esperaría un
--  papel que el CIIP no puede mandarle.
--
--  Así que son tres cosas, las mismas de un piso más arriba:
--
--   1. Resuelta la protocolización, la publicación del acta se crea sola,
--      ya enviada, con lo que aquélla decía.
--   2. El equipo deja en ella el PUB de la publicación mercantil.
--   3. Sin el comprobante de ese pago, la publicación no se resuelve.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: la publicación se sigue pidiendo a
--  mano, su paso del PUB sale vacío —no hay tipo de documento que colgar—
--  y la casilla del equipo falla al enganchar el papel.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LOS DOS PAPELES DEL PAGO
-- ───────────────────────────────────────────────────────────────────────
--  Ninguno caduca: el PUB es la orden de pago de un expediente concreto y
--  el comprobante acredita un pago de una fecha concreta. Los de la
--  protocolización —'planilla_aranceles' y 'pago_aranceles'— no se tocan:
--  son de otro trámite y de otro arancel.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_publicacion', 'PUB para pagar la publicación mercantil', false),
  ('pago_publicacion',     'Comprobante del pago de la publicación',  false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. EL EQUIPO DEJA EL PUB
-- ───────────────────────────────────────────────────────────────────────
--  Las dos políticas gemelas de las de la protocolización. Entra
--  'validado', que es lo que impide al inversionista borrarlo sin querer,
--  y el archivo va a la carpeta 'emitidos', que el cubo ya le deja al
--  equipo.
drop policy if exists "documentos: el equipo sube el PUB de la publicacion" on public.documentos;
create policy "documentos: el equipo sube el PUB de la publicacion" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_publicacion' and estado = 'validado');

--  Y engancharlo: solo a una publicación, y solo mientras está en marcha,
--  que es cuando el paso del pago se ofrece. El papel tiene que ser de la
--  bóveda del mismo inversionista del trámite, para no colgarle a alguien
--  el de otro.
drop policy if exists "adjuntos: el equipo engancha el PUB de la publicacion" on public.tramite_documentos;
create policy "adjuntos: el equipo engancha el PUB de la publicacion" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_publicacion'
         and t.tipo = 'publicacion_acta'
         and t.estado in ('enviado','en_revision','ante_el_ente')
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- 3. RESUELTA LA PROTOCOLIZACIÓN, NACE LA PUBLICACIÓN
-- ───────────────────────────────────────────────────────────────────────
--  Todo lo que dice constitucion_abre_la_protocolizacion() vale aquí
--  igual: AFTER UPDATE, security definer para insertar por encima del RLS,
--  y en la base y no en el panel, para que nazca lo resuelva quien lo
--  resuelva y desde donde lo resuelva.
--
--  QUÉ SE COPIA, Y QUÉ NO. La publicación pregunta cuatro cosas y la
--  protocolización solo sabe una de verdad:
--    · razón social          ← la misma
--    · número de registro    ← NO: lo asigna el registro al inscribir, y
--                              la protocolización no lo guarda.
--    · fecha de protocolización ← NO: la fecha en que el equipo marcó el
--                              trámite resuelto no es la nota del
--                              registrador, y ponerla sería inventar un
--                              dato que luego nadie corrige.
--    · periódico             ← NO: lo elige el inversionista.
--  Las tres que faltan las rellena quien las tenga delante, igual que la
--  protocolización deja en blanco la fecha de firma del acta.
--
--  Y si ya hay una publicación de esa persona no se crea otra, ni aunque
--  esté resuelta.
create or replace function public.protocolizacion_abre_la_publicacion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  copia jsonb := '{}'::jsonb;
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'protocolizacion_acta' then
    return new;
  end if;

  --  Sin el trámite en el catálogo —o apagado— no hay nada que crear: la
  --  llave foránea lo rechazaría y se llevaría por delante el «resuelto»
  --  que el gestor acaba de dar.
  if not exists (
    select 1 from public.tipos_tramite
     where codigo = 'publicacion_acta' and coalesce(activo, true)
  ) then
    return new;
  end if;

  --  UNA POR PROTOCOLIZACIÓN, NO UNA POR PERSONA (24-9-2026). Lo mismo
  --  que en supabase-protocolizacion.sql y por lo mismo: miraba si esa
  --  persona ya tenía una publicación, de modo que una segunda empresa no
  --  llegaba a tener la suya. Ahora se mira si ESTA protocolización ya la
  --  abrió.
  if exists (
    select 1 from public.tramites
     where viene_de = new.id
       and tipo = 'publicacion_acta'
  ) then
    return new;
  end if;

  --  LO QUE EL TRAMO NUEVO HEREDA
  --  ─────────────────────────────────────────────────────────────────
  --  La razón social desde el principio. El número de registro y la fecha
  --  de protocolización desde el 21 de septiembre de 2026, a petición de
  --  Franklin Reyes: «esa información debería llenarse con la primera
  --  fase». De la constitución no puede salir —el registro los ASIGNA al
  --  protocolizar, así que cuando se constituye no existen todavía—, pero
  --  de la protocolización sí: el gestor los copia del acta en el momento
  --  de subirla, que es el único momento en que alguien los tiene delante.
  --
  --  Los tres nombres son los del formulario de la publicación. Si allí se
  --  renombra un campo, hay que renombrarlo aquí o la herencia se corta sin
  --  hacer ruido: lo que se hereda es un nombre, no una columna.
  --
  --  Lo que no esté, no se copia: una clave en blanco taparía el relleno
  --  del panel, que busca en los otros trámites lo que se escribió antes.
  if coalesce(new.datos->>'razon_social', '') <> '' then
    copia := copia || jsonb_build_object('razon_social', new.datos->>'razon_social');
  end if;

  if coalesce(new.datos->>'numero_registro', '') <> '' then
    copia := copia || jsonb_build_object('numero_registro', new.datos->>'numero_registro');
  end if;

  if coalesce(new.datos->>'fecha_protocolizacion', '') <> '' then
    copia := copia || jsonb_build_object('fecha_protocolizacion',
                                         new.datos->>'fecha_protocolizacion');
  end if;

  --  Y nace en manos de quien resolvió la protocolización, por lo mismo
  --  que allí: un trámite sin dueño solo ofrece «Tómalo» en la cola, y la
  --  casilla donde el equipo deja el PUB vive un paso más adentro. El
  --  gestor esperaría a que apareciera y el inversionista, a un papel que
  --  nadie le manda. Desde el SQL Editor no hay gestor que copiar: queda
  --  null, sin asignar.
  insert into public.tramites (inversionista, tipo, estado, datos, enviado_en, gestor, viene_de)
  values (new.inversionista, 'publicacion_acta', 'enviado', copia, now(), new.gestor, new.id);

  return new;
end;
$$;

drop trigger if exists tramites_abre_publicacion on public.tramites;
create trigger tramites_abre_publicacion
  after update on public.tramites
  for each row execute function public.protocolizacion_abre_la_publicacion();


--  LAS QUE YA NACIERON SIN DUEÑO
--  ─────────────────────────────────────────────────────────────────────
--  Igual que un piso más arriba: a las publicaciones que ya existen y no
--  tienen gestor se les pone el de SU protocolización, que es de quien lo
--  habrían heredado. Solo a las que no tienen ninguno: si alguien ya la
--  tomó a mano, esa decisión manda. Correrlo dos veces no hace nada la
--  segunda.
update public.tramites c23
   set gestor = c22.gestor
  from public.tramites c22
 where c23.tipo   = 'publicacion_acta'
   and c23.gestor is null
   and c22.inversionista = c23.inversionista
   and c22.tipo   = 'protocolizacion_acta'
   and c22.gestor is not null;


--  Y LAS QUE NO LLEGARON A NACER
--  ──────────────────────────────────
--  Quien tuvo su protocolización resuelta ANTES de que existiera el
--  disparador se queda sin publicación y sin forma de conseguirla: en su
--  paso del PUB el panel dice que el CIIP se lo enviará, y el CIIP no
--  puede dejárselo porque no hay solicitud donde colgarlo. Los dos
--  esperando al otro, para siempre.
--
--  Correrlo dos veces no hace nada la segunda: el `not exists` ya no
--  encuentra a nadie.
insert into public.tramites (inversionista, tipo, estado, datos, enviado_en, gestor)
select c22.inversionista, 'publicacion_acta', 'enviado',
       jsonb_strip_nulls(jsonb_build_object(
         'razon_social', nullif(c22.datos->>'razon_social', '')
       )),
       now(), c22.gestor
  from public.tramites c22
 where c22.tipo   = 'protocolizacion_acta'
   and c22.estado = 'resuelto'
   and exists (select 1 from public.tipos_tramite
                where codigo = 'publicacion_acta' and activo)
   and not exists (
     select 1 from public.tramites otra
      where otra.inversionista = c22.inversionista
        and otra.tipo = 'publicacion_acta');


-- ───────────────────────────────────────────────────────────────────────
-- 4. SIN EL COMPROBANTE DEL PAGO, NO HAY «RESUELTA»
-- ───────────────────────────────────────────────────────────────────────
--  La misma regla de la protocolización: el periódico no publica nada sin
--  cobrar, así que una publicación resuelta sin ese papel estaría
--  mintiendo.
--
--  Los BEFORE UPDATE corren por orden alfabético, y 'tramites_proteger' va
--  antes que 'tramites_publicacion_pago': un salto que la escalera no deja
--  no llega aquí. Desde el SQL Editor (auth.uid() nulo) no estorba, para
--  poder enderezar a mano un expediente atascado.
create or replace function public.tramites_publicacion_con_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'publicacion_acta' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;

  if not exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
     where td.tramite = new.id
       and d.tipo = 'pago_publicacion'
  ) then
    raise exception 'La publicación no se resuelve sin el comprobante del pago de la publicación'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists tramites_publicacion_pago on public.tramites;
create trigger tramites_publicacion_pago
  before update on public.tramites
  for each row execute function public.tramites_publicacion_con_pago();


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--   select codigo, nombre, vence from public.tipos_documento
--    where codigo in ('planilla_publicacion', 'pago_publicacion');  -- dos filas
--
--   select polname from pg_policy
--    where polname in ('documentos: el equipo sube el PUB de la publicacion',
--                      'adjuntos: el equipo engancha el PUB de la publicacion');
--                                                              -- dos filas
--
--   select tgname from pg_trigger
--    where tgname in ('tramites_abre_publicacion', 'tramites_publicacion_pago');
--                                                              -- dos filas
--
--  Y el camino entero, con una cuenta del equipo (no desde el SQL Editor,
--  que no estorba):
--    · resolver una protocolización que tenga su comprobante del pago
--      tiene que dejar una publicación nueva, en 'enviado', con la razón
--      social ya puesta:
--        select tipo, estado, datos from public.tramites
--         where inversionista = '<uuid>' order by creado_en desc limit 2;
--    · y marcarla resuelta sin el comprobante del pago tiene que responder
--        La publicación no se resuelve sin el comprobante del pago de la
--        publicación

-- ====================================================================
--  41 / 105   supabase-parafiscales.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LAS CINCO INSCRIPCIONES, EN UNA CASILLA (c37)
--  Va DESPUÉS de supabase-rupdae-rum.sql: apaga el c35 que aquel encendió,
--  y usa las columnas `nivel` (supabase-informe-victor.sql) y `emite`
--  (supabase-encadenado.sql).
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Del encargo del 20 de septiembre de 2026:
--
--    «Vamos a agrupar los trámites de Banavih, Inces, Ministerio de
--     Trabajo, RNC y Rupdae en una sola casilla. Se va a llamar
--     Inscripciones: Registros Parafiscales y Regulatorios.»
--
--    «Ahora bien, con un solo paso vamos a recoger todos los recaudos, no
--     es necesario que creemos un proceso por cada inscripción, porque
--     todos requieren los mismos recaudos.»
--
--  Son las dos cosas, y la segunda es la que manda: no es una ficha madre
--  con cinco trámites dentro —eso es lo que ya hace la constitución con la
--  protocolización y la publicación, y son tres solicitudes—, es UN
--  trámite, UNA solicitud, UN juego de recaudos. El precedente de la casa
--  es el c14: cuatro solvencias, una sola solicitud.
--
--  EL IVSS (c9) NO ENTRA AQUÍ, Y DESDE EL 22-9-2026 NO ESTÁ EN NINGÚN SITIO
--  ─────────────────────────────────────────────────────────────────────
--  El 20 de septiembre no estaba en la lista del encargo, se preguntó, y
--  se quedó con casilla propia al lado de ésta.
--
--  El 22 de septiembre el CIIP la quitó: «elimina la casilla de IVSS», y
--  se confirmó que sale DEL CATÁLOGO, no que se hace dentro de esta. Así
--  que aquí no hay nada que absorber: el c9 no está entre los cinco de
--  abajo porque no está en el catálogo. Quien tenga la fila todavía la
--  apaga y la borra con QUITAR-IVSS.sql.
--
--  Y el rótulo «Obligaciones parafiscales y laborales» se fue con él: con
--  una sola ficha debajo repetía lo que la ficha ya dice en su nombre.
--
--  QUÉ PASA CON LOS CINCO QUE ABSORBE
--  ─────────────────────────────────────────────────────────────────────
--  Se APAGAN, no se borran. Es la diferencia que cuenta:
--
--   · Las solicitudes que ya estén en la base siguen donde están, con su
--     historial, sus recaudos y su sitio en la cola del equipo. Apagar un
--     trámite no toca un expediente; lo dice supabase-catalogos.sql.
--   · Lo que deja de pasar es que se ofrezcan a quien no los haya
--     empezado. En el panel sus fichas llevan data-tramo-de="c37" y ya no
--     se ven en la portada ni se cuentan en la etapa.
--   · Y se vuelven a encender con el mismo interruptor, desde el panel del
--     admin, si el CIIP se arrepiente.
--
--  EL PLAZO: 28 DÍAS, Y POR QUÉ ESTE
--  ─────────────────────────────────────────────────────────────────────
--  Los cinco se presentan a la vez con el mismo expediente, así que la
--  casilla no está resuelta hasta que vuelve el último. De los cinco, el
--  más largo de los que TIENEN plazo en el catálogo es el RNET: 28 días
--  (supabase-plazos.sql). El FAOV y el INCES van a 21, el RUPDAE a 14.
--
--  POR CONFIRMAR: el RNC no tiene plazo en el catálogo —nunca lo tuvo— y
--  es el que más podría tardar de los cinco. Si el CIIP mide que el
--  expediente del RNC se va más allá de las cuatro semanas, este número
--  se queda corto y la casilla promete algo que no cumple. Lo honesto
--  entonces es dejarlo en null: sin fila, la ficha no enseña reloj.
--
--  POR QUÉ 'esencial'
--  ─────────────────────────────────────────────────────────────────────
--  El RNET y el RUPDAE le tocan a toda empresa, así que la casilla le toca
--  a todos. Los cinco sueltos estaban en 'actividad' —menos el RUPDAE, que
--  ya era 'esencial'— y juntos no pueden decir «según tu actividad»: lo
--  que hay dentro es de todos. No suma a los diez obligatorios del informe
--  del 2 de septiembre, que los decidió el CIIP y no se tocan aquí.
--
--  POR QUÉ NO EMITE NADA
--  ─────────────────────────────────────────────────────────────────────
--  `emite` guarda UN tipo de documento y esta casilla devuelve CINCO
--  constancias. Poner una de las cinco sería decir que las otras cuatro no
--  salen de ningún sitio, y encadenaría mal: un trámite que pidiera la
--  constancia del RNET se quedaría esperando por un `emite` que dice
--  «certificado_rupdae». Se deja en null, que es lo que ya hacía el c27.
--  El día que la columna admita varios, esto es una línea.
--
--  Si alguien corre supabase-tramites.sql SOLO, después de este, los cinco
--  se vuelven a encender y el c37 se apaga: aquel deja encendidos
--  exactamente los de su lista. Es lo mismo que le pasa al c32, al c33, al
--  c34, al c35 y al c36. TODO-EN-ORDEN.sql lo corre detrás y lo arregla.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA CASILLA NUEVA
-- ───────────────────────────────────────────────────────────────────────
-- El ente va en plural y sin siglas: son cinco organismos y ninguno manda
-- sobre los otros. Es el mismo criterio del c14, «Entes varios».
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('registros_parafiscales', 'c37',
   'Inscripciones: Registros Parafiscales y Regulatorios',
   'Entes varios', 3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set nombre     = 'Inscripciones: Registros Parafiscales y Regulatorios',
       ente       = 'Entes varios',
       fase       = 3,
       emite      = null,
       plazo_dias = 28,
       nivel      = 'esencial',
       activo     = true
 where codigo = 'registros_parafiscales';


-- ───────────────────────────────────────────────────────────────────────
-- 2. Y LOS CINCO QUE AHORA SE HACEN DENTRO
-- ───────────────────────────────────────────────────────────────────────
-- Apagar, no borrar. Sus expedientes siguen vivos; lo que se retira es la
-- oferta. Ver la nota de arriba.
update public.tipos_tramite
   set activo = false
 where codigo in ('faov_banavih',   -- c25  BANAVIH · FAOV
                  'inces',          -- c26  INCES
                  'rnet',           -- c27  Ministerio del Trabajo · RNET
                  'rnc',            -- c13  Servicio Nacional de Contrataciones
                  'rupdae');        -- c35  SUNDDE

-- AQUÍ SE ENCENDÍA EL IVSS (c9) A PROPÓSITO, y se fue el 22-9-2026 con la
-- casilla. Se deja dicho para que nadie lo añada a la lista de arriba por
-- parecerse: no se apaga porque esté dentro de ésta, es que ya no está.


-- ───────────────────────────────────────────────────────────────────────
-- 3. LOS PAPELES DE LOS INVERSIONISTAS Y DE LA JUNTA (23-9-2026)
-- ───────────────────────────────────────────────────────────────────────
-- Un archivo por papel con todas las personas dentro. No vencen: con
-- varias personas en un archivo no hay una sola fecha que pedir.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('rif_inversionistas', 'RIF de los inversionistas',                      false),
  ('cedulas_junta',      'Cédula de los miembros de la junta directiva',   false),
  ('rifs_junta',         'RIF de los miembros de la junta directiva',      false)
on conflict (codigo) do update set nombre = excluded.nombre;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) La casilla nueva: c37 · Entes varios · fase 3 · esencial · 28 días ·
--    sin `emite` · encendida.
--
--   select ref_panel, codigo, nombre, ente, fase, nivel, emite, plazo_dias, activo
--   from public.tipos_tramite where ref_panel = 'c37';
--
-- 2) Los cinco apagados. Tienen que salir cinco filas y las cinco en
--    'false'; 'registros_laborales' va en la lista para comprobar que NO
--    sale ninguna, que es donde estaba el IVSS:
--
--   select ref_panel, codigo, activo from public.tipos_tramite
--   where codigo in ('faov_banavih','inces','rnet','rnc','rupdae','registros_laborales')
--   order by ref_panel;
--
-- 3) Que apagar no se llevó ningún expediente por delante. Si había
--    solicitudes de los cinco, siguen aquí:
--
--   select tipo, estado, count(*) from public.tramites
--   where tipo in ('faov_banavih','inces','rnet','rnc','rupdae')
--   group by tipo, estado order by tipo;
--
-- 4) Los obligatorios siguen siendo DIEZ, cinco y cinco: el c37 es
--    'esencial' y no suma.
--
--   select fase, count(*) from public.tipos_tramite
--   where nivel = 'obligatorio' group by fase;

-- ====================================================================
--  42 / 105   supabase-entes-parafiscales.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS CINCO ENTES DE LOS REGISTROS PARAFISCALES
--  Va DESPUÉS de supabase-tramites.sql y de supabase-parafiscales.sql.
--  Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  Franklin Reyes, 23-9-2026: los registros parafiscales (c37) son UNA
--  solicitud con un solo envío de recaudos, pero ante cinco entes, y cada
--  uno avanza por su cuenta: el ente le manda un código al inversionista,
--  el inversionista nos lo manda a nosotros y con eso el CIIP da ese ente
--  por listo.
--
--  Una fila por solicitud y ente, con cuatro estados: pendiente, inscrito,
--  codigo_enviado y listo. El ente no manda su código hasta que el CIIP
--  inscribe a la empresa ante él, así que la inscripción es el primer paso
--  y es tarea del gestor: 'pendiente' → 'inscrito'. Luego el inversionista
--  escribe el código -y si quiere, adjunta un archivo- y la fila queda en
--  'codigo_enviado'; solo el equipo la pone en 'listo'. Una vez lista, el
--  inversionista ya no la toca.
--
--  25-9-2026 (Franklin): las cinco filas NACEN SOLAS al enviarse la
--  solicitud, las crea un disparador de la base. «Una fila que solo existe
--  si alguien abrió una pantalla no es una fila, es una casualidad»: el
--  gestor tiene que verlas aunque el inversionista no haya entrado nunca.
--  Esto vivía solo en CORRER-HOY-2026-09-25.sql; desde el mismo día está
--  aquí, que es de donde sale TODO-EN-ORDEN.sql.
-- ═══════════════════════════════════════════════════════════════════════

insert into public.tipos_documento (codigo, nombre, vence) values
  ('codigo_ente', 'Código o constancia que envió un ente', false)
on conflict (codigo) do update set nombre = excluded.nombre;

create table if not exists public.tramite_entes (
  tramite        uuid not null references public.tramites(id) on delete cascade,
  ente           text not null check (ente in ('banavih', 'inces', 'mpppst', 'sundde', 'ivss', 'snc')),
  codigo         text check (codigo is null or length(codigo) <= 200),
  documento      uuid references public.documentos(id) on delete set null,
  estado         text not null default 'pendiente'
                 check (estado in ('pendiente', 'inscrito', 'codigo_enviado', 'listo')),
  actualizado_en timestamptz not null default now(),
  primary key (tramite, ente)
);

-- En una base donde la tabla ya existía con los dos estados de antes, el
-- create table de arriba no toca nada: se cambia aquí la regla y el valor
-- por defecto. Se busca por lo que dice y no por su nombre, que lo pone
-- Postgres.
do $entes$
declare c text;
begin
  for c in select conname from pg_constraint
            where conrelid = 'public.tramite_entes'::regclass
              and contype = 'c'
              and pg_get_constraintdef(oid) ilike '%estado%'
  loop
    execute format('alter table public.tramite_entes drop constraint %I', c);
  end loop;
end $entes$;
alter table public.tramite_entes add constraint tramite_entes_estado_check
  check (estado in ('pendiente', 'inscrito', 'codigo_enviado', 'listo'));
alter table public.tramite_entes alter column estado set default 'pendiente';

-- El IVSS, la sexta inscripción (Franklin Reyes, 25-9-2026; venía en
-- CORRER-PARAFISCALES-2026-09-25.sql). Igual que arriba: en una base con la
-- tabla ya creada con cinco entes, se cambia la regla.
do $entes$
declare c text;
begin
  for c in select conname from pg_constraint
            where conrelid = 'public.tramite_entes'::regclass
              and contype = 'c'
              and pg_get_constraintdef(oid) ilike '%ente%'
              and pg_get_constraintdef(oid) not ilike '%estado%'
  loop
    execute format('alter table public.tramite_entes drop constraint %I', c);
  end loop;
end $entes$;
alter table public.tramite_entes add constraint tramite_entes_ente_check
  check (ente in ('banavih', 'inces', 'mpppst', 'sundde', 'ivss', 'snc'));

alter table public.tramite_entes enable row level security;
grant select, insert, update, delete on public.tramite_entes to authenticated;

drop policy if exists "entes: leer los propios" on public.tramite_entes;
create policy "entes: leer los propios" on public.tramite_entes
  for select using (
    public.es_gestor() or exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
    )
  );

--  El inversionista, solo en su solicitud de parafiscales y con ella en
--  marcha: ni en borrador -todavía no la ha mandado- ni resuelta.
drop policy if exists "entes: el inversionista manda su codigo" on public.tramite_entes;
create policy "entes: el inversionista manda su codigo" on public.tramite_entes
  for insert with check (
    estado = 'codigo_enviado'
    and exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
         and t.tipo = 'registros_parafiscales'
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
    and (documento is null or exists (
      select 1 from public.documentos d
       where d.id = tramite_entes.documento and d.inversionista = auth.uid()
    ))
  );

drop policy if exists "entes: el inversionista corrige su codigo" on public.tramite_entes;
create policy "entes: el inversionista corrige su codigo" on public.tramite_entes
  for update
  using (
    -- El código solo se manda con el ente ya inscrito por el CIIP: que la
    -- pantalla esconda el botón no impide que alguien llame a la API.
    estado in ('inscrito', 'codigo_enviado')
    and exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
  )
  with check (
    estado = 'codigo_enviado'
    and exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
    and (documento is null or exists (
      select 1 from public.documentos d
       where d.id = tramite_entes.documento and d.inversionista = auth.uid()
    ))
  );

drop policy if exists "entes: el equipo los lleva" on public.tramite_entes;
create policy "entes: el equipo los lleva" on public.tramite_entes
  for all using (public.es_gestor()) with check (public.es_gestor());

create or replace function public.tramite_entes_marca_tiempo()
returns trigger language plpgsql as $$
begin
  new.actualizado_en := now();
  return new;
end $$;

drop trigger if exists tramite_entes_marca_tiempo on public.tramite_entes;
create trigger tramite_entes_marca_tiempo
  before update on public.tramite_entes
  for each row execute function public.tramite_entes_marca_tiempo();

-- Las seis nacen solas al enviarse la solicitud de parafiscales.
create or replace function public.tramite_entes_nacen()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.tipo = 'registros_parafiscales'
     and new.estado in ('enviado', 'en_revision', 'ante_el_ente') then
    insert into public.tramite_entes (tramite, ente, estado)
    select new.id, e, 'pendiente'
      from unnest(array['banavih', 'inces', 'mpppst', 'sundde', 'ivss', 'snc']) as e
    on conflict (tramite, ente) do nothing;
  end if;
  return new;
end $$;

drop trigger if exists tramite_entes_nacen on public.tramites;
create trigger tramite_entes_nacen
  after insert or update of estado on public.tramites
  for each row execute function public.tramite_entes_nacen();

-- Y las solicitudes que ya estaban en marcha, rellenas. No toca las filas
-- que ya existen.
insert into public.tramite_entes (tramite, ente, estado)
select t.id, e, 'pendiente'
  from public.tramites t
  cross join unnest(array['banavih', 'inces', 'mpppst', 'sundde', 'ivss', 'snc']) as e
 where t.tipo = 'registros_parafiscales'
   and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
on conflict (tramite, ente) do nothing;

-- Cada ente con su propia constancia (Franklin Reyes, 25-9-2026; venía en
-- CORRER-CONSTANCIA-DE-CADA-ENTE.sql). El equipo la deja ya validada y la
-- cuelga del trámite.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('constancia_ente', 'Constancia de inscripción ante el ente', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

drop policy if exists "documentos: el equipo entrega la constancia del ente" on public.documentos;
create policy "documentos: el equipo entrega la constancia del ente" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'constancia_ente' and estado = 'validado');

drop policy if exists "adjuntos: el equipo cuelga la constancia del ente" on public.tramite_documentos;
create policy "adjuntos: el equipo cuelga la constancia del ente" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1 from public.documentos d
       where d.id = documento and d.tipo = 'constancia_ente'
    )
  );

-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--   select policyname, cmd from pg_policies where tablename = 'tramite_entes';
--   -- cuatro: leer, mandar, corregir y la del equipo

-- ====================================================================
--  43 / 105   supabase-visa-tri.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  LA VISA SE PARTE EN DOS: TR-N DE NEGOCIOS Y TR-I DE INVERSIONISTA
--  Franklin Reyes, 22 de septiembre de 2026.
-- ═══════════════════════════════════════════════════════════════════════
--  En el panel las dos se presentan en UNA casilla -«Visa para
--  Extranjeros»- y se elige dentro. Por debajo son DOS tramites, porque
--  piden recaudos distintos y dan cosas distintas: la TR-N es de
--  transeunte y dura un año; la TR-I dura tres, con multiples entradas y
--  sin limite de permanencia.
--
--  ═══ EL LIO DEL CODIGO, QUE ES LO QUE ARREGLA ESTE ARCHIVO ═══════════
--  La c1 nacio siendo la visa de inversionista, con el codigo
--  'visa_inversionista'. El 15 de septiembre paso a ser la de negocios
--  (TR-N) y se le cambio el NOMBRE, pero no el codigo: desde entonces la
--  base decia 'visa_inversionista' de una ficha que se llama «Visa de
--  negocios». Ahora que vuelve la TR-I de verdad, ese nombre lo necesita
--  ella.
--
--      ANTES                                    DESPUES
--      visa_inversionista → TR-N, c1            visa_negocios      → TR-N, c1
--                                               visa_inversionista → TR-I, c38
--
--  ═══ POR QUE NO ES UN UPDATE Y YA ═══════════════════════════════════
--  Cuatro tablas apuntan a tipos_tramite.codigo con clave foranea:
--  tramites.tipo, citas.tipo_tramite, consultas.tipo y aranceles.tramite.
--  Ninguna lleva ON UPDATE CASCADE, asi que cambiar el codigo con las
--  solicitudes colgando lo rechaza la base. Y tampoco vale insertar
--  primero la fila nueva: ref_panel es UNIQUE y 'c1' seguiria ocupado.
--
--  El camino que si funciona, y en este orden:
--    1. copiar la fila con el codigo nuevo y un ref_panel provisional,
--    2. mudar a ella lo que colgaba de la vieja,
--    3. borrar la vieja, que ya no tiene hijos,
--    4. devolverle el 'c1' de verdad,
--    5. y recien entonces dar de alta la TR-I con el nombre liberado.
--
--  La copia se hace con una tabla temporal y `select *`, no enumerando
--  columnas: tipos_tramite ha ido ganando columnas en otros archivos
--  -plazo_dias, emite, nivel- y una lista escrita a mano las perderia sin
--  decirlo.
--
--  ═══ SE PUEDE CORRER VARIAS VECES ═══════════════════════════════════
--  Todo va dentro de guardas: si ya esta hecho, no hace nada y lo dice.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL RECAUDO QUE SEPARA A LAS DOS
--    El Certificado de Inversionista, que se saca por la Ventanilla Unica
--    de Comercio Exterior. Tipo PROPIO y no el generico 'inversion': con
--    el mismo tipo la boveda daria el uno por el otro, que es el mismo
--    criterio que ya separa el certificado medico del pais de origen del
--    de aqui. No vence: acredita un hecho de una fecha dada, no una
--    situacion vigente.
-- ───────────────────────────────────────────────────────────────────────
insert into public.tipos_documento (codigo, nombre, vence) values
  ('certificado_inversionista', 'Certificado de Inversionista (VUCE)', false)
on conflict (codigo) do update
  set nombre = excluded.nombre,
      vence  = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LIBERAR EL NOMBRE Y DAR DE ALTA LA TR-I
-- ───────────────────────────────────────────────────────────────────────
do $visas$
declare
  mudadas  bigint := 0;
  cuantas  bigint;
begin
  -- ── 2.1  ¿Hay algo que hacer? ────────────────────────────────────────
  -- Si 'visa_inversionista' ya no ocupa el c1, este archivo ya corrio.
  if not exists (select 1 from public.tipos_tramite
                  where codigo = 'visa_inversionista' and ref_panel = 'c1') then
    raise notice 'El codigo ya estaba liberado: no hay nada que mudar.';
  else
    -- ── 2.2  La copia, con TODAS sus columnas ──────────────────────────
    drop table if exists pg_temp.visa_vieja;
    create temporary table visa_vieja as
      select * from public.tipos_tramite where codigo = 'visa_inversionista';
    update visa_vieja set codigo = 'visa_negocios', ref_panel = 'c1-provisional';
    insert into public.tipos_tramite select * from visa_vieja;

    -- ── 2.3  Lo que colgaba de la vieja, a la nueva ────────────────────
    -- Cada tabla se mira antes: en una base recien creada puede que
    -- todavia no existan, y el archivo tiene que correr igual.
    if to_regclass('public.tramites') is not null then
      update public.tramites set tipo = 'visa_negocios'
       where tipo = 'visa_inversionista';
      get diagnostics cuantas = row_count;  mudadas := mudadas + cuantas;
    end if;

    if to_regclass('public.citas') is not null then
      update public.citas set tipo_tramite = 'visa_negocios'
       where tipo_tramite = 'visa_inversionista';
      get diagnostics cuantas = row_count;  mudadas := mudadas + cuantas;
    end if;

    if to_regclass('public.consultas') is not null then
      update public.consultas set tipo = 'visa_negocios'
       where tipo = 'visa_inversionista';
      get diagnostics cuantas = row_count;  mudadas := mudadas + cuantas;
    end if;

    if to_regclass('public.aranceles') is not null then
      update public.aranceles set tramite = 'visa_negocios'
       where tramite = 'visa_inversionista';
      get diagnostics cuantas = row_count;  mudadas := mudadas + cuantas;
    end if;

    -- ── 2.4  Fuera la vieja, que ya no tiene a nadie colgando ──────────
    delete from public.tipos_tramite where codigo = 'visa_inversionista';

    -- ── 2.5  Y el c1 de verdad para la TR-N ────────────────────────────
    update public.tipos_tramite set ref_panel = 'c1'
     where codigo = 'visa_negocios';

    raise notice 'Codigo liberado. Filas mudadas a visa_negocios: %', mudadas;
  end if;

  -- ── 2.6  La TR-I, ya con su nombre ───────────────────────────────────
  -- Nace ENCENDIDA, y no apagada como nacieron otras. La diferencia es que
  -- esta no tiene casilla propia en la portada: se llega a ella desde la
  -- guia de la visa, y apagada NO SE PUEDE ABRIR. El panel saca del arbol
  -- las tarjetas de lo que esta apagado, asi que pulsar «Ver tramite» en la
  -- guia devolvia a la portada; y aunque no la sacara, sin 'activo' la
  -- ficha enseña la escalera de adorno en vez del formulario.
  --
  -- El 'activo' se pone tambien al actualizar, que es como hacen los demas
  -- archivos del catalogo -supabase-zodi.sql enciende el c34,
  -- supabase-parafiscales apaga el c35-: aqui el SQL manda sobre el estado.
  insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
    ('visa_inversionista', 'c38', 'Visa de inversionista (TR-I)', 'MPPRE', 1, true)
  on conflict (codigo) do update
    set ref_panel = excluded.ref_panel,
        nombre    = excluded.nombre,
        ente      = excluded.ente,
        fase      = excluded.fase,
        activo    = excluded.activo;
end
$visas$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. SU PLAZO
--    Los treinta dias son los que el catalogo del CIIP daba a la visa
--    cuando la c1 ERA la TR-I, asi que vuelven a estar donde nacieron.
--    Se pone aparte y con guarda porque la columna la crea
--    supabase-plazos.sql, que puede no haber corrido todavia.
-- ───────────────────────────────────────────────────────────────────────
do $plazo$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public'
                and table_name   = 'tipos_tramite'
                and column_name  = 'plazo_dias') then
    update public.tipos_tramite set plazo_dias = 30
     where codigo = 'visa_inversionista' and plazo_dias is null;
  end if;
end
$plazo$;


-- ───────────────────────────────────────────────────────────────────────
-- 4. COMO QUEDO
--    Lo esperado: dos filas, la TR-N en c1 y la TR-I en c38, y ninguna
--    solicitud con el codigo viejo.
-- ───────────────────────────────────────────────────────────────────────
select codigo, ref_panel, nombre, ente, fase, activo
  from public.tipos_tramite
 where codigo in ('visa_negocios', 'visa_inversionista')
 order by ref_panel;

-- ====================================================================
--  44 / 105   supabase-locti.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL SIDCAI, EN DOS TRAMOS (c39 y c40)
--  Va DESPUÉS de supabase-visa-tri.sql. Necesita el catálogo con `nivel` y
--  `emite`, tramites, documentos y es_gestor(). Se puede correr más de una
--  vez.
-- ═══════════════════════════════════════════════════════════════════════
--  Del encargo del 23 de septiembre de 2026: la ficha del SIDCAI -el
--  sistema del FONACIT para declarar el aporte de la LOCTI- «en permisos
--  sectoriales», y que trabaje «parecido a como trabaja la constitución».
--  Se eligió el molde de la constitución con SOLO EL PRIMER PAGO:
--
--    c39  Inscripción en el SIDCAI. La pide el inversionista, con sus
--         recaudos. No emite nada.
--    c40  Declaración y primer pago. Nace sola al resolverse la c39, en
--         manos del mismo gestor y con la razón social, el RIF y los
--         ingresos copiados. El equipo deja la planilla que genera el
--         SIDCAI, el inversionista paga en el banco y sube el comprobante;
--         sin él no se resuelve. Emite el certificado de solvencia.
--
--  Los pagos de los meses siguientes -quince días tras cada mes,
--  Providencia 015-004-2024- NO pasan por la ventanilla. Por eso la c40 se
--  crea una sola vez por inversionista, como la protocolización.
--
--  'actividad' y no 'esencial': sólo le toca a quien ingresó el año
--  anterior más de 150.000 veces el tipo de cambio oficial del BCV (LOCTI,
--  G.O. Ext. 6.693 de 2022, arts. 30 a 32). Sin plazo: ninguno de los dos
--  tiene uno publicado.
--
--  La política del comprobante va aparte y no dentro de «adjuntos: papeles
--  de un paso, con el tramite en marcha» (supabase-reserva-nombre.sql):
--  las políticas se suman, y así este archivo no reescribe la de otro.
-- ═══════════════════════════════════════════════════════════════════════

insert into public.tipos_documento (codigo, nombre, vence) values
  ('certificado_locti', 'Certificado de solvencia del aporte LOCTI (FONACIT)', true),
  ('planilla_locti',    'Planilla del SIDCAI para pagar el aporte LOCTI',      false),
  ('pago_locti',        'Comprobante del pago del aporte LOCTI',               false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('aporte_locti',      'c39', 'Inscripción en el SIDCAI (aporte LOCTI)',    'FONACIT', 3, true),
  ('aporte_locti_pago', 'c40', 'Declaración y primer pago del aporte LOCTI', 'FONACIT', 3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite = null, plazo_dias = null, nivel = 'actividad', activo = true
 where codigo = 'aporte_locti';

update public.tipos_tramite
   set emite = 'certificado_locti', plazo_dias = null, nivel = 'actividad', activo = true
 where codigo = 'aporte_locti_pago';

drop policy if exists "documentos: el equipo sube la planilla del SIDCAI" on public.documentos;
create policy "documentos: el equipo sube la planilla del SIDCAI" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_locti' and estado = 'validado');

drop policy if exists "adjuntos: el equipo engancha la planilla del SIDCAI" on public.tramite_documentos;
create policy "adjuntos: el equipo engancha la planilla del SIDCAI" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_locti'
         and t.tipo = 'aporte_locti_pago'
         and t.estado in ('enviado','en_revision','ante_el_ente')
    )
  );

drop policy if exists "adjuntos: el pago del SIDCAI, con el tramite en marcha" on public.tramite_documentos;
create policy "adjuntos: el pago del SIDCAI, con el tramite en marcha" on public.tramite_documentos
  for insert
  with check (
    exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and t.inversionista = auth.uid()
         and d.inversionista = auth.uid()
         and t.tipo = 'aporte_locti_pago'
         and d.tipo = 'pago_locti'
         and t.estado in ('enviado','en_revision','ante_el_ente')
    )
  );

create or replace function public.sidcai_abre_el_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  copia jsonb := '{}'::jsonb;
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'aporte_locti' then
    return new;
  end if;
  if not exists (
    select 1 from public.tipos_tramite
     where codigo = 'aporte_locti_pago' and coalesce(activo, true)
  ) then
    return new;
  end if;
  if exists (
    select 1 from public.tramites
     where inversionista = new.inversionista
       and tipo = 'aporte_locti_pago'
  ) then
    return new;
  end if;

  if coalesce(new.datos->>'razon_social', '') <> '' then
    copia := copia || jsonb_build_object('razon_social', new.datos->>'razon_social');
  end if;
  if coalesce(new.datos->>'rif_empresa', '') <> '' then
    copia := copia || jsonb_build_object('rif_empresa', new.datos->>'rif_empresa');
  end if;
  if coalesce(new.datos->>'ingresos_brutos', '') <> '' then
    copia := copia || jsonb_build_object('ingresos_brutos', new.datos->>'ingresos_brutos');
  end if;

  insert into public.tramites (inversionista, tipo, estado, datos, enviado_en, gestor)
  values (new.inversionista, 'aporte_locti_pago', 'enviado', copia, now(), new.gestor);

  return new;
end;
$$;

drop trigger if exists tramites_abre_pago_sidcai on public.tramites;
create trigger tramites_abre_pago_sidcai
  after update on public.tramites
  for each row execute function public.sidcai_abre_el_pago();

create or replace function public.tramites_sidcai_con_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'aporte_locti_pago' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;
  if not exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
     where td.tramite = new.id
       and d.tipo = 'pago_locti'
  ) then
    raise exception 'El primer pago del SIDCAI no se resuelve sin el comprobante del pago del aporte'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists tramites_sidcai_pago on public.tramites;
create trigger tramites_sidcai_pago
  before update on public.tramites
  for each row execute function public.tramites_sidcai_con_pago();

-- ====================================================================
--  45 / 105   supabase-papeles-sellados.sql
-- ====================================================================

-- ══════════════════════════════════════════════════════════════════════
--  LOS PAPELES, SELLADOS
--  Lo que encontró la revisión de seguridad del 25 de septiembre de 2026
-- ══════════════════════════════════════════════════════════════════════
--
--  QUÉ ESTABA ABIERTO
--
--  1. Un inversionista podía darse de alta un papel YA VALIDADO.
--     La política "documentos: subir los propios" solo miraba que fuera
--     suyo, no con qué estado nacía. Con la consola del navegador bastaba:
--
--         sb.from('documentos').insert({inversionista: yo, tipo: 'resolucion',
--           archivo: yo + '/x.pdf', estado: 'validado', huella: <sha256>})
--
--     y verificar_documento(), que contesta a cualquiera sin entrar,
--     respondía «consta» para un PDF inventado. Las políticas del equipo
--     exigen estado = 'validado' dando por hecho que el inversionista no
--     podía ponerlo. Podía.
--
--  2. Validado el papel, el archivo seguía siendo suyo para cambiarlo.
--     Las políticas del cubo le dejaban reemplazar y borrar TODO lo que
--     hubiera en su carpeta, y lo que emite el CIIP vive dentro de esa
--     carpeta, en {uid}/emitidos/. La ficha decía «validado» y el archivo
--     ya era otro.
--
--  3. La ruta del archivo no se comprobaba. Una ficha podía apuntar a la
--     carpeta de otra persona; al borrarla, apuntar_el_huerfano() la
--     anotaba y el barrendero, con la clave de servidor, borraba el
--     archivo ajeno.
--
--  QUÉ CAMBIA
--
--  · Quien no es del equipo no decide el estado de un papel, ni quién lo
--    revisó, ni cuándo, ni la nota. Nace 'cargado' y así sigue hasta que
--    lo toque el equipo.
--  · Los tipos que solo emite el CIIP (la resolución y las planillas para
--    pagar) no los puede crear el inversionista.
--  · La ruta tiene que estar en la carpeta del dueño de la ficha, sin
--    «..», y la subcarpeta emitidos/ es solo del equipo.
--  · En el cubo, emitidos/ es de solo lectura para el inversionista; lo
--    validado no se reemplaza ni se borra; y reemplazar (upsert) solo vale
--    para la foto de perfil, que es lo único que el panel sobrescribe.
--  · verificar_documento() solo responde por lo que dejó el equipo en
--    emitidos/. La huella de un recaudo la calcula el navegador de quien
--    lo sube y la base nunca comprueba que corresponda al archivo: podía
--    subir A con la huella de B, que el gestor validara A, y que desde
--    entonces B «constara». Lo que verifica un banco es lo que emitió el
--    ente, y eso lo sube el equipo.
--
--  LO QUE NO CAMBIA PARA EL PANEL
--  Nada de lo que hace el panel choca con esto: sube() no manda estado,
--  entrega() lo manda como gestor, la foto usa {uid}/perfil/foto y
--  borraDeVerdad() solo borra papeles no validados. El lector de
--  documentos sube a {uid}/lector/ y lo borra: sigue pudiendo.
--
--  La puerta de servicio (auth.uid() nulo: SQL Editor, clave de
--  servidor) sigue abierta, como en las demás tablas.
--
--  Va DESPUÉS de supabase-huellas.sql (redefine verificar_documento) y
--  de supabase-emision.sql (la carpeta emitidos/). Se puede correr más
--  de una vez.
-- ══════════════════════════════════════════════════════════════════════

do $comprueba$
begin
  if to_regprocedure('public.verificar_documento(text)') is null then
    raise exception 'Falta verificar_documento(): corre antes supabase-huellas.sql';
  end if;
  if to_regprocedure('public.es_gestor()') is null then
    raise exception 'Falta es_gestor(): corre antes supabase-tramites.sql';
  end if;
  if to_regclass('public.archivos_huerfanos') is null then
    raise exception 'Falta archivos_huerfanos: corre antes supabase-tramites.sql';
  end if;
end
$comprueba$;

-- La pone supabase-revision-papeles.sql. Se repite aquí porque el
-- trigger de abajo la escribe, y en una base sin ella cada papel que se
-- subiera daría error.
alter table public.documentos add column if not exists revisado_en timestamptz;


-- ── 1 · La ficha del papel ────────────────────────────────────────────

create or replace function public.papel_lo_decide_el_equipo()
returns trigger
language plpgsql
as $sellados$
declare
  del_equipo boolean;
  carpeta    text;
begin
  if auth.uid() is null then
    return new;   -- la puerta de servicio
  end if;

  del_equipo := public.es_gestor();

  -- La ruta, para todos, cuando es nueva o cambia: en la carpeta del
  -- dueño de la ficha y sin subir de nivel.
  if tg_op = 'INSERT' or new.archivo is distinct from old.archivo then
    if new.archivo not like new.inversionista::text || '/%'
       or position('..' in new.archivo) > 0 then
      raise exception 'El archivo tiene que estar en la carpeta de su dueño'
        using errcode = 'check_violation';
    end if;
    carpeta := split_part(new.archivo, '/', 2);
    if carpeta = 'emitidos' and not del_equipo then
      raise exception 'Esa carpeta es del equipo del CIIP'
        using errcode = 'check_violation';
    end if;
  end if;

  if del_equipo then
    return new;
  end if;

  if tg_op = 'INSERT' then
    if new.estado <> 'cargado'
       or new.revisado_por is not null
       or new.revisado_en is not null
       or new.nota_revision <> '' then
      raise exception 'Un papel nuevo entra como cargado: lo revisa el equipo'
        using errcode = 'check_violation';
    end if;
    if new.tipo in ('resolucion', 'planilla_reserva_nombre', 'planilla_aranceles',
                    'planilla_publicacion', 'planilla_locti') then
      raise exception 'Ese papel lo emite el CIIP'
        using errcode = 'check_violation';
    end if;
    return new;
  end if;

  -- UPDATE: lo que es de la revisión se queda como estaba.
  if new.estado        is distinct from old.estado
     or new.revisado_por  is distinct from old.revisado_por
     or new.revisado_en   is distinct from old.revisado_en
     or new.nota_revision is distinct from old.nota_revision then
    raise exception 'La revisión de un papel la hace el equipo'
      using errcode = 'check_violation';
  end if;
  if new.tipo is distinct from old.tipo
     and new.tipo in ('resolucion', 'planilla_reserva_nombre', 'planilla_aranceles',
                      'planilla_publicacion', 'planilla_locti') then
    raise exception 'Ese papel lo emite el CIIP'
      using errcode = 'check_violation';
  end if;
  return new;
end
$sellados$;

drop trigger if exists documentos_lo_decide_el_equipo on public.documentos;
create trigger documentos_lo_decide_el_equipo
  before insert or update on public.documentos
  for each row execute function public.papel_lo_decide_el_equipo();

-- Y el que firma la revisión es quien la hace, cuando la hace: el panel
-- mandaba revisado_por y revisado_en desde el navegador, y un gestor
-- podía firmar a nombre de otro o con otra fecha. También la observación
-- (25-9-2026): el gestor deja una nota sin tocar el estado, y esa nota
-- también es una revisión con su autor y su hora.
create or replace function public.papel_firma_la_revision()
returns trigger
language plpgsql
as $sellados$
begin
  if auth.uid() is null then
    return new;
  end if;
  if new.estado is distinct from old.estado
     or new.nota_revision is distinct from old.nota_revision then
    new.revisado_por := auth.uid();
    new.revisado_en  := now();
  end if;
  return new;
end
$sellados$;

drop trigger if exists documentos_firma_la_revision on public.documentos;
create trigger documentos_firma_la_revision
  before update on public.documentos
  for each row execute function public.papel_firma_la_revision();

-- Lo que se anota como huérfano tiene que ser de la carpeta del dueño:
-- las fichas viejas, de antes de esta comprobación, podrían apuntar a
-- otra, y el barrendero borra con la clave de servidor.
create or replace function public.apuntar_el_huerfano()
returns trigger
language plpgsql
security definer
set search_path = public
as $sellados$
begin
  if old.archivo is null or old.archivo = ''
     or old.archivo not like old.inversionista::text || '/%'
     or position('..' in old.archivo) > 0 then
    return old;
  end if;

  insert into public.archivos_huerfanos (cubo, ruta, de_quien)
  values ('recaudos', old.archivo, old.inversionista)
  on conflict (cubo, ruta) do nothing;

  return old;
end
$sellados$;


-- ── 2 · El cubo ───────────────────────────────────────────────────────
-- Con el bloqueo ya puesto (8-10-2026): idénticas a las de
-- supabase-tramites-y-bloqueo.sql, para que volver a correr este archivo
-- suelto no le devuelva la subida a una cuenta bloqueada.

drop policy if exists "recaudos: subir a su carpeta" on storage.objects;
create policy "recaudos: subir a su carpeta" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'recaudos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.foldername(name))[2] is distinct from 'emitidos'
    and not public.esta_bloqueado()
  );

-- Reemplazar solo la foto: es el único upsert del panel. Todo lo demás
-- se sube con un nombre nuevo cada vez.
drop policy if exists "recaudos: reemplazar en su carpeta" on storage.objects;
create policy "recaudos: reemplazar en su carpeta" on storage.objects
  for update to authenticated
  using      (bucket_id = 'recaudos' and name = auth.uid()::text || '/perfil/foto'
              and not public.esta_bloqueado())
  with check (bucket_id = 'recaudos' and name = auth.uid()::text || '/perfil/foto'
              and not public.esta_bloqueado());

drop policy if exists "recaudos: borrar de su carpeta" on storage.objects;
create policy "recaudos: borrar de su carpeta" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'recaudos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.foldername(name))[2] is distinct from 'emitidos'
    and not exists (select 1 from public.documentos d
                     where d.archivo = storage.objects.name
                       and d.estado = 'validado')
    and not public.esta_bloqueado()
  );


-- ── 3 · La verificación ───────────────────────────────────────────────

create or replace function public.verificar_documento(huella_hex text)
returns table (
  consta       boolean,
  tipo         text,
  validado_el  timestamptz,
  vence_el     date,
  vigente      boolean
)
language sql
stable
security definer
set search_path = public
as $sellados$
  select
    true,
    coalesce(td.nombre, d.tipo),
    d.actualizado_en,
    d.vence_el,
    (d.vence_el is null or d.vence_el >= current_date)
  from public.documentos d
  left join public.tipos_documento td on td.codigo = d.tipo
  where d.huella = lower(trim(huella_hex))
    and d.estado = 'validado'
    and split_part(d.archivo, '/', 2) = 'emitidos'
  limit 1;
$sellados$;

comment on function public.verificar_documento(text) is
  'Dice si un documento que emitió el CIIP consta, sin revelar de quién es';

revoke all on function public.verificar_documento(text) from public;
grant execute on function public.verificar_documento(text) to anon, authenticated;

-- ====================================================================
--  46 / 105   supabase-tramites-y-bloqueo.sql
-- ====================================================================

-- ══════════════════════════════════════════════════════════════════════
--  LO DEL CIIP EN UN TRÁMITE, Y EL BLOQUEO ENTERO
--  Revisión de seguridad del 25 de septiembre de 2026, paso 2
-- ══════════════════════════════════════════════════════════════════════
--
--  QUÉ ESTABA ABIERTO
--
--  1. Un trámite tiene columnas que son del CIIP -el gestor, el banco, el
--     expediente del ente, las fechas- y la política de edición del
--     inversionista no las distinguía de las suyas. Con el borrador en la
--     mano, desde la consola:
--
--         sb.from('tramites').update({creado_en: '2020-01-01',
--           gestor: '<uuid>', banco: '<codigo>'}).eq('id', miId)
--
--     se colaba al principio de la cola (se ordena por creado_en), se
--     asignaba el gestor que quisiera o lo sacaba de «sin asignar», y
--     dejaba una fecha de envío falsa: registrar_evento_tramite() solo la
--     pone si está vacía. Al crear el trámite pasaba lo mismo, y además
--     podía colgarlo (viene_de) de la constitución de otra persona, con lo
--     que a esa persona ya no se le abría su protocolización.
--
--  2. El bloqueo de cuentas cortaba trámites, documentos y citas, pero no
--     el resto: una cuenta bloqueada seguía escribiendo en los hilos, las
--     consultas, su empresa, el pliego y el cubo de archivos.
--
--  QUÉ CAMBIA
--
--  · Cuando escribe el inversionista, las columnas del CIIP se quedan como
--    estaban (al crear: vacías, y creado_en la hora de la base). No da
--    error: las deja como estaban y sigue. Así el panel no cambia en nada
--    y la fecha de envío la sigue sellando registrar_evento_tramite().
--    El trigger se llama tramite_columnas_del_ciip para correr ANTES que
--    tramite_historial_update (Postgres los ordena por nombre): si fuera
--    después, borraría la fecha de envío que aquél acaba de poner.
--  · viene_de solo puede apuntar a un trámite de la misma persona.
--  · corta_si_bloqueado() en las ocho tablas que faltaban, y las políticas
--    del cubo piden además que la cuenta no esté bloqueada.
--
--  QUÉ NO SE TOCA
--  · perfiles: el panel llama a tocar_visto() al entrar, que escribe ahí,
--    y una cuenta bloqueada vería un error en cada carga. Lo que importa
--    de perfiles -el rol y el bloqueo- ya lo guardan sus triggers.
--  · Lo que hace el equipo, la puerta de servicio (auth.uid() nulo) y lo
--    que escriben las funciones security definer (los tramos que se abren
--    solos al resolver): ahí current_user no es 'authenticated'.
--
--  Va DESPUÉS de supabase-bloqueo.sql (corta_si_bloqueado) y de
--  supabase-papeles-sellados.sql (redefine sus políticas del cubo). Se
--  puede correr más de una vez.
-- ══════════════════════════════════════════════════════════════════════

do $comprueba$
begin
  if to_regprocedure('public.corta_si_bloqueado()') is null
     or to_regprocedure('public.esta_bloqueado()') is null then
    raise exception 'Falta el bloqueo: corre antes supabase-bloqueo.sql';
  end if;
  if to_regprocedure('public.papel_lo_decide_el_equipo()') is null then
    raise exception 'Falta supabase-papeles-sellados.sql: va antes que éste';
  end if;
end
$comprueba$;

-- Las columnas que añadieron otros archivos. Si alguna falta, el trigger
-- de abajo daría error en cada trámite.
alter table public.tramites add column if not exists banco text references public.bancos_aliados(codigo);
alter table public.tramites add column if not exists viene_de uuid references public.tramites(id) on delete set null;
alter table public.tramites add column if not exists expediente_ente text;


-- ── 1 · Las columnas del CIIP ─────────────────────────────────────────

create or replace function public.tramite_columnas_del_ciip()
returns trigger
language plpgsql
as $tyb$
begin
  if auth.uid() is null
     or current_user <> 'authenticated'
     or public.es_gestor() then
    return new;
  end if;

  if tg_op = 'INSERT' then
    new.gestor          := null;
    new.banco           := null;
    new.expediente_ente := null;
    new.creado_en       := now();
    new.enviado_en      := null;
    new.resuelto_en     := null;
    if new.viene_de is not null and not exists (
         select 1 from public.tramites o
          where o.id = new.viene_de and o.inversionista = new.inversionista) then
      new.viene_de := null;
    end if;
    return new;
  end if;

  new.inversionista   := old.inversionista;
  new.tipo            := old.tipo;
  new.gestor          := old.gestor;
  new.banco           := old.banco;
  new.expediente_ente := old.expediente_ente;
  new.viene_de        := old.viene_de;
  new.creado_en       := old.creado_en;
  new.enviado_en      := old.enviado_en;
  new.resuelto_en     := old.resuelto_en;
  return new;
end
$tyb$;

drop trigger if exists tramite_columnas_del_ciip on public.tramites;
create trigger tramite_columnas_del_ciip
  before insert or update on public.tramites
  for each row execute function public.tramite_columnas_del_ciip();


-- ── 2 · El bloqueo, en todo lo que escribe el inversionista ───────────

do $tyb$
declare
  t text;
begin
  foreach t in array array['tramite_mensajes', 'cita_mensajes', 'consultas',
                           'consulta_mensajes', 'tramite_documentos', 'tramite_entes',
                           'empresas', 'pliego_aceptaciones'] loop
    if to_regclass('public.' || t) is null then
      raise notice 'No existe public.%: se salta', t;
      continue;
    end if;
    execute format('drop trigger if exists %I on public.%I', t || '_bloqueo', t);
    execute format('create trigger %I before insert or update or delete on public.%I '
                   'for each row execute function public.corta_si_bloqueado()',
                   t || '_bloqueo', t);
  end loop;
end
$tyb$;

-- El cubo: las tres de supabase-papeles-sellados.sql, con el bloqueo.
drop policy if exists "recaudos: subir a su carpeta" on storage.objects;
create policy "recaudos: subir a su carpeta" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'recaudos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.foldername(name))[2] is distinct from 'emitidos'
    and not public.esta_bloqueado()
  );

drop policy if exists "recaudos: reemplazar en su carpeta" on storage.objects;
create policy "recaudos: reemplazar en su carpeta" on storage.objects
  for update to authenticated
  using      (bucket_id = 'recaudos' and name = auth.uid()::text || '/perfil/foto'
              and not public.esta_bloqueado())
  with check (bucket_id = 'recaudos' and name = auth.uid()::text || '/perfil/foto'
              and not public.esta_bloqueado());

drop policy if exists "recaudos: borrar de su carpeta" on storage.objects;
create policy "recaudos: borrar de su carpeta" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'recaudos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and (storage.foldername(name))[2] is distinct from 'emitidos'
    -- 21-10-2026: ningún archivo que tenga ficha, esté como esté. Antes
    -- solo se protegían los validados, y un recaudo «cargado» o
    -- «rechazado» de una solicitud ya enviada se podía borrar del cubo y
    -- volver a subir con la misma ruta: el gestor veía otro PDF y
    -- papel_en_marcha_no_cambia no se enteraba. El panel siempre borra
    -- primero la ficha (borraDeVerdad) y el archivo después, así que
    -- borrar lo propio sigue funcionando; un huérfano lo recoge el
    -- barrendero.
    and not exists (select 1 from public.documentos d
                     where d.archivo = storage.objects.name)
    and not public.esta_bloqueado()
  );

-- ====================================================================
--  47 / 105   supabase-tope-ia.sql
-- ====================================================================

-- ══════════════════════════════════════════════════════════════════════
--  EL TOPE DEL ASISTENTE Y DEL LECTOR, EN LA BASE
--  Revisión de seguridad del 25 de septiembre de 2026
-- ══════════════════════════════════════════════════════════════════════
--
--  QUÉ PASABA
--  api/asistente.js y api/leer-documento.js contaban las preguntas de cada
--  persona en la memoria de la función. Vercel tiene varias copias a la vez
--  y las apaga cuando no se usan: cada copia nueva empezaba en cero, y unas
--  cuantas peticiones en paralelo multiplicaban el tope. Lo decían ellos
--  mismos: «un tope de verdad va en una tabla de la base».
--
--  QUÉ HACE
--  gasta_uso_ia('asistente' | 'lector') apunta una pregunta de quien llama
--  en la hora en curso y contesta si todavía cabía. Los topes viven AQUÍ y
--  no los manda nadie de fuera: 40 preguntas por hora al asistente y 20
--  papeles por hora al lector, los mismos que había en los dos archivos.
--  Quien la llame por su cuenta solo gasta su propio cupo.
--
--  Las funciones de Vercel la llaman con el token del usuario. Si esta
--  función todavía no existe en la base, vuelven al contador en memoria de
--  antes: correr este archivo mejora el tope, no correrlo no rompe nada.
--
--  Se puede correr más de una vez.
-- ══════════════════════════════════════════════════════════════════════

create table if not exists public.uso_ia (
  usuario uuid        not null references auth.users(id) on delete cascade,
  pieza   text        not null,
  hora    timestamptz not null,
  usos    integer     not null default 1,
  primary key (usuario, pieza, hora),
  constraint uso_ia_pieza_valida check (pieza in ('asistente', 'lector', 'traductor'))
);

comment on table public.uso_ia is
  'Cuántas veces usó cada persona el asistente y el lector en cada hora. Solo la escribe gasta_uso_ia()';

-- Sin políticas: nadie la lee ni la escribe desde fuera. Solo la función.
-- Una tabla de antes del traductor tiene la regla de dos piezas.
alter table public.uso_ia drop constraint if exists uso_ia_pieza_valida;
alter table public.uso_ia add constraint uso_ia_pieza_valida
  check (pieza in ('asistente', 'lector', 'traductor'));

alter table public.uso_ia enable row level security;
revoke all on public.uso_ia from anon, authenticated;

create or replace function public.gasta_uso_ia(p_pieza text)
returns boolean
language plpgsql
security definer
set search_path = public
as $tope$
declare
  yo   uuid := auth.uid();
  tope integer;
  n    integer;
begin
  if yo is null then
    raise exception 'Hace falta haber entrado' using errcode = '42501';
  end if;

  if public.esta_bloqueado() then
    return false;
  end if;

  -- Las tres definiciones (tope-ia, qa-admin, traduccion-chat) son la
  -- misma desde el 8-10-2026: volver a correr una suelta no puede quitar
  -- el bloqueo ni dejar sin tope al traductor.
  tope := case p_pieza when 'asistente' then 40
                       when 'lector'    then 20
                       when 'traductor' then 60 end;
  if tope is null then
    raise exception 'pieza desconocida: %', p_pieza;
  end if;

  -- Lo de hace más de dos días ya no cuenta para nada.
  delete from public.uso_ia where usuario = yo and hora < now() - interval '2 days';

  -- Con el cupo lleno el UPDATE no se hace y no devuelve fila: n queda nulo.
  insert into public.uso_ia as u (usuario, pieza, hora, usos)
  values (yo, p_pieza, date_trunc('hour', now()), 1)
  on conflict (usuario, pieza, hora)
  do update set usos = u.usos + 1 where u.usos < tope
  returning usos into n;

  return n is not null;
end
$tope$;

revoke all on function public.gasta_uso_ia(text) from public, anon;
grant execute on function public.gasta_uso_ia(text) to authenticated;

-- ====================================================================
--  48 / 105   supabase-confirma-paso.sql
-- ====================================================================

-- ══════════════════════════════════════════════════════════════════════
--  CONFIRMA UN PASO: «ya me registré»
--  Se puede correr más de una vez.
-- ══════════════════════════════════════════════════════════════════════
--  Franklin Reyes, 25-9-2026: «el 2 se marca cuando el usuario confirma
--  que registró el usuario». La marca va en tramites.datos, pero no puede
--  ser un update a secas: con la visa en revisión el inversionista no toca
--  su trámite (la política solo le deja el borrador o el devuelto), el
--  update cambiaría cero filas y PostgREST contestaría que todo bien.
--
--  Así que va por esta función: comprueba que el trámite es tuyo y que está
--  en marcha, y levanta una excepción si no tocó ninguna fila. Acepta UNA
--  sola llave, a propósito: con el nombre libre, el inversionista podría
--  escribir lo que quisiera dentro de datos.
--
--  Vivía en CORRER-HOY-2026-09-25.sql; desde el mismo día está aquí, que
--  es de donde sale TODO-EN-ORDEN.sql.
-- ══════════════════════════════════════════════════════════════════════

create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
-- Supabase le da EXECUTE a anon en cada función nueva por su cuenta: el
-- revoke de PUBLIC no lo quita. Sin sesión no haría nada (auth.uid() es
-- nulo y no encuentra trámite), pero no tiene por qué poder llamarla.
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;

-- ====================================================================
--  49 / 105   supabase-cancelar.sql
-- ====================================================================

-- ══════════════════════════════════════════════════════════════════════
--  CANCELAR UNA SOLICITUD, MIENTRAS NO HAYA SALIDO DEL CIIP
--  Se puede correr más de una vez.
-- ══════════════════════════════════════════════════════════════════════
--  Franklin Reyes, 25-9-2026: «necesito que el inversionista pueda cancelar
--  un trámite si el trámite aún no ha pasado al ente». Mientras el
--  expediente está en el CIIP -recibido, en revisión, devuelto- cancelarlo
--  no le cuesta nada a nadie. Una vez ante el organismo hay un número de
--  entrada fuera, y decir aquí «cancelada» no lo retiraría de allí.
--
--  El inversionista no escribe 'cancelado' a mano: su política de edición
--  no lo deja. Va por cancela_tramite(), que comprueba que el trámite es
--  suyo y que está donde puede cancelarse, y revienta si no tocó ninguna
--  fila. Un expediente cancelado no se descancela: la escalera no deja
--  volver. Y no cuenta como «vivo»: supabase-una-viva.sql solo mira
--  enviado, en_revision y ante_el_ente, así que se puede volver a pedir.
--
--  Vivía en CORRER-CANCELAR-UN-TRAMITE.sql (9f3386b); desde el mismo día
--  está aquí, que es de donde sale TODO-EN-ORDEN.sql. Va al final: redefine
--  tramites_solo_la_escalera(), que nace en supabase-tramites.sql.
--
--  Y el ADMINISTRADOR también cancela, sea de quien sea el trámite
--  (Franklin Reyes, 2-11-2026: «no puedo cancelar… es que estoy como
--  administrador»). El gestor no: sigue siendo solo del dueño o del admin.
-- ══════════════════════════════════════════════════════════════════════

alter table public.tramites drop constraint if exists tramites_estado_valido;
alter table public.tramites add constraint tramites_estado_valido
  check (estado in ('borrador', 'enviado', 'en_revision', 'devuelto',
                    'ante_el_ente', 'resuelto', 'cancelado'));

create or replace function public.tramites_solo_la_escalera()
returns trigger
language plpgsql
as $$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;

  if auth.uid() is null then
    return new;
  end if;

  if not (
       (old.estado = 'borrador'     and new.estado = 'enviado')
    or (old.estado = 'devuelto'     and new.estado = 'enviado')
    or (old.estado = 'enviado'      and new.estado in ('en_revision','devuelto'))
    or (old.estado = 'en_revision'  and new.estado in ('ante_el_ente','devuelto'))
    or (old.estado = 'ante_el_ente' and new.estado in ('resuelto','devuelto'))
    or (old.estado in ('borrador','enviado','en_revision','devuelto')
        and new.estado = 'cancelado')
  ) then
    raise exception 'Un trámite no pasa de "%" a "%"', old.estado, new.estado
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

create or replace function public.cancela_tramite(p_tramite uuid)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  update public.tramites
     set estado = 'cancelado'
   where id = p_tramite
     and (inversionista = auth.uid() or public.es_admin())
     and estado in ('borrador', 'enviado', 'en_revision', 'devuelto')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo cancelar';
  end if;

  return fila;
end $$;

revoke all on function public.cancela_tramite(uuid) from public;
-- Supabase le da EXECUTE a anon a cada función nueva: el revoke de PUBLIC
-- no lo quita. Sin sesión no haría nada, pero no tiene por qué poder llamarla.
revoke execute on function public.cancela_tramite(uuid) from anon;
grant execute on function public.cancela_tramite(uuid) to authenticated;

-- ====================================================================
--  50 / 105   supabase-importe-del-dia.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL IMPORTE DEL DÍA
--  Va DESPUÉS de supabase-papeles-sellados.sql. Se puede correr más de una
--  vez. Sin correrlo el panel no se rompe: el gestor no puede dejar el
--  importe y el inversionista no puede enganchar su comprobante.
-- ═══════════════════════════════════════════════════════════════════════

-- Los dos papeles. Sirven para cualquier trámite: lo que cambia de uno a
-- otro es en qué paso se piden, y eso va en la tabla de abajo.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('importe_dia',      'Importe del día para pagar',                 false),
  ('pago_importe_dia', 'Comprobante del pago del importe del día',   false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- El monto, escrito por el gestor al subir el importe. Texto y no número:
-- lo que se copia es lo que dice el papel, con su moneda.
alter table public.documentos add column if not exists monto text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'documentos_monto_corto') then
    alter table public.documentos add constraint documentos_monto_corto
      check (monto is null or char_length(monto) <= 60);
  end if;
end $$;

-- QUÉ TRÁMITES LLEVAN IMPORTE DEL DÍA, Y EN QUÉ ESTADOS. Engancharlo a un
-- trámite nuevo es una fila aquí (y su entrada en IMPORTE_DEL_DIA de
-- panel.js); ninguna política hay que tocarla.
create table if not exists public.importe_del_dia_pasos (
  tipo_tramite text primary key references public.tipos_tramite(codigo) on delete cascade,
  estados      text[] not null default array['enviado','en_revision','ante_el_ente']
);
alter table public.importe_del_dia_pasos enable row level security;
drop policy if exists "importe del dia: lo lee quien entra" on public.importe_del_dia_pasos;
create policy "importe del dia: lo lee quien entra" on public.importe_del_dia_pasos
  for select to authenticated using (true);
drop policy if exists "importe del dia: lo cambia el admin" on public.importe_del_dia_pasos;
create policy "importe del dia: lo cambia el admin" on public.importe_del_dia_pasos
  for all using (public.es_admin()) with check (public.es_admin());

-- Hoy, en Caracas. La medianoche que manda es la de allí, no la del
-- servidor (UTC): a las 8 de la noche en Caracas el servidor ya va por
-- mañana.
create or replace function public.hoy_en_caracas()
returns date
language sql
stable
as $$ select (now() at time zone 'America/Caracas')::date $$;

-- Si este trámite, en este estado, lleva importe del día. security definer
-- para que las políticas la usen sin depender de la RLS de la tabla.
create or replace function public.importe_del_dia_abierto(p_tipo text, p_estado text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.importe_del_dia_pasos
     where tipo_tramite = p_tipo and p_estado = any(estados)
  )
$$;

-- Si el trámite tiene un importe de HOY. Es lo que decide la caducidad: el
-- de ayer sigue en la bóveda, pero ya no deja pagar contra él.
create or replace function public.importe_del_dia_vigente(p_tramite uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
      join public.tramites t   on t.id = td.tramite
     where td.tramite = p_tramite
       and d.tipo = 'importe_dia'
       and d.estado = 'validado'
       and d.inversionista = t.inversionista
       and (d.creado_en at time zone 'America/Caracas')::date = public.hoy_en_caracas()
  )
$$;

-- VARIOS IMPORTES EN UN TRÁMITE (28-9-2026). El registro de marca paga
-- tres o cuatro, uno por etapa. Cada importe y cada comprobante llevan el
-- nombre de su etapa en paso_importe, y el comprobante solo se engancha
-- contra un importe de hoy DEL MISMO nombre: el pago de la búsqueda de
-- antecedentes no sirve para el derecho de marca. Sin nombre (nulo en los
-- dos) es el caso de siempre, un importe por trámite.
alter table public.documentos add column if not exists paso_importe text;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'documentos_paso_importe_corto') then
    alter table public.documentos add constraint documentos_paso_importe_corto
      check (paso_importe is null or char_length(paso_importe) <= 40);
  end if;
end $$;

create or replace function public.importe_del_dia_vigente(p_tramite uuid, p_paso text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
      join public.tramites t   on t.id = td.tramite
     where td.tramite = p_tramite
       and d.tipo = 'importe_dia'
       and d.estado = 'validado'
       and d.inversionista = t.inversionista
       and d.paso_importe is not distinct from p_paso
       and (d.creado_en at time zone 'America/Caracas')::date = public.hoy_en_caracas()
  )
$$;

revoke all on function public.importe_del_dia_abierto(text, text) from public, anon;
revoke all on function public.importe_del_dia_vigente(uuid) from public, anon;
revoke all on function public.importe_del_dia_vigente(uuid, text) from public, anon;
grant execute on function public.importe_del_dia_abierto(text, text) to authenticated;
grant execute on function public.importe_del_dia_vigente(uuid) to authenticated;
grant execute on function public.importe_del_dia_vigente(uuid, text) to authenticated;

-- El importe lo sube el equipo, entra 'validado' y va a 'emitidos', como el
-- documento para pagar la reserva del nombre.
drop policy if exists "documentos: el equipo sube el importe del dia" on public.documentos;
create policy "documentos: el equipo sube el importe del dia" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'importe_dia' and estado = 'validado');

drop policy if exists "adjuntos: el equipo engancha el importe del dia" on public.tramite_documentos;
create policy "adjuntos: el equipo engancha el importe del dia" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'importe_dia'
         and public.importe_del_dia_abierto(t.tipo, t.estado)
    )
  );

-- El comprobante: solo en su trámite, en los estados del paso y con un
-- importe de hoy colgado, del mismo nombre que el comprobante. Una vez
-- enganchado se queda: la medianoche caduca el importe, no el pago hecho
-- contra él.
drop policy if exists "adjuntos: el pago del importe del dia, con importe de hoy" on public.tramite_documentos;
create policy "adjuntos: el pago del importe del dia, con importe de hoy" on public.tramite_documentos
  for insert
  with check (
    exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and t.inversionista = auth.uid()
         and d.inversionista = auth.uid()
         and d.tipo = 'pago_importe_dia'
         and public.importe_del_dia_abierto(t.tipo, t.estado)
         and public.importe_del_dia_vigente(t.id, d.paso_importe)
    )
  );

-- El importe es papel del CIIP: el inversionista no lo crea, no le cambia
-- el monto ni la fecha. Y la fecha la pone la base, que es la que manda en
-- la caducidad. Trigger propio para no reescribir el de
-- supabase-papeles-sellados.sql.
create or replace function public.importe_del_dia_lo_pone_el_equipo()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'INSERT' and new.tipo = 'importe_dia' then
    new.creado_en := now();
  end if;
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.tipo = 'importe_dia' or (tg_op = 'UPDATE' and old.tipo = 'importe_dia') then
    raise exception 'Ese papel lo emite el CIIP'
      using errcode = 'check_violation';
  end if;
  return new;
end
$$;

drop trigger if exists documentos_importe_del_dia on public.documentos;
create trigger documentos_importe_del_dia
  before insert or update on public.documentos
  for each row execute function public.importe_del_dia_lo_pone_el_equipo();

-- OPCIONAL: LIMPIAR A LAS 12:00 AM CON pg_cron. No hace falta: lo vencido
-- ya se ve vencido y no deja pagar. Si se quiere además que desaparezca,
-- se activa pg_cron en Supabase (Database → Extensions) y se corre esto.
-- 04:00 UTC es la medianoche de Caracas. Solo se lleva los importes sin
-- pagar; borrar la ficha deja el archivo apuntado al barrendero.
--
-- select cron.schedule('importe-del-dia-caduca', '0 4 * * *', $cron$
--   delete from public.documentos d
--    where d.tipo = 'importe_dia'
--      and (d.creado_en at time zone 'America/Caracas')::date < public.hoy_en_caracas()
--      and not exists (
--        select 1
--          from public.tramite_documentos td
--          join public.tramite_documentos tp on tp.tramite = td.tramite
--          join public.documentos p on p.id = tp.documento
--         where td.documento = d.id
--           and p.tipo = 'pago_importe_dia'
--           and p.estado <> 'rechazado'
--           and (tp.creado_en at time zone 'America/Caracas')::date
--             = (d.creado_en at time zone 'America/Caracas')::date
--      )
-- $cron$);
--
-- Para quitarlo: select cron.unschedule('importe-del-dia-caduca');

-- COMPROBACIÓN
--   select codigo from public.tipos_documento
--    where codigo in ('importe_dia', 'pago_importe_dia');            -- dos filas
--   select public.hoy_en_caracas();                                  -- la fecha de Caracas
--   select polname from pg_policy where polname like '%importe del dia%';  -- cinco filas

-- ====================================================================
--  51 / 105   supabase-traduccion.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA TRADUCCIÓN DE DOCUMENTOS (c17)
--  Va DESPUÉS de supabase-importe-del-dia.sql. Se puede correr más de una
--  vez.
-- ═══════════════════════════════════════════════════════════════════════

-- El importe del día sale en el paso 2, «Importe de traducción», mientras
-- la solicitud está recibida o en revisión. Los mismos estados que
-- IMPORTE_DEL_DIA.apostilla_documentos en panel.js.
insert into public.importe_del_dia_pasos (tipo_tramite, estados)
values ('apostilla_documentos', array['enviado','en_revision'])
on conflict (tipo_tramite) do update set estados = excluded.estados;

-- «Documento traducido» va detrás de «Comprobante de pago»: sin el
-- comprobante no se resuelve. Trigger propio, como el del SIDCAI.
create or replace function public.tramites_traduccion_con_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'apostilla_documentos' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;
  if not exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
     where td.tramite = new.id
       and d.tipo = 'pago_importe_dia'
       -- Uno rechazado no es un pago (8-10-2026, auditoría): como en libros.
       and d.estado <> 'rechazado'
  ) then
    raise exception 'La traducción no se resuelve sin el comprobante del pago del importe'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists tramites_traduccion_pago on public.tramites;
create trigger tramites_traduccion_pago
  before update on public.tramites
  for each row execute function public.tramites_traduccion_con_pago();

-- Las escaleras viejas (apostilla → traducción → legalización ante el
-- MPPRE) cambiadas desde «Editar textos» se quedarían pisando a las nuevas
-- paso por paso. Se van: las nuevas vienen de pasos.js.
delete from public.textos_panel
 where clave like '\_p.pasos.c17.%'
    or clave like '\_p.pasos.c17\_yaapostillado.%';

-- COMPROBACIÓN
--   select * from public.importe_del_dia_pasos where tipo_tramite = 'apostilla_documentos';
--   select tgname from pg_trigger where tgname = 'tramites_traduccion_pago';
--   select clave, idioma, texto from public.textos_panel where clave like '\_p.pasos.c17%';  -- ninguna

-- ====================================================================
--  52 / 105   supabase-firma-ciip.sql
-- ====================================================================

-- La constitución (c5): tras revisar los recaudos, el inversionista viene al
-- CIIP a entregar la carta del comisario, la certificación del inventario o
-- del capital y el inventario, y firma. Lo marca el equipo, y queda en
-- tramites.datos -> 'firma_ciip' con la fecha.
-- Se puede correr más de una vez. Necesita supabase-tramites.sql (es_gestor).

create or replace function public.marca_firma_ciip(p_tramite uuid, p_hecha boolean default true)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if not public.es_gestor() then
    raise exception 'la firma en el CIIP la marca el equipo';
  end if;

  update public.tramites
     set datos = case when p_hecha
                      then coalesce(datos, '{}'::jsonb)
                           || jsonb_build_object('firma_ciip',
                                to_char(now() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'))
                      else coalesce(datos, '{}'::jsonb) - 'firma_ciip'
                 end
   where id = p_tramite
     and tipo = 'constitucion'
     and estado in ('enviado', 'en_revision')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar la firma';
  end if;

  return fila;
end $$;

revoke all on function public.marca_firma_ciip(uuid, boolean) from public;
revoke execute on function public.marca_firma_ciip(uuid, boolean) from anon;
grant execute on function public.marca_firma_ciip(uuid, boolean) to authenticated;

-- La marca es del equipo: el inversionista no la pone escribiendo en datos,
-- y al reenviar un devuelto -que reescribe datos entero- no la borra.
create or replace function public.tramite_firma_la_marca_el_ciip()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() is null
     or current_user <> 'authenticated'
     or public.es_gestor() then
    return new;
  end if;

  if tg_op = 'UPDATE' and old.datos ? 'firma_ciip' then
    new.datos := coalesce(new.datos, '{}'::jsonb)
                 || jsonb_build_object('firma_ciip', old.datos -> 'firma_ciip');
  elsif new.datos ? 'firma_ciip' then
    new.datos := new.datos - 'firma_ciip';
  end if;

  return new;
end $$;

drop trigger if exists tramite_firma_ciip on public.tramites;
create trigger tramite_firma_ciip
  before insert or update on public.tramites
  for each row execute function public.tramite_firma_la_marca_el_ciip();

-- Comprobación: la función y el disparador.
select proname from pg_proc where proname in ('marca_firma_ciip', 'tramite_firma_la_marca_el_ciip');
select tgname from pg_trigger where tgname = 'tramite_firma_ciip';

-- ====================================================================
--  53 / 105   supabase-entes-clave.sql
-- ====================================================================

-- El IVSS y el INCES no mandan un código: mandan usuario y contraseña. El
-- usuario va en tramite_entes.codigo, como el código de los demás, y la
-- contraseña en su propia columna. La leen las mismas políticas de la fila:
-- el inversionista dueño de la solicitud y el equipo, nadie más.
-- Se puede correr más de una vez. Va después de supabase-entes-parafiscales.sql.

alter table public.tramite_entes add column if not exists clave text;

alter table public.tramite_entes drop constraint if exists tramite_entes_clave_tope;
alter table public.tramite_entes add constraint tramite_entes_clave_tope
  check (clave is null or length(clave) <= 200);

-- Solo esos dos entes llevan contraseña.
alter table public.tramite_entes drop constraint if exists tramite_entes_clave_solo_ivss_inces;
alter table public.tramite_entes add constraint tramite_entes_clave_solo_ivss_inces
  check (clave is null or ente in ('ivss', 'inces'));

-- La contraseña solo hace falta hasta que la inscripción queda lista: en
-- cuanto el equipo la da por lista, se borra sola (Franklin, 28-9-2026).
-- Lo hace la base y no el panel, para que ningún camino se la salte.
create or replace function public.tramite_entes_borra_clave()
returns trigger language plpgsql as $$
begin
  if new.estado = 'listo' then
    new.clave := null;
  end if;
  return new;
end;
$$;

drop trigger if exists tramite_entes_borra_clave on public.tramite_entes;
create trigger tramite_entes_borra_clave
  before insert or update on public.tramite_entes
  for each row execute function public.tramite_entes_borra_clave();

update public.tramite_entes set clave = null where estado = 'listo' and clave is not null;

-- Sin sesión no hay fila que leer (las políticas son por dueño o equipo),
-- pero la columna tampoco tiene por qué estar a su alcance.
revoke all on public.tramite_entes from anon;

-- Comprobación: la columna, y las cuatro políticas de siempre.
select column_name, data_type from information_schema.columns
 where table_schema = 'public' and table_name = 'tramite_entes' and column_name = 'clave';
select policyname, cmd from pg_policies where tablename = 'tramite_entes' order by policyname;

-- ====================================================================
--  54 / 105   supabase-chat-del-paso.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL CHAT DE UN PASO
--  Va DESPUÉS de supabase-hilo.sql (tramite_mensajes) y ANTES de
--  supabase-marca.sql, cuyo habilita_contestacion() escribe en el chat.
--  Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 9 de octubre de 2026: en el registro de marca, cuando
--  el SAPI devuelve el registro y el gestor habilita la contestación, el
--  inversionista habla con su gestor en un chat que vive SOLO en ese paso,
--  y el gestor le puede mandar documentos por ahí.
--
--  CÓMO QUEDA
--  ───────────────────────────────────────────────────────────────────────
--  · Es la misma conversación del expediente (tramite_mensajes), con una
--    columna más: paso. Null es la conversación de siempre; 'contestacion'
--    es el chat de la contestación de la marca. Así hereda todo lo que ya
--    tiene el hilo: la firma de la base, los adjuntos a la bóveda del
--    inversionista, la traducción y que un mensaje no se borra.
--  · Solo se escribe en él con la contestación habilitada, y se cierra
--    cuando la marca pasa a registro (o se resuelve o se cancela): lo dicho
--    se sigue leyendo, pero ya no se contesta ahí.
--  · El anuncio con el que el gestor habilita la contestación es su primer
--    mensaje (supabase-marca.sql).
-- ═══════════════════════════════════════════════════════════════════════

alter table public.tramite_mensajes add column if not exists paso text;

alter table public.tramite_mensajes drop constraint if exists mensaje_paso_valido;
alter table public.tramite_mensajes add constraint mensaje_paso_valido
  check (paso is null or paso in ('contestacion'));

comment on column public.tramite_mensajes.paso is
  'De qué chat es: null, la conversación del expediente; contestacion, el chat de la contestación de la marca';

create index if not exists mensajes_por_paso
  on public.tramite_mensajes (tramite, paso, creado_en);

-- Cuándo se puede escribir en el chat de un paso. Security definer para
-- leer el trámite tal como es, no como lo deja ver RLS.
create or replace function public.mensaje_del_paso()
returns trigger
language plpgsql
security definer
set search_path = public
as $chat$
declare
  t public.tramites;
begin
  if new.paso is null then
    return new;
  end if;
  select * into t from public.tramites where id = new.tramite;
  if new.paso = 'contestacion' then
    if t.tipo is distinct from 'marca'
       or not coalesce((t.datos -> 'pasos_ciip') ? 'contestacion', false) then
      raise exception 'El chat de la contestación no está abierto'
        using errcode = 'check_violation';
    end if;
    if coalesce((t.datos -> 'pasos_ciip') ? 'en_registro', false)
       or t.estado in ('resuelto', 'cancelado') then
      raise exception 'El chat de la contestación ya se cerró'
        using errcode = 'check_violation';
    end if;
  end if;
  return new;
end
$chat$;

drop trigger if exists mensajes_del_paso on public.tramite_mensajes;
create trigger mensajes_del_paso
  before insert on public.tramite_mensajes
  for each row execute function public.mensaje_del_paso();

-- COMPROBACIÓN
--   select column_name from information_schema.columns
--    where table_name = 'tramite_mensajes' and column_name = 'paso';   -- una fila
--   select tgname from pg_trigger where tgname = 'mensajes_del_paso';  -- una fila

-- ====================================================================
--  55 / 105   supabase-marca.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL REGISTRO DE MARCA POR ETAPAS (c8)
--  Va DESPUÉS de supabase-importe-del-dia.sql. Se puede correr más de una
--  vez. Sin él el panel no se rompe: la escalera de la marca se queda
--  quieta en el paso en que esté.
-- ═══════════════════════════════════════════════════════════════════════

do $comprueba$
begin
  if to_regprocedure('public.importe_del_dia_vigente(uuid, text)') is null then
    raise exception 'Falta supabase-importe-del-dia.sql: va antes que éste';
  end if;
end
$comprueba$;

-- Los dos papeles que el CIIP le manda al inversionista por el camino.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('busqueda_antecedentes', 'Búsqueda de antecedentes de la marca', false),
  ('certificado_marca',     'Certificado de registro de marca',     false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- Cuál de los cuatro importes toca lo dice la escalera; aquí basta con el
-- estado, y el nombre de cada importe lo cuadra
-- importe_del_dia_vigente(tramite, paso). Desde el 8-10-2026 (Franklin
-- Reyes) el de la búsqueda de antecedentes se sube ANTES de presentarla,
-- con la solicitud recibida o en revisión, y la búsqueda empieza con su
-- comprobante: por eso valen los tres estados.
insert into public.importe_del_dia_pasos (tipo_tramite, estados)
values ('marca', array['enviado', 'en_revision', 'ante_el_ente'])
on conflict (tipo_tramite) do update set estados = excluded.estados;

-- El equipo sube los dos papeles, ya validados, a la bóveda del
-- inversionista, y los cuelga de SU solicitud de marca.
drop policy if exists "documentos: el equipo manda los papeles de la marca" on public.documentos;
create policy "documentos: el equipo manda los papeles de la marca" on public.documentos
  for insert
  with check (public.es_gestor()
              and tipo in ('busqueda_antecedentes', 'certificado_marca')
              and estado = 'validado');

drop policy if exists "adjuntos: el equipo cuelga los papeles de la marca" on public.tramite_documentos;
create policy "adjuntos: el equipo cuelga los papeles de la marca" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and t.tipo = 'marca'
         and d.tipo in ('busqueda_antecedentes', 'certificado_marca')
    )
  );

-- Esos dos los emite el CIIP: el inversionista no los crea ni convierte
-- otro papel en ellos. Y el nombre del importe al que paga un comprobante
-- no lo cambia después de colgarlo.
create or replace function public.marca_papeles_del_ciip()
returns trigger
language plpgsql
as $marca$
begin
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.tipo in ('busqueda_antecedentes', 'certificado_marca')
     or (tg_op = 'UPDATE' and old.tipo in ('busqueda_antecedentes', 'certificado_marca')) then
    raise exception 'Ese papel lo emite el CIIP'
      using errcode = 'check_violation';
  end if;
  if tg_op = 'UPDATE' then
    new.paso_importe := old.paso_importe;
  end if;
  return new;
end
$marca$;

drop trigger if exists documentos_marca_del_ciip on public.documentos;
create trigger documentos_marca_del_ciip
  before insert or update on public.documentos
  for each row execute function public.marca_papeles_del_ciip();

-- LOS PASOS APUNTADOS. Viven en tramites.datos: pasos_ciip (nombre →
-- fecha), anuncio y anuncio_en. Quien no es del equipo no los toca, ni
-- siquiera al reenviar el formulario de una devuelta, que reescribe datos
-- entero: se le devuelven los que había. Las funciones de abajo son
-- security definer y escriben como su dueño, no como 'authenticated'.
create or replace function public.pasos_del_ciip_se_quedan()
returns trigger
language plpgsql
as $marca$
declare
  guarda jsonb;
begin
  if auth.uid() is null
     or current_user <> 'authenticated'
     or public.es_gestor() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.datos := coalesce(new.datos, '{}'::jsonb) - 'pasos_ciip' - 'anuncio' - 'anuncio_en';
    return new;
  end if;
  guarda := jsonb_strip_nulls(jsonb_build_object(
    'pasos_ciip', old.datos -> 'pasos_ciip',
    'anuncio',    old.datos -> 'anuncio',
    'anuncio_en', old.datos -> 'anuncio_en'));
  new.datos := (coalesce(new.datos, '{}'::jsonb) - 'pasos_ciip' - 'anuncio' - 'anuncio_en') || guarda;
  return new;
end
$marca$;

drop trigger if exists tramites_pasos_del_ciip on public.tramites;
create trigger tramites_pasos_del_ciip
  before insert or update on public.tramites
  for each row execute function public.pasos_del_ciip_se_quedan();

-- La hora, escrita como la escribe confirma_paso().
create or replace function public.marca_ahora()
returns text
language sql
stable
as $$ select to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF') $$;

-- Al colgarse un papel de una marca, la base apunta su paso: el importe y
-- el comprobante de cada etapa por su nombre, y los dos papeles del CIIP.
-- Una vez: el primero que llega pone la fecha.
create or replace function public.marca_apunta_el_papel()
returns trigger
language plpgsql
security definer
set search_path = public
as $marca$
declare
  papel public.documentos;
  suTipo text;
  clave text;
begin
  select * into papel from public.documentos where id = new.documento;
  select tipo into suTipo from public.tramites where id = new.tramite;
  if suTipo is distinct from 'marca' or papel.id is null then
    return new;
  end if;
  clave := case
    when papel.tipo = 'importe_dia'      and papel.paso_importe is not null then 'importe_' || papel.paso_importe
    when papel.tipo = 'pago_importe_dia' and papel.paso_importe is not null
         and papel.estado <> 'rechazado'                                  then 'pago_' || papel.paso_importe
    when papel.tipo = 'busqueda_antecedentes'                             then 'busqueda'
    when papel.tipo = 'certificado_marca'                                 then 'certificado'
  end;
  if clave is null then
    return new;
  end if;
  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(clave, public.marca_ahora()))
   where id = new.tramite
     and not coalesce((datos -> 'pasos_ciip') ? clave, false);
  return new;
end
$marca$;

drop trigger if exists tramite_documentos_marca_apunta on public.tramite_documentos;
create trigger tramite_documentos_marca_apunta
  after insert on public.tramite_documentos
  for each row execute function public.marca_apunta_el_papel();

-- Un comprobante rechazado deja de contar: su paso vuelve a estar por
-- hacer, y el inversionista puede cargar otro.
create or replace function public.marca_borra_el_pago_rechazado()
returns trigger
language plpgsql
security definer
set search_path = public
as $marca$
begin
  if new.tipo <> 'pago_importe_dia' or new.paso_importe is null
     or new.estado <> 'rechazado' or old.estado = 'rechazado' then
    return new;
  end if;
  update public.tramites t
     set datos = jsonb_set(t.datos, '{pasos_ciip}',
                           (t.datos -> 'pasos_ciip') - ('pago_' || new.paso_importe))
   where t.tipo = 'marca'
     and (t.datos -> 'pasos_ciip') ? ('pago_' || new.paso_importe)
     and t.id in (select td.tramite from public.tramite_documentos td where td.documento = new.id);
  return new;
end
$marca$;

drop trigger if exists documentos_marca_pago_rechazado on public.documentos;
create trigger documentos_marca_pago_rechazado
  after update of estado on public.documentos
  for each row execute function public.marca_borra_el_pago_rechazado();

-- Los dos pasos que marca el gestor, cada uno en su sitio: «Solicitud en
-- proceso ante el SAPI» con la FM-02 pagada, y «Marca en proceso de
-- registro» con aquél cerrado y, si hubo contestación, pagada. Revienta si
-- no tocó ninguna fila: una política que falta no da error, cambia cero.
create or replace function public.marca_paso_ciip(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $marca$
declare
  fila public.tramites;
begin
  if not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP marca estos pasos';
  end if;
  if p_clave not in ('sapi', 'en_registro') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(p_clave, public.marca_ahora()))
   where id = p_tramite
     and tipo = 'marca'
     and estado = 'ante_el_ente'
     and not coalesce((datos -> 'pasos_ciip') ? p_clave, false)
     and (
          (p_clave = 'sapi' and coalesce((datos -> 'pasos_ciip') ? 'pago_fm02', false))
       or (p_clave = 'en_registro'
           and coalesce((datos -> 'pasos_ciip') ? 'sapi', false)
           and (not coalesce((datos -> 'pasos_ciip') ? 'contestacion', false)
                or coalesce((datos -> 'pasos_ciip') ? 'pago_contestacion', false)))
     )
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;
  return fila;
end
$marca$;

-- La contestación: el gestor la habilita con un anuncio que explica qué
-- pasó, y abre los dos pasos del importe de la contestación. La marca SE
-- QUEDA en «Solicitud en proceso ante el SAPI» -si estaba marcado, se
-- reabre- mientras se resuelve la devolución o la oposición; el gestor lo
-- cierra con marca_paso_ciip('sapi') cuando queda resuelta, y solo
-- entonces sigue el importe (Franklin Reyes, 9-10-2026; antes se daba por
-- cerrado al habilitar). El anuncio entra además en el chat de la
-- contestación, que suena en la campana del inversionista, y en los
-- avisos por correo.
alter table public.avisos drop constraint if exists avisos_motivo_valido;
alter table public.avisos add constraint avisos_motivo_valido
  check (motivo in ('cambio_estado', 'documento_vence', 'anuncio'));

create or replace function public.habilita_contestacion(p_tramite uuid, p_anuncio text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $marca$
declare
  fila   public.tramites;
  texto  text := btrim(coalesce(p_anuncio, ''));
  ahora  text := public.marca_ahora();
  correo text;
  suPais text;
begin
  if not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP habilita la contestación';
  end if;
  if texto = '' or char_length(texto) > 2000 then
    raise exception 'El anuncio tiene que decir algo, y en menos de 2000 caracteres';
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(
                      'pasos_ciip', (coalesce(datos -> 'pasos_ciip', '{}'::jsonb) - 'sapi')
                                    || jsonb_build_object('contestacion', ahora),
                      'anuncio', texto,
                      'anuncio_en', ahora)
   where id = p_tramite
     and tipo = 'marca'
     and estado = 'ante_el_ente'
     and coalesce((datos -> 'pasos_ciip') ? 'pago_fm02', false)
     and not coalesce((datos -> 'pasos_ciip') ? 'en_registro', false)
     and not coalesce((datos -> 'pasos_ciip') ? 'contestacion', false)
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo habilitar la contestación';
  end if;

  -- El anuncio abre el chat de la contestación (supabase-chat-del-paso.sql,
  -- 9-10-2026): es su primer mensaje.
  insert into public.tramite_mensajes (tramite, texto, paso) values (p_tramite, texto, 'contestacion');

  select u.email into correo from auth.users u where u.id = fila.inversionista;
  select p.pais  into suPais from public.perfiles p where p.id = fila.inversionista;
  if correo is not null and correo <> '' then
    insert into public.avisos (tramite, destinatario, pais, motivo, nota)
    values (p_tramite, correo, coalesce(suPais, ''), 'anuncio', texto);
  end if;

  return fila;
end
$marca$;

revoke all on function public.marca_paso_ciip(uuid, text) from public;
revoke execute on function public.marca_paso_ciip(uuid, text) from anon;
grant execute on function public.marca_paso_ciip(uuid, text) to authenticated;
revoke all on function public.habilita_contestacion(uuid, text) from public;
revoke execute on function public.habilita_contestacion(uuid, text) from anon;
grant execute on function public.habilita_contestacion(uuid, text) to authenticated;

-- Y no se resuelve sin el certificado enviado: el último paso le dice al
-- inversionista que vaya a retirar los originales.
create or replace function public.marca_con_certificado()
returns trigger
language plpgsql
as $marca$
begin
  if auth.uid() is null
     or new.tipo is distinct from 'marca'
     or new.estado is distinct from 'resuelto'
     or old.estado = 'resuelto' then
    return new;
  end if;
  if not coalesce((new.datos -> 'pasos_ciip') ? 'certificado', false) then
    raise exception 'Falta el certificado de registro de la marca'
      using errcode = 'check_violation';
  end if;
  return new;
end
$marca$;

drop trigger if exists tramites_marca_con_certificado on public.tramites;
create trigger tramites_marca_con_certificado
  before update on public.tramites
  for each row execute function public.marca_con_certificado();

-- COMPROBACIÓN
--   select codigo from public.tipos_documento
--    where codigo in ('busqueda_antecedentes', 'certificado_marca');     -- dos filas
--   select estados from public.importe_del_dia_pasos where tipo_tramite = 'marca';
--   select proname from pg_proc
--    where proname in ('marca_paso_ciip', 'habilita_contestacion');     -- dos filas

-- ====================================================================
--  56 / 105   supabase-entes-sin-codigo.sql
-- ====================================================================

-- Los registros parafiscales sin código (pedido del CIIP, 28-9-2026): solo
-- el IVSS y el INCES le mandan algo al inversionista -usuario y contraseña-.
-- En los otros cuatro el CIIP inscribe y da la inscripción por lista, sin
-- código por medio. El equipo ya podía ir de 'pendiente' a 'listo' con su
-- política de siempre; lo que cambia es que el inversionista solo escribe
-- en las filas del IVSS y del INCES.
-- Va después de supabase-entes-parafiscales.sql. Se puede correr más de una vez.

drop policy if exists "entes: el inversionista manda su codigo" on public.tramite_entes;
create policy "entes: el inversionista manda su codigo" on public.tramite_entes
  for insert with check (
    estado = 'codigo_enviado'
    and ente in ('ivss', 'inces')
    and exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
         and t.tipo = 'registros_parafiscales'
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
    and (documento is null or exists (
      select 1 from public.documentos d
       where d.id = tramite_entes.documento and d.inversionista = auth.uid()
    ))
  );

drop policy if exists "entes: el inversionista corrige su codigo" on public.tramite_entes;
create policy "entes: el inversionista corrige su codigo" on public.tramite_entes
  for update
  using (
    estado in ('inscrito', 'codigo_enviado')
    and ente in ('ivss', 'inces')
    and exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
  )
  with check (
    estado = 'codigo_enviado'
    and ente in ('ivss', 'inces')
    and exists (
      select 1 from public.tramites t
       where t.id = tramite_entes.tramite and t.inversionista = auth.uid()
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
    and (documento is null or exists (
      select 1 from public.documentos d
       where d.id = tramite_entes.documento and d.inversionista = auth.uid()
    ))
  );

-- Comprobación: las mismas cuatro políticas, y las dos del inversionista
-- nombrando al IVSS y al INCES.
select policyname, cmd,
       coalesce(qual, '') ilike '%ivss%' or coalesce(with_check, '') ilike '%ivss%' as solo_ivss_inces
  from pg_policies where tablename = 'tramite_entes' order by policyname;

-- ====================================================================
--  57 / 105   supabase-conformidad-uso.sql
-- ====================================================================

-- La conformidad de uso (c28), pedido del CIIP del 28-9-2026: los recaudos
-- que pide el SIGAT de la alcaldía y su escalera propia, «Revisión de
-- recaudos → Inscripción ante el ente → Emitida certificación de
-- conformidad de uso». Se puede correr más de una vez.

-- Los tres papeles nuevos. El título o arrendamiento (titulo_inmueble) y el
-- plano (plano_local) ya existían. Sin estas filas el panel no los pide.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('cedula_catastral',     'Cédula catastral del inmueble',                     false),
  ('permiso_construccion', 'Permiso de construcción o conformidad ocupacional', false),
  ('fotos_local',          'Fotografías internas y externas del local',         false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- Los pasos viejos (cuatro) o un rótulo de estado escrito a mano para la
-- c28 desde «Editar textos» pisarían los nuevos: se van, y mandan los de
-- pasos.js.
delete from public.textos_panel
 where clave like '\_p.pasos.c28.%'
    or clave like '\_p.circuito.c28.%';

-- Comprobación: tres filas, y ningún texto de la c28.
select codigo, nombre from public.tipos_documento
 where codigo in ('cedula_catastral', 'permiso_construccion', 'fotos_local');
select clave from public.textos_panel
 where clave like '\_p.pasos.c28.%' or clave like '\_p.circuito.c28.%';

-- ====================================================================
--  58 / 105   supabase-licencia.sql
-- ====================================================================

-- La licencia de actividades económicas (c10), pedido del CIIP del
-- 28-9-2026: dos importes del día con nombre -'tasa' (la tasa
-- administrativa) y 'timbre' (el timbre fiscal)-, cada uno con su
-- comprobante, y no se resuelve sin los dos comprobantes.
-- Va DESPUÉS de supabase-importe-del-dia.sql y de supabase-marca.sql, de
-- quien usa la guarda de los pasos apuntados. Se puede correr más de una
-- vez. Sin él el panel no se rompe: la escalera se queda en el importe.

do $comprueba$
begin
  if to_regprocedure('public.importe_del_dia_vigente(uuid, text)') is null then
    raise exception 'Falta supabase-importe-del-dia.sql: va antes que éste';
  end if;
  if to_regprocedure('public.pasos_del_ciip_se_quedan()') is null then
    raise exception 'Falta supabase-marca.sql: va antes que éste';
  end if;
end
$comprueba$;

-- Los dos importes van con la solicitud ante la alcaldía. Cuál es cuál lo
-- dice su nombre, y lo cuadra importe_del_dia_vigente(tramite, paso).
insert into public.importe_del_dia_pasos (tipo_tramite, estados)
values ('licencia_municipal', array['ante_el_ente'])
on conflict (tipo_tramite) do update set estados = excluded.estados;

-- Al colgarse un importe o un comprobante con nombre, la base apunta su
-- paso en tramites.datos.pasos_ciip, igual que en la marca: importe_tasa,
-- pago_tasa, importe_timbre, pago_timbre. El primero que llega pone la
-- fecha.
create or replace function public.licencia_apunta_el_papel()
returns trigger
language plpgsql
security definer
set search_path = public
as $licencia$
declare
  papel public.documentos;
  suTipo text;
  clave text;
begin
  select * into papel from public.documentos where id = new.documento;
  select tipo into suTipo from public.tramites where id = new.tramite;
  if suTipo is distinct from 'licencia_municipal' or papel.id is null
     or papel.paso_importe is null then
    return new;
  end if;
  clave := case
    when papel.tipo = 'importe_dia'                                   then 'importe_' || papel.paso_importe
    when papel.tipo = 'pago_importe_dia' and papel.estado <> 'rechazado' then 'pago_' || papel.paso_importe
  end;
  if clave is null then
    return new;
  end if;
  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF')))
   where id = new.tramite
     and not coalesce((datos -> 'pasos_ciip') ? clave, false);
  return new;
end
$licencia$;

drop trigger if exists tramite_documentos_licencia_apunta on public.tramite_documentos;
create trigger tramite_documentos_licencia_apunta
  after insert on public.tramite_documentos
  for each row execute function public.licencia_apunta_el_papel();

-- Un comprobante rechazado deja de contar: su paso vuelve a estar por
-- hacer y el inversionista carga otro.
create or replace function public.licencia_borra_el_pago_rechazado()
returns trigger
language plpgsql
security definer
set search_path = public
as $licencia$
begin
  if new.tipo <> 'pago_importe_dia' or new.paso_importe is null
     or new.estado <> 'rechazado' or old.estado = 'rechazado' then
    return new;
  end if;
  update public.tramites t
     set datos = jsonb_set(t.datos, '{pasos_ciip}',
                           (t.datos -> 'pasos_ciip') - ('pago_' || new.paso_importe))
   where t.tipo = 'licencia_municipal'
     and (t.datos -> 'pasos_ciip') ? ('pago_' || new.paso_importe)
     and t.id in (select td.tramite from public.tramite_documentos td where td.documento = new.id);
  return new;
end
$licencia$;

drop trigger if exists documentos_licencia_pago_rechazado on public.documentos;
create trigger documentos_licencia_pago_rechazado
  after update of estado on public.documentos
  for each row execute function public.licencia_borra_el_pago_rechazado();

-- «Licencia otorgada» va detrás de «Comprobante del pago»: sin los dos
-- comprobantes -tasa y timbre, no rechazados- no se resuelve.
create or replace function public.tramites_licencia_con_pagos()
returns trigger
language plpgsql
security definer
set search_path = public
as $licencia$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'licencia_municipal' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;
  if exists (
    select 1
      from unnest(array['tasa', 'timbre']) as p(paso)
     where not exists (
       select 1
         from public.tramite_documentos td
         join public.documentos d on d.id = td.documento
        where td.tramite = new.id
          and d.tipo = 'pago_importe_dia'
          and d.paso_importe = p.paso
          and d.estado <> 'rechazado'
     )
  ) then
    raise exception 'La licencia no se resuelve sin el comprobante del pago de la tasa administrativa y el del timbre fiscal'
      using errcode = 'check_violation';
  end if;
  return new;
end
$licencia$;

drop trigger if exists tramites_licencia_pagos on public.tramites;
create trigger tramites_licencia_pagos
  before update on public.tramites
  for each row execute function public.tramites_licencia_con_pagos();

-- Los pasos viejos de la c10 (cuatro) escritos desde «Editar textos» se
-- quedarían pisando los nuevos: se van, y mandan los de pasos.js.
delete from public.textos_panel
 where clave like '\_p.pasos.c10.%'
    or clave like '\_p.circuito.c10.%';

-- COMPROBACIÓN
--   select * from public.importe_del_dia_pasos where tipo_tramite = 'licencia_municipal';
--   select tgname from pg_trigger
--    where tgname in ('tramite_documentos_licencia_apunta', 'documentos_licencia_pago_rechazado',
--                     'tramites_licencia_pagos');                              -- tres filas

-- ====================================================================
--  59 / 105   supabase-quitar-importador.sql
-- ====================================================================

-- El registro de importador y exportador (c11, VUCE) se va del catálogo
-- (pedido del CIIP, 28-9-2026: «Eliminar»). Se apaga y no se borra: las
-- solicitudes que ya existan son de este tipo y la fila es lo que las
-- nombra. Nadie puede pedir una nueva de un tipo apagado.
-- Se puede correr más de una vez.

update public.tipos_tramite
   set activo = false
 where codigo = 'comercio_exterior';

-- Comprobación: apagado, y cuántas solicitudes viejas hay.
select codigo, ref_panel, nombre, activo
  from public.tipos_tramite
 where codigo = 'comercio_exterior';

select estado, count(*)
  from public.tramites
 where tipo = 'comercio_exterior'
 group by estado;

-- ====================================================================
--  60 / 105   supabase-bomberos.sql
-- ====================================================================

-- El permiso de bomberos (c29), pedido del CIIP del 28-9-2026: su escalera
-- es «Revisión de recaudos → Permiso otorgado», y la escriben pasos.js. Los
-- tres recaudos nuevos -cédula o pasaporte y RIF del representante legal,
-- documento constitutivo- son tipos que ya existen (cedula, rif_personal,
-- acta_constitutiva): no hace falta crear ninguno.
-- Se puede correr más de una vez.

-- Los pasos viejos (cuatro) o un rótulo de estado escrito a mano para la
-- c29 desde «Editar textos» pisarían los nuevos: se van.
delete from public.textos_panel
 where clave like '\_p.pasos.c29.%'
    or clave like '\_p.circuito.c29.%';

-- Comprobación: ninguna fila.
select clave from public.textos_panel
 where clave like '\_p.pasos.c29.%' or clave like '\_p.circuito.c29.%';

-- ── 29-9-2026: dos recaudos y el importe de aranceles con su comprobante ──
-- Va DESPUÉS de supabase-importe-del-dia.sql y de supabase-marca.sql. Sin
-- esto el panel no se rompe: el plano de seguridad no se pide y la escalera
-- se queda en el importe.

do $comprueba$
begin
  if to_regprocedure('public.importe_del_dia_vigente(uuid, text)') is null then
    raise exception 'Falta supabase-importe-del-dia.sql: va antes que éste';
  end if;
  if to_regprocedure('public.pasos_del_ciip_se_quedan()') is null then
    raise exception 'Falta supabase-marca.sql: va antes que éste';
  end if;
end
$comprueba$;

-- El plano de seguridad es un papel nuevo. El contrato de arrendamiento o
-- título de propiedad (titulo_inmueble) ya existía.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('plano_seguridad', 'Plano a escala 1:50 demarcando los sistemas de seguridad', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- El importe de aranceles, con la solicitud ante los bomberos.
insert into public.importe_del_dia_pasos (tipo_tramite, estados)
values ('permiso_bomberos', array['ante_el_ente'])
on conflict (tipo_tramite) do update set estados = excluded.estados;

-- Al colgarse el importe o el comprobante, la base apunta su paso en
-- tramites.datos.pasos_ciip: importe_aranceles, pago_aranceles.
create or replace function public.bomberos_apunta_el_papel()
returns trigger
language plpgsql
security definer
set search_path = public
as $bomberos$
declare
  papel public.documentos;
  suTipo text;
  clave text;
begin
  select * into papel from public.documentos where id = new.documento;
  select tipo into suTipo from public.tramites where id = new.tramite;
  if suTipo is distinct from 'permiso_bomberos' or papel.id is null
     or papel.paso_importe is null then
    return new;
  end if;
  clave := case
    when papel.tipo = 'importe_dia'                                      then 'importe_' || papel.paso_importe
    when papel.tipo = 'pago_importe_dia' and papel.estado <> 'rechazado' then 'pago_' || papel.paso_importe
  end;
  if clave is null then
    return new;
  end if;
  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF')))
   where id = new.tramite
     and not coalesce((datos -> 'pasos_ciip') ? clave, false);
  return new;
end
$bomberos$;

drop trigger if exists tramite_documentos_bomberos_apunta on public.tramite_documentos;
create trigger tramite_documentos_bomberos_apunta
  after insert on public.tramite_documentos
  for each row execute function public.bomberos_apunta_el_papel();

-- Un comprobante rechazado deja de contar: su paso vuelve a estar por hacer.
create or replace function public.bomberos_borra_el_pago_rechazado()
returns trigger
language plpgsql
security definer
set search_path = public
as $bomberos$
begin
  if new.tipo <> 'pago_importe_dia' or new.paso_importe is null
     or new.estado <> 'rechazado' or old.estado = 'rechazado' then
    return new;
  end if;
  update public.tramites t
     set datos = jsonb_set(t.datos, '{pasos_ciip}',
                           (t.datos -> 'pasos_ciip') - ('pago_' || new.paso_importe))
   where t.tipo = 'permiso_bomberos'
     and (t.datos -> 'pasos_ciip') ? ('pago_' || new.paso_importe)
     and t.id in (select td.tramite from public.tramite_documentos td where td.documento = new.id);
  return new;
end
$bomberos$;

drop trigger if exists documentos_bomberos_pago_rechazado on public.documentos;
create trigger documentos_bomberos_pago_rechazado
  after update of estado on public.documentos
  for each row execute function public.bomberos_borra_el_pago_rechazado();

-- «Permiso otorgado» va detrás del comprobante: sin él no se resuelve.
create or replace function public.tramites_bomberos_con_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $bomberos$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'permiso_bomberos' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;
  if not exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
     where td.tramite = new.id
       and d.tipo = 'pago_importe_dia'
       and d.paso_importe = 'aranceles'
       and d.estado <> 'rechazado'
  ) then
    raise exception 'El permiso de bomberos no se resuelve sin el comprobante de pago de aranceles'
      using errcode = 'check_violation';
  end if;
  return new;
end
$bomberos$;

drop trigger if exists tramites_bomberos_pago on public.tramites;
create trigger tramites_bomberos_pago
  before update on public.tramites
  for each row execute function public.tramites_bomberos_con_pago();

-- COMPROBACIÓN
--   select codigo from public.tipos_documento where codigo = 'plano_seguridad';     -- una fila
--   select * from public.importe_del_dia_pasos where tipo_tramite = 'permiso_bomberos';
--   select tgname from pg_trigger
--    where tgname in ('tramite_documentos_bomberos_apunta', 'documentos_bomberos_pago_rechazado',
--                     'tramites_bomberos_pago');                              -- tres filas

-- ====================================================================
--  61 / 105   supabase-libros.sql
-- ====================================================================

-- El sellado de libros (c24), pedido del CIIP del 29-9-2026: «Revisión de
-- recaudos → Consignación de libros en el CIIP → Solicitud introducida ante
-- el SAREN → Emisión de PUB por SAREN → Comprobante de pago de PUB → Libros
-- sellados». El PUB es un importe del día con nombre, 'pub', con su
-- comprobante, y no se resuelve sin él.
-- Va DESPUÉS de supabase-importe-del-dia.sql y de supabase-marca.sql. Se
-- puede correr más de una vez. Sin él el panel no se rompe: la escalera se
-- queda en el PUB.

-- Los pasos viejos (tres) escritos a mano desde «Editar textos» pisarían
-- los nuevos: se van.
delete from public.textos_panel
 where clave like '\_p.pasos.c24.%'
    or clave like '\_p.circuito.c24.%';

do $comprueba$
begin
  if to_regprocedure('public.importe_del_dia_vigente(uuid, text)') is null then
    raise exception 'Falta supabase-importe-del-dia.sql: va antes que éste';
  end if;
  if to_regprocedure('public.pasos_del_ciip_se_quedan()') is null then
    raise exception 'Falta supabase-marca.sql: va antes que éste';
  end if;
end
$comprueba$;


-- El PUB, con la solicitud ante el SAREN.
insert into public.importe_del_dia_pasos (tipo_tramite, estados)
values ('libros_contables', array['ante_el_ente'])
on conflict (tipo_tramite) do update set estados = excluded.estados;

-- Al colgarse el importe o el comprobante, la base apunta su paso en
-- tramites.datos.pasos_ciip: importe_pub, pago_pub.
create or replace function public.libros_apunta_el_papel()
returns trigger
language plpgsql
security definer
set search_path = public
as $libros$
declare
  papel public.documentos;
  suTipo text;
  clave text;
begin
  select * into papel from public.documentos where id = new.documento;
  select tipo into suTipo from public.tramites where id = new.tramite;
  if suTipo is distinct from 'libros_contables' or papel.id is null
     or papel.paso_importe is null then
    return new;
  end if;
  clave := case
    when papel.tipo = 'importe_dia'                                      then 'importe_' || papel.paso_importe
    when papel.tipo = 'pago_importe_dia' and papel.estado <> 'rechazado' then 'pago_' || papel.paso_importe
  end;
  if clave is null then
    return new;
  end if;
  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF')))
   where id = new.tramite
     and not coalesce((datos -> 'pasos_ciip') ? clave, false);
  return new;
end
$libros$;

drop trigger if exists tramite_documentos_libros_apunta on public.tramite_documentos;
create trigger tramite_documentos_libros_apunta
  after insert on public.tramite_documentos
  for each row execute function public.libros_apunta_el_papel();

-- Un comprobante rechazado deja de contar: su paso vuelve a estar por hacer.
create or replace function public.libros_borra_el_pago_rechazado()
returns trigger
language plpgsql
security definer
set search_path = public
as $libros$
begin
  if new.tipo <> 'pago_importe_dia' or new.paso_importe is null
     or new.estado <> 'rechazado' or old.estado = 'rechazado' then
    return new;
  end if;
  update public.tramites t
     set datos = jsonb_set(t.datos, '{pasos_ciip}',
                           (t.datos -> 'pasos_ciip') - ('pago_' || new.paso_importe))
   where t.tipo = 'libros_contables'
     and (t.datos -> 'pasos_ciip') ? ('pago_' || new.paso_importe)
     and t.id in (select td.tramite from public.tramite_documentos td where td.documento = new.id);
  return new;
end
$libros$;

drop trigger if exists documentos_libros_pago_rechazado on public.documentos;
create trigger documentos_libros_pago_rechazado
  after update of estado on public.documentos
  for each row execute function public.libros_borra_el_pago_rechazado();

-- «Libros sellados» va detrás del comprobante del PUB: sin él no se resuelve.
create or replace function public.tramites_libros_con_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $libros$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'libros_contables' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;
  if not exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
     where td.tramite = new.id
       and d.tipo = 'pago_importe_dia'
       and d.paso_importe = 'pub'
       and d.estado <> 'rechazado'
  ) then
    raise exception 'El sellado de libros no se resuelve sin el comprobante de pago del PUB'
      using errcode = 'check_violation';
  end if;
  return new;
end
$libros$;

drop trigger if exists tramites_libros_pago on public.tramites;
create trigger tramites_libros_pago
  before update on public.tramites
  for each row execute function public.tramites_libros_con_pago();

-- COMPROBACIÓN
--   select * from public.importe_del_dia_pasos where tipo_tramite = 'libros_contables';
--   select tgname from pg_trigger
--    where tgname in ('tramite_documentos_libros_apunta', 'documentos_libros_pago_rechazado',
--                     'tramites_libros_pago');                              -- tres filas

-- ── El PUB no caduca (29-9-2026) ──
-- «Nosotros somos los que enviamos el PUB y él nos reenvía el comprobante,
-- como en constitución de empresa»: el PUB del SAREN no vence a medianoche
-- como el importe del día. Una columna en importe_del_dia_pasos lo dice por
-- trámite, y importe_del_dia_vigente la mira: con ella, vale el último
-- importe colgado aunque sea de otro día. Los demás trámites, igual.
alter table public.importe_del_dia_pasos
  add column if not exists sin_caducidad boolean not null default false;

update public.importe_del_dia_pasos set sin_caducidad = true
 where tipo_tramite = 'libros_contables';

create or replace function public.importe_del_dia_vigente(p_tramite uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
      join public.tramites t   on t.id = td.tramite
     where td.tramite = p_tramite
       and d.tipo = 'importe_dia'
       and d.estado = 'validado'
       and d.inversionista = t.inversionista
       and ((d.creado_en at time zone 'America/Caracas')::date = public.hoy_en_caracas()
            or exists (select 1 from public.importe_del_dia_pasos p
                        where p.tipo_tramite = t.tipo and p.sin_caducidad))
  )
$$;

create or replace function public.importe_del_dia_vigente(p_tramite uuid, p_paso text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
      join public.tramites t   on t.id = td.tramite
     where td.tramite = p_tramite
       and d.tipo = 'importe_dia'
       and d.estado = 'validado'
       and d.inversionista = t.inversionista
       and d.paso_importe is not distinct from p_paso
       and ((d.creado_en at time zone 'America/Caracas')::date = public.hoy_en_caracas()
            or exists (select 1 from public.importe_del_dia_pasos p
                        where p.tipo_tramite = t.tipo and p.sin_caducidad))
  )
$$;

-- COMPROBACIÓN
--   select tipo_tramite, sin_caducidad from public.importe_del_dia_pasos;   -- libros_contables: true

-- ====================================================================
--  62 / 105   supabase-gestor-visible.sql
-- ====================================================================

-- El nombre del gestor que atiende cada solicitud, para el inversionista
-- que la pidió (Franklin Reyes, 30-9-2026: «aquí quiero ver el nombre del
-- gestor que me atiende», en la campana de avisos). El inversionista solo
-- lee su propio perfil, y abrirle perfiles ajenos le daría correos y
-- teléfonos del equipo. Esta función devuelve el nombre y nada más, y solo
-- de las solicitudes de quien pregunta. Se puede correr más de una vez.
-- Sin ella el panel no se rompe: los avisos salen sin el nombre.

create or replace function public.gestores_de_mis_tramites()
returns table (tramite uuid, nombre text)
language sql
stable
security definer
set search_path = public
as $$
  select t.id, nullif(trim(p.nombre_completo), '')
    from public.tramites t
    join public.perfiles p on p.id = t.gestor
   where t.inversionista = auth.uid()
     and t.gestor is not null
$$;

revoke all on function public.gestores_de_mis_tramites() from public;
revoke execute on function public.gestores_de_mis_tramites() from anon;
grant execute on function public.gestores_de_mis_tramites() to authenticated;

-- COMPROBACIÓN
--   select proname from pg_proc where proname = 'gestores_de_mis_tramites';   -- una fila

-- ====================================================================
--  63 / 105   supabase-qa-atencion.sql
-- ====================================================================

-- Citas y consultas: lo que encontró la auditoría QA del 28-9-2026.
-- Va DETRÁS de supabase-citas, supabase-consultas y supabase-disponibilidad.

do $$
begin
  if to_regclass('public.citas') is null
     or to_regclass('public.consultas') is null
     or to_regclass('public.horario_citas') is null then
    raise exception using
      message = 'Faltan las citas, las consultas o el horario',
      hint    = 'Pasa antes supabase-citas.sql, supabase-consultas.sql y supabase-disponibilidad.sql.';
  end if;
end $$;


-- ── 1. LOS ESTADOS DE UNA CITA, Y POR QUÉ SE CANCELÓ ─────────────────────
-- «No asistió» es lo que le pasa a una cita que llegó y no vino nadie: sin
-- él, la única forma de sacarla de las vivas era decir que se hizo.
--
-- motivo lo escribe el CIIP al rechazar, cancelar o mover una cita, y es
-- lo que el buzón le enseña al inversionista. cancelada_por_ciip la pone la
-- base: la fila no guardaba quién la canceló, y por eso el buzón no podía
-- avisar de una cancelación sin arriesgarse a contarle a alguien lo que
-- acababa de hacer él mismo.
alter table public.citas drop constraint if exists citas_estado_valido;
alter table public.citas add  constraint citas_estado_valido
  check (estado in ('solicitada','confirmada','hecha','no_asistio','cancelada'));

alter table public.citas add column if not exists motivo text not null default '';
alter table public.citas add column if not exists cancelada_por_ciip boolean not null default false;

alter table public.citas drop constraint if exists citas_motivo_cabe;
alter table public.citas add  constraint citas_motivo_cabe check (length(motivo) <= 500);

comment on column public.citas.motivo is 'Por qué el CIIP la rechazó, la canceló o la movió. Lo lee el inversionista en su buzón';
comment on column public.citas.cancelada_por_ciip is 'true = la canceló o la rechazó el CIIP, no quien la pidió. La pone la base';


-- ── 2. EL INVERSIONISTA SOLO CANCELA ─────────────────────────────────────
-- Antes se miraba campo por campo y se escapaban modo y nota: por la API se
-- podía cambiar cómo y para qué era una cita ya confirmada. Ahora se
-- compara la fila entera menos el estado y lo que pone la propia base.
--
-- pg_trigger_depth() > 1 es la base cerrando sola las citas pasadas de
-- quien pide otra (apartado 4): viene de un disparador, no de nadie.
create or replace function public.citas_solo_cancelar()
returns trigger
language plpgsql
as $$
begin
  if auth.uid() is null or public.es_gestor() or pg_trigger_depth() > 1 then
    return new;
  end if;

  if new.estado is distinct from old.estado and new.estado <> 'cancelada' then
    raise exception 'Una cita solo se puede cancelar desde el panel';
  end if;

  if (to_jsonb(new) - 'estado' - 'actualizado_en' - 'cancelada_por_ciip')
     is distinct from
     (to_jsonb(old) - 'estado' - 'actualizado_en' - 'cancelada_por_ciip') then
    raise exception 'Esos datos de la cita los fija el CIIP';
  end if;

  return new;
end;
$$;


-- ── 3. LO QUE HACE EL CIIP CON UNA CITA ──────────────────────────────────
-- Rechazar o cancelar pide motivo, y queda dicho que fue el CIIP. Cerrarla
-- -hecha o no asistió- solo cuando ya ha pasado: cerrar una del martes que
-- viene sería borrarla de la agenda sin avisar a nadie.
create or replace function public.citas_lo_que_hace_el_ciip()
returns trigger
language plpgsql
as $$
begin
  if new.estado = 'cancelada' and old.estado is distinct from 'cancelada' then
    new.cancelada_por_ciip := (auth.uid() is not null
                               and public.es_gestor()
                               and new.inversionista is distinct from auth.uid());
    if new.cancelada_por_ciip and length(trim(coalesce(new.motivo, ''))) = 0 then
      raise exception 'Hace falta decir por qué se cancela la cita'
        using errcode = 'check_violation';
    end if;
  end if;

  if new.estado in ('hecha','no_asistio') and old.estado is distinct from new.estado
     and auth.uid() is not null and pg_trigger_depth() = 1
     and (new.cuando is null or new.cuando > now()) then
    raise exception 'Una cita que todavía no ha pasado no se cierra'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists citas_quien_cancela on public.citas;
create trigger citas_quien_cancela
  before update on public.citas
  for each row execute function public.citas_lo_que_hace_el_ciip();


-- ── 4. UNA CITA PASADA YA NO ESTÁ VIVA ───────────────────────────────────
-- Nadie ponía «hecha», así que una cita confirmada del mes pasado seguía
-- viva para siempre y reserva_cita contestaba «Ya tienes una cita en
-- marcha» a quien quería otra.
--
-- Viva es: pedida, o confirmada y por delante. Y como un índice parcial no
-- puede usar now(), la regla de una viva por persona (apartado 5) se
-- apoya en el ESTADO: cuando alguien pide otra, la base da por hechas sus
-- confirmadas que ya pasaron. «Hecha» y no «no asistió» porque es lo que
-- casi siempre ocurrió; si no fue así, el equipo tiene la lista de
-- pendientes de cerrar para decirlo antes, y es donde debería hacerse.
create or replace function public.citas_cierra_las_pasadas()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.citas
     set estado = 'hecha'
   where inversionista = new.inversionista
     and estado = 'confirmada'
     and cuando <= now();
  return new;
end;
$$;

drop trigger if exists citas_cierra_pasadas on public.citas;
create trigger citas_cierra_pasadas
  before insert on public.citas
  for each row execute function public.citas_cierra_las_pasadas();

create or replace function public.reserva_cita(
  p_cuando timestamptz,
  p_modo   text,
  p_tipo   text default null,
  p_nota   text default ''
)
returns public.citas
language plpgsql
security definer
set search_path = public
as $res$
declare
  yo     uuid := auth.uid();
  local  timestamp;
  dia_l  date;
  hora_l time;
  fila   public.citas;
begin
  if yo is null then
    raise exception 'Hace falta haber entrado para reservar'
      using errcode = 'insufficient_privilege';
  end if;

  if p_modo is null or p_modo not in ('presencial','video','telefono') then
    raise exception 'Modo de cita no válido'
      using errcode = 'check_violation';
  end if;

  if length(coalesce(p_nota, '')) > 500 then
    raise exception 'La nota es demasiado larga'
      using errcode = 'check_violation';
  end if;

  if p_cuando is null or p_cuando <= now() then
    raise exception 'Ese hueco ya pasó'
      using errcode = 'check_violation';
  end if;

  if p_cuando > now() + interval '92 days' then
    raise exception 'Ese hueco está demasiado lejos'
      using errcode = 'check_violation';
  end if;

  local  := p_cuando at time zone 'America/Caracas';
  dia_l  := local::date;
  hora_l := local::time;

  if exists (select 1 from public.cierres_citas where fecha = dia_l) then
    raise exception 'Ese día el CIIP no atiende'
      using errcode = 'check_violation';
  end if;

  if not exists (
    select 1
      from public.horario_citas h
     where h.dia = extract(isodow from local)::int
       and hora_l >= h.desde
       and hora_l + make_interval(mins => h.cada_min) <= h.hasta
       and (extract(epoch from (hora_l - h.desde))::int % (h.cada_min * 60)) = 0
  ) then
    raise exception 'Ese hueco no está en el horario del CIIP'
      using errcode = 'check_violation';
  end if;

  -- Una cita viva por persona. La que ya pasó no cuenta: la cierra el
  -- disparador del apartado 4 al entrar la nueva.
  if exists (
    select 1 from public.citas
     where inversionista = yo
       and (estado = 'solicitada' or (estado = 'confirmada' and cuando > now()))
  ) then
    raise exception 'Ya tienes una cita en marcha'
      using errcode = 'check_violation';
  end if;

  if exists (
    select 1 from public.citas
     where cuando = p_cuando and estado in ('solicitada','confirmada')
  ) then
    raise exception 'Ese hueco se acaba de ocupar'
      using errcode = 'unique_violation';
  end if;

  insert into public.citas
    (inversionista, tipo_tramite, modo, desde, hasta, nota, estado, cuando, hueco)
  values
    (yo, nullif(p_tipo, ''), p_modo, dia_l, dia_l, coalesce(trim(p_nota), ''),
     'confirmada', p_cuando, true)
  returning * into fila;

  return fila;

-- El índice de una viva por persona también salta como unique_violation, y
-- no es lo mismo que un hueco ocupado: se distingue por su nombre.
exception when unique_violation then
  if sqlerrm like '%citas_una_viva_por_persona%' then
    raise exception 'Ya tienes una cita en marcha'
      using errcode = 'check_violation';
  end if;
  raise exception 'Ese hueco se acaba de ocupar'
    using errcode = 'unique_violation';
end
$res$;

revoke all on function public.reserva_cita(timestamptz, text, text, text) from public;
grant execute on function public.reserva_cita(timestamptz, text, text, text) to authenticated;


-- ── 5. UNA VIVA POR PERSONA, TAMBIÉN POR DETRÁS ──────────────────────────
-- La pantalla y reserva_cita lo comprobaban, pero un insert directo a la
-- API no, y dos pestañas a la vez tampoco. El índice es la cerradura.
--
-- Si ya hay personas con dos vivas, crearlo haría fallar el archivo
-- entero. Entonces no se crea, se dice quiénes son, y se vuelve a pasar
-- este archivo cuando el equipo las haya cerrado o cancelado.
do $$
declare
  repetidas int;
begin
  if to_regclass('public.citas_una_viva_por_persona') is not null then
    return;
  end if;
  select count(*) into repetidas from (
    select inversionista from public.citas
     where estado in ('solicitada','confirmada')
     group by inversionista having count(*) > 1
  ) x;
  if repetidas > 0 then
    raise notice 'Hay % personas con más de una cita viva: el índice de una por persona no se crea. Ciérralas o cancélalas y vuelve a pasar este archivo.', repetidas;
    return;
  end if;
  execute 'create unique index citas_una_viva_por_persona
             on public.citas (inversionista)
             where estado in (''solicitada'',''confirmada'')';
end $$;


-- ── 6. CONFIRMAR O MOVER UNA CITA DESDE EL EQUIPO ────────────────────────
-- La confirmación a mano mandaba la hora en la zona del navegador del
-- gestor y no miraba nada: ni que fuera futura, ni el día cerrado, ni que
-- la hora estuviera libre. Aquí se mira lo mismo que en reserva_cita,
-- salvo el «en punto con su intervalo»: una cita pedida con una ventana de
-- días la pone el CIIP a la hora que acuerde, siempre que caiga dentro de
-- lo que atiende. Sin horario publicado no hay tramos que mirar.
--
-- Sirve también para MOVER una confirmada, y entonces el motivo es
-- obligatorio: es lo que le dice al inversionista por qué cambia su día.
create or replace function public.confirma_cita(
  p_cita   uuid,
  p_cuando timestamptz,
  p_lugar  text default null,
  p_motivo text default ''
)
returns public.citas
language plpgsql
security definer
set search_path = public
as $con$
declare
  vieja  public.citas;
  local  timestamp;
  hora_l time;
  fila   public.citas;
begin
  if auth.uid() is null or not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP confirma citas'
      using errcode = 'insufficient_privilege';
  end if;

  select * into vieja from public.citas where id = p_cita for update;
  if vieja.id is null or vieja.estado not in ('solicitada','confirmada') then
    raise exception 'Esa cita ya no está viva'
      using errcode = 'check_violation';
  end if;

  if vieja.estado = 'confirmada' and vieja.cuando is distinct from p_cuando
     and length(trim(coalesce(p_motivo, ''))) = 0 then
    raise exception 'Hace falta decir por qué se mueve la cita'
      using errcode = 'check_violation';
  end if;

  if p_cuando is null or p_cuando <= now() then
    raise exception 'Ese hueco ya pasó'
      using errcode = 'check_violation';
  end if;

  local  := p_cuando at time zone 'America/Caracas';
  hora_l := local::time;

  if exists (select 1 from public.cierres_citas where fecha = local::date) then
    raise exception 'Ese día el CIIP no atiende'
      using errcode = 'check_violation';
  end if;

  if exists (select 1 from public.horario_citas)
     and not exists (
       select 1 from public.horario_citas h
        where h.dia = extract(isodow from local)::int
          and hora_l >= h.desde and hora_l < h.hasta
     ) then
    raise exception 'Esa hora no está en el horario del CIIP'
      using errcode = 'check_violation';
  end if;

  -- Dos gestores confirmando a la vez la misma hora: el candado hace que el
  -- segundo espere al primero y vea su cita al comprobar.
  perform pg_advisory_xact_lock(hashtext('cita ' || p_cuando::text));
  if exists (
    select 1 from public.citas
     where cuando = p_cuando and id <> p_cita
       and estado in ('solicitada','confirmada')
  ) then
    raise exception 'Ese hueco se acaba de ocupar'
      using errcode = 'unique_violation';
  end if;

  update public.citas
     set estado = 'confirmada',
         cuando = p_cuando,
         lugar  = coalesce(nullif(trim(p_lugar), ''), lugar),
         motivo = coalesce(trim(p_motivo), ''),
         gestor = coalesce(gestor, auth.uid())
   where id = p_cita
  returning * into fila;

  return fila;
end
$con$;

revoke all on function public.confirma_cita(uuid, timestamptz, text, text) from public;
grant execute on function public.confirma_cita(uuid, timestamptz, text, text) to authenticated;


-- ── 7. UNA CONSULTA RESUELTA SE REABRE SI EL INVERSIONISTA ESCRIBE ───────
-- Era un callejón: lo que escribía en una resuelta no salía en ninguna
-- cola. Vuelve a la del equipo; en curso si ya la llevaba alguien, que es
-- quien sabe de qué va, y abierta si no.
create or replace function public.consulta_se_reabre()
returns trigger
language plpgsql
security definer
set search_path = public
as $con$
begin
  if not new.del_equipo then
    update public.consultas
       set estado = case when gestor is null then 'abierta' else 'en_curso' end
     where id = new.consulta and estado = 'resuelta';
  end if;
  return null;
end
$con$;

-- Desde el 5-10-2026 ya no: en una consulta resuelta no se puede escribir
-- (política «consulta_mensajes: escribir en mi consulta», en
-- supabase-consultas.sql) y reabrirla es cosa del equipo, con «Reabrir».
-- La función se queda, pero el disparador se quita.
drop trigger if exists consulta_mensajes_reabre on public.consulta_mensajes;


-- ── 8. EL EQUIPO ABRE UNA CONSULTA CON ALGUIEN ───────────────────────────
-- Lo que el gestor escribía en el hilo de una cita no le llegaba al
-- inversionista: desde el 8-9-2026 su lado de la cita no tiene hilo. En
-- vez de volver a ponérselo, el equipo le escribe por una consulta, que es
-- el sitio donde ya se conversa y que su buzón sí mira.
--
-- La firma de la consulta pone siempre como dueño a quien la abre. Aquí
-- se le avisa, con una marca que dura lo que la transacción, de que esta
-- la abre el equipo a nombre de otro.
create or replace function public.consulta_la_firma_la_base()
returns trigger
language plpgsql
security definer
set search_path = public
as $con$
begin
  if auth.uid() is not null then
    if not (coalesce(current_setting('ciip.consulta_para', true), '') = 'si'
            and public.es_gestor()) then
      new.inversionista := auth.uid();
    end if;
    new.estado      := 'abierta';
    new.gestor      := null;
    new.resuelto_en := null;
  end if;
  new.creado_en      := now();
  new.actualizado_en := now();
  return new;
end
$con$;

create or replace function public.abre_consulta_para(
  p_inversionista uuid,
  p_asunto        text,
  p_tipo          text default null
)
returns public.consultas
language plpgsql
security definer
set search_path = public
as $con$
declare
  fila public.consultas;
begin
  if auth.uid() is null or not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP abre consultas a nombre de otro'
      using errcode = 'insufficient_privilege';
  end if;

  perform set_config('ciip.consulta_para', 'si', true);
  insert into public.consultas (inversionista, asunto, tipo)
  values (p_inversionista, left(coalesce(trim(p_asunto), ''), 200), nullif(p_tipo, ''))
  returning * into fila;
  perform set_config('ciip.consulta_para', '', true);

  update public.consultas
     set estado = 'en_curso', gestor = auth.uid()
   where id = fila.id
  returning * into fila;

  return fila;
end
$con$;

revoke all on function public.abre_consulta_para(uuid, text, text) from public;
grant execute on function public.abre_consulta_para(uuid, text, text) to authenticated;

-- ====================================================================
--  64 / 105   supabase-qa-tramites.sql
-- ====================================================================

-- Lo que encontró la revisión de trámites y papeles (QA, 28-9-2026).
-- Se puede correr más de una vez. Va detrás de todo: toca trabajos
-- (supabase-cola), ordenes_pago (supabase-aranceles), tramite_entes
-- (supabase-entes-parafiscales) y redefine confirma_paso().

do $qa$
begin
  if to_regclass('public.trabajos') is null then
    raise exception 'Falta supabase-cola.sql: va antes que éste';
  end if;
  if to_regclass('public.ordenes_pago') is null then
    raise exception 'Falta supabase-aranceles.sql: va antes que éste';
  end if;
  if to_regclass('public.tramite_entes') is null then
    raise exception 'Falta supabase-entes-parafiscales.sql: va antes que éste';
  end if;
end
$qa$;


-- ── QA-09 y QA-15 · Lo pendiente de un trámite que sale del CIIP ──────
-- Un trabajo de 'presentar' encolado seguía ahí al cancelar o devolver el
-- trámite, y el trabajador lo presentaba igual. Y la orden de pago de un
-- cancelado se quedaba pendiente para siempre. Se anulan, no se borran:
-- que se viera que hubo algo y por qué dejó de haberlo.
--
-- Solo lo 'pendiente'. Lo que está 'haciendose' lo tiene el trabajador en
-- la mano, y lo cierra él; si lo que iba a hacer ya no cabe en la
-- escalera, la base se lo rechaza y lo alerta.
--
-- Devolver no anula la orden de pago: el trámite vuelve, y la orden viva
-- es la misma que se pagará cuando vuelva. Qué se hace con lo ya PAGADO
-- de un cancelado (devolverlo, guardarlo para otra solicitud) lo decide
-- el CIIP: aquí no se toca.

alter table public.trabajos drop constraint if exists trabajos_estado_valido;
alter table public.trabajos add constraint trabajos_estado_valido
  check (estado in ('pendiente', 'haciendose', 'hecho', 'alertado', 'anulado'));

create or replace function public.tramite_anula_lo_pendiente()
returns trigger
language plpgsql
security definer
set search_path = public
as $qa$
begin
  if new.estado is not distinct from old.estado
     or new.estado not in ('cancelado', 'devuelto') then
    return new;
  end if;

  update public.trabajos
     set estado = 'anulado',
         ultimo_error = 'Anulado: el trámite pasó a ' || new.estado
   where tramite = new.id
     and estado = 'pendiente';

  if new.estado = 'cancelado' then
    update public.ordenes_pago
       set estado = 'anulada'
     where tramite = new.id
       and estado = 'pendiente';
  end if;

  return new;
end
$qa$;

drop trigger if exists tramites_anula_lo_pendiente on public.tramites;
create trigger tramites_anula_lo_pendiente
  after update of estado on public.tramites
  for each row execute function public.tramite_anula_lo_pendiente();


-- ── QA-16 · Un papel en una solicitud en marcha no se borra ───────────
-- tramite_documentos va con 'on delete cascade': borrar el documento lo
-- quitaba en silencio del expediente que el CIIP ya estaba revisando. Lo
-- frenaba el panel, y por la API no lo frenaba nadie. En borrador y en
-- devuelto sí se puede: son de quien los rellena. Cancelada, también.
-- Desde el 15-10-2026 la redefine supabase-borrado-admin.sql: la misma, con
-- la puerta del borrado del administrador (solo para borrar).
create or replace function public.papel_en_marcha_no_se_borra()
returns trigger
language plpgsql
security definer
set search_path = public
as $qa$
begin
  if auth.uid() is null then
    return old;   -- la puerta de servicio: borrar una cuenta entera
  end if;
  if exists (
    select 1
      from public.tramite_documentos td
      join public.tramites t on t.id = td.tramite
     where td.documento = old.id
       and t.estado not in ('borrador', 'devuelto', 'cancelado')
  ) then
    raise exception 'Ese documento va en una solicitud en marcha: no se borra'
      using errcode = 'check_violation';
  end if;
  return old;
end
$qa$;

drop trigger if exists documentos_en_marcha_no_se_borra on public.documentos;
create trigger documentos_en_marcha_no_se_borra
  before delete on public.documentos
  for each row execute function public.papel_en_marcha_no_se_borra();


-- ── QA-17 · El papel que el CIIP revisa no cambia por debajo ──────────
-- La política deja al inversionista editar su papel mientras no esté
-- validado, y eso incluía cambiarle el archivo y el tipo a uno que el
-- gestor tenía abierto. El panel nunca lo hace: «Cambiar» sube uno nuevo.
-- Trigger propio, al lado de los de supabase-papeles-sellados,
-- supabase-importe-del-dia y supabase-marca, sin tocar ninguno.
create or replace function public.papel_en_marcha_no_cambia()
returns trigger
language plpgsql
security definer
set search_path = public
as $qa$
begin
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.archivo is not distinct from old.archivo
     and new.tipo is not distinct from old.tipo then
    return new;
  end if;
  if exists (
    select 1
      from public.tramite_documentos td
      join public.tramites t on t.id = td.tramite
     where td.documento = old.id
       and t.estado not in ('borrador', 'devuelto')
  ) then
    raise exception 'Ese documento va en una solicitud en marcha: sube uno nuevo'
      using errcode = 'check_violation';
  end if;
  return new;
end
$qa$;

drop trigger if exists documentos_en_marcha_no_cambia on public.documentos;
create trigger documentos_en_marcha_no_cambia
  before update on public.documentos
  for each row execute function public.papel_en_marcha_no_cambia();


-- ── QA-18 · Los registros parafiscales, con los seis entes listos ─────
-- Lo miraba solo el panel. Misma forma que tramites_marca_con_certificado.
create or replace function public.parafiscales_con_los_seis()
returns trigger
language plpgsql
security definer
set search_path = public
as $qa$
begin
  if auth.uid() is null
     or new.tipo is distinct from 'registros_parafiscales'
     or new.estado is distinct from 'resuelto'
     or old.estado = 'resuelto' then
    return new;
  end if;
  if (select count(*) from public.tramite_entes
       where tramite = new.id and estado = 'listo') < 6 then
    raise exception 'Hay inscripciones sin terminar en los registros parafiscales'
      using errcode = 'check_violation';
  end if;
  return new;
end
$qa$;

drop trigger if exists tramites_parafiscales_con_los_seis on public.tramites;
create trigger tramites_parafiscales_con_los_seis
  before update on public.tramites
  for each row execute function public.parafiscales_con_los_seis();


-- ── QA-34 · confirma_paso() no toca un cancelado ──────────────────────
-- La de supabase-confirma-paso.sql, con 'cancelado' entre lo excluido.
create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;


-- ── QA-35 · La nota de un evento, solo quien lo hizo y ese mismo día ──
-- Cualquier gestor podía reescribir la nota de cualquier evento pasado,
-- también la de una devolución de hace un mes que el inversionista ya
-- leyó. El panel solo escribe la del evento que acaba de nacer de su
-- propio cambio, así que esto no le quita nada. El trigger
-- eventos_solo_la_nota (supabase-gestor.sql) sigue cortando lo demás.
drop policy if exists "eventos: el equipo anota" on public.tramite_eventos;
create policy "eventos: el equipo anota" on public.tramite_eventos
  for update
  using      (public.es_gestor() and autor = auth.uid()
              and creado_en > now() - interval '24 hours')
  with check (public.es_gestor() and autor = auth.uid());


-- ── QA-38 · Escribir una clave de datos sin pisar las demás ───────────
-- El gestor mandaba datos enteros sobre una copia leída hace un rato, y se
-- llevaba por delante lo que el inversionista hubiera marcado entretanto.
-- Esto mezcla en la base. Con los permisos de quien llama: la política y
-- los triggers de tramites deciden, como en un update a secas. Revienta si
-- no tocó ninguna fila.
create or replace function public.mezcla_datos_tramite(p_tramite uuid, p_datos jsonb)
returns public.tramites
language plpgsql
set search_path = public
as $qa$
declare
  fila public.tramites;
begin
  if p_datos is null or jsonb_typeof(p_datos) <> 'object' then
    raise exception 'datos tiene que ser un objeto';
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb) || p_datos
   where id = p_tramite
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo guardar';
  end if;
  return fila;
end
$qa$;

revoke all on function public.mezcla_datos_tramite(uuid, jsonb) from public;
revoke execute on function public.mezcla_datos_tramite(uuid, jsonb) from anon;
grant execute on function public.mezcla_datos_tramite(uuid, jsonb) to authenticated;


-- COMPROBACIÓN
--   select tgname from pg_trigger where tgname in
--     ('tramites_anula_lo_pendiente', 'documentos_en_marcha_no_se_borra',
--      'documentos_en_marcha_no_cambia', 'tramites_parafiscales_con_los_seis');   -- cuatro filas
--   select proname from pg_proc where proname = 'mezcla_datos_tramite';           -- una fila

-- ====================================================================
--  65 / 105   supabase-qa-admin.sql
-- ====================================================================

-- Auditoría QA, administración y cuentas: QA-05, 06, 07, 26, 27, 40 y 43.
-- Idempotente. Va detrás de todos: necesita perfiles con bloqueado
-- (supabase-bloqueo.sql), la bitácora y el tope de la IA.

do $qa$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'perfiles'
                    and column_name = 'bloqueado') then
    raise exception 'Falta perfiles.bloqueado: pasa antes supabase-bloqueo.sql';
  end if;
  if to_regprocedure('public.esta_bloqueado()') is null
     or to_regprocedure('public.corta_si_bloqueado()') is null then
    raise exception 'Falta esta_bloqueado() o corta_si_bloqueado(): pasa antes supabase-bloqueo.sql';
  end if;
end
$qa$;


-- ── QA-05 · Bloquear a alguien del equipo le quita los permisos ────────
-- Misma firma y mismo cuerpo que en supabase-tramites.sql y
-- supabase-admin.sql, con una condición más. Decenas de políticas pasan
-- por aquí: no se toca nada más.
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
      and not coalesce(bloqueado, false)
  );
$$;

create or replace function public.es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.perfiles p
    where p.id = auth.uid() and p.rol = 'admin'
      and not coalesce(p.bloqueado, false)
  );
$$;

-- Las tres tablas que el corte no cubría.
do $qa$
declare
  t text;
begin
  foreach t in array array['activos', 'horario_citas', 'identidad_comprobaciones'] loop
    if to_regclass('public.' || t) is null then
      raise notice 'No existe public.%: se salta', t;
      continue;
    end if;
    execute format('drop trigger if exists %I on public.%I', t || '_bloqueo', t);
    execute format('create trigger %I before insert or update or delete on public.%I '
                   'for each row execute function public.corta_si_bloqueado()',
                   t || '_bloqueo', t);
  end loop;
end
$qa$;

-- El asistente y el lector: una cuenta bloqueada no gasta IA. Devuelve
-- false y no un error, porque con un error las funciones de api/ vuelven
-- al contador de la memoria y dejarían pasar la pregunta.
do $qa$
begin
  if to_regclass('public.uso_ia') is null then
    raise notice 'Sin public.uso_ia: gasta_uso_ia() se queda como esté. Corre supabase-tope-ia.sql y vuelve a pasar este.';
    return;
  end if;

  execute $f$
create or replace function public.gasta_uso_ia(p_pieza text)
returns boolean
language plpgsql
security definer
set search_path = public
as $tope$
declare
  yo   uuid := auth.uid();
  tope integer;
  n    integer;
begin
  if yo is null then
    raise exception 'Hace falta haber entrado' using errcode = '42501';
  end if;

  if public.esta_bloqueado() then
    return false;
  end if;

  -- Las tres definiciones (tope-ia, qa-admin, traduccion-chat) son la
  -- misma desde el 8-10-2026: volver a correr una suelta no puede quitar
  -- el bloqueo ni dejar sin tope al traductor.
  tope := case p_pieza when 'asistente' then 40
                       when 'lector'    then 20
                       when 'traductor' then 60 end;
  if tope is null then
    raise exception 'pieza desconocida: %', p_pieza;
  end if;

  delete from public.uso_ia where usuario = yo and hora < now() - interval '2 days';

  insert into public.uso_ia as u (usuario, pieza, hora, usos)
  values (yo, p_pieza, date_trunc('hour', now()), 1)
  on conflict (usuario, pieza, hora)
  do update set usos = u.usos + 1 where u.usos < tope
  returning usos into n;

  return n is not null;
end
$tope$
  $f$;

  revoke all on function public.gasta_uso_ia(text) from public, anon;
  grant execute on function public.gasta_uso_ia(text) to authenticated;
end
$qa$;


-- ── QA-06 · Dar de baja en vez de borrar ───────────────────────────────
-- La baja deja la cuenta bloqueada y con fecha; los trámites, papeles,
-- citas y aceptaciones del pliego siguen donde estaban.
alter table public.perfiles
  add column if not exists dado_de_baja_en  timestamptz,
  add column if not exists dado_de_baja_por uuid references auth.users(id) on delete set null;

comment on column public.perfiles.dado_de_baja_en is
  'Baja lógica: la cuenta queda bloqueada y su historia se conserva. La pone un admin';

-- Borrar la cuenta en auth.users arrastra en cascada todo lo suyo, y con
-- ello la prueba de que aceptó el pliego. Mientras haya aceptaciones no se
-- borra; si de verdad hay que hacerlo (una cuenta de pruebas), desde el
-- editor de SQL y a sabiendas:
--   begin; set local ciip.borrado_fisico = 'si'; delete from auth.users where ...; commit;
create or replace function public.no_borrar_con_historia()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if coalesce(current_setting('ciip.borrado_fisico', true), '') = 'si' then
    return old;
  end if;
  if to_regclass('public.pliego_aceptaciones') is not null
     and exists (select 1 from public.pliego_aceptaciones a where a.persona = old.id) then
    raise exception 'Esta cuenta aceptó el pliego: no se borra, se da de baja desde el panel (Usuarios)';
  end if;
  return old;
end $$;

drop trigger if exists no_borrar_con_historia on auth.users;
create trigger no_borrar_con_historia
  before delete on auth.users
  for each row execute function public.no_borrar_con_historia();


-- ── QA-26 y QA-40 · Lo que cada cual puede cambiar de un perfil ────────
-- Corre ANTES que los demás disparadores de perfiles (van por orden
-- alfabético y este empieza por «aa»), así que ve solo lo que manda el
-- navegador:
--   · las columnas de rastro vuelven a su valor; las rellenan después los
--     disparadores de siempre (proteger_rol, perfiles_bloqueo,
--     sellar_sector). visto_en solo puede ser la hora del servidor.
--   · en un perfil AJENO solo se mueven el rol, el bloqueo y la baja.
--   · la baja la da un admin, nunca sobre sí mismo, y bloquea.
-- Se trabaja con jsonb para no nombrar columnas que a lo mejor aún no
-- existen (sector_elegido_en, visto_en...).
create or replace function public.perfiles_guarda_columnas()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  yo      uuid := auth.uid();
  viejo   jsonb := to_jsonb(old);
  nuevo   jsonb := to_jsonb(new);
  vuelve  jsonb := '{}'::jsonb;
  c       text;
  rastro  text[] := array['rol_cambiado_por', 'rol_cambiado_en', 'bloqueado_por',
                          'bloqueado_en', 'sector_elegido_en', 'dado_de_baja_por'];
  ajenas  text[] := array['rol', 'bloqueado', 'dado_de_baja_en', 'dado_de_baja_por',
                          'rol_cambiado_por', 'rol_cambiado_en', 'bloqueado_por',
                          'bloqueado_en', 'actualizado_en', 'visto_en', 'sector_elegido_en'];
begin
  if yo is not null then
    foreach c in array rastro loop
      if viejo ? c and (nuevo -> c) is distinct from (viejo -> c) then
        vuelve := vuelve || jsonb_build_object(c, viejo -> c);
      end if;
    end loop;
    if viejo ? 'visto_en' and (nuevo -> 'visto_en') is distinct from (viejo -> 'visto_en') then
      vuelve := vuelve || jsonb_build_object('visto_en', to_jsonb(now()));
    end if;
    if vuelve <> '{}'::jsonb then
      new := jsonb_populate_record(new, vuelve);
    end if;

    if new.id <> yo and (to_jsonb(new) - ajenas) is distinct from (viejo - ajenas) then
      raise exception 'De una cuenta ajena solo se cambian el rol, el bloqueo y la baja'
        using errcode = '42501';
    end if;
  end if;

  if new.dado_de_baja_en is distinct from old.dado_de_baja_en then
    if yo is not null then
      if not public.es_admin() then
        raise exception 'Solo un administrador da de baja una cuenta' using errcode = '42501';
      end if;
      if new.id = yo then
        raise exception 'Nadie se da de baja a sí mismo';
      end if;
    end if;
    if new.dado_de_baja_en is not null then
      new.dado_de_baja_en  := now();
      new.dado_de_baja_por := yo;
      new.bloqueado        := true;
    else
      new.dado_de_baja_por := null;
    end if;
  elsif old.dado_de_baja_en is not null and not new.bloqueado then
    raise exception 'La cuenta está dada de baja: deshaz la baja antes de desbloquearla';
  end if;

  return new;
end $$;

drop trigger if exists aa_perfiles_guarda_columnas on public.perfiles;
create trigger aa_perfiles_guarda_columnas
  before update on public.perfiles
  for each row execute function public.perfiles_guarda_columnas();


-- ── QA-07 · El correo de cada cuenta, solo para el admin ───────────────
-- perfiles no guarda el correo y una cuenta nueva llega «Sin nombre». El
-- correo vive en auth.users, que el navegador no lee: esto lo da, y solo
-- a un admin.
create or replace function public.correos_de_las_cuentas()
returns table (id uuid, correo text)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve los correos' using errcode = '42501';
  end if;
  return query select u.id, u.email::text from auth.users u order by u.id;
end $$;

revoke all on function public.correos_de_las_cuentas() from public;
revoke all on function public.correos_de_las_cuentas() from anon;
grant execute on function public.correos_de_las_cuentas() to authenticated;


-- ── QA-27 · La bitácora guarda el rol de antes, y la baja ──────────────
do $qa$
begin
  if to_regprocedure('public.apunta(text, text, text, text)') is null then
    raise notice 'Sin bitácora: el rol anterior y la baja no se apuntan. Corre supabase-bitacora.sql y vuelve a pasar este.';
    return;
  end if;

  -- El detalle pasa a ser {"rol": nuevo, "antes": viejo}. El panel lee
  -- los dos formatos: los apuntes viejos traen solo el rol nuevo.
  execute $f$
create or replace function public.bit_roles()
returns trigger language plpgsql security definer set search_path = public as $b$
begin
  if new.rol is distinct from old.rol then
    perform public.apunta('roles', 'rol', new.nombre_completo,
      json_build_object('rol', new.rol, 'antes', old.rol)::text);
  end if;
  return null;
end $b$
  $f$;

  execute $f$
create or replace function public.bit_baja()
returns trigger language plpgsql security definer set search_path = public as $b$
begin
  if new.dado_de_baja_en is distinct from old.dado_de_baja_en then
    perform public.apunta('roles',
      case when new.dado_de_baja_en is null then 'alta' else 'baja' end,
      new.nombre_completo);
  end if;
  return null;
end $b$
  $f$;

  drop trigger if exists bitacora_baja on public.perfiles;
  create trigger bitacora_baja
    after update of dado_de_baja_en on public.perfiles
    for each row execute function public.bit_baja();
end
$qa$;


-- ── QA-43 · Lo que no debe llamarse sin sesión, y el original del texto ─
-- «revoke from public» no basta en Supabase: anon tiene su propio grant.
do $qa$
begin
  if to_regprocedure('public.huecos_ocupados(date, date)') is not null then
    revoke execute on function public.huecos_ocupados(date, date) from anon;
  end if;
  if to_regprocedure('public.reserva_cita(timestamptz, text, text, text)') is not null then
    revoke execute on function public.reserva_cita(timestamptz, text, text, text) from anon;
  end if;
end
$qa$;

-- El «original» de un texto lo manda el panel al guardarlo por primera
-- vez: el diccionario vive en el panel, no aquí, y de eso no hay otra
-- fuente. Lo que sí se evita es que un guardado posterior lo reescriba:
-- una vez en la base, el original es el de la base.
do $qa$
begin
  if not exists (select 1 from information_schema.columns
                  where table_schema = 'public' and table_name = 'textos_panel'
                    and column_name = 'original') then
    raise notice 'Sin textos_panel.original: se salta. Corre supabase-textos-rastro.sql y vuelve a pasar este.';
    return;
  end if;

  execute $f$
create or replace function public.textos_original_fijo()
returns trigger language plpgsql as $b$
begin
  new.original := old.original;
  return new;
end $b$
  $f$;

  drop trigger if exists textos_original_fijo on public.textos_panel;
  create trigger textos_original_fijo
    before update on public.textos_panel
    for each row execute function public.textos_original_fijo();
end
$qa$;


-- ── Comprobación ───────────────────────────────────────────────────────
-- Que es_gestor() y es_admin() sigan dejando entrar a quien debe. Si no
-- queda ningún admin sin bloquear, se para aquí y no se aplica nada.
do $qa$
declare
  n_admin int;
begin
  if pg_get_functiondef('public.es_gestor()'::regprocedure) not like '%bloqueado%'
     or pg_get_functiondef('public.es_admin()'::regprocedure) not like '%bloqueado%' then
    raise exception 'es_gestor() o es_admin() no quedaron con el bloqueo';
  end if;
  select count(*) into n_admin from public.perfiles
   where rol = 'admin' and not coalesce(bloqueado, false);
  if n_admin = 0 and exists (select 1 from public.perfiles where rol = 'admin') then
    raise exception 'Todos los admin están bloqueados: nadie podría desbloquearlos. Revisa perfiles antes de correr esto.';
  end if;
end
$qa$;

-- Quién del equipo conserva los permisos después de esto.
select p.nombre_completo, p.rol, p.bloqueado, p.dado_de_baja_en
from   public.perfiles p
where  p.rol in ('gestor', 'admin')
order  by p.rol, p.nombre_completo;

-- ====================================================================
--  66 / 105   supabase-traduccion-chat.sql
-- ====================================================================

-- ══════════════════════════════════════════════════════════════════════
--  LOS MENSAJES DEL CHAT, TRADUCIDOS
--  Pedido del CIIP, 28 de septiembre de 2026
-- ══════════════════════════════════════════════════════════════════════
--
--  QUÉ PIDIÓ EL CIIP
--  «Si el inversionista escribe en japonés, a nosotros nos llega en
--  español, y cuando le respondamos, a él le llega en su idioma.» En los
--  tres chats (trámites, consultas y citas), con «Ver original», y solo
--  desde que se active: lo que ya se dijo no se traduce.
--
--  CÓMO
--  El mensaje se guarda como siempre, en su tabla, y no cambia: esas
--  tablas no dejan tocar una fila escrita, y el original es lo que vale.
--  Al lado, en mensaje_traducciones, una fila por mensaje con el idioma en
--  que se escribió y el texto en el idioma de quien lo va a leer:
--
--    del inversionista  →  al español (lo lee el equipo)
--    del equipo         →  al idioma del inversionista, que es el de su
--                          último mensaje en ese hilo; si todavía no ha
--                          escrito, el de su país
--
--  Si ya está en ese idioma, la fila se guarda igual, con texto nulo: así
--  se sabe en qué idioma escribe cada cual sin volver a preguntárselo a la
--  IA.
--
--  QUIÉN LA ESCRIBE
--  api/traducir.js, con el token de quien mandó el mensaje, a través de
--  guarda_traduccion(). La función solo deja poner la traducción de un
--  mensaje propio, recién escrito y una sola vez. Quien la llame por su
--  cuenta podría poner otra traducción a SU mensaje, que es lo mismo que
--  escribir otro mensaje: el original sigue ahí y «Ver original» lo
--  enseña.
--
--  QUIÉN LA LEE
--  Quien puede leer el mensaje. La política mira la tabla del mensaje con
--  los permisos de quien pregunta, así que manda la RLS de siempre.
--
--  EL TOPE
--  gasta_uso_ia('traductor'): 200 mensajes por hora y persona, que es más
--  de lo que escribe nadie en un chat y corta una pestaña que se vuelve
--  loca. Redefine gasta_uso_ia() de supabase-qa-admin.sql añadiendo la
--  pieza, así que va detrás.
--
--  Se puede correr más de una vez.
-- ══════════════════════════════════════════════════════════════════════

create table if not exists public.mensaje_traducciones (
  tabla           text        not null,
  mensaje         uuid        not null,
  idioma_original text        not null,
  idioma          text        not null,
  texto           text,
  creado_en       timestamptz not null default now(),
  primary key (tabla, mensaje),
  constraint traduccion_de_un_chat check (tabla in ('tramite_mensajes', 'consulta_mensajes', 'cita_mensajes')),
  constraint traduccion_idiomas check (idioma_original ~ '^[a-z]{2,3}$' and idioma ~ '^[a-z]{2,3}$'),
  constraint traduccion_cabe check (texto is null or length(texto) <= 8000)
);

comment on table public.mensaje_traducciones is
  'La traducción automática de cada mensaje de chat al idioma de quien lo lee. texto nulo = no hacía falta. Solo la escribe guarda_traduccion()';

alter table public.mensaje_traducciones enable row level security;
revoke all on public.mensaje_traducciones from anon, authenticated;
grant select on public.mensaje_traducciones to authenticated;

drop policy if exists "traducciones: quien lee el mensaje" on public.mensaje_traducciones;
create policy "traducciones: quien lee el mensaje" on public.mensaje_traducciones
  for select to authenticated using (
    case tabla
      when 'tramite_mensajes'  then exists (select 1 from public.tramite_mensajes  m where m.id = mensaje)
      when 'consulta_mensajes' then exists (select 1 from public.consulta_mensajes m where m.id = mensaje)
      when 'cita_mensajes'     then exists (select 1 from public.cita_mensajes     m where m.id = mensaje)
      else false
    end
  );

create or replace function public.guarda_traduccion(
  p_tabla text, p_mensaje uuid, p_idioma_original text, p_idioma text, p_texto text)
returns boolean
language plpgsql
security definer
set search_path = public
as $tr$
declare
  yo    uuid := auth.uid();
  autor uuid;
  hecho timestamptz;
begin
  if yo is null then
    raise exception 'Hace falta haber entrado' using errcode = '42501';
  end if;
  if public.esta_bloqueado() then
    return false;
  end if;

  if p_tabla = 'tramite_mensajes' then
    select m.autor, m.creado_en into autor, hecho from public.tramite_mensajes m where m.id = p_mensaje;
  elsif p_tabla = 'consulta_mensajes' then
    select m.autor, m.creado_en into autor, hecho from public.consulta_mensajes m where m.id = p_mensaje;
  elsif p_tabla = 'cita_mensajes' then
    select m.autor, m.creado_en into autor, hecho from public.cita_mensajes m where m.id = p_mensaje;
  else
    raise exception 'tabla desconocida: %', p_tabla;
  end if;

  -- Solo lo propio y recién escrito: la traducción sale al enviar.
  if autor is distinct from yo or hecho < now() - interval '15 minutes' then
    raise exception 'Solo se traduce un mensaje propio, al enviarlo' using errcode = '42501';
  end if;

  insert into public.mensaje_traducciones (tabla, mensaje, idioma_original, idioma, texto)
  values (p_tabla, p_mensaje, lower(p_idioma_original), lower(p_idioma), nullif(btrim(p_texto), ''))
  on conflict (tabla, mensaje) do nothing;

  return found;
end
$tr$;

revoke all on function public.guarda_traduccion(text, uuid, text, text, text) from public, anon;
grant execute on function public.guarda_traduccion(text, uuid, text, text, text) to authenticated;

-- El tope: la pieza 'traductor' entra en uso_ia y en gasta_uso_ia().
do $tr$
begin
  if to_regclass('public.uso_ia') is null then
    raise notice 'Sin public.uso_ia: el traductor usa el contador de la memoria. Corre supabase-tope-ia.sql y vuelve a pasar este.';
    return;
  end if;

  alter table public.uso_ia drop constraint if exists uso_ia_pieza_valida;
  alter table public.uso_ia add constraint uso_ia_pieza_valida
    check (pieza in ('asistente', 'lector', 'traductor'));

  execute $f$
create or replace function public.gasta_uso_ia(p_pieza text)
returns boolean
language plpgsql
security definer
set search_path = public
as $tope$
declare
  yo   uuid := auth.uid();
  tope integer;
  n    integer;
begin
  if yo is null then
    raise exception 'Hace falta haber entrado' using errcode = '42501';
  end if;

  if public.esta_bloqueado() then
    return false;
  end if;

  -- Traductor: 60 por hora (8-10-2026, auditoría). Cada traducción pide un
  -- mensaje nuevo y propio, y 60 mensajes por hora ya es mucho escribir.
  tope := case p_pieza when 'asistente' then 40
                       when 'lector'    then 20
                       when 'traductor' then 60 end;
  if tope is null then
    raise exception 'pieza desconocida: %', p_pieza;
  end if;

  delete from public.uso_ia where usuario = yo and hora < now() - interval '2 days';

  insert into public.uso_ia as u (usuario, pieza, hora, usos)
  values (yo, p_pieza, date_trunc('hour', now()), 1)
  on conflict (usuario, pieza, hora)
  do update set usos = u.usos + 1 where u.usos < tope
  returning usos into n;

  return n is not null;
end
$tope$
  $f$;

  revoke all on function public.gasta_uso_ia(text) from public, anon;
  grant execute on function public.gasta_uso_ia(text) to authenticated;
end
$tr$;

-- ====================================================================
--  67 / 105   supabase-planilla-firmada.sql
-- ====================================================================

-- La planilla firmada, de vuelta desde «Firme la planilla» (Franklin Reyes,
-- 29-9-2026): el inversionista la sube desde ese paso de su escalera, con
-- la solicitud ya enviada, en los dos RIF (c3, c6) y en la licencia (c10).
-- Solo necesita tipos_documento, tramites, documentos y tramite_documentos.
-- Se puede correr más de una vez. Sin él el panel no se rompe: la subida
-- falla y el paso lo dice.

insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_firmada', 'Planilla de solicitud firmada', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- «adjuntos: adjuntar a lo propio» solo deja colgar papeles en borrador o
-- devuelta; ésta llega con la solicitud en marcha. Va en su propia
-- política, como la del SIDCAI: las políticas se suman, y así no se
-- reescribe la de otro archivo.
drop policy if exists "adjuntos: la planilla firmada, desde su paso" on public.tramite_documentos;
create policy "adjuntos: la planilla firmada, desde su paso" on public.tramite_documentos
  for insert
  with check (
    exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and t.inversionista = auth.uid()
         and d.inversionista = auth.uid()
         and d.tipo = 'planilla_firmada'
         and t.tipo in ('rif_personal', 'rif_empresa', 'licencia_municipal')
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
  );

-- COMPROBACIÓN
--   select codigo, nombre from public.tipos_documento where codigo = 'planilla_firmada';  -- una fila
--   select polname from pg_policy
--    where polname = 'adjuntos: la planilla firmada, desde su paso';                     -- una fila

-- ====================================================================
--  68 / 105   supabase-planilla-rif.sql
-- ====================================================================

-- La planilla del RIF que el CIIP manda para firmar (30-9-2026).

insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_solicitud', 'Planilla de solicitud del RIF (la prepara el CIIP)', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

drop policy if exists "documentos: el equipo sube la planilla del RIF" on public.documentos;
create policy "documentos: el equipo sube la planilla del RIF" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_solicitud' and estado = 'validado');

drop policy if exists "adjuntos: el equipo engancha la planilla del RIF" on public.tramite_documentos;
create policy "adjuntos: el equipo engancha la planilla del RIF" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_solicitud'
         and t.tipo in ('rif_personal', 'rif_empresa')
         and t.estado in ('enviado', 'en_revision')
    )
  );

-- COMPROBACIÓN
--   select codigo from public.tipos_documento where codigo = 'planilla_solicitud';   -- una fila
--   select polname from pg_policy where polname like '%planilla del RIF%';           -- dos filas

-- ====================================================================
--  69 / 105   supabase-visa-planilla.sql
-- ====================================================================

-- Las dos visas (c1 y c38) con la planilla de solicitud (Franklin Reyes,
-- 30-9-2026): el CIIP la manda tras revisar los recaudos, el inversionista
-- la devuelve firmada y sin ella no se presenta ante la Cancillería.
-- Va detrás de supabase-marca.sql y supabase-planilla-firmada.sql. Se
-- puede correr más de una vez.

do $comprueba$
begin
  if to_regprocedure('public.marca_ahora()') is null then
    raise exception 'Falta supabase-marca.sql: va antes que éste';
  end if;
end
$comprueba$;

insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_visa',    'Planilla de solicitud de visa',  false),
  ('planilla_firmada', 'Planilla de solicitud firmada',  false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- La planilla la manda el equipo, validada, y la cuelga de la visa en
-- revisión o ante el ente.
drop policy if exists "documentos: el equipo manda la planilla de la visa" on public.documentos;
create policy "documentos: el equipo manda la planilla de la visa" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_visa' and estado = 'validado');

drop policy if exists "adjuntos: el equipo cuelga la planilla de la visa" on public.tramite_documentos;
create policy "adjuntos: el equipo cuelga la planilla de la visa" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_visa'
         and t.tipo in ('visa_negocios', 'visa_inversionista')
         and t.estado in ('en_revision', 'ante_el_ente')
    )
  );

-- La de supabase-planilla-firmada.sql, con las dos visas en la lista.
drop policy if exists "adjuntos: la planilla firmada, desde su paso" on public.tramite_documentos;
create policy "adjuntos: la planilla firmada, desde su paso" on public.tramite_documentos
  for insert
  with check (
    exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and t.inversionista = auth.uid()
         and d.inversionista = auth.uid()
         and d.tipo = 'planilla_firmada'
         and t.tipo in ('rif_personal', 'rif_empresa', 'licencia_municipal',
                        'visa_negocios', 'visa_inversionista')
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
    )
  );

-- La planilla de la visa solo la hace el equipo.
create or replace function public.visa_planilla_del_ciip()
returns trigger
language plpgsql
as $visa$
begin
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.tipo = 'planilla_visa'
     or (tg_op = 'UPDATE' and old.tipo = 'planilla_visa') then
    raise exception 'Ese papel lo emite el CIIP'
      using errcode = 'check_violation';
  end if;
  return new;
end
$visa$;

drop trigger if exists documentos_visa_planilla_del_ciip on public.documentos;
create trigger documentos_visa_planilla_del_ciip
  before insert or update on public.documentos
  for each row execute function public.visa_planilla_del_ciip();

-- Colgada la planilla, su paso; colgada la firmada (no rechazada), el suyo.
create or replace function public.visa_apunta_la_planilla()
returns trigger
language plpgsql
security definer
set search_path = public
as $visa$
declare
  papel public.documentos;
  suTipo text;
  clave text;
begin
  select * into papel from public.documentos where id = new.documento;
  select tipo into suTipo from public.tramites where id = new.tramite;
  if suTipo is null or suTipo not in ('visa_negocios', 'visa_inversionista') or papel.id is null then
    return new;
  end if;
  clave := case
    when papel.tipo = 'planilla_visa'                                   then 'planilla'
    when papel.tipo = 'planilla_firmada' and papel.estado <> 'rechazado' then 'firmada'
  end;
  if clave is null then
    return new;
  end if;
  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(clave, public.marca_ahora()))
   where id = new.tramite
     and not coalesce((datos -> 'pasos_ciip') ? clave, false);
  return new;
end
$visa$;

drop trigger if exists tramite_documentos_visa_apunta on public.tramite_documentos;
create trigger tramite_documentos_visa_apunta
  after insert on public.tramite_documentos
  for each row execute function public.visa_apunta_la_planilla();

-- Rechazada la firmada, su paso vuelve a estar por hacer, salvo que haya
-- colgada otra que valga.
create or replace function public.visa_borra_la_firmada_rechazada()
returns trigger
language plpgsql
security definer
set search_path = public
as $visa$
begin
  if new.tipo <> 'planilla_firmada' or new.estado <> 'rechazado'
     or old.estado = 'rechazado' then
    return new;
  end if;
  update public.tramites t
     set datos = jsonb_set(t.datos, '{pasos_ciip}', (t.datos -> 'pasos_ciip') - 'firmada')
   where t.tipo in ('visa_negocios', 'visa_inversionista')
     and (t.datos -> 'pasos_ciip') ? 'firmada'
     and t.id in (select td.tramite from public.tramite_documentos td where td.documento = new.id)
     and not exists (
       select 1
         from public.tramite_documentos td2
         join public.documentos d2 on d2.id = td2.documento
        where td2.tramite = t.id
          and d2.id <> new.id
          and d2.tipo = 'planilla_firmada'
          and d2.estado <> 'rechazado');
  return new;
end
$visa$;

drop trigger if exists documentos_visa_firmada_rechazada on public.documentos;
create trigger documentos_visa_firmada_rechazada
  after update of estado on public.documentos
  for each row execute function public.visa_borra_la_firmada_rechazada();

-- Sin la planilla firmada, la visa no pasa a la Cancillería.
create or replace function public.visa_con_planilla_firmada()
returns trigger
language plpgsql
as $visa$
begin
  if auth.uid() is null
     or new.tipo not in ('visa_negocios', 'visa_inversionista')
     or new.estado is distinct from 'ante_el_ente'
     or old.estado = 'ante_el_ente' then
    return new;
  end if;
  if not coalesce((new.datos -> 'pasos_ciip') ? 'firmada', false) then
    raise exception 'Falta la planilla firmada del inversionista'
      using errcode = 'check_violation';
  end if;
  return new;
end
$visa$;

drop trigger if exists tramites_visa_con_planilla_firmada on public.tramites;
create trigger tramites_visa_con_planilla_firmada
  before update on public.tramites
  for each row execute function public.visa_con_planilla_firmada();

-- COMPROBACIÓN
--   select codigo from public.tipos_documento where codigo = 'planilla_visa';          -- una fila
--   select tgname from pg_trigger
--    where tgname in ('tramite_documentos_visa_apunta', 'documentos_visa_firmada_rechazada',
--                     'tramites_visa_con_planilla_firmada', 'documentos_visa_planilla_del_ciip');  -- cuatro

-- ====================================================================
--  70 / 105   supabase-planilla-ivss.sql
-- ====================================================================

-- La planilla de inscripción del IVSS que el CIIP manda al inversionista (30-9-2026).
-- Va colgada de la fila del IVSS en tramite_entes, en la columna documento. Se puede correr más de una vez.

insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_ivss', 'Planilla de inscripción del IVSS (la prepara el CIIP)', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

drop policy if exists "documentos: el equipo manda la planilla del IVSS" on public.documentos;
create policy "documentos: el equipo manda la planilla del IVSS" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_ivss' and estado = 'validado');

drop policy if exists "adjuntos: el equipo cuelga la planilla del IVSS" on public.tramite_documentos;
create policy "adjuntos: el equipo cuelga la planilla del IVSS" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_ivss'
         and t.tipo = 'registros_parafiscales'
    )
  );

-- Solo la hace el equipo: un inversionista no puede subir una ni cambiar un papel a ese tipo.
create or replace function public.planilla_ivss_del_ciip()
returns trigger
language plpgsql
as $ivss$
begin
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.tipo = 'planilla_ivss'
     or (tg_op = 'UPDATE' and old.tipo = 'planilla_ivss') then
    raise exception 'Ese papel lo emite el CIIP'
      using errcode = 'check_violation';
  end if;
  return new;
end
$ivss$;

drop trigger if exists documentos_planilla_ivss_del_ciip on public.documentos;
create trigger documentos_planilla_ivss_del_ciip
  before insert or update on public.documentos
  for each row execute function public.planilla_ivss_del_ciip();

-- Comprobación: debe salir una fila con el tipo y dos políticas.
select codigo, nombre from public.tipos_documento where codigo = 'planilla_ivss';
select tablename, policyname from pg_policies where policyname ilike '%planilla del IVSS%';

-- ====================================================================
--  71 / 105   supabase-opcion2.sql
-- ====================================================================

-- Taquilla única, opción 2 (Franklin Reyes, 1-10-2026): el inversionista se registra él mismo en el
-- portal de cada ente y marca que lo hizo. Va detrás de supabase-qa-tramites.sql. Se puede correr más de una vez.

-- Las marcas que el inversionista puede poner con su botón.
create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;

-- La visa ya no lleva planilla del CIIP ni firmada: fuera sus disparadores y las políticas de la planilla.
drop trigger if exists tramites_visa_con_planilla_firmada on public.tramites;
drop function if exists public.visa_con_planilla_firmada();
drop trigger if exists tramite_documentos_visa_apunta on public.tramite_documentos;
drop function if exists public.visa_apunta_la_planilla();
drop trigger if exists documentos_visa_firmada_rechazada on public.documentos;
drop function if exists public.visa_borra_la_firmada_rechazada();
drop policy if exists "documentos: el equipo manda la planilla de la visa" on public.documentos;
drop policy if exists "adjuntos: el equipo cuelga la planilla de la visa" on public.tramite_documentos;

-- La licencia ya no lleva importes de tasa y timbre: deja de exigir sus comprobantes para resolverse.
drop trigger if exists tramites_licencia_pagos on public.tramites;

-- Los pasos de estos cinco trámites escritos a mano desde «Editar textos» taparían los nuevos.
delete from public.textos_panel
 where clave like '\_p.pasos.c1.%'  or clave like '\_p.circuito.c1.%'
    or clave like '\_p.pasos.c38.%' or clave like '\_p.circuito.c38.%'
    or clave like '\_p.pasos.c10.%' or clave like '\_p.circuito.c10.%'
    or clave like '\_p.pasos.c28.%' or clave like '\_p.circuito.c28.%'
    or clave like '\_p.pasos.c36.%' or clave like '\_p.circuito.c36.%';

-- Comprobación: ninguna fila (los dos candados quitados).
select tgname from pg_trigger
 where tgname in ('tramites_visa_con_planilla_firmada', 'tramites_licencia_pagos');

-- ====================================================================
--  72 / 105   supabase-bomberos-opcion2.sql
-- ====================================================================

-- Permiso de bomberos como la Taquilla única opción 2 (Franklin Reyes, 1-10-2026): el inversionista
-- lo solicita en el portal de los bomberos y marca dos pasos. Va detrás de supabase-opcion2.sql.
-- Se puede correr más de una vez.

-- Las marcas del botón: las de supabase-opcion2.sql y 'bomberos_solicitado'.
create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                     'bomberos_solicitado') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;

-- Un paso que pide un dato: guarda lo escrito (no la fecha). Hoy solo la sede de bomberos.
create or replace function public.anota_paso(p_tramite uuid, p_clave text, p_valor text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
  valor text := btrim(coalesce(p_valor, ''));
begin
  if p_clave not in ('sede_bomberos') then
    raise exception 'paso desconocido: %', p_clave;
  end if;
  if valor = '' or char_length(valor) > 200 then
    raise exception 'el dato tiene que tener entre 1 y 200 caracteres';
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb) || jsonb_build_object(p_clave, valor)
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo anotar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.anota_paso(uuid, text, text) from public;
revoke execute on function public.anota_paso(uuid, text, text) from anon;
grant execute on function public.anota_paso(uuid, text, text) to authenticated;

-- Sin importe ni comprobante por el CIIP: deja de exigir el de aranceles para resolverse.
drop trigger if exists tramites_bomberos_pago on public.tramites;

-- Los pasos del c29 escritos a mano desde «Editar textos» taparían los nuevos.
delete from public.textos_panel
 where clave like '\_p.pasos.c29.%' or clave like '\_p.circuito.c29.%';

-- Comprobación: una fila (anota_paso) y ninguna del candado.
select proname from pg_proc where proname = 'anota_paso';
select tgname from pg_trigger where tgname = 'tramites_bomberos_pago';

-- ====================================================================
--  73 / 105   supabase-cedula-opcion2.sql
-- ====================================================================

-- Cédula de identidad de extranjero como la Taquilla única opción 2 (Franklin Reyes, 1-10-2026,
-- «Ventanilla unica 2.4»): el inversionista se registra y la solicita en el portal del SAIME y lo
-- marca con «Ya me registré». Va detrás de supabase-bomberos-opcion2.sql. Se puede correr más de una vez.

create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada', 'saime_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                     'bomberos_solicitado') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;

-- ====================================================================
--  74 / 105   supabase-locti-opcion2.sql
-- ====================================================================

-- Inscripción en el SIDCAI (c39) por el portal (Franklin Reyes, 1-10-2026, Ventanilla Única 2.3): el
-- inversionista se inscribe en el FONACIT y lo marca con «Ya me inscribí». Va detrás de
-- supabase-cedula-opcion2.sql. Se puede correr más de una vez.

-- Las marcas del botón: las de supabase-cedula-opcion2.sql (con 'saime_confirmada') y 'locti_inscrito'.
create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                     'bomberos_solicitado', 'saime_confirmada', 'locti_inscrito') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;

-- Los pasos del c39 escritos a mano desde «Editar textos» taparían los nuevos.
delete from public.textos_panel
 where clave like '\_p.pasos.c39.%' or clave like '\_p.circuito.c39.%';

-- Comprobación: una fila, true en las dos si confirma_paso ya acepta la cédula y el LOCTI.
select position('locti_inscrito' in pg_get_functiondef('public.confirma_paso(uuid, text)'::regprocedure)) > 0
       as acepta_locti_inscrito,
       position('saime_confirmada' in pg_get_functiondef('public.confirma_paso(uuid, text)'::regprocedure)) > 0
       as acepta_saime_confirmada;

-- ====================================================================
--  75 / 105   supabase-control-estadisticas.sql
-- ====================================================================

-- Control y Estadísticas (Franklin Reyes, 1-10-2026): el sector de cada consulta, los trámites
-- específicos de cada sector y las cifras del administrador. Va detrás de supabase-admin.sql
-- (es_admin), supabase-consultas.sql y supabase-tramites.sql. Se puede correr más de una vez.

-- 1. EL SECTOR DE LA CONSULTA
-- Lo elige el inversionista en la consulta nueva que abre la franja del final del catálogo.
-- Hasta hoy solo iba escrito, traducido, en el asunto, y un texto en ocho idiomas no se cuenta.
-- Se guarda un código estable; los seis que ya existían en public.sectores se reutilizan tal
-- cual, y energetico, telecomunicaciones y construccion son nuevos. No es una clave foránea
-- a public.sectores porque ese catálogo es el del perfil y no tiene esos tres.
alter table public.consultas
  add column if not exists sector text;

alter table public.consultas
  drop constraint if exists consultas_sector_valido;
alter table public.consultas
  add constraint consultas_sector_valido check (sector is null or sector in (
    'hidrocarburos', 'mineria', 'industrial', 'agroindustrial', 'pesca_acuicultura',
    'energetico', 'telecomunicaciones', 'turismo', 'construccion'));

comment on column public.consultas.sector is 'Sector que eligió el inversionista al abrir la consulta desde la franja del catálogo. Null = no eligió ninguno';

create index if not exists consultas_por_sector
  on public.consultas (sector) where sector is not null;

-- 2. LOS TRÁMITES ESPECÍFICOS DE CADA SECTOR
-- La lista la escribe el administrador en «Control y Estadísticas»; el inversionista la ve en
-- el chat al elegir el sector. Leer, cualquiera con sesión; escribir, solo el administrador.
create table if not exists public.tramites_por_sector (
  id             uuid primary key default gen_random_uuid(),
  sector         text not null,
  nombre         text not null,
  organismo      text not null default '',
  orden          integer not null default 0,
  creado_en      timestamptz not null default now(),
  actualizado_en timestamptz not null default now(),

  constraint tramites_por_sector_sector_valido check (sector in (
    'hidrocarburos', 'mineria', 'industrial', 'agroindustrial', 'pesca_acuicultura',
    'energetico', 'telecomunicaciones', 'turismo', 'construccion')),
  constraint tramites_por_sector_nombre_cabe check (length(trim(nombre)) between 1 and 200),
  constraint tramites_por_sector_organismo_cabe check (length(organismo) <= 200)
);

comment on table public.tramites_por_sector is 'Trámites específicos por los que pregunta el inversionista en cada sector; los carga el administrador';

create index if not exists tramites_por_sector_lista
  on public.tramites_por_sector (sector, orden);

create or replace function public.tramites_por_sector_al_cambiar()
returns trigger
language plpgsql
as $$
begin
  new.actualizado_en := now();
  return new;
end;
$$;

drop trigger if exists tramites_por_sector_cambio on public.tramites_por_sector;
create trigger tramites_por_sector_cambio
  before update on public.tramites_por_sector
  for each row execute function public.tramites_por_sector_al_cambiar();

alter table public.tramites_por_sector enable row level security;

drop policy if exists "tramites_por_sector: leerlos" on public.tramites_por_sector;
create policy "tramites_por_sector: leerlos"
  on public.tramites_por_sector for select
  to authenticated
  using (true);

drop policy if exists "tramites_por_sector: solo el admin escribe" on public.tramites_por_sector;
create policy "tramites_por_sector: solo el admin escribe"
  on public.tramites_por_sector for all
  using      (public.es_admin())
  with check (public.es_admin());

grant select, insert, update, delete on public.tramites_por_sector to authenticated;

-- 3. LAS CIFRAS
-- Una sola función, security definer, que comprueba ella misma que quien llama es
-- administrador: así el conteo no depende de qué políticas de lectura haya corridas en
-- tramites, tramite_eventos y consultas, y lo que viaja son las cifras y no las filas.
-- Solicitado = enviado alguna vez (enviado_en, o un estado posterior al borrador); los
-- borradores y lo cancelado sin enviar no cuentan. El tiempo, solo de lo resuelto: de
-- enviado_en a resuelto_en, que pone el disparador registrar_evento_tramite(); y aparte, el
-- tramo «ante el ente», del primer evento ante_el_ente a resuelto_en.
create or replace function public.estadisticas_control()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r jsonb;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve las estadísticas' using errcode = '42501';
  end if;

  with enviados as (
    select t.id, t.tipo, coalesce(tt.ente, '') as ente, t.estado,
           t.datos,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
  resueltos as (
    select e.tipo, e.ente,
           extract(epoch from (e.resuelto_en - e.desde)) / 3600.0 as horas,
           (select extract(epoch from (e.resuelto_en - min(ev.creado_en))) / 3600.0
              from public.tramite_eventos ev
             where ev.tramite = e.id and ev.a_estado = 'ante_el_ente'
            having min(ev.creado_en) <= e.resuelto_en) as horas_ente
      from enviados e
     where e.estado = 'resuelto'
       and e.resuelto_en is not null
       and e.resuelto_en >= e.desde
  ),
  por_tipo as (
    select tipo, max(ente) as ente, count(*) as solicitados
      from enviados
     group by tipo
  ),
  tiempo_tipo as (
    select tipo,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente
      from resueltos
     group by tipo
  ),
  tiempo_ente as (
    select ente,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente
      from resueltos
     group by ente
  ),
  por_sector as (
    select sector, count(*) as n
      from public.consultas
     where sector is not null
     group by sector
  ),
  -- Los motivos de «ya lo solicité» (6-10-2026): por qué pide ayuda el inversionista, ente por
  -- ente. En c45 a c47 hay un solo ente, el del catálogo, y un motivo_ya; en c44, uno por cada
  -- ente marcado, motivo_ya_<ente>. Se guardan en español (opcionesClave), así que se agrupan
  -- igual los haya escrito quien sea en el idioma que sea.
  -- Y el SACS ya solicitado (c49, Franklin Reyes, 7-10-2026, Ventanilla única 2.7), con su ente
  -- del catálogo, 'SACS', y su motivo_ya, como c45 a c47.
  motivos as (
    select m.motivo, m.ente, count(*) as n
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso')
        union all
        select e.datos ->> ('motivo_ya_' || x.clave), x.ente
          from enviados e
         cross join (values ('banavih', 'BANAVIH (FAOV)'), ('inces', 'INCES'),
                            ('rupdae', 'RUPDAE'), ('ivss', 'IVSS'),
                            ('rnet', 'RNET'), ('rnc', 'RNC')) as x(clave, ente)
         where e.tipo = 'parafiscales_en_proceso'
      ) m
     where coalesce(m.motivo, '') <> ''
     group by m.motivo, m.ente
  )
  select jsonb_build_object(
    'tramites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', p.tipo, 'ente', p.ente, 'solicitados', p.solicitados,
               'resueltos', coalesce(x.n, 0),
               'mediana_h', round(x.mediana::numeric, 1),
               'promedio_h', round(x.promedio::numeric, 1),
               'n_ente', coalesce(x.n_ente, 0),
               'mediana_ente_h', round(x.mediana_ente::numeric, 1))
             order by p.solicitados desc, p.tipo)
        from por_tipo p
        left join tiempo_tipo x on x.tipo = p.tipo), '[]'::jsonb),
    'entes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ente', y.ente, 'resueltos', y.n,
               'mediana_h', round(y.mediana::numeric, 1),
               'promedio_h', round(y.promedio::numeric, 1),
               'n_ente', y.n_ente,
               'mediana_ente_h', round(y.mediana_ente::numeric, 1))
             order by y.n desc, y.ente)
        from tiempo_ente y), '[]'::jsonb),
    'sectores', coalesce((
      select jsonb_agg(jsonb_build_object('sector', s.sector, 'consultas', s.n)
             order by s.n desc, s.sector)
        from por_sector s), '[]'::jsonb),
    'motivos', coalesce((
      select jsonb_agg(jsonb_build_object('motivo', mo.motivo, 'ente', mo.ente, 'n', mo.n)
             order by mo.n desc, mo.motivo, mo.ente)
        from motivos mo), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;

-- ====================================================================
--  76 / 105   supabase-bienes.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — BIENES: COMPRAVENTA O ALQUILER DE UN INMUEBLE
--  (c41 y c42)
--  Necesita el catálogo con `nivel` y `emite` (supabase-informe-victor.sql
--  y supabase-encadenado.sql). Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  Franklin Reyes, 2 de octubre de 2026: un servicio nuevo del CIIP en la
--  estructura corporativa (fase 2). El inversionista elige la operación
--  -compraventa o alquiler- y después el servicio:
--
--    Redacción de contrato y acompañamiento: llena los datos y consigna los
--    recaudos, como en cualquier solicitud, y el CIIP redacta el contrato.
--    Es un trámite, con su escalera: recibida, revisión de recaudos,
--    redacción del contrato y contrato listo (el contrato lo sube el equipo
--    al resolver, y queda en la bóveda como cualquier documento emitido).
--
--    Asesoría legal: una consulta en el chat con el tema que escribe. No es
--    un trámite: es una fila de `consultas` con el código del trámite en
--    `tipo` -por eso tiene que existir aquí, por la llave foránea- y la
--    operación delante del tema en `asunto`. No necesita nada más.
--
--  Las dos operaciones son DOS tipos, como las dos visas (c1 y c38): cada
--  una con sus campos, sus recaudos y su solicitud viva (tramites_una_viva),
--  y la del alquiler escondida de la cuadrícula del panel.
--
--  Nivel 'actividad': hace falta según lo que haga la empresa -quien opera
--  desde casa o en un local que ya tiene no lo necesita-, y lo de
--  'actividad' no se aparta nunca de su fase. No emite ningún tipo del
--  catálogo: el contrato entra como 'resolucion', y no hay trámite que lo
--  pida como recaudo, así que no hay cadena que encender.
--
--  LOS RECAUDOS DE LA COMPRAVENTA, CON LAS DOS PARTES (Franklin Reyes,
--  2-10-2026, el mismo día): el documento de propiedad, la Forma 33, la
--  cédula de identidad y el RIF del vendedor y los del comprador, la cédula
--  catastral y la solvencia municipal de inmuebles urbanos. El contrato
--  lleva al que vende y al que compra, y «el propietario» era solo uno de
--  los dos: identidad_propietario se queda para el alquiler, que no cambia.
--
--  Y el vendedor puede ser una empresa. Lo pregunta la primera casilla del
--  formulario, «¿El vendedor es una persona jurídica?»: con «Sí», en lugar
--  de su cédula -una empresa no tiene- se piden el acta constitutiva y su
--  última actualización, la cédula y el RIF del representante legal, el
--  acta de asamblea que lo nombra y el RIF de la empresa. Qué se pide y
--  cuándo lo decide el panel (RECAUDOS.bienes_compraventa, en panel.js);
--  aquí solo nacen los siete tipos nuevos.
--
--  Si ya se corrió la versión anterior de este archivo, HAY QUE VOLVER A
--  CORRERLO: documentos.tipo apunta a tipos_documento, y sin los siete
--  tipos la base rechaza esos papeles al subirlos y la compraventa no se
--  puede enviar.
-- ═══════════════════════════════════════════════════════════════════════

-- Los recaudos de la redacción: los del alquiler, los de la compraventa y
-- los cuatro de la empresa vendedora. La cédula catastral ya la creó
-- supabase-conformidad-uso.sql; se repite abajo por si este va antes.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('propiedad_inmueble',     'Documento de propiedad del inmueble, registrado',                  false),
  ('identidad_propietario',  'Cédula o RIF del propietario del inmueble',                        false),
  ('solvencia_inmuebles',    'Solvencia municipal de inmuebles urbanos',                         true),
  ('forma_33',               'Forma 33',                                                         false),
  ('identidad_vendedor',     'Cédula de identidad y RIF del vendedor',                           false),
  ('identidad_comprador',    'Cédula de identidad y RIF del comprador',                          false),
  ('acta_vendedor',          'Acta constitutiva y última actualización de la empresa vendedora', false),
  ('identidad_rep_vendedor', 'Cédula y RIF del representante legal de la empresa vendedora',     false),
  ('asamblea_rep_vendedor',  'Acta de asamblea con el nombramiento del representante legal',     false),
  ('rif_vendedor',           'RIF de la empresa vendedora',                                      false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

insert into public.tipos_documento (codigo, nombre, vence) values
  ('cedula_catastral',      'Cédula catastral del inmueble',                   false)
on conflict (codigo) do nothing;

-- Los dos trámites, con el CIIP de ente: el servicio lo da el propio CIIP.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('bienes_compraventa', 'c41', 'Bienes: compraventa de un inmueble', 'CIIP', 2, true),
  ('bienes_alquiler',    'c42', 'Bienes: alquiler de un inmueble',    'CIIP', 2, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite      = null,
       plazo_dias = null,
       nivel      = 'actividad',
       activo     = true
 where codigo in ('bienes_compraventa', 'bienes_alquiler');

-- COMPROBACIÓN
--   select codigo, ref_panel, fase, nivel, activo from public.tipos_tramite
--    where codigo like 'bienes\_%';                                        -- dos filas
--   select codigo, vence from public.tipos_documento
--    where codigo in ('propiedad_inmueble', 'identidad_propietario',
--                     'solvencia_inmuebles', 'cedula_catastral',
--                     'forma_33', 'identidad_vendedor', 'identidad_comprador',
--                     'acta_vendedor', 'identidad_rep_vendedor',
--                     'asamblea_rep_vendedor', 'rif_vendedor');             -- once filas
--   Solo solvencia_inmuebles con vence = true.

-- ====================================================================
--  77 / 105   supabase-marca-proceso.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA MARCA EN PROCESO DE REGISTRO (c43)
--  Necesita el catálogo con `nivel` y `emite` (supabase-informe-victor.sql
--  y supabase-encadenado.sql). Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  Franklin Reyes, 5 de octubre de 2026 («Ventanilla única 2.5»): el
--  registro de marca se divide en dos opciones previas.
--
--    «¿Quieres registrar tu marca por primera vez?» es el registro de
--    siempre (marca, c8), y no cambia nada.
--
--    «¿Tienes una marca en proceso de registro?» es un trámite nuevo,
--    marca_en_proceso (c43): cuatro datos -el nombre de la marca, la fecha
--    de la solicitud, a nombre de quién se registra y, si la hubo, la
--    oposición, el recurso o la devolución del SAPI-, dos recaudos -la
--    planilla de solicitud y la cédula y el RIF de quien registra la
--    marca- y su escalera: revisión de estatus, solicitud de información
--    al SAPI y marca concedida. Va con los cuatro estados de siempre; no
--    usa nada de supabase-marca.sql, que es solo del registro nuevo.
--
--  Como las dos visas y «Bienes»: la casilla de la portada es la c8 y la
--  c43 va escondida con data-tramo-de, cada una con sus campos, sus
--  recaudos y su solicitud viva (tramites_una_viva). Nivel 'esencial', el
--  de la marca: la casilla es la misma, solo cambia en qué punto llega.
-- ═══════════════════════════════════════════════════════════════════════

insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_solicitud_marca', 'Planilla de solicitud de registro de marca',  false),
  ('identidad_titular_marca',  'Cédula y RIF de quien registra la marca',     false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('marca_en_proceso', 'c43', 'Registro de marca: marca en proceso de registro', 'SAPI', 2, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite      = null,
       plazo_dias = null,
       nivel      = 'esencial',
       activo     = true
 where codigo = 'marca_en_proceso';

-- COMPROBACIÓN
--   select codigo, ref_panel, fase, nivel, activo from public.tipos_tramite
--    where codigo in ('marca', 'marca_en_proceso');                        -- dos filas
--   select codigo from public.tipos_documento
--    where codigo in ('planilla_solicitud_marca', 'identidad_titular_marca'); -- dos filas

-- ====================================================================
--  78 / 105   supabase-recaudos-revisados.sql
-- ====================================================================

-- «Recaudos revisados» como botón aparte del gestor (Franklin Reyes, 5-10-2026: «Presentar» se parte
-- en dos). Apunta la fecha en datos.pasos_ciip.recaudos_revisados de una solicitud en revisión, y la
-- borra al devolverla: lo corregido se vuelve a revisar.
-- Usa es_gestor() (supabase-tramites.sql). Se puede correr más de una vez.

create or replace function public.marca_recaudos_revisados(p_tramite uuid)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP da los recaudos por revisados';
  end if;

  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object('recaudos_revisados', to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF')))
   where id = p_tramite
     and estado = 'en_revision'
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar la revisión';
  end if;

  return fila;
end $$;

revoke all on function public.marca_recaudos_revisados(uuid) from public;
revoke execute on function public.marca_recaudos_revisados(uuid) from anon;
grant execute on function public.marca_recaudos_revisados(uuid) to authenticated;

create or replace function public.devuelta_sin_revisados()
returns trigger
language plpgsql
as $$
begin
  if new.estado = 'devuelto' and old.estado is distinct from 'devuelto'
     and coalesce((new.datos -> 'pasos_ciip') ? 'recaudos_revisados', false) then
    new.datos = jsonb_set(new.datos, '{pasos_ciip}', (new.datos -> 'pasos_ciip') - 'recaudos_revisados');
  end if;
  return new;
end $$;

drop trigger if exists tramites_devuelta_sin_revisados on public.tramites;
create trigger tramites_devuelta_sin_revisados
  before update on public.tramites
  for each row execute function public.devuelta_sin_revisados();

-- ====================================================================
--  79 / 105   supabase-ya-solicitado.sql
-- ====================================================================

-- «Ya lo solicité» (Franklin Reyes, 5-10-2026, Ventanilla única 2.6): inscripciones (c44), licencia (c45),
-- conformidad de uso (c46) y bomberos (c47). Sus recaudos son tipos que ya existen. Con el nivel y la fase
-- de su casilla madre. Necesita supabase-informe-victor.sql. Se puede correr más de una vez.

insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('parafiscales_en_proceso', 'c44', 'Inscripciones: empresa ya inscrita',                 'Entes varios', 3, true),
  ('licencia_en_proceso',     'c45', 'Licencia de actividades económicas: ya solicitada',  'Alcaldía',     3, true),
  ('conformidad_en_proceso',  'c46', 'Conformidad de uso: ya solicitada',                  'Alcaldía',     3, true),
  ('bomberos_en_proceso',     'c47', 'Permiso de bomberos: ya solicitado',                 'Bomberos',     3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite t
   set emite      = null,
       plazo_dias = null,
       nivel      = coalesce(m.nivel, 'actividad'),
       fase       = coalesce(m.fase, 3),
       activo     = true
  from (values ('parafiscales_en_proceso', 'registros_parafiscales'),
               ('licencia_en_proceso',     'licencia_municipal'),
               ('conformidad_en_proceso',  'conformidad_uso'),
               ('bomberos_en_proceso',     'permiso_bomberos')) as p(nuevo, madre)
  left join public.tipos_tramite m on m.codigo = p.madre
 where t.codigo = p.nuevo;

select codigo, ref_panel, fase, nivel, activo from public.tipos_tramite
 where codigo in ('parafiscales_en_proceso', 'licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso')
 order by ref_panel;

-- ====================================================================
--  80 / 105   supabase-bienes-comprador.sql
-- ====================================================================

-- CIIP · Ventanilla Única — los recaudos del comprador en la compraventa (c41)
-- Franklin Reyes, 5-10-2026. Se puede correr más de una vez.

insert into public.tipos_documento (codigo, nombre, vence) values
  ('acta_comprador',          'Acta constitutiva del comprador',                    false),
  ('rif_comprador',           'RIF del comprador',                                  false),
  ('identidad_rep_comprador', 'Cédula y RIF del representante legal del comprador', false),
  ('asamblea_comprador',      'Última acta de asamblea del comprador',              false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- COMPROBACIÓN
--   select codigo, nombre, vence from public.tipos_documento
--    where codigo in ('acta_comprador', 'rif_comprador',
--                     'identidad_rep_comprador', 'asamblea_comprador');   -- cuatro filas

-- ====================================================================
--  81 / 105   supabase-bienes-registro.sql
-- ====================================================================

-- CIIP · Ventanilla Única — la compraventa (c41) en dos fases: contrato y registro (Franklin Reyes, 5-10-2026).
-- Va DESPUÉS de supabase-importe-del-dia.sql, supabase-marca.sql, supabase-libros.sql y supabase-bienes.sql.
-- Se puede correr más de una vez.

do $comprueba$
begin
  if to_regprocedure('public.pasos_del_ciip_se_quedan()') is null then
    raise exception 'Falta supabase-marca.sql: va antes que éste';
  end if;
  if not exists (select 1 from information_schema.columns
                  where table_name = 'importe_del_dia_pasos' and column_name = 'sin_caducidad') then
    raise exception 'Falta supabase-libros.sql: va antes que éste';
  end if;
end
$comprueba$;

delete from public.textos_panel
 where clave like '\_p.pasos.c41.%'
    or clave like '\_p.circuito.c41.%';

insert into public.tipos_documento (codigo, nombre, vence) values
  ('contrato_compraventa', 'Contrato de compraventa', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- El contrato lo manda el equipo, ya validado, colgado de la compraventa.
drop policy if exists "documentos: el equipo manda el contrato de compraventa" on public.documentos;
create policy "documentos: el equipo manda el contrato de compraventa" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'contrato_compraventa' and estado = 'validado');

drop policy if exists "adjuntos: el equipo cuelga el contrato de compraventa" on public.tramite_documentos;
create policy "adjuntos: el equipo cuelga el contrato de compraventa" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and t.tipo = 'bienes_compraventa'
         and d.tipo = 'contrato_compraventa'
    )
  );

create or replace function public.compraventa_contrato_del_ciip()
returns trigger
language plpgsql
as $cv$
begin
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.tipo = 'contrato_compraventa'
     or (tg_op = 'UPDATE' and old.tipo = 'contrato_compraventa') then
    raise exception 'Ese papel lo emite el CIIP'
      using errcode = 'check_violation';
  end if;
  return new;
end
$cv$;

drop trigger if exists documentos_compraventa_del_ciip on public.documentos;
create trigger documentos_compraventa_del_ciip
  before insert or update on public.documentos
  for each row execute function public.compraventa_contrato_del_ciip();

-- Los dos importes, con la solicitud ante el ente. El PUB no caduca; el timbre fiscal sí.
alter table public.importe_del_dia_pasos
  add column if not exists pasos_sin_caducidad text[] not null default '{}';

insert into public.importe_del_dia_pasos (tipo_tramite, estados, sin_caducidad, pasos_sin_caducidad)
values ('bienes_compraventa', array['ante_el_ente'], false, array['pub'])
on conflict (tipo_tramite) do update
  set estados = excluded.estados,
      sin_caducidad = excluded.sin_caducidad,
      pasos_sin_caducidad = excluded.pasos_sin_caducidad;

create or replace function public.importe_del_dia_vigente(p_tramite uuid, p_paso text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
      join public.tramites t   on t.id = td.tramite
     where td.tramite = p_tramite
       and d.tipo = 'importe_dia'
       and d.estado = 'validado'
       and d.inversionista = t.inversionista
       and d.paso_importe is not distinct from p_paso
       and ((d.creado_en at time zone 'America/Caracas')::date = public.hoy_en_caracas()
            or exists (select 1 from public.importe_del_dia_pasos p
                        where p.tipo_tramite = t.tipo
                          and (p.sin_caducidad or d.paso_importe = any(p.pasos_sin_caducidad))))
  )
$$;

-- Al colgarse el contrato, un importe o un comprobante, la base apunta su paso.
create or replace function public.compraventa_apunta_el_papel()
returns trigger
language plpgsql
security definer
set search_path = public
as $cv$
declare
  papel public.documentos;
  suTipo text;
  clave text;
begin
  select * into papel from public.documentos where id = new.documento;
  select tipo into suTipo from public.tramites where id = new.tramite;
  if suTipo is distinct from 'bienes_compraventa' or papel.id is null then
    return new;
  end if;
  clave := case
    when papel.tipo = 'importe_dia'      and papel.paso_importe is not null then 'importe_' || papel.paso_importe
    when papel.tipo = 'pago_importe_dia' and papel.paso_importe is not null
         and papel.estado <> 'rechazado'                                  then 'pago_' || papel.paso_importe
    when papel.tipo = 'contrato_compraventa'                              then 'contrato'
  end;
  if clave is null then
    return new;
  end if;
  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(clave, public.marca_ahora()))
   where id = new.tramite
     and not coalesce((datos -> 'pasos_ciip') ? clave, false);
  return new;
end
$cv$;

drop trigger if exists tramite_documentos_compraventa_apunta on public.tramite_documentos;
create trigger tramite_documentos_compraventa_apunta
  after insert on public.tramite_documentos
  for each row execute function public.compraventa_apunta_el_papel();

create or replace function public.compraventa_borra_el_pago_rechazado()
returns trigger
language plpgsql
security definer
set search_path = public
as $cv$
begin
  if new.tipo <> 'pago_importe_dia' or new.paso_importe is null
     or new.estado <> 'rechazado' or old.estado = 'rechazado' then
    return new;
  end if;
  update public.tramites t
     set datos = jsonb_set(t.datos, '{pasos_ciip}',
                           (t.datos -> 'pasos_ciip') - ('pago_' || new.paso_importe))
   where t.tipo = 'bienes_compraventa'
     and (t.datos -> 'pasos_ciip') ? ('pago_' || new.paso_importe)
     and t.id in (select td.tramite from public.tramite_documentos td where td.documento = new.id);
  return new;
end
$cv$;

drop trigger if exists documentos_compraventa_pago_rechazado on public.documentos;
create trigger documentos_compraventa_pago_rechazado
  after update of estado on public.documentos
  for each row execute function public.compraventa_borra_el_pago_rechazado();

-- Los tres pasos que marca el gestor, cada uno detrás del anterior.
create or replace function public.compraventa_paso_ciip(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $cv$
declare
  fila public.tramites;
begin
  if not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP marca estos pasos';
  end if;
  if p_clave not in ('redaccion', 'introduccion', 'registrador') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(p_clave, public.marca_ahora()))
   where id = p_tramite
     and tipo = 'bienes_compraventa'
     and estado = 'ante_el_ente'
     and not coalesce((datos -> 'pasos_ciip') ? p_clave, false)
     and (
          p_clave = 'redaccion'
       or (p_clave = 'introduccion' and coalesce((datos -> 'pasos_ciip') ? 'contrato', false))
       or (p_clave = 'registrador'  and coalesce((datos -> 'pasos_ciip') ? 'introduccion', false))
     )
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;
  return fila;
end
$cv$;

-- La fecha de la firma, con el timbre pagado. Se puede cambiar hasta resolver.
create or replace function public.compraventa_fecha_firma(p_tramite uuid, p_dia date)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $cv$
declare
  fila public.tramites;
begin
  if not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP pone la fecha de la firma';
  end if;
  if p_dia is null then
    raise exception 'Falta la fecha de la firma';
  end if;

  update public.tramites
     set datos = jsonb_set(coalesce(datos, '{}'::jsonb), '{pasos_ciip}',
                           coalesce(datos -> 'pasos_ciip', '{}'::jsonb)
                           || jsonb_build_object(
                                'firma', coalesce(datos -> 'pasos_ciip' ->> 'firma', public.marca_ahora()),
                                'firma_dia', to_char(p_dia, 'YYYY-MM-DD')))
   where id = p_tramite
     and tipo = 'bienes_compraventa'
     and estado = 'ante_el_ente'
     and coalesce((datos -> 'pasos_ciip') ? 'pago_timbre', false)
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo poner la fecha de la firma';
  end if;
  return fila;
end
$cv$;

-- Un aviso del CIIP en mitad del registro: lo que observe o pida el Registrador. Destacado en el trámite,
-- en la conversación y por correo, como la contestación de la marca. Se puede mandar más de uno.
create or replace function public.anuncio_del_ciip(p_tramite uuid, p_anuncio text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $cv$
declare
  fila   public.tramites;
  texto  text := btrim(coalesce(p_anuncio, ''));
  correo text;
  suPais text;
begin
  if not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP manda avisos';
  end if;
  if texto = '' or char_length(texto) > 2000 then
    raise exception 'El aviso tiene que decir algo, y en menos de 2000 caracteres';
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object('anuncio', texto, 'anuncio_en', public.marca_ahora())
   where id = p_tramite
     and tipo = 'bienes_compraventa'
     and estado = 'ante_el_ente'
     and coalesce((datos -> 'pasos_ciip') ? 'introduccion', false)
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo mandar el aviso';
  end if;

  insert into public.tramite_mensajes (tramite, texto) values (p_tramite, texto);

  select u.email into correo from auth.users u where u.id = fila.inversionista;
  select p.pais  into suPais from public.perfiles p where p.id = fila.inversionista;
  if correo is not null and correo <> '' then
    insert into public.avisos (tramite, destinatario, pais, motivo, nota)
    values (p_tramite, correo, coalesce(suPais, ''), 'anuncio', texto);
  end if;

  return fila;
end
$cv$;

revoke all on function public.compraventa_paso_ciip(uuid, text) from public;
revoke execute on function public.compraventa_paso_ciip(uuid, text) from anon;
grant execute on function public.compraventa_paso_ciip(uuid, text) to authenticated;
revoke all on function public.compraventa_fecha_firma(uuid, date) from public;
revoke execute on function public.compraventa_fecha_firma(uuid, date) from anon;
grant execute on function public.compraventa_fecha_firma(uuid, date) to authenticated;
revoke all on function public.anuncio_del_ciip(uuid, text) from public;
revoke execute on function public.anuncio_del_ciip(uuid, text) from anon;
grant execute on function public.anuncio_del_ciip(uuid, text) to authenticated;

-- «Documento protocolizado» va detrás de la fecha de la firma: sin ella no se resuelve.
create or replace function public.tramites_compraventa_con_firma()
returns trigger
language plpgsql
security definer
set search_path = public
as $cv$
begin
  if new.estado is not distinct from old.estado
     or new.estado <> 'resuelto' or new.tipo <> 'bienes_compraventa'
     or auth.uid() is null then
    return new;
  end if;
  if not coalesce((new.datos -> 'pasos_ciip') ? 'firma_dia', false) then
    raise exception 'La compraventa no se resuelve sin la fecha de la firma'
      using errcode = 'check_violation';
  end if;
  return new;
end
$cv$;

drop trigger if exists tramites_compraventa_firma on public.tramites;
create trigger tramites_compraventa_firma
  before update on public.tramites
  for each row execute function public.tramites_compraventa_con_firma();

-- COMPROBACIÓN
--   select tipo_tramite, sin_caducidad, pasos_sin_caducidad from public.importe_del_dia_pasos
--    where tipo_tramite = 'bienes_compraventa';                             -- {pub}
--   select proname from pg_proc
--    where proname in ('compraventa_paso_ciip', 'compraventa_fecha_firma', 'anuncio_del_ciip');  -- tres filas
--   select tgname from pg_trigger
--    where tgname in ('tramite_documentos_compraventa_apunta', 'documentos_compraventa_pago_rechazado',
--                     'tramites_compraventa_firma', 'documentos_compraventa_del_ciip');           -- cuatro filas

-- ====================================================================
--  82 / 105   supabase-sacs.sql
-- ====================================================================

-- El SACS, Servicio Autónomo de Contraloría Sanitaria (Franklin Reyes, 7-10-2026, Ventanilla única 2.7).
-- Un trámite nuevo en la etapa 3 con su pregunta previa: «Solicitar un permiso por primera vez» (c48,
-- permiso_sacs, el de la portada) o «Ya solicité un permiso» (c49, sacs_en_proceso, escondido con
-- data-tramo-de). Sustituye al permiso sanitario del establecimiento (c12), que se apaga: deja de
-- ofrecerse en la portada y en el catálogo, pero su fila y sus solicitudes viejas se quedan.
-- Sus recaudos son tipos que ya existen (acta, RIF de la empresa, cédula y RIF del representante).
-- Necesita supabase-informe-victor.sql (nivel), supabase-encadenado.sql (emite), supabase-plazos.sql,
-- supabase-locti-opcion2.sql (la última confirma_paso) y supabase-control-estadisticas.sql.
-- Se puede correr más de una vez.

-- 1. Los dos trámites, encendidos, en la fase 3 y con el ente del catálogo del c12, 'SACS'.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('permiso_sacs',    'c48', 'Servicio Autónomo de Contraloría Sanitaria',        'SACS', 3, true),
  ('sacs_en_proceso', 'c49', 'SACS: permiso ya solicitado',                       'SACS', 3, true)
on conflict (codigo) do nothing;

-- El de primera vez, con el nivel, lo que emite y el plazo del permiso sanitario (c12), al que
-- sustituye y que es el mismo permiso ante el mismo ente; si el c12 no estuviera, los de la
-- licencia (c10), que es su pareja en «por primera vez». El ya solicitado, como c45 a c47: sin
-- emite ni plazo, con el nivel de su casilla madre.
update public.tipos_tramite t
   set nivel      = coalesce(s.nivel, l.nivel, 'actividad'),
       emite      = case when s.codigo is not null then s.emite else l.emite end,
       plazo_dias = coalesce(s.plazo_dias, l.plazo_dias),
       fase       = 3,
       activo     = true
  from (select 1) as uno
  left join public.tipos_tramite s on s.codigo = 'permiso_sanitario'
  left join public.tipos_tramite l on l.codigo = 'licencia_municipal'
 where t.codigo = 'permiso_sacs';

update public.tipos_tramite t
   set emite      = null,
       plazo_dias = null,
       nivel      = coalesce(m.nivel, 'actividad'),
       fase       = 3,
       activo     = true
  from (select 1) as uno
  left join public.tipos_tramite m on m.codigo = 'permiso_sacs'
 where t.codigo = 'sacs_en_proceso';

-- 2. El permiso sanitario (c12) se apaga: el SACS nuevo ocupa su sitio. No se borra, que puede
-- haber solicitudes que apunten a él.
update public.tipos_tramite set activo = false where codigo = 'permiso_sanitario';

-- 3. La marca del paso 1 del c48, «Ya me registré» en el sistema del SACS: 'sacs_registrado'. Es la
-- confirma_paso de supabase-locti-opcion2.sql con esa llave más.
create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                     'bomberos_solicitado', 'saime_confirmada', 'locti_inscrito',
                     'sacs_registrado') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;

-- 4. Las cifras de Control y Estadísticas: los motivos de «ya lo solicité» cuentan también el SACS
-- ya solicitado (c49). Es estadisticas_control() de supabase-control-estadisticas.sql, entera.
create or replace function public.estadisticas_control()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r jsonb;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve las estadísticas' using errcode = '42501';
  end if;

  with enviados as (
    select t.id, t.tipo, coalesce(tt.ente, '') as ente, t.estado,
           t.datos,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
  resueltos as (
    select e.tipo, e.ente,
           extract(epoch from (e.resuelto_en - e.desde)) / 3600.0 as horas,
           (select extract(epoch from (e.resuelto_en - min(ev.creado_en))) / 3600.0
              from public.tramite_eventos ev
             where ev.tramite = e.id and ev.a_estado = 'ante_el_ente'
            having min(ev.creado_en) <= e.resuelto_en) as horas_ente
      from enviados e
     where e.estado = 'resuelto'
       and e.resuelto_en is not null
       and e.resuelto_en >= e.desde
  ),
  por_tipo as (
    select tipo, max(ente) as ente, count(*) as solicitados
      from enviados
     group by tipo
  ),
  tiempo_tipo as (
    select tipo,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente
      from resueltos
     group by tipo
  ),
  tiempo_ente as (
    select ente,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente
      from resueltos
     group by ente
  ),
  por_sector as (
    select sector, count(*) as n
      from public.consultas
     where sector is not null
     group by sector
  ),
  -- Los motivos de «ya lo solicité» (6-10-2026): por qué pide ayuda el inversionista, ente por
  -- ente. En c45 a c47 hay un solo ente, el del catálogo, y un motivo_ya; en c44, uno por cada
  -- ente marcado, motivo_ya_<ente>. Se guardan en español (opcionesClave), así que se agrupan
  -- igual los haya escrito quien sea en el idioma que sea.
  -- Y el SACS ya solicitado (c49, Franklin Reyes, 7-10-2026, Ventanilla única 2.7), con su ente
  -- del catálogo, 'SACS', y su motivo_ya, como c45 a c47.
  motivos as (
    select m.motivo, m.ente, count(*) as n
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso')
        union all
        select e.datos ->> ('motivo_ya_' || x.clave), x.ente
          from enviados e
         cross join (values ('banavih', 'BANAVIH (FAOV)'), ('inces', 'INCES'),
                            ('rupdae', 'RUPDAE'), ('ivss', 'IVSS'),
                            ('rnet', 'RNET'), ('rnc', 'RNC')) as x(clave, ente)
         where e.tipo = 'parafiscales_en_proceso'
      ) m
     where coalesce(m.motivo, '') <> ''
     group by m.motivo, m.ente
  )
  select jsonb_build_object(
    'tramites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', p.tipo, 'ente', p.ente, 'solicitados', p.solicitados,
               'resueltos', coalesce(x.n, 0),
               'mediana_h', round(x.mediana::numeric, 1),
               'promedio_h', round(x.promedio::numeric, 1),
               'n_ente', coalesce(x.n_ente, 0),
               'mediana_ente_h', round(x.mediana_ente::numeric, 1))
             order by p.solicitados desc, p.tipo)
        from por_tipo p
        left join tiempo_tipo x on x.tipo = p.tipo), '[]'::jsonb),
    'entes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ente', y.ente, 'resueltos', y.n,
               'mediana_h', round(y.mediana::numeric, 1),
               'promedio_h', round(y.promedio::numeric, 1),
               'n_ente', y.n_ente,
               'mediana_ente_h', round(y.mediana_ente::numeric, 1))
             order by y.n desc, y.ente)
        from tiempo_ente y), '[]'::jsonb),
    'sectores', coalesce((
      select jsonb_agg(jsonb_build_object('sector', s.sector, 'consultas', s.n)
             order by s.n desc, s.sector)
        from por_sector s), '[]'::jsonb),
    'motivos', coalesce((
      select jsonb_agg(jsonb_build_object('motivo', mo.motivo, 'ente', mo.ente, 'n', mo.n)
             order by mo.n desc, mo.motivo, mo.ente)
        from motivos mo), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;

-- Comprobación: tres filas (c12 apagado, c48 y c49 encendidos) y true si confirma_paso ya acepta
-- la marca del SACS.
select ref_panel, codigo, ente, fase, nivel, plazo_dias, activo from public.tipos_tramite
 where codigo in ('permiso_sanitario', 'permiso_sacs', 'sacs_en_proceso')
 order by ref_panel;
select position('sacs_registrado' in pg_get_functiondef('public.confirma_paso(uuid, text)'::regprocedure)) > 0
       as acepta_sacs_registrado;

-- ====================================================================
--  83 / 105   supabase-libros-saren.sql
-- ====================================================================

-- El ente del sellado de libros y dos nombres del catálogo (Franklin Reyes, 7-10-2026).
--
-- 1. El sellado de libros (c24) se presenta ante el SAREN, no ante el SENIAT. Lo dicen sus
--    pasos desde el 29-9-2026 («Solicitud introducida ante el SAREN», «Emisión de PUB por
--    SAREN») y la especificación («Pendientes FRANK.pdf», p. 13), pero el catálogo seguía con
--    el 'SENIAT' de supabase-tramites.sql, y el ente del catálogo es el que lee el gestor en
--    su botón: «Presentada ante SENIAT» para una solicitud que el CIIP lleva al SAREN.
--
-- 2. Los nombres de la cédula (c2) y de la traducción (c17), como los dice la especificación
--    y ya los enseña la tarjeta: «Cédula de identidad de extranjero» («Ventanilla unica
--    2.4.pdf», p. 1) y «Traducción de documentos» («Pendientes FRANK.pdf», p. 7; el CIIP ya
--    no apostilla desde el 28-9-2026). La tarjeta y la ficha leen el nombre del diccionario
--    (i18n.js); el del catálogo es el que sale en la pantalla del catálogo del administrador,
--    y no debe decir otra cosa. El ente del c17 no se toca: es una duda del cliente.
--
-- Solo necesita supabase-tramites.sql. Se puede correr más de una vez.

update public.tipos_tramite set ente = 'SAREN'
 where codigo = 'libros_contables' and ente is distinct from 'SAREN';

update public.tipos_tramite set nombre = 'Cédula de identidad de extranjero'
 where codigo = 'cedula_residencia' and nombre is distinct from 'Cédula de identidad de extranjero';

update public.tipos_tramite set nombre = 'Traducción de documentos'
 where codigo = 'apostilla_documentos' and nombre is distinct from 'Traducción de documentos';

-- Comprobar:
--   select codigo, ref_panel, nombre, ente from public.tipos_tramite
--    where codigo in ('libros_contables', 'cedula_residencia', 'apostilla_documentos');
--   -- c24 SAREN; c2 «Cédula de identidad de extranjero»; c17 «Traducción de documentos»

-- ====================================================================
--  84 / 105   supabase-modelos.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS MODELOS DE «AUTORIZACIONES Y NDA»
--  Va DESPUÉS de supabase-admin.sql (es_admin()). Va al final para no
--  mover el número de nadie.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 8 de octubre de 2026: una categoría «Autorizaciones y
--  NDA» donde el inversionista descarga los modelos del CIIP, y donde el
--  administrador los sube sin tocar el código.
--
--  CÓMO QUEDA
--  ───────────────────────────────────────────────────────────────────────
--  · Un cubo 'modelos' con dos archivos de nombre fijo:
--      nda-ciip.pdf            el NDA con el CIIP
--      autorizacion-ciip.pdf   la autorización al CIIP
--    Subir otro es reemplazar el que había: no hay historial que guardar,
--    el modelo vigente es uno.
--  · PRIVADO: lo lee quien tiene sesión, y el panel lo baja con una URL
--    firmada. No es un secreto, pero tampoco es para cualquiera que pase.
--  · Escribir, reemplazar y borrar, solo el admin.
--  · Solo PDF, hasta 10 MB: lo que se descarga tiene que abrirse igual en
--    cualquier equipo.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: el inversionista ve «El CIIP
--  todavía no ha publicado este modelo» y al administrador la subida le
--  dice que no se pudo.
-- ═══════════════════════════════════════════════════════════════════════


insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('modelos', 'modelos', false, 10485760, array['application/pdf'])
on conflict (id) do update set
  public             = excluded.public,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "modelos: se leen con sesion" on storage.objects;
create policy "modelos: se leen con sesion" on storage.objects
  for select to authenticated
  using (bucket_id = 'modelos');

drop policy if exists "modelos: el admin sube" on storage.objects;
create policy "modelos: el admin sube" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'modelos' and public.es_admin());

drop policy if exists "modelos: el admin reemplaza" on storage.objects;
create policy "modelos: el admin reemplaza" on storage.objects
  for update to authenticated
  using      (bucket_id = 'modelos' and public.es_admin())
  with check (bucket_id = 'modelos' and public.es_admin());

drop policy if exists "modelos: el admin borra" on storage.objects;
create policy "modelos: el admin borra" on storage.objects
  for delete to authenticated
  using (bucket_id = 'modelos' and public.es_admin());

-- ====================================================================
--  85 / 105   supabase-seguridad-octubre.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  AUDITORÍA DE SEGURIDAD, SEGUNDA PASADA (8-10-2026)
-- ═══════════════════════════════════════════════════════════════════════
--  Lo que salió al revisar lo que entró desde la primera (25-9-2026) y
--  que se arregla en la base. Va el último de juntar-sql.js porque toca
--  tablas y funciones de muchos archivos anteriores. Se puede correr las
--  veces que haga falta.
--
--  1 · Las contraseñas del IVSS y del INCES dejan de leerse en bloque.
--  2 · Dos papeles más que solo emite el CIIP.
--  3 · Dos funciones del equipo, cerradas también a anon.
--
--  Fuera de aquí, en sus archivos de siempre: es_gestor() y es_admin()
--  ya no se pisan al volver a correr supabase-tramites.sql o
--  supabase-admin.sql, las políticas del cubo de supabase-papeles-
--  sellados.sql llevan el bloqueo, gasta_uso_ia() es la misma en sus tres
--  archivos (traductor: 60 por hora) y el candado de la traducción no
--  acepta un comprobante rechazado.
-- ═══════════════════════════════════════════════════════════════════════


-- ── 1 · LAS CONTRASEÑAS DE LOS ENTES ──────────────────────────────────
-- tramite_entes.clave guarda en claro la contraseña que el inversionista
-- crea en el portal del IVSS o del INCES, para que el CIIP entre por él.
-- La política de lectura es la de la tabla entera: cualquiera del equipo
-- podía bajarse todas las contraseñas pendientes de una vez
-- (tramite_entes?select=clave&clave=not.is.null), o quien le robara la
-- sesión a uno.
--
-- Ahora la columna no la lee nadie con sesión (ni el propio inversionista,
-- que la escribió y no la necesita de vuelta). El equipo la pide de una en
-- una con clave_del_ente(), y cada vez queda en la bitácora quién la vio.
-- La cola compartida de «Códigos enviados» sigue igual: cualquiera del
-- equipo despacha cualquier expediente, solo que ahora deja rastro.
--
-- tiene_clave dice si hay contraseña sin enseñarla: es lo que la pantalla
-- necesita para poner el botón de verla.

alter table public.tramite_entes
  add column if not exists tiene_clave boolean
  generated always as (clave is not null) stored;

-- Permiso de lectura por columnas: todas menos la contraseña. OJO: una
-- columna que se añada a tramite_entes en el futuro NO tendrá permiso de
-- lectura hasta que se vuelva a correr este archivo.
do $cols$
declare
  c record;
begin
  revoke select on public.tramite_entes from authenticated;
  for c in select column_name from information_schema.columns
            where table_schema = 'public' and table_name = 'tramite_entes'
              and column_name <> 'clave'
  loop
    execute format('grant select (%I) on public.tramite_entes to authenticated', c.column_name);
  end loop;
end
$cols$;

-- La bitácora acepta la fuente nueva.
alter table public.bitacora drop constraint if exists bitacora_fuente_valida;
alter table public.bitacora add constraint bitacora_fuente_valida
  check (fuente in ('catalogo','roles','papeles','citas',
                    'textos','activos','acompanamiento','entes'));

create or replace function public.clave_del_ente(p_tramite uuid, p_ente text)
returns text
language plpgsql
security definer
set search_path = public
as $clave$
declare
  la_clave text;
  de_quien text;
begin
  if auth.uid() is null or not public.es_gestor() then
    raise exception 'Solo el equipo del CIIP ve estas contraseñas'
      using errcode = 'insufficient_privilege';
  end if;

  select e.clave, coalesce(p.nombre_completo, '')
    into la_clave, de_quien
    from public.tramite_entes e
    join public.tramites t on t.id = e.tramite
    left join public.perfiles p on p.id = t.inversionista
   where e.tramite = p_tramite and e.ente = p_ente;

  -- Solo se apunta si había algo que ver.
  if la_clave is not null then
    perform public.apunta('entes', 'vio_clave', de_quien, p_ente);
  end if;
  return la_clave;
end
$clave$;

revoke all on function public.clave_del_ente(uuid, text) from public;
revoke execute on function public.clave_del_ente(uuid, text) from anon;
grant execute on function public.clave_del_ente(uuid, text) to authenticated;


-- ── 2 · PAPELES QUE SOLO EMITE EL CIIP ────────────────────────────────
-- La planilla de los RIF y la constancia de cada ente las sube el equipo
-- (supabase-planilla-rif.sql, supabase-entes-parafiscales.sql), pero nada
-- impedía que un inversionista subiera un papel suyo con ese tipo. Entraba
-- como cargado, sin validar, pero el panel lo encuentra por tipo y lo
-- enseñaba como si lo hubiera mandado el CIIP. Mismo cierre que la planilla
-- del IVSS (supabase-planilla-ivss.sql).
create or replace function public.papeles_que_emite_el_ciip()
returns trigger
language plpgsql
security definer
set search_path = public
as $emite$
begin
  if auth.uid() is null or public.es_gestor() then
    return new;
  end if;
  if new.tipo in ('planilla_solicitud', 'constancia_ente')
     or (tg_op = 'UPDATE' and old.tipo in ('planilla_solicitud', 'constancia_ente')) then
    raise exception 'Ese papel lo emite el CIIP' using errcode = 'check_violation';
  end if;
  return new;
end
$emite$;

drop trigger if exists documentos_papeles_que_emite_el_ciip on public.documentos;
create trigger documentos_papeles_que_emite_el_ciip
  before insert or update on public.documentos
  for each row execute function public.papeles_que_emite_el_ciip();


-- ── 3 · ANON ──────────────────────────────────────────────────────────
-- En Supabase una función nueva nace ejecutable por anon, y «revoke … from
-- public» no lo quita. Las dos se negaban por dentro a quien no es del
-- equipo, así que no se podía sacar nada; esto es para que ni lleguen.
revoke execute on function public.confirma_cita(uuid, timestamptz, text, text) from anon;
revoke execute on function public.abre_consulta_para(uuid, text, text) from anon;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--   select has_column_privilege('authenticated', 'public.tramite_entes', 'clave', 'select');        -- false
--   select has_column_privilege('authenticated', 'public.tramite_entes', 'tiene_clave', 'select');  -- true
--   select has_function_privilege('anon', 'public.clave_del_ente(uuid,text)', 'execute');           -- false
--   select has_function_privilege('anon', 'public.confirma_cita(uuid,timestamptz,text,text)', 'execute'); -- false
--   select has_function_privilege('anon', 'public.abre_consulta_para(uuid,text,text)', 'execute');  -- false
--   select tgname from pg_trigger where tgname = 'documentos_papeles_que_emite_el_ciip';           -- una fila

-- ====================================================================
--  86 / 105   supabase-autorizaciones.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA AUTORIZACIÓN AL CIIP, TRÁMITE A TRÁMITE
--  Va DESPUÉS de supabase-tramites.sql (tramites, tipos_tramite,
--  es_gestor()). Va al final para no mover el número de nadie.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 8 de octubre de 2026: al solicitar un trámite, el
--  inversionista contesta «¿Autorizas al CIIP a gestionar este trámite en
--  tu nombre?». Si dice que sí, acepta en línea -sin firma- una
--  autorización con sus datos, y el CIIP puede presentar, consignar y
--  retirar documentos. Si dice que no, gestiona él y el CIIP solo verifica.
--  No se pregunta en la constitución (con sus tramos), en el sellado de
--  libros ni en la acreditación de representación legal, que es ante el
--  propio CIIP. El texto está en revisión con el abogado.
--
--  CÓMO QUEDA
--  ───────────────────────────────────────────────────────────────────────
--  · Lo que eligió vive en tramites.datos.gestion ('ciip' | 'directa'):
--    no hace falta columna, y la cola del equipo ya lee datos.
--  · Cada «sí» deja una fila en autorizaciones: la CONSTANCIA. Lleva el
--    texto exacto que se aceptó, para que un cambio posterior del modelo
--    no reescriba lo que alguien aceptó, y un código AUT-AAAA-NNNNNN que
--    pone la base.
--  · Append-only, como pliego_aceptaciones: no se edita ni se borra. Solo
--    se revoca, con revoca_autorizacion(), que pone la fecha y nada más.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: la pregunta sale igual y la
--  solicitud se envía; lo que no queda es la constancia.
-- ═══════════════════════════════════════════════════════════════════════


create sequence if not exists public.autorizaciones_numero;

create table if not exists public.autorizaciones (
  id           uuid primary key default gen_random_uuid(),
  codigo       text unique,
  inversionista uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tramite      uuid not null references public.tramites(id) on delete cascade,
  tipo         text not null references public.tipos_tramite(codigo),
  texto        text not null,
  datos        jsonb not null default '{}'::jsonb,
  aceptada_en  timestamptz not null default now(),
  revocada_en  timestamptz,
  -- Una por trámite: reenviar una devuelta no vuelve a pedir el sí.
  constraint autorizaciones_una_por_tramite unique (tramite)
);

comment on table public.autorizaciones is
  'Constancia de que el inversionista autorizo al CIIP en un tramite. Solo se inserta; se revoca con revoca_autorizacion()';

create index if not exists autorizaciones_por_inversionista
  on public.autorizaciones (inversionista, aceptada_en desc);


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA CONSTANCIA LA PONE LA BASE
-- ───────────────────────────────────────────────────────────────────────
-- Quién, cuándo y el código: se ignora lo que venga. Y el trámite tiene
-- que ser suyo, que la política de insert solo mira la columna.
create or replace function public.autorizacion_la_pone_la_base()
returns trigger
language plpgsql
security definer
set search_path = public
as $aut$
begin
  if auth.uid() is not null then
    new.inversionista := auth.uid();
    new.aceptada_en   := now();
    new.revocada_en   := null;
    if not exists (select 1 from public.tramites t
                    where t.id = new.tramite and t.inversionista = auth.uid()) then
      raise exception 'Ese trámite no es tuyo.' using errcode = 'check_violation';
    end if;
  end if;
  new.codigo := 'AUT-' || to_char(new.aceptada_en at time zone 'America/Caracas', 'YYYY') || '-' ||
                lpad(nextval('public.autorizaciones_numero')::text, 6, '0');
  return new;
end
$aut$;

drop trigger if exists autorizacion_constancia on public.autorizaciones;
create trigger autorizacion_constancia
  before insert on public.autorizaciones
  for each row execute function public.autorizacion_la_pone_la_base();

-- Desde el 15-10-2026 la redefine supabase-borrado-admin.sql: la misma, con
-- la puerta del borrado del administrador (solo para borrar).
create or replace function public.autorizacion_no_se_toca()
returns trigger
language plpgsql
as $aut$
begin
  -- La puerta de servicio (SQL Editor) y la revocación, que solo pone
  -- la fecha a una que no la tenía.
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  if tg_op = 'UPDATE'
     and old.revocada_en is null and new.revocada_en is not null
     and (to_jsonb(new) - 'revocada_en') = (to_jsonb(old) - 'revocada_en') then
    return new;
  end if;
  raise exception 'Una autorización aceptada no se cambia ni se borra: se revoca.'
    using errcode = 'check_violation';
end
$aut$;

drop trigger if exists autorizacion_inmutable on public.autorizaciones;
create trigger autorizacion_inmutable
  before update or delete on public.autorizaciones
  for each row execute function public.autorizacion_no_se_toca();


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN LA VE Y QUIÉN LA ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
alter table public.autorizaciones enable row level security;

drop policy if exists "autorizaciones: las propias y el equipo" on public.autorizaciones;
create policy "autorizaciones: las propias y el equipo" on public.autorizaciones
  for select to authenticated
  using (inversionista = auth.uid() or public.es_gestor());

drop policy if exists "autorizaciones: el inversionista acepta" on public.autorizaciones;
create policy "autorizaciones: el inversionista acepta" on public.autorizaciones
  for insert to authenticated
  with check (inversionista = auth.uid());

revoke all on public.autorizaciones from anon;
grant select, insert on public.autorizaciones to authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- 3. REVOCAR
-- ───────────────────────────────────────────────────────────────────────
-- Solo la propia y solo una vez. Devuelve la fecha, o null si no había
-- nada que revocar.
create or replace function public.revoca_autorizacion(p_id uuid)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $aut$
declare
  cuando timestamptz;
begin
  update public.autorizaciones
     set revocada_en = now()
   where id = p_id
     and inversionista = auth.uid()
     and revocada_en is null
  returning revocada_en into cuando;
  return cuando;
end
$aut$;

revoke all on function public.revoca_autorizacion(uuid) from public;
revoke all on function public.revoca_autorizacion(uuid) from anon;
grant execute on function public.revoca_autorizacion(uuid) to authenticated;

-- ====================================================================
--  87 / 105   supabase-control-detalle.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — CONTROL Y ESTADÍSTICAS, CON EL DETALLE
--  Va DESPUÉS de supabase-control-estadisticas.sql (consultas.sector,
--  tramites_por_sector) y de supabase-sacs.sql, que es quien dejó escrita
--  la última estadisticas_control(). Va al final para no mover el número
--  de nadie. Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 9 de octubre de 2026, dos cosas de la misma pantalla:
--
--  1. «En control y seguimiento, en las estadísticas que se lleva por
--     sector, al lado debería de salir el tipo de trámite que más solicitan
--     por sector, o sea el trámite en específico que solicita apoyo cada
--     inversionista; en la forma en que aparece ahí pareciera que lo
--     tuvieras que escribir y seleccionar nosotros mismos.»
--
--     Hasta hoy el trámite que el inversionista pulsa en el chat de
--     sectores solo se escribía en la caja del asunto, delante de lo que
--     él añadiera y con el sector traducido delante de todo. Un texto libre
--     en ocho idiomas no se cuenta. Desde ahora va además, tal cual se
--     pulsó, en consultas.tramite_sector.
--
--     Es el NOMBRE y no el id de tramites_por_sector a propósito: esa lista
--     la cambia el administrador (renombra, quita, reordena) y una consulta
--     de hace tres meses tiene que seguir contando como lo que se pidió
--     entonces, no desaparecer porque alguien borró la fila.
--
--  2. «En ¿Por qué piden ayuda? debería de salir la respuesta completa que
--     pone el inversionista, no ..., porque si el trámite tiene alguna
--     incidencia no podremos saberlo ni tener un registro de ello.»
--
--     El motivo ya se guardaba (motivo_ya, motivo_ya_<ente>) y ya se
--     contaba. Lo que el equipo no podía leer era el CASO: quién, qué
--     solicitud, ante qué ente, cuándo, y lo que escribió al lado
--     (detalle_ya, detalle_ya_<ente>, opcional). La función lo devuelve
--     ahora en motivos_casos, del más reciente al más viejo.
--
--  POR QUÉ OTRA VEZ LA FUNCIÓN ENTERA
--  ───────────────────────────────────────────────────────────────────────
--  Las cifras de esa pantalla las cuenta la base, no el panel (lo explica
--  supabase-control-estadisticas.sql: una mediana no se rehace sumando
--  trozos, y lo que viaja son cifras y no filas). Las dos de hoy siguen la
--  misma regla, así que van dentro de estadisticas_control(), que aquí se
--  reescribe entera, como hizo supabase-sacs.sql. Lo de antes no cambia:
--  solo se añaden dos llaves, tramites_sector y motivos_casos.
--
--  Los casos llevan un tope de 500, los más recientes: la pantalla se
--  refresca cada minuto y no tiene sentido mandar el archivo entero de la
--  oficina en cada vuelta. Si algún día se pasa, se pagina aparte.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: el chat abre la consulta igual (si
--  la base rechaza la columna, el panel repite sin ella), la tarjeta de los
--  trámites por sector dice que aún no hay datos y cada motivo se despliega
--  diciendo que falta este archivo.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL TRÁMITE QUE ELIGIÓ EN EL CHAT DE SECTORES
-- ───────────────────────────────────────────────────────────────────────
alter table public.consultas
  add column if not exists tramite_sector text;

alter table public.consultas
  drop constraint if exists consultas_tramite_sector_cabe;
alter table public.consultas
  add constraint consultas_tramite_sector_cabe check (
    tramite_sector is null or length(trim(tramite_sector)) between 1 and 200);

comment on column public.consultas.tramite_sector is 'Nombre del trámite de tramites_por_sector que pulsó el inversionista en el chat de sectores, tal cual estaba al pulsarlo. Null = no eligió ninguno de la lista';

create index if not exists consultas_por_tramite_sector
  on public.consultas (sector, tramite_sector) where tramite_sector is not null;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LAS CIFRAS, CON LAS DOS LLAVES NUEVAS
-- ───────────────────────────────────────────────────────────────────────
create or replace function public.estadisticas_control()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r jsonb;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve las estadísticas' using errcode = '42501';
  end if;

  with enviados as (
    select t.id, t.tipo, coalesce(tt.ente, '') as ente, t.estado,
           t.datos, t.inversionista,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
  resueltos as (
    select e.tipo, e.ente,
           extract(epoch from (e.resuelto_en - e.desde)) / 3600.0 as horas,
           (select extract(epoch from (e.resuelto_en - min(ev.creado_en))) / 3600.0
              from public.tramite_eventos ev
             where ev.tramite = e.id and ev.a_estado = 'ante_el_ente'
            having min(ev.creado_en) <= e.resuelto_en) as horas_ente
      from enviados e
     where e.estado = 'resuelto'
       and e.resuelto_en is not null
       and e.resuelto_en >= e.desde
  ),
  por_tipo as (
    select tipo, max(ente) as ente, count(*) as solicitados
      from enviados
     group by tipo
  ),
  tiempo_tipo as (
    select tipo,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente
      from resueltos
     group by tipo
  ),
  tiempo_ente as (
    select ente,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente
      from resueltos
     group by ente
  ),
  por_sector as (
    select sector, count(*) as n
      from public.consultas
     where sector is not null
     group by sector
  ),
  -- El trámite específico de cada sector (9-10-2026). Se agrupa sin mirar mayúsculas ni
  -- espacios de los lados, para que «Licencia ambiental» y «licencia ambiental » cuenten
  -- juntas; se enseña el nombre tal como lo escribió la mayoría.
  por_tramite_sector as (
    select c.sector, lower(trim(c.tramite_sector)) as clave,
           mode() within group (order by trim(c.tramite_sector)) as tramite,
           count(*) as n
      from public.consultas c
     where c.sector is not null
       and coalesce(trim(c.tramite_sector), '') <> ''
     group by c.sector, lower(trim(c.tramite_sector))
  ),
  -- Los motivos de «ya lo solicité» (6-10-2026): por qué pide ayuda el inversionista, ente por
  -- ente. En c45 a c47 y en el SACS ya solicitado (c49) hay un solo ente, el del catálogo, y un
  -- motivo_ya; en c44, uno por cada ente marcado, motivo_ya_<ente>. Se guardan en español
  -- (opcionesClave), así que se agrupan igual los haya escrito quien sea en el idioma que sea.
  -- Desde el 9-10-2026 cada caso lleva también su detalle (detalle_ya, detalle_ya_<ente>), la
  -- solicitud, quién y cuándo: de aquí salen a la vez las cifras y el registro de casos.
  casos as (
    select m.*
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente,
               e.datos ->> 'detalle_ya' as detalle,
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social' as empresa
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso')
        union all
        select e.datos ->> ('motivo_ya_' || x.clave), x.ente,
               e.datos ->> ('detalle_ya_' || x.clave),
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social'
          from enviados e
         cross join (values ('banavih', 'BANAVIH (FAOV)'), ('inces', 'INCES'),
                            ('rupdae', 'RUPDAE'), ('ivss', 'IVSS'),
                            ('rnet', 'RNET'), ('rnc', 'RNC')) as x(clave, ente)
         where e.tipo = 'parafiscales_en_proceso'
      ) m
     where coalesce(m.motivo, '') <> ''
  ),
  motivos as (
    select motivo, ente, count(*) as n
      from casos
     group by motivo, ente
  ),
  ultimos_casos as (
    select ca.*, coalesce(p.nombre_completo, '') as quien
      from casos ca
      left join public.perfiles p on p.id = ca.inversionista
     order by ca.desde desc, ca.id, ca.ente
     limit 500
  )
  select jsonb_build_object(
    'tramites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', p.tipo, 'ente', p.ente, 'solicitados', p.solicitados,
               'resueltos', coalesce(x.n, 0),
               'mediana_h', round(x.mediana::numeric, 1),
               'promedio_h', round(x.promedio::numeric, 1),
               'n_ente', coalesce(x.n_ente, 0),
               'mediana_ente_h', round(x.mediana_ente::numeric, 1))
             order by p.solicitados desc, p.tipo)
        from por_tipo p
        left join tiempo_tipo x on x.tipo = p.tipo), '[]'::jsonb),
    'entes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ente', y.ente, 'resueltos', y.n,
               'mediana_h', round(y.mediana::numeric, 1),
               'promedio_h', round(y.promedio::numeric, 1),
               'n_ente', y.n_ente,
               'mediana_ente_h', round(y.mediana_ente::numeric, 1))
             order by y.n desc, y.ente)
        from tiempo_ente y), '[]'::jsonb),
    'sectores', coalesce((
      select jsonb_agg(jsonb_build_object('sector', s.sector, 'consultas', s.n)
             order by s.n desc, s.sector)
        from por_sector s), '[]'::jsonb),
    'tramites_sector', coalesce((
      select jsonb_agg(jsonb_build_object('sector', ts.sector, 'tramite', ts.tramite, 'n', ts.n)
             order by ts.sector, ts.n desc, ts.tramite)
        from por_tramite_sector ts), '[]'::jsonb),
    'motivos', coalesce((
      select jsonb_agg(jsonb_build_object('motivo', mo.motivo, 'ente', mo.ente, 'n', mo.n)
             order by mo.n desc, mo.motivo, mo.ente)
        from motivos mo), '[]'::jsonb),
    'motivos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'motivo', uc.motivo, 'ente', uc.ente, 'detalle', coalesce(uc.detalle, ''),
               'tramite', uc.id, 'tipo', uc.tipo, 'inversionista', uc.quien,
               'empresa', coalesce(uc.empresa, ''), 'fecha', uc.desde)
             order by uc.desde desc, uc.id, uc.ente)
        from ultimos_casos uc), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;


-- COMPROBACIÓN
--   select column_name from information_schema.columns
--    where table_schema = 'public' and table_name = 'consultas'
--      and column_name = 'tramite_sector';                                  -- una fila
--   select conname from pg_constraint where conname = 'consultas_tramite_sector_cabe';  -- una fila
--   select position('motivos_casos' in pg_get_functiondef('public.estadisticas_control()'::regprocedure)) > 0
--          and position('tramites_sector' in pg_get_functiondef('public.estadisticas_control()'::regprocedure)) > 0
--          as trae_el_detalle;                                              -- true

-- ====================================================================
--  88 / 105   supabase-tiempos.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL TIEMPO DE RESPUESTA, EN SUS DOS TRAMOS
--  Va DESPUÉS de supabase-control-detalle.sql, que es quien dejó escrita
--  la última estadisticas_control(). Va al final para no mover el número
--  de nadie. Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 15 de octubre de 2026, sobre «Tiempo de respuesta» en
--  Control y estadísticas: «quiero más detalles en esta gráfica, cuántos
--  días tarda el CIIP, en cuántos días nos da respuesta el ente, más
--  detallada la información».
--
--  Hasta hoy la función daba la mediana del total y la del tramo ante el
--  ente, y el panel dibujaba el tramo del CIIP restando una de la otra.
--  Dos medianas no se restan: el resultado no es el caso típico de nada.
--  Desde aquí cada resuelto lleva sus dos tramos medidos, y de cada uno
--  salen su mediana, su promedio y su máximo:
--
--    horas_ciip   de que el inversionista envía a la primera vez que se
--                 presenta ante el ente (tramite_eventos, a 'ante_el_ente').
--                 Sin presentación, todo el tiempo es del CIIP.
--    horas_ente   de esa presentación a resuelto. Sin presentación, null:
--                 ese caso no cuenta para el ente.
--
--  Y llaves nuevas, sin tocar las de antes:
--    · en tramites y entes, mediana / promedio / maximo de cada tramo
--      (*_ciip_h, *_ente_h) y del total (maximo_h);
--    · tiempo_total, lo mismo para todos los resueltos juntos;
--    · tiempos_casos, cada resuelto con sus fechas y sus dos tramos, los
--      500 más recientes, como motivos_casos.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: la ficha enseña lo de antes y avisa
--  de que falta este archivo para ver el detalle.
-- ═══════════════════════════════════════════════════════════════════════

create or replace function public.estadisticas_control()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r jsonb;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve las estadísticas' using errcode = '42501';
  end if;

  with enviados as (
    select t.id, t.tipo, coalesce(tt.ente, '') as ente, t.estado,
           t.datos, t.inversionista,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
  -- Cada resuelto con sus dos tramos (15-10-2026): el del CIIP, de que el inversionista
  -- envía a la primera vez que se presenta ante el ente, y el del ente, de ahí a resuelto.
  -- Sin presentación (lo resolvió el CIIP sin pasar por el ente) todo el tiempo es del CIIP
  -- y el ente no cuenta. Una presentación de antes del envío o de después de resolver no es
  -- de este caso.
  presentados as (
    select e.*,
           (select min(ev.creado_en)
              from public.tramite_eventos ev
             where ev.tramite = e.id and ev.a_estado = 'ante_el_ente'
               and ev.creado_en >= e.desde and ev.creado_en <= e.resuelto_en) as presentado
      from enviados e
     where e.estado = 'resuelto'
       and e.resuelto_en is not null
       and e.resuelto_en >= e.desde
  ),
  resueltos as (
    select p.id, p.tipo, p.ente, p.inversionista, p.desde, p.presentado, p.resuelto_en,
           p.datos ->> 'razon_social' as empresa,
           extract(epoch from (p.resuelto_en - p.desde)) / 3600.0 as horas,
           extract(epoch from (coalesce(p.presentado, p.resuelto_en) - p.desde)) / 3600.0 as horas_ciip,
           extract(epoch from (p.resuelto_en - p.presentado)) / 3600.0 as horas_ente
      from presentados p
  ),
  por_tipo as (
    select tipo, max(ente) as ente, count(*) as solicitados
      from enviados
     group by tipo
  ),
  tiempo_tipo as (
    select tipo,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by tipo
  ),
  tiempo_ente as (
    select ente,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by ente
  ),
  -- Lo mismo para todos los resueltos juntos: las tres cifras de arriba de la ficha.
  tiempo_total as (
    select
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
  ),
  -- Y los casos uno por uno, los más recientes primero, con el mismo tope que motivos_casos.
  ultimos_resueltos as (
    select r.*, coalesce(pf.nombre_completo, '') as quien
      from resueltos r
      left join public.perfiles pf on pf.id = r.inversionista
     order by r.resuelto_en desc, r.id
     limit 500
  ),
  por_sector as (
    select sector, count(*) as n
      from public.consultas
     where sector is not null
     group by sector
  ),
  -- El trámite específico de cada sector (9-10-2026). Se agrupa sin mirar mayúsculas ni
  -- espacios de los lados, para que «Licencia ambiental» y «licencia ambiental » cuenten
  -- juntas; se enseña el nombre tal como lo escribió la mayoría.
  por_tramite_sector as (
    select c.sector, lower(trim(c.tramite_sector)) as clave,
           mode() within group (order by trim(c.tramite_sector)) as tramite,
           count(*) as n
      from public.consultas c
     where c.sector is not null
       and coalesce(trim(c.tramite_sector), '') <> ''
     group by c.sector, lower(trim(c.tramite_sector))
  ),
  -- Los motivos de «ya lo solicité» (6-10-2026): por qué pide ayuda el inversionista, ente por
  -- ente. En c45 a c47 y en el SACS ya solicitado (c49) hay un solo ente, el del catálogo, y un
  -- motivo_ya; en c44, uno por cada ente marcado, motivo_ya_<ente>. Se guardan en español
  -- (opcionesClave), así que se agrupan igual los haya escrito quien sea en el idioma que sea.
  -- Desde el 9-10-2026 cada caso lleva también su detalle (detalle_ya, detalle_ya_<ente>), la
  -- solicitud, quién y cuándo: de aquí salen a la vez las cifras y el registro de casos.
  casos as (
    select m.*
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente,
               e.datos ->> 'detalle_ya' as detalle,
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social' as empresa
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso')
        union all
        select e.datos ->> ('motivo_ya_' || x.clave), x.ente,
               e.datos ->> ('detalle_ya_' || x.clave),
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social'
          from enviados e
         cross join (values ('banavih', 'BANAVIH (FAOV)'), ('inces', 'INCES'),
                            ('rupdae', 'RUPDAE'), ('ivss', 'IVSS'),
                            ('rnet', 'RNET'), ('rnc', 'RNC')) as x(clave, ente)
         where e.tipo = 'parafiscales_en_proceso'
      ) m
     where coalesce(m.motivo, '') <> ''
  ),
  motivos as (
    select motivo, ente, count(*) as n
      from casos
     group by motivo, ente
  ),
  ultimos_casos as (
    select ca.*, coalesce(p.nombre_completo, '') as quien
      from casos ca
      left join public.perfiles p on p.id = ca.inversionista
     order by ca.desde desc, ca.id, ca.ente
     limit 500
  )
  select jsonb_build_object(
    'tramites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', p.tipo, 'ente', p.ente, 'solicitados', p.solicitados,
               'resueltos', coalesce(x.n, 0),
               'mediana_h', round(x.mediana::numeric, 1),
               'promedio_h', round(x.promedio::numeric, 1),
               'maximo_h', round(x.maximo::numeric, 1),
               'mediana_ciip_h', round(x.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(x.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(x.maximo_ciip::numeric, 1),
               'n_ente', coalesce(x.n_ente, 0),
               'mediana_ente_h', round(x.mediana_ente::numeric, 1),
               'promedio_ente_h', round(x.promedio_ente::numeric, 1),
               'maximo_ente_h', round(x.maximo_ente::numeric, 1))
             order by p.solicitados desc, p.tipo)
        from por_tipo p
        left join tiempo_tipo x on x.tipo = p.tipo), '[]'::jsonb),
    'entes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ente', y.ente, 'resueltos', y.n,
               'mediana_h', round(y.mediana::numeric, 1),
               'promedio_h', round(y.promedio::numeric, 1),
               'maximo_h', round(y.maximo::numeric, 1),
               'mediana_ciip_h', round(y.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(y.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(y.maximo_ciip::numeric, 1),
               'n_ente', y.n_ente,
               'mediana_ente_h', round(y.mediana_ente::numeric, 1),
               'promedio_ente_h', round(y.promedio_ente::numeric, 1),
               'maximo_ente_h', round(y.maximo_ente::numeric, 1))
             order by y.n desc, y.ente)
        from tiempo_ente y), '[]'::jsonb),
    'tiempo_total', (
      select jsonb_build_object('resueltos', z.n,
               'mediana_h', round(z.mediana::numeric, 1),
               'promedio_h', round(z.promedio::numeric, 1),
               'maximo_h', round(z.maximo::numeric, 1),
               'mediana_ciip_h', round(z.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(z.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(z.maximo_ciip::numeric, 1),
               'n_ente', z.n_ente,
               'mediana_ente_h', round(z.mediana_ente::numeric, 1),
               'promedio_ente_h', round(z.promedio_ente::numeric, 1),
               'maximo_ente_h', round(z.maximo_ente::numeric, 1))
        from tiempo_total z),
    'tiempos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tramite', ur.id, 'tipo', ur.tipo, 'ente', ur.ente,
               'inversionista', ur.quien, 'empresa', coalesce(ur.empresa, ''),
               'enviado', ur.desde, 'presentado', ur.presentado, 'resuelto', ur.resuelto_en,
               'horas', round(ur.horas::numeric, 1),
               'horas_ciip', round(ur.horas_ciip::numeric, 1),
               'horas_ente', round(ur.horas_ente::numeric, 1))
             order by ur.resuelto_en desc, ur.id)
        from ultimos_resueltos ur), '[]'::jsonb),
    'sectores', coalesce((
      select jsonb_agg(jsonb_build_object('sector', s.sector, 'consultas', s.n)
             order by s.n desc, s.sector)
        from por_sector s), '[]'::jsonb),
    'tramites_sector', coalesce((
      select jsonb_agg(jsonb_build_object('sector', ts.sector, 'tramite', ts.tramite, 'n', ts.n)
             order by ts.sector, ts.n desc, ts.tramite)
        from por_tramite_sector ts), '[]'::jsonb),
    'motivos', coalesce((
      select jsonb_agg(jsonb_build_object('motivo', mo.motivo, 'ente', mo.ente, 'n', mo.n)
             order by mo.n desc, mo.motivo, mo.ente)
        from motivos mo), '[]'::jsonb),
    'motivos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'motivo', uc.motivo, 'ente', uc.ente, 'detalle', coalesce(uc.detalle, ''),
               'tramite', uc.id, 'tipo', uc.tipo, 'inversionista', uc.quien,
               'empresa', coalesce(uc.empresa, ''), 'fecha', uc.desde)
             order by uc.desde desc, uc.id, uc.ente)
        from ultimos_casos uc), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;


-- COMPROBACIÓN
--   select position('tiempos_casos' in pg_get_functiondef('public.estadisticas_control()'::regprocedure)) > 0
--          and position('mediana_ciip_h' in pg_get_functiondef('public.estadisticas_control()'::regprocedure)) > 0
--          as trae_los_tramos;                                              -- true

-- ====================================================================
--  89 / 105   supabase-tiempos-pasos.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL TIEMPO DE RESPUESTA, PASO A PASO
--  Va DESPUÉS de supabase-tiempos.sql, que es quien dejó escrita la última
--  estadisticas_control(). Va al final para no mover el número de nadie.
--  Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 15 de octubre de 2026, sobre «Tiempo de respuesta»:
--  «quiero que estas opciones estén en una sola, quiero saber cuánto
--  tardaron los funcionarios para dar la autorización de firmas, pasos
--  detallados». La autorización de firmas es el último paso de la Firma en
--  el Registro de Extranjeros (c32): «Solicitud recibida por el CIIP» →
--  «Revisión de tus recaudos» → «Solicitud recibida por SAREN» →
--  «Autorización para la firma otorgada».
--
--  Los dos tramos de supabase-tiempos.sql (CIIP y ente) no bastan: dentro
--  del CIIP hay dos pasos, y una solicitud devuelta pasa un tiempo en manos
--  del inversionista. tramite_eventos ya apunta cada cambio de estado con
--  su hora y su autor, así que cada resuelto se corta en tramos -de un
--  cambio al siguiente, o a resolverse- y de cada estado sale:
--
--    pasos_tipo        por trámite y estado (enviado, en_revision,
--                      devuelto, ante_el_ente): en cuántos casos se pasó
--                      por ahí, cuántas veces, y la mediana, el promedio y
--                      el máximo de lo que se estuvo en él;
--    tiempos_casos     cada caso lleva además 'pasos', su recorrido: cada
--                      tramo con su estado, cuándo entró, cuándo salió,
--                      cuánto duró y quién del equipo lo movió al siguiente.
--
--  Lo de antes no cambia: solo se añaden esas dos cosas.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: la ficha enseña los dos tramos, sin
--  el paso a paso, y dice qué falta.
-- ═══════════════════════════════════════════════════════════════════════

create or replace function public.estadisticas_control()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r jsonb;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve las estadísticas' using errcode = '42501';
  end if;

  with enviados as (
    select t.id, t.tipo, coalesce(tt.ente, '') as ente, t.estado,
           t.datos, t.inversionista,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
  -- Cada resuelto con sus dos tramos (15-10-2026): el del CIIP, de que el inversionista
  -- envía a la primera vez que se presenta ante el ente, y el del ente, de ahí a resuelto.
  -- Sin presentación (lo resolvió el CIIP sin pasar por el ente) todo el tiempo es del CIIP
  -- y el ente no cuenta. Una presentación de antes del envío o de después de resolver no es
  -- de este caso.
  presentados as (
    select e.*,
           (select min(ev.creado_en)
              from public.tramite_eventos ev
             where ev.tramite = e.id and ev.a_estado = 'ante_el_ente'
               and ev.creado_en >= e.desde and ev.creado_en <= e.resuelto_en) as presentado
      from enviados e
     where e.estado = 'resuelto'
       and e.resuelto_en is not null
       and e.resuelto_en >= e.desde
  ),
  resueltos as (
    select p.id, p.tipo, p.ente, p.inversionista, p.desde, p.presentado, p.resuelto_en,
           p.datos ->> 'razon_social' as empresa,
           extract(epoch from (p.resuelto_en - p.desde)) / 3600.0 as horas,
           extract(epoch from (coalesce(p.presentado, p.resuelto_en) - p.desde)) / 3600.0 as horas_ciip,
           extract(epoch from (p.resuelto_en - p.presentado)) / 3600.0 as horas_ente
      from presentados p
  ),
  por_tipo as (
    select tipo, max(ente) as ente, count(*) as solicitados
      from enviados
     group by tipo
  ),
  tiempo_tipo as (
    select tipo,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by tipo
  ),
  tiempo_ente as (
    select ente,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by ente
  ),
  -- PASO A PASO (15-10-2026): el historial de cada resuelto, cortado en tramos. Cada cambio
  -- de estado abre un tramo que dura hasta el cambio siguiente, o hasta resolverse. «abrio»
  -- es quien lo puso en ese estado y «cerro», quien lo sacó. El tramo de 'resuelto' no
  -- dura nada y no se cuenta, ni lo de antes del envío (el borrador).
  tramos as (
    select r.id, r.tipo, ev.id as ev, ev.a_estado as estado, ev.creado_en as desde_paso,
           coalesce(lead(ev.creado_en) over w, r.resuelto_en) as hasta_paso,
           lead(ev.autor) over w as cerro
      from resueltos r
      join public.tramite_eventos ev on ev.tramite = r.id
     where ev.creado_en >= r.desde - interval '1 second'
       and ev.creado_en <= r.resuelto_en
    window w as (partition by r.id order by ev.creado_en, ev.id)
  ),
  pasos as (
    select t.*, extract(epoch from (t.hasta_paso - t.desde_paso)) / 3600.0 as horas
      from tramos t
     where t.estado in ('enviado', 'en_revision', 'devuelto', 'ante_el_ente')
  ),
  -- Lo de cada caso en cada estado, sumado: una devuelta que vuelve a revisión pasa dos
  -- veces por 'en_revision'.
  paso_caso as (
    select id, tipo, estado, sum(horas) as horas, count(*) as veces
      from pasos
     group by id, tipo, estado
  ),
  paso_tipo as (
    select tipo, estado,
           count(*) as n,
           sum(veces) as veces,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo
      from paso_caso
     group by tipo, estado
  ),
  -- Lo mismo para todos los resueltos juntos: las tres cifras de arriba de la ficha.
  tiempo_total as (
    select
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
  ),
  -- Y los casos uno por uno, los más recientes primero, con el mismo tope que motivos_casos.
  ultimos_resueltos as (
    select r.*, coalesce(pf.nombre_completo, '') as quien
      from resueltos r
      left join public.perfiles pf on pf.id = r.inversionista
     order by r.resuelto_en desc, r.id
     limit 500
  ),
  por_sector as (
    select sector, count(*) as n
      from public.consultas
     where sector is not null
     group by sector
  ),
  -- El trámite específico de cada sector (9-10-2026). Se agrupa sin mirar mayúsculas ni
  -- espacios de los lados, para que «Licencia ambiental» y «licencia ambiental » cuenten
  -- juntas; se enseña el nombre tal como lo escribió la mayoría.
  por_tramite_sector as (
    select c.sector, lower(trim(c.tramite_sector)) as clave,
           mode() within group (order by trim(c.tramite_sector)) as tramite,
           count(*) as n
      from public.consultas c
     where c.sector is not null
       and coalesce(trim(c.tramite_sector), '') <> ''
     group by c.sector, lower(trim(c.tramite_sector))
  ),
  -- Los motivos de «ya lo solicité» (6-10-2026): por qué pide ayuda el inversionista, ente por
  -- ente. En c45 a c47 y en el SACS ya solicitado (c49) hay un solo ente, el del catálogo, y un
  -- motivo_ya; en c44, uno por cada ente marcado, motivo_ya_<ente>. Se guardan en español
  -- (opcionesClave), así que se agrupan igual los haya escrito quien sea en el idioma que sea.
  -- Desde el 9-10-2026 cada caso lleva también su detalle (detalle_ya, detalle_ya_<ente>), la
  -- solicitud, quién y cuándo: de aquí salen a la vez las cifras y el registro de casos.
  casos as (
    select m.*
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente,
               e.datos ->> 'detalle_ya' as detalle,
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social' as empresa
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso')
        union all
        select e.datos ->> ('motivo_ya_' || x.clave), x.ente,
               e.datos ->> ('detalle_ya_' || x.clave),
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social'
          from enviados e
         cross join (values ('banavih', 'BANAVIH (FAOV)'), ('inces', 'INCES'),
                            ('rupdae', 'RUPDAE'), ('ivss', 'IVSS'),
                            ('rnet', 'RNET'), ('rnc', 'RNC')) as x(clave, ente)
         where e.tipo = 'parafiscales_en_proceso'
      ) m
     where coalesce(m.motivo, '') <> ''
  ),
  motivos as (
    select motivo, ente, count(*) as n
      from casos
     group by motivo, ente
  ),
  ultimos_casos as (
    select ca.*, coalesce(p.nombre_completo, '') as quien
      from casos ca
      left join public.perfiles p on p.id = ca.inversionista
     order by ca.desde desc, ca.id, ca.ente
     limit 500
  )
  select jsonb_build_object(
    'tramites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', p.tipo, 'ente', p.ente, 'solicitados', p.solicitados,
               'resueltos', coalesce(x.n, 0),
               'mediana_h', round(x.mediana::numeric, 1),
               'promedio_h', round(x.promedio::numeric, 1),
               'maximo_h', round(x.maximo::numeric, 1),
               'mediana_ciip_h', round(x.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(x.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(x.maximo_ciip::numeric, 1),
               'n_ente', coalesce(x.n_ente, 0),
               'mediana_ente_h', round(x.mediana_ente::numeric, 1),
               'promedio_ente_h', round(x.promedio_ente::numeric, 1),
               'maximo_ente_h', round(x.maximo_ente::numeric, 1))
             order by p.solicitados desc, p.tipo)
        from por_tipo p
        left join tiempo_tipo x on x.tipo = p.tipo), '[]'::jsonb),
    'entes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ente', y.ente, 'resueltos', y.n,
               'mediana_h', round(y.mediana::numeric, 1),
               'promedio_h', round(y.promedio::numeric, 1),
               'maximo_h', round(y.maximo::numeric, 1),
               'mediana_ciip_h', round(y.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(y.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(y.maximo_ciip::numeric, 1),
               'n_ente', y.n_ente,
               'mediana_ente_h', round(y.mediana_ente::numeric, 1),
               'promedio_ente_h', round(y.promedio_ente::numeric, 1),
               'maximo_ente_h', round(y.maximo_ente::numeric, 1))
             order by y.n desc, y.ente)
        from tiempo_ente y), '[]'::jsonb),
    'tiempo_total', (
      select jsonb_build_object('resueltos', z.n,
               'mediana_h', round(z.mediana::numeric, 1),
               'promedio_h', round(z.promedio::numeric, 1),
               'maximo_h', round(z.maximo::numeric, 1),
               'mediana_ciip_h', round(z.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(z.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(z.maximo_ciip::numeric, 1),
               'n_ente', z.n_ente,
               'mediana_ente_h', round(z.mediana_ente::numeric, 1),
               'promedio_ente_h', round(z.promedio_ente::numeric, 1),
               'maximo_ente_h', round(z.maximo_ente::numeric, 1))
        from tiempo_total z),
    'pasos_tipo', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', pt.tipo, 'estado', pt.estado, 'casos', pt.n, 'veces', pt.veces,
               'mediana_h', round(pt.mediana::numeric, 1),
               'promedio_h', round(pt.promedio::numeric, 1),
               'maximo_h', round(pt.maximo::numeric, 1))
             order by pt.tipo, pt.estado)
        from paso_tipo pt), '[]'::jsonb),
    'tiempos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tramite', ur.id, 'tipo', ur.tipo, 'ente', ur.ente,
               'inversionista', ur.quien, 'empresa', coalesce(ur.empresa, ''),
               'enviado', ur.desde, 'presentado', ur.presentado, 'resuelto', ur.resuelto_en,
               'horas', round(ur.horas::numeric, 1),
               'horas_ciip', round(ur.horas_ciip::numeric, 1),
               'horas_ente', round(ur.horas_ente::numeric, 1),
               'pasos', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'estado', pa.estado, 'desde', pa.desde_paso, 'hasta', pa.hasta_paso,
                          'horas', round(pa.horas::numeric, 1),
                          'quien', coalesce(pc.nombre_completo, ''))
                        order by pa.desde_paso, pa.ev)
                   from pasos pa
                   left join public.perfiles pc on pc.id = pa.cerro
                  where pa.id = ur.id), '[]'::jsonb))
             order by ur.resuelto_en desc, ur.id)
        from ultimos_resueltos ur), '[]'::jsonb),
    'sectores', coalesce((
      select jsonb_agg(jsonb_build_object('sector', s.sector, 'consultas', s.n)
             order by s.n desc, s.sector)
        from por_sector s), '[]'::jsonb),
    'tramites_sector', coalesce((
      select jsonb_agg(jsonb_build_object('sector', ts.sector, 'tramite', ts.tramite, 'n', ts.n)
             order by ts.sector, ts.n desc, ts.tramite)
        from por_tramite_sector ts), '[]'::jsonb),
    'motivos', coalesce((
      select jsonb_agg(jsonb_build_object('motivo', mo.motivo, 'ente', mo.ente, 'n', mo.n)
             order by mo.n desc, mo.motivo, mo.ente)
        from motivos mo), '[]'::jsonb),
    'motivos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'motivo', uc.motivo, 'ente', uc.ente, 'detalle', coalesce(uc.detalle, ''),
               'tramite', uc.id, 'tipo', uc.tipo, 'inversionista', uc.quien,
               'empresa', coalesce(uc.empresa, ''), 'fecha', uc.desde)
             order by uc.desde desc, uc.id, uc.ente)
        from ultimos_casos uc), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;


-- COMPROBACIÓN
--   select position('pasos_tipo' in pg_get_functiondef('public.estadisticas_control()'::regprocedure)) > 0
--          as trae_el_paso_a_paso;                                          -- true

-- ====================================================================
--  90 / 105   supabase-rtn.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL REGISTRO TURÍSTICO NACIONAL (c50)
--  Va DESPUÉS de supabase-sacs.sql: redefine su confirma_paso() con una
--  llave más. Usa `nivel` (supabase-informe-victor.sql), `emite`
--  (supabase-encadenado.sql) y `plazo_legal_*` (supabase-plazos.sql).
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 13-10-2026: «https://www.mintur.gob.ve/rtn necesito
--  crear una ficha con este trámite». Y, a la pregunta de cómo: «Portal de
--  MINTUR», igual que el Registro Único Minero (c36). El inversionista se
--  inscribe en el RTN Digital (turismonac.mintur.gob.ve) y lo avisa con su
--  «Ya lo solicité»; el gestor del CIIP lo sigue y lo da por resuelto.
--
--  LO QUE SE LEYÓ
--  ─────────────────────────────────────────────────────────────────────
--  · mintur.gob.ve/rtn (13-10-2026): el RTN es el padrón «único, público,
--    permanente, personal, intransferible y obligatorio» de los prestadores
--    de servicios turísticos. Se hace en el RTN Digital. Revisión: máximo
--    15 días hábiles. Inscripción: 3 UT; actualización: 1 UT, a la cuenta
--    de INATUR en el Banco de Venezuela. Actualizar dentro de 30 días si
--    cambia la denominación, la directiva, los accionistas, el domicilio...
--  · Resolución 007 del MINTUR, 15-2-2016, Gaceta Oficial 40.883 del
--    12-4-2016 (leída en tugacetaoficial.com, no en la Gaceta). Recaudos de
--    la persona jurídica: acta constitutiva y estatutos, RIF vigente,
--    cédulas de todos los accionistas y pólizas de responsabilidad civil e
--    incendio. Credencial provisional de hasta 6 meses; la definitiva dura
--    DOS años y se renueva 30 días antes de vencer: vence = true.
--    Son los recaudos de la ficha (panel.js, RECAUDOS), como en el SACS:
--    el CIIP los revisa antes de que el inversionista los cargue en el RTN
--    Digital (Franklin Reyes, 13-10-2026: «los recaudos»).
--  · La planilla de MINTUR para persona jurídica (solicitud_rtn_juridico.pdf)
--    pide además el tipo de prestador, el registro mercantil, la patente
--    municipal y los empleados.
--
--  POR QUÉ 'actividad'
--  Sólo le toca al que presta servicios turísticos, como el RUM sólo a la
--  minería. Desde el 5-10-2026 'actividad' no lleva distintivo en la
--  tarjeta: lo dice la condición de la ficha.
--
--  EL PLAZO
--  La revisión de 15 días hábiles la dicen la página del MINTUR y la
--  Resolución 007. plazo_dias = 21: quince hábiles en días corridos, como
--  los 14 del RUPDAE para sus diez hábiles.
--
--  LO QUE ESTÁ POR CONFIRMAR CON EL CIIP
--  ─────────────────────────────────────────────────────────────────────
--  1. El artículo exacto de la Resolución 007 que fija los 15 días: no se
--     ha visto en la Gaceta.
--  2. El costo (3 UT) no se modela: lo paga el inversionista en el portal.
--  3. Si va antes o después de la licencia de actividades económicas: la
--     planilla pide el número de patente, así que aquí depende del c10.
--
--  Si alguien corre supabase-tramites.sql SOLO, después de este, el c50 se
--  apaga: aquel deja encendidos exactamente los de su lista. TODO-EN-ORDEN.sql
--  lo corre detrás y lo vuelve a encender.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LOS PAPELES NUEVOS
-- ───────────────────────────────────────────────────────────────────────
--  Lo que sale del trámite, la credencial, y las dos pólizas que pide la
--  Resolución 007. El acta, el RIF y las cédulas de los accionistas ya
--  estaban en la bóveda. Las pólizas caducan: se renuevan cada año.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('certificado_rtn',              'Credencial del Registro Turístico Nacional (RTN)', true),
  ('poliza_responsabilidad_civil', 'Póliza de responsabilidad civil',                  true),
  ('poliza_incendio',              'Póliza de incendio',                               true)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. EL TRÁMITE
-- ───────────────────────────────────────────────────────────────────────
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('registro_turistico', 'c50', 'Registro Turístico Nacional (RTN)', 'MINTUR', 3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite             = 'certificado_rtn',
       plazo_dias        = 21,
       plazo_legal_dias  = 15,
       plazo_legal_norma = 'Resolución 007 del Ministerio del Poder Popular para el Turismo, Gaceta Oficial 40.883 del 12-4-2016',
       nivel             = 'actividad',
       fase              = 3,
       activo            = true
 where codigo = 'registro_turistico';


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA MARCA DEL PASO 1: «Ya lo solicité» en el RTN Digital
-- ───────────────────────────────────────────────────────────────────────
--  'rtn_solicitado'. Es la confirma_paso de supabase-sacs.sql con esa
--  llave más.
create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                     'bomberos_solicitado', 'saime_confirmada', 'locti_inscrito',
                     'sacs_registrado', 'rtn_solicitado') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Una fila: c50 · MINTUR · fase 3 · actividad · emite la credencial ·
--    21 días · 15 por la Resolución 007 · encendido.
--
--   select ref_panel, codigo, nombre, ente, fase, nivel, emite, plazo_dias,
--          plazo_legal_dias, plazo_legal_norma, activo
--   from public.tipos_tramite where ref_panel = 'c50';
--
-- 2) Los tres papeles nuevos, y los tres caducan:
--
--   select codigo, nombre, vence from public.tipos_documento
--   where codigo in ('certificado_rtn','poliza_responsabilidad_civil','poliza_incendio');
--
-- 3) Los obligatorios siguen siendo DIEZ, cinco y cinco: el c50 no suma.
--
--   select fase, count(*) from public.tipos_tramite
--   where nivel = 'obligatorio' group by fase;

-- ====================================================================
--  91 / 105   supabase-permisos-ambientales.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS PERMISOS AMBIENTALES (c30)
--  Va DESPUÉS de supabase-rtn.sql: redefine su confirma_paso() con una
--  llave más. Usa `nivel` (supabase-informe-victor.sql) y `plazo_legal_*`
--  (supabase-plazos.sql).
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 19-10-2026: «tengo que crear una nueva ficha que se
--  llama permisos ambientales», con el documento Permisos_MINEC (Valeria
--  Ramos, CIIP, 14-10-2026), y «solo debe trabajar con el recuadro de
--  Sistemas en línea del MINEC». A la pregunta de qué hacer con la c30
--  genérica: reemplazarla. A la de cómo: el inversionista elige el sistema
--  en línea y el paso 1 le lleva a él, como el SACS (c48). A la de para
--  quién: a todos.
--
--  LO QUE SE LEYÓ
--  ─────────────────────────────────────────────────────────────────────
--  · El cuadro «Sistemas en línea del MINEC y trámites que se presentan en
--    cada uno» del documento: Ventanilla Verde, SIGETRAT, SIFORTRAT, RACDA,
--    SIALAMB y RENMA, con lo que se tramita en cada uno. Los «sin sistema
--    indicado» no entran.
--  · www.minec.gob.ve (19-10-2026): los seis enlaces del cuadro siguen ahí.
--
--  POR QUÉ 'esencial' Y NO 'actividad'
--  Hasta hoy era 'actividad' (supabase-informe-victor.sql): sólo a quien
--  construye. Franklin Reyes pidió que se le muestre a todos, y 'esencial'
--  es el de por defecto.
--
--  SIN PLAZO Y SIN `emite`
--  Cada uno de los más de cien trámites del MINEC tiene su plazo, y los
--  180 días de supabase-plazos.sql eran un estimado del permiso genérico.
--  El gestor lo resuelve con la resolución, como el SACS.
--
--  LO QUE ESTÁ POR CONFIRMAR CON EL CIIP
--  ─────────────────────────────────────────────────────────────────────
--  1. Si hacen falta recaudos revisados por el CIIP antes de ir al
--     sistema, como en el SACS y el RTN. Hoy no pide ninguno.
--  2. Los trámites «sin sistema indicado» (27, más el 221 presencial).
--
--  Si alguien corre supabase-tramites.sql SOLO, después de este, el c30
--  vuelve a llamarse «Permiso ambiental». TODO-EN-ORDEN.sql lo corre detrás.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL TRÁMITE
-- ───────────────────────────────────────────────────────────────────────
update public.tipos_tramite
   set nombre            = 'Permisos ambientales',
       emite             = null,
       plazo_dias        = null,
       plazo_legal_dias  = null,
       plazo_legal_norma = null,
       nivel             = 'esencial',
       fase              = 3,
       activo            = true
 where codigo = 'permiso_ambiental';


-- ───────────────────────────────────────────────────────────────────────
-- 2. LA MARCA DEL PASO 1: «Ya lo solicité» en el sistema del MINEC
-- ───────────────────────────────────────────────────────────────────────
--  'ambiental_solicitado'. Es la confirma_paso de supabase-rtn.sql con esa
--  llave más.
create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                     'bomberos_solicitado', 'saime_confirmada', 'locti_inscrito',
                     'sacs_registrado', 'rtn_solicitado', 'ambiental_solicitado') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Una fila: c30 · Permisos ambientales · MINEC · fase 3 · esencial ·
--    sin emite ni plazo · encendido.
--
--   select ref_panel, codigo, nombre, ente, fase, nivel, emite, plazo_dias,
--          plazo_legal_dias, activo
--   from public.tipos_tramite where ref_panel = 'c30';

-- ====================================================================
--  92 / 105   supabase-borrado-admin.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL ADMINISTRADOR BORRA LO DE LAS PRUEBAS
--  Va al FINAL: redefine tres cerrojos de archivos anteriores
--  (mensaje_no_se_toca de supabase-hilo.sql, papel_en_marcha_no_se_borra
--  de supabase-qa-tramites.sql y autorizacion_no_se_toca de
--  supabase-autorizaciones.sql) y la regla de fuentes de la bitácora
--  (la última, de supabase-seguridad-octubre.sql). Usa es_admin()
--  (supabase-qa-admin.sql), apunta() (supabase-bitacora.sql) y
--  archivos_huerfanos (supabase-setup.sql).
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 15-10-2026: «que desde administrador pueda borrar
--  trámites realizados y documentos», «trámites realizados por nosotros,
--  que estamos realizando pruebas: es para no tocar la base siempre».
--  Hasta hoy, limpiar una cuenta de pruebas era correr a mano un
--  BORRAR-*.sql en el SQL Editor. Decidido con él: las dos formas -una
--  solicitud o un papel sueltos, y vaciar una cuenta entera- y de
--  CUALQUIER cuenta, sin marca de «cuenta de prueba». La guarda contra el
--  error la pone el panel, con su confirmación.
--
--  LA PUERTA DEL BORRADO
--  ─────────────────────────────────────────────────────────────────────
--  Tres cerrojos dejan borrar solo con la puerta de servicio -auth.uid()
--  nulo, el SQL Editor-: los mensajes, que no se cambian ni se borran; las
--  autorizaciones aceptadas; y el papel de una solicitud en marcha. Desde
--  el panel hay un usuario, y el borrado en cascada de una solicitud se
--  topaba con los tres.
--
--  Las tres funciones de aquí abren otra puerta, la del borrado del
--  administrador: un ajuste de la transacción, 'ciip.borrado_admin', que
--  ponen con set_config(..., true) DESPUÉS de comprobar es_admin() y que
--  se apaga solo al terminar. Nadie más lo puede poner: PostgREST solo
--  deja fijar ajustes request.*, y set_config no está a la vista de la
--  API. Y la puerta es SOLO para borrar: un mensaje sigue sin poderse
--  cambiar, lo pida quien lo pida.
--
--  EL ARCHIVO DEL CUBO
--  ─────────────────────────────────────────────────────────────────────
--  Al borrar un papel, el trigger lo apunta en archivos_huerfanos para el
--  barrendero. Pero el barrendero no corre en producción: el archivo se
--  quedaría en el cubo para siempre. Así que las funciones devuelven las
--  rutas, el panel las quita con la API de Storage -el administrador
--  puede borrar en 'recaudos', política nueva- y marca_barridos() deja
--  constancia en archivos_huerfanos. Si el cubo no las acepta, siguen
--  'pendiente' y el barrendero las encuentra donde siempre.
--
--  QUÉ SE LLEVA CADA UNA
--  ─────────────────────────────────────────────────────────────────────
--  · borra_solicitud(id): la solicitud y lo que cuelga de ella por
--    cascade -eventos, enganches con papeles, cola, avisos, órdenes de
--    pago, mensajes, autorización, entes-. Los papeles de la bóveda se
--    quedan: son del inversionista, no de la solicitud.
--  · borra_documento(id): el papel. Devuelve su ruta en el cubo.
--  · vacia_cuenta(usuario): todas sus solicitudes y todos sus papeles. La
--    cuenta, su perfil, su empresa, sus citas y sus consultas se quedan.
--    Devuelve las rutas de los archivos.
--  Las tres dejan rastro en la bitácora: el papel, por el trigger de
--  siempre ('papeles', 'borro'), con el administrador como autor; la
--  solicitud y la cuenta, con la fuente nueva 'borrados'.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA PUERTA
-- ───────────────────────────────────────────────────────────────────────
create or replace function public.borrado_de_admin()
returns boolean
language sql
stable
as $$
  select coalesce(current_setting('ciip.borrado_admin', true), '') = 'si';
$$;

revoke all on function public.borrado_de_admin() from public;
revoke execute on function public.borrado_de_admin() from anon;
grant execute on function public.borrado_de_admin() to authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- 2. LOS TRES CERROJOS, CON LA PUERTA DEL BORRADO
-- ───────────────────────────────────────────────────────────────────────
-- Iguales a los de sus archivos, más una línea: tg_op = 'DELETE' y la
-- puerta abierta.

create or replace function public.mensaje_no_se_toca()
returns trigger
language plpgsql
as $hilo$
begin
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' and public.borrado_de_admin() then
    return old;
  end if;
  raise exception 'Un mensaje no se cambia ni se borra. Escribe otro.'
    using errcode = 'check_violation';
end
$hilo$;

create or replace function public.papel_en_marcha_no_se_borra()
returns trigger
language plpgsql
security definer
set search_path = public
as $qa$
begin
  if auth.uid() is null or public.borrado_de_admin() then
    return old;   -- la puerta de servicio, o la del borrado del administrador
  end if;
  if exists (
    select 1
      from public.tramite_documentos td
      join public.tramites t on t.id = td.tramite
     where td.documento = old.id
       and t.estado not in ('borrador', 'devuelto', 'cancelado')
  ) then
    raise exception 'Ese documento va en una solicitud en marcha: no se borra'
      using errcode = 'check_violation';
  end if;
  return old;
end
$qa$;

create or replace function public.autorizacion_no_se_toca()
returns trigger
language plpgsql
as $aut$
begin
  -- La puerta de servicio (SQL Editor) y la revocación, que solo pone
  -- la fecha a una que no la tenía.
  if auth.uid() is null then
    return coalesce(new, old);
  end if;
  if tg_op = 'DELETE' and public.borrado_de_admin() then
    return old;
  end if;
  if tg_op = 'UPDATE'
     and old.revocada_en is null and new.revocada_en is not null
     and (to_jsonb(new) - 'revocada_en') = (to_jsonb(old) - 'revocada_en') then
    return new;
  end if;
  raise exception 'Una autorización aceptada no se cambia ni se borra: se revoca.'
    using errcode = 'check_violation';
end
$aut$;


-- ───────────────────────────────────────────────────────────────────────
-- 3. LA BITÁCORA ACEPTA 'borrados'
-- ───────────────────────────────────────────────────────────────────────
alter table public.bitacora drop constraint if exists bitacora_fuente_valida;
alter table public.bitacora add constraint bitacora_fuente_valida
  check (fuente in ('catalogo','roles','papeles','citas',
                    'textos','activos','acompanamiento','entes','borrados'));


-- ───────────────────────────────────────────────────────────────────────
-- 4. EL ADMINISTRADOR PUEDE QUITAR ARCHIVOS DEL CUBO
-- ───────────────────────────────────────────────────────────────────────
-- Leer ya podía: «recaudos: leer su carpeta» deja al equipo. La API de
-- Storage pide las dos para borrar.
drop policy if exists "recaudos: el administrador borra" on storage.objects;
create policy "recaudos: el administrador borra" on storage.objects
  for delete to authenticated
  using (bucket_id = 'recaudos' and public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 5. LAS TRES FUNCIONES
-- ───────────────────────────────────────────────────────────────────────
create or replace function public.borra_solicitud(p_tramite uuid)
returns void
language plpgsql
security definer
set search_path = public
as $bo$
declare
  v_nombre text;
  v_correo text;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede borrar solicitudes'
      using errcode = 'insufficient_privilege';
  end if;

  select coalesce(tt.nombre, t.tipo), coalesce(u.email, '')
    into v_nombre, v_correo
    from public.tramites t
    left join public.tipos_tramite tt on tt.codigo = t.tipo
    left join auth.users u on u.id = t.inversionista
   where t.id = p_tramite;
  if not found then
    raise exception 'Esa solicitud ya no existe'
      using errcode = 'no_data_found';
  end if;

  perform set_config('ciip.borrado_admin', 'si', true);
  delete from public.tramites where id = p_tramite;
  perform public.apunta('borrados', 'solicitud', v_nombre, v_correo);
end
$bo$;

create or replace function public.borra_documento(p_documento uuid)
returns text
language plpgsql
security definer
set search_path = public
as $bo$
declare
  v_ruta text;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede borrar documentos'
      using errcode = 'insufficient_privilege';
  end if;

  perform set_config('ciip.borrado_admin', 'si', true);
  delete from public.documentos where id = p_documento
  returning archivo into v_ruta;
  if not found then
    raise exception 'Ese documento ya no existe'
      using errcode = 'no_data_found';
  end if;
  return v_ruta;
end
$bo$;

create or replace function public.vacia_cuenta(p_usuario uuid)
returns setof text
language plpgsql
security definer
set search_path = public
as $bo$
declare
  v_correo text;
  v_solicitudes int;
  v_papeles int;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador puede vaciar una cuenta'
      using errcode = 'insufficient_privilege';
  end if;

  select coalesce(email, '') into v_correo from auth.users where id = p_usuario;
  if not found then
    raise exception 'Esa cuenta no existe'
      using errcode = 'no_data_found';
  end if;

  perform set_config('ciip.borrado_admin', 'si', true);
  delete from public.tramites where inversionista = p_usuario;
  get diagnostics v_solicitudes = row_count;

  return query
    with fuera as (
      delete from public.documentos where inversionista = p_usuario
      returning archivo
    )
    select archivo from fuera where coalesce(archivo, '') <> '';
  get diagnostics v_papeles = row_count;

  -- Las cuentas, no una frase: el panel las dice en el idioma de quien mira.
  perform public.apunta('borrados', 'cuenta', v_correo,
                        json_build_object('solicitudes', v_solicitudes, 'papeles', v_papeles)::text);
end
$bo$;

-- Y la constancia de que el panel quitó los archivos del cubo. Solo las
-- rutas que el panel consiguió borrar; las demás siguen 'pendiente'.
create or replace function public.marca_barridos(p_rutas text[])
returns integer
language plpgsql
security definer
set search_path = public
as $bo$
declare
  n integer;
begin
  if not public.es_admin() then
    raise exception 'Solo el administrador'
      using errcode = 'insufficient_privilege';
  end if;
  update public.archivos_huerfanos
     set estado = 'barrido', barrido_en = now(), ultimo_error = null
   where cubo = 'recaudos'
     and ruta = any(coalesce(p_rutas, '{}'))
     and estado <> 'barrido';
  get diagnostics n = row_count;
  return n;
end
$bo$;

revoke all on function public.borra_solicitud(uuid) from public;
revoke execute on function public.borra_solicitud(uuid) from anon;
grant execute on function public.borra_solicitud(uuid) to authenticated;
revoke all on function public.borra_documento(uuid) from public;
revoke execute on function public.borra_documento(uuid) from anon;
grant execute on function public.borra_documento(uuid) to authenticated;
revoke all on function public.vacia_cuenta(uuid) from public;
revoke execute on function public.vacia_cuenta(uuid) from anon;
grant execute on function public.vacia_cuenta(uuid) to authenticated;
revoke all on function public.marca_barridos(text[]) from public;
revoke execute on function public.marca_barridos(text[]) from anon;
grant execute on function public.marca_barridos(text[]) to authenticated;


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1) Las cuatro funciones están, y solo las ejecuta authenticated:
--
--   select p.proname, has_function_privilege('anon', p.oid, 'execute') as anon,
--          has_function_privilege('authenticated', p.oid, 'execute') as auth
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--   where n.nspname = 'public'
--     and p.proname in ('borra_solicitud','borra_documento','vacia_cuenta','marca_barridos');
--
-- 2) La política nueva del cubo:
--
--   select policyname from pg_policies
--   where schemaname = 'storage' and policyname = 'recaudos: el administrador borra';
--
-- 3) La bitácora acepta 'borrados':
--
--   select pg_get_constraintdef(oid) from pg_constraint
--   where conname = 'bitacora_fuente_valida';

-- ====================================================================
--  93 / 105   supabase-permiso-ambiental-sube.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL PERMISO DEL MINEC LO SUBE EL INVERSIONISTA
--  Va DESPUÉS de supabase-permisos-ambientales.sql. Solo necesita
--  tipos_documento, tramites, documentos y tramite_documentos. Se puede
--  correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 19-10-2026, en los permisos ambientales (c30): «el
--  gestor estaría pendiente del trámite pero él no puede cerrar el caso,
--  porque no le llegará el documento a él, o sea tiene que estar informado
--  en el proceso, y el paso lo cierra cuando el inversionista suba el
--  permiso solicitado», y «el CIIP confirma el permiso y finaliza el
--  trámite».
--
--  Los pasos pasan a ser tres: «Solicita tu permiso en el sistema en línea
--  del MINEC» (la marca 'ambiental_solicitado'), «Sube el permiso que te
--  otorgó el MINEC» (este papel) y «Permiso confirmado por el CIIP», que
--  el gestor cierra al resolver sin subir nada.
--
--  LO QUE HACE
--  ─────────────────────────────────────────────────────────────────────
--  1. El tipo de documento 'permiso_ambiental', que no vence: cada permiso
--     del MINEC tiene su vigencia, y la dice el propio permiso.
--  2. La política que deja al inversionista colgarlo de SU solicitud de
--     permisos ambientales, ya enviada y con el paso 1 marcado. Como la de
--     la planilla firmada (supabase-planilla-firmada.sql), en su propia
--     política: las políticas se suman y no se reescribe la de otro. Y una
--     restrictiva que no lo deja colgar de ninguna otra manera.
--  3. El freno: no se resuelve un permiso ambiental sin un permiso del
--     MINEC colgado que no esté rechazado. Como el del sellado de libros
--     (supabase-libros.sql). El panel ya avisa antes de intentarlo; esto es
--     para quien llegue por otro camino.
--
--  El aviso al gestor no necesita nada aquí: la campana del panel ya lee
--  los papeles colgados de las solicitudes que lleva, y basta con que el
--  tipo esté en su lista.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. EL TIPO DE DOCUMENTO
-- ───────────────────────────────────────────────────────────────────────
insert into public.tipos_documento (codigo, nombre, vence) values
  ('permiso_ambiental', 'Permiso ambiental del MINEC', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. COLGARLO DESDE SU PASO
-- ───────────────────────────────────────────────────────────────────────
--  «adjuntos: adjuntar a lo propio» solo deja colgar papeles en borrador o
--  devuelta, y éste llega con la solicitud en marcha: recibida, en revisión
--  o ya presentada ante el MINEC, que es lo normal, porque el permiso lo
--  otorga el MINEC cuando quiere. Devuelta no, que es volver al principio.
--  Y solo con «Ya lo solicité» marcado: sin solicitud en el sistema del
--  MINEC no hay permiso que subir, y el paso 2 todavía no está en curso.
drop policy if exists "adjuntos: el permiso del MINEC, desde su paso" on public.tramite_documentos;
create policy "adjuntos: el permiso del MINEC, desde su paso" on public.tramite_documentos
  for insert
  with check (
    exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and t.inversionista = auth.uid()
         and d.inversionista = auth.uid()
         and d.tipo = 'permiso_ambiental'
         and t.tipo = 'permiso_ambiental'
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
         and coalesce(t.datos, '{}'::jsonb) ? 'ambiental_solicitado'
    )
  );

--  Y SOLO ASÍ. La de arriba suma; ésta resta. «adjuntos: adjuntar a lo
--  propio» deja colgar cualquier papel propio de una solicitud en borrador
--  o devuelta, y con ella el permiso entraba en un borrador, o en la
--  solicitud de otro trámite, antes de que el paso 2 estuviera en curso.
--  Restrictiva: un permiso del MINEC solo se cuelga de un permiso
--  ambiental en marcha y con «Ya lo solicité» marcado. A los demás papeles
--  no les toca.
drop policy if exists "adjuntos: el permiso del MINEC, solo desde su paso" on public.tramite_documentos;
create policy "adjuntos: el permiso del MINEC, solo desde su paso" on public.tramite_documentos
  as restrictive
  for insert
  with check (
    not exists (
      select 1
        from public.documentos d
       where d.id = tramite_documentos.documento
         and d.tipo = 'permiso_ambiental'
    )
    or exists (
      select 1
        from public.tramites t
       where t.id = tramite_documentos.tramite
         and t.tipo = 'permiso_ambiental'
         and t.estado in ('enviado', 'en_revision', 'ante_el_ente')
         and coalesce(t.datos, '{}'::jsonb) ? 'ambiental_solicitado'
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- 3. EL FRENO: NO SE CONFIRMA SIN EL PERMISO
-- ───────────────────────────────────────────────────────────────────────
--  Sin sesión (auth.uid() nulo) pasa, como en el de los libros: es el
--  dueño de la base o una tarea del servidor, no alguien desde el panel.
create or replace function public.tramites_ambiental_con_permiso()
returns trigger
language plpgsql
security definer
set search_path = public
as $ambiental$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'permiso_ambiental' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;
  if not exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
     where td.tramite = new.id
       and d.tipo = 'permiso_ambiental'
       and d.estado <> 'rechazado'
  ) then
    raise exception 'Los permisos ambientales no se confirman sin el permiso del MINEC que sube el inversionista'
      using errcode = 'check_violation';
  end if;
  return new;
end
$ambiental$;

drop trigger if exists tramites_ambiental_permiso on public.tramites;
create trigger tramites_ambiental_permiso
  before update on public.tramites
  for each row execute function public.tramites_ambiental_con_permiso();


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
--   select codigo, nombre, vence from public.tipos_documento
--    where codigo = 'permiso_ambiental';                                   -- una fila
--   select polname from pg_policy
--    where polname in ('adjuntos: el permiso del MINEC, desde su paso',
--                      'adjuntos: el permiso del MINEC, solo desde su paso'); -- dos filas
--   select tgname from pg_trigger where tgname = 'tramites_ambiental_permiso'; -- una fila

-- ====================================================================
--  94 / 105   supabase-fichas-tecnicas.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA FICHA TÉCNICA DE LOS PERMISOS
--  Solo necesita public.es_admin() y public.es_gestor() (supabase-admin.sql
--  y supabase-tramites.sql). Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 20-10-2026: «En administrador necesito crear la ficha
--  técnica de permiso». Un renglón propio en Administración, «Ficha
--  técnica», con la lista de las fichas agrupadas por ente a la izquierda
--  y la ficha elegida a la derecha, editable ahí mismo (la forma 2 de
--  maquetas/ficha-tecnica-cuatro.html).
--
--  Una ficha es lo que el CIIP sabe de UN permiso de UN ente: su base
--  legal, a quién aplica, en qué momento de la inversión se pide, sus
--  recaudos, plazo, vigencia, tasa y cómo se tramita. No es un trámite de
--  la ventanilla, y por ahora no se relaciona con ninguno: «podemos crear
--  la ficha sin datos, mejor sin relacionarla aún con los permisos que ya
--  tenemos» (Franklin Reyes, 20-10-2026).
--
--  QUIÉN HACE QUÉ
--  ─────────────────────────────────────────────────────────────────────
--  · El administrador crea, cambia y borra.
--  · El resto del equipo del CIIP (gestor) la lee: le sirve para contestar
--    al inversionista, pero no la cambia.
--  · El inversionista no la ve. Son apuntes de trabajo del CIIP, con
--    fichas en borrador y notas internas.
--
--  NACE VACÍA
--  ─────────────────────────────────────────────────────────────────────
--  Sin datos: las fichas las escribe el administrador desde el panel. La
--  clave natural (ente_sigla, codigo_ente, nombre) evita dos fichas iguales
--  y deja la puerta abierta a una carga con «on conflict do nothing» el día
--  que haga falta.
--
--  'sectores' queda preparado para el cruce con el sector que traerá
--  Atlas (la matriz de permisos por sector, 16-10-2026): hoy se rellena a
--  mano, separado por comas en la pantalla.
-- ═══════════════════════════════════════════════════════════════════════

do $$
begin
  if to_regprocedure('public.es_admin()') is null then
    raise exception 'Falta public.es_admin(): corre antes supabase-admin.sql';
  end if;
  if to_regprocedure('public.es_gestor()') is null then
    raise exception 'Falta public.es_gestor(): corre antes supabase-tramites.sql';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA TABLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.fichas_tecnicas (
  id              uuid        primary key default gen_random_uuid(),
  -- El ente, por su sigla (MINTUR, MINEC) y por su nombre entero. La
  -- pantalla agrupa por la sigla.
  ente_sigla      text        not null,
  ente            text        not null default '',
  -- El código que el propio ente le da al permiso, si le da alguno.
  codigo_ente     text        not null default '',
  nombre          text        not null,
  base_legal      text        not null default '',
  -- A quién aplica: el supuesto en que hace falta el permiso.
  supuestos       text        not null default '',
  sectores        text[]      not null default '{}',
  -- En qué momento de la inversión se pide.
  momento         text        not null default 'por_clasificar',
  recaudos        text[]      not null default '{}',
  plazo           text        not null default '',
  vigencia        text        not null default '',
  tasa            text        not null default '',
  como_se_tramita text        not null default '',
  enlace          text        not null default '',
  categoria       text        not null default '',
  estado          text        not null default 'borrador',
  notas           text        not null default '',
  -- De dónde salió lo que dice (el documento del CIIP, la Gaceta...).
  fuente          text        not null default '',
  creado_en       timestamptz default now(),
  actualizado_en  timestamptz default now(),
  actualizado_por uuid references auth.users(id) on delete set null,

  constraint fichas_tecnicas_clave unique (ente_sigla, codigo_ente, nombre),
  -- Los cuatro momentos del panel, ni uno más: uno mal escrito dejaría la
  -- ficha fuera de todos los grupos y nadie sabría por qué.
  constraint fichas_tecnicas_momento_valido
    check (momento in ('previo', 'durante', 'operar', 'por_clasificar')),
  constraint fichas_tecnicas_estado_valido
    check (estado in ('borrador', 'confirmado')),
  -- Sin sigla ni nombre no hay ficha: no se sabría dónde ponerla ni cómo
  -- llamarla.
  constraint fichas_tecnicas_sigla_cabe
    check (char_length(btrim(ente_sigla)) between 1 and 60),
  constraint fichas_tecnicas_nombre_cabe
    check (char_length(btrim(nombre)) between 1 and 300),
  -- Topes generosos: cortan un pegado accidental, no una ficha larga.
  constraint fichas_tecnicas_cortos_caben check (
    char_length(ente) <= 300 and char_length(codigo_ente) <= 60 and
    char_length(plazo) <= 300 and char_length(vigencia) <= 300 and
    char_length(tasa) <= 300 and char_length(categoria) <= 120 and
    char_length(enlace) <= 500 and char_length(fuente) <= 500),
  constraint fichas_tecnicas_largos_caben check (
    char_length(base_legal) <= 4000 and char_length(supuestos) <= 4000 and
    char_length(como_se_tramita) <= 4000 and char_length(notas) <= 4000),
  constraint fichas_tecnicas_listas_caben check (
    cardinality(sectores) <= 60 and
    char_length(array_to_string(sectores, '')) <= 3000 and
    cardinality(recaudos) <= 80 and
    char_length(array_to_string(recaudos, '')) <= 16000)
);

comment on table  public.fichas_tecnicas           is 'Ficha técnica de cada permiso, por ente. La escribe el administrador; la lee el equipo del CIIP';
comment on column public.fichas_tecnicas.momento   is 'previo, durante, operar o por_clasificar: en qué momento de la inversión se pide';
comment on column public.fichas_tecnicas.sectores  is 'Los sectores a que aplica, para el cruce con el sector de Atlas';

create index if not exists fichas_tecnicas_por_ente
  on public.fichas_tecnicas (ente_sigla);

alter table public.fichas_tecnicas enable row level security;


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN LA LEE Y QUIÉN LA ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
-- Leer: el equipo del CIIP (gestor y admin; es_gestor() cuenta a los dos
-- y deja fuera a quien esté bloqueado).
drop policy if exists "fichas_tecnicas: la lee el equipo" on public.fichas_tecnicas;
create policy "fichas_tecnicas: la lee el equipo" on public.fichas_tecnicas
  for select to authenticated
  using (public.es_gestor());

-- Escribir: solo el admin.
drop policy if exists "fichas_tecnicas: el admin la crea" on public.fichas_tecnicas;
create policy "fichas_tecnicas: el admin la crea" on public.fichas_tecnicas
  for insert to authenticated
  with check (public.es_admin());

drop policy if exists "fichas_tecnicas: el admin la cambia" on public.fichas_tecnicas;
create policy "fichas_tecnicas: el admin la cambia" on public.fichas_tecnicas
  for update to authenticated
  using      (public.es_admin())
  with check (public.es_admin());

drop policy if exists "fichas_tecnicas: el admin la borra" on public.fichas_tecnicas;
create policy "fichas_tecnicas: el admin la borra" on public.fichas_tecnicas
  for delete to authenticated
  using (public.es_admin());

-- Sin sesión, nada: ni la tabla.
revoke all on public.fichas_tecnicas from anon;


-- ───────────────────────────────────────────────────────────────────────
-- 3. QUIÉN LA TOCÓ
-- ───────────────────────────────────────────────────────────────────────
-- Lo escribe un disparador, como en textos_panel: un campo que rellena
-- quien escribe es un campo que quien escribe puede mentir. Y la fecha de
-- creación no se mueve al cambiarla.
create or replace function public.marca_fichas_tecnicas()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.actualizado_por := auth.uid();
  new.actualizado_en  := now();
  if tg_op = 'UPDATE' then
    new.creado_en := old.creado_en;
  end if;
  return new;
end $$;

drop trigger if exists fichas_tecnicas_quien on public.fichas_tecnicas;
create trigger fichas_tecnicas_quien
  before insert or update on public.fichas_tecnicas
  for each row execute function public.marca_fichas_tecnicas();


-- ───────────────────────────────────────────────────────────────────────
-- 4. LOS DOCUMENTOS DE LA FICHA TÉCNICA
-- ───────────────────────────────────────────────────────────────────────
-- Franklin Reyes, 21-10-2026: que la ficha del caso Tertoga (un PDF hecho
-- fuera del panel) «llegue al de ficha técnica de la ventanilla». Un cubo
-- propio, privado, solo de PDF de hasta 10 MB, como el de los modelos
-- (supabase-modelos.sql). Lo lee el equipo, como la tabla; lo escribe
-- solo el administrador. El inversionista no lo ve. No depende de la
-- tabla: los documentos son archivos sueltos, sin fila que los describa.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('fichas-tecnicas', 'fichas-tecnicas', false, 10485760, array['application/pdf'])
on conflict (id) do update set
  public             = excluded.public,
  file_size_limit    = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "fichas-tecnicas: las lee el equipo" on storage.objects;
create policy "fichas-tecnicas: las lee el equipo" on storage.objects
  for select to authenticated
  using (bucket_id = 'fichas-tecnicas' and public.es_gestor());

drop policy if exists "fichas-tecnicas: el admin sube" on storage.objects;
create policy "fichas-tecnicas: el admin sube" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'fichas-tecnicas' and public.es_admin());

drop policy if exists "fichas-tecnicas: el admin reemplaza" on storage.objects;
create policy "fichas-tecnicas: el admin reemplaza" on storage.objects
  for update to authenticated
  using      (bucket_id = 'fichas-tecnicas' and public.es_admin())
  with check (bucket_id = 'fichas-tecnicas' and public.es_admin());

drop policy if exists "fichas-tecnicas: el admin borra" on storage.objects;
create policy "fichas-tecnicas: el admin borra" on storage.objects
  for delete to authenticated
  using (bucket_id = 'fichas-tecnicas' and public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE
-- ───────────────────────────────────────────────────────────────────────
-- · No entra en la bitácora. Su regla de fuentes es una lista cerrada
--   (supabase-borrado-admin.sql), y abrirla para esto es otro trabajo.
--   Quién la cambió por última vez queda en su propia fila.
-- · No trae fichas ni se relaciona con los trámites: ver la cabecera.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. Las cuatro políticas: leer, crear, cambiar y borrar.
select policyname, cmd from pg_policies
where  schemaname = 'public' and tablename = 'fichas_tecnicas'
order  by cmd;

-- 2. Lo que hay, por ente.
select ente_sigla, count(*) from public.fichas_tecnicas group by ente_sigla order by ente_sigla;

-- ====================================================================
--  95 / 105   supabase-fichas-inversionistas.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA FICHA DE CADA INVERSIONISTA
--  Necesita public.es_admin() y public.es_gestor() (supabase-admin.sql y
--  supabase-tramites.sql). Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ─────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 27-10-2026: la ficha toma los permisos que le faltan al
--  inversionista al crear su usuario, «con el fin de hacer función del
--  expediente»; se genera en Administración → Ficha técnica; tiene la
--  forma de la ficha de Atlas (la del caso Tertoga); y es editable por el
--  administrador «antes de subirla al inversionista».
--
--  UNA FILA POR INVERSIONISTA
--  ─────────────────────────────────────────────────────────────────────
--  La hoja entera va en 'contenido' (jsonb): título, línea de debajo, las
--  seis cifras, la ruta legal por secciones, la nota y las fuentes. Es un
--  documento que el administrador reescribe a mano, no un registro que se
--  consulte por partes, y así cada cambio del formato no pide otro SQL.
--
--  QUIÉN HACE QUÉ
--  ─────────────────────────────────────────────────────────────────────
--  · El administrador la crea, la cambia, la envía y la borra.
--  · El resto del equipo del CIIP la lee.
--  · El inversionista lee la suya, y solo una vez enviada: el borrador es
--    trabajo del CIIP.
-- ═══════════════════════════════════════════════════════════════════════

do $$
begin
  if to_regprocedure('public.es_admin()') is null then
    raise exception 'Falta public.es_admin(): corre antes supabase-admin.sql';
  end if;
  if to_regprocedure('public.es_gestor()') is null then
    raise exception 'Falta public.es_gestor(): corre antes supabase-tramites.sql';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA TABLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.fichas_inversionistas (
  usuario_id      uuid        primary key references public.perfiles(id) on delete cascade,
  contenido       jsonb       not null default '{}'::jsonb,
  estado          text        not null default 'borrador',
  -- Cuándo se le envió por última vez. Volver a borrador no la borra:
  -- dice que ya la vio una vez.
  enviada_en      timestamptz,
  creado_en       timestamptz default now(),
  actualizado_en  timestamptz default now(),
  actualizado_por uuid references auth.users(id) on delete set null,

  constraint fichas_inversionistas_estado_valido
    check (estado in ('borrador', 'enviada')),
  constraint fichas_inversionistas_es_objeto
    check (jsonb_typeof(contenido) = 'object'),
  constraint fichas_inversionistas_cabe
    check (pg_column_size(contenido) <= 200000)
);

comment on table  public.fichas_inversionistas           is 'La ficha de cada inversionista (ruta legal de su proyecto). La escribe el administrador; el inversionista la ve una vez enviada';
comment on column public.fichas_inversionistas.contenido is 'La hoja entera: titulo, sub, kpis, ruta, nota y fuentes';
comment on column public.fichas_inversionistas.estado    is 'borrador (solo la ve el CIIP) o enviada (la ve también el inversionista)';

alter table public.fichas_inversionistas enable row level security;


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN LA LEE Y QUIÉN LA ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
drop policy if exists "fichas_inversionistas: la lee el equipo" on public.fichas_inversionistas;
create policy "fichas_inversionistas: la lee el equipo" on public.fichas_inversionistas
  for select to authenticated
  using (public.es_gestor());

drop policy if exists "fichas_inversionistas: el inversionista lee la suya enviada" on public.fichas_inversionistas;
create policy "fichas_inversionistas: el inversionista lee la suya enviada" on public.fichas_inversionistas
  for select to authenticated
  using (usuario_id = auth.uid() and estado = 'enviada');

drop policy if exists "fichas_inversionistas: el admin la crea" on public.fichas_inversionistas;
create policy "fichas_inversionistas: el admin la crea" on public.fichas_inversionistas
  for insert to authenticated
  with check (public.es_admin());

drop policy if exists "fichas_inversionistas: el admin la cambia" on public.fichas_inversionistas;
create policy "fichas_inversionistas: el admin la cambia" on public.fichas_inversionistas
  for update to authenticated
  using      (public.es_admin())
  with check (public.es_admin());

drop policy if exists "fichas_inversionistas: el admin la borra" on public.fichas_inversionistas;
create policy "fichas_inversionistas: el admin la borra" on public.fichas_inversionistas
  for delete to authenticated
  using (public.es_admin());

revoke all on public.fichas_inversionistas from anon;


-- ───────────────────────────────────────────────────────────────────────
-- 3. QUIÉN LA TOCÓ Y CUÁNDO SE ENVIÓ
-- ───────────────────────────────────────────────────────────────────────
-- Lo pone la base, no el navegador. La fecha del envío se sella al pasar
-- a 'enviada', y no se mueve mientras siga enviada.
create or replace function public.marca_fichas_inversionistas()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.actualizado_por := auth.uid();
  new.actualizado_en  := now();
  if tg_op = 'UPDATE' then
    new.creado_en := old.creado_en;
    new.enviada_en := case
      when new.estado = 'enviada' and old.estado is distinct from 'enviada' then now()
      else old.enviada_en end;
  else
    new.enviada_en := case when new.estado = 'enviada' then now() else null end;
  end if;
  return new;
end $$;

drop trigger if exists fichas_inversionistas_quien on public.fichas_inversionistas;
create trigger fichas_inversionistas_quien
  before insert or update on public.fichas_inversionistas
  for each row execute function public.marca_fichas_inversionistas();

-- ====================================================================
--  96 / 105   supabase-permisos-agricolas.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS PERMISOS DE AGRICULTURA (c51)
--  Va DESPUÉS de supabase-permisos-ambientales.sql: redefine su
--  confirma_paso() con una llave más. Usa `nivel` (supabase-informe-
--  victor.sql). Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  Franklin Reyes, 30-10-2026: el equipo mandó «para Claude» lo que se hace
--  en los sistemas del INSAI (SIGESAI, RUNSAI y la plataforma de
--  certificados) y en el INTI. Primero fueron dos fichas (c51 insai y c52
--  inti), y el mismo día: «no es en casillas separadas, INSAI e INTI van
--  dentro de permisos de agricultura». Queda UNA, la c51:
--  · el inversionista elige dónde -un sistema del INSAI o la Oficina
--    Regional de Tierras del INTI- y lo que va a pedir;
--  · lo solicita allí y lo avisa con «Ya lo solicité» (agricola_solicitado).
--  Sin plazo publicado. Lo que entrega el ente se guarda como documento.
--  Si las dos de antes llegaron a la base, se apagan y sueltan la c51 y la
--  c52. No se borran: ref_panel es NOT NULL y UNIQUE, y tramites, citas,
--  consultas y autorizaciones las señalan sin cascada; una solicitud que
--  ya existiera haría fallar el borrado.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Lo que entrega el ente. No se sabe si vence: no vence.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('permiso_agricola', 'Registro, permiso o certificado del INSAI, o documento del INTI', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- 2. Las dos de antes, si están: apagadas y con un ref_panel que ninguna
-- tarjeta usa. Antes que el insert, que si no chocaría con la c51.
update public.tipos_tramite
   set activo    = false,
       ref_panel = 'retirado-' || codigo
 where codigo in ('insai', 'inti');

-- 3. El trámite, en la fase 3 con los demás registros sectoriales.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('permisos_agricolas', 'c51', 'Permisos de agricultura', 'MPPAPT', 3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set ref_panel = 'c51',
       emite     = 'permiso_agricola',
       nivel     = 'actividad',
       fase      = 3,
       activo    = true
 where codigo = 'permisos_agricolas';

-- 4. La marca del paso 1: la de supabase-permisos-ambientales.sql con
-- 'agricola_solicitado'.
create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                     'bomberos_solicitado', 'saime_confirmada', 'locti_inscrito',
                     'sacs_registrado', 'rtn_solicitado', 'ambiental_solicitado',
                     'agricola_solicitado') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;

-- ====================================================================
--  97 / 105   supabase-logos-diligencias.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS LOGOS DE AYUDA Y GUÍA, DE CADA ENLACE
--  Va DESPUÉS de supabase-textos.sql (textos_panel) y de
--  supabase-logos-fichas.sql (el cubo). Va al final para no mover el
--  número de nadie.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 30 de octubre de 2026: en Ayuda y guía → «Dónde hacer
--  las diligencias», cada enlace de una tarjeta (Authenology, Apacuana,
--  PROCERT…) enseñaba sólo sus iniciales. Que el administrador le pueda
--  poner, cambiar o quitar el logo desde el panel, como ya podía con el de
--  la tarjeta desde el 13-10-2026.
--
--  CÓMO QUEDA
--  ───────────────────────────────────────────────────────────────────────
--  Sin tabla ni cubo nuevos. El archivo va al cubo 'logos-fichas'
--  (público de lectura, sólo el admin escribe y borra) y su ruta a
--  textos_panel (la lee quien entra, sólo el admin escribe), en 'es':
--
--    · '<tarjeta>.logo'      → 'ayuda/<tarjeta>/<hora>.png'
--    · '<tarjeta>.logo.<n>'  → 'ayuda/<tarjeta>/enlaces/<n>/<hora>.png'
--
--  <n> sale de la dirección del enlace (ayHuella() en panel.js). Lo único
--  que añade este archivo es la regla de que esas claves guarden eso y
--  nada más: una ruta de ayuda/ de su misma tarjeta, con extensión de
--  imagen, y sólo en español, que un logo no cambia con el idioma. Así un
--  texto pegado por error en «Editar textos» no se convierte en un logo
--  roto para todos los inversionistas.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: los logos se suben y se ven igual;
--  sólo falta la regla.
-- ═══════════════════════════════════════════════════════════════════════

alter table public.textos_panel
  drop constraint if exists textos_panel_logo_ayuda;

alter table public.textos_panel
  add constraint textos_panel_logo_ayuda check (
    clave !~ '^ay_[a-z0-9_]+\.logo(\.[a-z0-9]+)?$'
    or (idioma = 'es'
        and texto ~ '^ayuda/ay_[a-z0-9_]+/(enlaces/[a-z0-9]+/)?[0-9]+\.(png|jpg|webp)$'
        and split_part(texto, '/', 2) = split_part(clave, '.', 1)
        and case when clave ~ '\.logo$' then texto !~ '/enlaces/'
                 else split_part(texto, '/', 4) = split_part(clave, '.', 3) end)
  );

comment on constraint textos_panel_logo_ayuda on public.textos_panel is
  'Las claves de los logos de Ayuda (<tarjeta>.logo y <tarjeta>.logo.<enlace>) sólo guardan, en es, la ruta de su imagen en el cubo logos-fichas';

-- ====================================================================
--  98 / 105   supabase-ya-solicite-permisos.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — «YA SOLICITÉ UN PERMISO» ANTE EL MINEC Y ANTE
--  EL INSAI O EL INTI (c53 y c54)
--  Va DESPUÉS de supabase-permisos-ambientales.sql y de supabase-permisos-
--  agricolas.sql (las casillas madre, c30 y c51) y de supabase-tiempos-
--  pasos.sql, que es quien dejó escrita la última estadisticas_control().
--  Usa `nivel` (supabase-informe-victor.sql). Va al final para no mover el
--  número de nadie. Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 2 de noviembre de 2026: «ahora quiero que permisos
--  ambientales y agrícolas tengan esta pregunta también». La del SACS
--  (supabase-sacs.sql): al abrir la casilla, «Ya solicité un permiso» o
--  «Solicitar un permiso por primera vez». La de primera vez es la de
--  siempre (c30, c51); la de «ya solicité» es un trámite nuevo de cada
--  una, escondido detrás con data-tramo-de, como el c49:
--    · ambiental_en_proceso (c53), ante el MINEC;
--    · agricola_en_proceso  (c54), ante el INSAI o el INTI, con el ente de
--      su casilla madre en el catálogo (MPPAPT).
--  Sin emite ni plazo, en la fase 3 y con el nivel del SACS ya solicitado.
--  Sus recaudos son tipos que ya existen (acta, RIF de la empresa, cédula
--  y RIF del representante) y no llevan marca del paso 1 (confirma_paso no
--  cambia). Estadísticas cuenta sus motivos de pedir ayuda, como los del
--  c49: es estadisticas_control() de supabase-tiempos-pasos.sql, ENTERA,
--  con los dos tipos más.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Los dos trámites, encendidos.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('ambiental_en_proceso', 'c53', 'Permiso ambiental ya solicitado',      'MINEC',  3, true),
  ('agricola_en_proceso',  'c54', 'Permiso de agricultura ya solicitado', 'MPPAPT', 3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set ref_panel  = case codigo when 'ambiental_en_proceso' then 'c53' else 'c54' end,
       emite      = null,
       plazo_dias = null,
       nivel      = 'actividad',
       fase       = 3,
       activo     = true
 where codigo in ('ambiental_en_proceso', 'agricola_en_proceso');

-- 2. Las cifras de Control y Estadísticas: los motivos de «ya lo solicité» cuentan también los dos.
create or replace function public.estadisticas_control()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r jsonb;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve las estadísticas' using errcode = '42501';
  end if;

  with enviados as (
    select t.id, t.tipo, coalesce(tt.ente, '') as ente, t.estado,
           t.datos, t.inversionista,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
  -- Cada resuelto con sus dos tramos (15-10-2026): el del CIIP, de que el inversionista
  -- envía a la primera vez que se presenta ante el ente, y el del ente, de ahí a resuelto.
  -- Sin presentación (lo resolvió el CIIP sin pasar por el ente) todo el tiempo es del CIIP
  -- y el ente no cuenta. Una presentación de antes del envío o de después de resolver no es
  -- de este caso.
  presentados as (
    select e.*,
           (select min(ev.creado_en)
              from public.tramite_eventos ev
             where ev.tramite = e.id and ev.a_estado = 'ante_el_ente'
               and ev.creado_en >= e.desde and ev.creado_en <= e.resuelto_en) as presentado
      from enviados e
     where e.estado = 'resuelto'
       and e.resuelto_en is not null
       and e.resuelto_en >= e.desde
  ),
  resueltos as (
    select p.id, p.tipo, p.ente, p.inversionista, p.desde, p.presentado, p.resuelto_en,
           p.datos ->> 'razon_social' as empresa,
           extract(epoch from (p.resuelto_en - p.desde)) / 3600.0 as horas,
           extract(epoch from (coalesce(p.presentado, p.resuelto_en) - p.desde)) / 3600.0 as horas_ciip,
           extract(epoch from (p.resuelto_en - p.presentado)) / 3600.0 as horas_ente
      from presentados p
  ),
  por_tipo as (
    select tipo, max(ente) as ente, count(*) as solicitados
      from enviados
     group by tipo
  ),
  tiempo_tipo as (
    select tipo,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by tipo
  ),
  tiempo_ente as (
    select ente,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by ente
  ),
  -- PASO A PASO (15-10-2026): el historial de cada resuelto, cortado en tramos. Cada cambio
  -- de estado abre un tramo que dura hasta el cambio siguiente, o hasta resolverse. «abrio»
  -- es quien lo puso en ese estado y «cerro», quien lo sacó. El tramo de 'resuelto' no
  -- dura nada y no se cuenta, ni lo de antes del envío (el borrador).
  tramos as (
    select r.id, r.tipo, ev.id as ev, ev.a_estado as estado, ev.creado_en as desde_paso,
           coalesce(lead(ev.creado_en) over w, r.resuelto_en) as hasta_paso,
           lead(ev.autor) over w as cerro
      from resueltos r
      join public.tramite_eventos ev on ev.tramite = r.id
     where ev.creado_en >= r.desde - interval '1 second'
       and ev.creado_en <= r.resuelto_en
    window w as (partition by r.id order by ev.creado_en, ev.id)
  ),
  pasos as (
    select t.*, extract(epoch from (t.hasta_paso - t.desde_paso)) / 3600.0 as horas
      from tramos t
     where t.estado in ('enviado', 'en_revision', 'devuelto', 'ante_el_ente')
  ),
  -- Lo de cada caso en cada estado, sumado: una devuelta que vuelve a revisión pasa dos
  -- veces por 'en_revision'.
  paso_caso as (
    select id, tipo, estado, sum(horas) as horas, count(*) as veces
      from pasos
     group by id, tipo, estado
  ),
  paso_tipo as (
    select tipo, estado,
           count(*) as n,
           sum(veces) as veces,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo
      from paso_caso
     group by tipo, estado
  ),
  -- Lo mismo para todos los resueltos juntos: las tres cifras de arriba de la ficha.
  tiempo_total as (
    select
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
  ),
  -- Y los casos uno por uno, los más recientes primero, con el mismo tope que motivos_casos.
  ultimos_resueltos as (
    select r.*, coalesce(pf.nombre_completo, '') as quien
      from resueltos r
      left join public.perfiles pf on pf.id = r.inversionista
     order by r.resuelto_en desc, r.id
     limit 500
  ),
  por_sector as (
    select sector, count(*) as n
      from public.consultas
     where sector is not null
     group by sector
  ),
  -- El trámite específico de cada sector (9-10-2026). Se agrupa sin mirar mayúsculas ni
  -- espacios de los lados, para que «Licencia ambiental» y «licencia ambiental » cuenten
  -- juntas; se enseña el nombre tal como lo escribió la mayoría.
  por_tramite_sector as (
    select c.sector, lower(trim(c.tramite_sector)) as clave,
           mode() within group (order by trim(c.tramite_sector)) as tramite,
           count(*) as n
      from public.consultas c
     where c.sector is not null
       and coalesce(trim(c.tramite_sector), '') <> ''
     group by c.sector, lower(trim(c.tramite_sector))
  ),
  -- Los motivos de «ya lo solicité» (6-10-2026): por qué pide ayuda el inversionista, ente por
  -- ente. En c45 a c47 y en el SACS ya solicitado (c49) hay un solo ente, el del catálogo, y un
  -- motivo_ya; y desde el 2-11-2026 (Franklin Reyes) también en los permisos ya solicitados ante el
  -- MINEC (c53) y ante el INSAI o el INTI (c54); en c44, uno por cada ente marcado, motivo_ya_<ente>. Se guardan en español
  -- (opcionesClave), así que se agrupan igual los haya escrito quien sea en el idioma que sea.
  -- Desde el 9-10-2026 cada caso lleva también su detalle (detalle_ya, detalle_ya_<ente>), la
  -- solicitud, quién y cuándo: de aquí salen a la vez las cifras y el registro de casos.
  casos as (
    select m.*
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente,
               e.datos ->> 'detalle_ya' as detalle,
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social' as empresa
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso', 'ambiental_en_proceso', 'agricola_en_proceso')
        union all
        select e.datos ->> ('motivo_ya_' || x.clave), x.ente,
               e.datos ->> ('detalle_ya_' || x.clave),
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social'
          from enviados e
         cross join (values ('banavih', 'BANAVIH (FAOV)'), ('inces', 'INCES'),
                            ('rupdae', 'RUPDAE'), ('ivss', 'IVSS'),
                            ('rnet', 'RNET'), ('rnc', 'RNC')) as x(clave, ente)
         where e.tipo = 'parafiscales_en_proceso'
      ) m
     where coalesce(m.motivo, '') <> ''
  ),
  motivos as (
    select motivo, ente, count(*) as n
      from casos
     group by motivo, ente
  ),
  ultimos_casos as (
    select ca.*, coalesce(p.nombre_completo, '') as quien
      from casos ca
      left join public.perfiles p on p.id = ca.inversionista
     order by ca.desde desc, ca.id, ca.ente
     limit 500
  )
  select jsonb_build_object(
    'tramites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', p.tipo, 'ente', p.ente, 'solicitados', p.solicitados,
               'resueltos', coalesce(x.n, 0),
               'mediana_h', round(x.mediana::numeric, 1),
               'promedio_h', round(x.promedio::numeric, 1),
               'maximo_h', round(x.maximo::numeric, 1),
               'mediana_ciip_h', round(x.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(x.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(x.maximo_ciip::numeric, 1),
               'n_ente', coalesce(x.n_ente, 0),
               'mediana_ente_h', round(x.mediana_ente::numeric, 1),
               'promedio_ente_h', round(x.promedio_ente::numeric, 1),
               'maximo_ente_h', round(x.maximo_ente::numeric, 1))
             order by p.solicitados desc, p.tipo)
        from por_tipo p
        left join tiempo_tipo x on x.tipo = p.tipo), '[]'::jsonb),
    'entes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ente', y.ente, 'resueltos', y.n,
               'mediana_h', round(y.mediana::numeric, 1),
               'promedio_h', round(y.promedio::numeric, 1),
               'maximo_h', round(y.maximo::numeric, 1),
               'mediana_ciip_h', round(y.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(y.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(y.maximo_ciip::numeric, 1),
               'n_ente', y.n_ente,
               'mediana_ente_h', round(y.mediana_ente::numeric, 1),
               'promedio_ente_h', round(y.promedio_ente::numeric, 1),
               'maximo_ente_h', round(y.maximo_ente::numeric, 1))
             order by y.n desc, y.ente)
        from tiempo_ente y), '[]'::jsonb),
    'tiempo_total', (
      select jsonb_build_object('resueltos', z.n,
               'mediana_h', round(z.mediana::numeric, 1),
               'promedio_h', round(z.promedio::numeric, 1),
               'maximo_h', round(z.maximo::numeric, 1),
               'mediana_ciip_h', round(z.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(z.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(z.maximo_ciip::numeric, 1),
               'n_ente', z.n_ente,
               'mediana_ente_h', round(z.mediana_ente::numeric, 1),
               'promedio_ente_h', round(z.promedio_ente::numeric, 1),
               'maximo_ente_h', round(z.maximo_ente::numeric, 1))
        from tiempo_total z),
    'pasos_tipo', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', pt.tipo, 'estado', pt.estado, 'casos', pt.n, 'veces', pt.veces,
               'mediana_h', round(pt.mediana::numeric, 1),
               'promedio_h', round(pt.promedio::numeric, 1),
               'maximo_h', round(pt.maximo::numeric, 1))
             order by pt.tipo, pt.estado)
        from paso_tipo pt), '[]'::jsonb),
    'tiempos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tramite', ur.id, 'tipo', ur.tipo, 'ente', ur.ente,
               'inversionista', ur.quien, 'empresa', coalesce(ur.empresa, ''),
               'enviado', ur.desde, 'presentado', ur.presentado, 'resuelto', ur.resuelto_en,
               'horas', round(ur.horas::numeric, 1),
               'horas_ciip', round(ur.horas_ciip::numeric, 1),
               'horas_ente', round(ur.horas_ente::numeric, 1),
               'pasos', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'estado', pa.estado, 'desde', pa.desde_paso, 'hasta', pa.hasta_paso,
                          'horas', round(pa.horas::numeric, 1),
                          'quien', coalesce(pc.nombre_completo, ''))
                        order by pa.desde_paso, pa.ev)
                   from pasos pa
                   left join public.perfiles pc on pc.id = pa.cerro
                  where pa.id = ur.id), '[]'::jsonb))
             order by ur.resuelto_en desc, ur.id)
        from ultimos_resueltos ur), '[]'::jsonb),
    'sectores', coalesce((
      select jsonb_agg(jsonb_build_object('sector', s.sector, 'consultas', s.n)
             order by s.n desc, s.sector)
        from por_sector s), '[]'::jsonb),
    'tramites_sector', coalesce((
      select jsonb_agg(jsonb_build_object('sector', ts.sector, 'tramite', ts.tramite, 'n', ts.n)
             order by ts.sector, ts.n desc, ts.tramite)
        from por_tramite_sector ts), '[]'::jsonb),
    'motivos', coalesce((
      select jsonb_agg(jsonb_build_object('motivo', mo.motivo, 'ente', mo.ente, 'n', mo.n)
             order by mo.n desc, mo.motivo, mo.ente)
        from motivos mo), '[]'::jsonb),
    'motivos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'motivo', uc.motivo, 'ente', uc.ente, 'detalle', coalesce(uc.detalle, ''),
               'tramite', uc.id, 'tipo', uc.tipo, 'inversionista', uc.quien,
               'empresa', coalesce(uc.empresa, ''), 'fecha', uc.desde)
             order by uc.desde desc, uc.id, uc.ente)
        from ultimos_casos uc), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;

-- COMPROBACIÓN
--   select ref_panel, codigo, ente, fase, nivel, activo from public.tipos_tramite
--    where codigo in ('ambiental_en_proceso', 'agricola_en_proceso') order by ref_panel;  -- c53 y c54
--   select position('agricola_en_proceso' in pg_get_functiondef('public.estadisticas_control()'::regprocedure)) > 0
--          as cuenta_los_ya_solicitados;                                    -- true

-- ====================================================================
--  99 / 105   supabase-ya-solicite-mineria-turismo.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — «YA SOLICITÉ UN PERMISO» EN MINERÍA Y TURISMO
--  (c55 y c56), Y EL RNC (c13) FUERA DE LAS INSCRIPCIONES, CON SU TARJETA
--  Va DESPUÉS de supabase-rupdae-rum.sql y de supabase-rtn.sql (las casillas
--  madre), de supabase-entes-parafiscales.sql y supabase-qa-tramites.sql (los
--  entes y el freno de resolver), de supabase-permisos-agricolas.sql (la
--  última confirma_paso) y de supabase-ya-solicite-permisos.sql (la última
--  estadisticas_control). Va al final para no mover el número de nadie. Se
--  puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 2 de noviembre de 2026, dos pedidos:
--
--  «Lo mismo con permisos mineros y permisos de turismo»: la pregunta del
--  SACS. La de primera vez es la de siempre (c36, c50); la de «ya solicité»
--  es un trámite nuevo de cada una, escondido detrás con data-tramo-de:
--    · minero_en_proceso    (c55), ante el ministerio minero;
--    · turistico_en_proceso (c56), ante el MINTUR.
--  Sin emite ni plazo, como el c49. Estadísticas cuenta sus motivos.
--
--  «Saca el RNC de ese grupo»: de las inscripciones (c37 y c44).
--    · El trámite 'rnc' (c13) YA EXISTÍA, apagado desde el 20-9-2026 por
--      supabase-parafiscales.sql, y con solicitudes viejas: no se crea otro,
--      se enciende. Lo que emite es nuevo, 'certificado_rnc'. Si alguien
--      corre supabase-parafiscales.sql SOLO, después de este, el c13 se
--      vuelve a apagar: hay que correr este otra vez.
--    · 'rnc_solicitado' entra en confirma_paso: el inversionista lo solicita
--      en RNC en línea y marca «Ya lo solicité».
--    · Las solicitudes nuevas de parafiscales nacen con CINCO entes y se
--      resuelven con esos cinco. El nombre parafiscales_con_los_seis se
--      queda: es el del disparador que ya está puesto en la base.
--    · LO VIEJO NO SE TOCA. 'snc' sigue en el check de tramite_entes, 'ente_snc'
--      en confirma_paso, y las filas de 'snc' que ya existan se quedan donde
--      están: el panel las sigue enseñando si alguien las movió.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Los dos trámites de «ya solicité», encendidos.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('minero_en_proceso',    'c55', 'Registro Único Minero ya solicitado',       'Ministerio de Desarrollo Minero', 3, true),
  ('turistico_en_proceso', 'c56', 'Registro Turístico Nacional ya solicitado', 'MINTUR',                          3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set ref_panel  = case codigo when 'minero_en_proceso' then 'c55' else 'c56' end,
       emite      = null,
       plazo_dias = null,
       nivel      = 'actividad',
       fase       = 3,
       activo     = true
 where codigo in ('minero_en_proceso', 'turistico_en_proceso');

-- 2. El RNC, con su tarjeta: lo que emite, y encendido.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('certificado_rnc', 'Certificado de inscripción en el Registro Nacional de Contratistas (RNC)', true)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

update public.tipos_tramite
   set emite  = 'certificado_rnc',
       nivel  = 'actividad',
       fase   = 3,
       activo = true
 where codigo = 'rnc';

-- 3. La marca del paso 1 del RNC: la confirma_paso de supabase-permisos-agricolas.sql con esa llave más.
create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                     'bomberos_solicitado', 'saime_confirmada', 'locti_inscrito',
                     'sacs_registrado', 'rtn_solicitado', 'ambiental_solicitado',
                     'agricola_solicitado', 'rnc_solicitado') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;

-- 4. Las inscripciones nacen con cinco entes, sin el RNC.
create or replace function public.tramite_entes_nacen()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.tipo = 'registros_parafiscales'
     and new.estado in ('enviado', 'en_revision', 'ante_el_ente') then
    insert into public.tramite_entes (tramite, ente, estado)
    select new.id, e, 'pendiente'
      from unnest(array['banavih', 'inces', 'mpppst', 'sundde', 'ivss']) as e
    on conflict (tramite, ente) do nothing;
  end if;
  return new;
end $$;

-- 5. Y se resuelven con esos cinco. Una fila vieja de 'snc' no cuenta ni estorba.
create or replace function public.parafiscales_con_los_seis()
returns trigger
language plpgsql
security definer
set search_path = public
as $qa$
begin
  if auth.uid() is null
     or new.tipo is distinct from 'registros_parafiscales'
     or new.estado is distinct from 'resuelto'
     or old.estado = 'resuelto' then
    return new;
  end if;
  if (select count(*) from public.tramite_entes
       where tramite = new.id and estado = 'listo' and ente <> 'snc') < 5 then
    raise exception 'Hay inscripciones sin terminar en los registros parafiscales'
      using errcode = 'check_violation';
  end if;
  return new;
end
$qa$;

-- 6. Las cifras de Control y Estadísticas: los motivos de «ya lo solicité» cuentan también los dos.
create or replace function public.estadisticas_control()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r jsonb;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve las estadísticas' using errcode = '42501';
  end if;

  with enviados as (
    select t.id, t.tipo, coalesce(tt.ente, '') as ente, t.estado,
           t.datos, t.inversionista,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
  -- Cada resuelto con sus dos tramos (15-10-2026): el del CIIP, de que el inversionista
  -- envía a la primera vez que se presenta ante el ente, y el del ente, de ahí a resuelto.
  -- Sin presentación (lo resolvió el CIIP sin pasar por el ente) todo el tiempo es del CIIP
  -- y el ente no cuenta. Una presentación de antes del envío o de después de resolver no es
  -- de este caso.
  presentados as (
    select e.*,
           (select min(ev.creado_en)
              from public.tramite_eventos ev
             where ev.tramite = e.id and ev.a_estado = 'ante_el_ente'
               and ev.creado_en >= e.desde and ev.creado_en <= e.resuelto_en) as presentado
      from enviados e
     where e.estado = 'resuelto'
       and e.resuelto_en is not null
       and e.resuelto_en >= e.desde
  ),
  resueltos as (
    select p.id, p.tipo, p.ente, p.inversionista, p.desde, p.presentado, p.resuelto_en,
           p.datos ->> 'razon_social' as empresa,
           extract(epoch from (p.resuelto_en - p.desde)) / 3600.0 as horas,
           extract(epoch from (coalesce(p.presentado, p.resuelto_en) - p.desde)) / 3600.0 as horas_ciip,
           extract(epoch from (p.resuelto_en - p.presentado)) / 3600.0 as horas_ente
      from presentados p
  ),
  por_tipo as (
    select tipo, max(ente) as ente, count(*) as solicitados
      from enviados
     group by tipo
  ),
  tiempo_tipo as (
    select tipo,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by tipo
  ),
  tiempo_ente as (
    select ente,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by ente
  ),
  -- PASO A PASO (15-10-2026): el historial de cada resuelto, cortado en tramos. Cada cambio
  -- de estado abre un tramo que dura hasta el cambio siguiente, o hasta resolverse. «abrio»
  -- es quien lo puso en ese estado y «cerro», quien lo sacó. El tramo de 'resuelto' no
  -- dura nada y no se cuenta, ni lo de antes del envío (el borrador).
  tramos as (
    select r.id, r.tipo, ev.id as ev, ev.a_estado as estado, ev.creado_en as desde_paso,
           coalesce(lead(ev.creado_en) over w, r.resuelto_en) as hasta_paso,
           lead(ev.autor) over w as cerro
      from resueltos r
      join public.tramite_eventos ev on ev.tramite = r.id
     where ev.creado_en >= r.desde - interval '1 second'
       and ev.creado_en <= r.resuelto_en
    window w as (partition by r.id order by ev.creado_en, ev.id)
  ),
  pasos as (
    select t.*, extract(epoch from (t.hasta_paso - t.desde_paso)) / 3600.0 as horas
      from tramos t
     where t.estado in ('enviado', 'en_revision', 'devuelto', 'ante_el_ente')
  ),
  -- Lo de cada caso en cada estado, sumado: una devuelta que vuelve a revisión pasa dos
  -- veces por 'en_revision'.
  paso_caso as (
    select id, tipo, estado, sum(horas) as horas, count(*) as veces
      from pasos
     group by id, tipo, estado
  ),
  paso_tipo as (
    select tipo, estado,
           count(*) as n,
           sum(veces) as veces,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo
      from paso_caso
     group by tipo, estado
  ),
  -- Lo mismo para todos los resueltos juntos: las tres cifras de arriba de la ficha.
  tiempo_total as (
    select
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
  ),
  -- Y los casos uno por uno, los más recientes primero, con el mismo tope que motivos_casos.
  ultimos_resueltos as (
    select r.*, coalesce(pf.nombre_completo, '') as quien
      from resueltos r
      left join public.perfiles pf on pf.id = r.inversionista
     order by r.resuelto_en desc, r.id
     limit 500
  ),
  por_sector as (
    select sector, count(*) as n
      from public.consultas
     where sector is not null
     group by sector
  ),
  -- El trámite específico de cada sector (9-10-2026). Se agrupa sin mirar mayúsculas ni
  -- espacios de los lados, para que «Licencia ambiental» y «licencia ambiental » cuenten
  -- juntas; se enseña el nombre tal como lo escribió la mayoría.
  por_tramite_sector as (
    select c.sector, lower(trim(c.tramite_sector)) as clave,
           mode() within group (order by trim(c.tramite_sector)) as tramite,
           count(*) as n
      from public.consultas c
     where c.sector is not null
       and coalesce(trim(c.tramite_sector), '') <> ''
     group by c.sector, lower(trim(c.tramite_sector))
  ),
  -- Los motivos de «ya lo solicité» (6-10-2026): por qué pide ayuda el inversionista, ente por
  -- ente. En c45 a c47 y en el SACS ya solicitado (c49) hay un solo ente, el del catálogo, y un
  -- motivo_ya; y desde el 2-11-2026 (Franklin Reyes) también en los permisos ya solicitados ante el
  -- MINEC (c53) y ante el INSAI o el INTI (c54); en c44, uno por cada ente marcado, motivo_ya_<ente>. Se guardan en español
  -- (opcionesClave), así que se agrupan igual los haya escrito quien sea en el idioma que sea.
  -- Desde el 9-10-2026 cada caso lleva también su detalle (detalle_ya, detalle_ya_<ente>), la
  -- solicitud, quién y cuándo: de aquí salen a la vez las cifras y el registro de casos.
  casos as (
    select m.*
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente,
               e.datos ->> 'detalle_ya' as detalle,
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social' as empresa
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso', 'ambiental_en_proceso', 'agricola_en_proceso',
                          'minero_en_proceso', 'turistico_en_proceso')
        union all
        select e.datos ->> ('motivo_ya_' || x.clave), x.ente,
               e.datos ->> ('detalle_ya_' || x.clave),
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social'
          from enviados e
         cross join (values ('banavih', 'BANAVIH (FAOV)'), ('inces', 'INCES'),
                            ('rupdae', 'RUPDAE'), ('ivss', 'IVSS'),
                            ('rnet', 'RNET'), ('rnc', 'RNC')) as x(clave, ente)
         where e.tipo = 'parafiscales_en_proceso'
      ) m
     where coalesce(m.motivo, '') <> ''
  ),
  motivos as (
    select motivo, ente, count(*) as n
      from casos
     group by motivo, ente
  ),
  ultimos_casos as (
    select ca.*, coalesce(p.nombre_completo, '') as quien
      from casos ca
      left join public.perfiles p on p.id = ca.inversionista
     order by ca.desde desc, ca.id, ca.ente
     limit 500
  )
  select jsonb_build_object(
    'tramites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', p.tipo, 'ente', p.ente, 'solicitados', p.solicitados,
               'resueltos', coalesce(x.n, 0),
               'mediana_h', round(x.mediana::numeric, 1),
               'promedio_h', round(x.promedio::numeric, 1),
               'maximo_h', round(x.maximo::numeric, 1),
               'mediana_ciip_h', round(x.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(x.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(x.maximo_ciip::numeric, 1),
               'n_ente', coalesce(x.n_ente, 0),
               'mediana_ente_h', round(x.mediana_ente::numeric, 1),
               'promedio_ente_h', round(x.promedio_ente::numeric, 1),
               'maximo_ente_h', round(x.maximo_ente::numeric, 1))
             order by p.solicitados desc, p.tipo)
        from por_tipo p
        left join tiempo_tipo x on x.tipo = p.tipo), '[]'::jsonb),
    'entes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ente', y.ente, 'resueltos', y.n,
               'mediana_h', round(y.mediana::numeric, 1),
               'promedio_h', round(y.promedio::numeric, 1),
               'maximo_h', round(y.maximo::numeric, 1),
               'mediana_ciip_h', round(y.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(y.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(y.maximo_ciip::numeric, 1),
               'n_ente', y.n_ente,
               'mediana_ente_h', round(y.mediana_ente::numeric, 1),
               'promedio_ente_h', round(y.promedio_ente::numeric, 1),
               'maximo_ente_h', round(y.maximo_ente::numeric, 1))
             order by y.n desc, y.ente)
        from tiempo_ente y), '[]'::jsonb),
    'tiempo_total', (
      select jsonb_build_object('resueltos', z.n,
               'mediana_h', round(z.mediana::numeric, 1),
               'promedio_h', round(z.promedio::numeric, 1),
               'maximo_h', round(z.maximo::numeric, 1),
               'mediana_ciip_h', round(z.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(z.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(z.maximo_ciip::numeric, 1),
               'n_ente', z.n_ente,
               'mediana_ente_h', round(z.mediana_ente::numeric, 1),
               'promedio_ente_h', round(z.promedio_ente::numeric, 1),
               'maximo_ente_h', round(z.maximo_ente::numeric, 1))
        from tiempo_total z),
    'pasos_tipo', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', pt.tipo, 'estado', pt.estado, 'casos', pt.n, 'veces', pt.veces,
               'mediana_h', round(pt.mediana::numeric, 1),
               'promedio_h', round(pt.promedio::numeric, 1),
               'maximo_h', round(pt.maximo::numeric, 1))
             order by pt.tipo, pt.estado)
        from paso_tipo pt), '[]'::jsonb),
    'tiempos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tramite', ur.id, 'tipo', ur.tipo, 'ente', ur.ente,
               'inversionista', ur.quien, 'empresa', coalesce(ur.empresa, ''),
               'enviado', ur.desde, 'presentado', ur.presentado, 'resuelto', ur.resuelto_en,
               'horas', round(ur.horas::numeric, 1),
               'horas_ciip', round(ur.horas_ciip::numeric, 1),
               'horas_ente', round(ur.horas_ente::numeric, 1),
               'pasos', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'estado', pa.estado, 'desde', pa.desde_paso, 'hasta', pa.hasta_paso,
                          'horas', round(pa.horas::numeric, 1),
                          'quien', coalesce(pc.nombre_completo, ''))
                        order by pa.desde_paso, pa.ev)
                   from pasos pa
                   left join public.perfiles pc on pc.id = pa.cerro
                  where pa.id = ur.id), '[]'::jsonb))
             order by ur.resuelto_en desc, ur.id)
        from ultimos_resueltos ur), '[]'::jsonb),
    'sectores', coalesce((
      select jsonb_agg(jsonb_build_object('sector', s.sector, 'consultas', s.n)
             order by s.n desc, s.sector)
        from por_sector s), '[]'::jsonb),
    'tramites_sector', coalesce((
      select jsonb_agg(jsonb_build_object('sector', ts.sector, 'tramite', ts.tramite, 'n', ts.n)
             order by ts.sector, ts.n desc, ts.tramite)
        from por_tramite_sector ts), '[]'::jsonb),
    'motivos', coalesce((
      select jsonb_agg(jsonb_build_object('motivo', mo.motivo, 'ente', mo.ente, 'n', mo.n)
             order by mo.n desc, mo.motivo, mo.ente)
        from motivos mo), '[]'::jsonb),
    'motivos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'motivo', uc.motivo, 'ente', uc.ente, 'detalle', coalesce(uc.detalle, ''),
               'tramite', uc.id, 'tipo', uc.tipo, 'inversionista', uc.quien,
               'empresa', coalesce(uc.empresa, ''), 'fecha', uc.desde)
             order by uc.desde desc, uc.id, uc.ente)
        from ultimos_casos uc), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;

-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
--   select ref_panel, codigo, ente, fase, nivel, emite, activo from public.tipos_tramite
--    where codigo in ('minero_en_proceso', 'turistico_en_proceso', 'rnc') order by ref_panel;  -- c13, c55 y c56, encendidos
--   select position('rnc_solicitado' in pg_get_functiondef('public.confirma_paso(uuid, text)'::regprocedure)) > 0;
--   select position('turistico_en_proceso' in pg_get_functiondef('public.estadisticas_control()'::regprocedure)) > 0;

-- ====================================================================
--  100 / 105   supabase-hidrocarburos-pesca-energia.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS PERMISOS DE HIDROCARBUROS, PESCA Y ENERGÍA
--  (c57 a c62)
--  Va DESPUÉS de supabase-ya-solicite-mineria-turismo.sql: redefine su
--  confirma_paso y su estadisticas_control con tres llaves y tres motivos más.
--  Va al final para no mover el número de nadie. Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 3 de noviembre de 2026: «permisos de hidrocarburos, pesca y
--  energía», «crea las fichas del catálogo»; «trabájalo como en la maqueta»
--  (maquetas/hidrocarburos-pesca-energia.html). Tres fichas, cada una con su
--  «ya solicité un permiso» escondido detrás, como el c49:
--    · permisos_hidrocarburos (c57) y hidrocarburos_en_proceso (c58), MINHIDROCARBUROS;
--    · permisos_pesca         (c59) y pesca_en_proceso         (c60), INSOPESCA;
--    · permisos_energia       (c61) y energia_en_proceso       (c62), MPPEE.
--  Sin plazo publicado. La de primera vez deja el documento que entrega el
--  ente, que no se sabe si vence: no vence. Los recaudos son los de la maqueta,
--  borrador para que el CIIP los corrija; los provisionales ya estaban en la base.
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Lo que entrega cada ente, y los recaudos que todavía no estaban en la base.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('permiso_hidrocarburos', 'Permiso o autorización del Ministerio de Hidrocarburos', false),
  ('permiso_pesca', 'Permiso, registro o certificado de INSOPESCA', false),
  ('permiso_energia', 'Permiso, habilitación o registro del Ministerio de Energía Eléctrica o de CORPOELEC', false),
  ('comunicacion_insopesca', 'Comunicación a la Presidencia de INSOPESCA', false),
  ('inspeccion_artes_equipos', 'Inspección de artes y equipos', false),
  ('informe_capitania_puerto', 'Informe de la Capitanía de Puerto', false),
  ('certificado_arqueo_inea', 'Certificado de arqueo del INEA', false),
  ('fotos_plano_buque', 'Dos fotos y plano del buque', false),
  ('comprobante_posicionamiento', 'Comprobante del dispositivo de posicionamiento', false),
  ('tenencia_tierra', 'Tenencia de la tierra', false),
  ('coordenadas_proyecto', 'Coordenadas del proyecto', false),
  ('inspeccion_tecnica_acuicultura', 'Inspección técnica', false),
  ('aot_aarn_conformidad', 'AOT y AARN, o conformidad de uso', false),
  ('analisis_agua_suelo', 'Análisis de agua y suelo', false),
  ('deposito_tasa_acuicultura', 'Depósito de la tasa', false),
  ('planilla_solicitud_insopesca', 'Planilla de solicitud de INSOPESCA', false),
  ('registro_mercantil_empresa', 'Registro mercantil', false),
  ('pago_tasa_insopesca', 'Pago de la tasa de INSOPESCA', false),
  ('analisis_agua_producto', 'Análisis de agua o producto (plantas y laboratorios)', false),
  ('formulario_for_dgse', 'Formulario FOR-DGSE-001 y planilla del MPPEE', false),
  ('ubicacion_regven_utm', 'Ubicación en coordenadas REGVEN/UTM y poligonal', false),
  ('justificacion_autogeneracion', 'Justificación: procesos, carga total y régimen de uso', false),
  ('especificaciones_equipos', 'Especificaciones de los equipos, planos y combustible', false),
  ('proyecto_conexion_sen', 'Proyecto de conexión al SEN y cronograma (instalación nueva)', false),
  ('racda_emisiones', 'RACDA y constancia de emisiones', false),
  ('factibilidad_combustible', 'Factibilidad y autorización de compra del combustible', false),
  ('legales_autogeneracion', 'Acta, junta vigente, RIF, cédula y poder', false),
  ('propiedad_o_alquiler', 'Propiedad del terreno o contrato de alquiler', false),
  ('registro_mercantil_carta', 'Registro mercantil y carta explicativa', false),
  ('plano_utm_poste', 'Plano con coordenadas UTM y número de poste', false),
  ('memoria_descriptiva_ingeniero', 'Memoria descriptiva firmada por ingeniero colegiado', false),
  ('solvencia_colegio_ingenieros', 'Solvencia del Colegio de Ingenieros', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- 2. Los seis trámites, encendidos, en la fase 3 con los demás sectoriales.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('permisos_hidrocarburos',   'c57', 'Permisos de hidrocarburos',             'MINHIDROCARBUROS', 3, true),
  ('hidrocarburos_en_proceso', 'c58', 'Permiso de hidrocarburos ya solicitado', 'MINHIDROCARBUROS', 3, true),
  ('permisos_pesca',           'c59', 'Permisos de pesca',                     'INSOPESCA',        3, true),
  ('pesca_en_proceso',         'c60', 'Permiso de pesca ya solicitado',        'INSOPESCA',        3, true),
  ('permisos_energia',         'c61', 'Permisos de energía',                   'MPPEE',            3, true),
  ('energia_en_proceso',       'c62', 'Permiso de energía ya solicitado',      'MPPEE',            3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite  = case codigo when 'permisos_hidrocarburos' then 'permiso_hidrocarburos'
                            when 'permisos_pesca'         then 'permiso_pesca'
                            else 'permiso_energia' end,
       nivel  = 'actividad',
       fase   = 3,
       activo = true
 where codigo in ('permisos_hidrocarburos', 'permisos_pesca', 'permisos_energia');

update public.tipos_tramite
   set emite      = null,
       plazo_dias = null,
       nivel      = 'actividad',
       fase       = 3,
       activo     = true
 where codigo in ('hidrocarburos_en_proceso', 'pesca_en_proceso', 'energia_en_proceso');

-- 3. La marca del paso 1: la confirma_paso de supabase-ya-solicite-mineria-turismo.sql con tres llaves más.
create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                     'bomberos_solicitado', 'saime_confirmada', 'locti_inscrito',
                     'sacs_registrado', 'rtn_solicitado', 'ambiental_solicitado',
                     'agricola_solicitado', 'rnc_solicitado',
                     'hidrocarburos_solicitado', 'pesca_solicitado', 'energia_solicitado') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;

-- 4. Sus motivos en las estadísticas: la estadisticas_control de ese mismo archivo con los tres «ya solicité».
create or replace function public.estadisticas_control()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r jsonb;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve las estadísticas' using errcode = '42501';
  end if;

  with enviados as (
    select t.id, t.tipo, coalesce(tt.ente, '') as ente, t.estado,
           t.datos, t.inversionista,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
  -- Cada resuelto con sus dos tramos (15-10-2026): el del CIIP, de que el inversionista
  -- envía a la primera vez que se presenta ante el ente, y el del ente, de ahí a resuelto.
  -- Sin presentación (lo resolvió el CIIP sin pasar por el ente) todo el tiempo es del CIIP
  -- y el ente no cuenta. Una presentación de antes del envío o de después de resolver no es
  -- de este caso.
  presentados as (
    select e.*,
           (select min(ev.creado_en)
              from public.tramite_eventos ev
             where ev.tramite = e.id and ev.a_estado = 'ante_el_ente'
               and ev.creado_en >= e.desde and ev.creado_en <= e.resuelto_en) as presentado
      from enviados e
     where e.estado = 'resuelto'
       and e.resuelto_en is not null
       and e.resuelto_en >= e.desde
  ),
  resueltos as (
    select p.id, p.tipo, p.ente, p.inversionista, p.desde, p.presentado, p.resuelto_en,
           p.datos ->> 'razon_social' as empresa,
           extract(epoch from (p.resuelto_en - p.desde)) / 3600.0 as horas,
           extract(epoch from (coalesce(p.presentado, p.resuelto_en) - p.desde)) / 3600.0 as horas_ciip,
           extract(epoch from (p.resuelto_en - p.presentado)) / 3600.0 as horas_ente
      from presentados p
  ),
  por_tipo as (
    select tipo, max(ente) as ente, count(*) as solicitados
      from enviados
     group by tipo
  ),
  tiempo_tipo as (
    select tipo,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by tipo
  ),
  tiempo_ente as (
    select ente,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by ente
  ),
  -- PASO A PASO (15-10-2026): el historial de cada resuelto, cortado en tramos. Cada cambio
  -- de estado abre un tramo que dura hasta el cambio siguiente, o hasta resolverse. «abrio»
  -- es quien lo puso en ese estado y «cerro», quien lo sacó. El tramo de 'resuelto' no
  -- dura nada y no se cuenta, ni lo de antes del envío (el borrador).
  tramos as (
    select r.id, r.tipo, ev.id as ev, ev.a_estado as estado, ev.creado_en as desde_paso,
           coalesce(lead(ev.creado_en) over w, r.resuelto_en) as hasta_paso,
           lead(ev.autor) over w as cerro
      from resueltos r
      join public.tramite_eventos ev on ev.tramite = r.id
     where ev.creado_en >= r.desde - interval '1 second'
       and ev.creado_en <= r.resuelto_en
    window w as (partition by r.id order by ev.creado_en, ev.id)
  ),
  pasos as (
    select t.*, extract(epoch from (t.hasta_paso - t.desde_paso)) / 3600.0 as horas
      from tramos t
     where t.estado in ('enviado', 'en_revision', 'devuelto', 'ante_el_ente')
  ),
  -- Lo de cada caso en cada estado, sumado: una devuelta que vuelve a revisión pasa dos
  -- veces por 'en_revision'.
  paso_caso as (
    select id, tipo, estado, sum(horas) as horas, count(*) as veces
      from pasos
     group by id, tipo, estado
  ),
  paso_tipo as (
    select tipo, estado,
           count(*) as n,
           sum(veces) as veces,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo
      from paso_caso
     group by tipo, estado
  ),
  -- Lo mismo para todos los resueltos juntos: las tres cifras de arriba de la ficha.
  tiempo_total as (
    select
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
  ),
  -- Y los casos uno por uno, los más recientes primero, con el mismo tope que motivos_casos.
  ultimos_resueltos as (
    select r.*, coalesce(pf.nombre_completo, '') as quien
      from resueltos r
      left join public.perfiles pf on pf.id = r.inversionista
     order by r.resuelto_en desc, r.id
     limit 500
  ),
  por_sector as (
    select sector, count(*) as n
      from public.consultas
     where sector is not null
     group by sector
  ),
  -- El trámite específico de cada sector (9-10-2026). Se agrupa sin mirar mayúsculas ni
  -- espacios de los lados, para que «Licencia ambiental» y «licencia ambiental » cuenten
  -- juntas; se enseña el nombre tal como lo escribió la mayoría.
  por_tramite_sector as (
    select c.sector, lower(trim(c.tramite_sector)) as clave,
           mode() within group (order by trim(c.tramite_sector)) as tramite,
           count(*) as n
      from public.consultas c
     where c.sector is not null
       and coalesce(trim(c.tramite_sector), '') <> ''
     group by c.sector, lower(trim(c.tramite_sector))
  ),
  -- Los motivos de «ya lo solicité» (6-10-2026): por qué pide ayuda el inversionista, ente por
  -- ente. En c45 a c47 y en el SACS ya solicitado (c49) hay un solo ente, el del catálogo, y un
  -- motivo_ya; y desde el 2-11-2026 (Franklin Reyes) también en los permisos ya solicitados ante el
  -- MINEC (c53) y ante el INSAI o el INTI (c54); en c44, uno por cada ente marcado, motivo_ya_<ente>. Se guardan en español
  -- (opcionesClave), así que se agrupan igual los haya escrito quien sea en el idioma que sea.
  -- Desde el 9-10-2026 cada caso lleva también su detalle (detalle_ya, detalle_ya_<ente>), la
  -- solicitud, quién y cuándo: de aquí salen a la vez las cifras y el registro de casos.
  casos as (
    select m.*
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente,
               e.datos ->> 'detalle_ya' as detalle,
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social' as empresa
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso', 'ambiental_en_proceso', 'agricola_en_proceso',
                          'minero_en_proceso', 'turistico_en_proceso',
                          'hidrocarburos_en_proceso', 'pesca_en_proceso', 'energia_en_proceso')
        union all
        select e.datos ->> ('motivo_ya_' || x.clave), x.ente,
               e.datos ->> ('detalle_ya_' || x.clave),
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social'
          from enviados e
         cross join (values ('banavih', 'BANAVIH (FAOV)'), ('inces', 'INCES'),
                            ('rupdae', 'RUPDAE'), ('ivss', 'IVSS'),
                            ('rnet', 'RNET'), ('rnc', 'RNC')) as x(clave, ente)
         where e.tipo = 'parafiscales_en_proceso'
      ) m
     where coalesce(m.motivo, '') <> ''
  ),
  motivos as (
    select motivo, ente, count(*) as n
      from casos
     group by motivo, ente
  ),
  ultimos_casos as (
    select ca.*, coalesce(p.nombre_completo, '') as quien
      from casos ca
      left join public.perfiles p on p.id = ca.inversionista
     order by ca.desde desc, ca.id, ca.ente
     limit 500
  )
  select jsonb_build_object(
    'tramites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', p.tipo, 'ente', p.ente, 'solicitados', p.solicitados,
               'resueltos', coalesce(x.n, 0),
               'mediana_h', round(x.mediana::numeric, 1),
               'promedio_h', round(x.promedio::numeric, 1),
               'maximo_h', round(x.maximo::numeric, 1),
               'mediana_ciip_h', round(x.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(x.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(x.maximo_ciip::numeric, 1),
               'n_ente', coalesce(x.n_ente, 0),
               'mediana_ente_h', round(x.mediana_ente::numeric, 1),
               'promedio_ente_h', round(x.promedio_ente::numeric, 1),
               'maximo_ente_h', round(x.maximo_ente::numeric, 1))
             order by p.solicitados desc, p.tipo)
        from por_tipo p
        left join tiempo_tipo x on x.tipo = p.tipo), '[]'::jsonb),
    'entes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ente', y.ente, 'resueltos', y.n,
               'mediana_h', round(y.mediana::numeric, 1),
               'promedio_h', round(y.promedio::numeric, 1),
               'maximo_h', round(y.maximo::numeric, 1),
               'mediana_ciip_h', round(y.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(y.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(y.maximo_ciip::numeric, 1),
               'n_ente', y.n_ente,
               'mediana_ente_h', round(y.mediana_ente::numeric, 1),
               'promedio_ente_h', round(y.promedio_ente::numeric, 1),
               'maximo_ente_h', round(y.maximo_ente::numeric, 1))
             order by y.n desc, y.ente)
        from tiempo_ente y), '[]'::jsonb),
    'tiempo_total', (
      select jsonb_build_object('resueltos', z.n,
               'mediana_h', round(z.mediana::numeric, 1),
               'promedio_h', round(z.promedio::numeric, 1),
               'maximo_h', round(z.maximo::numeric, 1),
               'mediana_ciip_h', round(z.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(z.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(z.maximo_ciip::numeric, 1),
               'n_ente', z.n_ente,
               'mediana_ente_h', round(z.mediana_ente::numeric, 1),
               'promedio_ente_h', round(z.promedio_ente::numeric, 1),
               'maximo_ente_h', round(z.maximo_ente::numeric, 1))
        from tiempo_total z),
    'pasos_tipo', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', pt.tipo, 'estado', pt.estado, 'casos', pt.n, 'veces', pt.veces,
               'mediana_h', round(pt.mediana::numeric, 1),
               'promedio_h', round(pt.promedio::numeric, 1),
               'maximo_h', round(pt.maximo::numeric, 1))
             order by pt.tipo, pt.estado)
        from paso_tipo pt), '[]'::jsonb),
    'tiempos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tramite', ur.id, 'tipo', ur.tipo, 'ente', ur.ente,
               'inversionista', ur.quien, 'empresa', coalesce(ur.empresa, ''),
               'enviado', ur.desde, 'presentado', ur.presentado, 'resuelto', ur.resuelto_en,
               'horas', round(ur.horas::numeric, 1),
               'horas_ciip', round(ur.horas_ciip::numeric, 1),
               'horas_ente', round(ur.horas_ente::numeric, 1),
               'pasos', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'estado', pa.estado, 'desde', pa.desde_paso, 'hasta', pa.hasta_paso,
                          'horas', round(pa.horas::numeric, 1),
                          'quien', coalesce(pc.nombre_completo, ''))
                        order by pa.desde_paso, pa.ev)
                   from pasos pa
                   left join public.perfiles pc on pc.id = pa.cerro
                  where pa.id = ur.id), '[]'::jsonb))
             order by ur.resuelto_en desc, ur.id)
        from ultimos_resueltos ur), '[]'::jsonb),
    'sectores', coalesce((
      select jsonb_agg(jsonb_build_object('sector', s.sector, 'consultas', s.n)
             order by s.n desc, s.sector)
        from por_sector s), '[]'::jsonb),
    'tramites_sector', coalesce((
      select jsonb_agg(jsonb_build_object('sector', ts.sector, 'tramite', ts.tramite, 'n', ts.n)
             order by ts.sector, ts.n desc, ts.tramite)
        from por_tramite_sector ts), '[]'::jsonb),
    'motivos', coalesce((
      select jsonb_agg(jsonb_build_object('motivo', mo.motivo, 'ente', mo.ente, 'n', mo.n)
             order by mo.n desc, mo.motivo, mo.ente)
        from motivos mo), '[]'::jsonb),
    'motivos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'motivo', uc.motivo, 'ente', uc.ente, 'detalle', coalesce(uc.detalle, ''),
               'tramite', uc.id, 'tipo', uc.tipo, 'inversionista', uc.quien,
               'empresa', coalesce(uc.empresa, ''), 'fecha', uc.desde)
             order by uc.desde desc, uc.id, uc.ente)
        from ultimos_casos uc), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;

-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
--   select ref_panel, codigo, ente, fase, nivel, emite, activo from public.tipos_tramite
--    where ref_panel in ('c57', 'c58', 'c59', 'c60', 'c61', 'c62') order by ref_panel;  -- seis, encendidos
--   select position('energia_solicitado' in pg_get_functiondef('public.confirma_paso(uuid, text)'::regprocedure)) > 0;
--   select position('energia_en_proceso' in pg_get_functiondef('public.estadisticas_control()'::regprocedure)) > 0;

-- ====================================================================
--  101 / 105   supabase-agua-industria-transporte.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS PERMISOS DE AGUA, INDUSTRIA Y COMERCIO, Y TRANSPORTE
--  (c63 a c68)
--  Va DESPUÉS de supabase-hidrocarburos-pesca-energia.sql: redefine su
--  confirma_paso y su estadisticas_control con tres llaves y tres motivos más.
--  Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  Franklin Reyes, 4 de noviembre de 2026: permisos de agua, de industria y
--  comercio y de transporte (maquetas/agua-industria-transporte.html). Tres
--  fichas, cada una con su «ya solicité un permiso» escondido detrás:
--    · permisos_agua       (c63) y agua_en_proceso       (c64), MINAGUAS;
--    · permisos_industria  (c65) y industria_en_proceso  (c66), MPPICN;
--    · permisos_transporte (c67) y transporte_en_proceso (c68), MPPT.
--  Sin plazo publicado. Lo que entrega el ente no vence, porque no se sabe.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Lo que entrega cada ente, y los recaudos que todavía no estaban en la base.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('permiso_agua', 'Concesión, licencia o autorización del Ministerio de Atención de las Aguas', false),
  ('permiso_industria', 'Registro o certificado de SUNDDE o de SENCAMER', false),
  ('permiso_transporte', 'Permiso, registro o certificación del INAC, del INEA o del INTT', false),
  ('planilla_minaguas', 'Planilla de solicitud del ministerio', false),
  ('derecho_inmueble', 'Documento que acredite el derecho sobre el inmueble o la actividad', false),
  ('constancia_hidrologica', 'Constancia de la hidrológica de que no puede suministrar (salvo envasadoras)', false),
  ('constancia_racda', 'Constancia RACDA, si aplica', false),
  ('aot_aarn_aguas', 'Autorización de Ocupación del Territorio y de Afectación de Recursos Naturales', false),
  ('estudio_impacto_aguas', 'Estudio de Impacto Ambiental y Sociocultural, en físico y digital', false),
  ('estudio_tecnico_aguas', 'Estudio técnico (agua superficial) o hidrogeológico (agua subterránea)', false),
  ('compraventa_certificada', 'Copia certificada del documento de compraventa', false),
  ('titulo_agua_vendedor', 'Copia del contrato o acto a nombre del vendedor', false),
  ('rif_gerente_calidad', 'RIF y cédula del gerente de calidad', false),
  ('manual_calidad', 'Manual de calidad', false),
  ('plan_calidad_producto', 'Plan de calidad del producto', false),
  ('catalogo_producto', 'Catálogo o fotos del producto', false),
  ('certificado_uso_sanitario', 'Certificado de uso del inmueble, o de Ingeniería Sanitaria si son alimentos', false),
  ('carta_solicitud_ente', 'Carta de solicitud al ente, con los datos que pide su instructivo', false),
  ('planilla_liquidacion_ente', 'Planilla de liquidación de derechos del ente', false),
  ('idoneidad_economica', 'Aprobación de idoneidad económica', false),
  ('estudio_economico', 'Estudio económico', false),
  ('dip_inac', 'Formulario de declaración de intención de pre-aplicación (DIP)', false),
  ('datos_operacion_aerea', 'Datos de la operación según el instructivo: rutas o zonas, aeronaves, base y mantenimiento', false),
  ('patente_arrendamiento', 'Patente de industria y comercio y contrato de arrendamiento', false),
  ('inspeccion_capitania', 'Inspección de la Capitanía de Puerto, con fotos', false),
  ('fianza_inea', 'Fianza notariada de 7.000 euros, con vencimiento a un año', false),
  ('sistema_calidad_iso', 'Informe y plan de sistema de calidad (ISO 9001:2015)', false),
  ('titulo_fletamento', 'Título del buque o contrato de fletamento', false),
  ('opinion_seguridad_maritima', 'Opinión técnica de seguridad marítima', false),
  ('numero_patronal_ivss', 'Número patronal del IVSS', false),
  ('solvencia_islr', 'Solvencia del ISLR', false),
  ('carta_rutas_cps', 'Carta con rutas, horarios y unidades', false),
  ('documento_objeto_transporte', 'Documento registrado con objeto de transporte público', false),
  ('registro_sunacoop', 'Registro de SUNACOOP (cooperativas)', false),
  ('certificado_vehiculo', 'Certificado de registro de cada vehículo', false),
  ('poliza_rcv', 'Póliza RCV de cada vehículo', false),
  ('informe_seguridad_vehiculo', 'Informe o constancia de seguridad, higiene y confort', false),
  ('fotos_vehiculos', 'Fotos de los vehículos', false),
  ('aval_terminal', 'Aval del terminal, la alcaldía o el instituto municipal', false),
  ('ultimo_dt', 'Último DT', false),
  ('rotc_vigente', 'ROTC vigente del vehículo transportador', false),
  ('revision_vehiculo', 'Formato de revisión del vehículo', false),
  ('estudio_ruta', 'Estudio especial de ruta hecho por una empresa de ingenieros', false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;

-- 2. Los seis trámites, encendidos, en la fase 3 con los demás sectoriales.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('permisos_agua',         'c63', 'Permisos de agua',                             'MINAGUAS', 3, true),
  ('agua_en_proceso',       'c64', 'Permiso de agua ya solicitado',                'MINAGUAS', 3, true),
  ('permisos_industria',    'c65', 'Permisos de industria y comercio',             'MPPICN',   3, true),
  ('industria_en_proceso',  'c66', 'Permiso de industria y comercio ya solicitado', 'MPPICN',  3, true),
  ('permisos_transporte',   'c67', 'Permisos de transporte',                       'MPPT',     3, true),
  ('transporte_en_proceso', 'c68', 'Permiso de transporte ya solicitado',          'MPPT',     3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite  = case codigo when 'permisos_agua'      then 'permiso_agua'
                            when 'permisos_industria' then 'permiso_industria'
                            else 'permiso_transporte' end,
       nivel  = 'actividad',
       fase   = 3,
       activo = true
 where codigo in ('permisos_agua', 'permisos_industria', 'permisos_transporte');

update public.tipos_tramite
   set emite      = null,
       plazo_dias = null,
       nivel      = 'actividad',
       fase       = 3,
       activo     = true
 where codigo in ('agua_en_proceso', 'industria_en_proceso', 'transporte_en_proceso');

-- 3. La marca del paso 1: la confirma_paso de supabase-hidrocarburos-pesca-energia.sql con tres llaves más.
create or replace function public.confirma_paso(p_tramite uuid, p_clave text)
returns public.tramites
language plpgsql
security definer
set search_path = public
as $$
declare
  fila public.tramites;
begin
  if p_clave not in ('cancilleria_confirmada',
                     'ente_banavih', 'ente_inces', 'ente_ivss', 'ente_ivss_confirma',
                     'ente_ivss_oficina', 'ente_mpppst', 'ente_sundde', 'ente_snc',
                     'licencia_solicitada', 'conformidad_solicitada', 'minero_solicitado',
                     'bomberos_solicitado', 'saime_confirmada', 'locti_inscrito',
                     'sacs_registrado', 'rtn_solicitado', 'ambiental_solicitado',
                     'agricola_solicitado', 'rnc_solicitado',
                     'hidrocarburos_solicitado', 'pesca_solicitado', 'energia_solicitado',
                     'agua_solicitado', 'industria_solicitado', 'transporte_solicitado') then
    raise exception 'paso desconocido: %', p_clave;
  end if;

  update public.tramites
     set datos = coalesce(datos, '{}'::jsonb)
                 || jsonb_build_object(p_clave, to_char(now(), 'YYYY-MM-DD"T"HH24:MI:SSOF'))
   where id = p_tramite
     and inversionista = auth.uid()
     and estado not in ('borrador', 'resuelto', 'cancelado')
  returning * into fila;

  if fila.id is null then
    raise exception 'no se pudo marcar el paso';
  end if;

  return fila;
end $$;

revoke all on function public.confirma_paso(uuid, text) from public;
revoke execute on function public.confirma_paso(uuid, text) from anon;
grant execute on function public.confirma_paso(uuid, text) to authenticated;

-- 4. Sus motivos en las estadísticas: la estadisticas_control de ese mismo archivo con los tres «ya solicité» nuevos.
create or replace function public.estadisticas_control()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r jsonb;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve las estadísticas' using errcode = '42501';
  end if;

  with enviados as (
    select t.id, t.tipo, coalesce(tt.ente, '') as ente, t.estado,
           t.datos, t.inversionista,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
  -- Cada resuelto con sus dos tramos (15-10-2026): el del CIIP, de que el inversionista
  -- envía a la primera vez que se presenta ante el ente, y el del ente, de ahí a resuelto.
  -- Sin presentación (lo resolvió el CIIP sin pasar por el ente) todo el tiempo es del CIIP
  -- y el ente no cuenta. Una presentación de antes del envío o de después de resolver no es
  -- de este caso.
  presentados as (
    select e.*,
           (select min(ev.creado_en)
              from public.tramite_eventos ev
             where ev.tramite = e.id and ev.a_estado = 'ante_el_ente'
               and ev.creado_en >= e.desde and ev.creado_en <= e.resuelto_en) as presentado
      from enviados e
     where e.estado = 'resuelto'
       and e.resuelto_en is not null
       and e.resuelto_en >= e.desde
  ),
  resueltos as (
    select p.id, p.tipo, p.ente, p.inversionista, p.desde, p.presentado, p.resuelto_en,
           p.datos ->> 'razon_social' as empresa,
           extract(epoch from (p.resuelto_en - p.desde)) / 3600.0 as horas,
           extract(epoch from (coalesce(p.presentado, p.resuelto_en) - p.desde)) / 3600.0 as horas_ciip,
           extract(epoch from (p.resuelto_en - p.presentado)) / 3600.0 as horas_ente
      from presentados p
  ),
  por_tipo as (
    select tipo, max(ente) as ente, count(*) as solicitados
      from enviados
     group by tipo
  ),
  tiempo_tipo as (
    select tipo,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by tipo
  ),
  tiempo_ente as (
    select ente,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by ente
  ),
  -- PASO A PASO (15-10-2026): el historial de cada resuelto, cortado en tramos. Cada cambio
  -- de estado abre un tramo que dura hasta el cambio siguiente, o hasta resolverse. «abrio»
  -- es quien lo puso en ese estado y «cerro», quien lo sacó. El tramo de 'resuelto' no
  -- dura nada y no se cuenta, ni lo de antes del envío (el borrador).
  tramos as (
    select r.id, r.tipo, ev.id as ev, ev.a_estado as estado, ev.creado_en as desde_paso,
           coalesce(lead(ev.creado_en) over w, r.resuelto_en) as hasta_paso,
           lead(ev.autor) over w as cerro
      from resueltos r
      join public.tramite_eventos ev on ev.tramite = r.id
     where ev.creado_en >= r.desde - interval '1 second'
       and ev.creado_en <= r.resuelto_en
    window w as (partition by r.id order by ev.creado_en, ev.id)
  ),
  pasos as (
    select t.*, extract(epoch from (t.hasta_paso - t.desde_paso)) / 3600.0 as horas
      from tramos t
     where t.estado in ('enviado', 'en_revision', 'devuelto', 'ante_el_ente')
  ),
  -- Lo de cada caso en cada estado, sumado: una devuelta que vuelve a revisión pasa dos
  -- veces por 'en_revision'.
  paso_caso as (
    select id, tipo, estado, sum(horas) as horas, count(*) as veces
      from pasos
     group by id, tipo, estado
  ),
  paso_tipo as (
    select tipo, estado,
           count(*) as n,
           sum(veces) as veces,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo
      from paso_caso
     group by tipo, estado
  ),
  -- Lo mismo para todos los resueltos juntos: las tres cifras de arriba de la ficha.
  tiempo_total as (
    select
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
  ),
  -- Y los casos uno por uno, los más recientes primero, con el mismo tope que motivos_casos.
  ultimos_resueltos as (
    select r.*, coalesce(pf.nombre_completo, '') as quien
      from resueltos r
      left join public.perfiles pf on pf.id = r.inversionista
     order by r.resuelto_en desc, r.id
     limit 500
  ),
  por_sector as (
    select sector, count(*) as n
      from public.consultas
     where sector is not null
     group by sector
  ),
  -- El trámite específico de cada sector (9-10-2026). Se agrupa sin mirar mayúsculas ni
  -- espacios de los lados, para que «Licencia ambiental» y «licencia ambiental » cuenten
  -- juntas; se enseña el nombre tal como lo escribió la mayoría.
  por_tramite_sector as (
    select c.sector, lower(trim(c.tramite_sector)) as clave,
           mode() within group (order by trim(c.tramite_sector)) as tramite,
           count(*) as n
      from public.consultas c
     where c.sector is not null
       and coalesce(trim(c.tramite_sector), '') <> ''
     group by c.sector, lower(trim(c.tramite_sector))
  ),
  -- Los motivos de «ya lo solicité» (6-10-2026): por qué pide ayuda el inversionista, ente por
  -- ente. En c45 a c47 y en el SACS ya solicitado (c49) hay un solo ente, el del catálogo, y un
  -- motivo_ya; y desde el 2-11-2026 (Franklin Reyes) también en los permisos ya solicitados ante el
  -- MINEC (c53) y ante el INSAI o el INTI (c54); en c44, uno por cada ente marcado, motivo_ya_<ente>. Se guardan en español
  -- (opcionesClave), así que se agrupan igual los haya escrito quien sea en el idioma que sea.
  -- Desde el 9-10-2026 cada caso lleva también su detalle (detalle_ya, detalle_ya_<ente>), la
  -- solicitud, quién y cuándo: de aquí salen a la vez las cifras y el registro de casos.
  casos as (
    select m.*
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente,
               e.datos ->> 'detalle_ya' as detalle,
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social' as empresa
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso', 'ambiental_en_proceso', 'agricola_en_proceso',
                          'minero_en_proceso', 'turistico_en_proceso',
                          'hidrocarburos_en_proceso', 'pesca_en_proceso', 'energia_en_proceso',
                          'agua_en_proceso', 'industria_en_proceso', 'transporte_en_proceso')
        union all
        select e.datos ->> ('motivo_ya_' || x.clave), x.ente,
               e.datos ->> ('detalle_ya_' || x.clave),
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social'
          from enviados e
         cross join (values ('banavih', 'BANAVIH (FAOV)'), ('inces', 'INCES'),
                            ('rupdae', 'RUPDAE'), ('ivss', 'IVSS'),
                            ('rnet', 'RNET'), ('rnc', 'RNC')) as x(clave, ente)
         where e.tipo = 'parafiscales_en_proceso'
      ) m
     where coalesce(m.motivo, '') <> ''
  ),
  motivos as (
    select motivo, ente, count(*) as n
      from casos
     group by motivo, ente
  ),
  ultimos_casos as (
    select ca.*, coalesce(p.nombre_completo, '') as quien
      from casos ca
      left join public.perfiles p on p.id = ca.inversionista
     order by ca.desde desc, ca.id, ca.ente
     limit 500
  )
  select jsonb_build_object(
    'tramites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', p.tipo, 'ente', p.ente, 'solicitados', p.solicitados,
               'resueltos', coalesce(x.n, 0),
               'mediana_h', round(x.mediana::numeric, 1),
               'promedio_h', round(x.promedio::numeric, 1),
               'maximo_h', round(x.maximo::numeric, 1),
               'mediana_ciip_h', round(x.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(x.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(x.maximo_ciip::numeric, 1),
               'n_ente', coalesce(x.n_ente, 0),
               'mediana_ente_h', round(x.mediana_ente::numeric, 1),
               'promedio_ente_h', round(x.promedio_ente::numeric, 1),
               'maximo_ente_h', round(x.maximo_ente::numeric, 1))
             order by p.solicitados desc, p.tipo)
        from por_tipo p
        left join tiempo_tipo x on x.tipo = p.tipo), '[]'::jsonb),
    'entes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ente', y.ente, 'resueltos', y.n,
               'mediana_h', round(y.mediana::numeric, 1),
               'promedio_h', round(y.promedio::numeric, 1),
               'maximo_h', round(y.maximo::numeric, 1),
               'mediana_ciip_h', round(y.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(y.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(y.maximo_ciip::numeric, 1),
               'n_ente', y.n_ente,
               'mediana_ente_h', round(y.mediana_ente::numeric, 1),
               'promedio_ente_h', round(y.promedio_ente::numeric, 1),
               'maximo_ente_h', round(y.maximo_ente::numeric, 1))
             order by y.n desc, y.ente)
        from tiempo_ente y), '[]'::jsonb),
    'tiempo_total', (
      select jsonb_build_object('resueltos', z.n,
               'mediana_h', round(z.mediana::numeric, 1),
               'promedio_h', round(z.promedio::numeric, 1),
               'maximo_h', round(z.maximo::numeric, 1),
               'mediana_ciip_h', round(z.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(z.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(z.maximo_ciip::numeric, 1),
               'n_ente', z.n_ente,
               'mediana_ente_h', round(z.mediana_ente::numeric, 1),
               'promedio_ente_h', round(z.promedio_ente::numeric, 1),
               'maximo_ente_h', round(z.maximo_ente::numeric, 1))
        from tiempo_total z),
    'pasos_tipo', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', pt.tipo, 'estado', pt.estado, 'casos', pt.n, 'veces', pt.veces,
               'mediana_h', round(pt.mediana::numeric, 1),
               'promedio_h', round(pt.promedio::numeric, 1),
               'maximo_h', round(pt.maximo::numeric, 1))
             order by pt.tipo, pt.estado)
        from paso_tipo pt), '[]'::jsonb),
    'tiempos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tramite', ur.id, 'tipo', ur.tipo, 'ente', ur.ente,
               'inversionista', ur.quien, 'empresa', coalesce(ur.empresa, ''),
               'enviado', ur.desde, 'presentado', ur.presentado, 'resuelto', ur.resuelto_en,
               'horas', round(ur.horas::numeric, 1),
               'horas_ciip', round(ur.horas_ciip::numeric, 1),
               'horas_ente', round(ur.horas_ente::numeric, 1),
               'pasos', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'estado', pa.estado, 'desde', pa.desde_paso, 'hasta', pa.hasta_paso,
                          'horas', round(pa.horas::numeric, 1),
                          'quien', coalesce(pc.nombre_completo, ''))
                        order by pa.desde_paso, pa.ev)
                   from pasos pa
                   left join public.perfiles pc on pc.id = pa.cerro
                  where pa.id = ur.id), '[]'::jsonb))
             order by ur.resuelto_en desc, ur.id)
        from ultimos_resueltos ur), '[]'::jsonb),
    'sectores', coalesce((
      select jsonb_agg(jsonb_build_object('sector', s.sector, 'consultas', s.n)
             order by s.n desc, s.sector)
        from por_sector s), '[]'::jsonb),
    'tramites_sector', coalesce((
      select jsonb_agg(jsonb_build_object('sector', ts.sector, 'tramite', ts.tramite, 'n', ts.n)
             order by ts.sector, ts.n desc, ts.tramite)
        from por_tramite_sector ts), '[]'::jsonb),
    'motivos', coalesce((
      select jsonb_agg(jsonb_build_object('motivo', mo.motivo, 'ente', mo.ente, 'n', mo.n)
             order by mo.n desc, mo.motivo, mo.ente)
        from motivos mo), '[]'::jsonb),
    'motivos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'motivo', uc.motivo, 'ente', uc.ente, 'detalle', coalesce(uc.detalle, ''),
               'tramite', uc.id, 'tipo', uc.tipo, 'inversionista', uc.quien,
               'empresa', coalesce(uc.empresa, ''), 'fecha', uc.desde)
             order by uc.desde desc, uc.id, uc.ente)
        from ultimos_casos uc), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;

-- ====================================================================
--  102 / 105   supabase-rnc-ya-solicitado.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL RNC YA SOLICITADO (c69)
--  Va DESPUÉS de supabase-agua-industria-transporte.sql: redefine su
--  estadisticas_control con un motivo más. Se puede correr más de una vez.
--  Franklin Reyes, 4 de noviembre de 2026 (maquetas/rnc-tarjetas.html).
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. El trámite, encendido, en la fase 3 con el RNC.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('rnc_en_proceso', 'c69', 'RNC ya solicitado', 'RNC', 3, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite      = null,
       plazo_dias = null,
       nivel      = 'actividad',
       fase       = 3,
       activo     = true
 where codigo = 'rnc_en_proceso';

-- 2. Su motivo en las estadísticas: la estadisticas_control de supabase-agua-industria-transporte.sql con uno más.
create or replace function public.estadisticas_control()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r jsonb;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve las estadísticas' using errcode = '42501';
  end if;

  with enviados as (
    select t.id, t.tipo, coalesce(tt.ente, '') as ente, t.estado,
           t.datos, t.inversionista,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
  -- Cada resuelto con sus dos tramos (15-10-2026): el del CIIP, de que el inversionista
  -- envía a la primera vez que se presenta ante el ente, y el del ente, de ahí a resuelto.
  -- Sin presentación (lo resolvió el CIIP sin pasar por el ente) todo el tiempo es del CIIP
  -- y el ente no cuenta. Una presentación de antes del envío o de después de resolver no es
  -- de este caso.
  presentados as (
    select e.*,
           (select min(ev.creado_en)
              from public.tramite_eventos ev
             where ev.tramite = e.id and ev.a_estado = 'ante_el_ente'
               and ev.creado_en >= e.desde and ev.creado_en <= e.resuelto_en) as presentado
      from enviados e
     where e.estado = 'resuelto'
       and e.resuelto_en is not null
       and e.resuelto_en >= e.desde
  ),
  resueltos as (
    select p.id, p.tipo, p.ente, p.inversionista, p.desde, p.presentado, p.resuelto_en,
           p.datos ->> 'razon_social' as empresa,
           extract(epoch from (p.resuelto_en - p.desde)) / 3600.0 as horas,
           extract(epoch from (coalesce(p.presentado, p.resuelto_en) - p.desde)) / 3600.0 as horas_ciip,
           extract(epoch from (p.resuelto_en - p.presentado)) / 3600.0 as horas_ente
      from presentados p
  ),
  por_tipo as (
    select tipo, max(ente) as ente, count(*) as solicitados
      from enviados
     group by tipo
  ),
  tiempo_tipo as (
    select tipo,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by tipo
  ),
  tiempo_ente as (
    select ente,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by ente
  ),
  -- PASO A PASO (15-10-2026): el historial de cada resuelto, cortado en tramos. Cada cambio
  -- de estado abre un tramo que dura hasta el cambio siguiente, o hasta resolverse. «abrio»
  -- es quien lo puso en ese estado y «cerro», quien lo sacó. El tramo de 'resuelto' no
  -- dura nada y no se cuenta, ni lo de antes del envío (el borrador).
  tramos as (
    select r.id, r.tipo, ev.id as ev, ev.a_estado as estado, ev.creado_en as desde_paso,
           coalesce(lead(ev.creado_en) over w, r.resuelto_en) as hasta_paso,
           lead(ev.autor) over w as cerro
      from resueltos r
      join public.tramite_eventos ev on ev.tramite = r.id
     where ev.creado_en >= r.desde - interval '1 second'
       and ev.creado_en <= r.resuelto_en
    window w as (partition by r.id order by ev.creado_en, ev.id)
  ),
  pasos as (
    select t.*, extract(epoch from (t.hasta_paso - t.desde_paso)) / 3600.0 as horas
      from tramos t
     where t.estado in ('enviado', 'en_revision', 'devuelto', 'ante_el_ente')
  ),
  -- Lo de cada caso en cada estado, sumado: una devuelta que vuelve a revisión pasa dos
  -- veces por 'en_revision'.
  paso_caso as (
    select id, tipo, estado, sum(horas) as horas, count(*) as veces
      from pasos
     group by id, tipo, estado
  ),
  paso_tipo as (
    select tipo, estado,
           count(*) as n,
           sum(veces) as veces,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo
      from paso_caso
     group by tipo, estado
  ),
  -- Lo mismo para todos los resueltos juntos: las tres cifras de arriba de la ficha.
  tiempo_total as (
    select
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
  ),
  -- Y los casos uno por uno, los más recientes primero, con el mismo tope que motivos_casos.
  ultimos_resueltos as (
    select r.*, coalesce(pf.nombre_completo, '') as quien
      from resueltos r
      left join public.perfiles pf on pf.id = r.inversionista
     order by r.resuelto_en desc, r.id
     limit 500
  ),
  por_sector as (
    select sector, count(*) as n
      from public.consultas
     where sector is not null
     group by sector
  ),
  -- El trámite específico de cada sector (9-10-2026). Se agrupa sin mirar mayúsculas ni
  -- espacios de los lados, para que «Licencia ambiental» y «licencia ambiental » cuenten
  -- juntas; se enseña el nombre tal como lo escribió la mayoría.
  por_tramite_sector as (
    select c.sector, lower(trim(c.tramite_sector)) as clave,
           mode() within group (order by trim(c.tramite_sector)) as tramite,
           count(*) as n
      from public.consultas c
     where c.sector is not null
       and coalesce(trim(c.tramite_sector), '') <> ''
     group by c.sector, lower(trim(c.tramite_sector))
  ),
  -- Los motivos de «ya lo solicité» (6-10-2026): por qué pide ayuda el inversionista, ente por
  -- ente. En c45 a c47 y en el SACS ya solicitado (c49) hay un solo ente, el del catálogo, y un
  -- motivo_ya; y desde el 2-11-2026 (Franklin Reyes) también en los permisos ya solicitados ante el
  -- MINEC (c53) y ante el INSAI o el INTI (c54); en c44, uno por cada ente marcado, motivo_ya_<ente>. Se guardan en español
  -- (opcionesClave), así que se agrupan igual los haya escrito quien sea en el idioma que sea.
  -- Desde el 9-10-2026 cada caso lleva también su detalle (detalle_ya, detalle_ya_<ente>), la
  -- solicitud, quién y cuándo: de aquí salen a la vez las cifras y el registro de casos.
  casos as (
    select m.*
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente,
               e.datos ->> 'detalle_ya' as detalle,
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social' as empresa
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso', 'ambiental_en_proceso', 'agricola_en_proceso',
                          'minero_en_proceso', 'turistico_en_proceso',
                          'hidrocarburos_en_proceso', 'pesca_en_proceso', 'energia_en_proceso',
                          'agua_en_proceso', 'industria_en_proceso', 'transporte_en_proceso',
                          'rnc_en_proceso')
        union all
        select e.datos ->> ('motivo_ya_' || x.clave), x.ente,
               e.datos ->> ('detalle_ya_' || x.clave),
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social'
          from enviados e
         cross join (values ('banavih', 'BANAVIH (FAOV)'), ('inces', 'INCES'),
                            ('rupdae', 'RUPDAE'), ('ivss', 'IVSS'),
                            ('rnet', 'RNET'), ('rnc', 'RNC')) as x(clave, ente)
         where e.tipo = 'parafiscales_en_proceso'
      ) m
     where coalesce(m.motivo, '') <> ''
  ),
  motivos as (
    select motivo, ente, count(*) as n
      from casos
     group by motivo, ente
  ),
  ultimos_casos as (
    select ca.*, coalesce(p.nombre_completo, '') as quien
      from casos ca
      left join public.perfiles p on p.id = ca.inversionista
     order by ca.desde desc, ca.id, ca.ente
     limit 500
  )
  select jsonb_build_object(
    'tramites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', p.tipo, 'ente', p.ente, 'solicitados', p.solicitados,
               'resueltos', coalesce(x.n, 0),
               'mediana_h', round(x.mediana::numeric, 1),
               'promedio_h', round(x.promedio::numeric, 1),
               'maximo_h', round(x.maximo::numeric, 1),
               'mediana_ciip_h', round(x.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(x.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(x.maximo_ciip::numeric, 1),
               'n_ente', coalesce(x.n_ente, 0),
               'mediana_ente_h', round(x.mediana_ente::numeric, 1),
               'promedio_ente_h', round(x.promedio_ente::numeric, 1),
               'maximo_ente_h', round(x.maximo_ente::numeric, 1))
             order by p.solicitados desc, p.tipo)
        from por_tipo p
        left join tiempo_tipo x on x.tipo = p.tipo), '[]'::jsonb),
    'entes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ente', y.ente, 'resueltos', y.n,
               'mediana_h', round(y.mediana::numeric, 1),
               'promedio_h', round(y.promedio::numeric, 1),
               'maximo_h', round(y.maximo::numeric, 1),
               'mediana_ciip_h', round(y.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(y.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(y.maximo_ciip::numeric, 1),
               'n_ente', y.n_ente,
               'mediana_ente_h', round(y.mediana_ente::numeric, 1),
               'promedio_ente_h', round(y.promedio_ente::numeric, 1),
               'maximo_ente_h', round(y.maximo_ente::numeric, 1))
             order by y.n desc, y.ente)
        from tiempo_ente y), '[]'::jsonb),
    'tiempo_total', (
      select jsonb_build_object('resueltos', z.n,
               'mediana_h', round(z.mediana::numeric, 1),
               'promedio_h', round(z.promedio::numeric, 1),
               'maximo_h', round(z.maximo::numeric, 1),
               'mediana_ciip_h', round(z.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(z.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(z.maximo_ciip::numeric, 1),
               'n_ente', z.n_ente,
               'mediana_ente_h', round(z.mediana_ente::numeric, 1),
               'promedio_ente_h', round(z.promedio_ente::numeric, 1),
               'maximo_ente_h', round(z.maximo_ente::numeric, 1))
        from tiempo_total z),
    'pasos_tipo', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', pt.tipo, 'estado', pt.estado, 'casos', pt.n, 'veces', pt.veces,
               'mediana_h', round(pt.mediana::numeric, 1),
               'promedio_h', round(pt.promedio::numeric, 1),
               'maximo_h', round(pt.maximo::numeric, 1))
             order by pt.tipo, pt.estado)
        from paso_tipo pt), '[]'::jsonb),
    'tiempos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tramite', ur.id, 'tipo', ur.tipo, 'ente', ur.ente,
               'inversionista', ur.quien, 'empresa', coalesce(ur.empresa, ''),
               'enviado', ur.desde, 'presentado', ur.presentado, 'resuelto', ur.resuelto_en,
               'horas', round(ur.horas::numeric, 1),
               'horas_ciip', round(ur.horas_ciip::numeric, 1),
               'horas_ente', round(ur.horas_ente::numeric, 1),
               'pasos', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'estado', pa.estado, 'desde', pa.desde_paso, 'hasta', pa.hasta_paso,
                          'horas', round(pa.horas::numeric, 1),
                          'quien', coalesce(pc.nombre_completo, ''))
                        order by pa.desde_paso, pa.ev)
                   from pasos pa
                   left join public.perfiles pc on pc.id = pa.cerro
                  where pa.id = ur.id), '[]'::jsonb))
             order by ur.resuelto_en desc, ur.id)
        from ultimos_resueltos ur), '[]'::jsonb),
    'sectores', coalesce((
      select jsonb_agg(jsonb_build_object('sector', s.sector, 'consultas', s.n)
             order by s.n desc, s.sector)
        from por_sector s), '[]'::jsonb),
    'tramites_sector', coalesce((
      select jsonb_agg(jsonb_build_object('sector', ts.sector, 'tramite', ts.tramite, 'n', ts.n)
             order by ts.sector, ts.n desc, ts.tramite)
        from por_tramite_sector ts), '[]'::jsonb),
    'motivos', coalesce((
      select jsonb_agg(jsonb_build_object('motivo', mo.motivo, 'ente', mo.ente, 'n', mo.n)
             order by mo.n desc, mo.motivo, mo.ente)
        from motivos mo), '[]'::jsonb),
    'motivos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'motivo', uc.motivo, 'ente', uc.ente, 'detalle', coalesce(uc.detalle, ''),
               'tramite', uc.id, 'tipo', uc.tipo, 'inversionista', uc.quien,
               'empresa', coalesce(uc.empresa, ''), 'fecha', uc.desde)
             order by uc.desde desc, uc.id, uc.ente)
        from ultimos_casos uc), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;

-- ====================================================================
--  103 / 105   supabase-visa-cedula-rif.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — VISA, CÉDULA Y RIF YA SOLICITADOS (c70 a c72)
--  Va DESPUÉS de supabase-rnc-ya-solicitado.sql: redefine su
--  estadisticas_control con tres motivos más. Se puede correr más de una vez.
--  Franklin Reyes, 4 de noviembre de 2026 (maquetas/visa-cedula-rif.html).
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Los tres trámites, encendidos, en la fase 1.
insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('visa_en_proceso',   'c70', 'Visa ya solicitada',   'MPPRE',  1, true),
  ('cedula_en_proceso', 'c71', 'Cédula ya solicitada', 'SAIME',  1, true),
  ('rif_en_proceso',    'c72', 'RIF ya solicitado',    'SENIAT', 1, true)
on conflict (codigo) do nothing;

update public.tipos_tramite
   set emite      = null,
       plazo_dias = null,
       nivel      = 'actividad',
       fase       = 1,
       activo     = true
 where codigo in ('visa_en_proceso', 'cedula_en_proceso', 'rif_en_proceso');

-- 2. Sus motivos en las estadísticas: la estadisticas_control de supabase-rnc-ya-solicitado.sql con tres más.
create or replace function public.estadisticas_control()
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  r jsonb;
begin
  if not public.es_admin() then
    raise exception 'Solo un administrador ve las estadísticas' using errcode = '42501';
  end if;

  with enviados as (
    select t.id, t.tipo, coalesce(tt.ente, '') as ente, t.estado,
           t.datos, t.inversionista,
           coalesce(t.enviado_en, t.creado_en) as desde, t.resuelto_en
      from public.tramites t
      left join public.tipos_tramite tt on tt.codigo = t.tipo
     where t.enviado_en is not null
        or t.estado not in ('borrador', 'cancelado')
  ),
  -- Cada resuelto con sus dos tramos (15-10-2026): el del CIIP, de que el inversionista
  -- envía a la primera vez que se presenta ante el ente, y el del ente, de ahí a resuelto.
  -- Sin presentación (lo resolvió el CIIP sin pasar por el ente) todo el tiempo es del CIIP
  -- y el ente no cuenta. Una presentación de antes del envío o de después de resolver no es
  -- de este caso.
  presentados as (
    select e.*,
           (select min(ev.creado_en)
              from public.tramite_eventos ev
             where ev.tramite = e.id and ev.a_estado = 'ante_el_ente'
               and ev.creado_en >= e.desde and ev.creado_en <= e.resuelto_en) as presentado
      from enviados e
     where e.estado = 'resuelto'
       and e.resuelto_en is not null
       and e.resuelto_en >= e.desde
  ),
  resueltos as (
    select p.id, p.tipo, p.ente, p.inversionista, p.desde, p.presentado, p.resuelto_en,
           p.datos ->> 'razon_social' as empresa,
           extract(epoch from (p.resuelto_en - p.desde)) / 3600.0 as horas,
           extract(epoch from (coalesce(p.presentado, p.resuelto_en) - p.desde)) / 3600.0 as horas_ciip,
           extract(epoch from (p.resuelto_en - p.presentado)) / 3600.0 as horas_ente
      from presentados p
  ),
  por_tipo as (
    select tipo, max(ente) as ente, count(*) as solicitados
      from enviados
     group by tipo
  ),
  tiempo_tipo as (
    select tipo,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by tipo
  ),
  tiempo_ente as (
    select ente,
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
     group by ente
  ),
  -- PASO A PASO (15-10-2026): el historial de cada resuelto, cortado en tramos. Cada cambio
  -- de estado abre un tramo que dura hasta el cambio siguiente, o hasta resolverse. «abrio»
  -- es quien lo puso en ese estado y «cerro», quien lo sacó. El tramo de 'resuelto' no
  -- dura nada y no se cuenta, ni lo de antes del envío (el borrador).
  tramos as (
    select r.id, r.tipo, ev.id as ev, ev.a_estado as estado, ev.creado_en as desde_paso,
           coalesce(lead(ev.creado_en) over w, r.resuelto_en) as hasta_paso,
           lead(ev.autor) over w as cerro
      from resueltos r
      join public.tramite_eventos ev on ev.tramite = r.id
     where ev.creado_en >= r.desde - interval '1 second'
       and ev.creado_en <= r.resuelto_en
    window w as (partition by r.id order by ev.creado_en, ev.id)
  ),
  pasos as (
    select t.*, extract(epoch from (t.hasta_paso - t.desde_paso)) / 3600.0 as horas
      from tramos t
     where t.estado in ('enviado', 'en_revision', 'devuelto', 'ante_el_ente')
  ),
  -- Lo de cada caso en cada estado, sumado: una devuelta que vuelve a revisión pasa dos
  -- veces por 'en_revision'.
  paso_caso as (
    select id, tipo, estado, sum(horas) as horas, count(*) as veces
      from pasos
     group by id, tipo, estado
  ),
  paso_tipo as (
    select tipo, estado,
           count(*) as n,
           sum(veces) as veces,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo
      from paso_caso
     group by tipo, estado
  ),
  -- Lo mismo para todos los resueltos juntos: las tres cifras de arriba de la ficha.
  tiempo_total as (
    select
           count(*) as n,
           percentile_cont(0.5) within group (order by horas) as mediana,
           avg(horas) as promedio,
           max(horas) as maximo,
           percentile_cont(0.5) within group (order by horas_ciip) as mediana_ciip,
           avg(horas_ciip) as promedio_ciip,
           max(horas_ciip) as maximo_ciip,
           count(horas_ente) as n_ente,
           percentile_cont(0.5) within group (order by horas_ente) as mediana_ente,
           avg(horas_ente) as promedio_ente,
           max(horas_ente) as maximo_ente
      from resueltos
  ),
  -- Y los casos uno por uno, los más recientes primero, con el mismo tope que motivos_casos.
  ultimos_resueltos as (
    select r.*, coalesce(pf.nombre_completo, '') as quien
      from resueltos r
      left join public.perfiles pf on pf.id = r.inversionista
     order by r.resuelto_en desc, r.id
     limit 500
  ),
  por_sector as (
    select sector, count(*) as n
      from public.consultas
     where sector is not null
     group by sector
  ),
  -- El trámite específico de cada sector (9-10-2026). Se agrupa sin mirar mayúsculas ni
  -- espacios de los lados, para que «Licencia ambiental» y «licencia ambiental » cuenten
  -- juntas; se enseña el nombre tal como lo escribió la mayoría.
  por_tramite_sector as (
    select c.sector, lower(trim(c.tramite_sector)) as clave,
           mode() within group (order by trim(c.tramite_sector)) as tramite,
           count(*) as n
      from public.consultas c
     where c.sector is not null
       and coalesce(trim(c.tramite_sector), '') <> ''
     group by c.sector, lower(trim(c.tramite_sector))
  ),
  -- Los motivos de «ya lo solicité» (6-10-2026): por qué pide ayuda el inversionista, ente por
  -- ente. En c45 a c47 y en el SACS ya solicitado (c49) hay un solo ente, el del catálogo, y un
  -- motivo_ya; y desde el 2-11-2026 (Franklin Reyes) también en los permisos ya solicitados ante el
  -- MINEC (c53) y ante el INSAI o el INTI (c54); en c44, uno por cada ente marcado, motivo_ya_<ente>. Se guardan en español
  -- (opcionesClave), así que se agrupan igual los haya escrito quien sea en el idioma que sea.
  -- Desde el 9-10-2026 cada caso lleva también su detalle (detalle_ya, detalle_ya_<ente>), la
  -- solicitud, quién y cuándo: de aquí salen a la vez las cifras y el registro de casos.
  casos as (
    select m.*
      from (
        select e.datos ->> 'motivo_ya' as motivo, e.ente,
               e.datos ->> 'detalle_ya' as detalle,
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social' as empresa
          from enviados e
         where e.tipo in ('licencia_en_proceso', 'conformidad_en_proceso', 'bomberos_en_proceso',
                          'sacs_en_proceso', 'ambiental_en_proceso', 'agricola_en_proceso',
                          'minero_en_proceso', 'turistico_en_proceso',
                          'hidrocarburos_en_proceso', 'pesca_en_proceso', 'energia_en_proceso',
                          'agua_en_proceso', 'industria_en_proceso', 'transporte_en_proceso',
                          'rnc_en_proceso',
                          'visa_en_proceso', 'cedula_en_proceso', 'rif_en_proceso')
        union all
        select e.datos ->> ('motivo_ya_' || x.clave), x.ente,
               e.datos ->> ('detalle_ya_' || x.clave),
               e.id, e.tipo, e.inversionista, e.desde, e.datos ->> 'razon_social'
          from enviados e
         cross join (values ('banavih', 'BANAVIH (FAOV)'), ('inces', 'INCES'),
                            ('rupdae', 'RUPDAE'), ('ivss', 'IVSS'),
                            ('rnet', 'RNET'), ('rnc', 'RNC')) as x(clave, ente)
         where e.tipo = 'parafiscales_en_proceso'
      ) m
     where coalesce(m.motivo, '') <> ''
  ),
  motivos as (
    select motivo, ente, count(*) as n
      from casos
     group by motivo, ente
  ),
  ultimos_casos as (
    select ca.*, coalesce(p.nombre_completo, '') as quien
      from casos ca
      left join public.perfiles p on p.id = ca.inversionista
     order by ca.desde desc, ca.id, ca.ente
     limit 500
  )
  select jsonb_build_object(
    'tramites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', p.tipo, 'ente', p.ente, 'solicitados', p.solicitados,
               'resueltos', coalesce(x.n, 0),
               'mediana_h', round(x.mediana::numeric, 1),
               'promedio_h', round(x.promedio::numeric, 1),
               'maximo_h', round(x.maximo::numeric, 1),
               'mediana_ciip_h', round(x.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(x.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(x.maximo_ciip::numeric, 1),
               'n_ente', coalesce(x.n_ente, 0),
               'mediana_ente_h', round(x.mediana_ente::numeric, 1),
               'promedio_ente_h', round(x.promedio_ente::numeric, 1),
               'maximo_ente_h', round(x.maximo_ente::numeric, 1))
             order by p.solicitados desc, p.tipo)
        from por_tipo p
        left join tiempo_tipo x on x.tipo = p.tipo), '[]'::jsonb),
    'entes', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ente', y.ente, 'resueltos', y.n,
               'mediana_h', round(y.mediana::numeric, 1),
               'promedio_h', round(y.promedio::numeric, 1),
               'maximo_h', round(y.maximo::numeric, 1),
               'mediana_ciip_h', round(y.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(y.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(y.maximo_ciip::numeric, 1),
               'n_ente', y.n_ente,
               'mediana_ente_h', round(y.mediana_ente::numeric, 1),
               'promedio_ente_h', round(y.promedio_ente::numeric, 1),
               'maximo_ente_h', round(y.maximo_ente::numeric, 1))
             order by y.n desc, y.ente)
        from tiempo_ente y), '[]'::jsonb),
    'tiempo_total', (
      select jsonb_build_object('resueltos', z.n,
               'mediana_h', round(z.mediana::numeric, 1),
               'promedio_h', round(z.promedio::numeric, 1),
               'maximo_h', round(z.maximo::numeric, 1),
               'mediana_ciip_h', round(z.mediana_ciip::numeric, 1),
               'promedio_ciip_h', round(z.promedio_ciip::numeric, 1),
               'maximo_ciip_h', round(z.maximo_ciip::numeric, 1),
               'n_ente', z.n_ente,
               'mediana_ente_h', round(z.mediana_ente::numeric, 1),
               'promedio_ente_h', round(z.promedio_ente::numeric, 1),
               'maximo_ente_h', round(z.maximo_ente::numeric, 1))
        from tiempo_total z),
    'pasos_tipo', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tipo', pt.tipo, 'estado', pt.estado, 'casos', pt.n, 'veces', pt.veces,
               'mediana_h', round(pt.mediana::numeric, 1),
               'promedio_h', round(pt.promedio::numeric, 1),
               'maximo_h', round(pt.maximo::numeric, 1))
             order by pt.tipo, pt.estado)
        from paso_tipo pt), '[]'::jsonb),
    'tiempos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'tramite', ur.id, 'tipo', ur.tipo, 'ente', ur.ente,
               'inversionista', ur.quien, 'empresa', coalesce(ur.empresa, ''),
               'enviado', ur.desde, 'presentado', ur.presentado, 'resuelto', ur.resuelto_en,
               'horas', round(ur.horas::numeric, 1),
               'horas_ciip', round(ur.horas_ciip::numeric, 1),
               'horas_ente', round(ur.horas_ente::numeric, 1),
               'pasos', coalesce((
                 select jsonb_agg(jsonb_build_object(
                          'estado', pa.estado, 'desde', pa.desde_paso, 'hasta', pa.hasta_paso,
                          'horas', round(pa.horas::numeric, 1),
                          'quien', coalesce(pc.nombre_completo, ''))
                        order by pa.desde_paso, pa.ev)
                   from pasos pa
                   left join public.perfiles pc on pc.id = pa.cerro
                  where pa.id = ur.id), '[]'::jsonb))
             order by ur.resuelto_en desc, ur.id)
        from ultimos_resueltos ur), '[]'::jsonb),
    'sectores', coalesce((
      select jsonb_agg(jsonb_build_object('sector', s.sector, 'consultas', s.n)
             order by s.n desc, s.sector)
        from por_sector s), '[]'::jsonb),
    'tramites_sector', coalesce((
      select jsonb_agg(jsonb_build_object('sector', ts.sector, 'tramite', ts.tramite, 'n', ts.n)
             order by ts.sector, ts.n desc, ts.tramite)
        from por_tramite_sector ts), '[]'::jsonb),
    'motivos', coalesce((
      select jsonb_agg(jsonb_build_object('motivo', mo.motivo, 'ente', mo.ente, 'n', mo.n)
             order by mo.n desc, mo.motivo, mo.ente)
        from motivos mo), '[]'::jsonb),
    'motivos_casos', coalesce((
      select jsonb_agg(jsonb_build_object(
               'motivo', uc.motivo, 'ente', uc.ente, 'detalle', coalesce(uc.detalle, ''),
               'tramite', uc.id, 'tipo', uc.tipo, 'inversionista', uc.quien,
               'empresa', coalesce(uc.empresa, ''), 'fecha', uc.desde)
             order by uc.desde desc, uc.id, uc.ente)
        from ultimos_casos uc), '[]'::jsonb)
  ) into r;

  return r;
end;
$$;

revoke all on function public.estadisticas_control() from public, anon;
grant execute on function public.estadisticas_control() to authenticated;

-- ====================================================================
--  104 / 105   supabase-borrar-c35.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — BORRAR c35 «INSCRIPCIÓN EN EL RUPDAE»
--  Revisión de la etapa 3 (Valeria Ramos, CIIP, 4-11-2026): estaba apagada y
--  duplicada, porque el RUPDAE se pide en el c37. El c37 no usa esta fila: su
--  ente es 'sundde', en tramite_entes.
--  Solo se borra si nada la referencia. Si una solicitud, autorización, cita o
--  consulta la usa, se queda apagada: la consulta final dice 1 en ese caso.
--  Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════════

delete from public.tipos_tramite t
 where t.codigo = 'rupdae'
   and not exists (select 1 from public.tramites x where x.tipo = t.codigo)
   and not exists (select 1 from public.autorizaciones x where x.tipo = t.codigo)
   and not exists (select 1 from public.citas x where x.tipo_tramite = t.codigo)
   and not exists (select 1 from public.consultas x where x.tipo = t.codigo);
select count(*) as filas_de_c35_que_quedan from public.tipos_tramite where codigo = 'rupdae';

-- ====================================================================
--  105 / 105   supabase-transporte-sin-intt.sql
-- ====================================================================

-- ═══════════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — EL PERMISO DE TRANSPORTE, SIN EL INTT EN SU NOMBRE
--  Franklin Reyes, 5 de noviembre de 2026: «INTT ya no va en transporte, porque
--  pasó al Ministerio de Interiores, Justicia y Paz, hay que quitarlo de ahí».
--  La ficha c67/c68 se quedó con el INAC y el INEA, y este nombre es lo único de
--  ella que vive en la base: sale en los avisos y en la verificación del papel.
--  No borra nada: los tipos de los recaudos del INTT se quedan en tipos_documento,
--  porque quien los subió los sigue teniendo en su bóveda.
--  Va DESPUÉS de supabase-agua-industria-transporte.sql, que escribe el nombre
--  viejo. Se puede correr más de una vez.
-- ═══════════════════════════════════════════════════════════════════════════

update public.tipos_documento
   set nombre = 'Permiso, registro o certificación del INAC o del INEA'
 where codigo = 'permiso_transporte';
