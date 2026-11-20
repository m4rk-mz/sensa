// Copiar a secrets.h y llenar en la laptop donde se compila.
// secrets.h NO se sube al repo.

#define WIFI_SSID      "NOMBRE_DE_LA_RED"      // el ESP32 solo ve 2.4 GHz
#define WIFI_PASSWORD  "CONTRASEÑA_WIFI"
#define API_BASE_URL  "https://sensa-backend.onrender.com" // URL pública del backend (HTTPS, sin / al final)
#define DEVICE_ID     "UUID_DEL_SENSOR"
#define DEVICE_TOKEN  "sensa.<ID>.<secreto>"    // se muestra una sola vez al registrar
