import 'package:flutter_test/flutter_test.dart';
import 'package:sensa_app/core/validaciones.dart';

/// Las mismas reglas que el backend: si estas pruebas pasan, la app señala
/// el error antes de gastar una petición.
void main() {
  group('correo', () {
    test('acepta un correo con dominio', () {
      expect(Validaciones.correo('usuario@friosdelnorte.mx'), isNull);
    });

    test('rechaza uno sin punto en el dominio', () {
      expect(Validaciones.correo('usuario@friosdelnorte'), isNotNull);
    });

    test('rechaza vacío', () {
      expect(Validaciones.correo('   '), isNotNull);
    });
  });

  group('contraseña nueva', () {
    test('acepta 8 caracteres con letra y número', () {
      expect(Validaciones.passwordNueva('Usuario1234'), isNull);
    });

    test('rechaza menos de 8', () {
      expect(Validaciones.passwordNueva('Abc123'), isNotNull);
    });

    test('rechaza sin número', () {
      expect(Validaciones.passwordNueva('contrasena'), isNotNull);
    });

    test('rechaza sin letra', () {
      expect(Validaciones.passwordNueva('12345678'), isNotNull);
    });
  });

  group('umbral', () {
    test('acepta un valor dentro del rango del DHT11', () {
      expect(Validaciones.umbral('27.0'), isNull);
    });

    test('acepta coma decimal', () {
      expect(Validaciones.umbral('27,5'), isNull);
      expect(Validaciones.umbralComoNumero('27,5'), 27.5);
    });

    test('rechaza arriba de 50 °C', () {
      expect(Validaciones.umbral('80'), isNotNull);
    });

    test('rechaza texto', () {
      expect(Validaciones.umbral('mucho calor'), isNotNull);
    });
  });

  group('uuid', () {
    test('acepta un UUID', () {
      expect(
        Validaciones.esUuid('3f2b1c9e-1a2b-4c3d-9e8f-7a6b5c4d3e2f'),
        isTrue,
      );
    });

    test('rechaza un id cualquiera', () {
      expect(Validaciones.esUuid("' or 1=1 --"), isFalse);
    });
  });
}
