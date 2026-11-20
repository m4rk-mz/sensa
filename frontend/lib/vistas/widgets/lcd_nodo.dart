import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../modelos/lineas_lcd.dart';
import '../../tema.dart';

/// Reproduce la pantalla LCD 1602 del nodo.
///
/// Si hay alerta, el firmware alterna dos pantallas cada 3 s (el aviso con
/// el umbral y la lectura); aquí se alterna igual, para que la app muestre
/// lo mismo que ve quien está frente al equipo.
class LcdNodo extends StatefulWidget {
  const LcdNodo({super.key, required this.vistas});

  final List<VistaLcd> vistas;

  @override
  State<LcdNodo> createState() => _LcdNodoState();
}

class _LcdNodoState extends State<LcdNodo> {
  int _indice = 0;
  Timer? _temporizador;

  @override
  void initState() {
    super.initState();
    _ajustarTemporizador();
  }

  @override
  void didUpdateWidget(LcdNodo anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.vistas.length != widget.vistas.length) {
      _indice = 0;
      _ajustarTemporizador();
    }
  }

  void _ajustarTemporizador() {
    _temporizador?.cancel();
    _temporizador = null;
    if (widget.vistas.length < 2) return;

    _temporizador = Timer.periodic(Config.alternanciaLcd, (_) {
      if (!mounted) return;
      setState(() => _indice = (_indice + 1) % widget.vistas.length);
    });
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.vistas.isEmpty) return const SizedBox.shrink();

    final vista = widget.vistas[_indice % widget.vistas.length];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: ColoresSensa.lcdFondo,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Renglon(vista.linea1),
          const SizedBox(height: 2),
          _Renglon(vista.linea2),
        ],
      ),
    );
  }
}

class _Renglon extends StatelessWidget {
  const _Renglon(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: const TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: <String>['Courier', 'Menlo'],
        fontSize: 17,
        height: 1.4,
        letterSpacing: 1.4,
        color: ColoresSensa.lcdTexto,
      ),
    );
  }
}
