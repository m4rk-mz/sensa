import '../modelos/negocio.dart';
import '../modelos/usuario.dart';
import '../servicios/sensa_api.dart';
import 'base_vm.dart';

/// VistaModelo de usuarios (solo administrador): lista, filtro por negocio y
/// promoción a administrador.
///
/// La app pide confirmación antes de promover; el cambio lo hace el backend
/// y queda en la BD, así que persiste al volver a iniciar sesión.
class UsuariosVm extends BaseVm {
  UsuariosVm(this.api);

  final SensaApi api;

  List<Usuario> _usuarios = const <Usuario>[];
  List<Negocio> _negocios = const <Negocio>[];
  String? _filtroNegocio;
  String? _aviso;

  List<Usuario> get usuarios => _usuarios;
  List<Negocio> get negocios => _negocios;
  String? get filtroNegocio => _filtroNegocio;
  String? get aviso => _aviso;

  String nombreDeNegocio(String? businessId) {
    if (businessId == null) return 'Plataforma';
    for (final negocio in _negocios) {
      if (negocio.id == businessId) return negocio.nombre;
    }
    return 'Negocio sin nombre';
  }

  Future<void> cargar({bool silencioso = false}) async {
    final resultado = await ejecutar(
      () async {
        final negocios = await api.negocios();
        final usuarios = await api.usuarios(businessId: _filtroNegocio);
        return <String, Object?>{'negocios': negocios, 'usuarios': usuarios};
      },
      silencioso: silencioso,
    );
    if (resultado == null) return;

    _negocios = (resultado['negocios'] as List<Negocio>?) ?? const <Negocio>[];
    _usuarios = (resultado['usuarios'] as List<Usuario>?) ?? const <Usuario>[];
    avisar();
  }

  Future<void> filtrarPor(String? businessId) async {
    _filtroNegocio = businessId;
    avisar();
    await cargar();
  }

  /// Promueve a un usuario. La vista ya mostró el diálogo de confirmación.
  Future<bool> promover(Usuario usuario) async {
    _aviso = null;
    final promovido = await ejecutar(() => api.promover(usuario.id));
    if (promovido == null) return false;

    _aviso = '${promovido.nombre} ya es administrador de la plataforma.';
    await cargar(silencioso: true);
    return true;
  }

  void limpiarAviso() {
    _aviso = null;
    avisar();
  }
}
