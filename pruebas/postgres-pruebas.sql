-- ══════════════════════════════════════════════════════════════════════
--  LO QUE HACE EL SQL, EJECUTADO
-- ══════════════════════════════════════════════════════════════════════
--  Las otras tandas no tocan Postgres. supabase-mentira.js concede o
--  niega segun lo que se escribio que deberia pasar; que el panel salga
--  en verde no dice nada de si un trigger existe o de si una politica
--  cierra. Esto ejecuta los once archivos en un Postgres de verdad y
--  luego intenta hacer lo que no se debe.
--
--  Se entra como entra Supabase: "set role authenticated" y el sub del
--  JWT en request.jwt.claims. No es una imitacion del mecanismo, es el
--  mecanismo; si se dejara el rol de dueno, RLS no se aplicaria -un dueno
--  se salta sus propias politicas- y saldria todo en verde sin haber
--  comprobado ni una cerradura.
-- ══════════════════════════════════════════════════════════════════════

\set ON_ERROR_STOP on

-- Lo que Supabase reparte de fabrica a las dos cuentas anonimas. Sin
-- esto, cada intento fallaria por falta de permiso de tabla y no por la
-- politica, que es lo que se viene a probar: un aprobado por el motivo
-- equivocado tapa el agujero que se buscaba.
grant select, insert, update, delete on all tables in schema public to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;
grant execute on all functions in schema public to anon, authenticated;
grant select, insert, update, delete on storage.objects, storage.buckets to anon, authenticated;

-- A partir de aqui no se enseña nada hasta el informe: cada llamada a
-- comprueba() devuelve una tablita vacia de tres lineas, y veinte de esas
-- entierran lo unico que hay que leer. 'nul' es el agujero negro de
-- Windows, que es donde corre esto.
\o nul

create schema arnes;

create table arnes.resultado (
  orden serial, nombre text, ok boolean, detalle text
);
create table arnes.gente     (papel text primary key, id uuid);
create table arnes.escenario (clave text primary key, id uuid);

grant usage on schema arnes to anon, authenticated;
grant select, insert, update, delete on all tables in schema arnes to anon, authenticated;
grant usage, select on all sequences in schema arnes to anon, authenticated;

create or replace function arnes.comprueba(nombre text, ok boolean, detalle text default '')
returns void language sql as $c$
  insert into arnes.resultado (nombre, ok, detalle) values (nombre, ok, detalle);
$c$;

/* Hacerse pasar por alguien, igual que el servidor de Supabase. */
create or replace function arnes.soy(quien uuid)
returns void language plpgsql as $c$
begin
  perform set_config('request.jwt.claims',
                     json_build_object('sub', quien)::text, false);
end
$c$;



-- ── tres cuentas ──────────────────────────────────────────────────────
-- El perfil lo crea el trigger al_crear_usuario; que aparezca solo ya es
-- la primera comprobacion.
insert into auth.users (email, raw_user_meta_data) values
  ('a@prueba.local', '{"nombre_completo":"Ana Inversionista","pais":"Italia"}'),
  ('b@prueba.local', '{"nombre_completo":"Bruno Inversionista","pais":"Brasil"}'),
  ('g@prueba.local', '{"nombre_completo":"Gabriela Gestora","pais":"Venezuela"}');

insert into arnes.gente (papel, id)
select 'A', id from auth.users where email = 'a@prueba.local';
insert into arnes.gente (papel, id)
select 'B', id from auth.users where email = 'b@prueba.local';
insert into arnes.gente (papel, id)
select 'G', id from auth.users where email = 'g@prueba.local';

select arnes.comprueba(
  'alta: el perfil nace solo, con su nombre y su pais',
  (select count(*) = 3 from public.perfiles p join arnes.gente g on g.id = p.id
    where p.nombre_completo <> '' and p.pais <> ''),
  (select string_agg(nombre_completo, ' / ') from public.perfiles));

update public.perfiles set rol = 'gestor'
 where id = (select id from arnes.gente where papel = 'G');


