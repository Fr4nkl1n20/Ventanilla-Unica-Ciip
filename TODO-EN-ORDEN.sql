-- ====================================================================
--  LOS 26 ARCHIVOS, EN EL ORDEN QUE PRUEBA PROBAR-SQL.bat
-- ====================================================================
--  Esto es la union literal de los 26 supabase-*.sql, sin cambiar una
--  coma, pegados en el orden que ejecuta el arnes contra un Postgres de
--  usar y tirar. Ese orden no esta deducido leyendo cabeceras: si uno
--  usara algo que otro define despues, la tanda se caeria diciendo cual.
--
--  Se pega ENTERO en el SQL Editor de Supabase y se pulsa Run una vez.
--  Todos son idempotentes -create if not exists, create or replace, drop
--  policy if exists-, asi que volver a correrlo no rompe nada y es la
--  forma de poner al dia un proyecto que ya tenia la mitad.
--
--  Generado el 2026-09-03. Si cambia un archivo, se vuelve a generar:
--  no se edita a mano, que entonces son 25 sitios donde mirar.
-- ====================================================================


-- ====================================================================
--  01 / 25   supabase-setup.sql
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
--  02 / 25   supabase-tramites.sql
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
--  03 / 25   supabase-admin.sql
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
  );
$$;


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
--  04 / 25   supabase-citas.sql
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
--  05 / 25   supabase-empresa.sql
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
--  06 / 25   supabase-activos.sql
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
--  07 / 25   supabase-identidad.sql
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
--  08 / 25   supabase-emision.sql
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
--  09 / 25   supabase-presencia.sql
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
--  10 / 25   supabase-sectores.sql
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
--  11 / 25   supabase-catalogos.sql
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
--  12 / 25   supabase-bitacora.sql
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
--  13 / 25   supabase-bloqueo.sql
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
--  14 / 25   supabase-acompanamiento.sql
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
--  15 / 25   supabase-gestor.sql
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
--  16 / 25   supabase-cola.sql
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
--  17 / 25   supabase-avisos.sql
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
--  18 / 25   supabase-aranceles.sql
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
--  19 / 25   supabase-huellas.sql
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
--  20 / 25   supabase-encadenado.sql
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
-- Siete, y ninguno inventado: cinco porque el código del trámite y el del
-- documento son EL MISMO o el nombre no admite otra lectura, y el del
-- acta porque lo dice el comentario del panel.
--
-- Se activan con UPDATE y no en el INSERT del catálogo, que lleva ON
-- CONFLICT DO NOTHING y en una base que ya existe no tocaría nada.

update public.tipos_tramite set emite = 'visa'               where codigo = 'visa_inversionista';
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
--  21 / 25   supabase-plazos.sql
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

-- ====================================================================
--  22 / 25   supabase-una-viva.sql
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
--  23 / 25   supabase-hilo.sql
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
--  24 / 25   supabase-hilo-citas.sql
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
--  25 / 25   supabase-informe-victor.sql
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

-- ====================================================================
--  26 / 25   supabase-pliego.sql
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
