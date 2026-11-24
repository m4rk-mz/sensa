import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/mensajes.dart';
import '../core/validaciones.dart';
import '../tema.dart';
import '../vistamodelos/sesion_vm.dart';
import 'widgets/comunes.dart';

/// Tu cuenta: quién eres según el backend y cambio de contraseña.
class PerfilVista extends StatefulWidget {
  const PerfilVista({super.key});

  @override
  State<PerfilVista> createState() => _PerfilVistaState();
}

class _PerfilVistaState extends State<PerfilVista> {
  final _formulario = GlobalKey<FormState>();
  final _actual = TextEditingController();
  final _nueva = TextEditingController();

  @override
  void dispose() {
    _actual.dispose();
    _nueva.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formulario.currentState!.validate()) return;

    final sesion = context.read<SesionVm>();
    final ok = await sesion.cambiarPassword(
      actual: _actual.text,
      nueva: _nueva.text,
    );

    Mensajes.mostrar(
      ok
          ? 'Contraseña actualizada.'
          : sesion.error ?? 'No se pudo cambiar la contraseña.',
    );
    if (ok) {
      _actual.clear();
      _nueva.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionVm>();
    final usuario = sesion.usuario;

    return Scaffold(
      appBar: AppBar(title: const Text('Tu cuenta')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
        children: [
          if (usuario != null)
            Tarjeta(
              hijo: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuario.nombre,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(usuario.email, style: _tenue),
                  const SizedBox(height: 3),
                  Text(usuario.rolLegible, style: _tenue),
                ],
              ),
            ),
          const SizedBox(height: 20),

          const Text(
            'Cambiar contraseña',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formulario,
            child: Column(
              children: [
                TextFormField(
                  controller: _actual,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña actual',
                  ),
                  validator: Validaciones.passwordLogin,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _nueva,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña nueva',
                    helperText:
                        'Mínimo 8 caracteres, con una letra y un número.',
                  ),
                  validator: Validaciones.passwordNueva,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: sesion.cargando ? null : _guardar,
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<SesionVm>().salir();
            },
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Salir de la sesión'),
          ),
          const SizedBox(height: 22),
          Text(
            'Servidor: ${Config.apiBaseUrl}',
            style: const TextStyle(fontSize: 11.5, color: ColoresSensa.tintaTenue),
          ),
        ],
      ),
    );
  }

  static const TextStyle _tenue =
      TextStyle(fontSize: 12.5, color: ColoresSensa.tintaTenue);
}
