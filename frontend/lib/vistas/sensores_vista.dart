import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formato.dart';
import '../core/mensajes.dart';
import '../modelos/sensor.dart';
import '../servicios/sensa_api.dart';
import '../tema.dart';
import '../vistamodelos/sensor_detalle_vm.dart';
import '../vistamodelos/sensores_vm.dart';
import '../vistamodelos/sesion_vm.dart';
import 'sensor_detalle_vista.dart';
import 'widgets/comunes.dart';
import 'widgets/menu_cuenta.dart';

/// Pantalla "Mis sensores".
class SensoresVista extends StatelessWidget {
  const SensoresVista({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<SensaApi>();
    final esAdmin = context.read<SesionVm>().esAdmin;

    return ChangeNotifierProvider<SensoresVm>(
      create: (_) => SensoresVm(api, esAdmin: esAdmin)
        ..cargar()
        ..iniciar(),
      child: const _Cuerpo(),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SensoresVm>();
    final esAdmin = context.read<SesionVm>().esAdmin;

    return RefreshIndicator(
      onRefresh: () => vm.cargar(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
        children: [
          EncabezadoPantalla(
            superior: vm.tituloNegocio,
            titulo: 'Mis sensores',
            inferior: _resumen(vm),
            accion: const MenuCuenta(),
          ),
          const SizedBox(height: 18),

          if (vm.error != null) ...[
            CajaError(mensaje: vm.error!, alReintentar: () => vm.cargar()),
            const SizedBox(height: 18),
          ],

          if (vm.cargando && vm.sensores.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (!vm.cargando && vm.sensores.isEmpty && vm.error == null)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Vacio(
                titulo: 'Todavía no hay sensores',
                detalle: 'El administrador de la plataforma registra los nodos '
                    'de tu negocio y te comparte su token.',
              ),
            ),

          for (final sensor in vm.sensores) ...[
            TarjetaSensor(
              estado: sensor,
              alAbrir: () => _abrir(context, sensor),
              alEliminar: esAdmin ? () => _eliminar(context, sensor, vm) : null,
            ),
            const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }

  static String? _resumen(SensoresVm vm) {
    if (vm.sensores.isEmpty) return null;
    final partes = <String>[
      if (vm.enAlerta > 0) '${vm.enAlerta} en alerta',
      '${vm.sensores.length - vm.enAlerta} sin alerta',
      if (vm.sinDatos > 0) '${vm.sinDatos} sin datos',
    ];
    return partes.join(' · ');
  }

  Future<void> _abrir(BuildContext context, SensorEstado sensor) async {
    final api = context.read<SensaApi>();
    final vm = context.read<SensoresVm>();

    // Mientras el detalle está abierto, la lista deja de pedir datos: no se
    // ve y solo serviría para competir por la red con la pantalla de enfrente.
    vm.detenerRefresco();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<SensorDetalleVm>(
          create: (_) => SensorDetalleVm(api: api, deviceId: sensor.id)
            ..iniciar(),
          child: SensorDetalleVista(nombreInicial: sensor.nombre),
        ),
      ),
    );
    vm.iniciar();
    await vm.cargar(silencioso: true);
  }

  /// Borra un sensor. Pide confirmación porque no tiene vuelta atrás: se va
  /// con sus lecturas, sus comandos y sus reportes.
  Future<void> _eliminar(
    BuildContext context,
    SensorEstado sensor,
    SensoresVm vm,
  ) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: Text('¿Eliminar "${sensor.nombre}"?'),
        content: const Text(
          'Se borra el sensor junto con sus lecturas, sus comandos y sus '
          'reportes. Esto no se puede deshacer.\n\nSi solo quieres sacarlo '
          'de la lista sin perder el historial, cámbialo a inactivo.',
          style: TextStyle(fontSize: 13.5, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ColoresSensa.ambar,
              minimumSize: const Size(0, 44),
            ),
            onPressed: () => Navigator.of(dialogo).pop(true),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    final ok = await vm.eliminar(sensor);
    Mensajes.mostrar(
      ok
          ? 'Se eliminó "${sensor.nombre}".'
          : vm.error ?? 'No se pudo eliminar el sensor.',
    );
  }
}

/// Tarjeta de un sensor en la lista.
class TarjetaSensor extends StatelessWidget {
  const TarjetaSensor({
    super.key,
    required this.estado,
    required this.alAbrir,
    this.alEliminar,
  });

  final SensorEstado estado;
  final VoidCallback alAbrir;

  /// Solo el administrador de plataforma puede borrar un sensor.
  final VoidCallback? alEliminar;

  @override
  Widget build(BuildContext context) {
    final sinDatos = !estado.enLinea;

    return Tarjeta(
      borde: estado.alerta ? ColoresSensa.ambar : null,
      fondo: sinDatos ? ColoresSensa.superficieTenue : null,
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  estado.nombre,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: 10),
              if (estado.alerta)
                const ChipEstado.alerta()
              else if (sinDatos)
                const ChipEstado.neutro(texto: 'Sin datos')
              else
                const ChipEstado.normal(),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formato.temperatura(estado.temperatura),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: ColoresSensa.tinta,
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  '${Formato.humedad(estado.humedad)} HR',
                  style: const TextStyle(
                    fontSize: 14,
                    color: ColoresSensa.tintaTenue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _detalle(estado),
            style: const TextStyle(
              fontSize: 13,
              height: 1.5,
              color: Color(0xFF3A3747),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                Formato.haceCuanto(estado.ultimaLecturaEn),
                style: const TextStyle(
                  fontSize: 12,
                  color: ColoresSensa.tintaTenue,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: alAbrir,
                child: const Text('Ver detalle'),
              ),
              if (alEliminar != null)
                IconButton(
                  tooltip: 'Eliminar sensor',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 20,
                    color: ColoresSensa.tintaTenue,
                  ),
                  onPressed: alEliminar,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _detalle(SensorEstado estado) {
    if (!estado.enLinea) {
      return 'El nodo no ha reportado. Si se queda sin red sigue avisando '
          'solo, con el umbral que trae guardado.';
    }
    if (estado.alerta) {
      return 'Pasó el umbral de ${estado.umbralC.toStringAsFixed(1)} °C. El '
          'nodo lo está avisando en el lugar con el LED rojo y el zumbador.';
    }
    return 'En automático, bajo el umbral de '
        '${estado.umbralC.toStringAsFixed(1)} °C.';
  }
}
