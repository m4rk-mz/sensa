import '../modelos/lectura.dart';
import '../modelos/reporte.dart';
import '../modelos/sensor.dart';
import '../servicios/sensa_api.dart';
import 'base_vm.dart';

/// Promedio de una hora del día, para la gráfica del reporte.
class PromedioHora {
  const PromedioHora({
    required this.hora,
    required this.promedio,
    required this.alerta,
  });

  final int hora;
  final double promedio;

  /// True si alguna lectura de esa hora pasó el umbral.
  final bool alerta;
}

/// VistaModelo de "Reporte del día": los números del backend más la gráfica
/// por hora, que se arma con las lecturas válidas de las últimas 24 h.
class ReporteVm extends BaseVm {
  ReporteVm(this.api);

  final SensaApi api;

  List<SensorEstado> _sensores = const <SensorEstado>[];
  SensorEstado? _seleccionado;
  ReporteDelDia? _reporte;
  List<PromedioHora> _porHora = const <PromedioHora>[];

  List<SensorEstado> get sensores => _sensores;
  SensorEstado? get seleccionado => _seleccionado;
  ReporteDelDia? get reporte => _reporte;
  List<PromedioHora> get porHora => _porHora;

  double get umbral => _seleccionado?.umbralC ?? 0;

  Future<void> cargar() async {
    final lista = await ejecutar(api.misSensores);
    if (lista == null) return;

    _sensores = lista;
    if (lista.isEmpty) {
      _seleccionado = null;
      _reporte = null;
      _porHora = const <PromedioHora>[];
      avisar();
      return;
    }

    final sigueExistiendo = _seleccionado != null &&
        lista.any((s) => s.id == _seleccionado!.id);
    _seleccionado = sigueExistiendo
        ? lista.firstWhere((s) => s.id == _seleccionado!.id)
        : lista.first;
    avisar();
    await _cargarDelSensor();
  }

  Future<void> elegirSensor(SensorEstado sensor) async {
    _seleccionado = sensor;
    _reporte = null;
    _porHora = const <PromedioHora>[];
    avisar();
    await _cargarDelSensor();
  }

  Future<void> _cargarDelSensor() async {
    final sensor = _seleccionado;
    if (sensor == null) return;

    final resultado = await ejecutar(() async {
      final reporte = await api.reporteDelDia(sensor.id);
      final lecturas = await api.lecturas(sensor.id, horas: 24, limite: 500);
      return <String, Object?>{'reporte': reporte, 'lecturas': lecturas};
    });
    if (resultado == null) return;

    _reporte = resultado['reporte'] as ReporteDelDia?;
    _porHora = _agruparPorHora(
      (resultado['lecturas'] as List<Lectura>?) ?? const <Lectura>[],
    );
    avisar();
  }

  /// Promedia las lecturas de cada hora local y marca las horas con alerta.
  static List<PromedioHora> _agruparPorHora(List<Lectura> lecturas) {
    final sumas = <int, double>{};
    final cuentas = <int, int>{};
    final alertas = <int>{};

    for (final lectura in lecturas) {
      final hora = lectura.creadoEn.toLocal().hour;
      sumas[hora] = (sumas[hora] ?? 0) + lectura.temperatura;
      cuentas[hora] = (cuentas[hora] ?? 0) + 1;
      if (lectura.alerta) alertas.add(hora);
    }

    final horas = sumas.keys.toList()..sort();
    return horas
        .map(
          (hora) => PromedioHora(
            hora: hora,
            promedio: sumas[hora]! / cuentas[hora]!,
            alerta: alertas.contains(hora),
          ),
        )
        .toList(growable: false);
  }
}
