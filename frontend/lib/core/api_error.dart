/// Error de la API, ya traducido a algo que la vista pueda mostrar.
class ApiError implements Exception {
  ApiError({
    required this.mensaje,
    this.estado,
    this.erroresPorCampo = const <String, String>{},
  });

  /// Código HTTP, o null si la petición nunca llegó (sin red, servidor
  /// apagado).
  final int? estado;

  /// Texto para mostrar arriba del formulario o en un SnackBar.
  final String mensaje;

  /// Errores campo por campo que manda el backend en un 422:
  /// `{"errores": [{"campo": "email", "mensaje": "..."}]}`.
  final Map<String, String> erroresPorCampo;

  bool get esSesionInvalida => estado == 401;
  bool get esSinPermiso => estado == 403;
  bool get esNoEncontrado => estado == 404;
  bool get esConflicto => estado == 409;
  bool get esValidacion => estado == 422;
  bool get esSinConexion => estado == null;

  @override
  String toString() => 'ApiError($estado): $mensaje';
}
