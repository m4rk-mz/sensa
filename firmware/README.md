# Sensa — Firmware del nodo (ESP32)

El nodo lee temperatura y humedad con un DHT11, las manda al backend y avisa en
el lugar con tres LEDs y un zumbador. Detalle del armado en
`Sensa_circuito_nodo.md` (pines: DHT 4, rojo 25, amarillo 26, verde 27,
zumbador 33).

## Qué hace

| Cada | Qué pasa |
|---|---|
| 1 s | Lee el DHT11 (descarta NaN y fuera de rango) y recalcula LEDs y zumbador. |
| 1 s | `GET /devices/{id}/command`. Aplica el comando y manda el `ack`. |
| en cuanto cambia (mín. 2 s) | `POST /devices/{id}/readings`. Cambio = ±0.1 °C, ±1 % HR, LED o alerta. |
| 10 s | `POST /devices/{id}/readings` aunque no cambie nada (latido). |
| 10 s | Revisa el WiFi y reconecta. |

Sin backend, solo sondea cada 5 s para no frenar el loop, y decide el LED con el
umbral guardado en memoria.

La conexión HTTP se reutiliza entre peticiones y el WiFi va sin ahorro de
energía (`WiFi.setSleep(false)`): las dos cosas bajan mucho la latencia.

## LEDs: siempre uno a la vez

| Luz | Cuándo |
|---|---|
| Rojo | LED de alerta encendido (automático sobre el umbral, o forzado en manual) |
| Amarillo | Modo manual con el LED apagado |
| Verde fijo | En línea y sin alerta |
| Verde parpadeando | Sin respuesta del backend |

`mostrarLuz()` es la única función que escribe los LEDs: apaga los otros dos
antes de prender uno.

## Acciones desde la app

| Botón | `accion` | En el nodo |
|---|---|---|
| Mandar alerta | `alerta` | 6 beeps (150 ms / 100 ms) con el rojo prendido y los demás apagados. |
| Probar LEDs | `probar_leds` | Rojo → amarillo → verde, 400 ms cada uno, dos vueltas. |

Ninguna cambia el modo ni el estado del LED. El `ack` sale al terminar. Mientras
corren, el nodo no usa la red para que los tiempos salgan parejos. La prueba de
LEDs también corre al arrancar.

Desde el monitor serie (115200): `a` = alerta, `p` = prueba de LEDs.

El zumbador también suena fijo mientras la temperatura esté sobre el umbral.

## Contrato con la API

El token del sensor va en el encabezado `X-Device-Token`. Se obtiene al
registrar el sensor y **se muestra una sola vez**.

```
POST /devices/<ID>/readings
     X-Device-Token: sensa.<ID>.<secreto>
     {"temperatura": 24.5, "humedad": 55.0, "led_estado": false}
  -> {"alerta": false, "led_deseado": false, "umbral_c": 27.0, "modo": "automatico"}

GET  /devices/<ID>/command
  -> {"comando": {"id": "...", "accion": "alerta"}, "led_deseado": false,
      "umbral_c": 27.0, "modo": "automatico"}
     accion: led_on | led_off | auto | alerta | probar_leds

POST /devices/<ID>/ack
     {"comando_id": "...", "led_estado": false}
```

Rangos válidos del DHT11: 0 a 50 °C y 20 a 90 % HR.

## Secretos

`secrets.h` (no se sube; está en `.gitignore`), a partir de `secrets.example.h`:

```c
#define WIFI_SSID     "..."
#define WIFI_PASSWORD "..."
#define API_BASE_URL  "http://192.168.x.x:8000"   // o https://... (se detecta)
#define DEVICE_ID     "..."
#define DEVICE_TOKEN  "sensa.<ID>.<secreto>"
```

Librerías: `DHT sensor library` (Adafruit) con `Adafruit Unified Sensor`, y
`ArduinoJson` 7.x.
