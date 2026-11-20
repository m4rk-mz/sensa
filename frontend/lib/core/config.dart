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
  static const Duration refrescoLista = Duration(seconds: 15);

  /// Cada cuánto se refresca el detalle de un sensor.
  static const Duration refrescoDetalle = Duration(seconds: 10);

  /// Cada cuánto alterna la LCD del nodo cuando hay alerta (igual que el
  /// firmware).
  static const Duration alternanciaLcd = Duration(seconds: 3);
}
