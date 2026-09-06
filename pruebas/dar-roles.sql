-- ══════════════════════════════════════════════════════════════════════
--  DAR ROL A DOS CUENTAS
-- ══════════════════════════════════════════════════════════════════════
--  LAS CUENTAS NO SE CREAN DESDE AQUI. Este archivo reparte ROLES; crear
--  el usuario es otra cosa y no debe hacerse a mano con SQL.
--
--  POR QUE NO: una fila de auth.users no es solo una fila. Supabase le
--  pone al lado una fila en auth.identities, la clave cifrada con su
--  algoritmo, el confirmed_at, el instance_id y media docena de campos
--  mas. Un INSERT escrito a mano crea una cuenta que EXISTE y con la que
--  NO SE PUEDE ENTRAR, y el fallo no aparece hasta que alguien lo
--  intenta. Peor: puede quedar a medias y no dejarse borrar desde el
--  panel de Supabase.
--
--  ASI QUE PRIMERO, EN EL PANEL DE SUPABASE:
--    Authentication → Users → Add user → Create new user
--    · Email          el que toque (ver abajo)
--    · Password       una que se cambiara al entrar
--    · Auto Confirm User: SI, o la cuenta nace sin confirmar y no entra
--
--  Al crearla salta el disparador al_crear_usuario, que le pone su fila
--  en public.perfiles con rol 'inversionista'. Por eso la cuenta de
--  inversionista NO necesita nada mas: nace con el rol que se quiere.
--  Solo hay que tocar la del admin.
--
--  Y DESPUES, ESTE ARCHIVO. Se puede correr las veces que haga falta.
-- ══════════════════════════════════════════════════════════════════════


-- ── 1. ¿EXISTEN LAS DOS CUENTAS, Y QUE ROL TIENEN AHORA? ───────────────
-- Correr esto ANTES. Si una sale sin fila, es que no se ha creado todavia
-- y lo de abajo no hara nada: un update sin filas no da error, solo dice
-- «UPDATE 0», que es facil de leer como si hubiera funcionado.

select u.email,
       u.id,
       u.email_confirmed_at is not null as confirmada,
       p.rol,
       p.nombre_completo
  from auth.users u
  left join public.perfiles p on p.id = u.id
 where lower(u.email) in (
         lower('ventanillaAdmin@gmail.com'),
         lower('Investionista@gmail.com')
       )
 order by u.email;


-- ── 2. EL ADMIN ────────────────────────────────────────────────────────
-- lower() en los dos lados: el correo se guarda tal como se escribio al
-- crear la cuenta, y 'ventanillaAdmin@' con la A grande no es la misma
-- cadena que 'ventanilladmin@'. Comparar en minusculas evita un UPDATE 0
-- que parece exito.

update public.perfiles p
   set rol = 'admin'
  from auth.users u
 where u.id = p.id
   and lower(u.email) = lower('ventanillaAdmin@gmail.com');


-- ── 3. EL INVERSIONISTA ────────────────────────────────────────────────
-- No hace falta si la cuenta se acaba de crear: el disparador ya la dejo
-- en 'inversionista'. Se deja escrito por si esa cuenta ya existia con
-- otro rol y hay que devolverla a su sitio.
--
-- OJO CON EL CORREO: dice «Investionista», sin la R de «Inversionista».
-- Puede ser a proposito o puede ser un dedazo. Si es un dedazo y la
-- cuenta se crea asi, el rol se le dara a una direccion que nadie usa y
-- la persona no podra entrar. Comprobarlo ANTES de crear la cuenta.

update public.perfiles p
   set rol = 'inversionista'
  from auth.users u
 where u.id = p.id
   and lower(u.email) = lower('Investionista@gmail.com');


-- ── 4. COMPROBAR QUE QUEDO HECHO ───────────────────────────────────────
-- Tiene que devolver DOS filas, una con 'admin' y otra con
-- 'inversionista'. Si devuelve una sola, falta crear la otra cuenta.

select u.email, p.rol, p.actualizado_en
  from public.perfiles p
  join auth.users u on u.id = p.id
 where lower(u.email) in (
         lower('ventanillaAdmin@gmail.com'),
         lower('Investionista@gmail.com')
       )
 order by p.rol;


-- ══════════════════════════════════════════════════════════════════════
--  EN QUE PROYECTO SE CORRE ESTO
-- ══════════════════════════════════════════════════════════════════════
--  · pruebas  (ifhdzxetixhrzqixcfbe) — el que usa el panel desde
--    localhost. Aqui no hay nada que romper.
--  · real     (fbxdwryppfctuwlnjjqr) — cuentas de verdad. Un 'admin' aqui
--    ve y cambia el expediente de TODO el mundo, reparte roles a otros y
--    entra al catalogo y a la bitacora.
--
--  Si esto es para probar, va en pruebas. Si es para el CIIP de verdad,
--  que lo sepa quien manda antes de correrlo: dar admin no se deshace
--  solo, y mientras tanto esa cuenta lo ve todo.
--
--  PARA QUITARLE EL ADMIN A ALGUIEN:
--    update public.perfiles p set rol = 'gestor'
--      from auth.users u
--     where u.id = p.id and lower(u.email) = lower('correo@ejemplo.com');
--
--  Los tres roles que admite la tabla, y nada mas -hay un check-:
--    inversionista  el usuario final
--    gestor         equipo del CIIP: atiende expedientes y citas
--    admin          total: ademas reparte roles y toca el catalogo
-- ══════════════════════════════════════════════════════════════════════
