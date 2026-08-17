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
  ('otro',              'Otro documento',                         false)
on conflict (codigo) do nothing;


-- ───────────────────────────────────────────────────────────────────────
-- 2. CATÁLOGO DE TIPOS DE TRÁMITE
-- ───────────────────────────────────────────────────────────────────────
-- ref_panel enlaza con los identificadores que ya usa el panel (c1…c15) y
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

  constraint tipos_tramite_fase_valida check (fase between 1 and 4)
);

comment on table  public.tipos_tramite        is 'Los quince trámites de la ventanilla';
comment on column public.tipos_tramite.ref_panel is 'Identificador que usa el panel y pasos.js (c1…c15)';
comment on column public.tipos_tramite.activo is 'false = solo se muestra; todavía no se puede solicitar de verdad';

insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
  ('visa_inversionista',  'c1',  'Visa de inversionista',            'SAIME',               1, false),
  ('cedula_residencia',   'c2',  'Cédula de residencia',             'SAIME',               1, false),
  ('rif_personal',        'c3',  'RIF personal',                     'SENIAT',              1, true ),
  ('licencia_conducir',   'c4',  'Homologación de licencia',         'INTT',                1, false),
  ('constitucion',        'c5',  'Constitución de empresa',          'SAREN',               2, false),
  ('rif_empresa',         'c6',  'RIF de la empresa',                'SENIAT',              2, false),
  ('cuenta_bancaria',     'c7',  'Cuenta bancaria corporativa',      'Banca aliada',        2, false),
  ('marca',               'c8',  'Registro de marca',                'SAPI',                2, false),
  ('registros_laborales', 'c9',  'Registros laborales',              'IVSS · INCES · FAOV', 3, false),
  ('licencia_municipal',  'c10', 'Licencia de funcionamiento',       'Alcaldía',            3, false),
  ('comercio_exterior',   'c11', 'Permisos de importación',          'VUCE',                3, false),
  ('registro_sanitario',  'c12', 'Registro sanitario',               'SENCAMER · INSAI',    3, false),
  ('rnc',                 'c13', 'Registro Nacional de Contratistas','RNC',                 4, false),
  ('solvencias',          'c14', 'Solvencias laborales y municipales','Entes varios',       4, false),
  ('banco_activos',       'c15', 'Banco de activos y oportunidades', 'CIIP',                4, false)
on conflict (codigo) do nothing;

-- Cuáles se pueden solicitar de verdad HOY.
--
-- Va aparte del INSERT de arriba y no dentro: aquel lleva ON CONFLICT DO
-- NOTHING, así que en una base donde el catálogo ya existe no toca nada y
-- activar un trámite nuevo no surtiría efecto por más veces que se corra.
-- Aquí se dice en positivo y en negativo, para que la lista de activos sea
-- exactamente esta y no se quede uno encendido de una prueba anterior.
update public.tipos_tramite set activo = true
  where codigo in ('rif_personal', 'rif_empresa');
update public.tipos_tramite set activo = false
  where codigo not in ('rif_personal', 'rif_empresa');


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

comment on table  public.tramites        is 'Una solicitud concreta de un inversionista';
comment on column public.tramites.datos  is 'Campos del formulario, distintos por tipo. Para rif_personal: numero_documento, tipo_documento, fecha_nacimiento, direccion_fiscal, telefono, profesion';
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

-- --- catálogos: los lee cualquiera que haya entrado, nadie los escribe ---
drop policy if exists "tipos_documento: leer" on public.tipos_documento;
create policy "tipos_documento: leer" on public.tipos_documento
  for select to authenticated using (true);

drop policy if exists "tipos_tramite: leer" on public.tipos_tramite;
create policy "tipos_tramite: leer" on public.tipos_tramite
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
-- 1) RLS activo en las seis tablas. Las seis deben salir con true:
--
--   select relname, relrowsecurity
--   from pg_class
--   where relname in ('documentos','tramites','tramite_documentos',
--                     'tramite_eventos','tipos_documento','tipos_tramite');
--
-- 2) Solo rif_personal debe poder recibir solicitudes por ahora:
--
--   select codigo, activo from public.tipos_tramite order by ref_panel;
--
-- 3) Prueba del aislamiento, que es lo único que de verdad importa.
--    Entra en la aplicación con DOS cuentas distintas y comprueba que la
--    segunda no ve ni un documento ni un trámite de la primera. Hacerlo
--    desde el SQL Editor no vale: ahí auth.uid() es null y RLS no aplica.
