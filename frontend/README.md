# Sensa — App móvil (Flutter, MVVM)

App de Sensa para las dos cuentas del proyecto: el **usuario del negocio**
(sus sensores, acciones en el nodo y reporte del día) y el **administrador
de plataforma** (panel, negocios y promoción de usuarios).

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

### Android bloquea HTTP sin TLS

Desde Android 9, una app no puede hablar por `http://` a menos que lo
permitas. El backend de la demo corre sin TLS, así que hay que habilitarlo
en el manifiesto de depuración (solo si usas `http://`, por ejemplo una PC en
la red local; con Render por `https://` no hace falta). El permiso `INTERNET`
siempre es necesario, así que no lo quites al editar el archivo. Abre
`android/app/src/debug/AndroidManifest.xml` (lo crea `flutter create`) y
deja la etiqueta `application` así:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <application android:usesCleartextTraffic="true" />
</manifest>
```

Ese archivo solo aplica al build de depuración (`flutter run`). Para un APK de
release hay que poner el permiso en el manifest principal,
`android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Síntoma de que falta: la app abre pero el login responde "No se pudo
conectar con el servidor".

### Correr contra Render (https)

Con el backend en Render no hace falta `usesCleartextTraffic`. Solo hay que
apuntar la app a la URL pública:

```bash
flutter run --dart-define=SENSA_API=https://sensa-2kse.onrender.com
```

En Android Studio, esto va en Run → Edit Configurations → *Additional run
args*. La primera petición puede tardar hasta un minuto si el plan gratuito
de Render estaba dormido.

### Compilar un APK para compañeros

```bash
flutter build apk --dart-define=SENSA_API=https://sensa-2kse.onrender.com
```

El archivo queda en `build/app/outputs/flutter-apk/app-release.apk` y se
instala en cualquier Android. Recuerda el permiso `INTERNET` del manifest
principal, o la app no podrá conectarse.

Otras dos cosas que tumban la conexión:

- **uvicorn escuchando solo en localhost.** Levántalo con
  `--host 0.0.0.0`, no con el valor por omisión.
- **Teléfono físico en otra red o firewall cerrado.** El teléfono y la
  computadora tienen que estar en la misma red y el puerto 8000 abierto.
  Para comprobarlo rápido, abre `http://<ip-de-la-compu>:8000/health` en el
  navegador del teléfono: debe responder `{"estado":"ok", ...}`.

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
   alerta, sin datos) y acceso al detalle. Se refresca cada 5 s.
3. **Detalle del sensor** — la temperatura en grande con su estado y
   cuándo llegó, humedad y umbral, **acciones en el nodo** (mandar alerta y
   probar LEDs) con el estado del comando (`pendiente`, `enviado`,
   `confirmado`, `sin_respuesta`), el umbral editable y la tabla de
   **lecturas registradas**, como se ven en la tabla `readings`. Se refresca
   cada 2 s (la tabla cada 6 s).
4. **Reporte del día** — mínima, promedio y máxima, gráfica de la
   temperatura por hora con la línea del umbral, alertas y veces que se
   encendió el LED. Botón **Generar** para guardar el reporte de hoy al
   momento, sin esperar a la tarea de las 00:10.
5. **Tu cuenta** — cambio de contraseña, salir y una prueba de conexión con
   el servidor, útil cuando una pantalla no carga.

**Administrador de plataforma**

1. **Panel** — indicadores, gráfica de temperatura promedio por negocio y
   tabla por negocio, más cuántas lecturas inválidas se descartaron en 24 h
   (la evidencia de la prueba 5). Incluye un botón para disparar el reporte
   diario sin esperar las 00:10.
2. **Sensores** — los de todos los negocios, cada uno con la opción de
   **eliminarlo** (se va con sus lecturas, comandos y reportes; pide
   confirmación). Sirve para limpiar nodos de prueba que ya no existen.
3. **Negocios** — lista, alta (con primer usuario opcional) y registro de
   nodos; el token del nodo se muestra **una sola vez**.
4. **Usuarios** — filtro por negocio, promoción a administrador y
   **dar de baja o reactivar** usuarios, con diálogo de confirmación. Dar de
   baja no borra nada: le quita el acceso y su sesión abierta deja de valer.

## El LED va siempre en automático

La app ya no enciende ni apaga el LED a mano. El nodo lo decide solo con el
umbral del sensor, así que sigue avisando aunque se quede sin red, y no hay
forma de dejarlo forzado por error. Si un sensor quedó en modo manual de una
versión anterior, el detalle le manda `auto` una vez al abrirlo.

El backend sigue aceptando `led_on`, `led_off` y `auto`: el contrato no
cambia y el flujo IoT completo (comando -> ack) se demuestra con **mandar
alerta** y **probar LEDs**.

## Refrescos y rendimiento

- El detalle pide una sola cosa por vuelta (`GET /devices/{id}`); el último
  comando solo se pide al abrir la pantalla y después de mandar una acción.
- Al abrir el detalle, la lista deja de refrescarse; se reanuda al volver.
- Con la app en segundo plano se detienen todos los refrescos y se reanudan
  al volver al frente (`VmConRefresco` en `vistamodelos/base_vm.dart`).

## Avisos de abajo (SnackBar)

Van por `core/mensajes.dart`, que guarda la llave del `ScaffoldMessenger`
del `MaterialApp`. Antes cada pantalla llamaba `ScaffoldMessenger.of(context)`,
a veces después de un `await`; si para entonces ese widget ya no estaba en el
árbol, Flutter tiraba la pantalla roja con
`'_dependents.isEmpty': is not true`. Con la llave no hace falta contexto.

## Pruebas

```bash
flutter test
```

- `test/validaciones_test.dart` — las reglas de los formularios.
- `test/modelos_test.dart` — lectura de las respuestas del backend (con
  campos nulos) y las acciones del nodo: `alerta` y `probar_leds` no son
  comandos del LED.
