-- ══════════════════════════════════════════════════════════════════════
--  LO QUE HACE EL SQL, EJECUTADO
-- ══════════════════════════════════════════════════════════════════════
--  Las otras tandas no tocan Postgres. supabase-mentira.js concede o
--  niega segun lo que se escribio que deberia pasar; que el panel salga
--  en verde no dice nada de si un trigger existe o de si una politica
--  cierra. Esto ejecuta los veintitres archivos en un Postgres de verdad y
--  luego intenta hacer lo que no se debe.
--
--  Se entra como entra Supabase: "set role authenticated" y el sub del
--  JWT en request.jwt.claims. No es una imitacion del mecanismo, es el
--  mecanismo; si se dejara el rol de dueno, RLS no se aplicaria -un dueno
--  se salta sus propias politicas- y saldria todo en verde sin haber
--  comprobado ni una cerradura.
-- ══════════════════════════════════════════════════════════════════════

\set ON_ERROR_STOP on

-- Lo que Supabase reparte de fabrica a las dos cuentas anonimas lo pone
-- ahora el doble al crear cada tabla (alter default privileges, al final
-- de postgres-doble.sql), y los archivos quitan encima. Aqui se concedia
-- en bloque justo antes de probar y pisaba esos revoke (8-10-2026).
-- Las FUNCIONES no se reparten aqui, y esta es la linea que mas cara ha
-- salido de este archivo: repartia EXECUTE sobre todas a anon y a
-- authenticated justo antes de probar, con lo cual daba igual lo que
-- dijeran los revoke de los archivos. Cualquier funcion abierta de par en
-- par salia verde aqui. Se vio corriendo las cerraduras contra un Supabase
-- de verdad, no aqui.
--
-- Ahora quien reparte es el doble, imitando el `alter default privileges`
-- que Supabase deja puesto (ver el final de postgres-doble.sql), y los
-- archivos quitan y ponen encima de eso. Que es lo que pasa en el proyecto
-- de verdad.
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
create or replace function arnes.nadie()
returns void language plpgsql as $c$
begin
  -- Un objeto vacio, no una cadena vacia: auth.uid() hace un cast a json
  -- y '' no es json valido, asi que vaciarlo del todo reventaba antes de
  -- llegar a devolver null.
  perform set_config('request.jwt.claims', '{}', false);
end
$c$;

create table arnes.gente     (papel text primary key, id uuid);

/* Dejar de ser nadie. No basta con cambiar de rol: request.jwt.claims
   sigue puesto de la vez anterior, y auth.uid() lo lee de ahi. Sin esto,
   una prueba de "sin entrar" se hace con la sesion del ultimo que
   entro, y sale en verde sin haber comprobado nada. */
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
-- ficha, un trigger APUNTA el archivo en archivos_huerfanos, y de ahi lo
-- recoge el barrendero llamando a la API de Storage.
--
-- No se borra aqui a proposito, por dos razones que estan explicadas
-- largo en supabase-tramites.sql: un `delete from storage.objects` quita
-- el indice y deja los bytes, y encima en un Supabase de verdad no le
-- dejan tocar esa tabla y se va en silencio.
--
-- Por eso estas comprobaciones miran la lista y NO miran storage.objects.
-- La fila del indice tiene que SEGUIR ahi: es por su nombre por donde la
-- API de Storage va a buscar el archivo cuando le toque.
--
-- Ojo con el nombre de la variable: la columna tambien se llama 'ruta', y
-- en plpgsql `where ruta = ruta` se compara consigo misma y sale que si
-- siempre. De ahi 'laRuta'.
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $p$
declare
  tipoDoc text;
  laRuta  text;
  ficha   uuid;
begin
  select codigo into tipoDoc from public.tipos_documento limit 1;
  laRuta := auth.uid() || '/rls-huerfano.pdf';

  insert into storage.objects (bucket_id, name, owner)
  values ('recaudos', laRuta, auth.uid());

  insert into public.documentos (inversionista, tipo, archivo, nombre_original, estado)
  values (auth.uid(), tipoDoc, laRuta, 'huerfano.pdf', 'cargado')
  returning id into ficha;

  delete from public.documentos where id = ficha;
end
$p$;

/* El apunte se COMPRUEBA con el rol quitado, y no es un atajo: la lista
   no la puede leer nadie que entre por la clave publica -eso se prueba
   dos parrafos mas abajo-, asi que mirandola como 'authenticated' esto
   saldria rojo aunque el trigger funcionara de maravilla. Lo que se esta
   probando aqui es que el trigger escribe, no quien puede leer. */
reset role;

do $p$
declare
  laRuta text;
  duenio uuid;
begin
  select id into duenio from arnes.gente where papel = 'A';
  laRuta := duenio || '/rls-huerfano.pdf';

  perform arnes.comprueba(
    'al borrar la ficha, el archivo queda apuntado para barrer',
    exists (select 1 from public.archivos_huerfanos h
             where h.ruta = laRuta and h.estado = 'pendiente'),
    'no lo apunto');

  -- Y con el nombre de quien fue, que es lo que no habia forma de saber
  -- cuando el archivo se quedaba suelto en el cubo.
  perform arnes.comprueba(
    'y queda dicho de quien era',
    (select h.de_quien from public.archivos_huerfanos h where h.ruta = laRuta) = duenio,
    'sin dueño');

  -- Lo que NO tiene que pasar: que se lleve por delante el indice. Si
  -- desapareciera de storage.objects, el barrendero se quedaria con una
  -- ruta que ya no apunta a nada y los bytes ahi para siempre.
  perform arnes.comprueba(
    'el indice del cubo sigue puesto, que es por donde se va a buscar',
    exists (select 1 from storage.objects where name = laRuta),
    'SE LO LLEVO');
end
$p$;

/* Y el caso que motivo todo esto: al borrar la CUENTA, el cascade se
   lleva la ficha, y con ella tiene que quedar apuntado el archivo. Aqui
   no hay codigo de cliente que pueda encargarse; o lo apunta la base o no
   lo apunta nadie. Se borra el usuario B, que no se usa para nada mas. */
reset role;

do $p$
declare
  tipoDoc text;
  laRuta  text;
  quien   uuid;
begin
  select id into quien from arnes.gente where papel = 'B';
  select codigo into tipoDoc from public.tipos_documento limit 1;
  laRuta := quien || '/de-una-cuenta-borrada.pdf';

  insert into storage.objects (bucket_id, name, owner) values ('recaudos', laRuta, quien);
  insert into public.documentos (inversionista, tipo, archivo, nombre_original, estado)
  values (quien, tipoDoc, laRuta, 'de-una-cuenta-borrada.pdf', 'cargado');

  delete from auth.users where id = quien;

  perform arnes.comprueba(
    'y tambien cuando lo que se borra es la cuenta entera',
    exists (select 1 from public.archivos_huerfanos h
             where h.ruta = laRuta and h.estado = 'pendiente'),
    'no lo apunto');

  -- La razon de que de_quien no tenga llave foranea. Con un cascade, esta
  -- fila se habria borrado en el mismo momento en que empezaba a hacer
  -- falta, y el archivo se habria quedado en el cubo sin que nada lo
  -- nombrara: exactamente el agujero que se venia a tapar.
  perform arnes.comprueba(
    'el apunte sobrevive a la cuenta que lo dejo',
    (select h.de_quien from public.archivos_huerfanos h where h.ruta = laRuta) = quien,
    'se fue con la cuenta');
end
$p$;

-- Nadie que entre por la clave publica ve esa lista. Cada fila es la ruta
-- de un archivo del cubo, y las rutas empiezan por el uuid del dueño:
-- poder leerlas seria poder nombrar recaudos ajenos, incluidos los de
-- cuentas ya borradas.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
select arnes.comprueba(
  'la lista de huerfanos no la lee ni el que la lleno',
  (select count(*) = 0 from public.archivos_huerfanos),
  'la esta leyendo');
reset role;


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
  values (auth.uid(), (select codigo from public.tipos_tramite where activo limit 1 offset 1), 'borrador')
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

-- ══ 5 · LA COLA SE LLENA SOLA ════════════════════════════════════════
-- El trabajo lo pone un trigger cuando el estado cambia, no la
-- aplicacion. Si dependiera de que alguien se acuerde de encolar, algun
-- dia se olvidaria y un tramite se quedaria parado sin que nadie supiera
-- por que -que es exactamente lo que ya se decidio para el historial-.
--
-- Y entra en 'en_revision', no en 'enviado': la escalera de estados solo
-- deja pasar a 'ante_el_ente' desde ahi. O sea que lo que se manda a un
-- organismo lo ha visto antes una persona.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $p$
declare
  conConector text;
  nuevo uuid;
begin
  select codigo into conConector
    from public.tipos_tramite where conector is not null and activo limit 1;
  if conConector is null then
    perform arnes.comprueba('cola: hay al menos un tramite con conector', false,
                            'ninguno lo tiene');
    return;
  end if;
  perform arnes.comprueba('cola: hay al menos un tramite con conector', true, conConector);

  insert into public.tramites (inversionista, tipo, estado)
  values (auth.uid(), conConector, 'borrador') returning id into nuevo;
  insert into arnes.escenario values ('con_conector', nuevo);

  update public.tramites set estado = 'enviado' where id = nuevo;
end
$p$;

-- Enviado todavia no encola: falta que una persona lo revise.
select arnes.comprueba(
  'cola: en "enviado" todavia no hay nada que hacer',
  (select count(*) = 0 from public.trabajos
    where tramite = (select id from arnes.escenario where clave = 'con_conector')),
  'sigue vacia');

select arnes.soy((select id from arnes.gente where papel = 'G'));

do $p$
begin
  update public.tramites set estado = 'en_revision'
   where id = (select id from arnes.escenario where clave = 'con_conector');
end
$p$;

select arnes.comprueba(
  'cola: al revisarlo aparece el "presentar", sin que nadie lo escriba',
  (select count(*) = 1 from public.trabajos
    where tramite = (select id from arnes.escenario where clave = 'con_conector')
      and tarea = 'presentar' and estado = 'pendiente'));

-- Y no dos veces. Sin el indice parcial, dos triggers seguidos -o dos
-- trabajadores- dejaban el mismo tramite dos veces en la cola, y eso es
-- un expediente presentado dos veces ante un organismo.
do $p$
begin
  insert into public.trabajos (tramite, tarea, llave)
  values ((select id from arnes.escenario where clave = 'con_conector'),
          'presentar', 'a mano');
  perform arnes.comprueba('cola: el mismo trabajo no se encola dos veces',
                          false, 'ENTRO LA SEGUNDA');
exception when others then
  perform arnes.comprueba('cola: el mismo trabajo no se encola dos veces', true, sqlerrm);
end
$p$;

-- Un tramite SIN conector no encola nada: se atiende a mano como
-- siempre, sin que haya que acordarse de excluirlo en ningun sitio.
reset role;
do $p$
declare
  sinConector text;
  otro uuid;
  quien uuid;
begin
  select codigo into sinConector
    from public.tipos_tramite where conector is null and activo limit 1;
  select id into quien from arnes.gente where papel = 'A';

  insert into public.tramites (inversionista, tipo, estado)
  values (quien, sinConector, 'borrador') returning id into otro;
  update public.tramites set estado = 'enviado'     where id = otro;
  update public.tramites set estado = 'en_revision' where id = otro;

  perform arnes.comprueba('cola: un tramite sin conector no encola nada',
    not exists (select 1 from public.trabajos where tramite = otro),
    'sigue yendo a mano');
end
$p$;

-- Al pasar a 'ante_el_ente' -lo hara el trabajador- se encola la
-- consulta, tambien sola. Asi el trabajador no tiene que acordarse de
-- programar el seguimiento: es un sitio menos donde olvidarse.
do $p$
declare
  cual uuid;
begin
  select id into cual from arnes.escenario where clave = 'con_conector';
  update public.trabajos set estado = 'hecho' where tramite = cual;
  update public.tramites  set estado = 'ante_el_ente' where id = cual;

  perform arnes.comprueba(
    'cola: al quedar ante el ente se encola la consulta, sola',
    exists (select 1 from public.trabajos
             where tramite = cual and tarea = 'consultar' and estado = 'pendiente'));
end
$p$;

-- Y el inversionista no la ve. No le dice nada que no le diga su
-- historial, y en cambio le ensenaria los reintentos y los errores de un
-- organismo, que es ruido nuestro y parece un problema suyo.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
select arnes.comprueba(
  'cola: el inversionista no ve la cola de envios',
  (select count(*) = 0 from public.trabajos));

select arnes.soy((select id from arnes.gente where papel = 'G'));
select arnes.comprueba(
  'cola: pero el equipo si (esto TIENE que salir)',
  (select count(*) > 0 from public.trabajos));

reset role;


-- ══ 6 · EL AVISO SE ESCRIBE SOLO ═════════════════════════════════════
-- Cuelga de tramite_eventos y no de tramites, y no es un detalle: el
-- historial ya se escribe desde un trigger y es la unica fila que existe
-- siempre que ha pasado algo digno de contarse. Colgar de ahi significa
-- que ningun cambio de estado puede escaparse.
reset role;

-- Un correo en auth.users, que es de donde lo saca el trigger. Sin esto
-- el aviso no se escribe -y no escribirlo es lo correcto: no se puede
-- avisar a quien no tiene direccion-.
update auth.users set email = 'ana@prueba.local'
 where id = (select id from arnes.gente where papel = 'A');

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));

do $p$
declare
  cual uuid;
begin
  select id into cual from arnes.escenario where clave = 'con_conector';
  -- Esta en 'ante_el_ente' desde la seccion 5. Se devuelve, que es el
  -- unico aviso que pide una accion de la persona.
  --
  -- Y se hace COMO LO HACE EL PANEL, en dos pasos: primero el estado -que
  -- es lo que dispara el historial y con el el aviso-, y despues la nota,
  -- con un update sobre el evento ya creado. Insertar el evento a mano no
  -- vale: la politica no deja, y ademas se saltaria justo el orden que
  -- aqui hay que comprobar.
  update public.tramites set estado = 'devuelto' where id = cual;

  update public.tramite_eventos set nota = 'Falta el acta constitutiva.'
   where tramite = cual and a_estado = 'devuelto';
end
$p$;

reset role;

select arnes.comprueba(
  'avisos: devolver un tramite escribe su aviso, sin que nadie lo pida',
  (select count(*) > 0 from public.avisos
    where motivo = 'cambio_estado' and a_estado = 'devuelto'
      and destinatario = 'ana@prueba.local'));

-- La nota se escribe DESPUES del evento, asi que el aviso nace vacio y
-- hay que copiarsela cuando llega. Sin eso, el correo de una devolucion
-- dice "hay algo que corregir" y no dice que, que es peor que no
-- mandarlo. Este es el fallo que encontro esta tanda al ejecutarse.
select arnes.comprueba(
  'avisos: y lleva dentro el motivo, aunque se escriba despues del evento',
  (select count(*) > 0 from public.avisos
    where a_estado = 'devuelto' and nota like '%acta constitutiva%'),
  (select coalesce(string_agg(quote_literal(nota), ' '), 'ninguno')
     from public.avisos where a_estado = 'devuelto'));

-- 'enviado' y 'en_revision' NO se avisan. El primero lo acaba de hacer
-- el, y avisarle de su propio clic es como se consigue que mande el
-- remitente a la basura; el segundo es trabajo interno nuestro.
select arnes.comprueba(
  'avisos: de "enviado" y "en_revision" no se avisa a nadie',
  (select count(*) = 0 from public.avisos
    where a_estado in ('enviado', 'en_revision', 'borrador')),
  (select coalesce(string_agg(distinct a_estado, ', '), 'ninguno') from public.avisos));

-- Sin correo no hay aviso, y tampoco hay error: reventar aqui haria
-- fallar el cambio de estado -que es lo importante- por no poder hacer
-- lo accesorio.
do $p$
declare
  quien uuid;
  otro  uuid;
  antes int;
begin
  select count(*) into antes from public.avisos;
  select id into quien from arnes.gente where papel = 'G';
  update auth.users set email = null where id = quien;

  insert into public.tramites (inversionista, tipo, estado)
  values (quien, (select codigo from public.tipos_tramite where activo limit 1 offset 2), 'borrador')
  returning id into otro;
  insert into public.tramite_eventos (tramite, a_estado, nota)
  values (otro, 'resuelto', 'x');

  perform arnes.comprueba(
    'avisos: sin correo no se avisa, y el cambio de estado no falla',
    (select count(*) from public.avisos) = antes,
    'no se escribio ninguno');
exception when others then
  perform arnes.comprueba(
    'avisos: sin correo no se avisa, y el cambio de estado no falla',
    false, 'REVENTO: ' || sqlerrm);
end
$p$;

-- ── lo que vence ──
-- Esto no lo dispara ningun trigger: no pasa porque alguien haga algo,
-- pasa porque pasa el tiempo. Es el ejemplo mas claro de por que hacia
-- falta algo que corra sin que nadie mire.
do $p$
declare
  quien uuid;
  tipoDoc text;
  puso int;
  otraVez int;
begin
  select id into quien from arnes.gente where papel = 'A';
  select codigo into tipoDoc from public.tipos_documento limit 1;

  insert into public.documentos (inversionista, tipo, archivo, nombre_original,
                                 vence_el, estado)
  values (quien, tipoDoc, quien || '/vence.pdf', 'vence.pdf',
          current_date + 10, 'cargado');

  select public.avisar_de_lo_que_vence(30) into puso;
  perform arnes.comprueba('avisos: lo que vence en diez dias se avisa', puso = 1,
                          puso || ' avisos');

  -- Dos veces seguidas tiene que dar cero. Sin esa guarda, un documento
  -- que vence en tres semanas manda veintiun correos iguales y la
  -- persona deja de leerlos, incluido el que si importaba.
  select public.avisar_de_lo_que_vence(30) into otraVez;
  perform arnes.comprueba('avisos: y no se avisa dos veces del mismo vencimiento',
                          otraVez = 0, otraVez || ' la segunda vez');
end
$p$;

-- Un documento que caduca dentro de un ano no molesta hoy: avisar tan
-- pronto es avisar cuando aun no se puede hacer nada, y se olvida.
do $p$
declare
  quien uuid;
  tipoDoc text;
  puso int;
begin
  select id into quien from arnes.gente where papel = 'A';
  select codigo into tipoDoc from public.tipos_documento limit 1;
  insert into public.documentos (inversionista, tipo, archivo, nombre_original,
                                 vence_el, estado)
  values (quien, tipoDoc, quien || '/lejos.pdf', 'lejos.pdf',
          current_date + 300, 'cargado');
  select public.avisar_de_lo_que_vence(30) into puso;
  perform arnes.comprueba('avisos: lo que vence dentro de un ano todavia no',
                          puso = 0, puso || ' avisos');
end
$p$;

-- Y el inversionista no ve su propio buzon de salida: ahi estan los
-- intentos fallidos y los errores del SMTP, que no significan nada para
-- el y parecen un problema suyo.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
select arnes.comprueba(
  'avisos: el inversionista no ve el buzon de salida',
  (select count(*) = 0 from public.avisos));

select arnes.soy((select id from arnes.gente where papel = 'G'));
select arnes.comprueba(
  'avisos: pero el equipo si (esto TIENE que salir)',
  (select count(*) > 0 from public.avisos));

reset role;


-- ══ 7 · LOS ARANCELES ════════════════════════════════════════════════
-- El catalogo nace VACIO a proposito -aqui no se inventan cifras
-- oficiales-, y mientras lo este todo funciona como antes. Se le pone uno
-- para poder comprobar lo que pasa cuando lo haya.
reset role;

select arnes.comprueba(
  'aranceles: el catalogo nace vacio, y no es un fallo',
  (select count(*) = 0 from public.aranceles),
  (select count(*)::text || ' filas' from public.aranceles));

-- Sin arancel no se emite orden: es el caso de los treinta y uno hoy.
do $p$
declare
  quien uuid; cual uuid; sinTasa text;
begin
  select id into quien from arnes.gente where papel = 'A';
  select codigo into sinTasa from public.tipos_tramite where activo limit 1 offset 3;
  insert into public.tramites (inversionista, tipo, estado)
  values (quien, sinTasa, 'borrador') returning id into cual;
  update public.tramites set estado = 'enviado' where id = cual;

  perform arnes.comprueba('aranceles: sin tasa no se emite ninguna orden',
    not exists (select 1 from public.ordenes_pago where tramite = cual),
    'ninguna');
end
$p$;

-- Ahora con tasa, y sobre el tramite que TIENE conector: asi se puede ver
-- lo unico que de verdad hace util esto, que es que no se presente lo que
-- no esta pagado.
do $p$
declare
  conConector text;
begin
  select codigo into conConector
    from public.tipos_tramite where conector is not null and activo limit 1;
  insert into public.aranceles (tramite, concepto, monto, moneda)
  values (conConector, 'Tasa de prueba', 120.00, 'USD');
end
$p$;

-- Un solo arancel vigente por tramite. Dos filas abiertas harian que la
-- orden dependiera de cual leyera primero la consulta, y eso es un cobro
-- distinto segun el dia.
do $p$
declare conConector text;
begin
  select codigo into conConector
    from public.tipos_tramite where conector is not null and activo limit 1;
  insert into public.aranceles (tramite, concepto, monto)
  values (conConector, 'Otra vigente a la vez', 999.00);
  perform arnes.comprueba('aranceles: no puede haber dos vigentes del mismo tramite',
                          false, 'ENTRO LA SEGUNDA');
exception when others then
  perform arnes.comprueba('aranceles: no puede haber dos vigentes del mismo tramite',
                          true, sqlerrm);
end
$p$;

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $p$
declare
  cual uuid; conConector text;
begin
  select codigo into conConector
    from public.tipos_tramite where conector is not null and activo limit 1;
  insert into public.tramites (inversionista, tipo, estado)
  values (auth.uid(), conConector, 'borrador') returning id into cual;
  insert into arnes.escenario values ('con_tasa', cual);
  update public.tramites set estado = 'enviado' where id = cual;
end
$p$;

select arnes.comprueba(
  'aranceles: al enviar la solicitud se emite la orden, sola',
  (select count(*) = 1 from public.ordenes_pago
    where tramite = (select id from arnes.escenario where clave = 'con_tasa')
      and estado = 'pendiente' and monto = 120.00));

-- El monto se COPIA. Si se leyera del catalogo, subir un arancel
-- cambiaria retroactivamente lo que debe alguien que solicito hace un mes.
reset role;
do $p$
declare conConector text;
begin
  select codigo into conConector
    from public.tipos_tramite where conector is not null and activo limit 1;
  update public.aranceles set hasta = current_date
   where tramite = conConector and hasta is null;
  insert into public.aranceles (tramite, concepto, monto)
  values (conConector, 'Tasa nueva, mas cara', 500.00);
end
$p$;

select arnes.comprueba(
  'aranceles: subir la tasa NO cambia lo que ya se debia',
  (select monto = 120.00 from public.ordenes_pago
    where tramite = (select id from arnes.escenario where clave = 'con_tasa')),
  (select monto::text from public.ordenes_pago
    where tramite = (select id from arnes.escenario where clave = 'con_tasa')));

-- ── y aqui lo que importa ──
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $p$
begin
  update public.tramites set estado = 'en_revision'
   where id = (select id from arnes.escenario where clave = 'con_tasa');
end
$p$;

select arnes.comprueba(
  'aranceles: con la orden sin pagar, NO se encola la presentacion',
  (select count(*) = 0 from public.trabajos
    where tramite = (select id from arnes.escenario where clave = 'con_tasa')),
  (select coalesce(string_agg(tarea, ', '), 'ninguno') from public.trabajos
    where tramite = (select id from arnes.escenario where clave = 'con_tasa')));

-- Al pagar se suelta. Sin esto, un tramite pagado despues de la revision
-- se quedaria esperando para siempre: el momento de encolar ya paso y
-- nadie volveria a mirarlo.
reset role;
update public.ordenes_pago
   set estado = 'pagada', pagado_en = now(), referencia = 'BCO-2026-000001'
 where tramite = (select id from arnes.escenario where clave = 'con_tasa');

select arnes.comprueba(
  'aranceles: y al pagarla aparece el "presentar" (esto TIENE que salir)',
  (select count(*) = 1 from public.trabajos
    where tramite = (select id from arnes.escenario where clave = 'con_tasa')
      and tarea = 'presentar'));

-- Una orden pagada sin fecha de pago no se puede conciliar con el banco.
do $p$
begin
  update public.ordenes_pago set pagado_en = null
   where tramite = (select id from arnes.escenario where clave = 'con_tasa');
  perform arnes.comprueba('aranceles: una orden pagada sin fecha no se admite',
                          false, 'LA ADMITIO');
exception when others then
  perform arnes.comprueba('aranceles: una orden pagada sin fecha no se admite',
                          true, sqlerrm);
end
$p$;

-- Y nadie la marca pagada desde el navegador, ni el equipo: eso lo
-- escribe el cobrador con la clave de servidor, despues de que la
-- pasarela lo confirme. Una orden que se pueda dar por pagada desde el
-- cliente no es una orden de pago.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $p$
declare fila int;
begin
  update public.ordenes_pago set estado = 'anulada'
   where inversionista = auth.uid();
  get diagnostics fila = row_count;
  perform arnes.comprueba('aranceles: nadie toca su propia orden desde el panel',
                          fila = 0, 'ESCRIBIO ' || fila || ' fila(s)');
exception when others then
  perform arnes.comprueba('aranceles: nadie toca su propia orden desde el panel',
                          true, sqlerrm);
end
$p$;

select arnes.comprueba(
  'aranceles: pero SI ve lo que debe (esto TIENE que salir)',
  (select count(*) > 0 from public.ordenes_pago where inversionista = auth.uid()));

select arnes.comprueba(
  'aranceles: y cuanto cuesta cada tramite antes de empezarlo',
  (select count(*) > 0 from public.aranceles));

reset role;


-- ══ 8 · LA HUELLA DE CADA DOCUMENTO ══════════════════════════════════
-- Dos cosas con la misma columna: que el conector pueda mandar al
-- organismo el sha256 que ya tenia escrito en su contrato -y que hasta
-- ahora iba vacio porque nadie lo calculaba-, y que un tercero pueda
-- verificar un documento emitido sin que le digamos de quien es.
reset role;

do $p$
declare
  quien uuid; tipoDoc text; hex text;
begin
  /* Por la puerta de servicio de verdad: reset role no borra la sesion
     de la prueba anterior, y un papel validado no lo da de alta un
     inversionista (supabase-papeles-sellados.sql). En emitidos/ porque
     es lo unico que verificar_documento() respalda. */
  perform arnes.nadie();
  select id into quien from arnes.gente where papel = 'A';
  select codigo into tipoDoc from public.tipos_documento limit 1;
  hex := repeat('ab', 32);   -- 64 hexadecimales

  insert into public.documentos (inversionista, tipo, archivo, nombre_original,
                                 estado, huella)
  values (quien, tipoDoc, quien || '/emitidos/con-huella.pdf', 'con-huella.pdf',
          'validado', hex);
  insert into arnes.escenario values ('huella', null);
