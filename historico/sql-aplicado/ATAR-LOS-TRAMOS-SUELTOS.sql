-- Solo para los que quedaron sin atar. Reejecutable.

-- 1. Mira: que constituciones hay y cual se resolvio antes de que naciera
--    cada tramo suelto. La buena es la ultima resuelta ANTES de 'nacio'.
select p.id as tramo, p.tipo, p.creado_en as nacio,
       c.id as constitucion, c.estado, c.resuelto_en
  from public.tramites p
  join public.tramites c
    on c.inversionista = p.inversionista and c.tipo = 'constitucion'
 where p.tipo = 'protocolizacion_acta' and p.viene_de is null
 order by p.creado_en, c.resuelto_en;

-- 2. Ata por esa regla: el tramo nace en el instante en que la
--    constitucion se resuelve, asi que es la ultima resuelta antes.
update public.tramites p
   set viene_de = (
     select c.id
       from public.tramites c
      where c.inversionista = p.inversionista
        and c.tipo = 'constitucion'
        and c.resuelto_en is not null
        and c.resuelto_en <= p.creado_en
      order by c.resuelto_en desc
      limit 1)
 where p.tipo = 'protocolizacion_acta'
   and p.viene_de is null;

-- 3. Y la publicacion, por lo mismo, contra su protocolizacion.
update public.tramites b
   set viene_de = (
     select p.id
       from public.tramites p
      where p.inversionista = b.inversionista
        and p.tipo = 'protocolizacion_acta'
        and p.resuelto_en is not null
        and p.resuelto_en <= b.creado_en
      order by p.resuelto_en desc
      limit 1)
 where b.tipo = 'publicacion_acta'
   and b.viene_de is null;

-- 4. Comprobar: cuantos y con origen tienen que salir iguales.
select tipo, count(*) as cuantos, count(viene_de) as con_origen
  from public.tramites
 where tipo in ('protocolizacion_acta', 'publicacion_acta')
 group by tipo;
