import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_cliente.dart';
import 'core/config.dart';
import 'servicios/sensa_api.dart';
import 'tema.dart';
import 'vistamodelos/sesion_vm.dart';
import 'vistas/inicio_vista.dart';
import 'vistas/login_vista.dart';

/// Raíz de la app.
///
/// Arma las tres capas de MVVM: el cliente y el servicio (datos), los
/// VistaModelo (que se inyectan con provider) y las vistas.
class SensaApp extends StatefulWidget {
  const SensaApp({super.key});

  @override
  State<SensaApp> createState() => _SensaAppState();
}

class _SensaAppState extends State<SensaApp> {
  late final ApiCliente _cliente;
  late final SensaApi _api;

  @override
  void initState() {
    super.initState();
    _cliente = ApiCliente(baseUrl: Config.apiBaseUrl);
    _api = SensaApi(_cliente);
  }

  @override
  void dispose() {
    _cliente.cerrar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiCliente>.value(value: _cliente),
        Provider<SensaApi>.value(value: _api),
        ChangeNotifierProvider<SesionVm>(
          create: (_) => SesionVm(cliente: _cliente, api: _api)..restaurar(),
        ),
      ],
      child: MaterialApp(
        title: 'Sensa',
        debugShowCheckedModeBanner: false,
        theme: temaSensa(),
        home: const _Puerta(),
      ),
    );
  }
}

/// Decide qué se ve según el estado de la sesión.
class _Puerta extends StatelessWidget {
  const _Puerta();

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionVm>();

    switch (sesion.estado) {
      case EstadoSesion.comprobando:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case EstadoSesion.sinSesion:
        return const LoginVista();
      case EstadoSesion.conSesion:
        return const InicioVista();
    }
  }
}
