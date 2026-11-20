import 'package:flutter_test/flutter_test.dart';
import 'package:sensa_app/modelos/lineas_lcd.dart';
import 'package:sensa_app/modelos/sensor.dart';

SensorEstado _estado({
  required double temperatura,
  required double humedad,
  required bool alerta,
  String modo = 'automatico',
  bool ledEncendido = false,
  double umbral = 27.0,
}) {
  return SensorEstado(
    sensor: Sensor(
      id: '3f2b1c9e-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
      businessId: '1a2b3c4d-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
      nombre: 'Cuarto de servidor',
      umbralC: umbral,
      ledEstadoReal: ledEncendido,
    ),
    temperatura: temperatura,
    humedad: humedad,
    alerta: alerta,
    ledEstadoReal: ledEncendido,
    modo: modo,
    enLinea: true,
  );
}

/// La app muestra lo mismo que la LCD 1602 del nodo, así que el texto tiene
/// que caber en 16 columnas y decir lo mismo que el firmware.
void main() {
  test('sin alerta hay una sola pantalla', () {
    final vistas = LineasLcd.de(
      _estado(temperatura: 24.1, humedad: 52, alerta: false),
    );

    expect(vistas.length, 1);
    expect(vistas.first.linea1, 'T:24.1C H:52%');
    expect(vistas.first.linea2, 'AUTO    LED:OFF');
  });

  test('en modo manual la segunda línea dice MANUAL', () {
    final vistas = LineasLcd.de(
      _estado(
        temperatura: 24.1,
        humedad: 52,
        alerta: false,
        modo: 'manual',
        ledEncendido: true,
      ),
    );

    expect(vistas.first.linea2, 'MANUAL  LED:ON');
  });

  test('en alerta alterna el aviso con la lectura', () {
    final vistas = LineasLcd.de(
      _estado(
        temperatura: 29.4,
        humedad: 58,
        alerta: true,
        ledEncendido: true,
      ),
    );

    expect(vistas.length, 2);
    expect(vistas[0].linea1, '!ALERTA! 29.4C');
    expect(vistas[0].linea2, 'Umbral 27.0C');
    expect(vistas[1].linea1, 'T:29.4C H:58%');
  });

  test('sin lecturas no se inventa nada', () {
    final vistas = LineasLcd.de(
      SensorEstado(
        sensor: Sensor(
          id: '3f2b1c9e-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
          businessId: '1a2b3c4d-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
          nombre: 'Cocina',
          umbralC: 27,
        ),
      ),
    );

    expect(vistas.length, 1);
    expect(vistas.first.linea2, 'Sin lecturas');
  });

  test('ningún renglón pasa de 16 caracteres', () {
    final casos = <SensorEstado>[
      _estado(temperatura: 49.9, humedad: 89, alerta: true, umbral: 50),
      _estado(temperatura: 0.0, humedad: 20, alerta: false),
      _estado(
        temperatura: 30.5,
        humedad: 75,
        alerta: true,
        modo: 'manual',
        ledEncendido: true,
      ),
    ];

    for (final estado in casos) {
      for (final vista in LineasLcd.de(estado)) {
        expect(vista.linea1.length, lessThanOrEqualTo(LineasLcd.columnas));
        expect(vista.linea2.length, lessThanOrEqualTo(LineasLcd.columnas));
      }
    }
  });
}
