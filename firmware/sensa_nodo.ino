// Sensa — Firmware del nodo (ESP32), versión sin LCD.
//
// Lee el DHT11 cada segundo, manda la lectura al backend en cuanto cambia
// (y al menos cada 10 s), consulta comandos cada segundo y confirma los que
// aplica. La alerta de temperatura se da en el lugar con el LED rojo y el
// zumbador, según el umbral guardado, aunque no haya backend.
//
// LEDs: nunca hay dos prendidos a la vez. Funcionan como semáforo:
//   rojo     -> alerta: la temperatura pasó el umbral
//   amarillo -> cerca: a MARGEN_AVISO °C o menos del umbral (o modo manual)
//   verde    -> normal
//   parpadeando (verde o amarillo) -> sin conexión con el backend
//
// Antes el amarillo solo marcaba el modo manual, y como la app deja el LED
// siempre en automático, nunca se prendía.
//
// Comandos de la app además del LED:
//   alerta       -> beeps en el zumbador con el rojo prendido
//   probar_leds  -> rojo, amarillo y verde, uno por uno (también al arrancar)
// Por el monitor serie (115200): "a" manda la alerta y "p" prueba los LEDs.
// "1", "2" y "3" prenden fijo 3 s el rojo, el amarillo y el verde, para
// revisar el cableado de cada uno.
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
const unsigned long T_SENSOR        = 1000;   // el DHT11 no da más de 1 por segundo
const unsigned long T_COMANDO       = 1000;   // consulta de comandos
const unsigned long T_LECTURA_MIN   = 2000;   // no mandar lecturas más seguido
const unsigned long T_LECTURA_MAX   = 10000;  // mandar aunque no cambie nada
const unsigned long T_REINTENTO     = 5000;   // sin backend, no insistir cada segundo
const unsigned long T_WIFI          = 10000;
const unsigned long T_HTTP_TIMEOUT  = 2500;   // respuesta
const unsigned long T_CONEXION      = 1500;   // abrir el socket (red local)
const unsigned long T_PARPADEO      = 500;    // verde sin conexión

// Cambio mínimo para mandar la lectura antes de T_LECTURA_MAX.
const float DELTA_TEMP = 0.1;
const float DELTA_HUM  = 1.0;

// ---------- Alerta manual (botón "Mandar alerta") ----------
const int           BEEPS_ALERTA = 6;
const unsigned long BEEP_ON      = 150;
const unsigned long BEEP_OFF     = 100;

// ---------- Prueba de LEDs ----------
const unsigned long T_PASO_PRUEBA  = 400;  // tiempo de cada LED
const int           VUELTAS_PRUEBA = 2;    // rojo -> amarillo -> verde, 2 veces

// ---------- Rangos válidos del DHT11 (mismos que backend y app) ----------
const float TEMP_MIN = 0.0,  TEMP_MAX = 50.0;
const float HUM_MIN  = 20.0, HUM_MAX  = 90.0;

const float UMBRAL_POR_OMISION = 27.0;  // solo para el primer arranque

// Amarillo: la temperatura está a este margen o menos debajo del umbral.
// Con umbral 24.0 °C, el amarillo se prende desde 23.0 °C.
const float MARGEN_AVISO = 1.0;

// Prueba de un LED desde el monitor serie.
const unsigned long T_LED_FIJO = 3000;

DHT dht(PIN_DHT, TIPO_DHT);
Preferences prefs;

// Conexión HTTP persistente: se reutiliza el mismo socket entre peticiones,
// así cada consulta no paga una conexión nueva. http:// o https:// según
// API_BASE_URL.
WiFiClient       clientePlano;
WiFiClientSecure clienteSeguro;
WiFiClient*      cliente = &clientePlano;
HTTPClient       http;

// ---------- Estado ----------
float umbralC      = UMBRAL_POR_OMISION;  // se guarda en memoria no volátil
bool  tieneLectura = false;               // ya hay una lectura válida
float ultimaTemp   = 0.0;
float ultimaHum    = 0.0;
bool  alerta       = false;               // temperatura local > umbral
bool  cerca        = false;               // a MARGEN_AVISO o menos del umbral

