// Sensa — Firmware del nodo (ESP32), versión sin LCD.
//
// Lee el DHT11, manda lecturas al backend cada 30 s, consulta comandos del
// LED cada 3 s y confirma los que aplica. La alerta se da en el lugar con el
// LED rojo y el zumbador, según el umbral guardado, aunque no haya backend.
//
// Configuración: crear firmware/secrets.h a partir de secrets.example.h.
// Ese archivo NO va al repo (está en .gitignore).

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <Preferences.h>
#include "secrets.h"

// ---------- Pines (ver Sensa_circuito_nodo.md) ----------
#define PIN_DHT        4    // DHT11 DATA
#define TIPO_DHT       DHT11
#define PIN_LED_ROJO   25   // alerta / estado real del actuador
#define PIN_LED_AMAR   26   // modo manual activo
#define PIN_LED_VERDE  27   // en línea y sin alerta
#define PIN_ZUMBADOR   33   // base del transistor: HIGH = suena

// ---------- Tiempos (ms) ----------
const unsigned long T_SENSOR       = 2500;
const unsigned long T_COMANDO      = 3000;
const unsigned long T_LECTURA      = 30000;
const unsigned long T_WIFI         = 10000;
const unsigned long T_HTTP_TIMEOUT = 4000;

// ---------- Rangos válidos del DHT11 (mismos que backend y app) ----------
const float TEMP_MIN = 0.0,  TEMP_MAX = 50.0;
const float HUM_MIN  = 20.0, HUM_MAX  = 90.0;

const float UMBRAL_POR_OMISION = 27.0;  // solo para el primer arranque

DHT dht(PIN_DHT, TIPO_DHT);
Preferences prefs;
WiFiClientSecure clienteSeguro;  // HTTPS hacia el backend en la nube

// ---------- Estado ----------
float umbralC      = UMBRAL_POR_OMISION;  // se guarda en memoria no volátil
bool  tieneLectura = false;               // ya hay una lectura válida
float ultimaTemp   = 0.0;
float ultimaHum    = 0.0;
bool  alerta       = false;               // temperatura local > umbral

bool  backendOk        = false;  // la última petición salió bien
bool  tieneRemoto      = false;  // ya recibimos algo del backend
bool  modoManual       = false;  // último modo que reportó el backend
bool  ledRemotoDeseado = false;  // led_deseado del backend
bool  ledEstado        = false;  // estado real del LED rojo (se envía)

unsigned long tSensor = 0, tComando = 0, tLectura = 0, tWifi = 0;

// ---------- Lecturas del sensor ----------

bool lecturaValida(float t, float h) {
  if (isnan(t) || isnan(h)) return false;
  return t >= TEMP_MIN && t <= TEMP_MAX && h >= HUM_MIN && h <= HUM_MAX;
}

void leerSensor() {
  float t = dht.readTemperature();
  float h = dht.readHumidity();
  if (!lecturaValida(t, h)) {
    Serial.println("Lectura descartada (fuera de rango o NaN)");
    return;  // conserva la última lectura válida
  }
  ultimaTemp = t;
  ultimaHum = h;
  tieneLectura = true;
  alerta = ultimaTemp > umbralC;
}

// ---------- Decisión del LED ----------

// Con backend, manda su led_deseado (cubre automático y manual).
// Sin backend en manual, mantiene el último valor remoto.
// Sin backend en automático, decide el nodo con el umbral guardado.
bool ledDeseadoFinal() {
  if (backendOk) return ledRemotoDeseado;
  if (tieneRemoto && modoManual) return ledRemotoDeseado;
  return tieneLectura && alerta;
}

void actualizarSalidas() {
  ledEstado = ledDeseadoFinal();
  digitalWrite(PIN_LED_ROJO, ledEstado ? HIGH : LOW);
  digitalWrite(PIN_LED_AMAR, modoManual ? HIGH : LOW);
  digitalWrite(PIN_LED_VERDE, (backendOk && !alerta) ? HIGH : LOW);
  digitalWrite(PIN_ZUMBADOR, alerta ? HIGH : LOW);
}

// ---------- WiFi ----------

void revisarWifi() {
  if (WiFi.status() == WL_CONNECTED) return;
  backendOk = false;
  Serial.println("WiFi caído, reconectando...");
  WiFi.reconnect();
}

// ---------- HTTP ----------

String rutaDispositivo(const char* sufijo) {
  return String("/devices/") + DEVICE_ID + sufijo;
}

// Devuelve el código HTTP, o -1 si no hubo conexión.
int peticion(bool esGet, const String& ruta, const String& cuerpo, String& respuesta) {
  if (WiFi.status() != WL_CONNECTED) return -1;

  HTTPClient http;
  http.setTimeout(T_HTTP_TIMEOUT);
  http.begin(clienteSeguro, String(API_BASE_URL) + ruta);
  http.addHeader("X-Device-Token", DEVICE_TOKEN);

  int code;
  if (esGet) {
    code = http.GET();
  } else {
    http.addHeader("Content-Type", "application/json");
    code = http.POST(cuerpo);
  }
  if (code > 0) respuesta = http.getString();
  http.end();
  return code;
}

