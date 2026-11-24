-- Sensa: limpieza de nodos de prueba (24 nov 2026).
-- Correr en el SQL Editor de Supabase SOLO si quedaron sensores registrados
-- que ya no existen físicamente.
--
-- Borrar un sensor se lleva por delante sus lecturas, sus comandos y sus
-- reportes (las tablas hijas tienen `on delete cascade`). No tiene vuelta
-- atrás. Lo mismo se puede hacer desde la app, con la cuenta de
-- administrador: en "Sensores", el icono de bote de basura de cada tarjeta.

-- 1) Primero mira qué hay y cuántas lecturas se irían con cada uno.
select d.id,
       d.nombre,
       b.nombre as negocio,
       d.activo,
       d.ultima_lectura_en,
       (select count(*) from readings r where r.device_id = d.id) as lecturas
from devices d
join businesses b on b.id = d.business_id
order by d.creado_en;

-- 2) Revisa el resultado de arriba y deja solo el nodo que sí existe.
--    Cambia el nombre si el tuyo se llama distinto.
delete from devices
where nombre <> 'NODO PRUEBA OTRA VEZ';

-- 3) Comprueba que quedó uno solo.
select id, nombre, umbral_c, ultima_lectura_en from devices;