end
$p$;

-- Una huella que no es una huella no entra. Sin esto, cualquier cadena
-- vale y la verificacion empieza a contestar a preguntas que no son
-- huellas.
do $p$
declare quien uuid; tipoDoc text;
begin
  select id into quien from arnes.gente where papel = 'A';
  select codigo into tipoDoc from public.tipos_documento limit 1;
  insert into public.documentos (inversionista, tipo, archivo, nombre_original, huella)
  values (quien, tipoDoc, quien || '/mala.pdf', 'mala.pdf', 'no soy una huella');
  perform arnes.comprueba('huellas: una cadena que no es un sha256 no entra',
                          false, 'ENTRO');
exception when others then
  perform arnes.comprueba('huellas: una cadena que no es un sha256 no entra',
                          true, sqlerrm);
end
$p$;

-- Mayusculas tampoco: si entraran, el mismo archivo tendria dos huellas
-- distintas segun quien lo subiera y la verificacion fallaria la mitad de
-- las veces.
do $p$
declare quien uuid; tipoDoc text;
begin
  select id into quien from arnes.gente where papel = 'A';
  select codigo into tipoDoc from public.tipos_documento limit 1;
  insert into public.documentos (inversionista, tipo, archivo, nombre_original, huella)
  values (quien, tipoDoc, quien || '/mayus.pdf', 'mayus.pdf', repeat('AB', 32));
  perform arnes.comprueba('huellas: ni en mayusculas', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('huellas: ni en mayusculas', true, sqlerrm);
end
$p$;

-- Y null si vale: son los documentos que ya estaban subidos, y los que
-- suba alguien desde la red de la oficina, donde crypto.subtle no existe
-- porque no hay https. null quiere decir "no se pudo calcular", no "no
-- vale".
do $p$
declare quien uuid; tipoDoc text;
begin
  select id into quien from arnes.gente where papel = 'A';
  select codigo into tipoDoc from public.tipos_documento limit 1;
  insert into public.documentos (inversionista, tipo, archivo, nombre_original)
  values (quien, tipoDoc, quien || '/sin-huella.pdf', 'sin-huella.pdf');
  perform arnes.comprueba('huellas: un documento sin huella sigue entrando', true, 'null');
exception when others then
  perform arnes.comprueba('huellas: un documento sin huella sigue entrando',
                          false, sqlerrm);
end
$p$;

-- ── verificar ──
select arnes.comprueba(
  'huellas: un documento validado consta al verificarlo',
  (select count(*) = 1 from public.verificar_documento(repeat('ab', 32))));

select arnes.comprueba(
  'huellas: y dice si sigue vigente, sin decir de quien es',
  (select vigente from public.verificar_documento(repeat('ab', 32))));

-- Lo que NO puede devolver. Si trajera al dueno, esto seria un buscador
-- de personas por documento: quien verifica tiene el papel delante y ya
-- sabe de quien es, pero no puede poder preguntar por una huella
-- cualquiera y averiguarlo.
select arnes.comprueba(
  'huellas: la verificacion no devuelve ninguna columna que identifique',
  (select count(*) = 0 from information_schema.columns
    where table_name = 'verificar_documento'
      and column_name in ('inversionista', 'destinatario', 'correo', 'nombre_completo')),
  'ninguna');

select arnes.comprueba(
  'huellas: una huella inventada no consta',
  (select count(*) = 0 from public.verificar_documento(repeat('cd', 32))));

-- Un documento SIN validar no es verificable: decir que si lo es seria
-- avalar un papel que aqui no ha mirado nadie.
do $p$
declare quien uuid; tipoDoc text;
begin
  select id into quien from arnes.gente where papel = 'A';
  select codigo into tipoDoc from public.tipos_documento limit 1;
  insert into public.documentos (inversionista, tipo, archivo, nombre_original,
                                 estado, huella)
  values (quien, tipoDoc, quien || '/sin-validar.pdf', 'sin-validar.pdf',
          'cargado', repeat('ef', 32));
  perform arnes.comprueba('huellas: uno sin validar NO se verifica',
    (select count(*) = 0 from public.verificar_documento(repeat('ef', 32))),
    'no consta');
end
$p$;

-- Y se puede preguntar SIN haber entrado. Quien verifica no es usuario de
-- la ventanilla: es un banco con un papel en la mano. Una verificacion
-- que exija cuenta no la usa nadie.
set role anon;
select arnes.nadie();
select arnes.comprueba(
  'huellas: se verifica sin entrar (esto TIENE que salir)',
  (select count(*) = 1 from public.verificar_documento(repeat('ab', 32))));

-- Pero sin poder mirar la tabla, que es lo que separa "verificar" de
-- "husmear".
select arnes.comprueba(
  'huellas: pero sin entrar no se lee la tabla de documentos',
  (select count(*) = 0 from public.documentos));

reset role;

-- ── la huella no se reescribe ──
-- Es lo unico que hace que sirva de algo. Si el dueno pudiera cambiarla,
-- subiria un archivo, esperaria a que se lo validaran, y luego le pondria
-- la huella de otro distinto.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $p$
begin
  update public.documentos set huella = repeat('99', 32)
   where huella = repeat('ef', 32);
  perform arnes.comprueba('huellas: el dueno no puede cambiar la huella',
    (select count(*) = 0 from public.documentos where huella = repeat('99', 32)),
    'no toco ninguna fila');
exception when others then
  perform arnes.comprueba('huellas: el dueno no puede cambiar la huella', true, sqlerrm);
end
$p$;

reset role;


-- ══ 9 · UNA SOLA SOLICITUD VIVA POR TRAMITE ══════════════════════════
-- El panel ya lo comprobaba antes de enviar, pero su propio comentario
-- decia que era "una comprobacion del panel, no una cerradura". Esta es
-- la cerradura. Lo que importa de estas cinco es que las dos ultimas
-- pasen: un indice sin el WHERE tambien impediria los duplicados, y de
-- paso impediria pedir la solvencia del ano siguiente.
reset role;

select arnes.comprueba(
  'una viva: el indice esta puesto',
  (select count(*) = 1 from pg_indexes
    where tablename = 'tramites' and indexname = 'tramites_una_viva'));

do $p$
declare
  quien uuid; tipoAct text; primero uuid;
begin
  select id into quien from arnes.gente where papel = 'A';
  -- La compraventa no se resuelve sin la fecha de la firma (3207268), y el
  -- paso 3 resuelve esta: cualquier otro tipo vale.
  select codigo into tipoAct from public.tipos_tramite
   where activo and codigo <> 'bienes_compraventa' limit 1 offset 4;

  insert into public.tramites (inversionista, tipo, estado)
  values (quien, tipoAct, 'borrador') returning id into primero;
  update public.tramites set estado = 'enviado' where id = primero;
  insert into arnes.escenario values ('viva', primero);

  -- 1 · otra viva del mismo tramite y la misma persona: NO
  begin
    insert into public.tramites (inversionista, tipo, estado)
    values (quien, tipoAct, 'borrador');
    update public.tramites set estado = 'enviado'
     where inversionista = quien and tipo = tipoAct and estado = 'borrador';
    perform arnes.comprueba('una viva: dos a la vez del mismo tramite, NO',
                            false, 'ENTRO LA SEGUNDA');
  exception when others then
    perform arnes.comprueba('una viva: dos a la vez del mismo tramite, NO', true, sqlerrm);
  end;
end
$p$;

-- 2 · otra PERSONA pidiendo lo mismo a la vez: SI. Dos inversionistas
--     con la misma visa en marcha es lo normal, no un duplicado.
do $p$
declare
  otro uuid; tipoAct text; nuevo uuid;
begin
  select id into otro from arnes.gente where papel = 'G';
  select codigo into tipoAct from public.tipos_tramite where activo limit 1 offset 5;
  insert into public.tramites (inversionista, tipo, estado)
  values (otro, tipoAct, 'borrador') returning id into nuevo;
  update public.tramites set estado = 'enviado' where id = nuevo;
  perform arnes.comprueba('una viva: pero OTRA persona si puede, a la vez', true, 'entro');
exception when others then
  perform arnes.comprueba('una viva: pero OTRA persona si puede, a la vez', false, sqlerrm);
end
$p$;

-- 3 · y con la primera RESUELTA, pedirla otra vez: SI.
--     Es la solvencia del ano que viene. Si esto fallara, el indice se
--     habria puesto sin el WHERE y estaria impidiendo el tramite normal
--     en vez del duplicado.
do $p$
declare
  quien uuid; tipoAct text; cual uuid; otra uuid;
begin
  select id into quien from arnes.gente where papel = 'A';
  select id into cual from arnes.escenario where clave = 'viva';
  -- La misma que se resuelve: «pedirla otra vez». Con otro tipo cualquiera
  -- dejaba a A con una parafiscal viva que choca con las pruebas de «hoy».
  select tipo into tipoAct from public.tramites where id = cual;

  update public.tramites set estado = 'en_revision'  where id = cual;
  update public.tramites set estado = 'ante_el_ente' where id = cual;
  update public.tramites set estado = 'resuelto'     where id = cual;

  insert into public.tramites (inversionista, tipo, estado)
  values (quien, tipoAct, 'borrador') returning id into otra;
  update public.tramites set estado = 'enviado' where id = otra;

  perform arnes.comprueba('una viva: con la anterior RESUELTA si se puede otra',
                          true, 'entro la del ano siguiente');
exception when others then
  perform arnes.comprueba('una viva: con la anterior RESUELTA si se puede otra',
                          false, sqlerrm);
end
$p$;

-- 4 · y una DEVUELTA tampoco estorba: volver a mandarla es justo lo que
--     se le esta pidiendo al inversionista.
do $p$
declare
  quien uuid; tipoAct text; cual uuid;
begin
  select id into quien from arnes.gente where papel = 'A';
  select codigo into tipoAct from public.tipos_tramite where activo limit 1 offset 7;
  select id into cual from public.tramites
   where inversionista = quien and tipo = tipoAct and estado = 'enviado' limit 1;

  update public.tramites set estado = 'devuelto' where id = cual;
  update public.tramites set estado = 'enviado'  where id = cual;

  perform arnes.comprueba('una viva: una devuelta se puede volver a mandar',
                          true, 'entro');
exception when others then
  perform arnes.comprueba('una viva: una devuelta se puede volver a mandar',
                          false, sqlerrm);
end
$p$;


-- ══ 10 · EL HILO DEL EXPEDIENTE ══════════════════════════════════════
-- Lo que hay que comprobar no es que se pueda escribir -eso es facil-,
-- sino las cuatro reglas que hacen que un hilo sirva de algo: que hable
-- en los dos sentidos, que nadie firme por otro, que nadie lea el de
-- otro, y que lo dicho no se reescriba.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $p$
declare
  cual uuid; tipoAct text;
begin
  select codigo into tipoAct from public.tipos_tramite where activo limit 1 offset 8;
  insert into public.tramites (inversionista, tipo, estado)
  values (auth.uid(), tipoAct, 'borrador') returning id into cual;
  insert into arnes.escenario values ('hilo', cual);

  insert into public.tramite_mensajes (tramite, texto)
  values (cual, 'El comprobante lo tengo escaneado del banco, ¿vale asi?');
end
$p$;

select arnes.comprueba(
  'hilo: el inversionista escribe en su expediente',
  (select count(*) = 1 from public.tramite_mensajes
    where tramite = (select id from arnes.escenario where clave = 'hilo')));

select arnes.comprueba(
  'hilo: y queda marcado como NO del equipo',
  (select del_equipo = false from public.tramite_mensajes
    where tramite = (select id from arnes.escenario where clave = 'hilo')));

-- ── la firma la pone la base ──
-- Se manda a nombre de otro a proposito. Tiene que quedar con el mio.
do $p$
declare otro uuid;
begin
  select id into otro from arnes.gente where papel = 'G';
  insert into public.tramite_mensajes (tramite, texto, autor, del_equipo)
  values ((select id from arnes.escenario where clave = 'hilo'),
          'esto lo escribio el CIIP, de verdad de la buena', otro, true);

  perform arnes.comprueba('hilo: nadie firma por otro',
    (select autor = auth.uid() and del_equipo = false
       from public.tramite_mensajes
      where texto like 'esto lo escribio el CIIP%'),
    'quedo con el autor de verdad');
end
$p$;

-- ── el equipo contesta ──
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $p$
begin
  insert into public.tramite_mensajes (tramite, texto)
  values ((select id from arnes.escenario where clave = 'hilo'),
          'Sirve el del banco si lleva el sello. Sube el sellado, por favor.');
end
$p$;

select arnes.comprueba(
  'hilo: el equipo contesta, y se sabe que es el equipo (esto TIENE que salir)',
  (select count(*) = 1 from public.tramite_mensajes
    where tramite = (select id from arnes.escenario where clave = 'hilo')
      and del_equipo = true));

select arnes.comprueba(
  'hilo: la conversacion tiene las tres lineas, en orden',
  (select count(*) = 3 from public.tramite_mensajes
    where tramite = (select id from arnes.escenario where clave = 'hilo')));

-- ── lo dicho no se reescribe ──
-- Se mira el RESULTADO, no si salta una excepcion. Hay dos cerraduras
-- puestas -no hay politica de update ni de delete, y ademas un trigger lo
-- prohibe- y la de fuera actua primero: RLS deja la operacion en CERO
-- filas, asi que el trigger ni llega a mirar y no hay excepcion que
-- recoger. La primera version de estas dos pruebas esperaba el error y
-- salia en rojo con el comportamiento correcto delante.
do $p$
declare cuantos int;
begin
  update public.tramite_mensajes set texto = 'yo nunca dije eso'
   where tramite = (select id from arnes.escenario where clave = 'hilo');
  get diagnostics cuantos = row_count;
  perform arnes.comprueba('hilo: un mensaje no se reescribe',
    cuantos = 0 and not exists (
      select 1 from public.tramite_mensajes where texto = 'yo nunca dije eso'),
    'no toco ninguna fila');
exception when others then
  perform arnes.comprueba('hilo: un mensaje no se reescribe', true, sqlerrm);
end
$p$;

do $p$
declare cuantos int; antes int;
begin
  select count(*) into antes from public.tramite_mensajes
   where tramite = (select id from arnes.escenario where clave = 'hilo');
  delete from public.tramite_mensajes
   where tramite = (select id from arnes.escenario where clave = 'hilo');
  get diagnostics cuantos = row_count;
  perform arnes.comprueba('hilo: ni se borra',
    cuantos = 0 and antes = (select count(*) from public.tramite_mensajes
      where tramite = (select id from arnes.escenario where clave = 'hilo')),
    'siguen las mismas');
exception when others then
  perform arnes.comprueba('hilo: ni se borra', true, sqlerrm);
end
$p$;

-- ── nadie lee el hilo de otro ──
-- Y esto SI se puede comprobar aqui, porque se entra con rol y con sub.
select arnes.soy('00000000-0000-0000-0000-0000000000ff'::uuid);
select arnes.comprueba(
  'hilo: un desconocido no lee la conversacion ajena',
  (select count(*) = 0 from public.tramite_mensajes
    where tramite = (select id from arnes.escenario where clave = 'hilo')));

do $p$
begin
  insert into public.tramite_mensajes (tramite, texto)
  values ((select id from arnes.escenario where clave = 'hilo'), 'me cuelo');
  perform arnes.comprueba('hilo: ni escribe en ella', false, 'ESCRIBIO');
exception when others then
  perform arnes.comprueba('hilo: ni escribe en ella', true, sqlerrm);
end
$p$;

-- ── el adjunto tiene que ser del mismo expediente ──
-- Sin esta regla, colgar el id de un documento ajeno y mirar que sale
-- seria una forma de leer la boveda de otro.
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $p$
declare
  mio uuid; tipoDoc text;
begin
  select codigo into tipoDoc from public.tipos_documento where codigo = 'otro';
  insert into public.documentos (inversionista, tipo, archivo, nombre_original)
  values (auth.uid(), tipoDoc, auth.uid() || '/foto-del-hilo.pdf', 'foto-del-hilo.pdf')
  returning id into mio;

  insert into public.tramite_mensajes (tramite, texto, documento)
  values ((select id from arnes.escenario where clave = 'hilo'), 'aqui va la foto', mio);

  perform arnes.comprueba('hilo: se puede adjuntar un papel propio (esto TIENE que salir)',
    (select count(*) = 1 from public.tramite_mensajes
      where documento = mio), 'adjuntado');
end
$p$;

-- Y ahora el de otra persona. El del equipo sirve: es de G, no de A.
reset role;
do $p$
declare
  ajeno uuid; quien uuid; tipoDoc text;
begin
  select id into quien from arnes.gente where papel = 'G';
  select codigo into tipoDoc from public.tipos_documento where codigo = 'otro';
  insert into public.documentos (inversionista, tipo, archivo, nombre_original)
  values (quien, tipoDoc, quien || '/papel-ajeno.pdf', 'papel-ajeno.pdf')
  returning id into ajeno;
  insert into arnes.escenario values ('ajeno', ajeno);
end
$p$;

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $p$
begin
  insert into public.tramite_mensajes (tramite, texto, documento)
  values ((select id from arnes.escenario where clave = 'hilo'),
          'a ver que hay aqui dentro',
          (select id from arnes.escenario where clave = 'ajeno'));
  perform arnes.comprueba('hilo: NO se adjunta el papel de otra persona', false, 'LO ADJUNTO');
exception when others then
  perform arnes.comprueba('hilo: NO se adjunta el papel de otra persona', true, sqlerrm);
end
$p$;

-- ── y un mensaje vacio sin adjunto no dice nada ──
do $p$
begin
  insert into public.tramite_mensajes (tramite, texto)
  values ((select id from arnes.escenario where clave = 'hilo'), '   ');
  perform arnes.comprueba('hilo: un mensaje vacio no entra', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('hilo: un mensaje vacio no entra', true, sqlerrm);
end
$p$;

reset role;


-- ══ 11 · EL EQUIPO TAMBIEN ADJUNTA ═══════════════════════════════════
-- Un hilo donde solo una parte puede mandar una foto no es una
-- conversacion. Pero el permiso tiene que ser estrecho: lo que importa de
-- estas cuatro son las dos ultimas.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));

do $p$
declare
  duenio uuid; doc uuid;
begin
  select inversionista into duenio from public.tramites
   where id = (select id from arnes.escenario where clave = 'hilo');

  insert into public.documentos (inversionista, tipo, archivo, nombre_original, estado)
  values (duenio, 'otro', duenio || '/emitidos/aclaracion.pdf', 'aclaracion.pdf', 'cargado')
  returning id into doc;

  insert into public.tramite_mensajes (tramite, texto, documento)
  values ((select id from arnes.escenario where clave = 'hilo'),
          'Te dejo un ejemplo de como tiene que verse el sello.', doc);

  perform arnes.comprueba('hilo: el equipo adjunta un papel en la boveda del inversionista',
    (select count(*) = 1 from public.tramite_mensajes
      where documento = doc and del_equipo = true), 'adjuntado');
exception when others then
  perform arnes.comprueba('hilo: el equipo adjunta un papel en la boveda del inversionista',
                          false, sqlerrm);
end
$p$;

-- Y NO puede colar un recaudo con nombre propio. Si apareciera en tu
-- boveda un 'rif_personal' que no subiste tu, el tramite que lo pide lo
-- daria por presentado.
do $p$
declare duenio uuid;
begin
  select inversionista into duenio from public.tramites
   where id = (select id from arnes.escenario where clave = 'hilo');
  insert into public.documentos (inversionista, tipo, archivo, nombre_original, estado)
  values (duenio, 'rif_personal', duenio || '/emitidos/colado.pdf', 'colado.pdf', 'cargado');
  perform arnes.comprueba('hilo: pero NO puede colar un recaudo con nombre propio',
                          false, 'LO METIO');
exception when others then
  perform arnes.comprueba('hilo: pero NO puede colar un recaudo con nombre propio',
                          true, sqlerrm);
end
$p$;

-- Ni darlo por validado. Lo que manda el CIIP en una conversacion es una
-- aclaracion, no un papel dado por bueno; y de paso, un 'validado' el
-- inversionista ya no lo puede borrar.
do $p$
declare duenio uuid;
begin
  select inversionista into duenio from public.tramites
   where id = (select id from arnes.escenario where clave = 'hilo');
  insert into public.documentos (inversionista, tipo, archivo, nombre_original, estado)
  values (duenio, 'otro', duenio || '/emitidos/dado-por-bueno.pdf', 'x.pdf', 'validado');
  perform arnes.comprueba('hilo: ni darlo por validado', false, 'LO VALIDO');
exception when others then
  perform arnes.comprueba('hilo: ni darlo por validado', true, sqlerrm);
end
$p$;

-- Y el inversionista LO VE: un adjunto que el equipo manda y el otro no
-- puede abrir es un adjunto que no sirve.
select arnes.soy((select id from arnes.gente where papel = 'A'));
select arnes.comprueba(
  'hilo: y el inversionista ve lo que le adjunto el equipo (esto TIENE que salir)',
  (select count(*) > 0 from public.tramite_mensajes m
    join public.documentos d on d.id = m.documento
   where m.del_equipo = true and d.nombre_original = 'aclaracion.pdf'));


-- ══ 12 · QUIEN PUEDE LLAMAR A LAS FUNCIONES ══════════════════════════
-- La ultima seccion, y la que este arnes no supo ver a tiempo.
--
-- Las politicas de RLS tapan las TABLAS. Una funcion `security definer`
-- no es una tabla: corre con los permisos de quien la escribio y se salta
-- el RLS por definicion. Lo unico que la protege es quien tiene EXECUTE.
--
-- Y ahi estaba el agujero. Supabase deja puesto un `alter default
-- privileges` que concede EXECUTE sobre toda funcion nueva de public a
-- anon, authenticated y service_role. Los archivos escribian
-- `revoke ... from public`, que parece lo correcto y no quita nada: el
-- permiso no venia de PUBLIC, venia de cada rol por su nombre. Hasta
-- correr las cerraduras contra un Supabase de verdad, esto estaba verde
-- aqui y abierto alli.
--
-- El doble ya imita esa costumbre (ver el final de postgres-doble.sql),
-- asi que estas comprobaciones fallan si se quitan los revoke.

-- La grave: recorre la boveda entera y ESCRIBE en el buzon de salida.
-- La llama el mensajero con la clave de servidor. Nadie mas.
select arnes.comprueba(
  'funciones: el barrido de avisos no lo dispara la clave anonima',
  not has_function_privilege('anon', 'public.avisar_de_lo_que_vence(int)', 'execute'),
  'anon SI puede llamarla');

select arnes.comprueba(
  'funciones: ni lo dispara quien haya entrado',
  not has_function_privilege('authenticated', 'public.avisar_de_lo_que_vence(int)', 'execute'),
  'authenticated SI puede llamarla');

-- Marcar «te vi» es de quien ha entrado; sin cuenta no apunta a nadie.
select arnes.comprueba(
  'funciones: tocar_visto() no la llama un desconocido',
  not has_function_privilege('anon', 'public.tocar_visto()', 'execute'),
  'anon SI puede llamarla');

select arnes.comprueba(
  'funciones: pero quien entra si marca su visto (esto TIENE que salir)',
  has_function_privilege('authenticated', 'public.tocar_visto()', 'execute'),
  'authenticated NO puede');

-- Y las que tienen que quedar abiertas, para que cerrar no se pase de
-- largo. Quien verifica un documento es un tercero con el papel en la
-- mano: no tiene cuenta en la ventanilla ni tiene por que tenerla.
select arnes.comprueba(
  'funciones: verificar un documento sigue abierto sin entrar (esto TIENE que salir)',
  has_function_privilege('anon', 'public.verificar_documento(text)', 'execute'),
  'anon NO puede: se cerro de mas');

-- es_gestor() y es_admin() las llaman las propias politicas de RLS. Si se
-- le quita EXECUTE a anon, una consulta anonima a cualquier tabla con esas
-- politicas revienta con un error de permisos en vez de contestar vacio;
-- y un error dice mas de lo que dice el silencio.
select arnes.comprueba(
  'funciones: es_gestor() la puede llamar cualquiera (esto TIENE que salir)',
  has_function_privilege('anon', 'public.es_gestor()', 'execute'),
  'anon NO puede: las politicas van a reventar en vez de contestar vacio');


-- ══ 13 · EL HILO DE UNA CITA ═════════════════════════════════════════
-- La conversacion de quien todavia no ha empezado ningun tramite. Cuelga
-- de una cita, y una cita con tipo_tramite null es -segun el propio
-- supabase-citas.sql- "una consulta general".
--
-- Se prueba lo mismo que en el hilo del expediente, porque los agujeros
-- son los mismos: que nadie firme por otro, que no se cuele el papel de
-- un tercero, que lo dicho no se reescriba y que no se lea lo ajeno.

do $p$
declare
  quienA uuid;
  laCita uuid;
begin
  select id into quienA from arnes.gente where papel = 'A';
  insert into public.citas (inversionista, tipo_tramite, modo, desde, hasta, nota)
  values (quienA, null, 'video', current_date, current_date + 7,
          'Todavia no se por donde empezar')
  returning id into laCita;
  insert into arnes.escenario values ('cita_general', laCita);
end
$p$;

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $p$
declare laCita uuid;
begin
  select id into laCita from arnes.escenario where clave = 'cita_general';
  insert into public.cita_mensajes (cita, texto)
  values (laCita, 'Hola, quiero invertir en agroindustria. Por donde empiezo?');
  perform arnes.comprueba('hilo cita: se escribe en la propia cita', true, '');
exception when others then
  perform arnes.comprueba('hilo cita: se escribe en la propia cita', false, sqlerrm);
end
$p$;

select arnes.comprueba(
  'hilo cita: y queda marcado como NO del equipo',
  (select not del_equipo from public.cita_mensajes
    where cita = (select id from arnes.escenario where clave = 'cita_general')
    order by creado_en limit 1));

-- Nadie firma por otro: se manda con el autor de B y tiene que quedar el
-- de A, que es quien escribe.
do $p$
declare laCita uuid; otro uuid;
begin
  select id into laCita from arnes.escenario where clave = 'cita_general';
  select id into otro from arnes.gente where papel = 'B';
  insert into public.cita_mensajes (cita, texto, autor, del_equipo)
  values (laCita, 'firmado por otro', otro, true);
  perform arnes.comprueba(
    'hilo cita: nadie firma por otro',
    (select autor = auth.uid() and not del_equipo from public.cita_mensajes
      where cita = laCita and texto = 'firmado por otro'),
    'se guardo con el autor ajeno');
