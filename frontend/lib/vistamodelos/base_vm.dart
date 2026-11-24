import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/api_error.dart';

/// Base de los VistaModelo (la VM de MVVM).
///
/// Guarda el estado que la vista necesita para decidir qué pintar: si está
/// cargando y si hay un error que mostrar. La vista no habla con la API:
/// solo llama métodos de su VistaModelo y escucha los cambios.
abstract class BaseVm extends ChangeNotifier {
  bool _cargando = false;
  String? _error;
  Map<String, String> _erroresPorCampo = const <String, String>{};
  bool _dispuesto = false;

  bool get cargando => _cargando;
  String? get error => _error;
  Map<String, String> get erroresPorCampo => _erroresPorCampo;

  String? errorDeCampo(String campo) => _erroresPorCampo[campo];

  @override
  void dispose() {
    _dispuesto = true;
    super.dispose();
  }

  /// True cuando la pantalla ya se cerró y el VistaModelo se desechó.
  @protected
  bool get cerrado => _dispuesto;

  /// notifyListeners seguro: si la pantalla ya se cerró, no hace nada.
  @protected
  void avisar() {
    if (!_dispuesto) notifyListeners();
  }

  @protected
  void ponerError(String? mensaje, {Map<String, String>? porCampo}) {
    _error = mensaje;
    _erroresPorCampo = porCampo ?? const <String, String>{};
    avisar();
  }

  void limpiarError() => ponerError(null);

  /// Corre una llamada a la API cuidando el estado de carga y los errores.
  ///
  /// Con `silencioso: true` no prende el indicador de carga: se usa en los
  /// refrescos automáticos, para que la pantalla no parpadee.
  @protected
  Future<T?> ejecutar<T>(
    Future<T> Function() accion, {
    bool silencioso = false,
  }) async {
    if (!silencioso) {
      _cargando = true;
      _error = null;
      _erroresPorCampo = const <String, String>{};
      avisar();
    }
    try {
      final resultado = await accion();
      _error = null;
      _erroresPorCampo = const <String, String>{};
      return resultado;
    } on ApiError catch (e) {
      _error = e.mensaje;
      _erroresPorCampo = e.erroresPorCampo;
      return null;
    } catch (e) {
      _error = 'Algo salió mal: $e';
      return null;
    } finally {
      _cargando = false;
      avisar();
    }
  }
}

/// VistaModelo que se refresca solo cada cierto tiempo.
///
/// El refresco se detiene cuando la app pasa a segundo plano y se reanuda
/// al volver: sin esto la app seguía pidiendo datos con la pantalla
/// apagada, que es trabajo de red y batería tirados a la basura, y además
/// llenaba de peticiones al backend.
abstract class VmConRefresco extends BaseVm with WidgetsBindingObserver {
  Timer? _temporizador;
  Duration? _cada;
  bool _activo = false;
  bool _observando = false;
  bool _enPrimerPlano = true;

  /// Lo que se vuelve a pedir en cada vuelta.
  @protected
  Future<void> refrescar();

  void iniciarRefresco(Duration cada) {
    // Si la pantalla ya se cerró (por ejemplo, si la sesión caducó mientras
    // se veía el detalle) no se vuelve a armar nada.
    if (cerrado) return;
    _cada = cada;
    _activo = true;
    if (!_observando) {
      WidgetsBinding.instance.addObserver(this);
      _observando = true;
    }
    _armar();
  }

  void detenerRefresco() {
    _activo = false;
    _temporizador?.cancel();
    _temporizador = null;
    if (_observando) {
      WidgetsBinding.instance.removeObserver(this);
      _observando = false;
    }
  }

  void _armar() {
    _temporizador?.cancel();
    _temporizador = null;
    final cada = _cada;
    if (!_activo || !_enPrimerPlano || cada == null) return;
    _temporizador = Timer.periodic(cada, (_) {
      if (!cerrado) refrescar();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    final estabaAdelante = _enPrimerPlano;
    _enPrimerPlano = estado == AppLifecycleState.resumed;
    _armar();
    // Al volver, una lectura de inmediato para no mostrar datos viejos.
    if (_enPrimerPlano && !estabaAdelante && _activo && !cerrado) refrescar();
  }

  @override
  void dispose() {
    detenerRefresco();
    super.dispose();
  }
}
