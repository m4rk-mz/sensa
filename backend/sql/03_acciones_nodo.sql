-- Sensa: acciones nuevas del nodo (24 nov 2026).
-- Correr UNA vez en el SQL Editor de Supabase si la BD ya existía.
-- Sin esto, POST /devices/<id>/command con "alerta" o "probar_leds" da 500.
--
-- alerta       -> el nodo da beeps con el zumbador y prende el LED rojo.
-- probar_leds  -> el nodo prende rojo, amarillo y verde, uno por uno.
-- Ninguna cambia el modo (automático/manual) ni el estado del LED.

alter type command_action add value if not exists 'alerta';
alter type command_action add value if not exists 'probar_leds';
