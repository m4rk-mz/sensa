import 'dart:async';

import '../core/config.dart';
import '../core/validaciones.dart';
import '../modelos/comando.dart';
import '../modelos/sensor.dart';
import '../servicios/sensa_api.dart';
import 'base_vm.dart';

/// VistaModelo del detalle de un sensor: lectura, control del LED,
/// acciones del nodo (alerta y prueba de LEDs) y umbral.
class SensorDetalleVm extends BaseVm {
  SensorDetalleVm({required this.api, required this.deviceId});

  final SensaApi api;
  final String deviceId;

  SensorEstado? _estado;
  Comando? _ultimoComando;
  bool _enviandoComando = false;
  Timer? _temporizador;
  bool _cerrado = false;

  SensorEstado? get estado => _estado;
  Comando? get ultimoComando => _ultimoComando;
  bool get enviandoComando => _enviandoComando;

  Future<void> cargar({bool silencioso = false}) async {
    final resultado = await ejecutar(
      () async {
        // Las dos consultas a la vez: el detalle se refresca cada 2 s.
        final resultados = await Future.wait<Object?>([
          api.sensor(deviceId),
          api.ultimoComando(deviceId),
        ]);
        return <String, Object?>{
          'estado': resultados[0],
          'comando': resultados[1],
        };
      },
      silencioso: silencioso,
    );
    if (resultado != null) {
      _estado = resultado['estado'] as SensorEstado?;
      _ultimoComando = resultado['comando'] as Comando?;
      avisar();
    }
  }

  /// Pide prender, apagar, volver a automático, mandar una alerta o probar
  /// los LEDs.
  ///
  /// Después de pedirlo se refresca enseguida, al segundo y a los 3 s: el
  /// nodo consulta cada segundo y la alerta o la prueba se confirman al
  /// terminar (unos 2 s).
  Future<bool> enviarComando(String accion) async {
    _enviandoComando = true;
    avisar();

    final comando = await ejecutar(
      () => api.enviarComando(deviceId, accion),
      silencioso: true,
    );

    _enviandoComando = false;
    if (comando == null) {
      avisar();
      return false;
    }

    _ultimoComando = comando;
    avisar();
    await cargar(silencioso: true);
    for (final espera in const [Duration(seconds: 1), Duration(seconds: 3)]) {
      Timer(espera, () {
        if (!_cerrado) cargar(silencioso: true);
      });
    }
    return true;
  }

  /// Cambia el umbral de alerta. La validación es la misma del backend.
  Future<bool> cambiarUmbral(String texto) async {
    final problema = Validaciones.umbral(texto);
    if (problema != null) {
      ponerError(problema, porCampo: {'umbral_c': problema});
      return false;
    }
    final valor = Validaciones.umbralComoNumero(texto);
    if (valor == null) return false;

    final sensor = await ejecutar(
      () => api.editarSensor(deviceId, umbralC: valor),
    );
    if (sensor == null) return false;

    await cargar(silencioso: true);
    return true;
  }

  Future<bool> cambiarNombre(String texto) async {
    final problema = Validaciones.nombre(texto);
    if (problema != null) {
      ponerError(problema, porCampo: {'nombre': problema});
      return false;
    }
    final sensor = await ejecutar(
      () => api.editarSensor(deviceId, nombre: texto.trim()),
    );
    if (sensor == null) return false;

    await cargar(silencioso: true);
    return true;
  }

  void iniciarRefresco() {
    _temporizador?.cancel();
    _temporizador = Timer.periodic(
      Config.refrescoDetalle,
      (_) => cargar(silencioso: true),
    );
  }

  void detenerRefresco() {
    _temporizador?.cancel();
    _temporizador = null;
  }

  @override
  void dispose() {
    _cerrado = true;
    detenerRefresco();
    super.dispose();
  }
}
