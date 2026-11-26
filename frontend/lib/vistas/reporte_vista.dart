import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formato.dart';
import '../core/mensajes.dart';
import '../modelos/sensor.dart';
import '../servicios/sensa_api.dart';
import '../tema.dart';
import '../vistamodelos/reporte_vm.dart';
import 'widgets/comunes.dart';
import 'widgets/grafica_linea.dart';
import 'widgets/menu_cuenta.dart';

/// Pantalla "Reporte del día".
class ReporteVista extends StatelessWidget {
  const ReporteVista({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<SensaApi>();

    return ChangeNotifierProvider<ReporteVm>(
      create: (_) => ReporteVm(api)..cargar(),
      child: const _Cuerpo(),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReporteVm>();
    final reporte = vm.reporte?.reporte;

    return RefreshIndicator(
      onRefresh: () => vm.cargar(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
        children: [
          EncabezadoPantalla(
            superior: 'Sensa',
            titulo: 'Reporte del día',
            inferior: vm.reporte == null
                ? null
                : Formato.fechaLarga(vm.reporte!.fecha),
            accion: const MenuCuenta(),
          ),
          const SizedBox(height: 16),

          if (vm.sensores.length > 1) ...[
            _SelectorSensor(vm: vm),
            const SizedBox(height: 16),
          ],

          if (vm.error != null) ...[
            CajaError(mensaje: vm.error!, alReintentar: () => vm.cargar()),
            const SizedBox(height: 16),
          ],

          if (vm.cargando && reporte == null)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (!vm.cargando && vm.sensores.isEmpty && vm.error == null)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Vacio(
                titulo: 'Sin sensores',
                detalle: 'Cuando tu negocio tenga un nodo registrado, aquí '
                    'aparece su reporte del día.',
                icono: Icons.insert_chart_outlined,
              ),
            ),

          if (vm.sensores.isNotEmpty) ...[
            _BotonGenerar(vm: vm),
            const SizedBox(height: 16),
          ],

          if (vm.reporte != null && reporte == null && !vm.cargando)
            Tarjeta(
              hijo: Text(
                vm.reporte!.mensaje ??
                    'Todavía no hay lecturas válidas para este día.',
                style: const TextStyle(fontSize: 13.5, height: 1.5),
              ),
            ),

          if (reporte != null) ...[
            Row(
              children: [
                Expanded(
                  child: _Tile(
                    etiqueta: 'Mínima',
                    valor: '${reporte.tempMin.toStringAsFixed(1)}°',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Tile(
                    etiqueta: 'Promedio',
                    valor: '${reporte.tempProm.toStringAsFixed(1)}°',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Tile(
                    etiqueta: 'Máxima',
                    valor: '${reporte.tempMax.toStringAsFixed(1)}°',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Tarjeta(
              hijo: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Temperatura por hora (°C)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  GraficaLinea(puntos: vm.porHora, umbral: vm.umbral),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _Tile(
                    etiqueta: 'Alertas',
                    valor: '${reporte.alertas}',
                    pie: 'últimas 24 h',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Tile(
                    etiqueta: 'LED encendido',
                    valor: '${reporte.activacionesLed}',
                    pie: 'veces',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Text(
              'El backend arma este reporte con las '
              '${reporte.lecturasValidas} lecturas válidas del día; humedad '
              'promedio ${reporte.humProm.toStringAsFixed(0)} %. Las lecturas '
              'fuera del rango del DHT11 no entran.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: ColoresSensa.tintaTenue,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Genera el reporte de hoy sin esperar a la tarea de medianoche.
class _BotonGenerar extends StatelessWidget {
  const _BotonGenerar({required this.vm});

  final ReporteVm vm;

  @override
  Widget build(BuildContext context) {
    final guardado = vm.reporte?.reporte?.generadoEn;

    return Tarjeta(
      relleno: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Reporte de hoy',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: vm.generando ? null : () => _generar(),
                icon: vm.generando
                    ? const SizedBox(
                        height: 15,
                        width: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bolt_rounded, size: 18),
                label: const Text('Generar'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            guardado == null
                ? 'El reporte del día anterior lo deja listo el servidor a '
                    'las 00:10. Con este botón se guarda el de hoy al '
                    'momento, con las lecturas que ya hay.'
                : 'Guardado ${Formato.haceCuanto(guardado)} '
                    '(${Formato.hora(guardado)}). Vuelve a generarlo para '
                    'incluir las lecturas más nuevas.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: ColoresSensa.tintaTenue,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generar() async {
    final conDatos = await vm.generarReporteDeHoy();
    Mensajes.mostrar(
      conDatos
          ? 'Reporte de hoy generado y guardado.'
          : vm.errorGenerar ??
              vm.reporte?.mensaje ??
              'Todavía no hay lecturas válidas de hoy.',
    );
  }
}

class _SelectorSensor extends StatelessWidget {
  const _SelectorSensor({required this.vm});

  final ReporteVm vm;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: PopupMenuButton<SensorEstado>(
        onSelected: vm.elegirSensor,
        itemBuilder: (_) => vm.sensores
            .map(
              (sensor) => PopupMenuItem<SensorEstado>(
                value: sensor,
                child: Text(sensor.nombre),
              ),
            )
            .toList(),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: ColoresSensa.superficie,
            border: Border.all(color: ColoresSensa.borde),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                vm.seleccionado?.nombre ?? 'Elige un sensor',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.etiqueta, required this.valor, this.pie});

  final String etiqueta;
  final String valor;
  final String? pie;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      relleno: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: ColoresSensa.tintaTenue,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            valor,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
          ),
          if (pie != null)
            Text(
              pie!,
              style: const TextStyle(
                fontSize: 11.5,
                color: ColoresSensa.tintaTenue,
              ),
            ),
        ],
      ),
    );
  }
}
