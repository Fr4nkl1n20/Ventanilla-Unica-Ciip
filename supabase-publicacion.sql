-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA PUBLICACIÓN NACE SOLA (c22 → c23)
--  Va DESPUÉS de supabase-protocolizacion.sql: repite su patrón un piso
--  más abajo y usa sus mismas tablas.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 20 de septiembre de 2026: la publicación del acta tiene
--  que llevar lo mismo que la protocolización y trabajarse igual. Y lo
--  mismo es esto: el primer paso del tramo es la emisión del PUB, el CIIP
--  lo deja en la solicitud, el inversionista paga con él y sube el
--  comprobante en el paso siguiente.
--
--  Para que el equipo tenga DÓNDE dejarlo hace falta una solicitud abierta,
--  y la publicación no nacía sola: la protocolización sí —la abre la
--  constitución—, pero ahí se acababa la cadena. Sin esto, el paso del PUB
--  saldría con su rótulo y sin nada dentro, y el inversionista esperaría un
--  papel que el CIIP no puede mandarle.
--
--  Así que son tres cosas, las mismas de un piso más arriba:
--
--   1. Resuelta la protocolización, la publicación del acta se crea sola,
--      ya enviada, con lo que aquélla decía.
--   2. El equipo deja en ella el PUB de la publicación mercantil.
--   3. Sin el comprobante de ese pago, la publicación no se resuelve.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: la publicación se sigue pidiendo a
--  mano, su paso del PUB sale vacío —no hay tipo de documento que colgar—
--  y la casilla del equipo falla al enganchar el papel.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1. LOS DOS PAPELES DEL PAGO
-- ───────────────────────────────────────────────────────────────────────
--  Ninguno caduca: el PUB es la orden de pago de un expediente concreto y
--  el comprobante acredita un pago de una fecha concreta. Los de la
--  protocolización —'planilla_aranceles' y 'pago_aranceles'— no se tocan:
--  son de otro trámite y de otro arancel.
insert into public.tipos_documento (codigo, nombre, vence) values
  ('planilla_publicacion', 'PUB para pagar la publicación mercantil', false),
  ('pago_publicacion',     'Comprobante del pago de la publicación',  false)
on conflict (codigo) do update set nombre = excluded.nombre, vence = excluded.vence;


-- ───────────────────────────────────────────────────────────────────────
-- 2. EL EQUIPO DEJA EL PUB
-- ───────────────────────────────────────────────────────────────────────
--  Las dos políticas gemelas de las de la protocolización. Entra
--  'validado', que es lo que impide al inversionista borrarlo sin querer,
--  y el archivo va a la carpeta 'emitidos', que el cubo ya le deja al
--  equipo.
drop policy if exists "documentos: el equipo sube el PUB de la publicacion" on public.documentos;
create policy "documentos: el equipo sube el PUB de la publicacion" on public.documentos
  for insert
  with check (public.es_gestor() and tipo = 'planilla_publicacion' and estado = 'validado');

--  Y engancharlo: solo a una publicación, y solo mientras está en marcha,
--  que es cuando el paso del pago se ofrece. El papel tiene que ser de la
--  bóveda del mismo inversionista del trámite, para no colgarle a alguien
--  el de otro.
drop policy if exists "adjuntos: el equipo engancha el PUB de la publicacion" on public.tramite_documentos;
create policy "adjuntos: el equipo engancha el PUB de la publicacion" on public.tramite_documentos
  for insert
  with check (
    public.es_gestor()
    and exists (
      select 1
        from public.tramites t, public.documentos d
       where t.id = tramite_documentos.tramite
         and d.id = tramite_documentos.documento
         and d.inversionista = t.inversionista
         and d.tipo = 'planilla_publicacion'
         and t.tipo = 'publicacion_acta'
         and t.estado in ('enviado','en_revision','ante_el_ente')
    )
  );


