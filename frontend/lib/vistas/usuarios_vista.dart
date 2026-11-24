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
              if (!usuario.activo)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: ChipEstado.neutro(texto: 'Dado de baja'),
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
          const SizedBox(height: 11),
          Row(
            children: [
              if (!usuario.esAdmin)
                Expanded(
                  child: OutlinedButton(
                    onPressed: esYo || !usuario.activo
                        ? null
                        : () => _confirmar(context),
                    child: const Text('Promover'),
                  ),
                ),
              if (!usuario.esAdmin) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: usuario.activo
                        ? ColoresSensa.ambarTexto
                        : ColoresSensa.verde,
                  ),
                  onPressed: esYo ? null : () => _cambiarEstado(context),
                  child: Text(usuario.activo ? 'Dar de baja' : 'Reactivar'),
                ),
              ),
            ],
          ),
          if (esYo) ...[
            const SizedBox(height: 7),
            const Text(
              'Esta es tu propia cuenta: no puedes darte de baja ni '
              'promoverte.',
              style: _tenue,
            ),
          ],
        ],
      ),
    );
  }

  static const TextStyle _tenue =
      TextStyle(fontSize: 12.5, color: ColoresSensa.tintaTenue);

  /// Da de baja o reactiva. No borra al usuario: solo le quita el acceso,
  /// y como el backend relee el estado en cada petición, una sesión abierta
  /// deja de valer en cuanto se guarda.
  Future<void> _cambiarEstado(BuildContext context) async {
    final darDeBaja = usuario.activo;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text(
          darDeBaja
              ? '¿Dar de baja a ${usuario.nombre}?'
              : '¿Reactivar a ${usuario.nombre}?',
        ),
        content: Text(
          darDeBaja
              ? 'No podrá iniciar sesión y su sesión abierta deja de valer en '
                  'la siguiente petición. No se borra nada: sus datos y los '
                  'de su negocio se quedan, y puedes reactivarlo cuando '
                  'quieras.'
              : 'Vuelve a poder iniciar sesión con la misma contraseña.',
          style: const TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: darDeBaja
                ? FilledButton.styleFrom(backgroundColor: ColoresSensa.ambar)
                : null,
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: Text(darDeBaja ? 'Dar de baja' : 'Reactivar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    final ok = await vm.cambiarEstado(usuario, activo: !darDeBaja);
    if (!ok) Mensajes.mostrar(vm.error ?? 'No se pudo actualizar al usuario.');
  }

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
