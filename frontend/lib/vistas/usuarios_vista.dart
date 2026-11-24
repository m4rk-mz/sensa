import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/mensajes.dart';
import '../modelos/usuario.dart';
import '../servicios/sensa_api.dart';
import '../tema.dart';
import '../vistamodelos/sesion_vm.dart';
import '../vistamodelos/usuarios_vm.dart';
import 'widgets/comunes.dart';
import 'widgets/menu_cuenta.dart';

/// Usuarios (solo administrador): lista, filtro por negocio y promoción a
/// administrador con confirmación.
class UsuariosVista extends StatelessWidget {
  const UsuariosVista({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<SensaApi>();

    return ChangeNotifierProvider<UsuariosVm>(
      create: (_) => UsuariosVm(api)..cargar(),
      child: const _Cuerpo(),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UsuariosVm>();

    if (vm.aviso != null) {
      final texto = vm.aviso!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Mensajes.mostrar(texto);
        vm.limpiarAviso();
      });
    }

    return RefreshIndicator(
      onRefresh: () => vm.cargar(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
        children: [
          const EncabezadoPantalla(
            superior: 'Administrador de Sensa',
            titulo: 'Usuarios',
            accion: MenuCuenta(),
          ),
          const SizedBox(height: 16),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('Todos'),
                  selected: vm.filtroNegocio == null,
                  onSelected: (_) => vm.filtrarPor(null),
                ),
                for (final negocio in vm.negocios) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(negocio.nombre),
                    selected: vm.filtroNegocio == negocio.id,
                    onSelected: (_) => vm.filtrarPor(negocio.id),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (vm.error != null) ...[
            CajaError(mensaje: vm.error!, alReintentar: () => vm.cargar()),
            const SizedBox(height: 16),
          ],

          if (vm.cargando && vm.usuarios.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 50),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (!vm.cargando && vm.usuarios.isEmpty && vm.error == null)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Vacio(
                titulo: 'Sin usuarios',
                detalle: 'Los usuarios se dan de alta desde el negocio.',
                icono: Icons.group_outlined,
              ),
            ),

          for (final usuario in vm.usuarios) ...[
            _TarjetaUsuario(usuario: usuario, vm: vm),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _TarjetaUsuario extends StatelessWidget {
  const _TarjetaUsuario({required this.usuario, required this.vm});

  final Usuario usuario;
  final UsuariosVm vm;

  @override
  Widget build(BuildContext context) {
    final yo = context.read<SesionVm>().usuario;
    final esYo = yo != null && yo.id == usuario.id;

    return Tarjeta(
      fondo: usuario.esAdmin ? ColoresSensa.superficieTenue : null,
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuario.nombre,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(usuario.email, style: _tenue),
                    const SizedBox(height: 2),
                    Text(
                      '${vm.nombreDeNegocio(usuario.businessId)} · '
                      '${usuario.esAdmin ? 'administrador' : 'usuario del negocio'}',
                      style: _tenue,
                    ),
                  ],
                ),
              ),
              if (usuario.esAdmin)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: ColoresSensa.indigoTenue,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'ADMIN',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                      color: ColoresSensa.indigoOscuro,
                    ),
                  ),
                ),
            ],
          ),
          if (!usuario.esAdmin) ...[
            const SizedBox(height: 11),
            OutlinedButton(
              onPressed: esYo ? null : () => _confirmar(context),
              child: const Text('Promover a administrador'),
            ),
          ],
        ],
      ),
    );
  }

  static const TextStyle _tenue =
      TextStyle(fontSize: 12.5, color: ColoresSensa.tintaTenue);

  Future<void> _confirmar(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text('¿Promover a ${usuario.nombre}?'),
        content: const Text(
          'Como administrador podrá ver los datos de todos los negocios, dar '
          'de alta negocios y promover a otras personas. Deja de pertenecer a '
          'su negocio. El cambio se guarda en la base de datos, así que sigue '
          'ahí cuando vuelva a iniciar sesión.',
          style: TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Sí, promover'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    final ok = await vm.promover(usuario);
    if (!ok) Mensajes.mostrar(vm.error ?? 'No se pudo promover.');
  }
}
