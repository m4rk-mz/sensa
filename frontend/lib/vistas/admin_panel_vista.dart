import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/mensajes.dart';
import '../modelos/panel.dart';
import '../servicios/sensa_api.dart';
import '../tema.dart';
import '../vistamodelos/panel_admin_vm.dart';
import 'widgets/comunes.dart';
import 'widgets/menu_cuenta.dart';

/// Panel del administrador de plataforma: indicadores, gráfica y tabla.
class AdminPanelVista extends StatelessWidget {
  const AdminPanelVista({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<SensaApi>();

    return ChangeNotifierProvider<PanelAdminVm>(
      create: (_) => PanelAdminVm(api)..cargar(),
      child: const _Cuerpo(),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PanelAdminVm>();
    final panel = vm.panel;

    if (vm.aviso != null) {
      // Se muestra una vez y se limpia, para no repetirlo en cada rebuild.
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
            titulo: 'Panel',
            accion: MenuCuenta(),
          ),
          const SizedBox(height: 18),

          if (vm.error != null) ...[
            CajaError(mensaje: vm.error!, alReintentar: () => vm.cargar()),
            const SizedBox(height: 18),
          ],

          if (panel == null && vm.cargando)
            const Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            ),

          if (panel != null) ...[
            Row(
              children: [
                Expanded(
                  child: _Indicador(
                    etiqueta: 'Negocios',
                    valor: '${panel.totalNegocios}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Indicador(
                    etiqueta: 'Sensores',
                    valor: '${panel.totalSensores}',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Indicador(
                    etiqueta: 'Alertas 24 h',
                    valor: '${panel.alertas24h}',
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
                    'Temperatura promedio por negocio (°C)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  if (vm.grafica.isEmpty)
                    const Text(
                      'Ningún negocio tiene lecturas válidas en 24 h.',
                      style: TextStyle(
                        fontSize: 13,
                        color: ColoresSensa.tintaTenue,
                      ),
                    )
                  else
                    for (final punto in vm.grafica) ...[
                      _BarraNegocio(punto: punto, maximo: vm.maximoGrafica),
                      const SizedBox(height: 12),
                    ],
                  const Text(
                    'Barras desde cero, con lecturas válidas de las últimas '
                    '24 h.',
                    style: TextStyle(
                      fontSize: 11,
                      color: ColoresSensa.tintaTenue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Tarjeta(
              hijo: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Negocios',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  const _FilaTabla(
                    negocio: 'Negocio',
                    sensores: 'Sens.',
                    alertas: 'Alertas',
                    esEncabezado: true,
                  ),
                  for (final fila in vm.tabla)
                    _FilaTabla(
                      negocio: fila.negocio,
                      sensores: '${fila.sensoresEnLinea}/${fila.sensores}',
                      alertas: '${fila.alertas24h}',
                      enAlerta: fila.alertas24h > 0,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'La tabla y la gráfica solo cuentan lecturas válidas. En las '
              'últimas 24 h se descartaron ${panel.lecturasDescartadas24h} de '
              '${panel.lecturasValidas24h + panel.lecturasDescartadas24h}.',
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: ColoresSensa.tintaTenue,
              ),
            ),
            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: vm.cargando ? null : vm.generarReportes,
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text('Generar reportes diarios ahora'),
            ),
            const SizedBox(height: 8),
            const Text(
              'La tarea programada corre a las 00:10. Este botón la dispara a '
              'mano para la demo.',
              style: TextStyle(
                fontSize: 11.5,
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

class _Indicador extends StatelessWidget {
  const _Indicador({required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      relleno: const EdgeInsets.fromLTRB(13, 13, 10, 13),
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
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _BarraNegocio extends StatelessWidget {
  const _BarraNegocio({required this.punto, required this.maximo});

  final PuntoGrafica punto;
  final double maximo;

  @override
  Widget build(BuildContext context) {
    final fraccion = (punto.valor / maximo).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                punto.etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF3A3747),
                ),
              ),
            ),
            Text(
              punto.valor.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraccion.toDouble(),
            minHeight: 12,
            backgroundColor: const Color(0xFFF2EFE7),
            valueColor: const AlwaysStoppedAnimation<Color>(
              ColoresSensa.indigo,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilaTabla extends StatelessWidget {
  const _FilaTabla({
    required this.negocio,
    required this.sensores,
    required this.alertas,
    this.esEncabezado = false,
    this.enAlerta = false,
  });

  final String negocio;
  final String sensores;
  final String alertas;
  final bool esEncabezado;
  final bool enAlerta;

  @override
  Widget build(BuildContext context) {
    final estilo = esEncabezado
        ? const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
            color: ColoresSensa.tintaTenue,
          )
        : const TextStyle(fontSize: 12.5, color: ColoresSensa.tinta);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: esEncabezado
          ? null
          : const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0ECE2))),
            ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              esEncabezado ? negocio.toUpperCase() : negocio,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: estilo,
            ),
          ),
          SizedBox(
            width: 52,
            child: Text(
              esEncabezado ? sensores.toUpperCase() : sensores,
              textAlign: TextAlign.right,
              style: estilo,
            ),
          ),
          SizedBox(
            width: 58,
            child: Text(
              esEncabezado ? alertas.toUpperCase() : alertas,
              textAlign: TextAlign.right,
              style: enAlerta && !esEncabezado
                  ? const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: ColoresSensa.ambarTexto,
                    )
                  : estilo,
            ),
          ),
        ],
      ),
    );
  }
}
