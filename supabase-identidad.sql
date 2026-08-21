-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — QUIÉN COMPROBÓ LA IDENTIDAD, Y CUÁNDO
-- ═══════════════════════════════════════════════════════════════════════
--  Se pega entero en el SQL Editor de Supabase y se pulsa Run. Es
--  reejecutable.
--
--  ORDEN: va después de supabase-tramites.sql y de supabase-gestor.sql.
-- ═══════════════════════════════════════════════════════════════════════
--
--  LO QUE ESTO ES, Y LO QUE NO ES
--  ─────────────────────────────────────────────────────────────────────
--  NO valida la identidad contra nadie. No le pregunta al SAIME si esa
--  cédula existe, ni a migración si ese pasaporte es válido. Eso es la
--  capa de interoperabilidad y necesita que un organismo conteste.
--
--  Lo que hace es dejar CONSTANCIA de una comprobación que ya ocurre y
--  que hoy no se escribe en ninguna parte: el gestor abre el expediente,
--  mira la cédula escaneada, decide que está bien... y de eso no queda
--  rastro. Mañana nadie puede responder "¿quién comprobó que esta
--  persona es quien dice ser, y cuándo?".
--
--  Convertir un acto informal en un registro con nombre y fecha no es
--  automatizar la verificación. Es poder auditarla. Y es la pieza que
--  migra intacta el día que exista la plataforma: entonces cambiará
--  QUIÉN firma la comprobación, no que quede registrada.
--
--  APPEND-ONLY, Y AHÍ ESTÁ TODO EL VALOR
--  ─────────────────────────────────────────────────────────────────────
--  No hay política de update ni de delete. Ninguna. Una comprobación de
--  identidad que se puede reescribir después no prueba nada: quien la
--  firmó podría cambiarla el día que le convenga, y entonces la traza no
--  vale ni el disco que ocupa.
--
--  Si un gestor se equivoca, no corrige: escribe otra encima, con su
--  nota. Las dos quedan. Que se vea que hubo una rectificación es parte
--  de lo que se está auditando.
--
--  Es el mismo criterio de tramite_eventos, donde de la nota para abajo
--  no se toca nada.
--
--  Y EL AUTOR LO PONE LA BASE
--  ─────────────────────────────────────────────────────────────────────
--  El campo 'gestor' no se acepta de quien escribe: lo pone un disparador
--  con auth.uid(). Todo el valor de esto es saber QUIÉN lo comprobó; si
--  alguien pudiera poner el nombre de otro, el registro seria peor que no
--  tenerlo, porque parecería fiable.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
--  1. LA TABLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.identidad_comprobaciones (
  id             bigint generated always as identity primary key,
  inversionista  uuid not null references auth.users(id)      on delete cascade,
  -- contra qué se comprobó. El documento puede borrarse mañana; la
  -- comprobación no, así que el tipo y el número se guardan aquí y no
  -- solo por referencia.
  documento      uuid references public.documentos(id)        on delete set null,
  tipo_documento text not null references public.tipos_documento(codigo),
  numero         text not null default '',
  resultado      text not null,
  nota           text not null default '',
  gestor         uuid not null references auth.users(id),
  creado_en      timestamptz not null default now(),

  constraint identidad_resultado_valido
    check (resultado in ('comprobada','rechazada')),
  -- Rechazar sin decir por qué deja al inversionista sin saber qué
  -- arreglar, igual que una devolución sin nota.
  constraint identidad_rechazo_con_motivo
    check (resultado <> 'rechazada' or length(trim(nota)) > 0)
);

comment on table  public.identidad_comprobaciones is
  'Constancia de que alguien del CIIP miró el documento de identidad. NO es validación contra ningún organismo';
comment on column public.identidad_comprobaciones.gestor is
  'Quién lo comprobó. Lo pone la base con auth.uid(), no quien escribe';
comment on column public.identidad_comprobaciones.numero is
  'El número leído del documento. Es lo que hace la constancia concreta: "comprobé que la cédula V-12345678 es de esta persona"';

create index if not exists identidad_por_persona
  on public.identidad_comprobaciones (inversionista, creado_en desc);


-- ───────────────────────────────────────────────────────────────────────
--  2. EL AUTOR Y LA HORA LOS PONE LA BASE
-- ───────────────────────────────────────────────────────────────────────
create or replace function public.identidad_firma()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Sin sesión (editor de SQL, proceso del servidor) se respeta lo que
  -- venga: es la única forma de cargar un histórico si algún día hace
  -- falta, y ahí no hay a quién atribuírselo.
  if auth.uid() is not null then
    new.gestor    := auth.uid();
    new.creado_en := now();
  end if;
  return new;
end;
$$;

drop trigger if exists identidad_la_firma_la_base on public.identidad_comprobaciones;
create trigger identidad_la_firma_la_base
  before insert on public.identidad_comprobaciones
  for each row execute function public.identidad_firma();


-- ───────────────────────────────────────────────────────────────────────
--  3. QUIÉN VE Y QUIÉN ESCRIBE
-- ───────────────────────────────────────────────────────────────────────
alter table public.identidad_comprobaciones enable row level security;

-- El inversionista ve las suyas. Tiene derecho a saber que alguien
-- revisó su documento, y cuándo: es información sobre él.
drop policy if exists "identidad: cada quien ve la suya" on public.identidad_comprobaciones;
create policy "identidad: cada quien ve la suya"
  on public.identidad_comprobaciones for select
  using (inversionista = auth.uid() or public.es_gestor());

-- Y solo el equipo escribe. El 'gestor = auth.uid()' del with check es
-- cinturón sobre tirantes: el disparador ya lo fuerza, pero si algún día
-- alguien toca el disparador, la política sigue en pie.
drop policy if exists "identidad: solo el equipo la firma" on public.identidad_comprobaciones;
create policy "identidad: solo el equipo la firma"
  on public.identidad_comprobaciones for insert
  with check (public.es_gestor() and gestor = auth.uid());

-- No hay política de update ni de delete, y es a propósito. Sin política
-- que lo permita, el RLS lo niega: nadie reescribe una comprobación de
-- identidad, ni siquiera quien la firmó.


-- ───────────────────────────────────────────────────────────────────────
--  COMPROBACIÓN
-- ───────────────────────────────────────────────────────────────────────
--  La última comprobación de cada persona:
--
--    select distinct on (inversionista)
--           inversionista, resultado, tipo_documento, numero, creado_en, gestor
--      from public.identidad_comprobaciones
--     order by inversionista, creado_en desc;
--
--  Que de verdad no se pueda reescribir (tiene que dar 0 filas tocadas):
--
--    update public.identidad_comprobaciones set resultado = 'comprobada';
--
--  Ojo: desde el SQL Editor eso SÍ pasa, porque ahí se corre como dueño
--  y el RLS no se aplica. La prueba de verdad es pruebas/rls.js, que lo
--  intenta con una sesión de gestor, que es como llegaría de fuera.
