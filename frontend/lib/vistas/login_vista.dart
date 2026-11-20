import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/validaciones.dart';
import '../tema.dart';
import '../vistamodelos/sesion_vm.dart';
import 'widgets/comunes.dart';

/// Pantalla de inicio de sesión.
///
/// Hay una sola puerta de entrada: el backend decide el rol con la sesión y
/// la app abre en "Mis sensores" o en el panel del administrador.
class LoginVista extends StatefulWidget {
  const LoginVista({super.key});

  @override
  State<LoginVista> createState() => _LoginVistaState();
}

class _LoginVistaState extends State<LoginVista> {
  final _formulario = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _password = TextEditingController();
  bool _verPassword = false;

  @override
  void dispose() {
    _correo.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    // Validación en la app: señala el campo y no deja enviar.
    if (!_formulario.currentState!.validate()) return;

    final sesion = context.read<SesionVm>();
    await sesion.entrar(
      email: _correo.text.trim(),
      password: _password.text,
    );
    // Si entró, la raíz de la app cambia de pantalla sola.
  }

  void _usarCuenta(String correo, String password) {
    _correo.text = correo;
    _password.text = password;
  }

  @override
  Widget build(BuildContext context) {
    final sesion = context.watch<SesionVm>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Marca(),
                  const SizedBox(height: 14),
                  const Text(
                    'Temperatura y humedad de los espacios de tu negocio, '
                    'desde el celular.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.45,
                      color: ColoresSensa.tintaTenue,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (sesion.avisoSesion != null) ...[
                    CajaError(mensaje: sesion.avisoSesion!),
                    const SizedBox(height: 18),
                  ],
                  if (sesion.error != null) ...[
                    CajaError(mensaje: sesion.error!),
                    const SizedBox(height: 18),
                  ],

                  Form(
                    key: _formulario,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Etiqueta('Correo'),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _correo,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            hintText: 'usuario@negocio.mx',
                          ),
                          validator: Validaciones.correo,
                        ),
                        const SizedBox(height: 20),
                        const _Etiqueta('Contraseña'),
                        const SizedBox(height: 7),
                        TextFormField(
                          controller: _password,
                          obscureText: !_verPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _entrar(),
                          decoration: InputDecoration(
                            suffixIcon: IconButton(
                              tooltip: _verPassword
                                  ? 'Ocultar contraseña'
                                  : 'Mostrar contraseña',
                              icon: Icon(
                                _verPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _verPassword = !_verPassword),
                            ),
                          ),
                          validator: Validaciones.passwordLogin,
                        ),
                        const SizedBox(height: 26),
                        FilledButton(
                          onPressed: sesion.cargando ? null : _entrar,
                          child: sesion.cargando
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Entrar'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),
                  const Text(
                    '¿No puedes entrar? El administrador de tu negocio da de '
                    'alta las cuentas.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: ColoresSensa.tintaTenue,
                    ),
                  ),

                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    _CuentasDePrueba(alElegir: _usarCuenta),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.thermostat_rounded, size: 30, color: ColoresSensa.indigo),
        const SizedBox(width: 8),
        Text('Sensa', style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF3A3747),
      ),
    );
  }
}

/// Atajo para la demo: solo aparece en modo depuración.
class _CuentasDePrueba extends StatelessWidget {
  const _CuentasDePrueba({required this.alElegir});

  final void Function(String correo, String password) alElegir;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      fondo: ColoresSensa.superficieTenue,
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CUENTAS DE PRUEBA',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: ColoresSensa.tintaTenue,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => alElegir('admin@sensa.mx', 'Admin1234'),
            child: const Text('Administrador · admin@sensa.mx'),
          ),
          TextButton(
            onPressed: () =>
                alElegir('usuario@friosdelnorte.mx', 'Usuario1234'),
            child: const Text('Negocio · usuario@friosdelnorte.mx'),
          ),
        ],
      ),
    );
  }
}
