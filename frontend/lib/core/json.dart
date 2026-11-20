/// Lectores tolerantes de JSON.
///
/// El backend ya valida lo que devuelve, pero la app no debe caerse si un
/// campo llega nulo o como texto.
class J {
  static Map<String, dynamic> mapa(dynamic valor) =>
      valor is Map ? Map<String, dynamic>.from(valor) : <String, dynamic>{};

  static List<Map<String, dynamic>> lista(dynamic valor) {
    if (valor is! List) return const <Map<String, dynamic>>[];
    return valor.whereType<Map>().map(mapa).toList();
  }

  static String texto(dynamic valor, {String porOmision = ''}) =>
      valor == null ? porOmision : '$valor';

  static double? decimalNulo(dynamic valor) {
    if (valor == null) return null;
    if (valor is num) return valor.toDouble();
    return double.tryParse('$valor');
  }

  static double decimal(dynamic valor, {double porOmision = 0}) =>
      decimalNulo(valor) ?? porOmision;

  static int entero(dynamic valor, {int porOmision = 0}) {
    if (valor is num) return valor.toInt();
    return int.tryParse('$valor') ?? porOmision;
  }

  static bool booleano(dynamic valor, {bool porOmision = false}) {
    if (valor is bool) return valor;
    if (valor is num) return valor != 0;
    if (valor is String) return valor.toLowerCase() == 'true';
    return porOmision;
  }

  static DateTime? fecha(dynamic valor) {
    if (valor == null) return null;
    final texto = '$valor';
    if (texto.isEmpty) return null;
    return DateTime.tryParse(texto);
  }
}
