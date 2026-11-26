import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formato.dart';
import '../core/mensajes.dart';
import '../core/validaciones.dart';
import '../modelos/comando.dart';
import '../modelos/lectura.dart';
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
            onPressed: () => vm.cargar(conComando: true, conLecturas: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => vm.cargar(conComando: true, conLecturas: true),
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
              _TarjetaLectura(vm: vm, estado: estado),
              const SizedBox(height: 13),

              _TarjetaAcciones(vm: vm, estado: estado),
              const SizedBox(height: 13),

              _TarjetaLecturas(vm: vm),
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
  const _TarjetaLectura({required this.vm, required this.estado});

  final SensorDetalleVm vm;
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
                  alTocar: () => _editarUmbral(context, vm, estado),
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
    this.alTocar,
  });

  final IconData icono;
  final String etiqueta;
  final String valor;
  final bool alineadoAlFinal;

  /// Si se da, el valor se puede tocar para editarlo (el umbral).
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final contenido = _contenido();
    if (alTocar == null) return contenido;
    return Align(
      alignment:
          alineadoAlFinal ? Alignment.centerRight : Alignment.centerLeft,
      // Material transparente: sin él, el efecto al tocar se pinta debajo
      // del fondo blanco de la tarjeta y no se ve.
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: alTocar,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: contenido,
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              valor,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            if (alTocar != null) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.edit_outlined,
                size: 16,
                color: ColoresSensa.indigo,
              ),
            ],
          ],
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
              'Pasó el umbral de ${estado.umbralC.toStringAsFixed(1)} °C '
              '(lectura de las ${Formato.horaConSegundos(estado.ultimaLecturaEn)}). '
              'El nodo lo está avisando con el LED rojo y el zumbador.',
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
        // Con letra grande del sistema el texto se encoge un poco en vez de
        // cortarse con "...": antes se leía "Mandar al…".
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, size: 18),
                const SizedBox(width: 6),
                Text(texto, maxLines: 1),
              ],
            ),
          );

    const relleno = EdgeInsets.symmetric(horizontal: 10);
    const textoBoton = TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600);

    if (destacado) {
      return FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: ColoresSensa.ambar,
          minimumSize: const Size.fromHeight(46),
          padding: relleno,
          textStyle: textoBoton,
        ),
        onPressed: alTocar,
        child: hijo,
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(46),
        padding: relleno,
        textStyle: textoBoton,
      ),
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

/// Cambia el umbral de alerta, con las mismas reglas del backend.
///
/// Antes tenía su propia tarjeta, que repetía el umbral que ya sale en la
/// tarjeta de la lectura. Ahora se edita tocando ese mismo valor.
Future<void> _editarUmbral(
  BuildContext context,
  SensorDetalleVm vm,
  SensorEstado estado,
) async {
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

/// Las lecturas guardadas, como se ven en la tabla `readings` de la base.
/// Se vuelve a pedir cada pocos segundos, así que la tabla crece sola.
class _TarjetaLecturas extends StatelessWidget {
  const _TarjetaLecturas({required this.vm});

  final SensorDetalleVm vm;

  @override
  Widget build(BuildContext context) {
    final lecturas = vm.lecturas;

    return Tarjeta(
      relleno: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Lecturas registradas',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                lecturas.isEmpty ? '' : 'últimas ${lecturas.length}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: ColoresSensa.tintaTenue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (lecturas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Todavía no hay lecturas guardadas de este sensor.',
                style: TextStyle(
                  fontSize: 13,
                  color: ColoresSensa.tintaTenue,
                ),
              ),
            )
          else ...[
            const _FilaLectura.encabezado(),
            const Divider(height: 12),
            for (var i = 0; i < lecturas.length; i++) ...[
              _FilaLectura(lectura: lecturas[i]),
              if (i < lecturas.length - 1)
                const Divider(height: 1, thickness: 0.6),
            ],
          ],
          const SizedBox(height: 8),
          const Text(
            'Se actualiza sola cada pocos segundos, con lo que el nodo va '
            'guardando. Solo salen las lecturas válidas.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.4,
              color: ColoresSensa.tintaTenue,
            ),
          ),
        ],
      ),
    );
  }
}

/// Un renglón de la tabla. Con [_FilaLectura.encabezado] pinta los títulos.
class _FilaLectura extends StatelessWidget {
  const _FilaLectura({required this.lectura}) : esEncabezado = false;
  const _FilaLectura.encabezado()
      : lectura = null,
        esEncabezado = true;

  final Lectura? lectura;
  final bool esEncabezado;

  @override
  Widget build(BuildContext context) {
    final estilo = esEncabezado
        ? const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: ColoresSensa.tintaTenue,
          )
        : TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: (lectura?.alerta ?? false)
                ? ColoresSensa.ambarTexto
                : ColoresSensa.tinta,
          );

    final hora =
        esEncabezado ? 'HORA' : Formato.horaConSegundos(lectura!.creadoEn);
    final temp = esEncabezado
        ? 'TEMP.'
        : '${lectura!.temperatura.toStringAsFixed(1)} °C';
    final hum = esEncabezado
        ? 'HUM.'
        : '${lectura!.humedad.toStringAsFixed(0)} %';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(width: 84, child: Text(hora, style: estilo)),
          Expanded(child: Text(temp, style: estilo)),
          Expanded(child: Text(hum, style: estilo)),
          SizedBox(
            width: 26,
            child: esEncabezado
                ? const SizedBox.shrink()
                : (lectura!.alerta
                    ? const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: ColoresSensa.ambarTexto,
                      )
                    : const SizedBox.shrink()),
          ),
        ],
      ),
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
