import '../core/api_cliente.dart';
import '../core/json.dart';
import '../modelos/comando.dart';
import '../modelos/lectura.dart';
import '../modelos/negocio.dart';
import '../modelos/panel.dart';
import '../modelos/reporte.dart';
import '../modelos/sensor.dart';
import '../modelos/usuario.dart';

/// Todas las llamadas a la API de Sensa, una por endpoint del contrato del
/// backend. No tiene estado: el token lo guarda el [ApiCliente].
class SensaApi {
  SensaApi(this.cliente);

  final ApiCliente cliente;

  // ---------------------------------------------------------------- sesión
  Future<Sesion> login({required String email, required String password}) async {
    final datos = await cliente.post('/auth/login', cuerpo: {
      'email': email,
      'password': password,
    });
    return Sesion.desdeJson(J.mapa(datos));
  }

  Future<Usuario> yo() async {
    final datos = await cliente.get('/me');
    return Usuario.desdeJson(J.mapa(datos));
  }

  Future<void> cambiarPassword({
    required String actual,
    required String nueva,
  }) async {
    await cliente.post('/auth/password', cuerpo: {
      'password_actual': actual,
      'password_nueva': nueva,
    });
  }

  // -------------------------------------------------------------- sensores
  Future<List<SensorEstado>> misSensores() async {
    final datos = await cliente.get('/devices');
    return J
        .lista(datos)
        .map(SensorEstado.desdeJson)
        .toList(growable: false);
  }

  Future<SensorEstado> sensor(String deviceId) async {
    final datos = await cliente.get('/devices/$deviceId');
    return SensorEstado.desdeJson(J.mapa(datos));
  }

  /// Cambia nombre o umbral. `activo` solo lo acepta el backend si quien
  /// llama es administrador de plataforma.
  Future<Sensor> editarSensor(
    String deviceId, {
    String? nombre,
    double? umbralC,
    bool? activo,
  }) async {
    final cuerpo = <String, dynamic>{};
    if (nombre != null) cuerpo['nombre'] = nombre;
    if (umbralC != null) cuerpo['umbral_c'] = umbralC;
    if (activo != null) cuerpo['activo'] = activo;

    final datos = await cliente.patch('/devices/$deviceId', cuerpo: cuerpo);
    return Sensor.desdeJson(J.mapa(datos));
  }

  Future<List<Lectura>> lecturas(
    String deviceId, {
    int horas = 24,
    int limite = 200,
  }) async {
    final datos = await cliente.get(
      '/devices/$deviceId/readings',
      query: {'horas': horas, 'limite': limite},
    );
    return J.lista(datos).map(Lectura.desdeJson).toList(growable: false);
  }

  // ------------------------------------------------------- LED (actuador)
  Future<Comando> enviarComando(String deviceId, String accion) async {
    final datos = await cliente.post(
      '/devices/$deviceId/command',
      cuerpo: {'accion': accion},
    );
    return Comando.desdeJson(J.mapa(datos));
  }

  /// Último comando del sensor, para mostrar su estado en la app.
  Future<Comando?> ultimoComando(String deviceId) async {
    final datos = await cliente.get('/devices/$deviceId/commands');
    final lista = J.lista(datos);
    if (lista.isEmpty) return null;
    return Comando.desdeJson(lista.first);
  }

  // -------------------------------------------------------------- reportes
  Future<ReporteDelDia> reporteDelDia(String deviceId, {DateTime? fecha}) async {
    final datos = await cliente.get(
      '/devices/$deviceId/reporte-diario',
      query: fecha == null ? null : {'fecha': _soloFecha(fecha)},
    );
    return ReporteDelDia.desdeJson(J.mapa(datos));
  }

  Future<List<ReporteDiario>> reportes(String deviceId, {int dias = 7}) async {
    final datos = await cliente.get(
      '/devices/$deviceId/reportes',
      query: {'dias': dias},
    );
    return J.lista(datos).map(ReporteDiario.desdeJson).toList(growable: false);
  }

