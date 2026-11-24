import 'dart:async';

import '../core/config.dart';
import '../core/validaciones.dart';
import '../modelos/comando.dart';
import '../modelos/sensor.dart';
import '../servicios/sensa_api.dart';
import 'base_vm.dart';

/// VistaModelo del detalle de un sensor: lectura en vivo, acciones en el
/// nodo (alerta y prueba de LEDs) y umbral.
///
/// El LED ya no se controla a mano desde la app: el nodo trabaja siempre en
/// automático con el umbral del sensor.
class SensorDetalleVm extends VmConRefresco {
  SensorDetalleVm({required this.api, required this.deviceId});

  final SensaApi api;
  final String deviceId;

  SensorEstado? _estado;
  Comando? _ultimoComando;
  String? _accionEnCurso;
  bool _yaRegreseAAutomatico = false;

  SensorEstado? get estado => _estado;
  Comando? get ultimoComando => _ultimoComando;

  /// Qué acción se está mandando ahora mismo, si hay alguna.
  String? get accionEnCurso => _accionEnCurso;
  bool get enviandoAccion => _accionEnCurso != null;

  @override
  Future<void> refrescar() => cargar(silencioso: true);

  /// Pide el estado del sensor. El último comando solo se pide cuando hace
  /// falta: en la primera carga y después de mandar una acción. Así el
  /// refresco automático es una sola petición y no dos.
  Future<void> cargar({bool silencioso = false, bool conComando = false}) async {
    final estado = await ejecutar(
      () => api.sensor(deviceId),
      silencioso: silencioso,
    );
    if (estado != null) {
      _estado = estado;
      avisar();
      _regresarAAutomaticoSiHaceFalta(estado);
    }
    if (conComando) await _cargarComando();
  }

  Future<void> _cargarComando() async {
    if (cerrado) return;
    final comando = await ejecutar(
      () => api.ultimoComando(deviceId),
      silencioso: true,
    );
    if (comando != null) {
      _ultimoComando = comando;
      avisar();
    }
  }

  /// Si el sensor quedó en modo manual de una versión anterior de la app,
  /// se le manda `auto` una vez para que vuelva a decidir por el umbral.
  void _regresarAAutomaticoSiHaceFalta(SensorEstado estado) {
    if (_yaRegreseAAutomatico || !estado.esManual) return;
    _yaRegreseAAutomatico = true;
    unawaited(
      ejecutar(
        () => api.enviarComando(deviceId, AccionLed.automatico),
        silencioso: true,
      ).then((_) {
        if (!cerrado) cargar(silencioso: true);
      }),
    );
  }

  /// Manda una acción de un momento al nodo: alerta o prueba de LEDs.
  Future<bool> enviarAccion(String accion) async {
    if (_accionEnCurso != null) return false;
    _accionEnCurso = accion;
    avisar();

    final comando = await ejecutar(
      () => api.enviarComando(deviceId, accion),
      silencioso: true,
    );

    _accionEnCurso = null;
    if (comando == null) {
      avisar();
      return false;
    }

    _ultimoComando = comando;
    avisar();
    _seguirComando();
    return true;
  }

  /// El nodo consulta cada segundo y confirma al terminar el efecto, así
  /// que se vuelve a preguntar un par de veces en los siguientes segundos.
  void _seguirComando() {
    const esperas = [
      Duration(seconds: 1),
      Duration(seconds: 3),
      Duration(seconds: 5),
    ];
    for (final espera in esperas) {
      Timer(espera, () {
        if (!cerrado) _cargarComando();
      });
    }
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

  void iniciar() {
    cargar(conComando: true);
    iniciarRefresco(Config.refrescoDetalle);
  }
}
