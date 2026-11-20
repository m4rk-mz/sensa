import '../core/almacen_sesion.dart';
import '../core/api_cliente.dart';
import '../core/api_error.dart';
import '../modelos/usuario.dart';
import '../servicios/sensa_api.dart';
import 'base_vm.dart';

enum EstadoSesion { comprobando, sinSesion, conSesion }

/// VistaModelo de la sesión: quién está dentro y con qué rol.
///
/// El rol que manda es el del backend. Esta clase solo lo guarda para
/// decidir qué pantallas mostrar; cada endpoint vuelve a revisar permisos.
class SesionVm extends BaseVm {
  SesionVm({
    required this.cliente,
    required this.api,
    AlmacenSesion? almacen,
  }) : almacen = almacen ?? AlmacenSesion() {
    cliente.alPerderSesion = _alPerderSesion;
  }

  final ApiCliente cliente;
  final SensaApi api;
  final AlmacenSesion almacen;

  EstadoSesion _estado = EstadoSesion.comprobando;
  Usuario? _usuario;
  String? _avisoSesion;

  EstadoSesion get estado => _estado;
  Usuario? get usuario => _usuario;
  bool get esAdmin => _usuario?.esAdmin ?? false;

  /// Mensaje para mostrar en el login cuando la sesión se cayó sola.
  String? get avisoSesion => _avisoSesion;

  /// Al abrir la app: si hay token guardado, se revalida con /me.
  Future<void> restaurar() async {
    final token = await almacen.token();
    if (token == null) {
      _estado = EstadoSesion.sinSesion;
      avisar();
      return;
    }

    cliente.usarToken(token);
    try {
      _usuario = await api.yo();
      _estado = EstadoSesion.conSesion;
    } on ApiError {
      // Token vencido o usuario dado de baja: se pide entrar otra vez.
      await almacen.limpiar();
      cliente.usarToken(null);
      _usuario = null;
      _estado = EstadoSesion.sinSesion;
    }
    avisar();
  }

  /// Devuelve true si entró. El error queda en [error] para la vista.
  Future<bool> entrar({required String email, required String password}) async {
    _avisoSesion = null;
    final sesion = await ejecutar(
      () => api.login(email: email, password: password),
    );
    if (sesion == null) return false;

    cliente.usarToken(sesion.token);
    await almacen.guardar(
      token: sesion.token,
      usuario: sesion.usuario.aJson(),
      expiraEn: sesion.expiraEn,
    );
    _usuario = sesion.usuario;
    _estado = EstadoSesion.conSesion;
    avisar();
    return true;
  }

  Future<void> salir() async {
    await almacen.limpiar();
    cliente.usarToken(null);
    _usuario = null;
    _avisoSesion = null;
    _estado = EstadoSesion.sinSesion;
    avisar();
  }

  /// Relee el rol de la BD. Sirve después de una promoción.
  Future<void> refrescarUsuario() async {
    final actualizado = await ejecutar(() => api.yo(), silencioso: true);
    if (actualizado != null) {
      _usuario = actualizado;
      avisar();
    }
  }

  Future<bool> cambiarPassword({
    required String actual,
    required String nueva,
  }) async {
    final hecho = await ejecutar(
      () => api.cambiarPassword(actual: actual, nueva: nueva).then((_) => true),
    );
    return hecho ?? false;
  }

  void _alPerderSesion() {
    if (_estado != EstadoSesion.conSesion) return;
    _avisoSesion = 'Tu sesión expiró. Vuelve a iniciar sesión.';
    _usuario = null;
    _estado = EstadoSesion.sinSesion;
    cliente.usarToken(null);
    almacen.limpiar();
    avisar();
  }
}
