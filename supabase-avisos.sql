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
