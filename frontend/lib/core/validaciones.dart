/// Reglas de validación de la app.
///
/// Son las mismas que aplica el backend (modelos de `app/models`), para que
/// la app señale el error y no deje enviar antes de gastar una petición:
///
/// - rangos del DHT11: 0 a 50 °C y 20 a 90 % HR,
/// - contraseña nueva: mínimo 8 caracteres, con al menos una letra y un
///   número,
/// - correo con formato `algo@algo.algo`.
///
/// Los VistaModelo las usan; las vistas solo muestran lo que devuelven.
class Rangos {
  static const double tempMinC = 0.0;
  static const double tempMaxC = 50.0;
  static const double humMinPct = 20.0;
  static const double humMaxPct = 90.0;
}

class Validaciones {
  static final RegExp _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');
  static final RegExp _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Devuelve null si el valor es correcto, o el texto a mostrar bajo el campo.
  static String? correo(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribe tu correo.';
    if (texto.length > 160) return 'El correo es demasiado largo.';
    if (!_email.hasMatch(texto)) {
      return 'Escribe un correo completo, por ejemplo nombre@negocio.mx';
    }
    return null;
  }

  static String? passwordLogin(String? valor) {
    final texto = valor ?? '';
    if (texto.isEmpty) return 'Escribe tu contraseña.';
    return null;
  }

  /// Contraseña nueva (alta de usuario y cambio de contraseña).
  static String? passwordNueva(String? valor) {
    final texto = valor ?? '';
    if (texto.isEmpty) return 'Escribe una contraseña.';
    if (texto.length < 8) return 'Debe tener al menos 8 caracteres.';
    if (texto.length > 128) return 'Debe tener máximo 128 caracteres.';
    final tieneLetra = texto.contains(RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]'));
    final tieneNumero = texto.contains(RegExp(r'\d'));
    if (!tieneLetra || !tieneNumero) {
      return 'Debe incluir al menos una letra y un número.';
    }
    return null;
  }

  static String? nombre(String? valor) {
    final texto = (valor ?? '').trim();
    if (texto.isEmpty) return 'Escribe un nombre.';
    if (texto.length < 2) return 'Debe tener al menos 2 caracteres.';
    if (texto.length > 120) return 'Debe tener máximo 120 caracteres.';
    return null;
  }

  /// Umbral de alerta en °C: tiene que caber en el rango del DHT11.
  static String? umbral(String? valor) {
    final texto = (valor ?? '').trim().replaceAll(',', '.');
    if (texto.isEmpty) return 'Escribe el umbral en °C.';
    final numero = double.tryParse(texto);
    if (numero == null) return 'Usa un número, por ejemplo 27.0';
    if (numero < Rangos.tempMinC || numero > Rangos.tempMaxC) {
      return 'El DHT11 mide de ${_sinDecimalCero(Rangos.tempMinC)} a '
          '${_sinDecimalCero(Rangos.tempMaxC)} °C.';
    }
    return null;
  }

  static bool esUuid(String valor) => _uuid.hasMatch(valor);

  static double? umbralComoNumero(String valor) =>
      double.tryParse(valor.trim().replaceAll(',', '.'));

  static String _sinDecimalCero(double valor) =>
      valor == valor.roundToDouble() ? valor.toStringAsFixed(0) : '$valor';
}
