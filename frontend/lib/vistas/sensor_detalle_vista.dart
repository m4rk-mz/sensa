import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formato.dart';
import '../core/mensajes.dart';
import '../core/validaciones.dart';
import '../modelos/comando.dart';
import '../modelos/sensor.dart';
import '../tema.dart';
import '../vistamodelos/sensor_detalle_vm.dart';
import 'widgets/comunes.dart';

/// Detalle de un sensor: lectura en vivo, acciones en el nodo y umbral.
///
/// El LED trabaja siempre en automático con el umbral del sensor, así que
/// esta pantalla ya no lo controla a mano.
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
            onPressed: () => vm.cargar(conComando: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => vm.cargar(conComando: true),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
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
              _TarjetaLectura(estado: estado),
              const SizedBox(height: 13),

              _TarjetaAcciones(vm: vm, estado: estado),
              const SizedBox(height: 13),

              _TarjetaUmbral(vm: vm, estado: estado),
              const SizedBox(height: 16),

              const _NotaAutomatico(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tarjeta principal: la lectura grande, con el estado y cuándo llegó.
class _TarjetaLectura extends StatelessWidget {
  const _TarjetaLectura({required this.estado});

  final SensorEstado estado;

  @override
  Widget build(BuildContext context) {
    final sinDatos = !estado.enLinea;

    return Tarjeta(
      borde: estado.alerta ? ColoresSensa.ambar : null,
      relleno: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (estado.alerta)
                const ChipEstado.alerta()
              else if (sinDatos)
                const ChipEstado.neutro(texto: 'Sin datos')
              else
                const ChipEstado.normal(),
              const Spacer(),
              _Punto(enLinea: estado.enLinea),
              const SizedBox(width: 6),
              Text(
                Formato.haceCuanto(estado.ultimaLecturaEn),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: ColoresSensa.tintaTenue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // La temperatura es el dato que la gente viene a ver: va grande y
          // cambia con una transición suave para que no parpadee.
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            transitionBuilder: (hijo, animacion) => FadeTransition(
              opacity: animacion,
              child: hijo,
            ),
            child: Row(
              key: ValueKey<String>('${estado.temperatura}'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  estado.temperatura == null
                      ? '--'
                      : estado.temperatura!.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 58,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.5,
                    color: estado.alerta
                        ? ColoresSensa.ambarTexto
                        : ColoresSensa.tinta,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 7, left: 4),
                  child: Text(
                    '°C',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w600,
                      color: ColoresSensa.tintaTenue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _Medida(
                  icono: Icons.water_drop_outlined,
                  etiqueta: 'Humedad',
                  valor: Formato.humedad(estado.humedad),
                ),
              ),
              Container(width: 1, height: 34, color: ColoresSensa.borde),
              Expanded(
                child: _Medida(
                  icono: Icons.thermostat_outlined,
                  etiqueta: 'Umbral',
                  valor: '${estado.umbralC.toStringAsFixed(1)} °C',
                  alineadoAlFinal: true,
                ),
              ),
            ],
          ),

          if (estado.alerta) ...[
            const SizedBox(height: 16),
            _AvisoAlerta(estado: estado),
          ],
        ],
      ),
    );
  }
}

/// Punto verde cuando el nodo está reportando, gris cuando no.
class _Punto extends StatelessWidget {
  const _Punto({required this.enLinea});

  final bool enLinea;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: enLinea ? ColoresSensa.verde : const Color(0xFFBDB7AC),
      ),
    );
  }
}

