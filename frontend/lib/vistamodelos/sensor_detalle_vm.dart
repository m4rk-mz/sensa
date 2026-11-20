import 'dart:async';

import '../core/config.dart';
import '../core/validaciones.dart';
import '../modelos/comando.dart';
import '../modelos/lineas_lcd.dart';
import '../modelos/sensor.dart';
import '../servicios/sensa_api.dart';
import 'base_vm.dart';

/// VistaModelo del detalle de un sensor: lectura, lo que muestra la LCD del
/// nodo, control del LED y umbral.
class SensorDetalleVm extends BaseVm {
  SensorDetalleVm({required this.api, required this.deviceId});

  final SensaApi api;
  final String deviceId;

  SensorEstado? _estado;
  Comando? _ultimoComando;
  bool _enviandoComando = false;
  Timer? _temporizador;

  SensorEstado? get estado => _estado;
  Comando? get ultimoComando => _ultimoComando;
  bool get enviandoComando => _enviandoComando;

  /// Las pantallas que el nodo muestra en su LCD 1602. En alerta son dos y
  /// el nodo las alterna cada 3 s; fuera de alerta es una sola.
  List<VistaLcd> get vistasLcd =>
      _estado == null ? const <VistaLcd>[] : LineasLcd.de(_estado!);

  bool get alternaLcd => vistasLcd.length > 1;

  Future<void> cargar({bool silencioso = false}) async {
    final resultado = await ejecutar(
      () async {
        final estado = await api.sensor(deviceId);
        final comando = await api.ultimoComando(deviceId);
        return <String, Object?>{'estado': estado, 'comando': comando};
      },
      silencioso: silencioso,
    );
    if (resultado != null) {
      _estado = resultado['estado'] as SensorEstado?;
      _ultimoComando = resultado['comando'] as Comando?;
      avisar();
    }
  }

  /// Pide prender, apagar o volver a automático.
  ///
  /// Después de pedirlo se refresca enseguida y otra vez a los 3 s, que es
  /// lo que tarda el nodo en recoger el comando y confirmarlo.
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
    Timer(const Duration(seconds: 3), () => cargar(silencioso: true));
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
    detenerRefresco();
    super.dispose();
  }
}