  // -------------------------------------------------------------- negocios
  Future<List<Negocio>> negocios() async {
    final datos = await cliente.get('/businesses');
    return J.lista(datos).map(Negocio.desdeJson).toList(growable: false);
  }

  Future<Negocio> negocio(String businessId) async {
    final datos = await cliente.get('/businesses/$businessId');
    return Negocio.desdeJson(J.mapa(datos));
  }

  /// Alta de negocio. Opcionalmente crea de una vez su primer usuario.
  Future<Negocio> crearNegocio({
    required String nombre,
    String? usuarioNombre,
    String? usuarioEmail,
    String? usuarioPassword,
  }) async {
    final cuerpo = <String, dynamic>{'nombre': nombre};
    if (usuarioNombre != null && usuarioEmail != null && usuarioPassword != null) {
      cuerpo['usuario_inicial'] = {
        'nombre': usuarioNombre,
        'email': usuarioEmail,
        'password': usuarioPassword,
      };
    }
    final datos = await cliente.post('/businesses', cuerpo: cuerpo);
    return Negocio.desdeJson(J.mapa(datos));
  }

  Future<List<Usuario>> usuariosDeNegocio(String businessId) async {
    final datos = await cliente.get('/businesses/$businessId/users');
    return J.lista(datos).map(Usuario.desdeJson).toList(growable: false);
  }

  /// Alta de usuario de negocio. No se manda `rol`: lo fija el backend.
  Future<Usuario> crearUsuarioDeNegocio(
    String businessId, {
    required String nombre,
    required String email,
    required String password,
  }) async {
    final datos = await cliente.post(
      '/businesses/$businessId/users',
      cuerpo: {'nombre': nombre, 'email': email, 'password': password},
    );
    return Usuario.desdeJson(J.mapa(datos));
  }

  Future<List<Sensor>> sensoresDeNegocio(String businessId) async {
    final datos = await cliente.get('/businesses/$businessId/devices');
    return J.lista(datos).map(Sensor.desdeJson).toList(growable: false);
  }

  /// Registra un nodo. El token viene en la respuesta una sola vez.
  Future<SensorRegistrado> registrarSensor(
    String businessId, {
    required String nombre,
    required double umbralC,
  }) async {
    final datos = await cliente.post(
      '/businesses/$businessId/devices',
      cuerpo: {'nombre': nombre, 'umbral_c': umbralC},
    );
    return SensorRegistrado.desdeJson(J.mapa(datos));
  }

  // --------------------------------------------------------- administración
  Future<List<Usuario>> usuarios({String? businessId}) async {
    final datos = await cliente.get(
      '/admin/users',
      query: businessId == null ? null : {'business_id': businessId},
    );
    return J.lista(datos).map(Usuario.desdeJson).toList(growable: false);
  }

  Future<Usuario> promover(String userId) async {
    final datos = await cliente.post('/admin/users/$userId/promover');
    return Usuario.desdeJson(J.mapa(datos));
  }

  Future<PanelAdmin> panel() async {
    final datos = await cliente.get('/admin/stats/negocios');
    return PanelAdmin.desdeJson(J.mapa(datos));
  }

  Future<List<PuntoGrafica>> graficaTempPromedio() async {
    final datos = await cliente.get('/admin/stats/temp-promedio-por-negocio');
    return J.lista(datos).map(PuntoGrafica.desdeJson).toList(growable: false);
  }

  /// Dispara la tarea del reporte diario a mano (útil en la demo).
  Future<List<ReporteDiario>> generarReportes({DateTime? fecha}) async {
    final datos = await cliente.post(
      '/admin/reportes/generar',
      query: fecha == null ? null : {'fecha': _soloFecha(fecha)},
    );
    return J.lista(datos).map(ReporteDiario.desdeJson).toList(growable: false);
  }

  static String _soloFecha(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}
