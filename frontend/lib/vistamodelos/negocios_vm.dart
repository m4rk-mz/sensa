import '../core/validaciones.dart';
import '../modelos/negocio.dart';
import '../modelos/sensor.dart';
import '../servicios/sensa_api.dart';
import 'base_vm.dart';

/// VistaModelo de negocios: lista, alta de negocio y registro de sensores.
/// Todo esto es solo del administrador de plataforma.
class NegociosVm extends BaseVm {
  NegociosVm(this.api);

  final SensaApi api;

  List<Negocio> _negocios = const <Negocio>[];
  SensorRegistrado? _sensorRecienRegistrado;

  List<Negocio> get negocios => _negocios;

  /// Sensor que se acaba de registrar: su token se muestra una sola vez.
  SensorRegistrado? get sensorRecienRegistrado => _sensorRecienRegistrado;

  Future<void> cargar() async {
    final lista = await ejecutar(api.negocios);
    if (lista != null) {
      _negocios = lista;
      avisar();
    }
  }

  /// Alta de negocio, con o sin primer usuario.
  ///
  /// Valida en la app lo mismo que el backend: nombre, correo y contraseña
  /// con al menos una letra y un número.
  Future<bool> crearNegocio({
    required String nombre,
    String? usuarioNombre,
    String? usuarioEmail,
    String? usuarioPassword,
  }) async {
    final conUsuario = (usuarioEmail ?? '').trim().isNotEmpty ||
        (usuarioPassword ?? '').isNotEmpty ||
        (usuarioNombre ?? '').trim().isNotEmpty;

    final problemas = <String, String>{};
    final problemaNombre = Validaciones.nombre(nombre);
    if (problemaNombre != null) problemas['nombre'] = problemaNombre;

    if (conUsuario) {
      final pNombre = Validaciones.nombre(usuarioNombre);
      if (pNombre != null) problemas['usuario_nombre'] = pNombre;
      final pEmail = Validaciones.correo(usuarioEmail);
      if (pEmail != null) problemas['email'] = pEmail;
      final pPassword = Validaciones.passwordNueva(usuarioPassword);
      if (pPassword != null) problemas['password'] = pPassword;
    }

    if (problemas.isNotEmpty) {
      ponerError('Revisa los datos marcados.', porCampo: problemas);
      return false;
    }

    final negocio = await ejecutar(
      () => api.crearNegocio(
        nombre: nombre.trim(),
        usuarioNombre: conUsuario ? usuarioNombre!.trim() : null,
        usuarioEmail: conUsuario ? usuarioEmail!.trim() : null,
        usuarioPassword: conUsuario ? usuarioPassword : null,
      ),
    );
    if (negocio == null) return false;

    await cargar();
    return true;
  }

  Future<List<Sensor>> sensoresDe(String businessId) async {
    final lista = await ejecutar(
      () => api.sensoresDeNegocio(businessId),
      silencioso: true,
    );
    return lista ?? const <Sensor>[];
  }

  /// Registra un nodo en un negocio. El token solo se ve esta vez.
  Future<bool> registrarSensor({
    required String businessId,
    required String nombre,
    required String umbral,
  }) async {
    final problemas = <String, String>{};
    final pNombre = Validaciones.nombre(nombre);
    if (pNombre != null) problemas['nombre'] = pNombre;
    final pUmbral = Validaciones.umbral(umbral);
    if (pUmbral != null) problemas['umbral_c'] = pUmbral;

    if (problemas.isNotEmpty) {
      ponerError('Revisa los datos marcados.', porCampo: problemas);
      return false;
    }

    final registrado = await ejecutar(
      () => api.registrarSensor(
        businessId,
        nombre: nombre.trim(),
        umbralC: Validaciones.umbralComoNumero(umbral)!,
      ),
    );
    if (registrado == null) return false;

    _sensorRecienRegistrado = registrado;
    avisar();
    return true;
  }

  void olvidarToken() {
    _sensorRecienRegistrado = null;
    avisar();
  }
}
