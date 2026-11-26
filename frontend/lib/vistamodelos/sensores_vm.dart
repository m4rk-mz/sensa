import '../core/api_error.dart';
import '../core/config.dart';
import '../core/formato.dart';
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
  String _firma = '';
  final Set<String> _eliminando = <String>{};

  List<SensorEstado> get sensores => _sensores;

  /// Nombre del negocio para el encabezado (o todos, si es administrador).
  String get tituloNegocio =>
      esAdmin ? 'Todos los negocios' : (_tituloNegocio ?? 'Tu negocio');

  int get enAlerta => _sensores.where((s) => s.alerta).length;
  int get sinDatos => _sensores.where((s) => !s.alerta && !s.enLinea).length;
  int get normales => _sensores.length - enAlerta - sinDatos;
  bool get vacio => _sensores.isEmpty && !cargando && error == null;

  /// True mientras se borra ese sensor (para deshabilitar su botón).
  bool eliminandoA(String id) => _eliminando.contains(id);

  Future<void> cargar({bool silencioso = false}) async {
    final lista = await ejecutar(api.misSensores, silencioso: silencioso);
    if (lista != null) _ponerSensores(lista);

    if (!esAdmin && _tituloNegocio == null) {
      final negocios = await ejecutar(api.negocios, silencioso: true);
      if (negocios != null && negocios.isNotEmpty) {
        _tituloNegocio = negocios.first.nombre;
        avisar();
      }
    }
  }

  /// Solo redibuja si cambió algo de lo que se ve, incluido el "hace X"
  /// de cada tarjeta. Un refresco que trae lo mismo no cuesta nada.
  void _ponerSensores(List<SensorEstado> lista) {
    final firma = lista
        .map((s) => '${s.firma}|${Formato.haceCuanto(s.ultimaLecturaEn)}')
        .join(';');
    _sensores = lista;
    if (firma == _firma) return;
    _firma = firma;
    avisar();
  }

  /// Borra un sensor y todo lo suyo (solo administrador de plataforma).
  /// La vista confirma antes: esto no se puede deshacer.
  ///
  /// Devuelve null si salió bien o el mensaje de error. El error no se pone
  /// en la caja de arriba de la lista: es de esta acción, no de la carga, y
  /// se muestra en un aviso.
  Future<String?> eliminar(SensorEstado sensor) async {
    if (_eliminando.contains(sensor.id)) return null;
    _eliminando.add(sensor.id);
    avisar();
    try {
      await api.eliminarSensor(sensor.id);
    } on ApiError catch (e) {
      return e.mensaje;
    } catch (e) {
      return 'No se pudo eliminar el sensor: $e';
    } finally {
      _eliminando.remove(sensor.id);
      avisar();
    }
    _ponerSensores(
      _sensores.where((s) => s.id != sensor.id).toList(growable: false),
    );
    await cargar(silencioso: true);
    return null;
  }

  @override
  Future<void> refrescar() => cargar(silencioso: true);

  /// Refresca mientras la pantalla está al frente. Se detiene al abrir el
  /// detalle de un sensor y cuando la app pasa a segundo plano.
  void iniciar() => iniciarRefresco(Config.refrescoLista);
}
