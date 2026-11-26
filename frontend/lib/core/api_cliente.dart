import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_error.dart';

/// Cliente HTTP de la API de Sensa.
///
/// Se encarga de tres cosas y nada más: poner el encabezado
/// `Authorization: Bearer <jwt>`, convertir la respuesta a JSON y convertir
/// cualquier falla en un [ApiError]. Las reglas de negocio viven en el
/// backend; los VistaModelo solo leen lo que devuelve.
class ApiCliente {
  ApiCliente({required this.baseUrl, http.Client? cliente})
      : _cliente = cliente ?? http.Client();

  final String baseUrl;
  final http.Client _cliente;

  String? _token;

  /// Se llama cuando el backend responde 401: la sesión caducó o el usuario
  /// fue dado de baja. La app lo usa para regresar al login.
  void Function()? alPerderSesion;

  static const Duration _tiempoLimite = Duration(seconds: 15);

  void usarToken(String? token) => _token = token;

  bool get tieneToken => _token != null;

  Future<dynamic> get(String ruta, {Map<String, dynamic>? query}) =>
      _enviar('GET', ruta, query: query);

  Future<dynamic> post(String ruta, {Object? cuerpo, Map<String, dynamic>? query}) =>
      _enviar('POST', ruta, cuerpo: cuerpo, query: query);

  Future<dynamic> patch(String ruta, {Object? cuerpo}) =>
      _enviar('PATCH', ruta, cuerpo: cuerpo);

  Future<dynamic> delete(String ruta) => _enviar('DELETE', ruta);

  Future<dynamic> _enviar(
    String metodo,
    String ruta, {
    Object? cuerpo,
    Map<String, dynamic>? query,
  }) async {
    final uri = _uri(ruta, query);
    final encabezados = <String, String>{
      'Accept': 'application/json',
      if (cuerpo != null) 'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };

    http.Response respuesta;
    try {
      final peticion = http.Request(metodo, uri)..headers.addAll(encabezados);
      if (cuerpo != null) {
        peticion.body = jsonEncode(cuerpo);
      }
      final transmitida = await _cliente.send(peticion).timeout(_tiempoLimite);
      respuesta = await http.Response.fromStream(transmitida);
    } on TimeoutException {
      throw ApiError(
        mensaje: 'El servidor no respondió. Revisa que la API esté corriendo.',
      );
    } catch (_) {
      throw ApiError(
        mensaje: 'No se pudo conectar con el servidor ($baseUrl).',
      );
    }

    return _procesar(respuesta);
  }

  Uri _uri(String ruta, Map<String, dynamic>? query) {
    final base = Uri.parse(baseUrl);
    final partes = <String>[
      ...base.pathSegments.where((s) => s.isNotEmpty),
      ...ruta.split('/').where((s) => s.isNotEmpty),
    ];
    final parametros = <String, String>{};
    query?.forEach((clave, valor) {
      if (valor != null) parametros[clave] = '$valor';
    });
    return base.replace(
      pathSegments: partes,
      queryParameters: parametros.isEmpty ? null : parametros,
    );
  }

  dynamic _procesar(http.Response respuesta) {
    final estado = respuesta.statusCode;
    final cuerpo = utf8.decode(respuesta.bodyBytes);

    dynamic datos;
    if (cuerpo.isNotEmpty) {
      try {
        datos = jsonDecode(cuerpo);
      } catch (_) {
        datos = null;
      }
    }

    if (estado >= 200 && estado < 300) {
      return datos;
    }

    if (estado == 401) {
      alPerderSesion?.call();
    }

    throw ApiError(
      estado: estado,
      mensaje: _mensaje(estado, datos),
      erroresPorCampo: _erroresPorCampo(datos),
    );
  }

  /// Textos genéricos de FastAPI/Starlette, en inglés. No dicen nada útil a
  /// quien usa la app, así que se cambian por el mensaje del código.
  static const Set<String> _detallesGenericos = {
    'Not Found',
    'Method Not Allowed',
    'Internal Server Error',
    'Unauthorized',
    'Forbidden',
  };

  String _mensaje(int estado, dynamic datos) {
    if (datos is Map) {
      final detalle = datos['detail'];
      if (detalle is String &&
          detalle.isNotEmpty &&
          !_detallesGenericos.contains(detalle)) {
        return detalle;
      }
      if (detalle is List && detalle.isNotEmpty) return 'Hay datos inválidos.';
    }
    switch (estado) {
      // 405: la ruta existe pero el servidor no acepta ese método. Pasa
      // cuando la app es más nueva que el backend que está corriendo.
      case 405:
        return 'El servidor todavía no tiene esta función. Actualiza el '
            'backend a la última versión y reinícialo.';
      case 500:
        return 'El servidor tuvo un error. Revisa la consola de uvicorn.';
      case 401:
        return 'Tu sesión expiró. Vuelve a iniciar sesión.';
      case 403:
        return 'Esta operación es solo para el administrador de la plataforma.';
      case 404:
        return 'No encontramos ese registro.';
      case 409:
        return 'Ese registro ya existe.';
      default:
        return 'El servidor respondió con un error ($estado).';
    }
  }

  Map<String, String> _erroresPorCampo(dynamic datos) {
    if (datos is! Map) return const <String, String>{};
    final lista = datos['errores'];
    if (lista is! List) return const <String, String>{};

    final errores = <String, String>{};
    for (final elemento in lista) {
      if (elemento is Map) {
        final campo = '${elemento['campo'] ?? ''}';
        final mensaje = '${elemento['mensaje'] ?? ''}';
        if (campo.isNotEmpty && mensaje.isNotEmpty) {
          // El backend manda rutas como "usuario_inicial.password".
          errores[campo.split('.').last] = mensaje;
        }
      }
    }
    return errores;
  }

  void cerrar() => _cliente.close();
}
