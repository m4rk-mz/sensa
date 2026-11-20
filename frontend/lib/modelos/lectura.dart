import '../core/json.dart';

/// Una lectura válida del DHT11. El backend nunca devuelve inválidas.
class Lectura {
  const Lectura({
    required this.id,
    required this.deviceId,
    required this.temperatura,
    required this.humedad,
    required this.creadoEn,
    this.ledReportado = false,
    this.alerta = false,
  });

  final String id;
  final String deviceId;
  final double temperatura;
  final double humedad;
  final DateTime creadoEn;
  final bool ledReportado;
  final bool alerta;

  factory Lectura.desdeJson(Map<String, dynamic> json) => Lectura(
        id: J.texto(json['id']),
        deviceId: J.texto(json['device_id']),
        temperatura: J.decimal(json['temperatura']),
        humedad: J.decimal(json['humedad']),
        creadoEn: J.fecha(json['creado_en']) ?? DateTime.now(),
        ledReportado: J.booleano(json['led_reportado']),
        alerta: J.booleano(json['alerta']),
      );
}
