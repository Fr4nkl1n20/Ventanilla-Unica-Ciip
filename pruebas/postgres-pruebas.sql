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
  values (quien, (select codigo from public.tipos_tramite where activo limit 1), 'borrador')
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
  select codigo into sinTasa from public.tipos_tramite where activo limit 1;
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
