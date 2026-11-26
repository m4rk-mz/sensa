import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../vistamodelos/sesion_vm.dart';
import 'admin_panel_vista.dart';
import 'historial_vista.dart';
import 'negocios_vista.dart';
import 'reporte_vista.dart';
import 'sensores_vista.dart';
import 'usuarios_vista.dart';

/// Contenedor con la barra de abajo. Las pestañas dependen del rol que
/// devolvió el backend.
class InicioVista extends StatefulWidget {
  const InicioVista({super.key});

  @override
  State<InicioVista> createState() => _InicioVistaState();
}

class _InicioVistaState extends State<InicioVista> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    final esAdmin = context.select<SesionVm, bool>((vm) => vm.esAdmin);

    final pantallas = esAdmin
        ? const <Widget>[
            AdminPanelVista(),
            SensoresVista(),
            HistorialVista(),
            NegociosVista(),
            UsuariosVista(),
          ]
        : const <Widget>[SensoresVista(), ReporteVista(), HistorialVista()];

    final destinos = esAdmin
        ? const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.insert_chart_outlined),
              selectedIcon: Icon(Icons.insert_chart),
              label: 'Panel',
            ),
            NavigationDestination(
              icon: Icon(Icons.sensors_outlined),
              selectedIcon: Icon(Icons.sensors),
              label: 'Sensores',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              label: 'Historial',
            ),
            NavigationDestination(
              icon: Icon(Icons.store_outlined),
              selectedIcon: Icon(Icons.store),
              label: 'Negocios',
            ),
            NavigationDestination(
              icon: Icon(Icons.group_outlined),
              selectedIcon: Icon(Icons.group),
              label: 'Usuarios',
            ),
          ]
        : const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.sensors_outlined),
              selectedIcon: Icon(Icons.sensors),
              label: 'Sensores',
            ),
            NavigationDestination(
              icon: Icon(Icons.insert_chart_outlined),
              selectedIcon: Icon(Icons.insert_chart),
              label: 'Reporte',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_rounded),
              label: 'Historial',
            ),
          ];

    final indiceSeguro = _indice < pantallas.length ? _indice : 0;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: indiceSeguro, children: pantallas),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: indiceSeguro,
        destinations: destinos,
        onDestinationSelected: (i) => setState(() => _indice = i),
      ),
    );
  }
}
