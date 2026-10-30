-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LOS LOGOS DE AYUDA Y GUÍA, DE CADA ENLACE
--  Va DESPUÉS de supabase-textos.sql (textos_panel) y de
--  supabase-logos-fichas.sql (el cubo). Va al final para no mover el
--  número de nadie.
-- ═══════════════════════════════════════════════════════════════════════
--  DE DÓNDE SALE
--  ───────────────────────────────────────────────────────────────────────
--  Franklin Reyes, 30 de octubre de 2026: en Ayuda y guía → «Dónde hacer
--  las diligencias», cada enlace de una tarjeta (Authenology, Apacuana,
--  PROCERT…) enseñaba sólo sus iniciales. Que el administrador le pueda
--  poner, cambiar o quitar el logo desde el panel, como ya podía con el de
--  la tarjeta desde el 13-10-2026.
--
--  CÓMO QUEDA
--  ───────────────────────────────────────────────────────────────────────
--  Sin tabla ni cubo nuevos. El archivo va al cubo 'logos-fichas'
--  (público de lectura, sólo el admin escribe y borra) y su ruta a
--  textos_panel (la lee quien entra, sólo el admin escribe), en 'es':
--
--    · '<tarjeta>.logo'      → 'ayuda/<tarjeta>/<hora>.png'
--    · '<tarjeta>.logo.<n>'  → 'ayuda/<tarjeta>/enlaces/<n>/<hora>.png'
--
--  <n> sale de la dirección del enlace (ayHuella() en panel.js). Lo único
--  que añade este archivo es la regla de que esas claves guarden eso y
--  nada más: una ruta de ayuda/ de su misma tarjeta, con extensión de
--  imagen, y sólo en español, que un logo no cambia con el idioma. Así un
--  texto pegado por error en «Editar textos» no se convierte en un logo
--  roto para todos los inversionistas.
--
--  SIN CORRERLO LA PÁGINA NO SE ROMPE: los logos se suben y se ven igual;
--  sólo falta la regla.
-- ═══════════════════════════════════════════════════════════════════════

alter table public.textos_panel
  drop constraint if exists textos_panel_logo_ayuda;

alter table public.textos_panel
  add constraint textos_panel_logo_ayuda check (
    clave !~ '^ay_[a-z0-9_]+\.logo(\.[a-z0-9]+)?$'
    or (idioma = 'es'
        and texto ~ '^ayuda/ay_[a-z0-9_]+/(enlaces/[a-z0-9]+/)?[0-9]+\.(png|jpg|webp)$'
        and split_part(texto, '/', 2) = split_part(clave, '.', 1)
        and case when clave ~ '\.logo$' then texto !~ '/enlaces/'
                 else split_part(texto, '/', 4) = split_part(clave, '.', 3) end)
  );

comment on constraint textos_panel_logo_ayuda on public.textos_panel is
  'Las claves de los logos de Ayuda (<tarjeta>.logo y <tarjeta>.logo.<enlace>) sólo guardan, en es, la ruta de su imagen en el cubo logos-fichas';
