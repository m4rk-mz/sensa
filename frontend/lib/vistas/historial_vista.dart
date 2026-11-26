import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formato.dart';
import '../modelos/reporte.dart';
import '../modelos/sensor.dart';
import '../servicios/sensa_api.dart';
import '../tema.dart';
import '../vistamodelos/historial_vm.dart';
import 'widgets/comunes.dart';
import 'widgets/menu_cuenta.dart';

/// Pantalla "Historial": los reportes diarios guardados de cada sensor, con
/// su fecha, para consultarlos después.
class HistorialVista extends StatelessWidget {
  const HistorialVista({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<SensaApi>();

    return ChangeNotifierProvider<HistorialVm>(
      create: (_) => HistorialVm(api)..cargar(),
      child: const _Cuerpo(),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HistorialVm>();

    return RefreshIndicator(
      onRefresh: () => vm.cargar(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
        children: [
          EncabezadoPantalla(
            key: const ValueKey('encabezado'),
            superior: 'Sensa',
            titulo: 'Historial',
            inferior: vm.seleccionado == null
                ? 'Reportes diarios guardados'
                : 'Reportes guardados de ${vm.seleccionado!.nombre}',
            accion: const MenuCuenta(),
          ),
          const SizedBox(height: 16),

          if (vm.sensores.isNotEmpty) ...[
            Wrap(
              key: const ValueKey('filtros'),
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (vm.sensores.length > 1) _SelectorSensor(vm: vm),
                _SelectorRango(vm: vm),
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (vm.error != null) ...[
            CajaError(
              key: const ValueKey('error'),
              mensaje: vm.error!,
              alReintentar: () => vm.cargar(),
            ),
            const SizedBox(height: 16),
          ],

          if (vm.cargando && !vm.hayReportes)
            const Padding(
              key: ValueKey('cargando'),
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (vm.sensores.isEmpty && vm.error == null)
            const Padding(
              key: ValueKey('sin-sensores'),
              padding: EdgeInsets.only(top: 40),
              child: Vacio(
                titulo: 'Sin sensores',
                detalle: 'Cuando haya un nodo registrado, aquí aparecen sus '
                    'reportes de cada día.',
                icono: Icons.history_rounded,
              ),
            )
          else if (!vm.hayReportes && vm.error == null)
            const Padding(
              key: ValueKey('sin-reportes'),
              padding: EdgeInsets.only(top: 30),
              child: Vacio(
                titulo: 'Todavía no hay reportes guardados',
                detalle: 'El servidor guarda el reporte de cada día a las '
                    '00:10. Para guardar uno antes, usa "Generar" en '
                    'Reporte del día o en el Panel.',
                icono: Icons.history_rounded,
              ),
            )
          else if (vm.hayReportes) ...[
            _Resumen(key: const ValueKey('resumen'), vm: vm),
            const SizedBox(height: 18),
            Padding(
              key: const ValueKey('titulo-lista'),
              padding: const EdgeInsets.only(left: 2, bottom: 10),
              child: Text(
                vm.reportes.length == 1
                    ? '1 reporte'
                    : '${vm.reportes.length} reportes',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: ColoresSensa.tintaTenue,
                ),
              ),
            ),
            for (final reporte in vm.reportes) ...[
              _TarjetaDia(
                key: ValueKey('dia-${reporte.fecha.toIso8601String()}'),
                reporte: reporte,
                alTocar: () => _verDetalle(context, vm, reporte),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }

  void _verDetalle(BuildContext context, HistorialVm vm, ReporteDiario r) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: ColoresSensa.superficie,
      builder: (_) => _DetalleDia(
        reporte: r,
        sensor: vm.seleccionado?.nombre ?? '',
      ),
    );
  }
}

// ------------------------------------------------------------ filtros

class _SelectorSensor extends StatelessWidget {
  const _SelectorSensor({required this.vm});

  final HistorialVm vm;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SensorEstado>(
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
            const Icon(Icons.sensors_rounded, size: 16),
            const SizedBox(width: 7),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Text(
                vm.seleccionado?.nombre ?? 'Elige un sensor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

/// "Últimos 7 / 14 / 30": cuántos reportes traer.
class _SelectorRango extends StatelessWidget {
  const _SelectorRango({required this.vm});

  final HistorialVm vm;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<int>(
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      segments: [
        for (final n in HistorialVm.rangos)
          ButtonSegment<int>(value: n, label: Text('Últimos $n')),
      ],
      selected: {vm.dias},
      onSelectionChanged: (elegidos) => vm.elegirDias(elegidos.first),
    );
  }
}

// ------------------------------------------------------------- resumen

/// Números de todo el rango: lo más frío, lo más caliente y las alertas.
class _Resumen extends StatelessWidget {
  const _Resumen({super.key, required this.vm});

  final HistorialVm vm;

  @override
  Widget build(BuildContext context) {
    final alertas = vm.alertasDelRango;

    return Tarjeta(
      borde: alertas > 0 ? ColoresSensa.ambar : null,
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _rangoDeFechas(vm.reportes),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Cifra(
                  etiqueta: 'Mínima',
                  valor: _grados(vm.minimaDelRango),
                ),
              ),
              Expanded(
                child: _Cifra(
                  etiqueta: 'Promedio',
                  valor: _grados(vm.promedioDelRango),
                ),
              ),
              Expanded(
                child: _Cifra(
                  etiqueta: 'Máxima',
                  valor: _grados(vm.maximaDelRango),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                alertas > 0
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
                size: 17,
                color: alertas > 0 ? ColoresSensa.ambarTexto : ColoresSensa.verde,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alertas > 0
                      ? '$alertas ${alertas == 1 ? 'lectura' : 'lecturas'} '
                          'en alerta, en ${vm.diasConAlerta} de '
                          '${vm.reportes.length} días.'
                      : 'Ninguna alerta en estos días.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: alertas > 0
                        ? ColoresSensa.ambarTexto
                        : ColoresSensa.verde,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_miles(vm.lecturasDelRango)} lecturas válidas en total.',
            style: const TextStyle(
              fontSize: 12,
              color: ColoresSensa.tintaTenue,
            ),
          ),
        ],
      ),
    );
  }

  static String _rangoDeFechas(List<ReporteDiario> reportes) {
    // Vienen del más nuevo al más viejo.
    final nuevo = reportes.first.fecha;
    final viejo = reportes.last.fecha;
    if (reportes.length == 1) return Formato.fechaLarga(nuevo);
    return 'Del ${Formato.fechaCorta(viejo)} al ${Formato.fechaCorta(nuevo)}';
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta.toUpperCase(),
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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------- un día

/// Un reporte en la lista: fecha, rango de temperatura y alertas.
class _TarjetaDia extends StatelessWidget {
  const _TarjetaDia({
    super.key,
    required this.reporte,
    required this.alTocar,
  });

  final ReporteDiario reporte;
  final VoidCallback alTocar;

  /// El reporte de hoy todavía no está cerrado: se recalcula cada vez que
  /// alguien abre "Reporte del día" o toca "Generar".
  bool get _esHoy {
    final hoy = DateTime.now();
    return reporte.fecha.year == hoy.year &&
        reporte.fecha.month == hoy.month &&
        reporte.fecha.day == hoy.day;
  }

  @override
  Widget build(BuildContext context) {
    final conAlerta = reporte.alertas > 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: alTocar,
      child: Tarjeta(
        borde: conAlerta ? ColoresSensa.ambar : null,
        relleno: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        hijo: Row(
          children: [
            _Calendario(fecha: reporte.fecha),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _esHoy
                        ? 'Hoy · en curso'
                        : Formato.fechaLarga(reporte.fecha),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_grados(reporte.tempMin)} a ${_grados(reporte.tempMax)}'
                    '  ·  prom. ${_grados(reporte.tempProm)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: ColoresSensa.tinta,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (conAlerta)
                    ChipEstado.alerta(
                      texto: reporte.alertas == 1
                          ? '1 alerta'
                          : '${reporte.alertas} alertas',
                    )
                  else
                    const ChipEstado.normal(texto: 'Sin alertas'),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: ColoresSensa.tintaTenue,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cuadrito con el día y el mes, como hoja de calendario.
class _Calendario extends StatelessWidget {
  const _Calendario({required this.fecha});

  final DateTime fecha;

  static const List<String> _meses = [
    'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN',
    'JUL', 'AGO', 'SEP', 'OCT', 'NOV', 'DIC',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: ColoresSensa.indigoTenue,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            _meses[fecha.month - 1],
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: ColoresSensa.indigo,
            ),
          ),
          Text(
            '${fecha.day}',
            style: const TextStyle(
              fontSize: 20,
              height: 1.15,
              fontWeight: FontWeight.w700,
              color: ColoresSensa.indigoOscuro,
            ),
          ),
        ],
      ),
    );
  }
}

/// Todo el reporte de un día, en una hoja de abajo.
class _DetalleDia extends StatelessWidget {
  const _DetalleDia({required this.reporte, required this.sensor});

  final ReporteDiario reporte;
  final String sensor;

  @override
  Widget build(BuildContext context) {
    final generado = reporte.generadoEn;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Formato.fechaLarga(reporte.fecha),
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            if (sensor.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                sensor,
                style: const TextStyle(
                  fontSize: 13,
                  color: ColoresSensa.tintaTenue,
                ),
              ),
            ],
            const SizedBox(height: 18),
            _Renglon('Temperatura mínima', _grados(reporte.tempMin)),
            _Renglon('Temperatura máxima', _grados(reporte.tempMax)),
            _Renglon('Temperatura promedio', _grados(reporte.tempProm)),
            _Renglon(
              'Humedad promedio',
              '${reporte.humProm.toStringAsFixed(0)} % HR',
            ),
            _Renglon('Lecturas válidas', _miles(reporte.lecturasValidas)),
            _Renglon(
              'Lecturas en alerta',
              _miles(reporte.alertas),
              destacado: reporte.alertas > 0,
            ),
            _Renglon(
              'Veces que se prendió el LED',
              _miles(reporte.activacionesLed),
            ),
            if (generado != null) ...[
              const SizedBox(height: 14),
              Text(
                'Guardado el ${Formato.fechaCorta(generado.toLocal())} a las '
                '${Formato.hora(generado)}.',
                style: const TextStyle(
                  fontSize: 12,
                  color: ColoresSensa.tintaTenue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon(this.etiqueta, this.valor, {this.destacado = false});

  final String etiqueta;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final color = destacado ? ColoresSensa.ambarTexto : ColoresSensa.tinta;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0ECE2))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: const TextStyle(fontSize: 13.5, color: ColoresSensa.tintaTenue),
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- formatos

String _grados(double? valor) =>
    valor == null ? '--' : '${valor.toStringAsFixed(1)} °C';

/// 12345 -> "12 345", para que los conteos grandes se lean de un vistazo.
String _miles(int n) {
  final texto = '$n';
  final partes = <String>[];
  for (var fin = texto.length; fin > 0; fin -= 3) {
    final inicio = fin - 3 < 0 ? 0 : fin - 3;
    partes.insert(0, texto.substring(inicio, fin));
  }
  return partes.join(' ');
}