-- ───────────────────────────────────────────────────────────────────────
-- 3. RESUELTA LA PROTOCOLIZACIÓN, NACE LA PUBLICACIÓN
-- ───────────────────────────────────────────────────────────────────────
--  Todo lo que dice constitucion_abre_la_protocolizacion() vale aquí
--  igual: AFTER UPDATE, security definer para insertar por encima del RLS,
--  y en la base y no en el panel, para que nazca lo resuelva quien lo
--  resuelva y desde donde lo resuelva.
--
--  QUÉ SE COPIA, Y QUÉ NO. La publicación pregunta cuatro cosas y la
--  protocolización solo sabe una de verdad:
--    · razón social          ← la misma
--    · número de registro    ← NO: lo asigna el registro al inscribir, y
--                              la protocolización no lo guarda.
--    · fecha de protocolización ← NO: la fecha en que el equipo marcó el
--                              trámite resuelto no es la nota del
--                              registrador, y ponerla sería inventar un
--                              dato que luego nadie corrige.
--    · periódico             ← NO: lo elige el inversionista.
--  Las tres que faltan las rellena quien las tenga delante, igual que la
--  protocolización deja en blanco la fecha de firma del acta.
--
--  Y si ya hay una publicación de esa persona no se crea otra, ni aunque
--  esté resuelta.
create or replace function public.protocolizacion_abre_la_publicacion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  copia jsonb := '{}'::jsonb;
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'protocolizacion_acta' then
    return new;
  end if;

  --  Sin el trámite en el catálogo —o apagado— no hay nada que crear: la
  --  llave foránea lo rechazaría y se llevaría por delante el «resuelto»
  --  que el gestor acaba de dar.
  if not exists (
    select 1 from public.tipos_tramite
     where codigo = 'publicacion_acta' and coalesce(activo, true)
  ) then
    return new;
  end if;

  if exists (
    select 1 from public.tramites
     where inversionista = new.inversionista
       and tipo = 'publicacion_acta'
  ) then
    return new;
  end if;

  --  LO QUE EL TRAMO NUEVO HEREDA
  --  ─────────────────────────────────────────────────────────────────
  --  La razón social desde el principio. El número de registro y la fecha
  --  de protocolización desde el 21 de septiembre de 2026, a petición de
  --  Franklin Reyes: «esa información debería llenarse con la primera
  --  fase». De la constitución no puede salir —el registro los ASIGNA al
  --  protocolizar, así que cuando se constituye no existen todavía—, pero
  --  de la protocolización sí: el gestor los copia del acta en el momento
  --  de subirla, que es el único momento en que alguien los tiene delante.
  --
  --  Los tres nombres son los del formulario de la publicación. Si allí se
  --  renombra un campo, hay que renombrarlo aquí o la herencia se corta sin
  --  hacer ruido: lo que se hereda es un nombre, no una columna.
  --
  --  Lo que no esté, no se copia: una clave en blanco taparía el relleno
  --  del panel, que busca en los otros trámites lo que se escribió antes.
  if coalesce(new.datos->>'razon_social', '') <> '' then
    copia := copia || jsonb_build_object('razon_social', new.datos->>'razon_social');
  end if;

  if coalesce(new.datos->>'numero_registro', '') <> '' then
    copia := copia || jsonb_build_object('numero_registro', new.datos->>'numero_registro');
  end if;

  if coalesce(new.datos->>'fecha_protocolizacion', '') <> '' then
    copia := copia || jsonb_build_object('fecha_protocolizacion',
                                         new.datos->>'fecha_protocolizacion');
  end if;

  --  Y nace en manos de quien resolvió la protocolización, por lo mismo
  --  que allí: un trámite sin dueño solo ofrece «Tómalo» en la cola, y la
  --  casilla donde el equipo deja el PUB vive un paso más adentro. El
  --  gestor esperaría a que apareciera y el inversionista, a un papel que
  --  nadie le manda. Desde el SQL Editor no hay gestor que copiar: queda
  --  null, sin asignar.
  insert into public.tramites (inversionista, tipo, estado, datos, enviado_en, gestor)
  values (new.inversionista, 'publicacion_acta', 'enviado', copia, now(), new.gestor);

  return new;
end;
$$;

drop trigger if exists tramites_abre_publicacion on public.tramites;
create trigger tramites_abre_publicacion
  after update on public.tramites
  for each row execute function public.protocolizacion_abre_la_publicacion();


