import '../core/json.dart';

/// Reporte de un día de un sensor, como lo arma el backend (solo con
/// lecturas válidas de las últimas 24 h).
class ReporteDiario {
  const ReporteDiario({
    required this.deviceId,
    required this.fecha,
    required this.tempMin,
    required this.tempMax,
    required this.tempProm,
    required this.humProm,
    required this.lecturasValidas,
    required this.alertas,
    required this.activacionesLed,
    this.generadoEn,
  });

  final String deviceId;
  final DateTime fecha;
  final double tempMin;
  final double tempMax;
  final double tempProm;
  final double humProm;
  final int lecturasValidas;
  final int alertas;
  final int activacionesLed;
  final DateTime? generadoEn;

  factory ReporteDiario.desdeJson(Map<String, dynamic> json) => ReporteDiario(
        deviceId: J.texto(json['device_id']),
        fecha: J.fecha(json['fecha']) ?? DateTime.now(),
        tempMin: J.decimal(json['temp_min']),
        tempMax: J.decimal(json['temp_max']),
        tempProm: J.decimal(json['temp_prom']),
        humProm: J.decimal(json['hum_prom']),
        lecturasValidas: J.entero(json['lecturas_validas']),
        alertas: J.entero(json['alertas']),
        activacionesLed: J.entero(json['activaciones_led']),
        generadoEn: J.fecha(json['generado_en']),
      );
}

/// Respuesta de GET /devices/{id}/reporte-diario: puede venir sin reporte
/// si el día todavía no tiene lecturas válidas.
class ReporteDelDia {
  const ReporteDelDia({
    required this.deviceId,
    required this.sensorNombre,
    required this.fecha,
    this.reporte,
    this.mensaje,
  });

  final String deviceId;
  final String sensorNombre;
  final DateTime fecha;
  final ReporteDiario? reporte;
  final String? mensaje;

  bool get tieneDatos => reporte != null;

  factory ReporteDelDia.desdeJson(Map<String, dynamic> json) {
    final crudo = json['reporte'];
    return ReporteDelDia(
      deviceId: J.texto(json['device_id']),
      sensorNombre: J.texto(json['sensor_nombre']),
      fecha: J.fecha(json['fecha']) ?? DateTime.now(),
      reporte: crudo == null ? null : ReporteDiario.desdeJson(J.mapa(crudo)),
      mensaje: json['mensaje'] == null ? null : J.texto(json['mensaje']),
    );
  }
}
