import 'sensor.dart';

/// Una pantalla de la LCD 1602: dos renglones de 16 caracteres.
class VistaLcd {
  const VistaLcd(this.linea1, this.linea2);

  final String linea1;
  final String linea2;

  @override
  String toString() => '$linea1|$linea2';
}

/// Arma el mismo texto que el firmware escribe en la LCD 1602 del nodo, para
/// que la app muestre exactamente lo que ve quien está en el lugar.
///
/// - Fuera de alerta: una sola pantalla con lectura, modo y estado del LED.
/// - En alerta: dos pantallas que el nodo alterna cada 3 s; la primera avisa
///   e incluye el umbral.
///
/// Los renglones se recortan a 16 caracteres, que es lo que cabe en la 1602.
class LineasLcd {
  static const int columnas = 16;

  static List<VistaLcd> de(SensorEstado estado) {
    final temperatura = estado.temperatura;
    final humedad = estado.humedad;

    if (temperatura == null || humedad == null) {
      return const <VistaLcd>[VistaLcd('Sensa', 'Sin lecturas')];
    }

    final lectura = VistaLcd(
      _recorta('T:${temperatura.toStringAsFixed(1)}C '
          'H:${humedad.toStringAsFixed(0)}%'),
      _recorta('${(estado.esManual ? 'MANUAL' : 'AUTO').padRight(8)}'
          'LED:${estado.ledEstadoReal ? 'ON' : 'OFF'}'),
    );

    if (!estado.alerta) {
      return <VistaLcd>[lectura];
    }

    final aviso = VistaLcd(
      _recorta('!ALERTA! ${temperatura.toStringAsFixed(1)}C'),
      _recorta('Umbral ${estado.umbralC.toStringAsFixed(1)}C'),
    );
    return <VistaLcd>[aviso, lectura];
  }

  static String _recorta(String texto) =>
      texto.length <= columnas ? texto : texto.substring(0, columnas);
}
