import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Guarda el token y el usuario de la sesión en el teléfono, para no pedir
/// la contraseña otra vez al abrir la app.
///
/// Solo se guarda el JWT y los datos públicos del usuario: nunca la
/// contraseña.
class AlmacenSesion {
  static const _claveToken = 'sensa.token';
  static const _claveUsuario = 'sensa.usuario';
  static const _claveExpira = 'sensa.expira';

  Future<void> guardar({
    required String token,
    required Map<String, dynamic> usuario,
    DateTime? expiraEn,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_claveToken, token);
    await prefs.setString(_claveUsuario, jsonEncode(usuario));
    if (expiraEn != null) {
      await prefs.setString(_claveExpira, expiraEn.toIso8601String());
    } else {
      await prefs.remove(_claveExpira);
    }
  }

  Future<String?> token() async {
    final prefs = await SharedPreferences.getInstance();
    final expira = prefs.getString(_claveExpira);
    if (expira != null) {
      final fecha = DateTime.tryParse(expira);
      if (fecha != null && fecha.isBefore(DateTime.now())) {
        await limpiar();
        return null;
      }
    }
    return prefs.getString(_claveToken);
  }

  Future<Map<String, dynamic>?> usuario() async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_claveUsuario);
    if (texto == null) return null;
    try {
      final datos = jsonDecode(texto);
      return datos is Map<String, dynamic> ? datos : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_claveToken);
    await prefs.remove(_claveUsuario);
    await prefs.remove(_claveExpira);
  }
}
