import '../core/config.dart';
import '../modelos/sensor.dart';
import '../servicios/sensa_api.dart';
import 'base_vm.dart';

/// VistaModelo de "Mis sensores".
class SensoresVm extends VmConRefresco {
  SensoresVm(this.api, {this.esAdmin = false});

  final SensaApi api;

  /// El administrador de plataforma ve los sensores de todos los negocios.
  final bool esAdmin;

  List<SensorEstado> _sensores = const <SensorEstado>[];
  String? _tituloNegocio;

  List<SensorEstado> get sensores => _sensores;

  /// Nombre del negocio para el encabezado (o todos, si es administrador).
  String get tituloNegocio =>
      esAdmin ? 'Todos los negocios' : (_tituloNegocio ?? 'Tu negocio');

  int get enAlerta => _sensores.where((s) => s.alerta).length;
  int get sinDatos => _sensores.where((s) => !s.enLinea).length;
  bool get vacio => _sensores.isEmpty && !cargando && error == null;

  Future<void> cargar({bool silencioso = false}) async {
    final lista = await ejecutar(api.misSensores, silencioso: silencioso);
    if (lista != null) {
      _sensores = lista;
      avisar();
    }
    if (!esAdmin && _tituloNegocio == null) {
      final negocios = await ejecutar(api.negocios, silencioso: true);
      if (negocios != null && negocios.isNotEmpty) {
        _tituloNegocio = negocios.first.nombre;
        avisar();
      }
    }
  }

  /// Borra un sensor y todo lo suyo (solo administrador de plataforma).
  /// La vista confirma antes: esto no se puede deshacer.
  Future<bool> eliminar(SensorEstado sensor) async {
    final hecho = await ejecutar(
      () => api.eliminarSensor(sensor.id).then((_) => true),
    );
    if (hecho != true) return false;
    _sensores = _sensores.where((s) => s.id != sensor.id).toList(growable: false);
    avisar();
    await cargar(silencioso: true);
    return true;
  }

  @override
  Future<void> refrescar() => cargar(silencioso: true);

  /// Refresca mientras la pantalla está al frente. Se detiene al abrir el
  /// detalle de un sensor y cuando la app pasa a segundo plano.
  void iniciar() => iniciarRefresco(Config.refrescoLista);
}
