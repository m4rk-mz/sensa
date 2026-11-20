import 'package:flutter/material.dart';

import '../../tema.dart';
import '../../vistamodelos/reporte_vm.dart';

/// Gráfica de la temperatura por hora, con la línea del umbral.
///
/// Es una línea (no barras) porque muestra cómo cambió la temperatura a lo
/// largo del día: así el eje puede empezar arriba de cero sin engañar. Las
/// horas que pasaron el umbral se marcan con un punto ámbar, además de
/// quedar por encima de la línea punteada.
class GraficaLinea extends StatelessWidget {
  const GraficaLinea({
    super.key,
    required this.puntos,
    required this.umbral,
    this.alto = 160,
  });

  final List<PromedioHora> puntos;
  final double umbral;
  final double alto;

  @override
  Widget build(BuildContext context) {
    if (puntos.isEmpty) {
      return SizedBox(
        height: alto,
        child: const Center(
          child: Text(
            'Todavía no hay lecturas de hoy.',
            style: TextStyle(fontSize: 13, color: ColoresSensa.tintaTenue),
          ),
        ),
      );
    }

    final temperaturas = puntos.map((p) => p.promedio).toList();
    final menor = temperaturas.reduce((a, b) => a < b ? a : b);
    final mayor = temperaturas.reduce((a, b) => a > b ? a : b);
    final minimoEje = (menor < umbral ? menor : umbral) - 1.5;
    final maximoEje = (mayor > umbral ? mayor : umbral) + 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 30,
              height: alto,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _EtiquetaEje(maximoEje.toStringAsFixed(0)),
                  _EtiquetaEje(
                    umbral.toStringAsFixed(0),
                    color: ColoresSensa.ambarTexto,
                  ),
                  _EtiquetaEje(minimoEje.toStringAsFixed(0)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: alto,
                child: CustomPaint(
                  painter: _PintorLinea(
                    puntos: puntos,
                    umbral: umbral,
                    minimo: minimoEje,
                    maximo: maximoEje,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 38),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _EtiquetaEje('${_dosDigitos(puntos.first.hora)} h'),
              if (puntos.length > 2)
                _EtiquetaEje('${_dosDigitos(puntos[puntos.length ~/ 2].hora)} h'),
              _EtiquetaEje('${_dosDigitos(puntos.last.hora)} h'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            _ClaveLeyenda(color: ColoresSensa.indigo, texto: 'Promedio por hora'),
            _ClaveLeyenda(color: ColoresSensa.ambar, texto: 'Hora con alerta'),
          ],
        ),
      ],
    );
  }

  static String _dosDigitos(int valor) => valor.toString().padLeft(2, '0');
}

class _EtiquetaEje extends StatelessWidget {
  const _EtiquetaEje(this.texto, {this.color});

  final String texto;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      style: TextStyle(
        fontSize: 10.5,
        color: color ?? ColoresSensa.tintaTenue,
      ),
    );
  }
}

class _ClaveLeyenda extends StatelessWidget {
  const _ClaveLeyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: const TextStyle(fontSize: 11.5, color: Color(0xFF3A3747)),
        ),
      ],
    );
  }
}

class _PintorLinea extends CustomPainter {
  _PintorLinea({
    required this.puntos,
    required this.umbral,
    required this.minimo,
    required this.maximo,
  });

  final List<PromedioHora> puntos;
  final double umbral;
  final double minimo;
  final double maximo;

  @override
  void paint(Canvas lienzo, Size tamano) {
    final rango = (maximo - minimo).abs() < 0.001 ? 1.0 : maximo - minimo;

    double y(double valor) =>
        tamano.height - ((valor - minimo) / rango) * tamano.height;
    double x(int indice) => puntos.length == 1
        ? tamano.width / 2
        : (indice / (puntos.length - 1)) * tamano.width;

    // Piso y techo del área de dibujo.
    final guia = Paint()
      ..color = ColoresSensa.borde
      ..strokeWidth = 1;
    lienzo.drawLine(
      Offset(0, tamano.height - 0.5),
      Offset(tamano.width, tamano.height - 0.5),
      guia,
    );

    // Línea punteada del umbral.
    final pincelUmbral = Paint()
      ..color = const Color(0xFFC98A3C)
      ..strokeWidth = 1.5;
    final alturaUmbral = y(umbral);
    const anchoGuion = 6.0;
    const anchoHueco = 5.0;
    double cursor = 0;
    while (cursor < tamano.width) {
      lienzo.drawLine(
        Offset(cursor, alturaUmbral),
        Offset(
          (cursor + anchoGuion).clamp(0, tamano.width).toDouble(),
          alturaUmbral,
        ),
        pincelUmbral,
      );
      cursor += anchoGuion + anchoHueco;
    }

    // Área bajo la línea.
    final trazo = Path();
    for (var i = 0; i < puntos.length; i++) {
      final punto = Offset(x(i), y(puntos[i].promedio));
      if (i == 0) {
        trazo.moveTo(punto.dx, punto.dy);
      } else {
        trazo.lineTo(punto.dx, punto.dy);
      }
    }

    final area = Path.from(trazo)
      ..lineTo(x(puntos.length - 1), tamano.height)
      ..lineTo(x(0), tamano.height)
      ..close();
    lienzo.drawPath(
      area,
      Paint()..color = const Color(0x1A4338CA),
    );

    lienzo.drawPath(
      trazo,
      Paint()
        ..color = ColoresSensa.indigo
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );

    // Puntos: ámbar donde hubo alerta.
    for (var i = 0; i < puntos.length; i++) {
      final punto = puntos[i];
      final centro = Offset(x(i), y(punto.promedio));
      lienzo.drawCircle(centro, 4.5, Paint()..color = Colors.white);
      lienzo.drawCircle(
        centro,
        punto.alerta ? 4 : 3,
        Paint()..color = punto.alerta ? ColoresSensa.ambar : ColoresSensa.indigo,
      );
    }
  }

  @override
  bool shouldRepaint(_PintorLinea anterior) =>
      anterior.puntos != puntos ||
      anterior.umbral != umbral ||
      anterior.minimo != minimo ||
      anterior.maximo != maximo;
}