bool  backendOk        = false;  // la última petición salió bien
bool  tieneRemoto      = false;  // ya recibimos algo del backend
bool  modoManual       = false;  // último modo que reportó el backend
bool  ledRemotoDeseado = false;  // led_deseado del backend
bool  ledEstado        = false;  // estado lógico del LED rojo (se envía)

// Lo último que se mandó, para mandar solo cuando cambie.
bool  yaEnvio       = false;
float tempEnviada   = 0.0;
float humEnviada    = 0.0;
bool  ledEnviado    = false;
bool  alertaEnviada = false;

// Efectos de un momento: mientras corren mandan sobre los LEDs y el
// zumbador, y se pausa la red para que los tiempos salgan parejos.
enum Efecto { SIN_EFECTO, EFECTO_ALERTA, EFECTO_PRUEBA, EFECTO_FIJO };
// Los enums van antes de cualquier función: el Arduino IDE genera los
// prototipos arriba de la primera y deben ver estos tipos.
enum Luz { NINGUNA, ROJO, AMARILLO, VERDE };
Efecto        efecto       = SIN_EFECTO;
Luz           luzFija      = NINGUNA;  // para EFECTO_FIJO
unsigned long efectoInicio = 0;
String        ackPendiente = "";  // se confirma al terminar el efecto
String        ultimoComandoId = "";

unsigned long tSensor = 0, tComando = 0, tLectura = 0, tWifi = 0;

// ---------- Lecturas del sensor ----------

bool lecturaValida(float t, float h) {
  if (isnan(t) || isnan(h)) return false;
  return t >= TEMP_MIN && t <= TEMP_MAX && h >= HUM_MIN && h <= HUM_MAX;
}

// Alerta (rojo) y cerca del umbral (amarillo), con el umbral guardado.
void calcularAlerta() {
  alerta = tieneLectura && ultimaTemp > umbralC;
  cerca  = tieneLectura && !alerta && ultimaTemp >= umbralC - MARGEN_AVISO;
}

