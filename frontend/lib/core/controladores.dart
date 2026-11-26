import 'package:flutter/widgets.dart';

/// Desecha controladores de texto de un diálogo o una hoja de abajo cuando
/// ya terminó su animación de salida.
///
/// `showDialog` y `showModalBottomSheet` regresan en cuanto se toca el
/// botón, pero el diálogo sigue en pantalla unos 200 ms mientras se va, y
/// sus campos siguen usando el controlador. Desecharlo en ese momento da la
/// pantalla roja "A TextEditingController was used after being disposed".
///
/// Mejor todavía es que el diálogo sea un StatefulWidget dueño de sus
/// controladores (como el del umbral); esto es para los que reciben los
/// controladores desde afuera.
void desecharAlCerrar(List<TextEditingController> controladores) {
  Future<void>.delayed(const Duration(milliseconds: 600), () {
    for (final c in controladores) {
      c.dispose();
    }
  });
}
