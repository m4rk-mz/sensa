# Sensa — App móvil (Flutter, MVVM)

App de Sensa para las dos cuentas del proyecto: el **usuario del negocio**
(sus sensores, control del LED y reporte del día) y el **administrador de
plataforma** (panel, negocios y promoción de usuarios).

Habla con el backend de `../backend` usando el contrato de
`claude/Sensa_backend_contrato.md`. La app no decide permisos: el rol lo
devuelve el backend y cada endpoint lo vuelve a revisar.

## Correr la app

La carpeta trae el código (`lib/`, `test/`, `pubspec.yaml`). Las carpetas de
plataforma no se versionan, así que la primera vez hay que generarlas:

```bash
cd frontend
flutter create . --platforms=android          # genera android/ (y agrega web con --platforms=android,web)
flutter pub get
flutter analyze
flutter test
```

Para levantarla apuntando al backend:

```bash
# Emulador de Android: 10.0.2.2 es la computadora donde corre uvicorn
flutter run --dart-define=SENSA_API=http://10.0.2.2:8000

# Teléfono físico en la misma red: usa la IP de la computadora
flutter run --dart-define=SENSA_API=http://192.168.1.70:8000
```

El backend se levanta con:

```bash
cd ../backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

En Android, para que el emulador acepte `http://` sin TLS, `flutter create`
ya deja el `AndroidManifest.xml` con `usesCleartextTraffic` en depuración.
Si usas un teléfono físico y no conecta, revisa que la computadora y el
teléfono estén en la misma red y que el firewall permita el puerto 8000.

### Cuentas de prueba

Las crea `backend/scripts/seed_admin.py --demo`. En modo depuración la
pantalla de login tiene un atajo para llenarlas:

| Rol | Correo | Contraseña |
|---|---|---|
| Administrador de plataforma | `admin@sensa.mx` | `Admin1234` |
| Usuario de negocio | `usuario@friosdelnorte.mx` | `Usuario1234` |

## Arquitectura (MVVM)

```
lib/
  core/            cliente HTTP, errores, validaciones, formatos, sesión guardada
  modelos/         M: las respuestas del backend como clases de Dart
  servicios/       una llamada por endpoint del contrato (SensaApi)
  vistamodelos/    VM: estado de cada pantalla, validación y llamadas a la API
  vistas/          V: solo pinta y manda eventos al VistaModelo
  tema.dart        paleta de la maqueta (crema, índigo, ámbar)
```

Reglas que se respetan en todo el código:

- **La vista no habla con la API.** Toda pantalla recibe su VistaModelo con
  `provider` y solo lee `cargando`, `error` y los datos ya listos.
- **El VistaModelo valida antes de enviar** con las mismas reglas del
  backend (`core/validaciones.dart`): correo, contraseña de 8 caracteres con
  letra y número, y umbral dentro del rango del DHT11 (0 a 50 °C). Si algo
  está mal, el campo se marca y no se manda la petición.
- **Los errores del backend se muestran campo por campo.** Un 422 trae
  `{"errores": [{"campo", "mensaje"}]}` y el cliente lo convierte en un mapa
  que el VistaModelo expone.
- **El rol nunca se manda desde un formulario.** El alta de usuario no tiene
  campo `rol`; promover es una operación aparte del administrador.

## Pantallas

**Usuario del negocio**

1. **Login** — una sola puerta; según el rol la app abre en sensores o en el
   panel.
2. **Mis sensores** — tarjeta por nodo con lectura, estado (alerta, sin
   alerta, sin datos) y acceso al detalle. Se refresca cada 15 s.
3. **Detalle del sensor** — aviso de alerta con el umbral y la hora,
   temperatura y humedad, la tarjeta **"Lo que se ve en el nodo"**, control
   del LED (automático / encender / apagar) con el estado del comando
   (`pendiente`, `enviado`, `confirmado`, `sin_respuesta`) y el umbral
   editable. Se refresca cada 10 s.
4. **Reporte del día** — mínima, promedio y máxima, gráfica de la
   temperatura por hora con la línea del umbral, alertas y veces que se
   encendió el LED.

**Administrador de plataforma**

1. **Panel** — indicadores, gráfica de temperatura promedio por negocio y
   tabla por negocio, más cuántas lecturas inválidas se descartaron en 24 h
   (la evidencia de la prueba 5). Incluye un botón para disparar el reporte
   diario sin esperar las 00:10.
2. **Sensores** — los de todos los negocios.
3. **Negocios** — lista, alta (con primer usuario opcional) y registro de
   nodos; el token del nodo se muestra **una sola vez**.
4. **Usuarios** — filtro por negocio y promoción a administrador con
   diálogo de confirmación.

## "Lo que se ve en el nodo"

`modelos/lineas_lcd.dart` arma el mismo texto que el firmware escribe en la
LCD 1602, y `vistas/widgets/lcd_nodo.dart` lo pinta:

```
Sin alerta        En alerta (alterna cada 3 s)
T:24.1C H:52%     !ALERTA! 29.4C     T:29.4C H:58%
AUTO    LED:OFF   Umbral 27.0C       AUTO    LED:ON
```

Cada renglón cabe en 16 columnas, y hay pruebas que lo verifican. Si el
firmware cambia ese texto, hay que cambiarlo aquí también: es lo único que
la app duplica a propósito, para que coincida con lo que ve quien está
frente al equipo.

## Pruebas

```bash
flutter test
```

- `test/validaciones_test.dart` — las reglas de los formularios.
- `test/lineas_lcd_test.dart` — el texto de la LCD y el límite de 16
  columnas.
- `test/modelos_test.dart` — lectura de las respuestas del backend, con
  campos nulos incluidos.