void leerSensor() {
  // force=true: la librería guarda la lectura 2 s si no se fuerza. La
  // humedad sale de la misma muestra (sin forzar, usa la recién leída).
  float t = dht.readTemperature(false, true);
  float h = dht.readHumidity();
  if (!lecturaValida(t, h)) {
    Serial.println("Lectura descartada (fuera de rango o NaN)");
    return;  // conserva la última lectura válida
  }
  ultimaTemp = t;
  ultimaHum = h;
  tieneLectura = true;
  calcularAlerta();
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

// Única función que escribe los LEDs: prende uno y apaga los otros dos.
// Primero apaga y después prende, así ni por un instante hay dos encendidos.
void mostrarLuz(Luz luz) {
  if (luz != ROJO)     digitalWrite(PIN_LED_ROJO,  LOW);
  if (luz != AMARILLO) digitalWrite(PIN_LED_AMAR,  LOW);
  if (luz != VERDE)    digitalWrite(PIN_LED_VERDE, LOW);
  if (luz == ROJO)     digitalWrite(PIN_LED_ROJO,  HIGH);
  if (luz == AMARILLO) digitalWrite(PIN_LED_AMAR,  HIGH);
  if (luz == VERDE)    digitalWrite(PIN_LED_VERDE, HIGH);
}

void zumbador(bool suena) {
  digitalWrite(PIN_ZUMBADOR, suena ? HIGH : LOW);
}

void iniciarEfecto(Efecto e) {
  efecto = e;
  efectoInicio = millis();
}

bool hayEfecto() {
  return efecto != SIN_EFECTO;
}

// Se llama en cada vuelta del loop.
void actualizarSalidas() {
  ledEstado = ledDeseadoFinal();
  unsigned long ahora = millis();
  unsigned long t = ahora - efectoInicio;

  if (efecto == EFECTO_ALERTA) {
    unsigned long periodo = BEEP_ON + BEEP_OFF;
    if (t < periodo * BEEPS_ALERTA) {
      mostrarLuz(ROJO);
      zumbador((t % periodo) < BEEP_ON);
      return;
    }
    efecto = SIN_EFECTO;
  }

  if (efecto == EFECTO_PRUEBA) {
    unsigned long paso = t / T_PASO_PRUEBA;
    if (paso < 3UL * VUELTAS_PRUEBA) {
      const Luz orden[3] = {ROJO, AMARILLO, VERDE};
      mostrarLuz(orden[paso % 3]);
      zumbador(false);
      return;
    }
    efecto = SIN_EFECTO;
  }

  if (efecto == EFECTO_FIJO) {
    if (t < T_LED_FIJO) {
      mostrarLuz(luzFija);
      zumbador(false);
      return;
    }
    efecto = SIN_EFECTO;
  }

  Luz luz;
  // En automático el rojo también sigue a la lectura local: así se prende
  // en cuanto el sensor pasa el umbral, sin esperar la respuesta del
  // backend (que tarda hasta 1 s en llegar con la siguiente consulta).
  if (ledEstado || (alerta && !modoManual)) {
    luz = ROJO;
  } else {
    Luz base = (modoManual || cerca) ? AMARILLO : VERDE;
    // Sin backend, la luz parpadea para avisar que no hay conexión.
    bool prendida = backendOk || (ahora / T_PARPADEO) % 2 == 0;
    luz = prendida ? base : NINGUNA;
  }
  mostrarLuz(luz);
  zumbador(alerta);
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

int peticionUnaVez(bool esGet, const String& url, const String& cuerpo, String& respuesta) {
  if (!http.begin(*cliente, url)) return -1;
  http.setTimeout(T_HTTP_TIMEOUT);
  http.setConnectTimeout(T_CONEXION);
  http.addHeader("X-Device-Token", DEVICE_TOKEN);

  int code;
  if (esGet) {
    code = http.GET();
  } else {
    http.addHeader("Content-Type", "application/json");
    code = http.POST(cuerpo);
  }
  if (code > 0) respuesta = http.getString();
  http.end();  // con setReuse(true) deja el socket abierto
  return code;
}

// Devuelve el código HTTP, o un número negativo si no hubo conexión.
int peticion(bool esGet, const String& ruta, const String& cuerpo, String& respuesta) {
  if (WiFi.status() != WL_CONNECTED) return -1;
  String url = String(API_BASE_URL) + ruta;

  bool reusando = cliente->connected();
  int code = peticionUnaVez(esGet, url, cuerpo, respuesta);
  if (code < 0) {
    cliente->stop();
    // Si falló sobre un socket reutilizado, el servidor pudo haberlo
    // cerrado: se reintenta una vez con uno nuevo.
    if (reusando) {
      code = peticionUnaVez(esGet, url, cuerpo, respuesta);
      if (code < 0) cliente->stop();
    }
  }
  return code;
}

// Registra si el backend respondió. Un 422 es dato malo, no falla de enlace.
bool marcarResultado(int code, const char* quien) {
  if (code >= 200 && code < 300) {
    backendOk = true;
    return true;
  }
  if (code == 422) {
    Serial.printf("[%s] rechazado por el backend (422)\n", quien);
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
    calcularAlerta();
  }
}

// ---------- Ciclos de trabajo ----------

bool lecturaCambio() {
  if (!yaEnvio) return true;
  return fabs(ultimaTemp - tempEnviada) >= DELTA_TEMP ||
         fabs(ultimaHum - humEnviada) >= DELTA_HUM ||
         ledEstado != ledEnviado || alerta != alertaEnviada;
}

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

  yaEnvio = true;
  tempEnviada = ultimaTemp;
  humEnviada = ultimaHum;
  ledEnviado = ledEstado;
  alertaEnviada = alerta;

  JsonDocument r;
  if (deserializeJson(r, resp)) return;
  aplicarEstadoRemoto(r);

  Serial.printf("Enviado: %.1f C, %.0f %% HR, LED %s, modo %s, %s\n",
                ultimaTemp, ultimaHum, ledEstado ? "on" : "off",
                modoManual ? "manual" : "automatico",
                alerta ? "ALERTA (rojo)" : (cerca ? "cerca (amarillo)" : "normal (verde)"));
}

void enviarAck(const String& id, const char* accion) {
  JsonDocument ack;
  ack["comando_id"] = id;
  ack["led_estado"] = ledEstado;
  String cuerpo;
  serializeJson(ack, cuerpo);

  String respAck;
  int codeAck = peticion(false, rutaDispositivo("/ack"), cuerpo, respAck);
  Serial.printf("Comando %s -> ack %d\n", accion, codeAck);
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

  // Si el ack anterior no llegó, el backend lo vuelve a mandar: se
  // confirma otra vez sin repetir la alerta ni la prueba.
  bool repetido = (id == ultimoComandoId);
  ultimoComandoId = id;

  if (!repetido && accion == "alerta") {
    Serial.println("Alerta desde la app: beeps");
    iniciarEfecto(EFECTO_ALERTA);
    ackPendiente = id;
    return;
  }
  if (!repetido && accion == "probar_leds") {
    Serial.println("Prueba de LEDs desde la app");
    iniciarEfecto(EFECTO_PRUEBA);
    ackPendiente = id;
    return;
  }
  enviarAck(id, accion.c_str());
}

// "a" = alerta, "p" = prueba de LEDs, para probar sin la app.
void leerSerie() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == 'a' || c == 'A') {
      Serial.println("Alerta desde el monitor serie");
      iniciarEfecto(EFECTO_ALERTA);
    } else if (c == 'p' || c == 'P') {
      Serial.println("Prueba de LEDs desde el monitor serie");
      iniciarEfecto(EFECTO_PRUEBA);
    } else if (c >= '1' && c <= '3') {
      const Luz luces[3] = {ROJO, AMARILLO, VERDE};
      const char* nombres[3] = {"rojo (GPIO 25)", "amarillo (GPIO 26)", "verde (GPIO 27)"};
      int i = c - '1';
      Serial.printf("LED %s fijo 3 s. Si no prende, revisa ese cable, la "
                    "resistencia y que la pata larga vaya al GPIO.\n", nombres[i]);
      luzFija = luces[i];
      iniciarEfecto(EFECTO_FIJO);
    }
  }
}