exception when others then
  perform arnes.comprueba('hilo cita: nadie firma por otro', false, sqlerrm);
end
$p$;

-- El papel de OTRA persona no se adjunta. Sin esto, el hilo seria una
-- forma de leer la boveda ajena: adjunta un id cualquiera y mira que sale.
--
-- El papel ajeno se crea AQUI, y no se busca uno que hubiera. Se buscaba
-- entre los de B, y B se borra en la seccion 3: no tenia ninguno, la
-- prueba se iba por el atajo del 'no habia ninguno' y salia verde. Se vio
-- quitando la comprobacion del trigger a proposito y comprobando que la
-- tanda NO se ponia roja, que es lo unico que distingue una prueba de un
-- adorno. Se usa la cuenta del equipo, que sigue viva hasta el final.
reset role;
do $p$
declare deG uuid; tipoDoc text; laCita uuid;
begin
  select id into deG from arnes.gente where papel = 'G';
  select codigo into tipoDoc from public.tipos_documento limit 1;
  insert into public.documentos (inversionista, tipo, archivo, nombre_original, estado)
  values (deG, tipoDoc, deG || '/papel-del-equipo.pdf', 'papel-del-equipo.pdf', 'cargado')
  returning id into laCita;
  insert into arnes.escenario values ('papel_ajeno', laCita);
end
$p$;
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $p$
declare laCita uuid; ajeno uuid;
begin
  select id into laCita from arnes.escenario where clave = 'cita_general';
  select id into ajeno  from arnes.escenario where clave = 'papel_ajeno';
  insert into public.cita_mensajes (cita, texto, documento)
  values (laCita, 'mira este', ajeno);
  perform arnes.comprueba('hilo cita: NO se adjunta el papel de otra persona', false, 'LO ADJUNTO');
exception when others then
  perform arnes.comprueba('hilo cita: NO se adjunta el papel de otra persona', true, sqlerrm);
end
$p$;

