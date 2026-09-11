-- ═══════════════════════════════════════════════════════════════════════
--  PARA LA BASE REAL · lo que le falta a fecha de 2026-09-11
-- ═══════════════════════════════════════════════════════════════════════
--  QUE HAY QUE HACER
--  ─────────────────────────────────────────────────────────────────────
--  Panel de Supabase → SQL Editor → New query → pegar esto entero → Run.
--  Una sola vez. Tarda unos segundos.
--
--  EN QUE PROYECTO
--  ─────────────────────────────────────────────────────────────────────
--  En el REAL, el que sirve la pagina publicada. NO en el de pruebas.
--
--  Si no estas seguro de cual es, abre la pagina publicada, pulsa F12 y
--  mira la consola: el panel escribe al arrancar una linea que dice
--  «CIIP · base de datos: real → https://XXXX.supabase.co». Esa es.
--
--  QUE LE FALTA HOY
--  ─────────────────────────────────────────────────────────────────────
--  1. EL HORARIO DE CITAS: el archivo 28, supabase-disponibilidad.sql.
--     Nuevo el 2026-09-11. El CIIP publica su horario semanal y quien pide
--     cita elige un hueco libre; la cita nace confirmada. Crea dos tablas
--     (horario_citas, cierres_citas), una columna en citas (hueco) y dos
--     funciones (huecos_ocupados, reserva_cita).
--
--     Sin correrlo la pagina NO se rompe: la ventana de la cita sigue
--     pidiendo una ventana de dias, como hasta ahora, y la pantalla
--     «Horario de citas» del equipo avisa de que falta este SQL.
--
--  2. El archivo 26 entero, supabase-informe-victor.sql, que ya iba en la
--     tanda del 2026-09-03 (el registro de la inversion pasa de la fase 5
--     a la 4). Si aquella ya se corrio, volver a pasarlo no cambia nada.
--
--  SI TIENES CUALQUIER DUDA, PEGA TODO-EN-ORDEN.sql EN VEZ DE ESTE
--  ─────────────────────────────────────────────────────────────────────
--  Aquel trae los veintiocho y siempre es correcto, aunque este archivo se
--  haya quedado viejo. Todos son idempotentes -create if not exists,
--  create or replace, drop policy if exists-, asi que volver a pasar lo que
--  ya estaba no rompe nada. Este archivo solo existe para no hacerte pegar
--  280 KB en el editor.
--
--  QUE VA A CAMBIAR EN LA PANTALLA
--  ─────────────────────────────────────────────────────────────────────
--  Nada hasta que el equipo escriba su horario en «Horario de citas» (menu
--  lateral, grupo Asistencia; solo lo ve el equipo). Desde ese momento,
--  quien pida cita elige entre los huecos libres de las proximas tres
--  semanas, en hora de Venezuela, y su cita sale en «Proximas citas».
--
--  NO BORRA NI APAGA NADA. Las citas que ya existen se quedan como estan.
--
--  COMO SABER QUE SALIO BIEN
--  ─────────────────────────────────────────────────────────────────────
--  Estas dos tienen que funcionar y devolver CERO FILAS: nacen vacias.
--
--    select * from public.horario_citas;
--    select * from public.cierres_citas;
--
--  Esta tiene que devolver una fila, 'hueco':
--
--    select column_name from information_schema.columns
--     where table_schema = 'public' and table_name = 'citas'
--       and column_name = 'hueco';
--
--  Y lo del archivo 26, como antes: cero filas en
--
--    select ref_panel, nombre from public.tipos_tramite where fase = 5;
-- ═══════════════════════════════════════════════════════════════════════


-- ====================================================================
--  28 / 28   supabase-disponibilidad.sql
--  el horario de citas, que publica el CIIP
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

  constraint horario_dia_valido   check (dia between 1 and 7),
  constraint horario_tramo_valido check (hasta > desde),
  constraint horario_cada_valido  check (cada_min between 10 and 240)
);

comment on table  public.horario_citas          is 'Cuándo atiende el CIIP, semana a semana. Lo edita el equipo desde el panel';
comment on column public.horario_citas.dia      is '1 lunes ... 7 domingo (isodow)';
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

  constraint cierre_motivo_cabe check (length(motivo) <= 200)
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


-- ====================================================================
--  26 / 28   supabase-informe-victor.sql
--  el catalogo del informe, con las cuatro fases
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

