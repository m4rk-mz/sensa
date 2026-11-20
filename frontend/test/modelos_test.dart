import 'package:flutter_test/flutter_test.dart';
import 'package:sensa_app/modelos/comando.dart';
import 'package:sensa_app/modelos/panel.dart';
import 'package:sensa_app/modelos/reporte.dart';
import 'package:sensa_app/modelos/sensor.dart';
import 'package:sensa_app/modelos/usuario.dart';

/// Lee las respuestas tal como las devuelve el backend (nombres de campo
/// del contrato) y comprueba que la app no se caiga con campos nulos.
void main() {
  test('login', () {
    final sesion = Sesion.desdeJson(<String, dynamic>{
      'access_token': 'jwt.de.prueba',
      'token_type': 'bearer',
      'expira_en': '2026-11-20T12:00:00Z',
      'usuario': <String, dynamic>{
        'id': '3f2b1c9e-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
        'nombre': 'Ana Medina',
        'email': 'usuario@friosdelnorte.mx',
        'rol': 'business_user',
        'business_id': '1a2b3c4d-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
        'activo': true,
      },
    });

    expect(sesion.token, 'jwt.de.prueba');
    expect(sesion.usuario.esAdmin, isFalse);
    expect(sesion.expiraEn, isNotNull);
  });

  test('el rol de administrador se reconoce', () {
    final usuario = Usuario.desdeJson(<String, dynamic>{
      'id': '3f2b1c9e-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
      'nombre': 'Sensa',
      'email': 'admin@sensa.mx',
      'rol': 'platform_admin',
      'business_id': null,
    });

    expect(usuario.esAdmin, isTrue);
    expect(usuario.businessId, isNull);
  });

  test('estado del sensor con alerta', () {
    final estado = SensorEstado.desdeJson(<String, dynamic>{
      'sensor': <String, dynamic>{
        'id': '3f2b1c9e-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
        'business_id': '1a2b3c4d-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
        'nombre': 'Cuarto de servidor',
        'umbral_c': 27.0,
        'led_estado_real': true,
        'activo': true,
      },
      'temperatura': 29.4,
      'humedad': 58.0,
      'alerta': true,
      'led_estado_real': true,
      'led_deseado': true,
      'modo': 'automatico',
      'en_linea': true,
    });

    expect(estado.alerta, isTrue);
    expect(estado.esManual, isFalse);
    expect(estado.umbralC, 27.0);
    expect(estado.nombre, 'Cuarto de servidor');
  });

  test('estado sin lecturas no truena', () {
    final estado = SensorEstado.desdeJson(<String, dynamic>{
      'sensor': <String, dynamic>{
        'id': '3f2b1c9e-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
        'business_id': '1a2b3c4d-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
        'nombre': 'Cocina',
        'umbral_c': 27.0,
      },
      'temperatura': null,
      'humedad': null,
      'en_linea': false,
    });

    expect(estado.temperatura, isNull);
    expect(estado.sinDatos, isTrue);
  });

  test('estados del comando', () {
    final comando = Comando.desdeJson(<String, dynamic>{
      'id': '3f2b1c9e-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
      'device_id': '1a2b3c4d-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
      'accion': 'led_on',
      'estado': 'sin_respuesta',
      'creado_en': '2026-11-19T23:00:00Z',
    });

    expect(comando.sinRespuesta, isTrue);
    expect(comando.confirmado, isFalse);
    expect(comando.accionLegible, 'Encender el LED');
  });

  test('reporte del día sin datos trae mensaje', () {
    final reporte = ReporteDelDia.desdeJson(<String, dynamic>{
      'device_id': '3f2b1c9e-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
      'sensor_nombre': 'Cuarto de servidor',
      'fecha': '2026-11-19',
      'reporte': null,
      'mensaje': 'Todavía no hay lecturas válidas para este día.',
    });

    expect(reporte.tieneDatos, isFalse);
    expect(reporte.mensaje, isNotNull);
  });

  test('panel del administrador', () {
    final panel = PanelAdmin.desdeJson(<String, dynamic>{
      'generado_en': '2026-11-19T23:30:00Z',
      'total_negocios': 2,
      'total_sensores': 3,
      'total_usuarios': 4,
      'lecturas_validas_24h': 120,
      'lecturas_descartadas_24h': 2,
      'alertas_24h': 3,
      'tabla': <dynamic>[
        <String, dynamic>{
          'business_id': '1a2b3c4d-1a2b-4c3d-9e8f-7a6b5c4d3e2f',
          'negocio': 'Fríos del Norte',
          'sensores': 2,
          'usuarios': 2,
          'lecturas_24h': 100,
          'temp_promedio': 25.6,
          'temp_max': 29.4,
          'alertas_24h': 3,
          'sensores_en_linea': 1,
        },
      ],
      'grafica_temp_promedio': <dynamic>[
        <String, dynamic>{'etiqueta': 'Fríos del Norte', 'valor': 25.6},
      ],
    });

    expect(panel.tabla.length, 1);
    expect(panel.tabla.first.tempPromedio, 25.6);
    expect(panel.lecturasDescartadas24h, 2);
    expect(panel.graficaTempPromedio.first.etiqueta, 'Fríos del Norte');
  });
}
