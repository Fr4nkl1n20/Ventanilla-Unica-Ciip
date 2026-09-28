-- ═══════════════════════════════════════════════════════════════════════
--  CIIP · VENTANILLA ÚNICA — LA TRADUCCIÓN DE DOCUMENTOS (c17)
--  Va DESPUÉS de supabase-importe-del-dia.sql. Se puede correr más de una
--  vez.
-- ═══════════════════════════════════════════════════════════════════════

-- El importe del día sale en el paso 2, «Importe de traducción», mientras
-- la solicitud está recibida o en revisión. Los mismos estados que
-- IMPORTE_DEL_DIA.apostilla_documentos en panel.js.
insert into public.importe_del_dia_pasos (tipo_tramite, estados)
values ('apostilla_documentos', array['enviado','en_revision'])
on conflict (tipo_tramite) do update set estados = excluded.estados;

-- «Documento traducido» va detrás de «Comprobante de pago»: sin el
-- comprobante no se resuelve. Trigger propio, como el del SIDCAI.
create or replace function public.tramites_traduccion_con_pago()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.estado is not distinct from old.estado then
    return new;
  end if;
  if new.estado <> 'resuelto' or new.tipo <> 'apostilla_documentos' then
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
       and d.tipo = 'pago_importe_dia'
  ) then
    raise exception 'La traducción no se resuelve sin el comprobante del pago del importe'
      using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

drop trigger if exists tramites_traduccion_pago on public.tramites;
create trigger tramites_traduccion_pago
  before update on public.tramites
  for each row execute function public.tramites_traduccion_con_pago();

-- Las escaleras viejas (apostilla → traducción → legalización ante el
-- MPPRE) cambiadas desde «Editar textos» se quedarían pisando a las nuevas
-- paso por paso. Se van: las nuevas vienen de pasos.js.
delete from public.textos_panel
 where clave like '\_p.pasos.c17.%'
    or clave like '\_p.pasos.c17\_yaapostillado.%';

-- COMPROBACIÓN
--   select * from public.importe_del_dia_pasos where tipo_tramite = 'apostilla_documentos';
--   select tgname from pg_trigger where tgname = 'tramites_traduccion_pago';
--   select clave, idioma, texto from public.textos_panel where clave like '\_p.pasos.c17%';  -- ninguna
