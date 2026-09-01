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
  select id into quien from arnes.gente where papel = 'A';
  select codigo into tipoDoc from public.tipos_documento limit 1;
  hex := repeat('ab', 32);   -- 64 hexadecimales

  insert into public.documentos (inversionista, tipo, archivo, nombre_original,
                                 estado, huella)
  values (quien, tipoDoc, quien || '/con-huella.pdf', 'con-huella.pdf',
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
  select codigo into tipoAct from public.tipos_tramite where activo limit 1 offset 4;

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
  select codigo into tipoAct from public.tipos_tramite where activo limit 1 offset 6;
  select id into cual from arnes.escenario where clave = 'viva';

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
