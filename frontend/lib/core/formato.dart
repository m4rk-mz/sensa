import 'package:intl/intl.dart';

/// Formatos de texto que se repiten en varias pantallas.
class Formato {
  static final DateFormat _hora = DateFormat('HH:mm');
  static final DateFormat _fechaLarga = DateFormat("EEEE d 'de' MMMM", 'es_MX');
  static final DateFormat _fechaCorta = DateFormat('d MMM', 'es_MX');

  static String temperatura(double? valor) =>
      valor == null ? '--' : '${valor.toStringAsFixed(1)} °C';

  static String humedad(double? valor) =>
      valor == null ? '--' : '${valor.toStringAsFixed(0)} %';

  static String hora(DateTime? fecha) =>
      fecha == null ? '--' : _hora.format(fecha.toLocal());

  static String fechaLarga(DateTime fecha) {
    final texto = _fechaLarga.format(fecha);
    return texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
  }

  static String fechaCorta(DateTime fecha) => _fechaCorta.format(fecha);

  /// "hace 12 s", "hace 7 min", "hace 2 h".
  static String haceCuanto(DateTime? fecha) {
    if (fecha == null) return 'sin lecturas';
    final diferencia = DateTime.now().difference(fecha.toLocal());
    if (diferencia.isNegative) return 'hace un momento';
    if (diferencia.inSeconds < 60) return 'hace ${diferencia.inSeconds} s';
    if (diferencia.inMinutes < 60) return 'hace ${diferencia.inMinutes} min';
    if (diferencia.inHours < 24) return 'hace ${diferencia.inHours} h';
    return 'hace ${diferencia.inDays} d';
  }

  /// "en 24 min": lo que falta para que el modo manual expire.
  static String faltanPara(DateTime? fecha) {
    if (fecha == null) return '';
    final diferencia = fecha.toLocal().difference(DateTime.now());
    if (diferencia.isNegative) return 'ya expiró';
    if (diferencia.inMinutes < 1) return 'en menos de 1 min';
    if (diferencia.inMinutes < 60) return 'en ${diferencia.inMinutes} min';
    return 'en ${diferencia.inHours} h';
  }
}
