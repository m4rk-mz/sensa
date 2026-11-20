import '../core/json.dart';

/// Una fila de la tabla del panel del administrador.
class FilaPanelNegocio {
  const FilaPanelNegocio({
    required this.businessId,
    required this.negocio,
    required this.sensores,
    required this.usuarios,
    required this.lecturas24h,
    required this.alertas24h,
    required this.sensoresEnLinea,
    this.tempPromedio,
    this.tempMax,
  });

  final String businessId;
  final String negocio;
  final int sensores;
  final int usuarios;
  final int lecturas24h;
  final int alertas24h;
  final int sensoresEnLinea;
  final double? tempPromedio;
  final double? tempMax;

  factory FilaPanelNegocio.desdeJson(Map<String, dynamic> json) =>
      FilaPanelNegocio(
        businessId: J.texto(json['business_id']),
        negocio: J.texto(json['negocio']),
        sensores: J.entero(json['sensores']),
        usuarios: J.entero(json['usuarios']),
        lecturas24h: J.entero(json['lecturas_24h']),
        alertas24h: J.entero(json['alertas_24h']),
        sensoresEnLinea: J.entero(json['sensores_en_linea']),
        tempPromedio: J.decimalNulo(json['temp_promedio']),
        tempMax: J.decimalNulo(json['temp_max']),
      );
}

/// Un punto de la gráfica del panel.
class PuntoGrafica {
  const PuntoGrafica({required this.etiqueta, required this.valor});

  final String etiqueta;
  final double valor;

  factory PuntoGrafica.desdeJson(Map<String, dynamic> json) => PuntoGrafica(
        etiqueta: J.texto(json['etiqueta']),
        valor: J.decimal(json['valor']),
      );
}

/// Respuesta de GET /admin/stats/negocios: los indicadores, la tabla y la
/// gráfica del panel, contando solo lecturas válidas.
class PanelAdmin {
  const PanelAdmin({
    required this.generadoEn,
    required this.totalNegocios,
    required this.totalSensores,
    required this.totalUsuarios,
    required this.lecturasValidas24h,
    required this.lecturasDescartadas24h,
    required this.alertas24h,
    required this.tabla,
    required this.graficaTempPromedio,
  });

  final DateTime generadoEn;
  final int totalNegocios;
  final int totalSensores;
  final int totalUsuarios;
  final int lecturasValidas24h;
  final int lecturasDescartadas24h;
  final int alertas24h;
  final List<FilaPanelNegocio> tabla;
  final List<PuntoGrafica> graficaTempPromedio;

  factory PanelAdmin.desdeJson(Map<String, dynamic> json) => PanelAdmin(
        generadoEn: J.fecha(json['generado_en']) ?? DateTime.now(),
        totalNegocios: J.entero(json['total_negocios']),
        totalSensores: J.entero(json['total_sensores']),
        totalUsuarios: J.entero(json['total_usuarios']),
        lecturasValidas24h: J.entero(json['lecturas_validas_24h']),
        lecturasDescartadas24h: J.entero(json['lecturas_descartadas_24h']),
        alertas24h: J.entero(json['alertas_24h']),
        tabla: J
            .lista(json['tabla'])
            .map(FilaPanelNegocio.desdeJson)
            .toList(growable: false),
        graficaTempPromedio: J
            .lista(json['grafica_temp_promedio'])
            .map(PuntoGrafica.desdeJson)
            .toList(growable: false),
      );
}
