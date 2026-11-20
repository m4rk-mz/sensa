import '../core/json.dart';

/// Un nodo (ESP32 + DHT11) registrado en un negocio.
class Sensor {
  const Sensor({
    required this.id,
    required this.businessId,
    required this.nombre,
    required this.umbralC,
    this.modoManualHasta,
    this.ledForzado,
    this.ledEstadoReal = false,
    this.ultimaLecturaEn,
    this.activo = true,
  });

  final String id;
  final String businessId;
  final String nombre;
  final double umbralC;
  final DateTime? modoManualHasta;
  final bool? ledForzado;
  final bool ledEstadoReal;
  final DateTime? ultimaLecturaEn;
  final bool activo;

  factory Sensor.desdeJson(Map<String, dynamic> json) => Sensor(
        id: J.texto(json['id']),
        businessId: J.texto(json['business_id']),
        nombre: J.texto(json['nombre']),
        umbralC: J.decimal(json['umbral_c']),
        modoManualHasta: J.fecha(json['modo_manual_hasta']),
        ledForzado: json['led_forzado'] == null
            ? null
            : J.booleano(json['led_forzado']),
        ledEstadoReal: J.booleano(json['led_estado_real']),
        ultimaLecturaEn: J.fecha(json['ultima_lectura_en']),
        activo: J.booleano(json['activo'], porOmision: true),
      );
}

/// Lo que devuelve GET /devices y GET /devices/{id}: el sensor más su última
/// lectura y el estado del LED, listo para pintar el detalle del sensor.
class SensorEstado {
  const SensorEstado({
    required this.sensor,
    this.temperatura,
    this.humedad,
    this.alerta = false,
    this.ledEstadoReal = false,
    this.ledDeseado = false,
    this.modo = 'automatico',
    this.modoManualHasta,
    this.ultimaLecturaEn,
    this.enLinea = false,
  });

  final Sensor sensor;
  final double? temperatura;
  final double? humedad;
  final bool alerta;
  final bool ledEstadoReal;
  final bool ledDeseado;

  /// "automatico" o "manual", calculado por el backend.
  final String modo;
  final DateTime? modoManualHasta;
  final DateTime? ultimaLecturaEn;
  final bool enLinea;

  String get id => sensor.id;
  String get nombre => sensor.nombre;
  double get umbralC => sensor.umbralC;
  bool get esManual => modo == 'manual';
  bool get sinDatos => temperatura == null || !enLinea;

  factory SensorEstado.desdeJson(Map<String, dynamic> json) => SensorEstado(
        sensor: Sensor.desdeJson(J.mapa(json['sensor'])),
        temperatura: J.decimalNulo(json['temperatura']),
        humedad: J.decimalNulo(json['humedad']),
        alerta: J.booleano(json['alerta']),
        ledEstadoReal: J.booleano(json['led_estado_real']),
        ledDeseado: J.booleano(json['led_deseado']),
        modo: J.texto(json['modo'], porOmision: 'automatico'),
        modoManualHasta: J.fecha(json['modo_manual_hasta']),
        ultimaLecturaEn: J.fecha(json['ultima_lectura_en']),
        enLinea: J.booleano(json['en_linea']),
      );
}

/// Respuesta del registro de un sensor: el token se muestra una sola vez.
class SensorRegistrado {
  const SensorRegistrado({required this.sensor, required this.token});

  final Sensor sensor;
  final String token;

  factory SensorRegistrado.desdeJson(Map<String, dynamic> json) =>
      SensorRegistrado(
        sensor: Sensor.desdeJson(J.mapa(json['sensor'])),
        token: J.texto(json['token']),
      );
}
