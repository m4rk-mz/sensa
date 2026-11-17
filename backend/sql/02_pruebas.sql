-- Sensa: inserciones para las pruebas de la sección 5 del documento de clase.
-- Ejecutar DESPUÉS de scripts/seed_admin.py (que crea el negocio y el sensor demo).

-- ---------------------------------------------------------------------------
-- Prueba 5: "Insertar un registro inválido directo en la BD de prueba;
--            la API no lo muestra."
--
-- La tabla acepta este valor a propósito (no hay CHECK de rango en readings):
-- el filtro vive en los modelos del backend, que validan lo leído antes de
-- devolverlo. Tras ejecutar esto, GET /devices/{id}/readings debe seguir
-- mostrando solo lecturas válidas, y el reporte diario debe ignorarla.
-- ---------------------------------------------------------------------------
insert into readings (device_id, temperatura, humedad, led_reportado, alerta, creado_en)
select id, 999.9, -5.0, false, false, now()
from devices
where nombre = 'Nodo cuarto de servidor'
limit 1;

-- Para verificar qué guardó la BD (incluida la inválida):
-- select temperatura, humedad, creado_en from readings order by creado_en desc limit 5;

-- ---------------------------------------------------------------------------
-- Lecturas válidas de relleno, para que el panel y la gráfica tengan datos.
-- Genera 48 lecturas de la última hora con temperaturas entre 22 y 31 C.
-- ---------------------------------------------------------------------------
insert into readings (device_id, temperatura, humedad, led_reportado, alerta, creado_en)
select
  d.id,
  round((22 + random() * 9)::numeric, 1)                as temperatura,
  round((40 + random() * 20)::numeric, 1)               as humedad,
  false,
  false,
  now() - (interval '1 minute' * g)                     as creado_en
from devices d
cross join generate_series(1, 48) as g
where d.nombre = 'Nodo cuarto de servidor';

-- Marca como alerta las que superan el umbral del sensor, igual que lo haría
-- el backend al recibirlas.
update readings r
set alerta = true, led_reportado = true
from devices d
where r.device_id = d.id
  and r.temperatura > d.umbral_c
  and r.temperatura <= 50;
