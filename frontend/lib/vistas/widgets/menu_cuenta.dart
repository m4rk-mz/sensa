import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../vistamodelos/sesion_vm.dart';
import '../perfil_vista.dart';

/// Botón de cuenta que llevan todas las pantallas: cambiar contraseña o
/// salir.
class MenuCuenta extends StatelessWidget {
  const MenuCuenta({super.key});

  @override
  Widget build(BuildContext context) {
    final sesion = context.read<SesionVm>();

    return PopupMenuButton<String>(
      tooltip: 'Tu cuenta',
      icon: const Icon(Icons.account_circle_outlined),
      onSelected: (opcion) {
        switch (opcion) {
          case 'perfil':
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PerfilVista()),
            );
            break;
          case 'salir':
            sesion.salir();
            break;
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'perfil',
          child: Text('Tu cuenta y contraseña'),
        ),
        PopupMenuItem<String>(
          value: 'salir',
          child: Text('Salir'),
        ),
      ],
    );
  }
}
