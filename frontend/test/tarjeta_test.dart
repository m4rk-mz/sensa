import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensa_app/modelos/sensor.dart';
import 'package:sensa_app/tema.dart';
import 'package:sensa_app/vistas/widgets/comunes.dart';

void main() {
  // La tarjeta de un sensor en alerta lleva barra ámbar a la izquierda.
  // Antes se pintaba con un borde de colores distintos más esquinas
  // redondas, Flutter lanzaba una excepción al pintar y la tarjeta salía
  // en blanco. Esta prueba falla si vuelve a pasar.
  testWidgets('tarjeta en alerta se pinta con su contenido', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Tarjeta(
            borde: ColoresSensa.ambar,
            hijo: Text('26.3 °C'),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('26.3 °C'), findsOneWidget);
  });

  // Al cambiar el umbral la alerta se prende o se apaga. La tarjeta debe
  // conservar su contenido (mismo estado) en vez de rehacerlo.
  testWidgets('prender y apagar la alerta no rehace el contenido',
      (tester) async {
    Widget tarjeta(Color? borde) => MaterialApp(
          home: Scaffold(
            body: Tarjeta(borde: borde, hijo: const _Contador()),
          ),
        );

    await tester.pumpWidget(tarjeta(ColoresSensa.ambar));
    final antes = tester.state(find.byType(_Contador));
    await tester.pumpWidget(tarjeta(null));
    await tester.pumpWidget(tarjeta(ColoresSensa.ambar));

    expect(tester.takeException(), isNull);
    expect(tester.state(find.byType(_Contador)), same(antes));
  });

  test('la firma cambia solo si cambia lo que se ve', () {
    Map<String, dynamic> json(double temp) => <String, dynamic>{
          'sensor': <String, dynamic>{
            'id': 'a',
            'business_id': 'b',
            'nombre': 'Nodo',
            'umbral_c': 24.0,
          },
          'temperatura': temp,
          'humedad': 60,
          'alerta': temp > 24,
          'en_linea': true,
          'ultima_lectura_en': '2026-11-25T15:32:10Z',
        };

    final a = SensorEstado.desdeJson(json(26.3));
    final b = SensorEstado.desdeJson(json(26.3));
    final c = SensorEstado.desdeJson(json(26.4));

    expect(a.firma, b.firma);
    expect(a.firma, isNot(c.firma));
  });
}

class _Contador extends StatefulWidget {
  const _Contador();

  @override
  State<_Contador> createState() => _ContadorEstado();
}

class _ContadorEstado extends State<_Contador> {
  @override
  Widget build(BuildContext context) => const Text('contenido');
}