class _Medida extends StatelessWidget {
  const _Medida({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    this.alineadoAlFinal = false,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final bool alineadoAlFinal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alineadoAlFinal ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: ColoresSensa.tintaTenue),
            const SizedBox(width: 5),
            Text(
              etiqueta.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: ColoresSensa.tintaTenue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          valor,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _AvisoAlerta extends StatelessWidget {
  const _AvisoAlerta({required this.estado});

  final SensorEstado estado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: ColoresSensa.ambarTenue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 19,
            color: ColoresSensa.ambarTexto,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Por encima del umbral desde las '
              '${Formato.hora(estado.ultimaLecturaEn)}. El nodo lo está '
              'avisando con el LED rojo y el zumbador.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFF6F3C06),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Acciones de un momento en el nodo: alerta con beeps y prueba de LEDs.
class _TarjetaAcciones extends StatelessWidget {
  const _TarjetaAcciones({required this.vm, required this.estado});

  final SensorDetalleVm vm;
  final SensorEstado estado;

  @override
  Widget build(BuildContext context) {
    final comando = vm.ultimoComando;

    return Tarjeta(
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acciones en el nodo',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _BotonAccion(
                  icono: Icons.campaign_rounded,
                  texto: 'Mandar alerta',
                  destacado: true,
                  cargando: vm.accionEnCurso == AccionNodo.alerta,
                  alTocar: vm.enviandoAccion
                      ? null
                      : () => _enviar(
                            AccionNodo.alerta,
                            'Alerta enviada: el nodo va a sonar.',
                          ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _BotonAccion(
                  icono: Icons.lightbulb_outline_rounded,
                  texto: 'Probar LEDs',
                  destacado: false,
                  cargando: vm.accionEnCurso == AccionNodo.probarLeds,
                  alTocar: vm.enviandoAccion
                      ? null
                      : () => _enviar(
                            AccionNodo.probarLeds,
                            'Prueba enviada: rojo, amarillo y verde.',
                          ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _EstadoAccion(comando: comando, enLinea: estado.enLinea),
        ],
      ),
    );
  }

  Future<void> _enviar(String accion, String aviso) async {
    final ok = await vm.enviarAccion(accion);
    Mensajes.mostrar(ok ? aviso : vm.error ?? 'No se pudo enviar la acción.');
  }
}

class _BotonAccion extends StatelessWidget {
  const _BotonAccion({
    required this.icono,
    required this.texto,
    required this.destacado,
    required this.cargando,
    required this.alTocar,
  });

  final IconData icono;
  final String texto;
  final bool destacado;
  final bool cargando;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final hijo = cargando
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: destacado ? Colors.white : ColoresSensa.indigoOscuro,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 18),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    if (destacado) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: ColoresSensa.ambar,
          minimumSize: const Size.fromHeight(46),
        ),
        onPressed: alTocar,
        child: hijo,
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
      onPressed: alTocar,
      child: hijo,
    );
  }
}

/// En qué va la última acción, sin sacar al usuario de la pantalla.
class _EstadoAccion extends StatelessWidget {
  const _EstadoAccion({required this.comando, required this.enLinea});

  final Comando? comando;
  final bool enLinea;

  @override
  Widget build(BuildContext context) {
    late final IconData icono;
    late final Color color;
    late final String texto;

    if (!enLinea) {
      icono = Icons.cloud_off_rounded;
      color = ColoresSensa.ambarTexto;
      texto = 'El nodo no ha reportado en los últimos 2 minutos: puede que no '
          'reciba la acción.';
    } else if (comando == null || comando!.esDelLed) {
      icono = Icons.info_outline_rounded;
      color = ColoresSensa.tintaTenue;
      texto = 'La alerta da beeps con el LED rojo. La prueba prende rojo, '
          'amarillo y verde, uno por uno.';
    } else if (comando!.confirmado) {
      icono = Icons.check_circle_outline_rounded;
      color = ColoresSensa.verde;
      texto = '${comando!.accionLegible}: el nodo lo aplicó '
          '${Formato.haceCuanto(comando!.confirmadoEn)}.';
    } else if (comando!.sinRespuesta) {
      icono = Icons.error_outline_rounded;
      color = ColoresSensa.ambarTexto;
      texto = '${comando!.accionLegible}: el nodo no confirmó en 15 s. Revisa '
          'que esté encendido y con red.';
    } else {
      icono = Icons.hourglass_top_rounded;
      color = ColoresSensa.tintaTenue;
      texto = '${comando!.accionLegible}: esperando que el nodo lo confirme.';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            texto,
            style: TextStyle(fontSize: 12.5, height: 1.45, color: color),
          ),
        ),
      ],
    );
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
      relleno: const EdgeInsets.fromLTRB(18, 10, 10, 10),
      hijo: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Umbral de alerta',
                  style: TextStyle(fontSize: 12, color: ColoresSensa.tintaTenue),
                ),
                const SizedBox(height: 2),
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

    final ok = await vm.cambiarUmbral(nuevo);
    Mensajes.mostrar(
      ok
          ? 'Umbral actualizado. El nodo lo recibe en su próxima lectura.'
          : vm.error ?? 'No se pudo actualizar el umbral.',
    );
  }
}

/// Explica por qué ya no hay botones de encender y apagar.
class _NotaAutomatico extends StatelessWidget {
  const _NotaAutomatico();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.autorenew_rounded,
          size: 15,
          color: ColoresSensa.tintaTenue,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'El LED del nodo trabaja solo: se enciende cuando la temperatura '
            'pasa el umbral y se apaga cuando baja, aunque el nodo se quede '
            'sin red.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: ColoresSensa.tintaTenue,
            ),
          ),
        ),
      ],
    );
  }
}