--  LAS QUE YA NACIERON SIN DUEÑO
--  ─────────────────────────────────────────────────────────────────────
--  Igual que un piso más arriba: a las publicaciones que ya existen y no
--  tienen gestor se les pone el de SU protocolización, que es de quien lo
--  habrían heredado. Solo a las que no tienen ninguno: si alguien ya la
--  tomó a mano, esa decisión manda. Correrlo dos veces no hace nada la
--  segunda.
update public.tramites c23
   set gestor = c22.gestor
  from public.tramites c22
 where c23.tipo   = 'publicacion_acta'
   and c23.gestor is null
   and c22.inversionista = c23.inversionista
   and c22.tipo   = 'protocolizacion_acta'
   and c22.gestor is not null;


--  Y LAS QUE NO LLEGARON A NACER
--  ──────────────────────────────────
--  Quien tuvo su protocolización resuelta ANTES de que existiera el
--  disparador se queda sin publicación y sin forma de conseguirla: en su
--  paso del PUB el panel dice que el CIIP se lo enviará, y el CIIP no
--  puede dejárselo porque no hay solicitud donde colgarlo. Los dos
--  esperando al otro, para siempre.
--
--  Correrlo dos veces no hace nada la segunda: el `not exists` ya no
--  encuentra a nadie.
insert into public.tramites (inversionista, tipo, estado, datos, enviado_en, gestor)
select c22.inversionista, 'publicacion_acta', 'enviado',
       jsonb_strip_nulls(jsonb_build_object(
         'razon_social', nullif(c22.datos->>'razon_social', '')
       )),
       now(), c22.gestor
  from public.tramites c22
 where c22.tipo   = 'protocolizacion_acta'
   and c22.estado = 'resuelto'
   and exists (select 1 from public.tipos_tramite
                where codigo = 'publicacion_acta' and activo)
   and not exists (
     select 1 from public.tramites otra
      where otra.inversionista = c22.inversionista
        and otra.tipo = 'publicacion_acta');


-- ───────────────────────────────────────────────────────────────────────
-- 4. SIN EL COMPROBANTE DEL PAGO, NO HAY «RESUELTA»
-- ───────────────────────────────────────────────────────────────────────
--  La misma regla de la protocolización: el periódico no publica nada sin
--  cobrar, así que una publicación resuelta sin ese papel estaría
--  mintiendo.
--
--  Los BEFORE UPDATE corren por orden alfabético, y 'tramites_proteger' va
--  antes que 'tramites_publicacion_pago': un salto que la escalera no deja
--  no llega aquí. Desde el SQL Editor (auth.uid() nulo) no estorba, para
--  poder enderezar a mano un expediente atascado.
create or replace function public.tramites_publicacion_con_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'publicacion_acta' then
    return new;
  end if;
  if auth.uid() is null then
    return new;
  end if;

  if not exists (
    select 1
      from public.tramite_documentos td
      join public.documentos d on d.id = td.documento
     where td.tramite = new.id
       and d.tipo = 'pago_publicacion'
  ) then
    raise exception 'La publicación no se resuelve sin el comprobante del pago de la publicación'
      using errcode = 'check_violation';
  end if;

  return new;
end;
$$;

drop trigger if exists tramites_publicacion_pago on public.tramites;
create trigger tramites_publicacion_pago
  before update on public.tramites
  for each row execute function public.tramites_publicacion_con_pago();


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--   select codigo, nombre, vence from public.tipos_documento
--    where codigo in ('planilla_publicacion', 'pago_publicacion');  -- dos filas
--
--   select polname from pg_policy
--    where polname in ('documentos: el equipo sube el PUB de la publicacion',
--                      'adjuntos: el equipo engancha el PUB de la publicacion');
--                                                              -- dos filas
--
--   select tgname from pg_trigger
--    where tgname in ('tramites_abre_publicacion', 'tramites_publicacion_pago');
--                                                              -- dos filas
--
--  Y el camino entero, con una cuenta del equipo (no desde el SQL Editor,
--  que no estorba):
--    · resolver una protocolización que tenga su comprobante del pago
--      tiene que dejar una publicación nueva, en 'enviado', con la razón
--      social ya puesta:
--        select tipo, estado, datos from public.tramites
--         where inversionista = '<uuid>' order by creado_en desc limit 2;
--    · y marcarla resuelta sin el comprobante del pago tiene que responder
--        La publicación no se resuelve sin el comprobante del pago de la
--        publicación