-- Un mensaje vacio y sin adjunto no dice nada y ensucia el hilo.
do $p$
declare laCita uuid;
begin
  select id into laCita from arnes.escenario where clave = 'cita_general';
  insert into public.cita_mensajes (cita, texto) values (laCita, '   ');
  perform arnes.comprueba('hilo cita: un mensaje vacio no entra', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('hilo cita: un mensaje vacio no entra', true, sqlerrm);
end
$p$;

-- Lo dicho no se reescribe ni se borra. Y esto NO se comprueba esperando
-- una excepcion, aunque el trigger la lance: sobre cita_mensajes no hay
-- politica de update ni de delete, asi que el RLS descarta las filas
-- ANTES de que el trigger llegue a verlas. Postgres no da error -no ha
-- pasado nada malo, simplemente no habia nada que tocar- y una prueba que
-- esperase el error saldria roja con las dos cerraduras funcionando.
-- Se mira el resultado: que siga diciendo lo que decia, y que siga estando.
do $p$
declare laCita uuid; cuantos int;
begin
  select id into laCita from arnes.escenario where clave = 'cita_general';
  select count(*) into cuantos from public.cita_mensajes where cita = laCita;

  begin
    update public.cita_mensajes set texto = 'otra cosa' where cita = laCita;
  exception when others then null;
  end;
  perform arnes.comprueba(
    'hilo cita: un mensaje no se reescribe',
    not exists (select 1 from public.cita_mensajes
                 where cita = laCita and texto = 'otra cosa'),
    'lo reescribio');

  begin
    delete from public.cita_mensajes where cita = laCita;
  exception when others then null;
  end;
  perform arnes.comprueba(
    'hilo cita: ni se borra',
    (select count(*) from public.cita_mensajes where cita = laCita) = cuantos,
    'se llevo ' || (cuantos - (select count(*) from public.cita_mensajes where cita = laCita))::text);
end
$p$;

-- Y un desconocido no lee ni escribe en la cita de otro.
select arnes.soy((select id from arnes.gente where papel = 'B'));

select arnes.comprueba(
  'hilo cita: un desconocido no lee la conversacion ajena',
  (select count(*) = 0 from public.cita_mensajes
    where cita = (select id from arnes.escenario where clave = 'cita_general')));

do $p$
declare laCita uuid;
begin
  select id into laCita from arnes.escenario where clave = 'cita_general';
  insert into public.cita_mensajes (cita, texto) values (laCita, 'me cuelo');
  perform arnes.comprueba('hilo cita: ni escribe en ella', false, 'ESCRIBIO');
exception when others then
  perform arnes.comprueba('hilo cita: ni escribe en ella', true, sqlerrm);
end
$p$;

-- El equipo contesta, y se sabe que es el equipo. Es la vuelta que le
-- faltaba a la cita: hasta ahora tenia una nota de ida y ninguna de
-- regreso, asi que la conversacion seguia por fuera.
select arnes.soy((select id from arnes.gente where papel = 'G'));

do $p$
declare laCita uuid;
begin
  select id into laCita from arnes.escenario where clave = 'cita_general';
  insert into public.cita_mensajes (cita, texto)
  values (laCita, 'Bienvenido. Empieza por la visa de inversionista.');
  perform arnes.comprueba(
    'hilo cita: el equipo contesta, y consta que es el equipo (esto TIENE que salir)',
    (select del_equipo from public.cita_mensajes
      where cita = laCita and texto like 'Bienvenido%'),
    'no quedo marcado como del equipo');
exception when others then
  perform arnes.comprueba('hilo cita: el equipo contesta, y consta que es el equipo (esto TIENE que salir)', false, sqlerrm);
end
$p$;

reset role;


-- ══ 13.1 · LA CONSULTA ═══════════════════════════════════════════════
-- Esta seccion no existia. El SQL de las consultas se escribio a mano al
-- final de TODO-EN-ORDEN.sql, sin archivo propio, asi que esta tanda ni
-- siquiera lo ejecutaba: la funcion mas nueva del sistema -y la unica que
-- ya esta viva en produccion- no la miraba nadie aqui.
--
-- Lo que se prueba es lo que PROBAR-CERRADURAS no puede: los disparadores
-- por dentro. Aquel entra por HTTP con sesion y se topa con RLS antes; lo
-- de aqui corre por la puerta de servicio, que es por donde entra el
-- equipo del CIIP desde el SQL Editor.
--
-- ── LA SESION SE PONE A PROPOSITO, Y ESO COSTO TRES ROJAS ──
-- La primera version de esta seccion heredaba la sesion que dejaba el
-- bloque anterior -la del GESTOR- y de ahi salieron tres fallos que no lo
-- eran: la consulta nacia siendo del gestor y no de A, asi que «cambio de
-- dueño» era falso sin que nada cambiara; el papel supuestamente ajeno
-- era del mismo gestor, asi que el disparador hacia bien en dejarlo
-- pasar; y «su dueño no la borra» leia a traves de RLS, o sea que
-- «no la veo» se contaba como «se la llevaron».
--
-- Las tres median otra cosa. Por eso aqui se dice quien eres antes de
-- cada paso, y lo que se comprueba se lee SIN RLS delante: mirar el
-- resultado de una cerradura a traves de otra cerradura no dice nada.
reset role;
select arnes.soy(null);

do $p$
declare
  quienA uuid;
  laCons uuid;
begin
  select id into quienA from arnes.gente where papel = 'A';
  -- Sin sesion, el disparador de la firma respeta lo que se le pasa: es la
  -- puerta de servicio, la misma por la que se siembran datos de ejemplo.
  insert into public.consultas (inversionista, asunto)
  values (quienA, 'Necesito visa para invertir en agroindustria?')
  returning id into laCons;
  insert into arnes.escenario values ('consulta_suelta', laCons);

  perform arnes.comprueba(
    'consulta: nace de quien se dice, por la puerta de servicio',
    (select inversionista = quienA from public.consultas where id = laCons),
    'nacio de otro');
end
$p$;

-- La fecha de resuelto la pone la base, y CUADRA con el estado. Sin esto
-- una consulta puede quedar 'resuelta' sin fecha -y el informe de cuanto
-- tarda el equipo en contestar mide humo- o con la fecha de la vez
-- anterior, que es peor porque parece un dato.
do $p$
declare laCons uuid;
begin
  select id into laCons from arnes.escenario where clave = 'consulta_suelta';

  perform arnes.comprueba(
    'consulta: nace sin fecha de resuelta',
    (select resuelto_en is null from public.consultas where id = laCons),
    'nacio con fecha');

  update public.consultas set estado = 'resuelta' where id = laCons;
  perform arnes.comprueba(
    'consulta: al resolverla se le pone la fecha sola',
    (select resuelto_en is not null from public.consultas where id = laCons),
    'se resolvio sin fecha');

  -- Y al reabrirla se quita. Una consulta abierta con fecha de resuelta
  -- es una fila que se contradice a si misma.
  update public.consultas set estado = 'en_curso' where id = laCons;
  perform arnes.comprueba(
    'consulta: y al reabrirla se le quita',
    (select resuelto_en is null from public.consultas where id = laCons),
    'se quedo con la fecha vieja');
end
$p$;

-- De quien es una consulta no se cambia NUNCA, ni por la puerta de
-- servicio. Una conversacion que cambia de dueño es una conversacion
-- privada apareciendo en la pantalla de otro. El disparador lo pisa con
-- el valor viejo en vez de dar error, asi que no se espera excepcion: se
-- mira que siga siendo de quien era.
-- Se intenta mudarla al GESTOR y no a B, y eso lo enseño el sabotaje: con
-- B, al quitar la linea que fija el dueño, la tanda no se ponia roja sino
-- que REVENTABA con una violacion de clave foranea. La cuenta B ya no
-- existe a esta altura -la borra la seccion del archivo que se va con su
-- ficha- y el update solo llegaba a intentarse de verdad cuando el
-- disparador estaba roto. Una prueba que al fallar mata la tanda no dice
-- cual fallo. La del equipo sigue viva hasta el final.
do $p$
declare laCons uuid; quienA uuid; otro uuid;
begin
  select id into laCons from arnes.escenario where clave = 'consulta_suelta';
  select id into quienA from arnes.gente where papel = 'A';
  select id into otro   from arnes.gente where papel = 'G';
  update public.consultas set inversionista = otro where id = laCons;
  perform arnes.comprueba(
    'consulta: no se le puede cambiar el dueño',
    (select inversionista = quienA from public.consultas where id = laCons),
    'cambio de dueño');
end
$p$;

-- El adjunto tiene que ser de la boveda del dueño de la consulta. Sin
-- esto, y como el hilo enseña sus adjuntos, colgar un id cualquiera seria
-- una forma de leer la boveda ajena: pruebas a ver que sale.
-- El 'papel_ajeno' es un documento del GESTOR y la consulta es de A, asi
-- que son de dos personas distintas de verdad. Cuando no lo eran, esta
-- prueba salia roja y tenia razon.
do $p$
declare laCons uuid; ajeno uuid;
begin
  select id into laCons from arnes.escenario where clave = 'consulta_suelta';
  select id into ajeno  from arnes.escenario where clave = 'papel_ajeno';
  insert into public.consulta_mensajes (consulta, texto, documento)
  values (laCons, 'mira este', ajeno);
  perform arnes.comprueba('consulta: NO se adjunta el papel de otra persona', false, 'LO ADJUNTO');
exception when others then
  perform arnes.comprueba('consulta: NO se adjunta el papel de otra persona', true, sqlerrm);
end
$p$;

-- Un mensaje vacio y sin adjunto no dice nada y ensucia el hilo.
do $p$
declare laCons uuid;
begin
  select id into laCons from arnes.escenario where clave = 'consulta_suelta';
  insert into public.consulta_mensajes (consulta, texto) values (laCons, '   ');
  perform arnes.comprueba('consulta: un mensaje vacio no entra', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('consulta: un mensaje vacio no entra', true, sqlerrm);
end
$p$;

do $p$
declare laCons uuid; cuantos int;
begin
  select id into laCons from arnes.escenario where clave = 'consulta_suelta';
  insert into public.consulta_mensajes (consulta, texto) values (laCons, 'una pregunta');
  select count(*) into cuantos from public.consulta_mensajes where consulta = laCons;
  perform arnes.comprueba('consulta: se puede escribir en ella (esto TIENE que salir)',
                          cuantos > 0, 'no entro ningun mensaje');
end
$p$;

-- ── BORRAR UNA CONSULTA: LAS DOS PUERTAS ──
-- Por la de la aplicacion NO se borra: no hay politica de delete y RLS
-- descarta la fila. No hay error, simplemente no pasa nada, que es lo que
-- se quiere -la conversacion con un inversionista es registro-.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $p$
declare laCons uuid;
begin
  select id into laCons from arnes.escenario where clave = 'consulta_suelta';
  begin
    delete from public.consultas where id = laCons;
  exception when others then null;   -- da igual como se niegue; importa que siga ahi
  end;
end
$p$;

-- Y se comprueba DESDE FUERA, sin RLS delante. Mirarlo con la sesion de A
-- puesta diria «no esta» cuando lo cierto seria «no la ve», que es otra
-- cosa: asi es como esta prueba salio roja la primera vez.
reset role;
select arnes.soy(null);

select arnes.comprueba(
  'consulta: su dueño no la borra',
  exists (select 1 from public.consultas
           where id = (select id from arnes.escenario where clave = 'consulta_suelta')));

-- Y por la puerta de servicio SI se borra, y se lleva sus mensajes. Es la
-- unica forma de limpiar una conversacion de prueba, y hace falta que
-- funcione: el arnes de cerraduras siembra dos cada vez que corre y no
-- puede recogerlas de ninguna otra manera.
do $p$
declare laCons uuid;
begin
  select id into laCons from arnes.escenario where clave = 'consulta_suelta';
  delete from public.consultas where id = laCons;
  perform arnes.comprueba(
    'consulta: por la puerta de servicio si se borra',
    not exists (select 1 from public.consultas where id = laCons),
    'sigue ahi');
  perform arnes.comprueba(
    'consulta: y se lleva sus mensajes',
    (select count(*) = 0 from public.consulta_mensajes where consulta = laCons),
    'quedaron mensajes sin consulta');
end
$p$;



-- ══ 14 · LO QUE PIDIO LA REVISION DEL 2 DE SEPTIEMBRE ════════════════
-- Cada comprobacion es una frase del informe convertida en algo que
-- Postgres puede decir que si o que no. Sin esto, "hecho" seria una
-- opinion.

select arnes.comprueba(
  'informe: el RNC pasa a la fase 3, Operar',
  (select fase = 3 from public.tipos_tramite where codigo = 'rnc'),
  (select 'esta en la fase ' || fase::text from public.tipos_tramite where codigo = 'rnc'));

-- El trámite que faltaba. Se comprobo que NO estaba antes de escribirlo:
-- ni en tipos_tramite ni en pasos.js.
select arnes.comprueba(
  'informe: existe la firma en el Registro de Extranjeros (SISREF)',
  (select count(*) = 1 from public.tipos_tramite
    where codigo = 'registro_extranjeros_saren' and ref_panel = 'c32' and fase = 2 and activo));

-- Y entra ENCADENADO, que es lo que lo hace util: sin esto seria una
-- tarjeta mas en una lista de treinta y tres.
select arnes.comprueba(
  'informe: y emite la constancia que pide la constitucion',
  (select emite = 'constancia_sisref' from public.tipos_tramite
    where codigo = 'registro_extranjeros_saren'));

select arnes.comprueba(
  'informe: la constancia del SISREF esta en el catalogo de recaudos',
  (select count(*) = 1 from public.tipos_documento where codigo = 'constancia_sisref'));

-- El modulo para los apoderados. El tipo de documento 'poder' existia
-- desde el primer dia; lo que no existia era el sitio donde el CIIP lo
-- mire y lo de por bueno.
select arnes.comprueba(
  'informe: existe la acreditacion de representacion legal',
  (select count(*) = 1 from public.tipos_tramite
    where codigo = 'poder_representacion' and ref_panel = 'c33' and fase = 1 and activo));

select arnes.comprueba(
  'informe: y emite el poder, que ya estaba en la boveda',
  (select emite = 'poder' from public.tipos_tramite where codigo = 'poder_representacion'));

-- Los tres niveles.
select arnes.comprueba(
  'informe: los cinco obligatorios de la fase 1 estan marcados',
  (select count(*) = 5 from public.tipos_tramite
    where nivel = 'obligatorio' and fase = 1),
  (select coalesce(string_agg(ref_panel, ' ' order by ref_panel), 'ninguno')
     from public.tipos_tramite where nivel = 'obligatorio' and fase = 1));

-- Los opcionales de la fase 1. Eran seis y la fase once el 2-9-2026; el
-- catalogo cambio despues por decision del CIIP: se quitaron tres fichas
-- (antecedentes, constancia de domicilio, visa de dependientes), la
-- licencia (c4) y el certificado medico (c21) se apagaron el 25-9, y entro
-- la visa de inversionista (c38) como 'esencial'. Puesto al dia el
-- 25-9-2026 con lo que hay en produccion, que coincide con esto pieza a
-- pieza. Lo que se sigue exigiendo es lo que importaba: que ninguno de la
-- fase 1 se quede sin marcar y parezca obligatorio sin serlo.
select arnes.comprueba(
  'informe: los opcionales de la fase 1 son la firma y los dos apagados',
  (select coalesce(string_agg(ref_panel, ' ' order by ref_panel), '') = 'c19 c21 c4'
     from public.tipos_tramite where nivel = 'opcional' and fase = 1),
  (select coalesce(string_agg(ref_panel, ' ' order by ref_panel), 'ninguno')
     from public.tipos_tramite where nivel = 'opcional' and fase = 1));

-- Y que no quede ninguno de la fase 1 sin nivel.
select arnes.comprueba(
  'informe: la fase 1, toda marcada',
  (select count(*) = 0 from public.tipos_tramite
    where fase = 1 and coalesce(nivel, '') not in ('obligatorio','opcional','esencial')),
  (select coalesce(string_agg(ref_panel || '=' || coalesce(nivel, 'nulo'), ' ' order by ref_panel), '-')
     from public.tipos_tramite
    where fase = 1 and coalesce(nivel, '') not in ('obligatorio','opcional','esencial')));

select arnes.comprueba(
  'informe: y los cinco de la fase 2',
  (select count(*) = 5 from public.tipos_tramite
    where nivel = 'obligatorio' and fase = 2),
  (select coalesce(string_agg(ref_panel, ' ' order by ref_panel), 'ninguno')
     from public.tipos_tramite where nivel = 'obligatorio' and fase = 2));

-- Los tres que el informe nombra uno a uno como "indispensables para el
-- comercio, mas no trabas bloqueantes".
select arnes.comprueba(
  'informe: marca, cuenta bancaria y libros son esenciales, no bloqueantes',
  (select count(*) = 3 from public.tipos_tramite
    where nivel = 'esencial'
      and codigo in ('marca', 'cuenta_bancaria', 'libros_contables')));

-- Y que no quede ninguno sin clasificar: un trámite sin nivel volveria a
-- verse igual que los demas, que es el problema que se venia a arreglar.
select arnes.comprueba(
  'informe: ningun tramite se queda sin nivel',
  (select count(*) = 0 from public.tipos_tramite
    where nivel is null or nivel not in ('obligatorio','esencial','actividad','opcional')));

-- La restriccion muerde: un nivel inventado no entra. Sin esto, un error
-- de escritura dejaria un tramite invisible para las tres vistas.
do $p$
begin
  update public.tipos_tramite set nivel = 'importantisimo' where codigo = 'rnc';
  perform arnes.comprueba('informe: un nivel inventado no entra', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('informe: un nivel inventado no entra', true, sqlerrm);
end
$p$;


-- El registro de la inversion extranjera, en la fase 4. Tenia una etapa
-- para el solo y desde el 3 de septiembre comparte la 4. Si el catalogo
-- dijera 5 y la pantalla ensenara cuatro etapas, la tarjeta seguiria
-- saliendo -el marcado manda- pero cualquier consulta por fase mentiria.
select arnes.comprueba(
  'informe: el registro de inversion esta en la fase 4',
  (select fase = 4 from public.tipos_tramite where codigo = 'registro_inversion'),
  (select fase::text from public.tipos_tramite where codigo = 'registro_inversion'));

-- Y que no quede NINGUNO en una quinta fase que ya no existe en pantalla.
select arnes.comprueba(
  'informe: ya no hay tramites en una fase 5',
  (select count(*) = 0 from public.tipos_tramite where fase = 5),
  (select coalesce(string_agg(ref_panel, ' '), 'ninguno')
     from public.tipos_tramite where fase = 5));


-- ══ 15 · EL PLIEGO DE DATOS ══════════════════════════════════════════
-- Una cuenta propia, y hay que decir por que: la B esta BORRADA desde la
-- seccion 3. Con su id, la clave foranea de persona rechazaba cualquier
-- insercion ANTES de que RLS llegara a opinar, asi que dos comprobaciones
-- de aqui salian verdes porque esa persona no existe y no porque las
-- cerraduras funcionaran. Lo dijo el sabotaje: romperlas no las ponia en
-- rojo. Es la segunda vez que pasa lo mismo en este arnes.
insert into auth.users (email, raw_user_meta_data) values
  ('d@prueba.local', '{"nombre_completo":"Delia Inversionista","pais":"Peru"}');
insert into arnes.gente (papel, id)
select 'D', id from auth.users where email = 'd@prueba.local';
-- Del punto 3 del informe del 2 de septiembre. Lo que se mide aqui no es
-- que el pliego exista -no existe todavia, y es a proposito- sino que la
-- maquinaria se comporte igual con la tabla vacia que llena.

-- Con la tabla VACIA no se le pide nada a nadie. Es lo primero porque es
-- lo que se rompe primero: una puerta cerrada con nada detras deja fuera
-- a todo el mundo, y eso pasaria el dia que esto se despliegue sin que
-- el abogado haya aprobado el texto -o sea, el dia de manana-.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
select arnes.comprueba(
  'pliego: sin pliego publicado no se le pide nada a nadie',
  public.pliego_pendiente() is null,
  coalesce(public.pliego_pendiente()::text, 'null'));
reset role;

-- Ahora se publica uno. Desde aqui, sin sesion, que es la puerta de
-- servicio: en Supabase lo hara un admin desde el panel.
insert into public.pliegos (version, titulo, texto, vigente, publicado_en)
values (1, 'Pliego de prueba',
        jsonb_build_object('es', 'Texto de prueba del pliego.'), true, now());

-- Y ahora si le falta. Este es el cambio que hace util toda la tabla: la
-- misma persona, la misma consulta, y la respuesta cambia porque hay algo
-- que aceptar.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
-- ══════════════════════════════════════════════════════════════════
--  LAS CITAS NO TIENEN FIN DE SEMANA
-- ══════════════════════════════════════════════════════════════════
--  La regla va en la base y no solo en la pantalla: si solo estuviera
--  alli, un insert a mano abriria un sabado y el panel se lo ofreceria a
--  los inversionistas sin que nadie lo hubiera decidido. Se prueba como
--  la clave de servicio, que es quien se salta las politicas: lo que se
--  mide aqui son las REGLAS de la tabla, que no se salta nadie.

reset role;

do $p$
begin
  insert into public.horario_citas (dia, desde, hasta) values (6, '09:00', '12:00');
  perform arnes.comprueba('citas: no se puede abrir un sabado', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('citas: no se puede abrir un sabado', true, sqlerrm);
end
$p$;

do $p$
begin
  insert into public.horario_citas (dia, desde, hasta) values (7, '09:00', '12:00');
  perform arnes.comprueba('citas: ni un domingo', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('citas: ni un domingo', true, sqlerrm);
end
$p$;

--  Y el viernes si. Sin esta, una regla que lo rechazara TODO pasaria las
--  dos de arriba.
do $p$
begin
  insert into public.horario_citas (dia, desde, hasta) values (5, '09:00', '12:00');
  perform arnes.comprueba('citas: y el viernes si se abre', true, 'entro');
exception when others then
  perform arnes.comprueba('citas: y el viernes si se abre', false, sqlerrm);
end
$p$;

--  Cerrar un sabado no significa nada: ese dia ya no hay citas. El 26 de
--  diciembre de 2026 es sabado.
do $p$
begin
  insert into public.cierres_citas (fecha, motivo) values ('2026-12-26', 'Sabado');
  perform arnes.comprueba('citas: no se cierra un sabado', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('citas: no se cierra un sabado', true, sqlerrm);
end
$p$;

--  Y un jueves -el 24- si.
do $p$
begin
  insert into public.cierres_citas (fecha, motivo) values ('2026-12-24', 'Navidad');
  perform arnes.comprueba('citas: y un dia de diario si se cierra', true, 'entro');
exception when others then
  perform arnes.comprueba('citas: y un dia de diario si se cierra', false, sqlerrm);
end
$p$;

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

select arnes.comprueba(
  'pliego: con uno vigente, a quien no lo acepto le falta',
  public.pliego_pendiente() = 1,
  coalesce(public.pliego_pendiente()::text, 'null'));

insert into public.pliego_aceptaciones (persona, version)
values ((select id from arnes.gente where papel = 'A'), 1);

select arnes.comprueba(
  'pliego: tras aceptarlo, ya no le falta',
  public.pliego_pendiente() is null,
  coalesce(public.pliego_pendiente()::text, 'null'));

-- La firma la pone la BASE. Se manda con el id de otro a proposito: si
-- se pudiera aceptar en nombre de un tercero, la constancia no probaria
-- nada y ademas pareceria fiable, que es peor.
-- Da igual como termine el intento -aqui choca con la clave unica,
-- porque el disparador le pone SU id y esa fila ya existe-. Lo que se
-- comprueba es el resultado: que no haya quedado nada a nombre de B.
do $d$
begin
  insert into public.pliego_aceptaciones (persona, version)
  values ((select id from arnes.gente where papel = 'D'), 1);
exception when others then
  null;
end
$d$;

-- Y AHORA el disparador, aparte. Lo de arriba lo para RLS -with check
-- (persona = auth.uid())-, asi que con el disparador roto sigue sin pasar
-- nada: la comprobacion salia verde con la firma desmontada. Era un
-- adorno, y lo dijo el sabotaje.
--
-- Se afloja RLS a proposito para medir el respaldo, igual que con la
-- inmutabilidad. Si el disparador hace su trabajo, la fila queda a nombre
-- de A aunque se pida a nombre de B.
reset role;
create policy "pliego: PRUEBA insert" on public.pliego_aceptaciones
  for insert with check (true);
insert into public.pliegos (version, titulo, texto, vigente, publicado_en)
values (50, 'Para medir la firma', jsonb_build_object('es', 'x'), false, now());
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $d$
begin
  insert into public.pliego_aceptaciones (persona, version)
  values ((select id from arnes.gente where papel = 'D'), 50);
exception when others then
  null;
end
$d$;
select arnes.comprueba(
  'pliego: la firma la pone la base, no quien escribe',
  /* coalesce, y no es adorno: sin fila la subconsulta devuelve NULL, y en
     este arnes un NULL no cuenta ni como verde ni como rojo -el informe
     hace count(*) filter (where ok) y el corte final where not ok, y NULL
     no entra en ninguno-. O sea que desaparecia de las dos cuentas y el
     sabotaje de la firma salia en verde. Sin fila = mal. */
  coalesce((select persona = (select id from arnes.gente where papel = 'A')
             from public.pliego_aceptaciones where version = 50), false),
  (select coalesce(persona::text, 'no hay fila')
     from public.pliego_aceptaciones where version = 50));
reset role;
-- arnes.nadie() y no solo reset role: el rol cambia pero la SESION sigue
-- puesta -request.jwt.claims lo guarda la conexion-, asi que auth.uid()
-- seguia siendo A y el disparador de inmutabilidad cortaba esta misma
-- limpieza. La puerta de servicio se abre estando de verdad sin sesion.
select arnes.nadie();
drop policy "pliego: PRUEBA insert" on public.pliego_aceptaciones;
delete from public.pliego_aceptaciones where version = 50;
delete from public.pliegos where version = 50;
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

select arnes.comprueba(
  'pliego: no se puede aceptar en nombre de otro',
  (select count(*) = 0 from public.pliego_aceptaciones
    where persona = (select id from arnes.gente where papel = 'D')),
  (select count(*)::text from public.pliego_aceptaciones
    where persona = (select id from arnes.gente where papel = 'D')));

-- Y a B, que no ha aceptado nada, le sigue faltando. Sin esto lo de
-- arriba podria pasar contando filas de otra manera.
select arnes.soy((select id from arnes.gente where papel = 'D'));
select arnes.comprueba(
  'pliego: y a quien no acepto le sigue faltando',
  public.pliego_pendiente() = 1,
  coalesce(public.pliego_pendiente()::text, 'null'));

-- ── lo dicho no se reescribe, y hay DOS cerraduras ──
-- Esto se escribio primero esperando un ERROR, y salio en rojo. Con
-- razon, y es la leccion que este proyecto lleva escrita desde el
-- principio y aqui se me olvido: RLS no da error cuando bloquea, DEVUELVE
-- CERO FILAS. El update se ejecuta, no toca nada, y todo el mundo tan
-- contento. Asi que se mira el RESULTADO, que es lo unico que vale.
select arnes.soy((select id from arnes.gente where papel = 'A'));

update public.pliego_aceptaciones set cuando = now() - interval '1 year'
 where persona = (select id from arnes.gente where papel = 'A');
delete from public.pliego_aceptaciones
 where persona = (select id from arnes.gente where papel = 'A');

select arnes.comprueba(
  'pliego: el consentimiento sigue ahi y con su fecha',
  (select count(*) = 1 from public.pliego_aceptaciones
    where persona = (select id from arnes.gente where papel = 'A')
      and version = 1
      and cuando > now() - interval '1 hour'),
  (select coalesce(count(*)::text, '0') from public.pliego_aceptaciones
    where persona = (select id from arnes.gente where papel = 'A')));

-- LA SEGUNDA CERRADURA. La de arriba es RLS: no hay politica de update ni
-- de delete, y por eso no toca nada. El disparador es el respaldo, «por si
-- mañana alguien añade una politica», y mientras no la haya NO SE PUEDE
-- ALCANZAR: RLS corta antes. O sea que estaba sin probar y parecia
-- probado, que es como se acumulan los adornos.
--
-- Se le pone la politica que falta, se comprueba que el disparador muerde
-- igual, y se quita. Es la unica forma de medir el respaldo sin quitar lo
-- que respalda.
reset role;
create policy "pliego: PRUEBA update" on public.pliego_aceptaciones
  for update using (true) with check (true);
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $p$
begin
  update public.pliego_aceptaciones set cuando = now() - interval '1 year'
   where persona = (select id from arnes.gente where papel = 'A');
  perform arnes.comprueba('pliego: y el disparador lo corta aunque haya politica', false, 'SE PUDO');
exception when others then
  perform arnes.comprueba('pliego: y el disparador lo corta aunque haya politica', true, sqlerrm);
end
$p$;
reset role;
drop policy "pliego: PRUEBA update" on public.pliego_aceptaciones;
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

-- Ni el inversionista publica pliegos. Cambiar el vigente es cambiar a
-- que esta consintiendo todo el mundo.
do $d$
begin
  insert into public.pliegos (version, titulo, texto, vigente, publicado_en)
  values (98, 'Mio', jsonb_build_object('es', 'Cedo todo.'), false, now());
exception when others then
  null;   /* que no entre es lo que se comprueba abajo */
end
$d$;
select arnes.comprueba(
  'pliego: un inversionista no publica pliegos',
  (select count(*) = 0 from public.pliegos where version = 98));
reset role;

-- Sin castellano no hay pliego: el instrumento que obliga es el
-- venezolano, y uno que solo existiera traducido dejaria sin saber cual
-- de las seis versiones es la que vale.
do $p$
begin
  insert into public.pliegos (version, titulo, texto, vigente)
  values (97, 'Solo ingles', jsonb_build_object('en', 'Only English.'), false);
  perform arnes.comprueba('pliego: sin castellano no entra', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('pliego: sin castellano no entra', true, sqlerrm);
end
$p$;

-- Dos vigentes a la vez seria gente aceptando pliegos distintos el mismo
-- dia, y pliego_pendiente() devolviendo uno u otro segun le diera.
do $p$
begin
  insert into public.pliegos (version, titulo, texto, vigente, publicado_en)
  values (96, 'El segundo', jsonb_build_object('es', 'Otro.'), true, now());
  perform arnes.comprueba('pliego: no caben dos vigentes', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('pliego: no caben dos vigentes', true, sqlerrm);
end
$p$;

-- Y uno vigente sin fecha de publicacion es un pliego que nadie sabe
-- desde cuando obliga.
--
-- Se apaga antes el que hay. Con el puesto, esta insercion la rechazaba
-- el indice de «uno solo vigente» ANTES de mirar la fecha, asi que la
-- comprobacion salia verde con la restriccion de la fecha desmontada:
-- estaba midiendo la cerradura de al lado.
update public.pliegos set vigente = false where vigente;
do $p$
begin
  insert into public.pliegos (version, titulo, texto, vigente)
  values (95, 'Sin fecha', jsonb_build_object('es', 'Otro.'), true);
  perform arnes.comprueba('pliego: uno vigente lleva fecha', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('pliego: uno vigente lleva fecha', true, sqlerrm);
end
$p$;
update public.pliegos set vigente = true where version = 1;

-- Solo se acepta lo VIGENTE. Una version vieja que siguiera en la tabla
-- -y siguen, que para eso se guardan- podria ser mas floja que la de hoy.
update public.pliegos set vigente = false where version = 1;
insert into public.pliegos (version, titulo, texto, vigente, publicado_en)
values (2, 'La segunda', jsonb_build_object('es', 'Texto nuevo.'), true, now());

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'D'));
do $d$
begin
  insert into public.pliego_aceptaciones (persona, version)
  values ((select id from arnes.gente where papel = 'D'), 1);
exception when others then
  null;   /* que la rechace es lo que se comprueba abajo */
end
$d$;
select arnes.comprueba(
  'pliego: no se puede aceptar una version que ya no rige',
  (select count(*) = 0 from public.pliego_aceptaciones where version = 1
     and persona = (select id from arnes.gente where papel = 'D')));

-- Y a quien acepto la 1, la 2 le vuelve a faltar. Es lo que hace que
-- versionar sirva de algo: si al cambiar el pliego nadie tuviera que
-- volver a aceptar, la version nueva no la habria consentido nadie.
select arnes.soy((select id from arnes.gente where papel = 'A'));
select arnes.comprueba(
  'pliego: al publicar una version nueva, hay que volver a aceptarla',
  public.pliego_pendiente() = 2,
  coalesce(public.pliego_pendiente()::text, 'null'));

-- Y a B, que no ha aceptado NINGUNA, le toca la 2 y no la 1. Parece la
-- misma comprobacion que la de arriba y no lo es: A tiene la 1 aceptada,
-- asi que una funcion que ignorara «vigente» le devolveria la 2 igual y
-- pasaria. B no tiene ninguna, y ahi si se distingue mirar el vigente de
-- devolver la primera que encuentre. Salia verde con «vigente» quitado.
select arnes.soy((select id from arnes.gente where papel = 'D'));
select arnes.comprueba(
  'pliego: y a quien no acepto ninguna le toca la vigente, no la vieja',
  public.pliego_pendiente() = 2,
  coalesce(public.pliego_pendiente()::text, 'null'));
select arnes.soy((select id from arnes.gente where papel = 'A'));

-- Y la vieja se puede releer: quien acepto la 1 tiene derecho a ver que
-- fue lo que acepto, aunque hoy rija la 2. Eso es medio habeas data.
select arnes.comprueba(
  'pliego: la version vieja se sigue pudiendo leer',
  (select count(*) = 1 from public.pliegos where version = 1),
  (select count(*)::text from public.pliegos where version = 1));
reset role;

-- Y anon no llama a la funcion. En Supabase el 'alter default
-- privileges' se la concede POR SU NOMBRE a los tres roles, asi que
-- revocarsela a PUBLIC no se la quita. Se comprueba como las demas.
set role anon;
select arnes.nadie();
do $p$
begin
  perform public.pliego_pendiente();
  perform arnes.comprueba('pliego: anon no puede llamar a pliego_pendiente', false, 'PUDO');
exception when insufficient_privilege then
  perform arnes.comprueba('pliego: anon no puede llamar a pliego_pendiente', true, sqlerrm);
end
$p$;
reset role;

-- Se deja la tabla como estaba: vacia. Las de mas arriba comprueban que
-- con la tabla vacia no se bloquea a nadie, y dejar un pliego publicado
-- aqui haria que esa comprobacion dependiera del orden.
select arnes.nadie();   /* por lo mismo de arriba */
delete from public.pliego_aceptaciones;
delete from public.pliegos;

reset role;

-- ── LOS TEXTOS EDITABLES (supabase-textos.sql) ────────────────────────
-- Lo que el admin cambia lo tiene que ver el inversionista, y el
-- inversionista no puede cambiarlo. En esta tanda no habia ningun admin:
-- se crea uno. El ascenso va con los disparadores apagados porque el de
-- roles, con razon, no deja que nadie se haga admin a si mismo ni que lo
-- haga quien no lo es; aqui lo hace el superusuario, que es el SQL Editor.
reset role;
select arnes.nadie();
insert into auth.users (email, raw_user_meta_data) values
  ('x@prueba.local', '{"nombre_completo":"Xiomara Admin","pais":"Venezuela"}');
insert into arnes.gente (papel, id)
select 'X', id from auth.users where email = 'x@prueba.local';
set session_replication_role = replica;
update public.perfiles set rol = 'admin' where id = (select id from arnes.gente where papel = 'X');
set session_replication_role = origin;

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'X'));
do $p$
begin
  insert into public.textos_panel (clave, idioma, texto) values ('c33.name', 'es', 'Poder de representación');
  perform arnes.comprueba('textos: el admin guarda un texto', true);
exception when others then
  perform arnes.comprueba('textos: el admin guarda un texto', false, sqlerrm);
end
$p$;
select arnes.comprueba('textos: y queda firmado por quien lo cambio',
  coalesce((select actualizado_por = (select id from arnes.gente where papel = 'X')
              from public.textos_panel where clave = 'c33.name' and idioma = 'es'), false));
do $p$
begin
  -- Lo que hace el panel: upsert por (clave, idioma).
  insert into public.textos_panel (clave, idioma, texto) values ('c33.name', 'es', 'Poder de representación legal')
  on conflict (clave, idioma) do update set texto = excluded.texto;
  perform arnes.comprueba('textos: el admin lo vuelve a cambiar',
    (select texto from public.textos_panel where clave = 'c33.name' and idioma = 'es') = 'Poder de representación legal');
exception when others then
  perform arnes.comprueba('textos: el admin lo vuelve a cambiar', false, sqlerrm);
end
$p$;

-- El inversionista B: lo ve, y no lo toca.
select arnes.soy((select id from arnes.gente where papel = 'B'));
select arnes.comprueba('textos: el inversionista ve el texto que cambio el admin',
  (select count(*) = 1 from public.textos_panel
    where clave = 'c33.name' and idioma = 'es' and texto = 'Poder de representación legal'),
  (select count(*)::text || ' fila(s) visibles' from public.textos_panel));
do $p$
begin
  insert into public.textos_panel (clave, idioma, texto) values ('tsec.title', 'es', 'Colado');
  perform arnes.comprueba('textos: un inversionista no escribe textos', false, 'ESCRIBIO');
exception when others then
  perform arnes.comprueba('textos: un inversionista no escribe textos', true, sqlerrm);
end
$p$;
do $p$
declare n int;
begin
  update public.textos_panel set texto = 'Colado' where clave = 'c33.name';
  get diagnostics n = row_count;
  perform arnes.comprueba('textos: ni cambia el del admin', n = 0, n || ' fila(s)');
exception when others then
  perform arnes.comprueba('textos: ni cambia el del admin', true, sqlerrm);
end
$p$;
do $p$
declare n int;
begin
  delete from public.textos_panel where clave = 'c33.name';
  get diagnostics n = row_count;
  perform arnes.comprueba('textos: ni lo borra', n = 0, n || ' fila(s)');
exception when others then
  perform arnes.comprueba('textos: ni lo borra', true, sqlerrm);
end
$p$;
reset role;

-- Sin entrar, nada.
set role anon;
select arnes.nadie();
do $p$
begin
  perform arnes.comprueba('textos: sin entrar no se leen',
    (select count(*) = 0 from public.textos_panel));
exception when insufficient_privilege then
  perform arnes.comprueba('textos: sin entrar no se leen', true, sqlerrm);
end
$p$;
reset role;

-- Lo que la base no deja guardar ni al admin.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'X'));
do $p$
begin
  insert into public.textos_panel (clave, idioma, texto) values ('c1.name', 'ES', 'Visa');
  perform arnes.comprueba('textos: no cabe un idioma que el panel no tiene', false, 'ENTRO');
exception when check_violation then
  perform arnes.comprueba('textos: no cabe un idioma que el panel no tiene', true, sqlerrm);
end
$p$;
do $p$
begin
  insert into public.textos_panel (clave, idioma, texto) values ('c1.name', 'es', '   ');
  perform arnes.comprueba('textos: ni un texto vacio', false, 'ENTRO');
exception when check_violation then
  perform arnes.comprueba('textos: ni un texto vacio', true, sqlerrm);
end
$p$;
do $p$
declare n int;
begin
  delete from public.textos_panel where clave = 'c33.name' and idioma = 'es';
  get diagnostics n = row_count;
  perform arnes.comprueba('textos: el admin vuelve al original borrando la fila', n = 1, n || ' fila(s)');
end
$p$;
reset role;
select arnes.nadie();


-- ══ 30 · LA BITACORA APUNTA LO QUE VINO DESPUES ═════════════════════
-- supabase-bitacora.sql solo apuntaba el interruptor del catalogo, los
-- roles, los papeles y las citas. Todo lo que el panel aprendio a tocar
-- despues -el plazo, bloquear, los activos, el horario, el acompañamiento
-- y los textos- no dejaba rastro, y Trazabilidad se quedo parada.
--
-- Se hace como dueño con el uid del admin: aqui no se prueban las
-- politicas de cada tabla, que tienen su seccion, sino que cada cambio
-- deje UNA fila, y que guardar sin cambiar nada no deje ninguna.
select arnes.soy((select id from arnes.gente where papel = 'X'));
do $p$
declare
  antes bigint;
  yo    uuid := (select id from arnes.gente where papel = 'X');
  tipo  text;
  act   uuid;
  tramo uuid;
  lunes date := date_trunc('week', current_date + 400)::date;
  vistos text;
begin
  select coalesce(max(id), 0) into antes from public.bitacora;
  -- Uno CONCRETO, y uno que ya tiene plazo. Era «el primero por orden
  -- alfabetico», y desde el 23-9-2026 ese es aporte_locti: esta seccion le
  -- sumaba siete dias y la del LOCTI, mas abajo, fallaba al encontrarle un
  -- plazo que no tiene. Ninguna otra prueba mira el plazo de la firma. (25-9)
  tipo := 'firma_electronica';

  update public.tipos_tramite set plazo_dias = coalesce(plazo_dias, 0) + 7 where codigo = tipo;
  update public.tipos_tramite set nombre = nombre where codigo = tipo;

  -- Una cuenta suya: las de arriba ya han pasado por otras secciones, y
  -- bloquear a alguien que no está no deja apunte ni da error.
  insert into auth.users (email, raw_user_meta_data)
  values ('bit@prueba.local', '{"nombre_completo":"Beto Bitacora","pais":"Chile"}')
  returning id into act;
  update public.perfiles set bloqueado = true  where id = act;
  update public.perfiles set bloqueado = false where id = act;

  insert into public.activos (titulo) values ('Finca de la bitacora') returning id into act;
  update public.activos set destacado = true where id = act;
  update public.activos set destacado = true where id = act;
  delete from public.activos where id = act;

  insert into public.horario_citas (dia, desde, hasta) values (5, '16:00', '17:00') returning id into tramo;
  delete from public.horario_citas where id = tramo;

  insert into public.cierres_citas (fecha, motivo) values (lunes, 'Feriado de la bitacora');
  delete from public.cierres_citas where fecha = lunes;

  update public.acompanamiento set nube = not nube;
  update public.acompanamiento set nube = not nube;
  update public.acompanamiento set nube = nube;

  insert into public.textos_panel (clave, idioma, texto) values ('bit.prueba', 'es', 'Primero')
    on conflict (clave, idioma) do update set texto = excluded.texto;
  insert into public.textos_panel (clave, idioma, texto) values ('bit.prueba', 'es', 'Segundo')
    on conflict (clave, idioma) do update set texto = excluded.texto;
  update public.textos_panel set texto = 'Segundo' where clave = 'bit.prueba';
  delete from public.textos_panel where clave = 'bit.prueba';

  select coalesce(string_agg(fuente || '/' || accion, ', ' order by id), 'nada')
    into vistos from public.bitacora where id > antes;

  perform arnes.comprueba('bitacora: cambiar un plazo deja un apunte, y guardar otro campo no',
    (select count(*) = 1 from public.bitacora where id > antes and fuente = 'catalogo' and accion = 'plazo'
       and detalle <> ''), vistos);
  perform arnes.comprueba('bitacora: bloquear y desbloquear, uno cada uno',
    (select count(*) filter (where accion = 'bloqueo') = 1 and count(*) filter (where accion = 'desbloqueo') = 1
       from public.bitacora where id > antes and fuente = 'roles'), vistos);
  perform arnes.comprueba('bitacora: un activo se crea, se edita y se borra, y guardarlo igual no cuenta',
    (select count(*) filter (where accion = 'creo') = 1 and count(*) filter (where accion = 'edito') = 1
        and count(*) filter (where accion = 'borro') = 1 and count(*) = 3
       from public.bitacora where id > antes and fuente = 'activos'), vistos);
  perform arnes.comprueba('bitacora: el horario, con sus horas y su dia',
    (select count(*) = 2 and bool_and(sobre = '16:00-17:00' and detalle = '5')
       from public.bitacora where id > antes and accion in ('puso_tramo', 'quito_tramo')), vistos);
  perform arnes.comprueba('bitacora: cerrar un dia y volver a abrirlo',
    (select count(*) = 2 and bool_and(sobre = lunes::text)
       from public.bitacora where id > antes and accion in ('cerro_dia', 'abrio_dia')), vistos);
  perform arnes.comprueba('bitacora: el acompañamiento, solo cuando algo cambia',
    (select count(*) = 2 from public.bitacora where id > antes and fuente = 'acompanamiento'), vistos);
  perform arnes.comprueba('bitacora: los textos, dos cambios y una vuelta al original',
    (select count(*) filter (where accion = 'cambio') = 2 and count(*) filter (where accion = 'original') = 1
        and count(*) = 3
       from public.bitacora where id > antes and fuente = 'textos'), vistos);
  perform arnes.comprueba('bitacora: y todo a nombre de quien lo hizo',
    (select count(*) > 0 and bool_and(quien = yo) from public.bitacora where id > antes), vistos);
end
$p$;
select arnes.nadie();

-- Y lo que prometia la cabecera de la bitacora y no se cumplia: nadie
-- escribe en ella desde fuera. apunta() estaba abierta a cualquiera.
select arnes.comprueba(
  'bitacora: apunta() no la llama la clave anonima',
  not has_function_privilege('anon', 'public.apunta(text,text,text,text)', 'execute'),
  'anon SI puede inventarse apuntes');
select arnes.comprueba(
  'bitacora: ni quien haya entrado',
  not has_function_privilege('authenticated', 'public.apunta(text,text,text,text)', 'execute'),
  'authenticated SI puede inventarse apuntes');

-- La opinion favorable de la ZODI (c34), del mensaje de Milagros Torres
-- del 15 de septiembre de 2026. Entra como el SISREF: encendida, en la
-- fase 2 y encadenada. Pero NO obligatoria, que es lo que la separa.
select arnes.comprueba(
  'zodi: existe la opinion favorable, en la fase 2 y encendida',
  (select count(*) = 1 from public.tipos_tramite
    where codigo = 'opinion_zodi' and ref_panel = 'c34' and fase = 2 and activo));

-- No le toca a todos: solo a quien se instala en zona fronteriza o de
-- seguridad, o toca la defensa. Como obligatoria, la fase 2 le diria a
-- una tienda de Caracas que no puede seguir sin ella.
select arnes.comprueba(
  'zodi: depende de la actividad, no es obligatoria',
  (select nivel = 'actividad' from public.tipos_tramite where codigo = 'opinion_zodi'),
  (select 'nivel ' || nivel from public.tipos_tramite where codigo = 'opinion_zodi'));

select arnes.comprueba(
  'zodi: emite la no objecion, y esta en el catalogo de recaudos',
  (select t.emite = 'no_objecion_zodi' and d.codigo is not null
     from public.tipos_tramite t
     left join public.tipos_documento d on d.codigo = t.emite
    where t.codigo = 'opinion_zodi'));

-- Nadie ha dado un plazo. Un numero puesto aqui marcaria como tardia una
-- solicitud que no tenia hora.
select arnes.comprueba(
  'zodi: no promete plazo, porque nadie lo ha dado',
  (select plazo_dias is null from public.tipos_tramite where codigo = 'opinion_zodi'));

select arnes.comprueba(
  'zodi: los tres papeles de la cadena corporativa estan en la boveda',
  (select count(*) = 3 from public.tipos_documento
    where codigo in ('estatutos_accionista', 'good_standing', 'beneficiarios_finales')));

-- El PROYECTO del acta es un tipo propio y no el acta registrada. El panel
-- lo pedia con 'acta_constitutiva' -lo que emite el c5- y la boveda le
-- colgaba encima el acta ya registrada con su visto de "ya lo tienes".
-- Por fechas es imposible: esta opinion va ANTES del Registro Mercantil.
-- Sin el tipo en la base, subirlo lo rechaza la clave foranea.
select arnes.comprueba(
  'zodi: el proyecto del acta tiene tipo propio, no el del acta registrada',
  (select count(*) = 1 from public.tipos_documento where codigo = 'proyecto_acta'));

-- Lo mismo en el c32: el documento del tramite iba con el tipo 'otro', que
-- es el cajon del catalogo, y ahi la boveda ofrece cualquier papel suelto.
select arnes.comprueba(
  'sisref: el documento del tramite tiene tipo propio, no el cajon',
  (select count(*) = 1 from public.tipos_documento
    where codigo = 'documento_tramite_sisref'));

-- Y el PUB, el cuarto recaudo del c32 desde el 22 de septiembre de 2026.
-- Las casillas del formulario viven en el panel y no en la base, pero los
-- recaudos si: sin esta fila, la boveda ensena un renglon sin nombre que
-- no deja subir nada, y el fallo no se ve hasta abrir el paso 2.
select arnes.comprueba(
  'sisref: el PUB esta en el catalogo de documentos',
  (select count(*) = 1 from public.tipos_documento where codigo = 'pub_saren'));

-- Y no le cuesta un obligatorio a nadie: siguen los diez del informe.
select arnes.comprueba(
  'zodi: y los obligatorios siguen siendo diez',
  (select count(*) = 10 from public.tipos_tramite where nivel = 'obligatorio'),
  (select count(*)::text || ' obligatorios' from public.tipos_tramite where nivel = 'obligatorio'));

-- El RUPDAE (c35) y el Registro Unico Minero (c36), del encargo del 15 de
-- septiembre de 2026: los dos a la fase 3, «Habilitacion operativa y
-- cumplimiento».
--
-- El RUM sigue encendido. El RUPDAE ya NO: desde el encargo del 20 de
-- septiembre se hace dentro del c37, y lo que se comprueba de el es que
-- este apagado, no que falte. Su fila se queda -con su nivel, su plazo y su
-- `emite`- porque las solicitudes que ya existen la referencian y porque el
-- admin puede volver a encenderlo desde el panel.
select arnes.comprueba(
  'rupdae y rum: estan en la fase 3, y solo el RUM encendido',
  (select count(*) = 2 from public.tipos_tramite
    where (codigo, ref_panel) in (('rupdae', 'c35'), ('registro_minero', 'c36'))
      and fase = 3
      and activo = (codigo = 'registro_minero')),
  (select string_agg(codigo || ' activo=' || activo::text, ', ' order by codigo)
     from public.tipos_tramite where codigo in ('rupdae', 'registro_minero')));

-- El RUPDAE le toca a toda empresa que vende, fabrica o presta servicios,
-- pero no suma a los diez obligatorios del informe: 'esencial'. El RUM
-- solo a la mineria: 'actividad'.
select arnes.comprueba(
  'rupdae y rum: el RUPDAE es esencial y el RUM depende de la actividad',
  (select bool_and(case codigo when 'rupdae' then nivel = 'esencial'
                               else nivel = 'actividad' end)
     from public.tipos_tramite where codigo in ('rupdae', 'registro_minero')),
  (select string_agg(codigo || ' ' || nivel, ', ') from public.tipos_tramite
    where codigo in ('rupdae', 'registro_minero')));

-- La SUNDDE da de cinco a diez dias habiles. La Resolucion 0010 del RUM no
-- da ninguno: un numero ahi marcaria como tardia una solicitud sin hora.
select arnes.comprueba(
  'rupdae y rum: catorce dias el RUPDAE, y el RUM sin plazo',
  (select plazo_dias = 14 from public.tipos_tramite where codigo = 'rupdae')
  and (select plazo_dias is null from public.tipos_tramite where codigo = 'registro_minero'));

-- El certificado del RUM dura tres anos; el del RUPDAE ya no vence.
select arnes.comprueba(
  'rupdae y rum: emiten su certificado, y solo el del RUM caduca',
  (select count(*) = 2 from public.tipos_tramite t
     join public.tipos_documento d on d.codigo = t.emite
    where (t.codigo = 'rupdae' and d.codigo = 'certificado_rupdae' and not d.vence)
       or (t.codigo = 'registro_minero' and d.codigo = 'certificado_rum' and d.vence)));

-- La inscripcion en el SIDCAI (c39), del encargo del 23 de septiembre de
-- 2026: fase 3, encendida, 'actividad' -solo si se pasa del umbral de
-- ingresos-, sin plazo, y emite un certificado que vence.
select arnes.comprueba(
  'locti: c39 en la fase 3, encendida, por actividad y sin plazo',
  (select fase = 3 and activo and nivel = 'actividad' and plazo_dias is null
     from public.tipos_tramite where codigo = 'aporte_locti' and ref_panel = 'c39'),
  (select coalesce(string_agg(ref_panel || ' ' || nivel || ' activo=' || activo::text, ', '), 'no esta')
     from public.tipos_tramite where codigo = 'aporte_locti'));


-- ── LAS CINCO INSCRIPCIONES, EN UNA CASILLA (c37) ──────────────────────
-- Del encargo del 20 de septiembre de 2026: «vamos a agrupar los tramites
-- de Banavih, Inces, Ministerio de Trabajo, RNC y Rupdae en una sola
-- casilla», con un solo juego de recaudos. Fase 3 y encendida.
select arnes.comprueba(
  'parafiscales: la casilla esta en la fase 3 y encendida',
  (select count(*) = 1 from public.tipos_tramite
    where codigo = 'registros_parafiscales' and ref_panel = 'c37'
      and fase = 3 and activo));

-- Y los cinco que recoge, APAGADOS. Este es el que de verdad importa: con
-- uno encendido, el inversionista veria la casilla nueva y ademas la vieja,
-- y subiria los mismos papeles dos veces.
select arnes.comprueba(
  'parafiscales: y los cinco que recoge estan apagados',
  (select count(*) = 0 from public.tipos_tramite
    where codigo in ('faov_banavih', 'inces', 'rnet', 'rnc', 'rupdae')
      and activo),
  (select coalesce(string_agg(codigo, ', ' order by codigo), '(ninguno)')
     from public.tipos_tramite
    where codigo in ('faov_banavih', 'inces', 'rnet', 'rnc', 'rupdae') and activo));

-- Pero NO borrados: sus filas siguen, que es lo que da nombre a las
-- solicitudes que ya existen de esos cinco tipos.
select arnes.comprueba(
  'parafiscales: apagar no borro ninguna de las cinco filas',
  (select count(*) = 5 from public.tipos_tramite
    where codigo in ('faov_banavih', 'inces', 'rnet', 'rnc', 'rupdae')));

-- El IVSS (c9) ya no esta: el 20-9-2026 se quedo fuera de esta casilla con
-- ficha propia, y el 22-9-2026 el CIIP quito la ficha del catalogo.
--
-- Se mide que NO hay fila, y no solo que este apagada: apagada seguiria
-- saliendo en el panel del admin para volver a encenderla de un clic.
select arnes.comprueba(
  'parafiscales: el IVSS ya no esta en el catalogo',
  (select count(*) = 0 from public.tipos_tramite
    where codigo = 'registros_laborales'),
  (select coalesce(string_agg(codigo || ' activo=' || activo, ', '), '(ninguna fila)')
     from public.tipos_tramite where codigo = 'registros_laborales'));

-- Le toca a toda empresa -el RNET y el RUPDAE son de todas-, asi que no
-- puede decir «segun tu actividad». Y no suma a los diez obligatorios.
select arnes.comprueba(
  'parafiscales: es esencial, no de actividad, y no suma obligatorios',
  (select nivel = 'esencial' from public.tipos_tramite
    where codigo = 'registros_parafiscales')
  and (select count(*) = 10 from public.tipos_tramite where nivel = 'obligatorio'),
  (select nivel from public.tipos_tramite where codigo = 'registros_parafiscales'));

-- Sin `emite`: devuelve CINCO constancias y la columna guarda una. Poner
-- una de las cinco encadenaria mal -un tramite que pidiera la del RNET se
-- quedaria esperando por un `emite` que dice otra cosa-.
select arnes.comprueba(
  'parafiscales: no dice emitir uno solo de los cinco papeles',
  (select emite is null from public.tipos_tramite
    where codigo = 'registros_parafiscales'));

-- ── LA JUNTA DIRECTIVA (c5): de quién es cada papel ────────────────────
-- Sin titular, cinco cédulas de cinco miembros eran cinco papeles del mismo
-- tipo, y la bóveda enseñaba la última a los cinco.
select arnes.comprueba(
  'junta: la bóveda sabe de quién es cada papel',
  (select count(*) = 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'documentos'
      and column_name = 'titular'));

-- Y lo guardado antes sigue siendo de quien lo subió: la columna admite vacío.
select arnes.comprueba(
  'junta: lo que ya estaba guardado no cambia de dueño',
  (select is_nullable = 'YES' from information_schema.columns
    where table_schema = 'public' and table_name = 'documentos'
      and column_name = 'titular'));

-- Un nombre en blanco sería un papel de nadie.
select arnes.comprueba(
  'junta: un titular en blanco no se acepta',
  (select count(*) = 1 from pg_constraint where conname = 'documentos_titular_no_vacio'));

-- La cédula y el RIF de cada miembro son DOS papeles, y la certificación
-- de inventario el tercero.
select arnes.comprueba(
  'junta: la cédula, el RIF y la certificación están en el catálogo, y no caducan',
  (select count(*) = 3 from public.tipos_documento
    where codigo in ('cedula_pasaporte_junta', 'rif_junta', 'certificacion_inventario')
      and not vence));

-- ── LOS TEXTOS: quién cambió cuál, y qué decía antes ──────────────────
select arnes.comprueba(
  'textos: se guarda lo que decía antes al lado del cambio',
  (select count(*) = 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'textos_panel'
      and column_name = 'original'));

select arnes.comprueba(
  'textos: el disparador de la bitácora está puesto',
  (select count(*) = 1 from pg_trigger
    where tgname = 'bitacora_textos' and not tgisinternal));

-- Y lo hace de verdad: un cambio deja apuntada su clave y lo de antes.
insert into public.textos_panel (clave, idioma, texto, original)
  values ('arnes.rastro', 'es', 'Texto nuevo', 'Texto de antes')
  on conflict (clave, idioma) do update set texto = excluded.texto, original = excluded.original;

select arnes.comprueba(
  'textos: el apunte dice qué texto era y qué decía antes',
  (select (detalle::jsonb ->> 'clave') = 'arnes.rastro'
      and (detalle::jsonb ->> 'antes') = 'Texto de antes'
      and (detalle::jsonb ->> 'idioma') = 'es'
      and sobre = 'Texto nuevo'
     from public.bitacora where fuente = 'textos'
     order by id desc limit 1));

delete from public.textos_panel where clave = 'arnes.rastro';

select arnes.comprueba(
  'textos: y volver al original también se apunta',
  (select accion = 'original' and (detalle::jsonb ->> 'antes') = 'Texto nuevo'
      and sobre = 'Texto de antes'
     from public.bitacora where fuente = 'textos'
     order by id desc limit 1));

-- ── LA REVISIÓN DE LOS PAPELES: quién validó o rechazó cuál ─────────────
select arnes.comprueba(
  'revision: el papel guarda cuándo se revisó',
  (select count(*) = 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'documentos'
      and column_name = 'revisado_en'));

select arnes.comprueba(
  'revision: el disparador de la bitácora está puesto',
  (select count(*) = 1 from pg_trigger
    where tgname = 'bitacora_papeles_revision' and not tgisinternal));

-- Ana sube un papel; Gabriela, del equipo, lo valida y luego lo rechaza.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $rv$
declare
  laRuta text;
  ficha  uuid;
begin
  laRuta := auth.uid() || '/revision-prueba.pdf';
  insert into storage.objects (bucket_id, name, owner) values ('recaudos', laRuta, auth.uid());
  insert into public.documentos (inversionista, tipo, archivo, nombre_original, estado)
    values (auth.uid(), 'cedula', laRuta, 'revision-prueba.pdf', 'cargado')
    returning id into ficha;
  delete from arnes.escenario where clave = 'rv_doc';
  insert into arnes.escenario (clave, id) values ('rv_doc', ficha);
end
$rv$;

select arnes.soy((select id from arnes.gente where papel = 'G'));
update public.documentos set estado = 'validado', revisado_en = now()
 where id = (select id from arnes.escenario where clave = 'rv_doc');

-- El apunte se mira con el rol quitado: la bitácora no la lee el gestor, y
-- lo que se prueba aquí es que el disparador escribe.
reset role;
select arnes.comprueba(
  'revision: validar un papel deja apuntado quién, qué papel y de quién era',
  (select accion = 'valido'
      and quien = (select id from arnes.gente where papel = 'G')
      and (detalle::jsonb ->> 'tipo') = 'cedula'
      and coalesce(detalle::jsonb ->> 'de', '') <> ''
      and sobre = 'revision-prueba.pdf'
     from public.bitacora where fuente = 'papeles'
     order by id desc limit 1));

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));
update public.documentos set estado = 'rechazado', nota_revision = 'No se lee bien.'
 where id = (select id from arnes.escenario where clave = 'rv_doc');
reset role;
select arnes.comprueba(
  'revision: y rechazarlo, con su motivo',
  (select accion = 'rechazo' and (detalle::jsonb ->> 'motivo') = 'No se lee bien.'
     from public.bitacora where fuente = 'papeles'
     order by id desc limit 1));

-- Guardar el mismo estado otra vez no es una revisión nueva.
select count(*) as n_antes from public.bitacora where fuente = 'papeles' \gset
update public.documentos set nota_revision = 'No se lee bien.'
 where id = (select id from arnes.escenario where clave = 'rv_doc');
select arnes.comprueba(
  'revision: retocar el papel sin cambiar su estado no deja apunte',
  (select count(*) = :n_antes from public.bitacora where fuente = 'papeles'));
select arnes.nadie();

-- ── LA ACCIONISTA JURÍDICA (c5) ─────────────────────────────────────────
select arnes.comprueba(
  'accionista juridica: sus dos papeles están en el catálogo, y no caducan',
  (select count(*) = 2 from public.tipos_documento
    where codigo in ('constitutivo_accionista', 'identidad_socios_accionista')
      and not vence));

-- ── EL LOGO DE LAS FICHAS ───────────────────────────────────────────────
-- Lo sube el admin; un inversionista no sube, no apunta y no borra, y
-- cualquiera lo ve.
reset role;
select arnes.nadie();
select arnes.comprueba(
  'logos: el cubo es publico, con tope de 1 MB y tres tipos, sin SVG',
  coalesce((select public and file_size_limit = 1048576
                   and array_length(allowed_mime_types, 1) = 3
                   and not ('image/svg+xml' = any(allowed_mime_types))
              from storage.buckets where id = 'logos-fichas'), false));

select coalesce(max(id), 0) as logo_antes from public.bitacora \gset

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'B'));
do $p$
begin
  insert into storage.objects (bucket_id, name, owner)
  values ('logos-fichas', 'rif_personal/colado.png', auth.uid());
  perform arnes.comprueba('logos: un inversionista no sube un logo', false, 'SUBIO');