-- ══ 1 · EL ESQUEMA QUEDO PUESTO ══════════════════════════════════════
select arnes.comprueba(
  'esquema: las trece tablas existen',
  (select count(*) = 13 from pg_tables where schemaname = 'public' and tablename in
    ('perfiles','tipos_documento','tipos_tramite','bancos_aliados','documentos',
     'tramites','tramite_documentos','tramite_eventos','citas','empresas',
     'activos','sectores','identidad_comprobaciones')),
  (select count(*)::text || ' de 13' from pg_tables where schemaname = 'public'));

select arnes.comprueba(
  'esquema: RLS activo en todas ellas',
  (select bool_and(c.relrowsecurity) from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r'),
  (select string_agg(c.relname, ', ') from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity));

select arnes.comprueba(
  'esquema: el indice de lo que vence',
  (select count(*) = 1 from pg_indexes
    where schemaname = 'public' and indexname = 'documentos_por_vencer'));

select arnes.comprueba(
  'esquema: el indice del lado flaco de la tabla puente',
  (select count(*) = 1 from pg_indexes
    where schemaname = 'public' and indexname = 'adjuntos_por_documento'));

select arnes.comprueba(
  'cubo: privado, con tope de 10 MB y ocho tipos',
  (select not public and file_size_limit = 10485760
          and array_length(allowed_mime_types, 1) = 8
     from storage.buckets where id = 'recaudos'),
  (select coalesce(file_size_limit::text, 'SIN TOPE') from storage.buckets where id = 'recaudos'));


-- ══ 2 · LA ESCALERA DE ESTADOS ═══════════════════════════════════════
-- El check de la tabla dice que estados EXISTEN; no dice en que orden se
-- pasa de uno a otro, y las politicas le dan al gestor mano libre sobre
-- el estado. Esto comprueba el trigger que puso la barandilla.
--
-- OJO con el rol: el trigger se aparta cuando auth.uid() es null, asi que
-- probarlo como dueno de la base no probaria nada. Se entra como entra
-- una persona.

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $p$
declare
  tipoAct text;
  nuevo   uuid;
begin
  select codigo into tipoAct from public.tipos_tramite where activo limit 1;
  if tipoAct is null then
    raise exception 'No hay ningun tipo de tramite activo: el seed no entro';
  end if;
  insert into public.tramites (inversionista, tipo, estado)
  values (auth.uid(), tipoAct, 'borrador')
  returning id into nuevo;
  insert into arnes.escenario values ('tramite', nuevo);
end
$p$;

/* El paso legitimo del inversionista. Va primero a proposito: un trigger
   que lo impidiera todo aprobaria cada intento de abajo sin proteger
   nada, y de paso dejaria al panel sin poder enviar una solicitud. */
do $p$
begin
  update public.tramites set estado = 'enviado'
   where id = (select id from arnes.escenario where clave = 'tramite');
  perform arnes.comprueba('escalera: de borrador a enviado SI se pasa', true, 'enviado');
exception when others then
  perform arnes.comprueba('escalera: de borrador a enviado SI se pasa', false, sqlerrm);
end
$p$;

-- Ahora el equipo. Las politicas le dejan escribir cualquier estado, asi
-- que lo unico que puede parar estos tres saltos es el trigger.
select arnes.soy((select id from arnes.gente where papel = 'G'));

do $p$
declare
  salto text;
  saltos text[] := array['resuelto', 'ante_el_ente', 'borrador'];
begin
  foreach salto in array saltos loop
    begin
      update public.tramites set estado = salto
       where id = (select id from arnes.escenario where clave = 'tramite')
         and estado = 'enviado';
      perform arnes.comprueba('escalera: no salta de enviado a ' || salto,
                                false, 'LO DEJO PASAR');
    exception when others then
      perform arnes.comprueba('escalera: no salta de enviado a ' || salto,
                                true, sqlerrm);
    end;
  end loop;
end
$p$;

/* Y los tres pasos que si toca, uno detras de otro hasta arriba. Sin
   esto, los rechazos de arriba podrian estar saliendo porque el gestor no
   puede escribir, y no porque la escalera tenga peldanos. */
do $p$
declare
  paso record;
  pasos constant text[][] := array[['enviado','en_revision'],
                                   ['en_revision','ante_el_ente'],
                                   ['ante_el_ente','resuelto']];
  i int;
begin
  for i in 1 .. array_length(pasos, 1) loop
    begin
      update public.tramites set estado = pasos[i][2]
       where id = (select id from arnes.escenario where clave = 'tramite');
      perform arnes.comprueba(
        'escalera: de ' || pasos[i][1] || ' a ' || pasos[i][2] || ' SI se pasa',
        (select estado = pasos[i][2] from public.tramites
          where id = (select id from arnes.escenario where clave = 'tramite')),
        pasos[i][2]);
    exception when others then
      perform arnes.comprueba(
        'escalera: de ' || pasos[i][1] || ' a ' || pasos[i][2] || ' SI se pasa',
        false, sqlerrm);
    end;
  end loop;
end
$p$;

/* De resuelto no se vuelve. Es el unico estado que no aparece a la
   izquierda de la tabla del trigger. */
do $p$
begin
  update public.tramites set estado = 'en_revision'
   where id = (select id from arnes.escenario where clave = 'tramite');
  perform arnes.comprueba('escalera: de resuelto no se vuelve', false, 'LO DEJO PASAR');
exception when others then
  perform arnes.comprueba('escalera: de resuelto no se vuelve', true, sqlerrm);
end
$p$;

/* Y el historial anoto cada peldano, que es lo que hace que "El proceso"
   del panel no sea un dibujo. */
select arnes.comprueba(
  'historial: quedaron anotados los cuatro pasos y el alta',
  (select count(*) = 5 from public.tramite_eventos
    where tramite = (select id from arnes.escenario where clave = 'tramite')),
  (select string_agg(coalesce(de_estado,'-') || '>' || a_estado, ' ' order by creado_en)
     from public.tramite_eventos
    where tramite = (select id from arnes.escenario where clave = 'tramite')));


-- ══ 3 · EL ARCHIVO SE VA CON SU FICHA ════════════════════════════════
-- documentos guarda la RUTA; el archivo vive en el cubo. Al borrar la
-- ficha, un trigger se lleva el archivo: sin el, borrar una cuenta dejaba
-- sus recaudos alli para siempre y sin nada que dijera de quien fueron.
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $p$
declare
  tipoDoc text;
  ruta    text;
  ficha   uuid;
begin
  select codigo into tipoDoc from public.tipos_documento limit 1;
  ruta := auth.uid() || '/rls-huerfano.pdf';

  insert into storage.objects (bucket_id, name, owner)
  values ('recaudos', ruta, auth.uid());

  insert into public.documentos (inversionista, tipo, archivo, nombre_original, estado)
  values (auth.uid(), tipoDoc, ruta, 'huerfano.pdf', 'cargado')
  returning id into ficha;

  delete from public.documentos where id = ficha;

  perform arnes.comprueba(
    'el archivo se va con su ficha',
    not exists (select 1 from storage.objects where name = ruta),
    case when exists (select 1 from storage.objects where name = ruta)
         then 'SIGUE AHI' else 'ya no esta' end);
end
$p$;

/* Y el caso que motivo el trigger: al borrar la CUENTA, el cascade se
   lleva la ficha, y con ella tiene que irse el archivo. Aqui no hay
   codigo de cliente que pueda encargarse; o lo hace la base o no lo hace
   nadie. Se borra el usuario B, que no se usa para nada mas. */
reset role;

do $p$
declare
  tipoDoc text;
  ruta    text;
  quien   uuid;
begin
  select id into quien from arnes.gente where papel = 'B';
  select codigo into tipoDoc from public.tipos_documento limit 1;
  ruta := quien || '/de-una-cuenta-borrada.pdf';

  insert into storage.objects (bucket_id, name, owner) values ('recaudos', ruta, quien);
  insert into public.documentos (inversionista, tipo, archivo, nombre_original, estado)
  values (quien, tipoDoc, ruta, 'de-una-cuenta-borrada.pdf', 'cargado');

  delete from auth.users where id = quien;

  perform arnes.comprueba(
    'y tambien cuando lo que se borra es la cuenta entera',
    not exists (select 1 from storage.objects where name = ruta),
    case when exists (select 1 from storage.objects where name = ruta)
         then 'SIGUE AHI' else 'ya no esta' end);
end
$p$;


-- ══ 4 · LAS CERRADURAS ═══════════════════════════════════════════════
-- Una muestra, no el reemplazo de PROBAR-CERRADURAS.bat: aquello entra
-- por HTTP como entraria un cliente hostil y prueba cuarenta y tantas.
-- Esto comprueba que las politicas que acompañan a lo de hoy cierran de
-- verdad en Postgres, que es donde cierran o no.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $p$
declare
  ajeno uuid;
begin
  -- A crea uno nuevo y suyo, para tener algo que otro intente mirar.
  insert into public.tramites (inversionista, tipo, estado)
  values (auth.uid(), (select codigo from public.tipos_tramite where activo limit 1), 'borrador')
  returning id into ajeno;
  insert into arnes.escenario values ('de_A', ajeno);
end
$p$;

/* Un inversionista cualquiera. Se hace pasar por un uuid que no es de
   nadie: si viera algo, lo veria todo el mundo. */
select arnes.soy('00000000-0000-0000-0000-0000000000ff'::uuid);

select arnes.comprueba(
  'un desconocido no ve el tramite de A',
  (select count(*) = 0 from public.tramites
    where id = (select id from arnes.escenario where clave = 'de_A')));

do $p$
begin
  update public.perfiles set rol = 'admin'
   where id = (select id from arnes.gente where papel = 'A');
  perform arnes.comprueba('nadie asciende a otro a admin',
    not exists (select 1 from public.perfiles p
                 where p.id = (select id from arnes.gente where papel = 'A') and p.rol = 'admin'),
    'no toco ninguna fila');
exception when others then
  perform arnes.comprueba('nadie asciende a otro a admin', true, sqlerrm);
end
$p$;

do $p$
declare fila int;
begin
  insert into public.sectores (codigo, ref_panel, nombre, orden)
  values ('colado', 'colado', 'Colado', 99);
  get diagnostics fila = row_count;
  perform arnes.comprueba('un inversionista no escribe en el catalogo de sectores',
                            false, 'ESCRIBIO ' || fila || ' fila(s)');
exception when others then
  perform arnes.comprueba('un inversionista no escribe en el catalogo de sectores',
                            true, sqlerrm);
end
$p$;

do $p$
begin
  insert into public.activos (titulo, sector, estado)
  values ('Oportunidad falsa', 'x', 'disponible');
  perform arnes.comprueba('ni publica un activo', false, 'ESCRIBIO');
exception when others then
  perform arnes.comprueba('ni publica un activo', true, sqlerrm);
end
$p$;

reset role;


-- ── el resultado ──────────────────────────────────────────────────────
\o
\pset tuples_only on
\pset format unaligned
select '  ' || case when ok then 'PASA ' else 'FALLA' end || ' ' || nombre ||
       case when ok or detalle = '' then '' else chr(10) || '          ' || detalle end
  from arnes.resultado order by orden;

select '';
select '  ' || count(*) filter (where ok) || ' de ' || count(*) ||
       ' comprobaciones superadas'
  from arnes.resultado;
select '';
\pset tuples_only off

do $p$
declare mal int;
begin
  select count(*) into mal from arnes.resultado where not ok;
  if mal > 0 then
    raise exception '% comprobaciones en rojo', mal;
  end if;
end
$p$;
