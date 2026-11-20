import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formato.dart';
import '../core/validaciones.dart';
import '../modelos/comando.dart';
import '../modelos/sensor.dart';
import '../tema.dart';
import '../vistamodelos/sensor_detalle_vm.dart';
import 'widgets/comunes.dart';

/// Detalle de un sensor: lectura, control del LED y umbral.
class SensorDetalleVista extends StatelessWidget {
  const SensorDetalleVista({super.key, required this.nombreInicial});

  final String nombreInicial;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SensorDetalleVm>();
    final estado = vm.estado;

    return Scaffold(
      appBar: AppBar(
        title: Text(estado?.nombre ?? nombreInicial),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => vm.cargar(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => vm.cargar(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            if (vm.error != null) ...[
              CajaError(mensaje: vm.error!, alReintentar: () => vm.cargar()),
              const SizedBox(height: 16),
            ],

            if (estado == null)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Text(
                '${estado.enLinea ? 'En línea' : 'Sin reportar'} · '
                '${Formato.haceCuanto(estado.ultimaLecturaEn)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ColoresSensa.tintaTenue,
                ),
              ),
              const SizedBox(height: 14),

              if (estado.alerta) ...[
                _AvisoAlerta(estado: estado),
                const SizedBox(height: 13),
              ],

              Tarjeta(
                hijo: Row(
                  children: [
                    Dato(
                      etiqueta: 'Temperatura',
                      valor: Formato.temperatura(estado.temperatura),
                    ),
                    const SizedBox(width: 26),
                    Dato(
                      etiqueta: 'Humedad',
                      valor: Formato.humedad(estado.humedad),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),

              _TarjetaLed(vm: vm, estado: estado),
              const SizedBox(height: 13),

              _TarjetaUmbral(vm: vm, estado: estado),
            ],
          ],
        ),
      ),
    );
  }
}

class _AvisoAlerta extends StatelessWidget {
  const _AvisoAlerta({required this.estado});

  final SensorEstado estado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: ColoresSensa.ambarTenue,
        border: Border.all(color: const Color(0xFFEBC489)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: ColoresSensa.ambarTexto,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alerta activa desde las '
                  '${Formato.hora(estado.ultimaLecturaEn)}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6F3C06),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${Formato.temperatura(estado.temperatura)}, por encima del '
                  'umbral de ${estado.umbralC.toStringAsFixed(1)} °C.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF6F3C06),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Control del LED: automático, encender o apagar, con el estado del
/// comando que devuelve el backend.
class _TarjetaLed extends StatelessWidget {
  const _TarjetaLed({required this.vm, required this.estado});

  final SensorDetalleVm vm;
  final SensorEstado estado;

  String get _seleccion {
    if (!estado.esManual) return AccionLed.automatico;
    return (estado.sensor.ledForzado ?? false)
        ? AccionLed.encender
        : AccionLed.apagar;
  }

  @override
  Widget build(BuildContext context) {
    final comando = vm.ultimoComando;

    return Tarjeta(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Expanded(
                child: Text(
                  'Control del LED',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              if (comando != null) _ChipComando(comando: comando),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: const <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: AccionLed.automatico,
                label: Text('Automático'),
              ),
              ButtonSegment<String>(
                value: AccionLed.encender,
                label: Text('Encender'),
              ),
              ButtonSegment<String>(
                value: AccionLed.apagar,
                label: Text('Apagar'),
              ),
            ],
            selected: <String>{_seleccion},
            showSelectedIcon: false,
            onSelectionChanged: vm.enviandoComando
                ? null
                : (seleccion) => _enviar(context, seleccion.first),
          ),
          const SizedBox(height: 11),
          Text(
            estado.esManual
                ? 'En modo manual. Vuelve a automático '
                    '${Formato.faltanPara(estado.modoManualHasta)}.'
                : 'En automático: el LED sigue el umbral del negocio. '
                    'Forzarlo a mano dura 30 min y luego regresa solo.',
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: Color(0xFF3A3747),
            ),
          ),
          if (comando != null && comando.sinRespuesta) ...[
            const SizedBox(height: 10),
            const Text(
              'El nodo no confirmó en 15 s. Revisa que esté encendido y con '
              'red; el backend lo marcó sin respuesta.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: ColoresSensa.ambarTexto,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _enviar(BuildContext context, String accion) async {
    final mensajero = ScaffoldMessenger.of(context);
    final ok = await vm.enviarComando(accion);
    if (!ok) return;

    mensajero.showSnackBar(
      const SnackBar(
        content: Text('Comando enviado. Esperando que el nodo lo confirme.'),
      ),
    );
  }
}

class _ChipComando extends StatelessWidget {
  const _ChipComando({required this.comando});

  final Comando comando;

  @override
  Widget build(BuildContext context) {
    if (comando.confirmado) {
      return ChipEstado.normal(
        texto: 'Confirmado ${Formato.haceCuanto(comando.confirmadoEn)}',
      );
    }
    if (comando.sinRespuesta) {
      return const ChipEstado.alerta(texto: 'Sin respuesta');
    }
    return const ChipEstado.neutro(texto: 'Enviado, sin confirmar');
  }
}

/// Umbral del sensor, con edición validada.
class _TarjetaUmbral extends StatelessWidget {
  const _TarjetaUmbral({required this.vm, required this.estado});

  final SensorDetalleVm vm;
  final SensorEstado estado;

  @override
  Widget build(BuildContext context) {
    return Tarjeta(
      relleno: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      hijo: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Umbral del sensor',
                  style: TextStyle(fontSize: 12, color: ColoresSensa.tintaTenue),
                ),
                Text(
                  '${estado.umbralC.toStringAsFixed(1)} °C',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _editar(context),
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  Future<void> _editar(BuildContext context) async {
    final controlador = TextEditingController(
      text: estado.umbralC.toStringAsFixed(1),
    );
    final formulario = GlobalKey<FormState>();

    final nuevo = await showDialog<String>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('Umbral de alerta'),
        content: Form(
          key: formulario,
          child: TextFormField(
            controller: controlador,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Grados centígrados',
              helperText: 'El DHT11 mide de 0 a 50 °C.',
            ),
            validator: Validaciones.umbral,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogo).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formulario.currentState!.validate()) {
                Navigator.of(dialogo).pop(controlador.text);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    controlador.dispose();
    if (nuevo == null) return;

    final mensajero = ScaffoldMessenger.of(context);
    final ok = await vm.cambiarUmbral(nuevo);
    mensajero.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Umbral actualizado. El nodo lo recibe en su próxima lectura.'
              : vm.error ?? 'No se pudo actualizar el umbral.',
        ),
      ),
    );
  }
}