exception when others then
  perform arnes.comprueba('logos: un inversionista no sube un logo', true, sqlerrm);
end
$p$;
with t as (
  update public.tipos_tramite set logo = 'rif_personal/colado.png'
   where codigo = 'rif_personal' returning 1)
select arnes.comprueba('logos: ni lo apunta en el catalogo',
  (select count(*) = 0 from t));

select arnes.soy((select id from arnes.gente where papel = 'X'));
do $p$
begin
  insert into storage.objects (bucket_id, name, owner)
  values ('logos-fichas', 'rif_personal/1.png', auth.uid());
  perform arnes.comprueba('logos: el admin sube un logo', true);
exception when others then
  perform arnes.comprueba('logos: el admin sube un logo', false, sqlerrm);
end
$p$;
with t as (
  update public.tipos_tramite set logo = 'rif_personal/1.png'
   where codigo = 'rif_personal' returning 1)
select arnes.comprueba('logos: y lo apunta en el catalogo',
  (select count(*) = 1 from t));

select arnes.soy((select id from arnes.gente where papel = 'B'));
select arnes.comprueba('logos: el inversionista ve la ruta en el catalogo',
  (select logo = 'rif_personal/1.png' from public.tipos_tramite where codigo = 'rif_personal'));
with t as (
  delete from storage.objects where bucket_id = 'logos-fichas' returning 1)
select arnes.comprueba('logos: pero no lo borra', (select count(*) = 0 from t));

select arnes.soy((select id from arnes.gente where papel = 'X'));
update public.tipos_tramite set logo = null where codigo = 'rif_personal';
with t as (
  delete from storage.objects
   where bucket_id = 'logos-fichas' and name = 'rif_personal/1.png' returning 1)
select arnes.comprueba('logos: el admin lo quita y lo borra', (select count(*) = 1 from t));

reset role;
select arnes.nadie();
select arnes.comprueba('logos: poner y quitar el logo deja dos apuntes en la bitacora',
  (select count(*) = 2 from public.bitacora
    where id > :logo_antes and fuente = 'catalogo' and accion = 'logo'),
  (select coalesce(string_agg(accion || ':' || detalle, ', '), 'nada')
     from public.bitacora where id > :logo_antes));

-- ── LA PROTOCOLIZACIÓN NACE AL RESOLVERSE LA CONSTITUCIÓN ──────
-- Franklin Reyes, 17-9-2026. Tres cosas: que nazca, que traiga lo que la
-- constitución ya decía, y que luego no se resuelva sin el comprobante
-- del pago de los aranceles.
-- Una cuenta propia: la B se borra mucho antes, probando el cascade.
insert into auth.users (email, raw_user_meta_data) values
  ('p@prueba.local', '{"nombre_completo":"Pablo Protocoliza","pais":"Brasil"}');
insert into arnes.gente (papel, id)
select 'P', id from auth.users where email = 'p@prueba.local';

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'P'));

do $pr$
declare
  cual uuid;
begin
  insert into public.tramites (inversionista, tipo, estado, datos)
  values (auth.uid(), 'constitucion', 'borrador', jsonb_build_object(
            'denominacion',     'INVERSIONES BRUNO C.A.',
            'capital_social',   '100000',
            'oficina_registro', 'REGISTRO MERCANTIL PRIMERO DEL DISTRITO CAPITAL',
            'junta_directiva',  'Bruno Silva (PRESIDENTE); Ana Costa (TESORERO)'))
  returning id into cual;
  delete from arnes.escenario where clave = 'pr_c5';
  insert into arnes.escenario (clave, id) values ('pr_c5', cual);
  update public.tramites set estado = 'enviado' where id = cual;
end
$pr$;

-- El equipo la sube hasta resuelta, peldaño a peldaño.
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $pr$
declare
  cual uuid := (select id from arnes.escenario where clave = 'pr_c5');
  paso text;
begin
  --  La toma primero, como en la cola: «Tómalo» va antes de moverla. De
  --  ese dueño sale el que hereda la protocolización.
  update public.tramites set gestor = auth.uid() where id = cual;
  foreach paso in array array['en_revision','ante_el_ente','resuelto'] loop
    update public.tramites set estado = paso where id = cual;
  end loop;
end
$pr$;

reset role;
select arnes.nadie();
select arnes.comprueba(
  'protocolizacion: resuelta la constitucion, nace la protocolizacion enviada',
  (select count(*) = 1 from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'P')
      and tipo = 'protocolizacion_acta' and estado = 'enviado'),
  (select coalesce(string_agg(tipo || ':' || estado, ', '), 'ninguna')
     from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'P')
      and tipo = 'protocolizacion_acta'));

-- Y NACE EN MANOS DE QUIEN RESOLVIÓ LA CONSTITUCIÓN (Franklin Reyes,
-- 18-9-2026). Sin dueño, la cola solo ofrece «Tómalo», y la casilla donde
-- el equipo le deja el documento con que pagar los aranceles vive un paso
-- más adentro: no aparecía sola, y el inversionista se quedaba esperando un
-- papel sin el cual no puede pagar.
select arnes.comprueba(
  'protocolizacion: y nace en manos de quien resolvio la constitucion',
  (select gestor = (select id from arnes.gente where papel = 'G')
     from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'P')
      and tipo = 'protocolizacion_acta'),
  (select coalesce(gestor::text, 'sin asignar') from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'P')
      and tipo = 'protocolizacion_acta'));

select arnes.comprueba(
  'protocolizacion: y trae lo que la constitucion ya decia',
  (select datos->>'razon_social' = 'INVERSIONES BRUNO C.A.'
      and datos->>'capital_social' = '100000'
      and datos->>'registro_mercantil' = 'REGISTRO MERCANTIL PRIMERO DEL DISTRITO CAPITAL'
      and datos->>'representante' = 'Bruno Silva'
     from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'P')
      and tipo = 'protocolizacion_acta'),
  (select datos::text from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'P')
      and tipo = 'protocolizacion_acta'));

-- La fecha de firma del acta no se copia: no existía todavía.
select arnes.comprueba(
  'protocolizacion: la fecha de firma se queda sin poner',
  (select not (datos ? 'fecha_firma') from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'P')
      and tipo = 'protocolizacion_acta'));

-- Y no nace una segunda si se vuelve a tocar la constitución.
select arnes.comprueba(
  'protocolizacion: y no nace dos veces',
  (select count(*) = 1 from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'P')
      and tipo = 'protocolizacion_acta'));

-- ── LAS QUE NACIERON SIN DUEÑO, REPESCADAS ────────────────────
-- Franklin Reyes, 18-9-2026. El disparador solo mira las que nacen, así
-- que las protocolizaciones creadas antes del cambio se quedarían sin
-- gestor para siempre. El archivo trae un update que les pone el de SU
-- constitución, y corre al instalar —cuando todavía no hay ningún
-- trámite—, así que la única forma de probarlo es volver a correr el
-- archivo con una ya creada. De paso dice que correrlo dos veces no rompe
-- nada, que es como se va a correr en producción.
reset role;
select arnes.nadie();
update public.tramites set gestor = null
 where inversionista = (select id from arnes.gente where papel = 'P')
   and tipo = 'protocolizacion_acta';

\i :proto

select arnes.comprueba(
  'protocolizacion: y a las que nacieron sin duenno se les pone el de su constitucion',
  (select gestor = (select id from arnes.gente where papel = 'G')
     from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'P')
      and tipo = 'protocolizacion_acta'),
  (select coalesce(gestor::text, 'sigue sin asignar') from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'P')
      and tipo = 'protocolizacion_acta'));

-- Y no nacio otra por volver a correr el archivo.
select arnes.comprueba(
  'protocolizacion: correr el archivo otra vez no abre una segunda',
  (select count(*) = 1 from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'P')
      and tipo = 'protocolizacion_acta'));

-- Sin el comprobante del pago, el equipo no la resuelve.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $pr$
declare
  cual uuid := (select id from public.tramites
                 where inversionista = (select id from arnes.gente where papel = 'P')
                   and tipo = 'protocolizacion_acta' limit 1);
  paso text;
begin
  delete from arnes.escenario where clave = 'pr_c22';
  insert into arnes.escenario (clave, id) values ('pr_c22', cual);
  foreach paso in array array['en_revision','ante_el_ente'] loop
    update public.tramites set estado = paso where id = cual;
  end loop;
  begin
    update public.tramites set estado = 'resuelto' where id = cual;
    perform arnes.comprueba(
      'protocolizacion: sin el comprobante del pago no se resuelve', false, 'LO DEJO PASAR');
  exception when others then
    perform arnes.comprueba(
      'protocolizacion: sin el comprobante del pago no se resuelve',
      sqlerrm like '%aranceles%', sqlerrm);
  end;
end
$pr$;

-- Con el comprobante colgado, sí. Se cuelga con el rol quitado: lo que se
-- prueba aquí es el trigger, no la política que deja adjuntarlo.
reset role;
select arnes.nadie();
do $pr$
declare
  ficha uuid;
begin
  insert into public.documentos (inversionista, tipo, archivo, nombre_original, estado)
  values ((select id from arnes.gente where papel = 'P'), 'pago_aranceles',
          'b/aranceles.pdf', 'aranceles.pdf', 'cargado')
  returning id into ficha;
  insert into public.tramite_documentos (tramite, documento)
  values ((select id from arnes.escenario where clave = 'pr_c22'), ficha);
end
$pr$;

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $pr$
begin
  update public.tramites set estado = 'resuelto'
   where id = (select id from arnes.escenario where clave = 'pr_c22');
  perform arnes.comprueba('protocolizacion: con el comprobante, se resuelve',
    (select estado = 'resuelto' from public.tramites
      where id = (select id from arnes.escenario where clave = 'pr_c22')), 'resuelto');
exception when others then
  perform arnes.comprueba('protocolizacion: con el comprobante, se resuelve', false, sqlerrm);
end
$pr$;
reset role;
select arnes.nadie();

-- ── EL SIDCAI, EN DOS TRAMOS (c39 y c40) ───────────────────────────────
-- Del encargo del 23-9-2026, con el molde de la constitución: resuelta la
-- inscripción nace la declaración con el primer pago, con lo que aquélla
-- decía y en manos del mismo gestor, y no se resuelve sin el comprobante.
insert into auth.users (email, raw_user_meta_data) values
  ('l@prueba.local', '{"nombre_completo":"Lucia Locti","pais":"Italia"}');
insert into arnes.gente (papel, id)
select 'L', id from auth.users where email = 'l@prueba.local';

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'L'));
do $lc$
declare
  cual uuid;
begin
  insert into public.tramites (inversionista, tipo, estado, datos)
  values (auth.uid(), 'aporte_locti', 'borrador', jsonb_build_object(
            'razon_social',    'LOCTI PRUEBA C.A.',
            'rif_empresa',     'J-12345678-9',
            'ingresos_brutos', '9000000',
            'usuario_principal', 'Lucia Locti, lucia@locti.com'))
  returning id into cual;
  delete from arnes.escenario where clave = 'lc_c39';
  insert into arnes.escenario (clave, id) values ('lc_c39', cual);
  update public.tramites set estado = 'enviado' where id = cual;
end
$lc$;

select arnes.soy((select id from arnes.gente where papel = 'G'));
do $lc$
declare
  cual uuid := (select id from arnes.escenario where clave = 'lc_c39');
  paso text;
begin
  update public.tramites set gestor = auth.uid() where id = cual;
  foreach paso in array array['en_revision','ante_el_ente','resuelto'] loop
    update public.tramites set estado = paso where id = cual;
  end loop;
end
$lc$;

reset role;
select arnes.nadie();
select arnes.comprueba(
  'sidcai: resuelta la inscripcion, nace el primer pago enviado',
  (select count(*) = 1 from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'L')
      and tipo = 'aporte_locti_pago' and estado = 'enviado'),
  (select coalesce(string_agg(tipo || ':' || estado, ', '), 'ninguna')
     from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'L')
      and tipo = 'aporte_locti_pago'));

select arnes.comprueba(
  'sidcai: y nace en manos de quien resolvio la inscripcion',
  (select gestor = (select id from arnes.gente where papel = 'G')
     from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'L')
      and tipo = 'aporte_locti_pago'),
  (select coalesce(gestor::text, 'sin asignar') from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'L')
      and tipo = 'aporte_locti_pago'));

-- Trae la razón social, el RIF y los ingresos; el usuario principal no,
-- que es de la inscripción.
select arnes.comprueba(
  'sidcai: y trae la razon social, el RIF y los ingresos',
  (select datos->>'razon_social' = 'LOCTI PRUEBA C.A.'
      and datos->>'rif_empresa' = 'J-12345678-9'
      and datos->>'ingresos_brutos' = '9000000'
      and not (datos ? 'usuario_principal')
     from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'L')
      and tipo = 'aporte_locti_pago'),
  (select datos::text from public.tramites
    where inversionista = (select id from arnes.gente where papel = 'L')
      and tipo = 'aporte_locti_pago'));

-- Sin el comprobante del pago, el equipo no puede darlo por resuelto.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $lc$
declare
  cual uuid := (select id from public.tramites
                 where inversionista = (select id from arnes.gente where papel = 'L')
                   and tipo = 'aporte_locti_pago');
begin
  update public.tramites set estado = 'resuelto' where id = cual;
  perform arnes.comprueba('sidcai: sin el comprobante del pago no se resuelve', false,
                          'se resolvio');
exception when check_violation then
  perform arnes.comprueba('sidcai: sin el comprobante del pago no se resuelve', true);
end
$lc$;
reset role;
select arnes.nadie();

-- Y el certificado sale del segundo tramo, no del primero.
select arnes.comprueba(
  'sidcai: el certificado lo emite el primer pago, y caduca',
  (select emite is null from public.tipos_tramite where codigo = 'aporte_locti')
  and (select count(*) = 1 from public.tipos_tramite t
         join public.tipos_documento d on d.codigo = t.emite
        where t.codigo = 'aporte_locti_pago' and d.codigo = 'certificado_locti' and d.vence));


-- ══ 31 · LOS PAPELES, SELLADOS (revision del 25 de septiembre) ════════
-- supabase-papeles-sellados.sql. Cada intento es lo que se podia hacer
-- desde la consola del navegador con una cuenta de inversionista.

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $ps$
declare
  yo  uuid := auth.uid();
  otro uuid := (select id from arnes.gente where papel = 'B');
  intentos text[][] := array[
    ['sellados: el inversionista no se da de alta un papel validado',
     'validado', 'pasaporte', '%s/ps-1.pdf'],
    ['sellados: ni una resolucion, aunque entre como cargada',
     'cargado', 'resolucion', '%s/ps-2.pdf'],
    ['sellados: ni en la carpeta emitidos/, que es del equipo',
     'cargado', 'pasaporte', '%s/emitidos/ps-3.pdf'],
    ['sellados: ni con una ruta que sube de nivel',
     'cargado', 'pasaporte', '%s/../x/ps-4.pdf']];
  i int;
