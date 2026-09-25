-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · Ventanilla Única del Inversionista
--  Cambio: se retiró "Crear cuenta" del acceso
-- ═══════════════════════════════════════════════════════════════════════
--
--  CÓMO SUBIRLO:
--    Panel de Supabase → SQL Editor → New query → pega esto → Run
--
--  Es idempotente: puedes ejecutarlo varias veces sin romper nada.
--
--  QUÉ CUBRE: solo lo que hace falta ahora que las cuentas las abre el
--  CIIP y no el propio inversionista. El esquema base sigue siendo
--  supabase-setup.sql y NO hay que volver a ejecutarlo.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
--  ⚠  PASO 0 — ESTO NO ES SQL, Y ES LO MÁS IMPORTANTE
-- ───────────────────────────────────────────────────────────────────────
--  Quitar el formulario del navegador NO cierra el registro. La puerta
--  sigue abierta en el servidor: cualquiera puede llamar directamente a
--
--      POST https://<tu-proyecto>.supabase.co/auth/v1/signup
--
--  usando la clave "anon", que es pública y está a la vista en config.js.
--  Se comprobó el 2026-08-16 y el registro seguía habilitado.
--
--  PARA CERRARLO DE VERDAD:
--      Authentication → Sign In / Providers → Email
--      → apaga  "Allow new users to sign up"   (Enable sign ups)
--      → Save
--
--  Compruébalo después con:
--      curl "https://<tu-proyecto>.supabase.co/auth/v1/settings?apikey=<anon>"
--  Debe decir  "disable_signup": true
--
--  Mientras diga false, el acceso está abierto aunque no se vea el botón.
-- ───────────────────────────────────────────────────────────────────────


-- ───────────────────────────────────────────────────────────────────────
--  1. DAR DE ALTA A UN INVERSIONISTA
-- ───────────────────────────────────────────────────────────────────────
--  El usuario se crea en:  Authentication → Users → Add user
--
--  Ahí conviene rellenar "Auto Confirm User" y, en Raw user meta data,
--  pegar esto para que el trigger cree el perfil completo de una vez:
--
--      { "nombre_completo": "Marco Bianchi", "pais": "Italia" }
--
--  Si se te olvidó ponerlo —o el usuario ya existía— el perfil queda con
--  el nombre y el país en blanco. Esta consulta lo arregla.
--
--  Cambia los tres valores y ejecútala:

update public.perfiles p
   set nombre_completo = 'Marco Bianchi',
       pais            = 'Italia'
  from auth.users u
 where u.id = p.id
   and u.email = 'correo@ejemplo.com';   -- ← el correo del inversionista


-- ───────────────────────────────────────────────────────────────────────
--  2. VARIOS DE UNA VEZ
-- ───────────────────────────────────────────────────────────────────────
--  Misma idea para una tanda. Añade o quita filas de la lista.
--  Los correos que no existan en auth.users se ignoran sin dar error.

update public.perfiles p
   set nombre_completo = d.nombre,
       pais            = d.pais
  from auth.users u,
       (values
          ('correo1@ejemplo.com', 'Marco Bianchi',  'Italia'),
          ('correo2@ejemplo.com', 'Ana Pérez',      'Colombia')
       ) as d(correo, nombre, pais)
 where u.id = p.id
   and lower(u.email) = lower(d.correo);


-- ───────────────────────────────────────────────────────────────────────
--  3. RED DE SEGURIDAD
-- ───────────────────────────────────────────────────────────────────────
--  Crea el perfil de cualquier usuario que no lo tenga. Pasa cuando se
--  crea un usuario antes de que exista el trigger, o si el trigger falla.
--  Inofensivo si no hay ninguno.

insert into public.perfiles (id, nombre_completo, pais)
select u.id,
       coalesce(u.raw_user_meta_data ->> 'nombre_completo', ''),
       coalesce(u.raw_user_meta_data ->> 'pais', '')
  from auth.users u
  left join public.perfiles p on p.id = u.id
 where p.id is null;


-- ───────────────────────────────────────────────────────────────────────
--  4. COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--  Quién hay dado de alta y a quién le falta rellenar los datos.

select u.email,
       p.nombre_completo,
       p.pais,
       p.rol,
       case when u.email_confirmed_at is null then 'sin confirmar' else 'confirmado' end as correo,
       case when p.nombre_completo = '' or p.pais = '' then '⚠ faltan datos' else 'completo' end as perfil
  from auth.users u
  left join public.perfiles p on p.id = u.id
 order by u.created_at desc;


-- ═══════════════════════════════════════════════════════════════════════
--  LO QUE NO HACE FALTA TOCAR
-- ═══════════════════════════════════════════════════════════════════════
--  · El trigger al_crear_usuario sigue sirviendo: salta con cualquier alta
--    en auth.users, venga del formulario o del panel de Supabase.
--  · Las políticas RLS no cambian: cada quien sigue viendo solo su fila.
--  · Recuperar clave y clave nueva siguen funcionando igual; esas dos
--    vistas se conservaron en acceso.html.
-- ═══════════════════════════════════════════════════════════════════════
