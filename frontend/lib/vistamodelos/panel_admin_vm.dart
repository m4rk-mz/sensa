import '../modelos/panel.dart';
import '../servicios/sensa_api.dart';
import 'base_vm.dart';

/// VistaModelo del panel del administrador: indicadores, tabla y gráfica.
///
/// Todo viene de GET /admin/stats/negocios, que solo cuenta lecturas
/// válidas e informa cuántas descartó.
class PanelAdminVm extends BaseVm {
  PanelAdminVm(this.api);

  final SensaApi api;

  PanelAdmin? _panel;
  String? _aviso;

  PanelAdmin? get panel => _panel;

  /// Mensaje de resultado de "generar reportes" (demo).
  String? get aviso => _aviso;

  List<FilaPanelNegocio> get tabla => _panel?.tabla ?? const <FilaPanelNegocio>[];
  List<PuntoGrafica> get grafica =>
      _panel?.graficaTempPromedio ?? const <PuntoGrafica>[];

  /// Valor máximo de la gráfica, redondeado hacia arriba, para escalar las
  /// barras desde cero.
  double get maximoGrafica {
    if (grafica.isEmpty) return 1;
    final mayor = grafica.map((p) => p.valor).reduce((a, b) => a > b ? a : b);
    return mayor <= 0 ? 1 : mayor;
  }

  Future<void> cargar({bool silencioso = false}) async {
    final datos = await ejecutar(api.panel, silencioso: silencioso);
    if (datos != null) {
      _panel = datos;
      avisar();
    }
  }

  /// Dispara la tarea del reporte diario sin esperar la medianoche.
  Future<void> generarReportes() async {
    _aviso = null;
    final reportes = await ejecutar(() => api.generarReportes());
    if (reportes == null) return;

    _aviso = reportes.isEmpty
        ? 'No había lecturas válidas para generar reportes.'
        : 'Se generaron ${reportes.length} reporte(s).';
    avisar();
    await cargar(silencioso: true);
  }

  void limpiarAviso() {
    _aviso = null;
    avisar();
  }
}