begin
  for i in 1 .. array_length(intentos, 1) loop
    begin
      insert into public.documentos (inversionista, tipo, archivo, nombre_original, estado)
      values (yo, intentos[i][3], format(intentos[i][4], yo), 'x.pdf', intentos[i][2]);
      perform arnes.comprueba(intentos[i][1], false, 'entro');
    exception when others then
      perform arnes.comprueba(intentos[i][1], true);
    end;
  end loop;

  begin
    insert into public.documentos (inversionista, tipo, archivo, nombre_original)
    values (yo, 'pasaporte', otro::text || '/ps-5.pdf', 'x.pdf');
    perform arnes.comprueba('sellados: ni apuntando a la carpeta de otro', false, 'entro');
  exception when others then
    perform arnes.comprueba('sellados: ni apuntando a la carpeta de otro', true);
  end;

  begin
    insert into public.documentos (inversionista, tipo, archivo, nombre_original, huella)
    values (yo, 'pasaporte', yo::text || '/ps-bueno.pdf', 'bueno.pdf', repeat('ef', 32));
    perform arnes.comprueba('sellados: el recaudo de siempre SI entra', true);
  exception when others then
    perform arnes.comprueba('sellados: el recaudo de siempre SI entra', false, sqlerrm);
  end;

  begin
    update public.documentos set estado = 'validado' where archivo = yo::text || '/ps-bueno.pdf';
    perform arnes.comprueba('sellados: ni se lo valida despues', false, 'entro');
  exception when others then
    perform arnes.comprueba('sellados: ni se lo valida despues', true);
  end;

  begin
    update public.documentos set revisado_por = (select id from arnes.gente where papel = 'G'),
                                 nota_revision = 'visto'
     where archivo = yo::text || '/ps-bueno.pdf';
    perform arnes.comprueba('sellados: ni se firma la revision', false, 'entro');
  exception when others then
    perform arnes.comprueba('sellados: ni se firma la revision', true);
  end;

  begin
    update public.documentos set vence_el = current_date + 365
     where archivo = yo::text || '/ps-bueno.pdf';
    perform arnes.comprueba('sellados: corregir la fecha de su papel SI se puede', true);
  exception when others then
    perform arnes.comprueba('sellados: corregir la fecha de su papel SI se puede', false, sqlerrm);
  end;
end
$ps$;

-- El equipo: valida el recaudo, firmando con otro nombre a proposito, y
-- entrega una resolucion en emitidos/.
select arnes.soy((select id from arnes.gente where papel = 'G'));

do $ps$
declare
  ana uuid := (select id from arnes.gente where papel = 'A');
begin
  update public.documentos
     set estado = 'validado', revisado_por = ana, revisado_en = '2020-01-01'
   where archivo = ana::text || '/ps-bueno.pdf';
  perform arnes.comprueba('sellados: el equipo SI valida, y firma el que valida',
    (select revisado_por = auth.uid() and revisado_en > now() - interval '1 minute'
       from public.documentos where archivo = ana::text || '/ps-bueno.pdf'),
    (select coalesce(revisado_por::text, 'nadie') from public.documentos
      where archivo = ana::text || '/ps-bueno.pdf'));

  insert into public.documentos (inversionista, tipo, archivo, nombre_original, estado, huella)
  values (ana, 'resolucion', ana::text || '/emitidos/ps-res.pdf', 'res.pdf', 'validado', repeat('cd', 32));
  perform arnes.comprueba('sellados: el equipo SI entrega en emitidos/', true);

  insert into storage.objects (bucket_id, name) values ('recaudos', ana::text || '/emitidos/ps-res.pdf');
exception when others then
  perform arnes.comprueba('sellados: el equipo SI entrega en emitidos/', false, sqlerrm);
end
$ps$;

reset role;
select arnes.nadie();
set role anon;
select arnes.comprueba('sellados: lo que emitio el CIIP SI consta',
  (select count(*) = 1 from public.verificar_documento(repeat('cd', 32))));
select arnes.comprueba('sellados: un recaudo validado no se verifica: su huella la puso el navegador',
  (select count(*) = 0 from public.verificar_documento(repeat('ef', 32))));
reset role;

-- El cubo.
insert into storage.objects (bucket_id, name)
select 'recaudos', id::text || '/ps-suelto.pdf' from arnes.gente where papel = 'A';
insert into storage.objects (bucket_id, name)
select 'recaudos', id::text || '/ps-bueno.pdf' from arnes.gente where papel = 'A';
insert into storage.objects (bucket_id, name)
select 'recaudos', id::text || '/perfil/foto' from arnes.gente where papel = 'A';

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $ps$
declare
  yo text := auth.uid()::text;
  n  int;
begin
  begin
    insert into storage.objects (bucket_id, name) values ('recaudos', yo || '/emitidos/falsa.pdf');
    perform arnes.comprueba('cubo: el inversionista no escribe en emitidos/', false, 'entro');
  exception when others then
    perform arnes.comprueba('cubo: el inversionista no escribe en emitidos/', true);
  end;

  begin
    insert into storage.objects (bucket_id, name) values ('recaudos', yo || '/pasaporte-nuevo.pdf');
    perform arnes.comprueba('cubo: subir a su carpeta SI se puede', true);
  exception when others then
    perform arnes.comprueba('cubo: subir a su carpeta SI se puede', false, sqlerrm);
  end;

  update storage.objects set creado_en = now() where name = yo || '/emitidos/ps-res.pdf';
  get diagnostics n = row_count;
  perform arnes.comprueba('cubo: lo emitido no se reemplaza', n = 0, n || ' filas');

  update storage.objects set creado_en = now() where name = yo || '/ps-suelto.pdf';
  get diagnostics n = row_count;
  perform arnes.comprueba('cubo: ni ningun otro archivo, fuera de la foto', n = 0, n || ' filas');

  update storage.objects set creado_en = now() where name = yo || '/perfil/foto';
  get diagnostics n = row_count;
  perform arnes.comprueba('cubo: la foto de perfil SI se reemplaza', n = 1, n || ' filas');

  delete from storage.objects where name = yo || '/emitidos/ps-res.pdf';
  get diagnostics n = row_count;
  perform arnes.comprueba('cubo: lo emitido no se borra', n = 0, n || ' filas');

  delete from storage.objects where name = yo || '/ps-bueno.pdf';
  get diagnostics n = row_count;
  perform arnes.comprueba('cubo: lo validado no se borra', n = 0, n || ' filas');

  delete from storage.objects where name = yo || '/ps-suelto.pdf';
  get diagnostics n = row_count;
  perform arnes.comprueba('cubo: lo suyo sin validar SI se borra', n = 1, n || ' filas');
end
$ps$;

reset role;
select arnes.nadie();

-- Una ficha vieja, de antes de la comprobacion, que apunta a la carpeta
-- de otro: al borrarla no se le manda el archivo ajeno al barrendero.
do $ps$
declare
  ana uuid := (select id from arnes.gente where papel = 'A');
  bru uuid := (select id from arnes.gente where papel = 'B');
  ficha uuid;
begin
  insert into public.documentos (inversionista, tipo, archivo, nombre_original)
  values (ana, 'pasaporte', bru::text || '/ps-ajeno.pdf', 'x.pdf')
  returning id into ficha;
  delete from public.documentos where id = ficha;
  perform arnes.comprueba('huerfanos: el barrendero no recibe rutas de otra carpeta',
    not exists (select 1 from public.archivos_huerfanos where ruta = bru::text || '/ps-ajeno.pdf'));
end
$ps$;



-- ══ 32 · LO DEL CIIP EN UN TRAMITE, Y EL BLOQUEO ENTERO ═══════════════
-- supabase-tramites-y-bloqueo.sql. Revision del 25 de septiembre, paso 2.

reset role;
select arnes.nadie();
insert into public.bancos_aliados (codigo, nombre) values ('ps-banco', 'Banco de prueba')
on conflict (codigo) do nothing;

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

-- Un borrador que nace con todo lo que es del CIIP ya puesto.
do $tb$
declare
  g    uuid := (select id from arnes.gente where papel = 'G');
  tipoAct text := (select codigo from public.tipos_tramite where activo order by codigo limit 1);
  nuevo uuid;
begin
  insert into public.tramites (inversionista, tipo, estado, gestor, banco, expediente_ente,
                               creado_en, enviado_en, resuelto_en)
  values (auth.uid(), tipoAct, 'borrador', g, 'ps-banco', 'EXP-FALSO',
          '2020-01-01', '2020-01-02', '2020-01-03')
  returning id into nuevo;
  insert into arnes.escenario values ('tb-tramite', nuevo);
  perform arnes.comprueba('tramites: al crearlo, lo del CIIP no se lo pone el inversionista',
    (select gestor is null and banco is null and expediente_ente is null
            and enviado_en is null and resuelto_en is null
            and creado_en > now() - interval '1 minute'
       from public.tramites where id = nuevo),
    (select format('gestor=%s banco=%s exp=%s creado=%s', gestor, banco, expediente_ente, creado_en)
       from public.tramites where id = nuevo));
exception when others then
  perform arnes.comprueba('tramites: al crearlo, lo del CIIP no se lo pone el inversionista', false, sqlerrm);
end
$tb$;

-- Y con el borrador en la mano, tampoco despues.
do $tb$
declare
  g  uuid := (select id from arnes.gente where papel = 'G');
  id_ uuid := (select id from arnes.escenario where clave = 'tb-tramite');
  otroTipo text := (select codigo from public.tipos_tramite t
                     where t.codigo <> (select tipo from public.tramites where id = id_)
                     order by codigo limit 1);
begin
  update public.tramites
     set gestor = g, banco = 'ps-banco', expediente_ente = 'EXP-FALSO',
         creado_en = '2020-01-01', enviado_en = '2020-01-02', resuelto_en = '2020-01-03',
         tipo = otroTipo, datos = '{"nota":"mia"}'
   where id = id_;
  perform arnes.comprueba('tramites: ni se asigna gestor, banco, expediente ni fechas en el borrador',
    (select gestor is null and banco is null and expediente_ente is null
            and enviado_en is null and resuelto_en is null
            and creado_en > now() - interval '1 minute'
            and tipo <> otroTipo
       from public.tramites where id = id_),
    (select format('gestor=%s banco=%s creado=%s tipo=%s', gestor, banco, creado_en, tipo)
       from public.tramites where id = id_));
  perform arnes.comprueba('tramites: pero sus datos SI los cambia',
    (select datos ->> 'nota' = 'mia' from public.tramites where id = id_));
exception when others then
  perform arnes.comprueba('tramites: ni se asigna gestor, banco, expediente ni fechas en el borrador', false, sqlerrm);
end
$tb$;

-- Enviarlo sigue sellando la fecha de envio, con la hora de la base.
do $tb$
declare id_ uuid := (select id from arnes.escenario where clave = 'tb-tramite');
begin
  update public.tramites set estado = 'enviado', enviado_en = '2020-01-02' where id = id_;
  perform arnes.comprueba('tramites: enviarlo SI se puede, y la fecha la pone la base',
    (select estado = 'enviado' and enviado_en > now() - interval '1 minute'
       from public.tramites where id = id_),
    (select format('estado=%s enviado=%s', estado, enviado_en) from public.tramites where id = id_));
exception when others then
  perform arnes.comprueba('tramites: enviarlo SI se puede, y la fecha la pone la base', false, sqlerrm);
end
$tb$;

-- Colgarse de la constitucion de otro para cortarle los tramos.
do $tb$
declare
  ajeno uuid;
  nuevo uuid;
  tipoAct text := (select codigo from public.tipos_tramite where activo order by codigo limit 1);
begin
  reset role;
  perform arnes.nadie();
  insert into public.tramites (inversionista, tipo, estado)
  values ((select id from arnes.gente where papel = 'G'), tipoAct, 'borrador')
  returning id into ajeno;
  set role authenticated;
  perform arnes.soy((select id from arnes.gente where papel = 'A'));
  begin
    insert into public.tramites (inversionista, tipo, estado, viene_de)
    values (auth.uid(), tipoAct, 'borrador', ajeno)
    returning id into nuevo;
    perform arnes.comprueba('tramites: no se cuelga de un tramite ajeno',
      (select viene_de is null from public.tramites where id = nuevo), 'quedo colgado');
  exception when others then
    perform arnes.comprueba('tramites: no se cuelga de un tramite ajeno', true, sqlerrm);
  end;
end
$tb$;

-- El equipo SI asigna.
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $tb$
declare id_ uuid := (select id from arnes.escenario where clave = 'tb-tramite');
begin
  update public.tramites set gestor = auth.uid(), banco = 'ps-banco', expediente_ente = 'EXP-1'
   where id = id_;
  perform arnes.comprueba('tramites: el equipo SI asigna gestor, banco y expediente',
    (select gestor = auth.uid() and banco = 'ps-banco' and expediente_ente = 'EXP-1'
       from public.tramites where id = id_));
exception when others then
  perform arnes.comprueba('tramites: el equipo SI asigna gestor, banco y expediente', false, sqlerrm);
end
$tb$;

-- EL BLOQUEO. Lo bloquea el admin (X), como en la seccion 30, y se prueba
-- todo lo que antes seguia pudiendo escribir.
reset role;
select arnes.soy((select id from arnes.gente where papel = 'X'));
update public.perfiles set bloqueado = true where id = (select id from arnes.gente where papel = 'A');
select arnes.nadie();

-- Las que existan: tramite_entes la pone supabase-entes-parafiscales.sql,
-- que no esta en la tanda.
select arnes.comprueba('bloqueo: el corte esta en las ocho tablas que faltaban',
  (select count(distinct tgrelid) = (select count(*) from unnest(array['tramite_mensajes','cita_mensajes',
            'consultas','consulta_mensajes','tramite_documentos','tramite_entes','empresas',
            'pliego_aceptaciones']) t where to_regclass('public.' || t) is not null)
     from pg_trigger
    where not tgisinternal and tgname like '%\_bloqueo'
      and tgrelid::regclass::text in ('tramite_mensajes','cita_mensajes','consultas','consulta_mensajes',
                                      'tramite_documentos','tramite_entes','empresas','pliego_aceptaciones')),
  (select string_agg(distinct tgrelid::regclass::text, ', ') from pg_trigger
    where not tgisinternal and tgname like '%\_bloqueo'));

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $tb$
declare
  id_ uuid := (select id from arnes.escenario where clave = 'tb-tramite');
  yo text := auth.uid()::text;
begin
  begin
    insert into public.tramite_mensajes (tramite, texto) values (id_, 'sigo aqui');
    perform arnes.comprueba('bloqueo: no escribe en el hilo', false, 'entro');
  exception when others then
    perform arnes.comprueba('bloqueo: no escribe en el hilo', true);
  end;

  begin
    insert into public.empresas (inversionista, razon_social) values (auth.uid(), 'Bloqueada C.A.')
    on conflict (inversionista) do update set razon_social = excluded.razon_social;
    perform arnes.comprueba('bloqueo: no toca su empresa', false, 'entro');
  exception when others then
    perform arnes.comprueba('bloqueo: no toca su empresa', true);
  end;

  begin
    insert into storage.objects (bucket_id, name) values ('recaudos', yo || '/bloqueada.pdf');
    perform arnes.comprueba('bloqueo: no sube archivos', false, 'entro');
  exception when others then
    perform arnes.comprueba('bloqueo: no sube archivos', true);
  end;
end
$tb$;

-- Y desbloqueada, vuelve a poder.
reset role;
select arnes.soy((select id from arnes.gente where papel = 'X'));
update public.perfiles set bloqueado = false where id = (select id from arnes.gente where papel = 'A');
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $tb$
begin
  insert into public.tramite_mensajes (tramite, texto)
  values ((select id from arnes.escenario where clave = 'tb-tramite'), 'ya puedo');
  perform arnes.comprueba('bloqueo: desbloqueada SI escribe en el hilo', true);
exception when others then
  perform arnes.comprueba('bloqueo: desbloqueada SI escribe en el hilo', false, sqlerrm);
end
$tb$;
reset role;
select arnes.nadie();



-- ══ 33 · EL TOPE DE LA IA, Y LA FIRMA DE LA OBSERVACION ═══════════════
-- supabase-tope-ia.sql y el retoque de supabase-papeles-sellados.sql.

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $ti$
declare i int; ult boolean; sigue boolean;
begin
  for i in 1 .. 40 loop ult := public.gasta_uso_ia('asistente'); end loop;
  sigue := public.gasta_uso_ia('asistente');
  perform arnes.comprueba('tope ia: cuarenta preguntas en una hora SI, la 41 no',
    ult and not sigue, format('la 40=%s la 41=%s', ult, sigue));
  for i in 1 .. 20 loop ult := public.gasta_uso_ia('lector'); end loop;
  sigue := public.gasta_uso_ia('lector');
  perform arnes.comprueba('tope ia: el lector, veinte papeles y no mas',
    ult and not sigue, format('el 20=%s el 21=%s', ult, sigue));
exception when others then
  perform arnes.comprueba('tope ia: cuarenta preguntas en una hora SI, la 41 no', false, sqlerrm);
end
$ti$;

select arnes.soy((select id from arnes.gente where papel = 'G'));
do $ti$
begin
  perform arnes.comprueba('tope ia: el cupo es de cada uno',
    public.gasta_uso_ia('asistente'));
exception when others then
  perform arnes.comprueba('tope ia: el cupo es de cada uno', false, sqlerrm);
end
$ti$;

do $ti$
begin
  perform public.gasta_uso_ia('otra-cosa');
  perform arnes.comprueba('tope ia: una pieza que no existe no se cuenta', false, 'entro');
exception when others then
  perform arnes.comprueba('tope ia: una pieza que no existe no se cuenta', true);
end
$ti$;

do $ti$
declare n int;
begin
  -- El arnes concede select sobre todo al empezar, asi que aqui el revoke
  -- no se ve: lo que se prueba es el RLS sin politicas. Hay filas (las de
  -- arriba) y no tiene que salir ninguna.
  select count(*) into n from public.uso_ia;
  perform arnes.comprueba('tope ia: la tabla no se lee desde fuera', n = 0, n || ' filas');
exception when others then
  perform arnes.comprueba('tope ia: la tabla no se lee desde fuera', true);
end
$ti$;

reset role;
select arnes.nadie();
select arnes.comprueba('tope ia: sin entrar no se puede ni llamar',
  not has_function_privilege('anon', 'public.gasta_uso_ia(text)', 'execute'));

-- La observacion: el gestor deja una nota sin tocar el estado, y la firma
-- es suya aunque el navegador mande otra.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $ti$
begin
  insert into public.documentos (inversionista, tipo, archivo, nombre_original)
  values (auth.uid(), 'pasaporte', auth.uid()::text || '/ti-obs.pdf', 'obs.pdf');
end
$ti$;
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $ti$
declare ana uuid := (select id from arnes.gente where papel = 'A');
begin
  update public.documentos
     set nota_revision = 'la foto sale borrosa', revisado_por = ana, revisado_en = '2020-01-01'
   where archivo = ana::text || '/ti-obs.pdf';
  perform arnes.comprueba('observacion: la firma es de quien la deja, con la hora de la base',
    (select estado = 'cargado' and revisado_por = auth.uid()
            and revisado_en > now() - interval '1 minute'
       from public.documentos where archivo = ana::text || '/ti-obs.pdf'),
    (select format('estado=%s por=%s en=%s', estado, revisado_por, revisado_en)
       from public.documentos where archivo = ana::text || '/ti-obs.pdf'));
exception when others then
  perform arnes.comprueba('observacion: la firma es de quien la deja, con la hora de la base', false, sqlerrm);
end
$ti$;
reset role;
select arnes.nadie();



-- ══ 34 · LO QUE VIVIA SOLO EN CORRER-HOY-2026-09-25.sql ═══════════════
-- Paso a las fuentes el 25-09: supabase-entes-parafiscales.sql,
-- supabase-confirma-paso.sql y supabase-tramites.sql.

reset role;
select arnes.nadie();
select arnes.comprueba('hoy: apostilla_previa esta en el catalogo de papeles',
  exists (select 1 from public.tipos_documento where codigo = 'apostilla_previa'));
select arnes.comprueba('hoy: c4 y c21 quedan apagados',
  (select count(*) = 2 and bool_and(not activo) from public.tipos_tramite
    where codigo in ('licencia_conducir', 'cert_medico')),
  (select string_agg(codigo || '=' || activo, ' ') from public.tipos_tramite
    where codigo in ('licencia_conducir', 'cert_medico')));
select arnes.comprueba('hoy: confirma_paso, para quien entro y no para anon',
  has_function_privilege('authenticated', 'public.confirma_paso(uuid,text)', 'execute')
  and not has_function_privilege('anon', 'public.confirma_paso(uuid,text)', 'execute'));

-- Las cinco inscripciones nacen al enviar la solicitud de parafiscales.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $hoy$
declare nuevo uuid; n int;
begin
  insert into public.tramites (inversionista, tipo, estado)
  values (auth.uid(), 'registros_parafiscales', 'borrador') returning id into nuevo;
  update public.tramites set estado = 'enviado' where id = nuevo;
  select count(*) into n from public.tramite_entes where tramite = nuevo and estado = 'pendiente';
  perform arnes.comprueba('hoy: al enviar los parafiscales nacen los seis entes, pendientes',
    n = 6, n || ' filas');
  insert into arnes.escenario values ('hoy-parafiscales', nuevo);
exception when others then
  perform arnes.comprueba('hoy: al enviar los parafiscales nacen los seis entes, pendientes', false, sqlerrm);
end
$hoy$;

-- Y el «ya me registre» marca el paso en un tramite propio en marcha.
do $hoy$
declare t uuid := (select id from arnes.escenario where clave = 'hoy-parafiscales');
begin
  perform public.confirma_paso(t, 'cancilleria_confirmada');
  perform arnes.comprueba('hoy: confirma_paso marca el paso en un tramite propio en marcha',
    (select datos ? 'cancilleria_confirmada' from public.tramites where id = t));
exception when others then
  perform arnes.comprueba('hoy: confirma_paso marca el paso en un tramite propio en marcha', false, sqlerrm);
end
$hoy$;
reset role;
select arnes.nadie();

-- La contraseña del IVSS se guarda mientras hace falta y se borra al quedar lista.
do $hoy$
declare t uuid := (select id from arnes.escenario where clave = 'hoy-parafiscales');
begin
  update public.tramite_entes set estado = 'codigo_enviado', codigo = 'usuario1', clave = 'secreta'
   where tramite = t and ente = 'ivss';
  perform arnes.comprueba('hoy: la contraseña del IVSS se guarda con el código enviado',
    (select clave = 'secreta' from public.tramite_entes where tramite = t and ente = 'ivss'));
  update public.tramite_entes set estado = 'listo' where tramite = t and ente = 'ivss';
  perform arnes.comprueba('hoy: al quedar lista, la contraseña del IVSS se borra y el usuario se queda',
    (select clave is null and codigo = 'usuario1' from public.tramite_entes where tramite = t and ente = 'ivss'));
exception when others then
  perform arnes.comprueba('hoy: al quedar lista, la contraseña del IVSS se borra y el usuario se queda', false, sqlerrm);
end
$hoy$;



-- ══ 35 · CANCELAR UNA SOLICITUD, MIENTRAS NO HAYA SALIDO DEL CIIP ══════
-- supabase-cancelar.sql (Franklin Reyes, 25-9-2026, 9f3386b).

reset role;
select arnes.nadie();
select arnes.comprueba('cancelar: sin entrar no se puede ni llamar',
  not has_function_privilege('anon', 'public.cancela_tramite(uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.cancela_tramite(uuid)', 'execute'));

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $ca$
declare
  t uuid; t2 uuid; t3 uuid;
  tipoAct text := (select codigo from public.tipos_tramite where activo and codigo <> 'registros_parafiscales' order by codigo desc limit 1);
begin
  insert into public.tramites (inversionista, tipo, estado) values (auth.uid(), tipoAct, 'borrador') returning id into t;
  update public.tramites set estado = 'enviado' where id = t;
  insert into arnes.escenario values ('ca-t', t);

  -- Saltarse la función: la política del inversionista no deja escribir 'cancelado'.
  begin
    update public.tramites set estado = 'cancelado' where id = t;
    perform arnes.comprueba('cancelar: a mano, sin la función, no se cancela',
      (select estado = 'enviado' from public.tramites where id = t),
      (select estado from public.tramites where id = t));
  exception when others then
    perform arnes.comprueba('cancelar: a mano, sin la función, no se cancela', true);
  end;

  perform public.cancela_tramite(t);
  perform arnes.comprueba('cancelar: la suya, recién enviada, SI se cancela',
    (select estado = 'cancelado' from public.tramites where id = t),
    (select estado from public.tramites where id = t));

  begin
    perform public.cancela_tramite(t);
    perform arnes.comprueba('cancelar: y cancelada no se vuelve a tocar', false, 'entro');
  exception when others then
    perform arnes.comprueba('cancelar: y cancelada no se vuelve a tocar', true);
  end;

  -- La una-viva no cuenta la cancelada: se puede pedir otra vez.
  begin
    insert into public.tramites (inversionista, tipo, estado) values (auth.uid(), tipoAct, 'borrador') returning id into t2;
    update public.tramites set estado = 'enviado' where id = t2;
    perform arnes.comprueba('cancelar: y después se puede volver a pedir el mismo trámite', true);
    insert into arnes.escenario values ('ca-t2', t2);
  exception when others then
    perform arnes.comprueba('cancelar: y después se puede volver a pedir el mismo trámite', false, sqlerrm);
  end;
end
$ca$;

-- Lo que ya está ante el ente no se cancela: tiene un número fuera.
select arnes.soy((select id from arnes.gente where papel = 'G'));
update public.tramites set estado = 'en_revision' where id = (select id from arnes.escenario where clave = 'ca-t2');
update public.tramites set estado = 'ante_el_ente' where id = (select id from arnes.escenario where clave = 'ca-t2');
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $ca$
begin
  perform public.cancela_tramite((select id from arnes.escenario where clave = 'ca-t2'));
  perform arnes.comprueba('cancelar: ante el ente, no', false, 'se cancelo');
exception when others then
  perform arnes.comprueba('cancelar: ante el ente, no', true);
end
$ca$;

-- Lo de otro, tampoco.
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $ca$
declare t uuid;
  -- Uno que G no tenga ya en marcha: si no, choca con la una-viva.
  tipoAct text := (select t.codigo from public.tipos_tramite t where t.activo and t.codigo <> 'registros_parafiscales'
      and not exists (select 1 from public.tramites x where x.inversionista = (select id from arnes.gente where papel = 'G')
                        and x.tipo = t.codigo and x.estado in ('enviado','en_revision','ante_el_ente'))
      order by t.codigo limit 1);
begin
  reset role; perform arnes.nadie();
  insert into public.tramites (inversionista, tipo, estado) values ((select id from arnes.gente where papel = 'G'), tipoAct, 'enviado') returning id into t;
  insert into arnes.escenario values ('ca-ajeno', t);
end
$ca$;
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $ca$
begin
  perform public.cancela_tramite((select id from arnes.escenario where clave = 'ca-ajeno'));
  perform arnes.comprueba('cancelar: lo de otro, no', false, 'se cancelo');
