import 'package:flutter/material.dart';

/// Avisos de abajo (SnackBar) sin depender de un BuildContext.
///
/// Antes cada pantalla llamaba `ScaffoldMessenger.of(context)`, a veces
/// después de un `await` o dentro de un `addPostFrameCallback`. Si para
/// entonces ese widget ya se había quitado del árbol, la llamada registraba
/// una dependencia sobre un contexto muerto y Flutter tiraba la pantalla
/// roja con `'_dependents.isEmpty': is not true`.
///
/// Con esta llave el aviso lo muestra el MaterialApp, que siempre está vivo,
/// así que ya no hace falta un contexto ni revisar si sigue montado.
class Mensajes {
  Mensajes._();

  static final GlobalKey<ScaffoldMessengerState> llave =
      GlobalKey<ScaffoldMessengerState>();

  static void mostrar(String texto) {
    final mensajero = llave.currentState;
    if (mensajero == null) return;
    mensajero
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texto),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
