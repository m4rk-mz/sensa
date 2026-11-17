# Sensa — Firmware del nodo (ESP32)

Pendiente de desarrollo. El nodo lee temperatura y humedad con un DHT11, las
manda al backend y enciende un LED cuando hay alerta.

## Hardware por nodo

ESP32 + DHT11 + LED de 5 mm con resistencia, protoboard, fuente y cables.
La tarjeta es genérica: en Windows puede pedir el driver CH340.

## Qué debe hacer

1. Conectarse al WiFi.
2. Cada 30 s: leer el DHT11 y mandar la lectura, incluyendo el estado real de
   su LED.
3. Cada 2 a 5 s: preguntar si hay un comando pendiente y aplicarlo.
4. Confirmar el comando aplicado.
5. Si el backend no responde, seguir en automático con el último umbral
   recibido, guardado en memoria.

## Contrato con la API

El token del sensor va en el encabezado `X-Device-Token`. Se obtiene al
registrar el sensor y **se muestra una sola vez**.

```
POST /devices/<ID>/readings          cada 30 s
     X-Device-Token: sensa.<ID>.<secreto>
     {"temperatura": 24.5, "humedad": 55.0, "led_estado": false}
  -> {"alerta": false, "led_deseado": false, "umbral_c": 27.0, "modo": "automatico"}

GET  /devices/<ID>/command           cada 2-5 s
     X-Device-Token: ...
  -> {"comando": {"id": "...", "accion": "led_on"}, "led_deseado": true,
      "umbral_c": 27.0, "modo": "manual"}

POST /devices/<ID>/ack
     {"comando_id": "...", "led_estado": true}
```

Rangos válidos del DHT11: 0 a 50 °C y 20 a 90 % HR. Una lectura fuera de rango
la rechaza el backend con 422, así que conviene descartarla en el nodo (el
DHT11 a veces devuelve basura) y reintentar en el siguiente ciclo.

## Secretos

El SSID, la contraseña del WiFi y el token del sensor van en un `secrets.h`
que **no se sube al repo** (está en `.gitignore`):

```c
#define WIFI_SSID     "..."
#define WIFI_PASSWORD "..."
#define API_BASE_URL  "http://192.168.x.x:8000"
#define DEVICE_ID     "..."
#define DEVICE_TOKEN  "sensa.<ID>.<secreto>"
```