exception when others then
  perform arnes.comprueba('cancelar: lo de otro, no', true);
end
$ca$;

-- Y con la cuenta bloqueada, tampoco.
reset role;
select arnes.soy((select id from arnes.gente where papel = 'X'));
update public.perfiles set bloqueado = true where id = (select id from arnes.gente where papel = 'A');
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $ca$
declare t uuid;
  tipoAct text := (select t.codigo from public.tipos_tramite t where t.activo and t.codigo <> 'registros_parafiscales'
      and not exists (select 1 from public.tramites x where x.inversionista = (select id from arnes.gente where papel = 'A')
                        and x.tipo = t.codigo and x.estado in ('enviado','en_revision','ante_el_ente'))
      order by t.codigo limit 1);
begin
  reset role; perform arnes.nadie();
  insert into public.tramites (inversionista, tipo, estado) values ((select id from arnes.gente where papel = 'A'), tipoAct, 'enviado') returning id into t;
  set role authenticated;
  perform arnes.soy((select id from arnes.gente where papel = 'A'));
  begin
    perform public.cancela_tramite(t);
    perform arnes.comprueba('cancelar: con la cuenta bloqueada, no', false, 'se cancelo');
  exception when others then
    perform arnes.comprueba('cancelar: con la cuenta bloqueada, no', true);
  end;
end
$ca$;
reset role;
select arnes.soy((select id from arnes.gente where papel = 'X'));
update public.perfiles set bloqueado = false where id = (select id from arnes.gente where papel = 'A');
select arnes.nadie();

-- ══ 36 · LA REVISIÓN DE TRÁMITES Y PAPELES (QA, 28-9-2026) ═══════════
-- supabase-qa-tramites.sql. Cada bloque recoge su propio error: uno que
-- revienta apunta su FALLA y deja correr a los demás.

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $qa$
declare
  t uuid; d uuid;
  tipoAct text := (select x.codigo from public.tipos_tramite x where x.activo and x.codigo <> 'registros_parafiscales'
      and not exists (select 1 from public.tramites o where o.inversionista = auth.uid()
                        and o.tipo = x.codigo and o.estado in ('enviado','en_revision','ante_el_ente'))
      order by x.codigo limit 1);
begin
  insert into public.tramites (inversionista, tipo, estado) values (auth.uid(), tipoAct, 'borrador') returning id into t;
  insert into public.documentos (inversionista, tipo, archivo, nombre_original)
  values (auth.uid(), 'pasaporte', auth.uid()::text || '/qa-papel.pdf', 'qa.pdf') returning id into d;
  insert into public.tramite_documentos (tramite, documento) values (t, d);
  insert into arnes.escenario values ('qa-t', t), ('qa-d', d);

  -- En borrador el papel es de quien lo rellena.
  begin
    update public.documentos set archivo = auth.uid()::text || '/qa-papel-2.pdf' where id = d;
    perform arnes.comprueba('qa: en borrador, el archivo de un papel enganchado se cambia',
      (select archivo like '%/qa-papel-2.pdf' from public.documentos where id = d));
  exception when others then
    perform arnes.comprueba('qa: en borrador, el archivo de un papel enganchado se cambia', false, sqlerrm);
  end;

  update public.tramites set estado = 'enviado' where id = t;

  begin
    update public.documentos set archivo = auth.uid()::text || '/qa-otro.pdf' where id = d;
    perform arnes.comprueba('qa: enviada, el archivo del papel ya no se cambia',
      (select archivo like '%/qa-papel-2.pdf' from public.documentos where id = d), 'se cambio');
  exception when others then
    perform arnes.comprueba('qa: enviada, el archivo del papel ya no se cambia', true);
  end;

  begin
    update public.documentos set tipo = 'domicilio' where id = d;
    perform arnes.comprueba('qa: ni su tipo',
      (select tipo = 'pasaporte' from public.documentos where id = d), 'se cambio');
  exception when others then
    perform arnes.comprueba('qa: ni su tipo', true);
  end;

  -- Lo que no es archivo ni tipo sigue siendo suyo.
  begin
    update public.documentos set vence_el = current_date + 400 where id = d;
    perform arnes.comprueba('qa: la fecha de vencimiento sí se corrige',
      (select vence_el = current_date + 400 from public.documentos where id = d));
  exception when others then
    perform arnes.comprueba('qa: la fecha de vencimiento sí se corrige', false, sqlerrm);
  end;

  begin
    delete from public.documentos where id = d;
    perform arnes.comprueba('qa: y no se borra mientras la solicitud está en marcha',
      exists (select 1 from public.documentos where id = d), 'se borro');
  exception when others then
    perform arnes.comprueba('qa: y no se borra mientras la solicitud está en marcha', true);
  end;
exception when others then
  perform arnes.comprueba('qa: el escenario del inversionista se monta', false, sqlerrm);
end
$qa$;

-- Lo que la base deja pendiente de esa solicitud: un trabajo y una orden.
reset role;
select arnes.nadie();
do $qa$
declare t uuid := (select id from arnes.escenario where clave = 'qa-t');
begin
  insert into public.trabajos (tramite, tarea, llave) values (t, 'presentar', t::text)
  on conflict do nothing;
  insert into public.ordenes_pago (tramite, inversionista, concepto, monto)
  values (t, (select id from arnes.gente where papel = 'A'), 'Tasa de prueba', 10)
  on conflict do nothing;
exception when others then
  perform arnes.comprueba('qa: el trabajo y la orden se siembran', false, sqlerrm);
end
$qa$;

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $qa$
declare t uuid := (select id from arnes.escenario where clave = 'qa-t');
begin
  -- La nota del envío es de A: el gestor no la reescribe.
  update public.tramite_eventos set nota = 'reescrita' where tramite = t and a_estado = 'enviado';
  perform arnes.comprueba('qa: un gestor no reescribe la nota de un evento que no es suyo',
    not exists (select 1 from public.tramite_eventos where tramite = t and nota = 'reescrita'));

  update public.tramites set estado = 'cancelado' where id = t;
  perform arnes.comprueba('qa: el equipo cancela una solicitud que sigue en el CIIP',
    (select estado = 'cancelado' from public.tramites where id = t),
    (select estado from public.tramites where id = t));

  update public.tramite_eventos set nota = 'Lleva un mes sin contestar.'
   where tramite = t and a_estado = 'cancelado';
  perform arnes.comprueba('qa: y el motivo va en su propio evento, recién hecho',
    exists (select 1 from public.tramite_eventos
             where tramite = t and a_estado = 'cancelado' and nota like 'Lleva un mes%'));
exception when others then
  perform arnes.comprueba('qa: el equipo cancela una solicitud que sigue en el CIIP', false, sqlerrm);
end
$qa$;

reset role;
select arnes.nadie();
select arnes.comprueba('qa: al cancelar, el trabajo de presentarla se anula',
  (select coalesce(bool_and(estado = 'anulado'), false) from public.trabajos
    where tramite = (select id from arnes.escenario where clave = 'qa-t')),
  (select coalesce(string_agg(estado, ', '), 'ninguno') from public.trabajos
    where tramite = (select id from arnes.escenario where clave = 'qa-t')));
select arnes.comprueba('qa: y la orden de pago pendiente también',
  (select coalesce(bool_and(estado = 'anulada'), false) from public.ordenes_pago
    where tramite = (select id from arnes.escenario where clave = 'qa-t')),
  (select coalesce(string_agg(estado, ', '), 'ninguna') from public.ordenes_pago
    where tramite = (select id from arnes.escenario where clave = 'qa-t')));

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $qa$
declare
  t uuid := (select id from arnes.escenario where clave = 'qa-t');
  d uuid := (select id from arnes.escenario where clave = 'qa-d');
begin
  begin
    perform public.confirma_paso(t, 'cancilleria_confirmada');
    perform arnes.comprueba('qa: confirma_paso no toca una cancelada', false, 'la marco');
  exception when others then
    perform arnes.comprueba('qa: confirma_paso no toca una cancelada', true);
  end;

  begin
    delete from public.documentos where id = d;
    perform arnes.comprueba('qa: cancelada, el papel ya se puede borrar',
      not exists (select 1 from public.documentos where id = d), 'sigue');
  exception when others then
    perform arnes.comprueba('qa: cancelada, el papel ya se puede borrar', false, sqlerrm);
  end;
end
$qa$;

-- Los registros parafiscales: resolver pide los seis entes listos.
reset role;
select arnes.nadie();
do $qa$
declare
  t uuid;
  quien uuid;
begin
  -- Una cuenta propia: B ya se borró más arriba, y las de los demás las
  -- usan las pruebas de «hoy» para sus propios parafiscales.
  insert into auth.users (email, raw_user_meta_data)
  values ('pf@prueba.local', '{"nombre_completo":"Pía Parafiscal","pais":"Chile"}')
  returning id into quien;
  insert into public.tramites (inversionista, tipo, estado, datos)
  values (quien, 'registros_parafiscales', 'ante_el_ente', '{"razon_social":"Bruno Frutas, C.A."}')
  returning id into t;
  insert into arnes.escenario values ('qa-pf', t);
exception when others then
  perform arnes.comprueba('qa: la parafiscal de prueba se monta', false, sqlerrm);
end
$qa$;

select arnes.comprueba('qa: mezclar datos no se ofrece sin entrar',
  not has_function_privilege('anon', 'public.mezcla_datos_tramite(uuid, jsonb)', 'execute')
  and has_function_privilege('authenticated', 'public.mezcla_datos_tramite(uuid, jsonb)', 'execute'));

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $qa$
declare t uuid := (select id from arnes.escenario where clave = 'qa-pf');
begin
  begin
    update public.tramites set estado = 'resuelto' where id = t;
    perform arnes.comprueba('qa: una parafiscal no se resuelve con entes sin terminar',
      (select estado = 'ante_el_ente' from public.tramites where id = t), 'se resolvio');
  exception when others then
    perform arnes.comprueba('qa: una parafiscal no se resuelve con entes sin terminar', true);
  end;

  perform public.mezcla_datos_tramite(t, '{"numero_registro":"77"}'::jsonb);
  perform arnes.comprueba('qa: mezclar datos añade la clave sin pisar las demás',
    (select datos->>'razon_social' = 'Bruno Frutas, C.A.' and datos->>'numero_registro' = '77'
       from public.tramites where id = t),
    (select datos::text from public.tramites where id = t));
exception when others then
  perform arnes.comprueba('qa: mezclar datos añade la clave sin pisar las demás', false, sqlerrm);
end
$qa$;

reset role;
select arnes.nadie();
update public.tramite_entes set estado = 'listo'
 where tramite = (select id from arnes.escenario where clave = 'qa-pf');

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $qa$
declare t uuid := (select id from arnes.escenario where clave = 'qa-pf');
begin
  update public.tramites set estado = 'resuelto' where id = t;
  perform arnes.comprueba('qa: con los seis listos, sí se resuelve',
    (select estado = 'resuelto' from public.tramites where id = t),
    (select estado from public.tramites where id = t));
exception when others then
  perform arnes.comprueba('qa: con los seis listos, sí se resuelve', false, sqlerrm);
end
$qa$;
reset role;
select arnes.nadie();




-- ══ 37 · CITAS Y CONSULTAS: LO QUE ENCONTRÓ LA AUDITORÍA QA ═══════════
-- supabase-qa-atencion.sql. Una cuenta propia, Q, para no pisar las citas
-- que las secciones de arriba le dejaron a A.

reset role;
select arnes.nadie();
insert into auth.users (email, raw_user_meta_data) values
  ('q@prueba.local', '{"nombre_completo":"Quique Citas","pais":"Italia"}');
insert into arnes.gente (papel, id)
select 'Q', id from auth.users where email = 'q@prueba.local';

-- Un viernes de 9 a 12 que seguro existe, y una cita de Q confirmada que
-- ya pasó: la que antes le bloqueaba para siempre.
insert into public.horario_citas (dia, desde, hasta, cada_min) values (5, '09:00', '12:00', 30);
do $qa$
declare c uuid;
begin
  insert into public.citas (inversionista, modo, desde, hasta, estado, cuando)
  values ((select id from arnes.gente where papel = 'Q'), 'video',
          current_date - 10, current_date - 10, 'confirmada', now() - interval '10 days')
  returning id into c;
  insert into arnes.escenario values ('qa-pasada', c);
end
$qa$;

-- QA-02: con la pasada sin cerrar, reservar ya no dice «en marcha».
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'Q'));
do $qa$
declare
  viernes date := (date_trunc('week', (now() at time zone 'America/Caracas'))::date + 11);
  fila public.citas;
begin
  fila := public.reserva_cita(((viernes + time '10:00') at time zone 'America/Caracas'), 'video');
  insert into arnes.escenario values ('qa-nueva', fila.id);
  perform arnes.comprueba('qa citas: una cita que ya pasó no bloquea la siguiente', true);
exception when others then
  perform arnes.comprueba('qa citas: una cita que ya pasó no bloquea la siguiente', false, sqlerrm);
end
$qa$;

select arnes.comprueba('qa citas: y la pasada queda dada por hecha',
  coalesce((select estado = 'hecha' from public.citas
             where id = (select id from arnes.escenario where clave = 'qa-pasada')), false),
  (select estado from public.citas where id = (select id from arnes.escenario where clave = 'qa-pasada')));

-- QA-29: con una viva, una segunda por la API no entra.
do $qa$
begin
  insert into public.citas (inversionista, modo, desde, hasta)
  values (auth.uid(), 'telefono', current_date + 1, current_date + 5);
  perform arnes.comprueba('qa citas: una segunda viva por la API no entra', false, 'entro');
exception when others then
  perform arnes.comprueba('qa citas: una segunda viva por la API no entra', true, sqlerrm);
end
$qa$;

-- QA-31: la confirmada no se cambia de modo ni de nota; cancelarla, sí.
do $qa$
declare c uuid := (select id from arnes.escenario where clave = 'qa-nueva');
begin
  update public.citas set modo = 'presencial' where id = c;
  perform arnes.comprueba('qa citas: el inversionista no cambia el modo', false, 'lo cambio');
exception when others then
  perform arnes.comprueba('qa citas: el inversionista no cambia el modo', true, sqlerrm);
end
$qa$;
do $qa$
declare c uuid := (select id from arnes.escenario where clave = 'qa-nueva');
begin
  update public.citas set nota = 'otra cosa' where id = c;
  perform arnes.comprueba('qa citas: ni la nota', false, 'la cambio');
exception when others then
  perform arnes.comprueba('qa citas: ni la nota', true, sqlerrm);
end
$qa$;

-- QA-20: confirmar es del equipo, no de quien pide.
do $qa$
begin
  perform public.confirma_cita((select id from arnes.escenario where clave = 'qa-nueva'),
                               now() + interval '3 days', '', 'por probar');
  perform arnes.comprueba('qa citas: el inversionista no se confirma una cita', false, 'la confirmo');
exception when others then
  perform arnes.comprueba('qa citas: el inversionista no se confirma una cita', true, sqlerrm);
end
$qa$;

-- Del lado del equipo.
select arnes.soy((select id from arnes.gente where papel = 'G'));

do $qa$
begin
  perform public.confirma_cita((select id from arnes.escenario where clave = 'qa-nueva'),
                               now() - interval '1 hour', '', 'por probar');
  perform arnes.comprueba('qa citas: no se confirma para una hora pasada', false, 'la confirmo');
exception when others then
  perform arnes.comprueba('qa citas: no se confirma para una hora pasada', true, sqlerrm);
end
$qa$;

do $qa$
declare
  viernes date := (date_trunc('week', (now() at time zone 'America/Caracas'))::date + 11);
begin
  perform public.confirma_cita((select id from arnes.escenario where clave = 'qa-nueva'),
                               ((viernes + time '11:00') at time zone 'America/Caracas'), '', '');
  perform arnes.comprueba('qa citas: moverla sin decir por qué no se puede', false, 'la movio');
exception when others then
  perform arnes.comprueba('qa citas: moverla sin decir por qué no se puede', true, sqlerrm);
end
$qa$;

do $qa$
declare
  viernes date := (date_trunc('week', (now() at time zone 'America/Caracas'))::date + 11);
  fila public.citas;
begin
  fila := public.confirma_cita((select id from arnes.escenario where clave = 'qa-nueva'),
                               ((viernes + time '11:00') at time zone 'America/Caracas'),
                               '', 'Se nos cruzó una reunión');
  perform arnes.comprueba('qa citas: con motivo, el equipo la mueve',
    fila.cuando = ((viernes + time '11:00') at time zone 'America/Caracas')
    and fila.motivo = 'Se nos cruzó una reunión', fila.motivo);
exception when others then
  perform arnes.comprueba('qa citas: con motivo, el equipo la mueve', false, sqlerrm);
end
$qa$;

do $qa$
begin
  update public.citas set estado = 'no_asistio'
   where id = (select id from arnes.escenario where clave = 'qa-nueva');
  perform arnes.comprueba('qa citas: una cita futura no se cierra', false, 'la cerro');
exception when others then
  perform arnes.comprueba('qa citas: una cita futura no se cierra', true, sqlerrm);
end
$qa$;

do $qa$
begin
  update public.citas set estado = 'cancelada', motivo = ''
   where id = (select id from arnes.escenario where clave = 'qa-nueva');
  perform arnes.comprueba('qa citas: el CIIP no cancela sin motivo', false, 'la cancelo');
exception when others then
  perform arnes.comprueba('qa citas: el CIIP no cancela sin motivo', true, sqlerrm);
end
$qa$;

update public.citas set estado = 'cancelada', motivo = 'El gestor está enfermo'
 where id = (select id from arnes.escenario where clave = 'qa-nueva');
select arnes.comprueba('qa citas: con motivo sí, y queda dicho que fue el CIIP',
  coalesce((select estado = 'cancelada' and cancelada_por_ciip from public.citas
             where id = (select id from arnes.escenario where clave = 'qa-nueva')), false),
  'cero filas: ¿falta la política de update del equipo?');

-- QA-02: la pasada se puede cerrar como «no asistió».
update public.citas set estado = 'no_asistio'
 where id = (select id from arnes.escenario where clave = 'qa-pasada');
select arnes.comprueba('qa citas: la que ya pasó se cierra como no asistió',
  coalesce((select estado = 'no_asistio' from public.citas
             where id = (select id from arnes.escenario where clave = 'qa-pasada')), false));

-- QA-03: una consulta resuelta vuelve a la cola si el inversionista escribe.
-- QA-04: y el equipo puede abrirle una a nombre suyo.
do $qa$
declare fila public.consultas;
begin
  fila := public.abre_consulta_para((select id from arnes.gente where papel = 'Q'), 'Sobre tu cita');
  insert into arnes.escenario values ('qa-consulta', fila.id);
  perform arnes.comprueba('qa consultas: el equipo abre una consulta a nombre de otro',
    fila.inversionista = (select id from arnes.gente where papel = 'Q')
    and fila.gestor = auth.uid() and fila.estado = 'en_curso',
    fila.inversionista::text || ' ' || fila.estado);
exception when others then
  perform arnes.comprueba('qa consultas: el equipo abre una consulta a nombre de otro', false, sqlerrm);
end
$qa$;

update public.consultas set estado = 'resuelta'
 where id = (select id from arnes.escenario where clave = 'qa-consulta');

select arnes.soy((select id from arnes.gente where papel = 'Q'));
do $qa$
begin
  perform public.abre_consulta_para((select id from arnes.gente where papel = 'A'), 'a nombre de otro');
  perform arnes.comprueba('qa consultas: el inversionista no abre consultas a nombre de otro', false, 'la abrio');
exception when others then
  perform arnes.comprueba('qa consultas: el inversionista no abre consultas a nombre de otro', true, sqlerrm);
end
$qa$;

-- Desde d2c3e8f (5-10-2026) una resuelta ya no admite mensajes: la base
-- los rechaza y reabrir es cosa del equipo, con «Reabrir».
do $qa$
begin
  insert into public.consulta_mensajes (consulta, texto)
  values ((select id from arnes.escenario where clave = 'qa-consulta'), 'Una cosa más');
  perform arnes.comprueba('qa consultas: en una resuelta el inversionista no escribe', false, 'entro el mensaje');
exception when others then
  perform arnes.comprueba('qa consultas: en una resuelta el inversionista no escribe', true, sqlerrm);
end
$qa$;

select arnes.comprueba('qa consultas: escribir en una resuelta no la reabre',
  coalesce((select estado = 'resuelta' from public.consultas
             where id = (select id from arnes.escenario where clave = 'qa-consulta')), false),
  (select estado from public.consultas where id = (select id from arnes.escenario where clave = 'qa-consulta')));

reset role;
select arnes.nadie();


-- ══ 38 · AUDITORIA QA: CUENTAS Y ADMINISTRACION ═══════════════════════
-- supabase-qa-admin.sql. Bloquear a alguien del equipo le quita los
-- permisos, la baja no borra, el admin no reescribe perfiles ajenos y las
-- columnas de rastro no las pone el navegador.

-- Un segundo admin, Z, para poder bloquear a un admin: desde el editor no
-- se bloquea a nadie (guarda_el_bloqueo pide un admin con sesion).
reset role;
select arnes.nadie();
insert into auth.users (email, raw_user_meta_data)
values ('z@prueba.local', '{"nombre_completo":"Zoe Admin","pais":"Chile"}');
insert into arnes.gente (papel, id) select 'Z', id from auth.users where email = 'z@prueba.local';
update public.perfiles set rol = 'admin' where id = (select id from arnes.gente where papel = 'Z');

select arnes.soy((select id from arnes.gente where papel = 'X'));
update public.perfiles set bloqueado = true
 where id in (select id from arnes.gente where papel in ('G', 'Z'));

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $qa$
begin
  perform arnes.comprueba('qa-05: un gestor bloqueado deja de ser del equipo', not public.es_gestor());
  perform arnes.comprueba('qa-05: y deja de ver los tramites de los demas',
    (select count(*) = 0 from public.tramites where inversionista <> auth.uid()));
  perform arnes.comprueba('qa-05: y no gasta IA', not public.gasta_uso_ia('asistente'));
  begin
    insert into public.horario_citas (dia, desde, hasta) values (4, '15:00', '16:00');
    perform arnes.comprueba('qa-05: ni toca el horario de citas', false, 'entro');
  exception when others then
    perform arnes.comprueba('qa-05: ni toca el horario de citas', true);
  end;
exception when others then
  perform arnes.comprueba('qa-05: un gestor bloqueado deja de ser del equipo', false, sqlerrm);
end
$qa$;

select arnes.soy((select id from arnes.gente where papel = 'Z'));
do $qa$
declare n int;
begin
  perform arnes.comprueba('qa-05: un admin bloqueado deja de ser admin', not public.es_admin());
  begin
    -- Bloqueado ya no ve el perfil ajeno: leer el rol de antes desde aquí
    -- daba null y la prueba fallaba siempre. Basta con que no toque filas.
    update public.perfiles set rol = 'gestor'
     where id = (select id from arnes.gente where papel = 'A');
    get diagnostics n = row_count;
    perform arnes.comprueba('qa-05: y no reparte roles', n = 0, 'lo cambio');
  exception when others then
    perform arnes.comprueba('qa-05: y no reparte roles', true);
  end;
end
$qa$;

reset role;
select arnes.soy((select id from arnes.gente where papel = 'X'));
update public.perfiles set bloqueado = false
 where id in (select id from arnes.gente where papel in ('G', 'Z'));
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));
select arnes.comprueba('qa-05: desbloqueado, vuelve a ser del equipo', public.es_gestor());
select arnes.comprueba('qa-05: y vuelve a tener IA', public.gasta_uso_ia('asistente'));

-- QA-26: el admin no reescribe el perfil de otro.
select arnes.soy((select id from arnes.gente where papel = 'X'));
do $qa$
begin
  update public.perfiles set nombre_completo = 'Otra Persona', pais = 'Marte'
   where id = (select id from arnes.gente where papel = 'A');
  perform arnes.comprueba('qa-26: el admin no cambia el nombre de otro', false, 'lo cambio');
exception when others then
  perform arnes.comprueba('qa-26: el admin no cambia el nombre de otro', true);
end
$qa$;
select arnes.comprueba('qa-26: y el nombre sigue siendo el suyo',
  (select nombre_completo = 'Ana Inversionista' from public.perfiles
    where id = (select id from arnes.gente where papel = 'A')),
  (select nombre_completo from public.perfiles where id = (select id from arnes.gente where papel = 'A')));

-- QA-40: las columnas de rastro del propio perfil no las pone uno mismo.
select arnes.soy((select id from arnes.gente where papel = 'A'));
do $qa$
declare antes timestamptz;
begin
  select rol_cambiado_en into antes from public.perfiles where id = auth.uid();
  update public.perfiles
     set rol_cambiado_en = '2000-01-01', rol_cambiado_por = auth.uid(),
         bloqueado_en = '2000-01-01', visto_en = '2000-01-01',
         nombre_completo = 'Ana I.'
   where id = auth.uid();
  perform arnes.comprueba('qa-40: rol_cambiado_en no se falsea',
    (select rol_cambiado_en is not distinct from antes and rol_cambiado_por is distinct from auth.uid()
       from public.perfiles where id = auth.uid()));
  perform arnes.comprueba('qa-40: bloqueado_en tampoco',
    (select bloqueado_en is distinct from '2000-01-01'::timestamptz from public.perfiles where id = auth.uid()));
  perform arnes.comprueba('qa-40: y visto_en solo puede ser ahora',
    (select visto_en > now() - interval '1 minute' from public.perfiles where id = auth.uid()));
  perform arnes.comprueba('qa-40: pero su nombre SI lo cambia',
    (select nombre_completo = 'Ana I.' from public.perfiles where id = auth.uid()));
  update public.perfiles set nombre_completo = 'Ana Inversionista' where id = auth.uid();
exception when others then
  perform arnes.comprueba('qa-40: rol_cambiado_en no se falsea', false, sqlerrm);
end
$qa$;

-- QA-06: la baja. Nadie se la da a si mismo.
do $qa$
begin
  update public.perfiles set dado_de_baja_en = now() where id = auth.uid();
  perform arnes.comprueba('qa-06: nadie se da de baja a si mismo',
    (select dado_de_baja_en is null from public.perfiles where id = auth.uid()), 'se dio de baja');
exception when others then
  perform arnes.comprueba('qa-06: nadie se da de baja a si mismo', true);
end
$qa$;

select arnes.soy((select id from arnes.gente where papel = 'X'));
do $qa$
declare
  a  uuid := (select id from arnes.gente where papel = 'A');
  x  uuid := (select id from arnes.gente where papel = 'X');
  n0 bigint := (select coalesce(max(id), 0) from public.bitacora);
