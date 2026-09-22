update public.tipos_tramite set activo = false
 where codigo = 'registros_laborales';

delete from public.tipos_tramite
 where codigo = 'registros_laborales'
   and not exists (
     select 1 from public.tramites t where t.tipo = 'registros_laborales'
   );

delete from public.textos_panel
 where clave like 'c9.%' or clave = 'g.parafiscal';

update public.tipos_tramite set activo = false
 where codigo in ('antecedentes_penales', 'constancia_domicilio', 'visa_dependientes');

delete from public.tipos_tramite
 where codigo in ('antecedentes_penales', 'constancia_domicilio', 'visa_dependientes')
   and not exists (
     select 1 from public.tramites t where t.tipo = tipos_tramite.codigo
   );

insert into public.tipos_documento (codigo, nombre, vence) values
  ('pub_saren', 'Planilla Única Bancaria (PUB) del pago al SAREN', false)
on conflict (codigo) do update set nombre = excluded.nombre;

insert into public.tipos_documento (codigo, nombre, vence) values
  ('certificado_inversionista', 'Certificado de Inversionista (VUCE)', false)
on conflict (codigo) do update
  set nombre = excluded.nombre,
      vence  = excluded.vence;

do $visas$
declare
  mudadas  bigint := 0;
  cuantas  bigint;
begin
  if not exists (select 1 from public.tipos_tramite
                  where codigo = 'visa_inversionista' and ref_panel = 'c1') then
    raise notice 'El codigo ya estaba liberado: no hay nada que mudar.';
  else
    drop table if exists pg_temp.visa_vieja;
    create temporary table visa_vieja as
      select * from public.tipos_tramite where codigo = 'visa_inversionista';
    update visa_vieja set codigo = 'visa_negocios', ref_panel = 'c1-provisional';
    insert into public.tipos_tramite select * from visa_vieja;

    if to_regclass('public.tramites') is not null then
      update public.tramites set tipo = 'visa_negocios'
       where tipo = 'visa_inversionista';
      get diagnostics cuantas = row_count;  mudadas := mudadas + cuantas;
    end if;

    if to_regclass('public.citas') is not null then
      update public.citas set tipo_tramite = 'visa_negocios'
       where tipo_tramite = 'visa_inversionista';
      get diagnostics cuantas = row_count;  mudadas := mudadas + cuantas;
    end if;

    if to_regclass('public.consultas') is not null then
      update public.consultas set tipo = 'visa_negocios'
       where tipo = 'visa_inversionista';
      get diagnostics cuantas = row_count;  mudadas := mudadas + cuantas;
    end if;

    if to_regclass('public.aranceles') is not null then
      update public.aranceles set tramite = 'visa_negocios'
       where tramite = 'visa_inversionista';
      get diagnostics cuantas = row_count;  mudadas := mudadas + cuantas;
    end if;

    delete from public.tipos_tramite where codigo = 'visa_inversionista';

    update public.tipos_tramite set ref_panel = 'c1'
     where codigo = 'visa_negocios';

    raise notice 'Codigo liberado. Filas mudadas a visa_negocios: %', mudadas;
  end if;

  insert into public.tipos_tramite (codigo, ref_panel, nombre, ente, fase, activo) values
    ('visa_inversionista', 'c38', 'Visa de inversionista (TR-I)', 'MPPRE', 1, true)
  on conflict (codigo) do update
    set ref_panel = excluded.ref_panel,
        nombre    = excluded.nombre,
        ente      = excluded.ente,
        fase      = excluded.fase,
        activo    = excluded.activo;
end
$visas$;

do $plazo$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public'
                and table_name   = 'tipos_tramite'
                and column_name  = 'plazo_dias') then
    update public.tipos_tramite set plazo_dias = 30
     where codigo = 'visa_inversionista' and plazo_dias is null;
  end if;
end
$plazo$;

update public.tipos_tramite set activo = true
 where codigo = 'visa_inversionista';
