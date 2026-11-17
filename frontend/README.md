# Sensa — App móvil (Flutter)

Pendiente de desarrollo. Esta carpeta guarda la app con arquitectura **MVVM**:
la Vista solo dibuja, el VistaModelo coordina la pantalla y valida las entradas.

## Pantallas

**Usuario del negocio**
1. Login
2. Mis sensores — temperatura, humedad, estado del LED y botón de control
3. Reporte del día

**Administrador**
1. Login
2. Panel — tabla y gráfica por negocio
3. Negocios — lista y alta
4. Usuarios — promover a administrador (pide confirmación antes de aplicar)

## Estructura sugerida

```
lib/
  models/          # datos que vienen de la API
  viewmodels/      # un VistaModelo por pantalla: estado y validación
  views/           # widgets de cada pantalla
  services/        # cliente HTTP contra la API y manejo del token
```

## Validación en el VistaModelo

Mismos rangos que el backend, para que el usuario vea el error antes de enviar:

- Temperatura: 0 a 50 °C (umbral del sensor)
- Humedad: 20 a 90 % HR
- Correo con formato válido; contraseña de 8 caracteres con al menos una letra
  y un número
- Campos obligatorios: el botón de enviar queda deshabilitado y se indica qué
  corregir

## Conexión con la API

Base URL en desarrollo: la IP de la computadora que corre el backend en la red
local (`http://192.168.x.x:8000`), no `localhost`, porque el celular es otro
dispositivo.

El token del login va en cada petición:

```
Authorization: Bearer <access_token>
```

El contrato completo de endpoints está en `../backend/README.md`, sección 4.
