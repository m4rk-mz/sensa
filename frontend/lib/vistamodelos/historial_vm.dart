import 'package:flutter/foundation.dart';

import '../modelos/reporte.dart';
import '../modelos/sensor.dart';
import '../servicios/sensa_api.dart';
import 'base_vm.dart';

/// VistaModelo de "Historial": los reportes diarios que ya quedaron
/// guardados de un sensor, del más nuevo al más viejo.
///
/// Los reportes los guarda el backend a las 00:10 (el del día anterior) o
/// cuando alguien toca "Generar" en "Reporte del día". Aquí solo se leen.
class HistorialVm extends BaseVm {
  HistorialVm(this.api) {
    reportesGuardados.addListener(_alGuardarseUnReporte);
  }

  final SensaApi api;

  /// Sube cada vez que la app guarda un reporte (botón "Generar"). Las
  /// pestañas viven todas a la vez, así que sin este aviso el historial no
  /// se enteraba del reporte nuevo hasta deslizar para refrescar.
  static final ValueNotifier<int> reportesGuardados = ValueNotifier<int>(0);

  static void avisarReporteGuardado() => reportesGuardados.value++;

  void _alGuardarseUnReporte() {
    if (!cerrado) _cargarReportes();
  }

  @override
  void dispose() {
    reportesGuardados.removeListener(_alGuardarseUnReporte);
    super.dispose();
  }

  /// Rangos que se pueden elegir. El backend acepta hasta 31 días.
  static const List<int> rangos = <int>[7, 14, 30];

  List<SensorEstado> _sensores = const <SensorEstado>[];
  SensorEstado? _seleccionado;
  int _dias = rangos.first;
  List<ReporteDiario> _reportes = const <ReporteDiario>[];

  List<SensorEstado> get sensores => _sensores;
  SensorEstado? get seleccionado => _seleccionado;
  int get dias => _dias;
  List<ReporteDiario> get reportes => _reportes;

  // ---------------------------------------------------- resumen del rango

  bool get hayReportes => _reportes.isNotEmpty;

  double? get minimaDelRango => hayReportes
      ? _reportes.map((r) => r.tempMin).reduce((a, b) => a < b ? a : b)
      : null;

  double? get maximaDelRango => hayReportes
      ? _reportes.map((r) => r.tempMax).reduce((a, b) => a > b ? a : b)
      : null;

  /// Promedio ponderado por lecturas: un día con 10 lecturas no pesa lo
  /// mismo que uno con 5 000.
  double? get promedioDelRango {
    final lecturas = lecturasDelRango;
    if (lecturas == 0) return null;
    final suma = _reportes.fold<double>(
      0,
      (total, r) => total + r.tempProm * r.lecturasValidas,
    );
    return suma / lecturas;
  }

  int get lecturasDelRango =>
      _reportes.fold<int>(0, (total, r) => total + r.lecturasValidas);

  int get alertasDelRango =>
      _reportes.fold<int>(0, (total, r) => total + r.alertas);

  int get diasConAlerta => _reportes.where((r) => r.alertas > 0).length;

  // ------------------------------------------------------------- acciones

  /// Carga los sensores (la primera vez) y los reportes del elegido.
  Future<void> cargar() async {
    final lista = await ejecutar(api.misSensores);
    if (lista == null) return;

    _sensores = lista;
    if (lista.isEmpty) {
      _seleccionado = null;
      _reportes = const <ReporteDiario>[];
      avisar();
      return;
    }
    // Conserva el sensor elegido si sigue existiendo.
    final actual = _seleccionado;
    _seleccionado = lista.firstWhere(
      (s) => s.id == actual?.id,
      orElse: () => lista.first,
    );
    avisar();
    await _cargarReportes();
  }

  Future<void> elegirSensor(SensorEstado sensor) async {
    if (sensor.id == _seleccionado?.id) return;
    _seleccionado = sensor;
    _reportes = const <ReporteDiario>[];
    avisar();
    await _cargarReportes();
  }

  Future<void> elegirDias(int dias) async {
    if (dias == _dias) return;
    _dias = dias;
    avisar();
    await _cargarReportes();
  }

  Future<void> _cargarReportes() async {
    final sensor = _seleccionado;
    if (sensor == null) return;
    final lista = await ejecutar(() => api.reportes(sensor.id, dias: _dias));
    // Si mientras tanto eligieron otro sensor, esta respuesta ya no sirve.
    if (lista == null || sensor.id != _seleccionado?.id) return;
    _reportes = lista;
    avisar();
  }
}
