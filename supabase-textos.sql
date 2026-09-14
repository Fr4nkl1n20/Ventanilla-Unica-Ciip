-- ═══════════════════════════════════════════════════════════════════════
--  LOS TEXTOS DEL PANEL, EDITABLES POR EL ADMINISTRADOR
-- ═══════════════════════════════════════════════════════════════════════
--  «quiero tener la opcion de como administrador poder editar titulos de la
--   pagina y de los que dicen las fichas» (Franklin Reyes, 14 de septiembre
--   de 2026).
--
--  Los textos del panel viven en el diccionario del propio HTML, en seis
--  idiomas, y cambiar uno era cambiar el archivo y volver a publicarlo. Esta
--  tabla guarda SOLO lo que el administrador ha cambiado: una fila por texto
--  y por idioma. Lo que no esté aquí lo sigue poniendo el diccionario, así
--  que la tabla vacía deja el panel exactamente como estaba.
--
--  Por idioma, y no un texto para todos: cambiar el español no toca las
--  otras cinco traducciones. Lo decidió Franklin el mismo día: «Edita cada
--  idioma».
--
--  QUÉ ES LA CLAVE
--  La misma que usa el panel, sin inventar otra:
--    · las del diccionario, con punto:     'c33.name', 'tsec.title'
--    · las de pasos.js, sin punto:          'lh_uno'
--    · las del organismo de cada tarjeta:   'c33.sigla', 'c33.ente'
--  El panel decide a cuál de los tres corresponde. La base no lo valida
--  contra el diccionario porque el diccionario no está en la base: una clave
--  que ya no exista simplemente no se pinta en ningún sitio.
--
--  Mismo patrón que acompanamiento.textos, pero en filas y no en un jsonb:
--  aquí hay cientos de textos posibles, y una fila por texto deja ver quién
--  cambió cuál y cuándo.
--
--  Depende de: supabase-setup.sql (perfiles) y supabase-admin.sql (es_admin).
-- ═══════════════════════════════════════════════════════════════════════

do $$
begin
  if to_regprocedure('public.es_admin()') is null then
    raise exception 'Falta public.es_admin(): corre antes supabase-admin.sql';
  end if;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 1. LA TABLA
-- ───────────────────────────────────────────────────────────────────────
create table if not exists public.textos_panel (
  clave           text        not null,
  idioma          text        not null,
  texto           text        not null,
  actualizado_en  timestamptz not null default now(),
  actualizado_por uuid references auth.users(id) on delete set null,

  primary key (clave, idioma),
  -- Los seis idiomas del panel, ni uno más: un 'ES' o un 'spa' guardaría
  -- una fila que no se pinta nunca y nadie sabría por qué.
  constraint textos_panel_idioma_valido check (idioma in ('es', 'en', 'pt', 'it', 'zh', 'ru')),
  -- Una clave con forma de clave: letras, números, punto, guion y guion
  -- bajo. Así no cabe un texto pegado por error en el sitio de la clave.
  constraint textos_panel_clave_valida  check (clave ~ '^[A-Za-z0-9_.-]{1,80}$'),
  -- Un texto vacío no es «sin texto»: es un hueco en la pantalla. Para
  -- volver al original se BORRA la fila, que es lo que hace el panel.
  constraint textos_panel_texto_lleno   check (length(btrim(texto)) > 0),
  -- Tope generoso: la descripción más larga del diccionario ronda las
  -- doscientas letras. Mil deja sitio de sobra y corta un pegado accidental.
  constraint textos_panel_texto_tope    check (length(texto) <= 1000)
);

comment on table  public.textos_panel        is 'Textos del panel cambiados por el administrador, por idioma. Lo que falte lo pone el diccionario';
comment on column public.textos_panel.clave  is 'La clave del panel: la del diccionario (c33.name), la de pasos.js (lh_uno) o la del organismo (c33.ente)';
comment on column public.textos_panel.idioma is 'es, en, pt, it, zh o ru';

alter table public.textos_panel enable row level security;

-- Leer: cualquiera con sesión. El inversionista ve los textos cambiados, así
-- que tiene que poder leerlos.
drop policy if exists "textos_panel: lo lee cualquiera" on public.textos_panel;
create policy "textos_panel: lo lee cualquiera" on public.textos_panel
  for select to authenticated using (true);

-- Escribir: solo el admin. Insertar y cambiar (el panel hace upsert) y
-- borrar (volver al original).
drop policy if exists "textos_panel: el admin lo escribe" on public.textos_panel;
create policy "textos_panel: el admin lo escribe" on public.textos_panel
  for insert to authenticated
  with check (public.es_admin());

drop policy if exists "textos_panel: el admin lo cambia" on public.textos_panel;
create policy "textos_panel: el admin lo cambia" on public.textos_panel
  for update to authenticated
  using      (public.es_admin())
  with check (public.es_admin());

drop policy if exists "textos_panel: el admin lo borra" on public.textos_panel;
create policy "textos_panel: el admin lo borra" on public.textos_panel
  for delete to authenticated
  using (public.es_admin());


-- ───────────────────────────────────────────────────────────────────────
-- 2. QUIÉN LO TOCÓ
-- ───────────────────────────────────────────────────────────────────────
-- Lo escribe un disparador, como en acompanamiento: un campo que rellena
-- quien escribe es un campo que quien escribe puede mentir.
create or replace function public.marca_textos_panel()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  new.actualizado_por := auth.uid();
  new.actualizado_en  := now();
  return new;
end $$;

drop trigger if exists textos_panel_quien on public.textos_panel;
create trigger textos_panel_quien
  before insert or update on public.textos_panel
  for each row execute function public.marca_textos_panel();


-- ───────────────────────────────────────────────────────────────────────
-- LO QUE ESTO NO HACE
-- ───────────────────────────────────────────────────────────────────────
-- · No entra en la bitácora. Quién cambió cada texto por última vez queda
--   en su propia fila, igual que en acompanamiento.
-- · No toca tipos_tramite.nombre. Ese nombre es el de la pantalla de
--   Catálogo y del filtro; el que ve el inversionista en la tarjeta sale
--   del diccionario, y es el que se cambia aquí.
-- · No guarda el texto original. El original está en el HTML; borrar la
--   fila es volver a él.


-- ───────────────────────────────────────────────────────────────────────
-- COMPROBACIONES
-- ───────────────────────────────────────────────────────────────────────
-- 1. Las cuatro políticas: leer, escribir, cambiar y borrar.
select policyname, cmd from pg_policies
where  schemaname = 'public' and tablename = 'textos_panel'
order  by cmd;

-- 2. Lo que hay cambiado, por idioma.
select idioma, count(*) from public.textos_panel group by idioma order by idioma;
