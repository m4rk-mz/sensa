import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/controladores.dart';
import '../core/mensajes.dart';
import '../core/validaciones.dart';
import '../modelos/negocio.dart';
import '../servicios/sensa_api.dart';
import '../tema.dart';
import '../vistamodelos/negocios_vm.dart';
import 'widgets/comunes.dart';
import 'widgets/menu_cuenta.dart';

/// Negocios (solo administrador): lista, alta y registro de sensores.
class NegociosVista extends StatelessWidget {
  const NegociosVista({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<SensaApi>();

    return ChangeNotifierProvider<NegociosVm>(
      create: (_) => NegociosVm(api)..cargar(),
      child: const _Cuerpo(),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NegociosVm>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () => vm.cargar(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 90),
          children: [
            const EncabezadoPantalla(
              superior: 'Administrador de Sensa',
              titulo: 'Negocios',
              accion: MenuCuenta(),
            ),
            const SizedBox(height: 18),

            if (vm.error != null) ...[
              CajaError(mensaje: vm.error!, alReintentar: () => vm.cargar()),
              const SizedBox(height: 18),
            ],

            if (vm.cargando && vm.negocios.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              ),

            if (!vm.cargando && vm.negocios.isEmpty && vm.error == null)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Vacio(
                  titulo: 'Sin negocios',
                  detalle: 'Da de alta el primero con el botón de abajo.',
                  icono: Icons.store_outlined,
                ),
              ),

            for (final negocio in vm.negocios) ...[
              _TarjetaNegocio(negocio: negocio),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _altaNegocio(context, vm),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo negocio'),
      ),
    );
  }
}

class _TarjetaNegocio extends StatelessWidget {
  const _TarjetaNegocio({required this.negocio});

  final Negocio negocio;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<NegociosVm>();

    return Tarjeta(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(negocio.nombre, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _altaSensor(context, vm, negocio),
              icon: const Icon(Icons.sensors_rounded, size: 18),
              label: const Text('Registrar un sensor'),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- diálogos

Future<void> _altaNegocio(BuildContext context, NegociosVm vm) async {
  final formulario = GlobalKey<FormState>();
  final nombre = TextEditingController();
  final usuarioNombre = TextEditingController();
  final usuarioEmail = TextEditingController();
  final usuarioPassword = TextEditingController();

  final guardar = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (hoja) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(hoja).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: formulario,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Nuevo negocio',
                style: Theme.of(hoja).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: Validaciones.nombre,
              ),
              const SizedBox(height: 22),
              const Text(
                'PRIMER USUARIO (OPCIONAL)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                  color: ColoresSensa.tintaTenue,
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: usuarioNombre,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => _opcional(v, usuarioEmail, usuarioPassword)
                    ? null
                    : Validaciones.nombre(v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: usuarioEmail,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Correo'),
                validator: (v) => _opcional(v, usuarioNombre, usuarioPassword)
                    ? null
                    : Validaciones.correo(v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: usuarioPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña',
                  helperText: 'Mínimo 8 caracteres, con una letra y un número.',
                ),
                validator: (v) => _opcional(v, usuarioNombre, usuarioEmail)
                    ? null
                    : Validaciones.passwordNueva(v),
              ),
              const SizedBox(height: 10),
              const Text(
                'El rol lo fija el backend: cualquier usuario que se cree '
                'aquí entra como usuario del negocio.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: ColoresSensa.tintaTenue,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  if (formulario.currentState!.validate()) {
                    Navigator.of(hoja).pop(true);
                  }
                },
                child: const Text('Dar de alta'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(hoja).pop(false),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  if (guardar == true) {
    final ok = await vm.crearNegocio(
      nombre: nombre.text,
      usuarioNombre: usuarioNombre.text,
      usuarioEmail: usuarioEmail.text,
      usuarioPassword: usuarioPassword.text,
    );
    Mensajes.mostrar(
      ok ? 'Negocio dado de alta.' : vm.error ?? 'No se pudo dar de alta el negocio.',
    );
  }

  desecharAlCerrar([nombre, usuarioNombre, usuarioEmail, usuarioPassword]);
}

/// El bloque del primer usuario es opcional: si los tres campos están
/// vacíos, no se valida ninguno.
bool _opcional(
  String? valor,
  TextEditingController otro1,
  TextEditingController otro2,
) {
  return (valor ?? '').trim().isEmpty &&
      otro1.text.trim().isEmpty &&
      otro2.text.trim().isEmpty;
}

Future<void> _altaSensor(
  BuildContext context,
  NegociosVm vm,
  Negocio negocio,
) async {
  final formulario = GlobalKey<FormState>();
  final nombre = TextEditingController();
  final umbral = TextEditingController(text: '27.0');

  final guardar = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: Text('Sensor en ${negocio.nombre}'),
      content: Form(
        key: formulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nombre,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nombre del nodo',
                hintText: 'Cuarto de servidor',
              ),
              validator: Validaciones.nombre,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: umbral,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Umbral (°C)',
                helperText: 'El DHT11 mide de 0 a 50 °C.',
              ),
              validator: Validaciones.umbral,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogo).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (formulario.currentState!.validate()) {
              Navigator.of(dialogo).pop(true);
            }
          },
          child: const Text('Registrar'),
        ),
      ],
    ),
  );

  if (guardar == true) {
    final ok = await vm.registrarSensor(
      businessId: negocio.id,
      nombre: nombre.text,
      umbral: umbral.text,
    );
    if (!ok) {
      Mensajes.mostrar(vm.error ?? 'No se pudo registrar el sensor.');
    } else if (context.mounted) {
      await _mostrarToken(context, vm);
    }
  }

  desecharAlCerrar([nombre, umbral]);
}

/// El token del nodo se muestra una sola vez: en la BD solo queda su hash.
Future<void> _mostrarToken(BuildContext context, NegociosVm vm) async {
  final registrado = vm.sensorRecienRegistrado;
  if (registrado == null) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogo) => AlertDialog(
      title: const Text('Copia el token del nodo'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${registrado.sensor.nombre} quedó registrado. Este token va en '
            'el firmware del ESP32 y solo se muestra ahora: en la base de '
            'datos queda su hash.',
            style: const TextStyle(fontSize: 13.5, height: 1.5),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: ColoresSensa.superficieTenue,
              border: Border.all(color: ColoresSensa.borde),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              registrado.token,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontFamilyFallback: <String>['Courier'],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: registrado.token));
          },
          child: const Text('Copiar'),
        ),
        FilledButton(
          onPressed: () {
            vm.olvidarToken();
            Navigator.of(dialogo).pop();
          },
          child: const Text('Ya lo guardé'),
        ),
      ],
    ),
  );
}
