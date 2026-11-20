import 'dart:async';

import '../core/config.dart';
import '../modelos/sensor.dart';
import '../servicios/sensa_api.dart';
import 'base_vm.dart';

/// VistaModelo de "Mis sensores".
class SensoresVm extends BaseVm {
  SensoresVm(this.api, {this.esAdmin = false});

  final SensaApi api;

  /// El administrador de plataforma ve los sensores de todos los negocios.
  final bool esAdmin;

  List<SensorEstado> _sensores = const <SensorEstado>[];
  String? _tituloNegocio;
  Timer? _temporizador;

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

  /// Refresca solo mientras la pantalla está visible.
  void iniciarRefresco() {
    _temporizador?.cancel();
    _temporizador = Timer.periodic(
      Config.refrescoLista,
      (_) => cargar(silencioso: true),
    );
  }

  void detenerRefresco() {
    _temporizador?.cancel();
    _temporizador = null;
  }

  @override
  void dispose() {
    detenerRefresco();
    super.dispose();
  }
}