begin
  update public.perfiles set dado_de_baja_en = now() where id = a;
  perform arnes.comprueba('qa-06: el admin da de baja, y la cuenta queda bloqueada',
    (select bloqueado and dado_de_baja_en is not null and dado_de_baja_por = x
       from public.perfiles where id = a));
  perform arnes.comprueba('qa-06: y su historia sigue ahi',
    (select count(*) > 0 from public.tramites where inversionista = a));
  perform arnes.comprueba('qa-06: y la baja queda en la bitacora',
    exists (select 1 from public.bitacora where id > n0 and fuente = 'roles' and accion = 'baja'));
  begin
    update public.perfiles set bloqueado = false where id = a;
    perform arnes.comprueba('qa-06: dada de baja no se desbloquea sin deshacer la baja',
      (select bloqueado from public.perfiles where id = a), 'se desbloqueo');
  exception when others then
    perform arnes.comprueba('qa-06: dada de baja no se desbloquea sin deshacer la baja', true);
  end;
  update public.perfiles set dado_de_baja_en = null where id = a;
  update public.perfiles set bloqueado = false where id = a;
  perform arnes.comprueba('qa-06: y deshecha la baja, se desbloquea',
    (select not bloqueado and dado_de_baja_en is null from public.perfiles where id = a));
exception when others then
  perform arnes.comprueba('qa-06: el admin da de baja, y la cuenta queda bloqueada', false, sqlerrm);
end
$qa$;

-- QA-27: el cambio de rol guarda el de antes.
do $qa$
declare n0 bigint := (select coalesce(max(id), 0) from public.bitacora);
begin
  update public.perfiles set rol = 'gestor' where id = (select id from arnes.gente where papel = 'Z');
  perform arnes.comprueba('qa-27: la bitacora guarda el rol de antes',
    exists (select 1 from public.bitacora where id > n0 and fuente = 'roles' and accion = 'rol'
             and detalle::json ->> 'rol' = 'gestor' and detalle::json ->> 'antes' = 'admin'),
    (select string_agg(detalle, ' | ') from public.bitacora where id > n0));
exception when others then
  perform arnes.comprueba('qa-27: la bitacora guarda el rol de antes', false, sqlerrm);
end
$qa$;

-- QA-07: el correo, solo para el admin.
do $qa$
begin
  perform arnes.comprueba('qa-07: el admin ve el correo de cada cuenta',
    exists (select 1 from public.correos_de_las_cuentas() c
             where c.id = (select id from arnes.gente where papel = 'A')
               and c.correo = (select email from auth.users where id = c.id)));
exception when others then
  perform arnes.comprueba('qa-07: el admin ve el correo de cada cuenta', false, sqlerrm);
end
$qa$;
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $qa$
begin
  perform count(*) from public.correos_de_las_cuentas();
  perform arnes.comprueba('qa-07: un gestor no', false, 'los vio');
exception when others then
  perform arnes.comprueba('qa-07: un gestor no', true);
end
$qa$;
reset role;
select arnes.nadie();
select arnes.comprueba('qa-07: ni quien no ha entrado',
  not has_function_privilege('anon', 'public.correos_de_las_cuentas()', 'execute'));

-- QA-43: sin sesion no se miran huecos ni se reserva.
select arnes.comprueba('qa-43: huecos_ocupados cerrada a anon',
  not has_function_privilege('anon', 'public.huecos_ocupados(date, date)', 'execute'));
select arnes.comprueba('qa-43: reserva_cita cerrada a anon',
  not has_function_privilege('anon', 'public.reserva_cita(timestamptz, text, text, text)', 'execute'));

-- QA-43: el original de un texto no se reescribe al volver a guardar.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'X'));
do $qa$
begin
  insert into public.textos_panel (clave, idioma, texto, original)
  values ('qa.prueba', 'es', 'uno', 'el de fabrica');
  insert into public.textos_panel (clave, idioma, texto, original)
  values ('qa.prueba', 'es', 'dos', 'inventado')
  on conflict (clave, idioma) do update set texto = excluded.texto, original = excluded.original;
  perform arnes.comprueba('qa-43: el original del texto no lo reescribe un guardado',
    (select original = 'el de fabrica' and texto = 'dos' from public.textos_panel
      where clave = 'qa.prueba' and idioma = 'es'),
    (select original from public.textos_panel where clave = 'qa.prueba' and idioma = 'es'));
  delete from public.textos_panel where clave = 'qa.prueba';
exception when others then
  perform arnes.comprueba('qa-43: el original del texto no lo reescribe un guardado', false, sqlerrm);
end
$qa$;

-- QA-06: una cuenta que acepto el pliego no se borra por descuido; con
-- la marca puesta a sabiendas, si.
reset role;
select arnes.nadie();
do $qa$
declare
  quien uuid;
  v     int := 91;
begin
  -- Uno sin publicar: la tabla se dejo vacia mas arriba, y uno vigente
  -- cerraria la puerta a todos en lo que queda de tanda.
  insert into public.pliegos (version, titulo, texto, vigente, publicado_en)
  values (v, 'QA', jsonb_build_object('es', 'Prueba.'), false, now());
  insert into auth.users (email, raw_user_meta_data)
  values ('borra@prueba.local', '{"nombre_completo":"Borja Borrable","pais":"Peru"}')
  returning id into quien;
  insert into public.pliego_aceptaciones (persona, version) values (quien, v);
  begin
    delete from auth.users where id = quien;
    perform arnes.comprueba('qa-06: no se borra quien acepto el pliego', false, 'se borro');
  exception when others then
    perform arnes.comprueba('qa-06: no se borra quien acepto el pliego',
      exists (select 1 from public.pliego_aceptaciones where persona = quien), sqlerrm);
  end;
  perform set_config('ciip.borrado_fisico', 'si', true);
  delete from auth.users where id = quien;
  perform arnes.comprueba('qa-06: y a sabiendas, desde el editor, si',
    not exists (select 1 from auth.users where id = quien));
  delete from public.pliegos where version = v;
exception when others then
  perform arnes.comprueba('qa-06: y a sabiendas, desde el editor, si', false, sqlerrm);
end
$qa$;
select arnes.nadie();

-- El sellado de libros (c24) se presenta ante el SAREN, y la cédula (c2) y la
-- traducción (c17) se llaman como la especificación (supabase-libros-saren.sql,
-- Franklin Reyes, 7-10-2026). El ente del catálogo es el del botón del gestor.
select arnes.comprueba(
  'catalogo: el sellado de libros va ante el SAREN',
  (select ente = 'SAREN' from public.tipos_tramite where codigo = 'libros_contables'));
select arnes.comprueba(
  'catalogo: la c2 es la cedula de identidad de extranjero y la c17 la traduccion',
  (select count(*) = 2 from public.tipos_tramite
    where (codigo = 'cedula_residencia' and nombre = 'Cédula de identidad de extranjero')
       or (codigo = 'apostilla_documentos' and nombre = 'Traducción de documentos')));



-- ══ EL TIEMPO DE RESPUESTA, EN SUS DOS TRAMOS (15-10-2026) ═══════════
-- supabase-tiempos.sql: un caso con fechas puestas a mano -enviado hace
-- diez días, presentado ante el ente hace cuatro, resuelto ahora- tiene
-- que salir con 144 horas del CIIP y 96 del ente. Las fechas se escriben
-- con los disparadores apagados: la escalera de estados, con razón, no
-- deja inventar el pasado.
reset role;
select arnes.nadie();
set session_replication_role = replica;
with t as (
  insert into public.tramites (inversionista, tipo, estado, enviado_en, resuelto_en, datos)
  values ((select id from arnes.gente where papel = 'A'), 'rif_empresa', 'resuelto',
          now() - interval '10 days', now(), '{"razon_social":"Tiempos de Prueba, C.A."}')
  returning id
)
insert into arnes.escenario (clave, id) select 'tiempos', id from t;
insert into public.tramite_eventos (tramite, de_estado, a_estado, creado_en)
values ((select id from arnes.escenario where clave = 'tiempos'), 'en_revision', 'ante_el_ente',
        now() - interval '4 days');
set session_replication_role = origin;

create temp table if not exists arnes_tiempos (r jsonb);
grant all on arnes_tiempos to authenticated;
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'X'));
do $ti$
begin
  insert into arnes_tiempos select public.estadisticas_control();
  perform arnes.comprueba('tiempos: el admin ve las cifras con sus tramos', true);
exception when others then
  perform arnes.comprueba('tiempos: el admin ve las cifras con sus tramos', false, sqlerrm);
end
$ti$;
select arnes.comprueba(
  'tiempos: el caso trae 144 h del CIIP, 96 del ente y 240 en total',
  coalesce((select (c ->> 'horas_ciip')::numeric = 144 and (c ->> 'horas_ente')::numeric = 96
                   and (c ->> 'horas')::numeric = 240 and c ->> 'empresa' = 'Tiempos de Prueba, C.A.'
              from arnes_tiempos, jsonb_array_elements(r -> 'tiempos_casos') c
             where c ->> 'tramite' = (select id::text from arnes.escenario where clave = 'tiempos')), false),
  (select r -> 'tiempos_casos' -> 0 from arnes_tiempos)::text);
select arnes.comprueba(
  'tiempos: el resumen y cada organismo traen la mediana de cada tramo',
  coalesce((select (r -> 'tiempo_total') ? 'mediana_ciip_h' and (r -> 'tiempo_total') ? 'mediana_ente_h'
                   and (r -> 'tiempo_total' ->> 'resueltos')::int >= 1
                   and exists (select 1 from jsonb_array_elements(r -> 'entes') e where e ? 'promedio_ciip_h')
              from arnes_tiempos), false));
reset role;
select arnes.nadie();
set session_replication_role = replica;
delete from public.tramites where id = (select id from arnes.escenario where clave = 'tiempos');
set session_replication_role = origin;



-- ══ EL TIEMPO DE RESPUESTA, PASO A PASO (15-10-2026) ═════════════════
-- supabase-tiempos-pasos.sql: un caso con su historial entero puesto a
-- mano -enviado hace diez días, en revisión hace ocho, ante el ente hace
-- cuatro, resuelto ahora- tiene que salir con 48 h recibido, 96 en
-- revisión y 96 ante el ente, y cada paso con quien lo movió: la gestora.
reset role;
select arnes.nadie();
set session_replication_role = replica;
with t as (
  insert into public.tramites (inversionista, tipo, estado, enviado_en, resuelto_en)
  values ((select id from arnes.gente where papel = 'B'), 'registro_extranjeros_saren', 'resuelto',
          now() - interval '10 days', now() + interval '1 minute')
  returning id
)
insert into arnes.escenario (clave, id) select 'pasos', id from t;
insert into public.tramite_eventos (tramite, de_estado, a_estado, autor, creado_en)
select (select id from arnes.escenario where clave = 'pasos'), x.de, x.a, x.quien, now() - x.hace
  from (values ('borrador', 'enviado', (select id from arnes.gente where papel = 'B'), interval '10 days'),
               ('enviado', 'en_revision', (select id from arnes.gente where papel = 'G'), interval '8 days'),
               ('en_revision', 'ante_el_ente', (select id from arnes.gente where papel = 'G'), interval '4 days'),
               ('ante_el_ente', 'resuelto', (select id from arnes.gente where papel = 'G'), interval '0 days'))
       as x(de, a, quien, hace);
set session_replication_role = origin;

create temp table if not exists arnes_pasos (r jsonb);
grant all on arnes_pasos to authenticated;
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'X'));
do $pa$
begin
  insert into arnes_pasos select public.estadisticas_control();
  perform arnes.comprueba('pasos: el admin ve el paso a paso', true);
exception when others then
  perform arnes.comprueba('pasos: el admin ve el paso a paso', false, sqlerrm);
end
$pa$;
select arnes.comprueba(
  'pasos: el caso trae 48 h recibido, 96 en revisión y 96 ante el ente',
  coalesce((select string_agg(p ->> 'estado' || '=' || round((p ->> 'horas')::numeric), ' ' order by p ->> 'desde')
              from arnes_pasos, jsonb_array_elements(r -> 'tiempos_casos') c, jsonb_array_elements(c -> 'pasos') p
             where c ->> 'tramite' = (select id::text from arnes.escenario where clave = 'pasos')), '(nada)')
    = 'enviado=48 en_revision=96 ante_el_ente=96',
  coalesce((select (c -> 'pasos')::text from arnes_pasos, jsonb_array_elements(r -> 'tiempos_casos') c
             where c ->> 'tramite' = (select id::text from arnes.escenario where clave = 'pasos')), '(sin el caso)'));
select arnes.comprueba(
  'pasos: y cada paso dice quién lo movió',
  coalesce((select bool_and(p ->> 'quien' = 'Gabriela Gestora')
              from arnes_pasos, jsonb_array_elements(r -> 'tiempos_casos') c, jsonb_array_elements(c -> 'pasos') p
             where c ->> 'tramite' = (select id::text from arnes.escenario where clave = 'pasos')), false));
select arnes.comprueba(
  'pasos: y el trámite trae la mediana de cada estado',
  coalesce((select count(*) = 3 from arnes_pasos, jsonb_array_elements(r -> 'pasos_tipo') p
             where p ->> 'tipo' = 'registro_extranjeros_saren'
               and (p ->> 'mediana_h') is not null), false));
reset role;
select arnes.nadie();
set session_replication_role = replica;
delete from public.tramites where id = (select id from arnes.escenario where clave = 'pasos');
set session_replication_role = origin;



-- ══ 36 · SEGUNDA AUDITORÍA DE SEGURIDAD (8-10-2026) ════════════════════
-- supabase-seguridad-octubre.sql: las contraseñas de los entes no se leen
-- en bloque, dos papeles más que solo emite el CIIP, y anon fuera.

reset role;
select arnes.nadie();
insert into auth.users (email, raw_user_meta_data)
values ('cl@prueba.local', '{"nombre_completo":"Clara Clave","pais":"Chile"}');
insert into arnes.gente (papel, id) select 'C', id from auth.users where email = 'cl@prueba.local';
do $sg$
declare t uuid;
begin
  insert into public.tramites (inversionista, tipo, estado)
  values ((select id from arnes.gente where papel = 'C'), 'registros_parafiscales', 'borrador')
  returning id into t;
  update public.tramites set estado = 'enviado' where id = t;
  update public.tramite_entes set estado = 'codigo_enviado', codigo = 'clara1', clave = 'muy-secreta'
   where tramite = t and ente = 'ivss';
  insert into arnes.escenario values ('sg-pf', t);
end
$sg$;

select arnes.comprueba('seguridad: sin entrar no se piden contraseñas ni se usan las funciones del equipo',
  not has_function_privilege('anon', 'public.clave_del_ente(uuid,text)', 'execute')
  and not has_function_privilege('anon', 'public.confirma_cita(uuid,timestamptz,text,text)', 'execute')
  and not has_function_privilege('anon', 'public.abre_consulta_para(uuid,text,text)', 'execute'));

-- El equipo: la columna no, el «hay contraseña» sí, y la función la da y apunta.
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));
do $sg$
declare t uuid := (select id from arnes.escenario where clave = 'sg-pf'); c text; n0 bigint;
begin
  begin
    perform clave from public.tramite_entes where tramite = t;
    perform arnes.comprueba('seguridad: el equipo no lee las contraseñas en bloque', false, 'las leyó');
  exception when others then
    perform arnes.comprueba('seguridad: el equipo no lee las contraseñas en bloque', true, sqlerrm);
  end;
  perform arnes.comprueba('seguridad: pero sabe cuáles tienen contraseña',
    (select tiene_clave from public.tramite_entes where tramite = t and ente = 'ivss'));
  reset role;
  n0 := (select coalesce(max(id), 0) from public.bitacora);
  set role authenticated;
  c := public.clave_del_ente(t, 'ivss');
  perform arnes.comprueba('seguridad: el equipo pide una contraseña y la ve', c = 'muy-secreta', coalesce(c, 'null'));
  reset role;
  perform arnes.comprueba('seguridad: y queda apuntado quién la vio',
    exists (select 1 from public.bitacora where id > n0 and fuente = 'entes' and accion = 'vio_clave'
             and quien = (select id from arnes.gente where papel = 'G') and detalle = 'ivss'
             and sobre = 'Clara Clave'),
    (select string_agg(fuente || '/' || accion, ' ') from public.bitacora where id > n0));
  set role authenticated;
exception when others then
  perform arnes.comprueba('seguridad: el equipo pide una contraseña y la ve', false, sqlerrm);
end
$sg$;

-- El inversionista: la escribe y la corrige, pero no la lee ni la pide.
select arnes.soy((select id from arnes.gente where papel = 'C'));
do $sg$
declare t uuid := (select id from arnes.escenario where clave = 'sg-pf'); ok boolean;
begin
  update public.tramite_entes set clave = 'otra-secreta'
   where tramite = t and ente = 'ivss' returning tiene_clave into ok;
  perform arnes.comprueba('seguridad: el inversionista sigue corrigiendo su contraseña', coalesce(ok, false));
  begin
    perform clave from public.tramite_entes where tramite = t;
    perform arnes.comprueba('seguridad: el inversionista no la lee de vuelta', false, 'la leyó');
  exception when others then
    perform arnes.comprueba('seguridad: el inversionista no la lee de vuelta', true, sqlerrm);
  end;
  begin
    perform public.clave_del_ente(t, 'ivss');
    perform arnes.comprueba('seguridad: ni la pide por la función', false, 'la dio');
  exception when others then
    perform arnes.comprueba('seguridad: ni la pide por la función', true, sqlerrm);
  end;
exception when others then
  perform arnes.comprueba('seguridad: el inversionista sigue corrigiendo su contraseña', false, sqlerrm);
end
$sg$;

-- Y no fabrica la planilla de los RIF ni la constancia de un ente.
do $sg$
declare tipo_ciip text;
begin
  foreach tipo_ciip in array array['planilla_solicitud', 'constancia_ente'] loop
    begin
      insert into public.documentos (inversionista, tipo, archivo, nombre_original, estado)
      values (auth.uid(), tipo_ciip, auth.uid() || '/falsa-' || tipo_ciip || '.pdf', 'falsa.pdf', 'cargado');
      perform arnes.comprueba('seguridad: el inversionista no sube un ' || tipo_ciip, false, 'entró');
    exception when others then
      perform arnes.comprueba('seguridad: el inversionista no sube un ' || tipo_ciip, true, sqlerrm);
    end;
  end loop;
end
$sg$;
reset role;
select arnes.nadie();



-- ───────────────────────────────────────────────────────────────────────
-- LA AUTORIZACIÓN AL CIIP (supabase-autorizaciones.sql, 8-10-2026)
-- ───────────────────────────────────────────────────────────────────────
reset role;
select arnes.nadie();
with t as (
  insert into public.tramites (inversionista, tipo, estado)
  values ((select id from arnes.gente where papel = 'A'), 'rif_empresa', 'borrador')
  returning id)
insert into arnes.escenario (clave, id) select 'au_tramite_a', id from t;
-- Otro inversionista propio: B se borra al principio de la tanda.
with u as (
  insert into auth.users (email, raw_user_meta_data)
  values ('au-otro@prueba.local', '{"nombre_completo":"Otro Inversionista","pais":"Chile"}')
  returning id)
insert into arnes.escenario (clave, id) select 'au_otro', id from u;
with t as (
  insert into public.tramites (inversionista, tipo, estado)
  values ((select id from arnes.escenario where clave = 'au_otro'), 'rif_empresa', 'borrador')
  returning id)
insert into arnes.escenario (clave, id) select 'au_tramite_b', id from t;

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

insert into public.autorizaciones (tramite, tipo, texto)
values ((select id from arnes.escenario where clave = 'au_tramite_a'), 'rif_empresa', 'Yo, A, autorizo al CIIP.');

select arnes.comprueba(
  'autorizacion: la constancia lleva su codigo AUT-AAAA-NNNNNN, puesto por la base',
  (select codigo ~ '^AUT-\d{4}-\d{6}$' from public.autorizaciones
    where tramite = (select id from arnes.escenario where clave = 'au_tramite_a')),
  coalesce((select codigo from public.autorizaciones
    where tramite = (select id from arnes.escenario where clave = 'au_tramite_a')), 'sin fila'));

do $au$
begin
  insert into public.autorizaciones (tramite, tipo, texto)
  values ((select id from arnes.escenario where clave = 'au_tramite_b'), 'rif_empresa', 'Me cuelo en el de B.');
  perform arnes.comprueba('autorizacion: no se autoriza en un tramite ajeno', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('autorizacion: no se autoriza en un tramite ajeno', true, sqlerrm);
end
$au$;

do $au$
begin
  update public.autorizaciones set texto = 'Otro texto'
   where tramite = (select id from arnes.escenario where clave = 'au_tramite_a');
  perform arnes.comprueba('autorizacion: el texto aceptado no se cambia',
    (select texto = 'Yo, A, autorizo al CIIP.' from public.autorizaciones
      where tramite = (select id from arnes.escenario where clave = 'au_tramite_a')), 'sin error, ¿cambio?');
exception when others then
  perform arnes.comprueba('autorizacion: el texto aceptado no se cambia', true, sqlerrm);
end
$au$;

select arnes.comprueba(
  'autorizacion: se revoca una vez y devuelve la fecha',
  public.revoca_autorizacion((select id from public.autorizaciones
    where tramite = (select id from arnes.escenario where clave = 'au_tramite_a'))) is not null, '');
select arnes.comprueba(
  'autorizacion: y la segunda vez no hay nada que revocar',
  public.revoca_autorizacion((select id from public.autorizaciones
    where tramite = (select id from arnes.escenario where clave = 'au_tramite_a'))) is null, '');

select arnes.soy((select id from arnes.escenario where clave = 'au_otro'));
select arnes.comprueba(
  'autorizacion: otro inversionista no ve las ajenas',
  (select count(*) = 0 from public.autorizaciones), (select count(*)::text from public.autorizaciones));

select arnes.soy((select id from arnes.gente where papel = 'G'));
select arnes.comprueba(
  'autorizacion: el equipo si las ve',
  (select count(*) >= 1 from public.autorizaciones), (select count(*)::text from public.autorizaciones));

reset role;
select arnes.nadie();

-- ───────────────────────────────────────────────────────────────────────
-- EL CHAT DE LA CONTESTACIÓN (supabase-chat-del-paso.sql, 9-10-2026)
-- ───────────────────────────────────────────────────────────────────────
-- Una marca de A ante el SAPI, con la planilla FM-02 pagada: el gestor
-- puede habilitar la contestación.
with t as (
  insert into public.tramites (inversionista, tipo, estado, datos)
  values ((select id from arnes.gente where papel = 'A'), 'marca', 'ante_el_ente',
          '{"pasos_ciip": {"pago_fm02": "2026-10-09T10:00:00-04"}}'::jsonb)
  returning id)
insert into arnes.escenario (clave, id) select 'chat_marca', id from t;

set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'A'));

do $ch$
begin
  insert into public.tramite_mensajes (tramite, texto, paso)
  values ((select id from arnes.escenario where clave = 'chat_marca'), 'Me adelanto', 'contestacion');
  perform arnes.comprueba('chat del paso: cerrado hasta que el gestor habilita la contestación', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('chat del paso: cerrado hasta que el gestor habilita la contestación', true, sqlerrm);
end
$ch$;

select arnes.soy((select id from arnes.gente where papel = 'G'));
select public.habilita_contestacion((select id from arnes.escenario where clave = 'chat_marca'),
  'El SAPI devolvió el registro: falta aclarar la clase.') is not null;

select arnes.comprueba(
  'contestación: habilitarla deja la marca en «Solicitud en proceso» hasta que se resuelva',
  (select not ((datos -> 'pasos_ciip') ? 'sapi') and (datos -> 'pasos_ciip') ? 'contestacion'
     from public.tramites where id = (select id from arnes.escenario where clave = 'chat_marca')));

select arnes.comprueba(
  'contestación: resuelta la devolución, el gestor cierra «Solicitud en proceso»',
  (select (datos -> 'pasos_ciip') ? 'sapi'
     from public.marca_paso_ciip((select id from arnes.escenario where clave = 'chat_marca'), 'sapi')));

select arnes.comprueba(
  'chat del paso: el anuncio del gestor es su primer mensaje, del equipo',
  (select count(*) = 1 from public.tramite_mensajes
    where tramite = (select id from arnes.escenario where clave = 'chat_marca')
      and paso = 'contestacion' and del_equipo));

select arnes.soy((select id from arnes.gente where papel = 'A'));
insert into public.tramite_mensajes (tramite, texto, paso)
values ((select id from arnes.escenario where clave = 'chat_marca'), '¿Qué clase pongo?', 'contestacion');

select arnes.comprueba(
  'chat del paso: habilitada, el inversionista escribe en él',
  (select count(*) = 1 from public.tramite_mensajes
    where tramite = (select id from arnes.escenario where clave = 'chat_marca')
      and paso = 'contestacion' and not del_equipo));

do $ch$
begin
  insert into public.tramite_mensajes (tramite, texto, paso)
  values ((select id from arnes.escenario where clave = 'chat_marca'), 'Otro chat', 'inventado');
  perform arnes.comprueba('chat del paso: no hay chats inventados', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('chat del paso: no hay chats inventados', true, sqlerrm);
end
$ch$;

do $ch$
begin
  insert into public.tramite_mensajes (tramite, texto, paso)
  values ((select id from arnes.escenario where clave = 'au_tramite_a'), 'En un RIF', 'contestacion');
  perform arnes.comprueba('chat del paso: solo en la marca', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('chat del paso: solo en la marca', true, sqlerrm);
end
$ch$;

-- En registro, se cierra: lo dicho se lee, pero no se escribe más.
reset role;
select arnes.nadie();
update public.tramites
   set datos = jsonb_set(datos, '{pasos_ciip,en_registro}', '"2026-10-10T10:00:00-04"')
 where id = (select id from arnes.escenario where clave = 'chat_marca');
set role authenticated;
select arnes.soy((select id from arnes.gente where papel = 'G'));

do $ch$
begin
  insert into public.tramite_mensajes (tramite, texto, paso)
  values ((select id from arnes.escenario where clave = 'chat_marca'), 'Tarde', 'contestacion');
  perform arnes.comprueba('chat del paso: en registro se cierra, también para el equipo', false, 'ENTRO');
exception when others then
  perform arnes.comprueba('chat del paso: en registro se cierra, también para el equipo', true, sqlerrm);
end
$ch$;

select arnes.soy((select id from arnes.gente where papel = 'A'));
select arnes.comprueba(
  'chat del paso: y lo dicho se sigue leyendo',
  (select count(*) = 2 from public.tramite_mensajes
    where tramite = (select id from arnes.escenario where clave = 'chat_marca')
      and paso = 'contestacion'));

reset role;
select arnes.nadie();

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
