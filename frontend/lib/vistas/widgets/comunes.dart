import 'package:flutter/material.dart';

import '../../tema.dart';

/// Etiqueta en mayúsculas sobre un valor grande (temperatura, humedad...).
class Dato extends StatelessWidget {
  const Dato({super.key, required this.etiqueta, required this.valor, this.tamano = 30});

  final String etiqueta;
  final String valor;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta.toUpperCase(),
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: ColoresSensa.tintaTenue,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            fontSize: tamano,
            fontWeight: FontWeight.w700,
            color: ColoresSensa.tinta,
          ),
        ),
      ],
    );
  }
}

/// Chip de estado: alerta (ámbar), normal (verde) o neutro (sin datos).
class ChipEstado extends StatelessWidget {
  const ChipEstado({super.key, required this.texto, required this.tipo});

  const ChipEstado.alerta({super.key, this.texto = 'Alerta'}) : tipo = TipoChip.alerta;
  const ChipEstado.normal({super.key, this.texto = 'Normal'}) : tipo = TipoChip.normal;
  const ChipEstado.neutro({super.key, required this.texto}) : tipo = TipoChip.neutro;

  final String texto;
  final TipoChip tipo;

  @override
  Widget build(BuildContext context) {
    late final Color fondo;
    late final Color color;
    late final IconData? icono;

    switch (tipo) {
      case TipoChip.alerta:
        fondo = ColoresSensa.ambarTenue;
        color = ColoresSensa.ambarTexto;
        icono = Icons.warning_amber_rounded;
        break;
      case TipoChip.normal:
        fondo = ColoresSensa.verdeTenue;
        color = ColoresSensa.verde;
        icono = Icons.check_rounded;
        break;
      case TipoChip.neutro:
        fondo = const Color(0xFFE7E2D8);
        color = const Color(0xFF4A4756);
        icono = null;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            texto.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

enum TipoChip { alerta, normal, neutro }

/// Aviso de error con opción de reintentar.
class CajaError extends StatelessWidget {
  const CajaError({super.key, required this.mensaje, this.alReintentar});

  final String mensaje;
  final VoidCallback? alReintentar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColoresSensa.ambarTenue,
        border: Border.all(color: const Color(0xFFEBC489)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 20,
                color: ColoresSensa.ambarTexto,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  mensaje,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: Color(0xFF6F3C06),
                  ),
                ),
              ),
            ],
          ),
          if (alReintentar != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: alReintentar,
                child: const Text('Reintentar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Estado vacío con un texto corto.
class Vacio extends StatelessWidget {
  const Vacio({super.key, required this.titulo, required this.detalle, this.icono});

  final String titulo;
  final String detalle;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icono ?? Icons.sensors_off_rounded,
              size: 36,
              color: ColoresSensa.tintaTenue,
            ),
            const SizedBox(height: 14),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              detalle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: ColoresSensa.tintaTenue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta blanca con borde, como en la maqueta.
///
/// La barra de color de la alerta se pinta aparte, encima y recortada con
/// las esquinas redondas, y el árbol de widgets es el mismo con alerta y
/// sin ella. Antes iba como el borde izquierdo de un `Border`
/// con colores distintos por lado más `borderRadius`, y Flutter no sabe
/// pintar esa combinación: lanzaba una excepción al pintar y la tarjeta se
/// quedaba en blanco justo cuando el sensor estaba en alerta.
class Tarjeta extends StatelessWidget {
  const Tarjeta({
    super.key,
    required this.hijo,
    this.borde,
    this.relleno = const EdgeInsets.fromLTRB(18, 16, 18, 16),
    this.fondo,
  });

  final Widget hijo;

  /// Barra de color a la izquierda (se usa en alerta).
  final Color? borde;
  final EdgeInsets relleno;
  final Color? fondo;

  static final BorderRadius _radio = BorderRadius.circular(14);

  @override
  Widget build(BuildContext context) {
    // El árbol es el mismo con alerta y sin ella; solo cambian colores y el
    // ancho de la barra. Antes, al prender o apagar la alerta (por ejemplo
    // al cambiar el umbral), la tarjeta cambiaba de forma y Flutter tiraba y
    // volvía a crear todo su contenido.
    final conBarra = borde != null;
    return ClipRRect(
      borderRadius: _radio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fondo ?? ColoresSensa.superficie,
          // Un solo color y un solo grosor: es lo único que Flutter puede
          // pintar junto con esquinas redondas.
          border: Border.all(color: borde ?? ColoresSensa.borde),
          borderRadius: _radio,
        ),
        // passthrough: el contenido recibe el mismo ancho que la tarjeta,
        // igual que cuando era un Container.
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Padding(
              padding: conBarra
                  ? relleno.copyWith(left: relleno.left + 3)
                  : relleno,
              child: hijo,
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: conBarra ? 4 : 0,
              child: ColoredBox(color: borde ?? const Color(0x00000000)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encabezado de pantalla: nombre del negocio arriba y título grande.
class EncabezadoPantalla extends StatelessWidget {
  const EncabezadoPantalla({
    super.key,
    required this.titulo,
    this.superior,
    this.inferior,
    this.accion,
  });

  final String titulo;
  final String? superior;
  final String? inferior;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (superior != null)
                Text(
                  superior!.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: ColoresSensa.tintaTenue,
                  ),
                ),
              const SizedBox(height: 3),
              Text(titulo, style: Theme.of(context).textTheme.headlineSmall),
              if (inferior != null) ...[
                const SizedBox(height: 3),
                Text(inferior!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (accion != null) accion!,
      ],
    );
  }
}
