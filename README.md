# Sensa

Monitoreo de temperatura y humedad de los espacios de un negocio desde el
celular. Un nodo ESP32 con DHT11 manda lecturas al backend; si la temperatura
supera el umbral del negocio, un LED avisa en el lugar, y un usuario puede
encenderlo o apagarlo desde la app.

Proyecto del 3er parcial de Aplicaciones móviles.

## Estructura

| Carpeta | Qué hay | Arquitectura |
|---|---|---|
| `backend/` | API en FastAPI + Supabase (PostgreSQL) | MC: modelos y controladores |
| `frontend/` | App móvil en Flutter (usuario del negocio y administrador) | MVVM: Vista y VistaModelo |
| `firmware/` | Nodo ESP32: DHT11, LED de alerta y envío de lecturas | — |

Cada carpeta tiene su propio `README.md` con los pasos para correrla.

## Roles

| Rol | Qué puede hacer |
|---|---|
| Administrador de la plataforma | Ve estadísticas de todos los negocios, da de alta negocios y sensores, y promueve usuarios a administrador. |
| Usuario del negocio | Ve los sensores de su negocio, sus lecturas y el reporte del día. Enciende o apaga el LED. |

El rol se determina en el backend a partir de la sesión y de la base de datos,
nunca desde el formulario. Un usuario no accede a datos de otro negocio aunque
cambie un identificador en la petición.

## Cómo empezar

1. **Base de datos y API:** `backend/README.md` (esquema SQL, variables de
   entorno, seed del primer administrador y cuentas de prueba).
2. **App:** `frontend/README.md`.
3. **Nodo:** `firmware/README.md`.

El contrato de la API que usan la app y el firmware está en
`backend/README.md`, secciones 4 y 5.

## Tecnologías

- **Backend:** Python 3.11+, FastAPI, cliente de Supabase, Argon2id, JWT, APScheduler.
- **Base de datos:** PostgreSQL (Supabase).
- **App:** Flutter.
- **Hardware:** ESP32 + DHT11 + LED.

## Nada de secretos en el repo

Las llaves y contraseñas van en archivos `.env`, ignorados por git. Cada
carpeta trae un `.env.example` con los nombres de las variables.