// Registra si el backend respondió. Un 422 es dato malo, no falla de enlace.
bool marcarResultado(int code, const char* quien) {
  if (code >= 200 && code < 300) {
    backendOk = true;
    return true;
  }
  if (code == 422) {
    Serial.printf("[%s] lectura rechazada por el backend (422)\n", quien);
    return false;
  }
  backendOk = false;
  if (code == 401) {
    Serial.printf("[%s] token rechazado (401): revisar DEVICE_TOKEN\n", quien);
  } else {
    Serial.printf("[%s] sin respuesta del backend (%d)\n", quien, code);
  }
  return false;
}

// Guarda el estado que manda el backend y el umbral si cambió.
void aplicarEstadoRemoto(JsonDocument& r) {
  tieneRemoto = true;
  ledRemotoDeseado = r["led_deseado"] | false;
  String modo = r["modo"] | "automatico";
  modoManual = (modo == "manual");

  float u = r["umbral_c"] | umbralC;
  if (u != umbralC) {
    umbralC = u;
    prefs.putFloat("umbral", umbralC);
    Serial.printf("Umbral actualizado: %.1f °C (guardado)\n", umbralC);
    alerta = tieneLectura && ultimaTemp > umbralC;
  }
}

// ---------- Ciclos de trabajo ----------

void enviarLectura() {
  if (!tieneLectura) return;

  JsonDocument doc;
  doc["temperatura"] = ultimaTemp;
  doc["humedad"] = ultimaHum;
  doc["led_estado"] = ledEstado;
  String cuerpo;
  serializeJson(doc, cuerpo);

  String resp;
  int code = peticion(false, rutaDispositivo("/readings"), cuerpo, resp);
  if (!marcarResultado(code, "lectura")) return;

  JsonDocument r;
  if (deserializeJson(r, resp)) return;
  aplicarEstadoRemoto(r);

  Serial.printf("Enviado: %.1f C, %.0f %% HR, LED %s, modo %s, alerta %s\n",
                ultimaTemp, ultimaHum, ledEstado ? "on" : "off",
                modoManual ? "manual" : "automatico", alerta ? "si" : "no");
}

void consultarComando() {
  String resp;
  int code = peticion(true, rutaDispositivo("/command"), "", resp);
  if (!marcarResultado(code, "comando")) return;

  JsonDocument doc;
  if (deserializeJson(doc, resp)) return;
  aplicarEstadoRemoto(doc);
  actualizarSalidas();  // el ack debe reportar el estado ya aplicado

  if (doc["comando"].isNull()) return;

  String id = doc["comando"]["id"] | "";
  String accion = doc["comando"]["accion"] | "";
  if (id.length() == 0) return;

  JsonDocument ack;
  ack["comando_id"] = id;
  ack["led_estado"] = ledEstado;
  String cuerpo;
  serializeJson(ack, cuerpo);

  String respAck;
  int codeAck = peticion(false, rutaDispositivo("/ack"), cuerpo, respAck);
  Serial.printf("Comando %s -> ack %d\n", accion.c_str(), codeAck);
}

// ---------- Arranque ----------

void setup() {
  Serial.begin(115200);

  pinMode(PIN_LED_ROJO, OUTPUT);
  pinMode(PIN_LED_AMAR, OUTPUT);
  pinMode(PIN_LED_VERDE, OUTPUT);
  pinMode(PIN_ZUMBADOR, OUTPUT);
  digitalWrite(PIN_ZUMBADOR, LOW);

  dht.begin();

  // Demo: no valida el certificado del servidor. Para algo más serio,
  // pasar el certificado raíz con clienteSeguro.setCACert(...).
  clienteSeguro.setInsecure();

  prefs.begin("sensa", false);
  umbralC = prefs.getFloat("umbral", UMBRAL_POR_OMISION);
  Serial.printf("Umbral guardado: %.1f C\n", umbralC);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long inicio = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - inicio < 20000) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("WiFi OK. IP del nodo: %s\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println("Sin WiFi: sigue en automático con el umbral guardado.");
  }
}

// ---------- Ciclo principal (sin delay) ----------

void loop() {
  unsigned long ahora = millis();

  if (ahora - tWifi >= T_WIFI) {
    tWifi = ahora;
    revisarWifi();
  }
  if (ahora - tSensor >= T_SENSOR) {
    tSensor = ahora;
    leerSensor();
    actualizarSalidas();
  }
  if (ahora - tComando >= T_COMANDO) {
    tComando = ahora;
    consultarComando();
    actualizarSalidas();
  }
  if (ahora - tLectura >= T_LECTURA) {
    tLectura = ahora;
    enviarLectura();
    actualizarSalidas();
  }
}
