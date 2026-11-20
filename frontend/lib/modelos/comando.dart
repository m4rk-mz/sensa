import '../core/json.dart';

/// Acciones que la app puede pedir para el LED.
class AccionLed {
  static const String encender = 'led_on';
  static const String apagar = 'led_off';
  static const String automatico = 'auto';
}

/// Un comando del LED y en qué va: pendiente, enviado, confirmado o sin
/// respuesta (cuando el nodo no contestó en 15 s).
class Comando {
  const Comando({
    required this.id,
    required this.deviceId,
    required this.accion,
    required this.estado,
    required this.creadoEn,
    this.enviadoEn,
    this.confirmadoEn,
  });

  final String id;
  final String deviceId;
  final String accion;
  final String estado;
  final DateTime creadoEn;
  final DateTime? enviadoEn;
  final DateTime? confirmadoEn;

  bool get confirmado => estado == 'confirmado';
  bool get sinRespuesta => estado == 'sin_respuesta';
  bool get enCamino => estado == 'pendiente' || estado == 'enviado';

  String get accionLegible {
    switch (accion) {
      case AccionLed.encender:
        return 'Encender el LED';
      case AccionLed.apagar:
        return 'Apagar el LED';
      default:
        return 'Volver a automático';
    }
  }

  String get estadoLegible {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente, el nodo no lo ha recogido';
      case 'enviado':
        return 'Enviado, sin confirmar';
      case 'confirmado':
        return 'Confirmado';
      case 'sin_respuesta':
        return 'Sin respuesta del nodo';
      default:
        return estado;
    }
  }

  factory Comando.desdeJson(Map<String, dynamic> json) => Comando(
        id: J.texto(json['id']),
        deviceId: J.texto(json['device_id']),
        accion: J.texto(json['accion']),
        estado: J.texto(json['estado']),
        creadoEn: J.fecha(json['creado_en']) ?? DateTime.now(),
        enviadoEn: J.fecha(json['enviado_en']),
        confirmadoEn: J.fecha(json['confirmado_en']),
      );
}