// ---------- Arranque ----------

void setup() {
  Serial.begin(115200);

  pinMode(PIN_LED_ROJO, OUTPUT);
  pinMode(PIN_LED_AMAR, OUTPUT);
  pinMode(PIN_LED_VERDE, OUTPUT);
  pinMode(PIN_ZUMBADOR, OUTPUT);
  mostrarLuz(NINGUNA);
  zumbador(false);

  dht.begin();

  prefs.begin("sensa", false);
  umbralC = prefs.getFloat("umbral", UMBRAL_POR_OMISION);
  Serial.printf("Umbral guardado: %.1f C\n", umbralC);

  if (strncmp(API_BASE_URL, "https", 5) == 0) {
    // Demo: no valida el certificado del servidor. Para algo más serio,
    // pasar el certificado raíz con clienteSeguro.setCACert(...).
    clienteSeguro.setInsecure();
    cliente = &clienteSeguro;
  }
  http.setReuse(true);

  // Prueba de LEDs al arrancar, mientras se conecta el WiFi.
  iniciarEfecto(EFECTO_PRUEBA);

  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);  // sin ahorro de energía: responde mucho más rápido
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  unsigned long inicio = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - inicio < 20000) {
    actualizarSalidas();
    delay(20);
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
  leerSerie();

  if (ahora - tSensor >= T_SENSOR) {
    tSensor = ahora;
    leerSensor();
  }
  actualizarSalidas();

  // Mientras suena la alerta o corre la prueba no se usa la red: cada
  // petición bloquea el loop y desacompasaría los beeps.
  if (hayEfecto()) return;

  if (ackPendiente.length() > 0) {
    String id = ackPendiente;
    ackPendiente = "";
    enviarAck(id, "efecto");
  }
  if (ahora - tWifi >= T_WIFI) {
    tWifi = ahora;
    revisarWifi();
  }
  // Sin backend cada petición puede tardar hasta T_CONEXION y frena el
  // loop: solo se sondea con la consulta de comandos cada T_REINTENTO y las
  // lecturas esperan a que vuelva (la primera sale en cuanto responde).
  unsigned long tCadaComando = backendOk ? T_COMANDO : T_REINTENTO;
  if (ahora - tComando >= tCadaComando) {
    tComando = ahora;
    consultarComando();
    actualizarSalidas();
    if (hayEfecto()) return;  // llegó una alerta o una prueba
  }
  bool tocaPorTiempo = ahora - tLectura >= T_LECTURA_MAX;
  bool tocaPorCambio = ahora - tLectura >= T_LECTURA_MIN && lecturaCambio();
  if (backendOk && tieneLectura && (tocaPorTiempo || tocaPorCambio)) {
    tLectura = ahora;
    enviarLectura();
    actualizarSalidas();
  }
}
