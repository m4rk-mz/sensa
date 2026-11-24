/// Configuración de la app.
///
/// La URL del backend se pasa al compilar, así no queda escrita en el código:
///
///   flutter run --dart-define=SENSA_API=http://192.168.1.70:8000
///
/// El valor por omisión (10.0.2.2) es como el emulador de Android ve la
/// computadora donde corre uvicorn.
class Config {
  static const String apiBaseUrl = String.fromEnvironment(
    'SENSA_API',
    defaultValue: 'http://10.0.2.2:8000',
  );

  /// Cada cuánto se refresca "Mis sensores".
  static const Duration refrescoLista = Duration(seconds: 5);

  /// Cada cuánto se refresca el detalle de un sensor. El nodo manda la
  /// lectura en cuanto cambia, así que la app la ve en 2 a 4 s.
  static const Duration refrescoDetalle = Duration(seconds: 2);
}
