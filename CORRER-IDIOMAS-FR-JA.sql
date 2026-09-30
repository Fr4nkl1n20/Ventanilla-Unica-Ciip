-- «Editar textos» en francés y japonés: textos_panel solo admitía los seis idiomas de antes.
alter table public.textos_panel
  drop constraint if exists textos_panel_idioma_valido,
  add constraint textos_panel_idioma_valido
    check (idioma in ('es', 'en', 'pt', 'it', 'zh', 'ru', 'fr', 'ja'));

comment on column public.textos_panel.idioma is 'es, en, pt, it, zh, ru, fr o ja';

select c.conname,
       pg_get_constraintdef(c.oid) as regla,
       pg_get_constraintdef(c.oid) like '%''fr''%'
         and pg_get_constraintdef(c.oid) like '%''ja''%' as admite_fr_y_ja
  from pg_constraint c
 where c.conrelid = 'public.textos_panel'::regclass
   and c.conname = 'textos_panel_idioma_valido';
