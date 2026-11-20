# Sensa — Backend

API del proyecto Sensa: monitoreo de temperatura y humedad por negocio, con
control del LED de alerta desde la app y reporte diario calculado en el
servidor.

**Stack:** FastAPI (Python) + Supabase (PostgreSQL por REST) + Argon2id + JWT.

---

## 1. Arquitectura MC

| Carpeta | Papel |
|---|---|
| `app/models/` | Capa **M**: estructura y validación. Valida lo que entra y también lo que sale de la BD. |
| `app/controllers/` | Capa **C**: endpoints y permisos. Un endpoint no toca la BD directo. |
| `app/repositories/` | Acceso a datos con el cliente de Supabase. Todo lo que devuelve ya pasó por un modelo. |
| `app/services/` | Reglas compartidas: lógica del LED, reporte diario, panel del admin. |
| `app/deps.py` | Autenticación y permisos (sesión, rol, pertenencia al negocio, token del sensor). |
| `app/security.py` | Argon2id, JWT y tokens de sensor. |
| `sql/` | Esquema y datos para las pruebas. |
| `scripts/` | Inicialización del primer administrador. |

Regla que atraviesa todo: **el rol y el negocio se leen de la base de datos a
partir de la sesión**, nunca del formulario ni del token.

---

## 2. Cómo correrlo

### 2.1 Base de datos

1. Crear un proyecto en [supabase.com](https://supabase.com) (plan gratis).
2. SQL Editor → pegar y ejecutar `sql/01_schema.sql`.
3. Project Settings → API → copiar `Project URL` y la llave `service_role`.

### 2.2 Backend

```bash
cd sensa-backend
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env               # Windows: copy .env.example .env
# Llenar SUPABASE_URL, SUPABASE_SERVICE_KEY y JWT_SECRET
python -c "import secrets; print(secrets.token_urlsafe(48))"   # para JWT_SECRET
```

### 2.3 Primer administrador y datos de prueba

```bash
python -m scripts.seed_admin --email admin@sensa.mx --password "Admin1234" --demo
```

Crea el administrador de plataforma, un negocio de prueba, un usuario de ese
negocio y un sensor. **Imprime el token del sensor una sola vez**: cópialo al
firmware del ESP32.

Luego, para tener lecturas en el panel y el registro inválido de la prueba 5:
SQL Editor → ejecutar `sql/02_pruebas.sql`.

### 2.4 Levantar la API

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- Documentación interactiva: http://localhost:8000/docs
- Desde el celular o el ESP32, usar la IP de la computadora en la red local
  (`http://192.168.x.x:8000`), no `localhost`.

---

## 3. Cuentas y datos de prueba

| Rol | Correo | Contraseña |
|---|---|---|
| Administrador de plataforma | `admin@sensa.mx` | `Admin1234` |
| Usuario de negocio (Fríos del Norte) | `usuario@friosdelnorte.mx` | `Usuario1234` |

| Dato | Valor |
|---|---|
| Negocio de prueba | Fríos del Norte |
| Sensor | Nodo cuarto de servidor, umbral 27.0 °C |
| Token del sensor | se muestra al correr el seed (no se guarda en claro) |

---

## 4. Endpoints

Autenticación de usuario: `Authorization: Bearer <token>`.
Autenticación del nodo: `X-Device-Token: sensa.<device_id>.<secreto>`.

### Sesión

| Método | Ruta | Quién | Qué hace |
|---|---|---|---|
| POST | `/auth/login` | público | Devuelve el JWT y el usuario (sin hash). |
| GET | `/me` | usuario | Usuario y rol tal como están en la BD. |
| POST | `/auth/password` | usuario | Cambia su propia contraseña. |

### Negocios

| Método | Ruta | Quién | Qué hace |
|---|---|---|---|
| POST | `/businesses` | admin | Alta de negocio (opcionalmente con su primer usuario). |
| GET | `/businesses` | usuario | Admin: todos. Usuario: solo el suyo. |
| GET | `/businesses/{id}` | usuario del negocio o admin | Datos del negocio. |
| POST | `/businesses/{id}/users` | admin | Alta de usuario de negocio. |
| GET | `/businesses/{id}/users` | usuario del negocio o admin | Usuarios del negocio. |
| POST | `/businesses/{id}/devices` | admin | Registra un sensor; devuelve el token una sola vez. |
| GET | `/businesses/{id}/devices` | usuario del negocio o admin | Sensores del negocio. |

### Sensores y lecturas

| Método | Ruta | Quién | Qué hace |
|---|---|---|---|
| GET | `/devices` | usuario | Pantalla "Mis sensores": última lectura, alerta, LED, en línea. |
| GET | `/devices/{id}` | usuario del negocio | Estado de un sensor. |
| PATCH | `/devices/{id}` | usuario del negocio (baja: admin) | Cambia nombre o umbral. |
| POST | `/devices/{id}/readings` | **nodo** | Guarda la lectura y responde el estado deseado del LED. |
| GET | `/devices/{id}/readings` | usuario del negocio | Lecturas **válidas** del periodo (`?horas=24&limite=100`). |

### Actuador (LED)

| Método | Ruta | Quién | Qué hace |
|---|---|---|---|
| POST | `/devices/{id}/command` | usuario del negocio | `led_on`, `led_off` o `auto`. |
| GET | `/devices/{id}/command` | **nodo** | Comando pendiente + estado deseado y umbral. |
| POST | `/devices/{id}/ack` | **nodo** | Confirma que aplicó el comando. |
| GET | `/devices/{id}/commands` | usuario del negocio | Último comando y su estado. |

### Reportes y panel

| Método | Ruta | Quién | Qué hace |
|---|---|---|---|
| GET | `/devices/{id}/reporte-diario` | usuario del negocio | Reporte del día (`?fecha=2026-11-17`). |
| GET | `/devices/{id}/reportes` | usuario del negocio | Últimos días. |
| GET | `/admin/users` | admin | Usuarios, con filtro por negocio. |
| POST | `/admin/users/{id}/promover` | admin | Promueve a administrador de plataforma. |
| GET | `/admin/stats/negocios` | admin | Tabla + gráfica + conteo de registros descartados. |
| GET | `/admin/stats/temp-promedio-por-negocio` | admin | Serie de la gráfica. |
| POST | `/admin/reportes/generar` | admin | Dispara el reporte diario a mano (para la demo). |

---

## 5. Cómo funciona el LED

- **Automático:** el LED se enciende si la última temperatura supera el umbral
  del sensor.
- **Manual:** `POST /devices/{id}/command` con `led_on` o `led_off` fuerza el
  estado por `MANUAL_MODE_MINUTES` (30 por omisión) y después vuelve solo a
  automático. `auto` lo regresa de inmediato.
- **Estados del comando:** `pendiente` → `enviado` (cuando el nodo lo recoge)
  → `confirmado`. Si pasan `COMMAND_TIMEOUT_SECONDS` (15) sin confirmación,
  queda `sin_respuesta`.
- El nodo reporta su LED real en cada lectura, así que un comando también se
  confirma por lectura, no solo por el ack.
- `GET /devices/{id}/command` siempre devuelve el umbral vigente, para que el
  ESP32 pueda seguir en automático si el backend no responde.

### Contrato para el firmware

```
# cada 30 s
POST /devices/<ID>/readings
     X-Device-Token: sensa.<ID>.<secreto>
     {"temperatura": 24.5, "humedad": 55.0, "led_estado": false}
  -> {"led_deseado": true, "umbral_c": 27.0, "modo": "manual", ...}

# cada 2-5 s
GET  /devices/<ID>/command
     X-Device-Token: ...
  -> {"comando": {"id": "...", "accion": "led_on", ...}, "led_deseado": true, ...}

POST /devices/<ID>/ack
     {"comando_id": "...", "led_estado": true}
```

---

## 6. Reporte diario

Lo calcula el backend con APScheduler, todos los días a las 00:10 de
`America/Mexico_City`, para el día anterior. Por sensor guarda temperatura
mínima, máxima y promedio, humedad promedio, número de lecturas válidas,
alertas y activaciones del LED, en `daily_reports` (única por sensor y fecha).

Solo usa **lecturas válidas**. El reporte de *hoy* se calcula al momento cuando
la app lo pide, así la pantalla "Reporte del día" nunca sale vacía esperando la
medianoche.

---

## 7. Las pruebas de la sección 9 del documento

| # | Prueba | Dónde se cumple |
|---|---|---|
| 1 | Login con ambas cuentas y una contraseña incorrecta | `POST /auth/login`. Mismo mensaje y tiempo parecido para correo inexistente y contraseña mala. |
| 2 | Promover a administrador y que persista | `POST /admin/users/{id}/promover` escribe el rol en la BD; `usuario_actual` relee el rol en cada petición, así que el cambio se nota al volver a entrar. |
| 3 | Dato inválido en el formulario | Validación en el VistaModelo de la app; los mismos rangos viven en `app/models/`. |
| 4 | Dato inválido directo a la API | Los modelos `EntradaModel` rechazan con 422 y `extra="forbid"`; nada se guarda. Probar con curl: ver abajo. |
| 5 | Registro inválido insertado en la BD | `sql/02_pruebas.sql` lo inserta. `validar_filas` lo descarta al leer, así que no sale en `/devices/{id}/readings`, ni en el reporte, ni en el panel. El panel reporta cuántos descartó en `lecturas_descartadas_24h`. |
| 6 | Panel del admin con tabla y gráfica | `GET /admin/stats/negocios`. Solo lecturas válidas de 24 h. |
| 7 | Flujo IoT completo | `POST /devices/{id}/readings` → el backend decide alerta y LED → `GET /devices/{id}/command` → `POST /devices/{id}/ack` → la app ve el estado confirmado. |
| 8 | Acceso a datos de otro negocio | `sensor_del_usuario` y `negocio_permitido` responden **404** si el recurso no es del negocio del usuario: cambiar el id en la URL no alcanza. |

> **Nota para la prueba 5:** el documento de clase da como ejemplo un usuario
> con edad negativa en `/users`. Sensa no tiene ni ruta `/users` ni campo de
> edad. Las rutas equivalentes son `GET /admin/users` y
> `GET /businesses/{id}/users`. La tabla `users` tiene CHECK, así que la
> prueba se hace con una lectura inválida (`sql/02_pruebas.sql`).

### Prueba 4 con curl

```bash
# Temperatura fuera del rango del DHT11: el backend la rechaza
curl -i -X POST http://localhost:8000/devices/<ID>/readings \
  -H "X-Device-Token: sensa.<ID>.<secreto>" \
  -H "Content-Type: application/json" \
  -d '{"temperatura": 999, "humedad": 50}'
# -> 422, y la lectura no se guarda

# Intento de mandar el rol en el alta de usuario
curl -i -X POST http://localhost:8000/businesses/<BID>/users \
  -H "Authorization: Bearer <TOKEN_ADMIN>" \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Prueba","email":"p@x.mx","password":"Prueba1234","rol":"platform_admin"}'
# -> 422: el modelo no acepta campos extra. El rol lo decide el backend.
```

### Prueba 8 con curl

```bash
# Usuario del negocio A pidiendo un sensor del negocio B
curl -i http://localhost:8000/devices/<ID_DE_OTRO_NEGOCIO> \
  -H "Authorization: Bearer <TOKEN_USUARIO>"
# -> 404 Recurso no encontrado
```

---

## 8. Pruebas automatizadas

```bash
python -m tests.test_offline
```

Corren sin red y sin Supabase: `tests/fake_supabase.py` imita al cliente con
una base en memoria. Verifican hashes Argon2id, tokens, aislamiento entre
negocios, descarte de lecturas inválidas, estados del comando del LED,
aritmética del reporte diario y los conteos del panel. Son el respaldo de las
pruebas 2, 5, 6, 7 y 8 de la demo.

Si `argon2-cffi` no está instalado, las pruebas usan el sustituto de
`tests/argon2_stub.py` (Argon2id de `cryptography`, mismo formato PHC). El
backend siempre usa `argon2-cffi`.

---

## 9. Seguridad

- Contraseñas con **Argon2id** (`argon2-cffi`), parámetros en `app/security.py`.
  El script del primer administrador usa el mismo hasher, así que los hashes
  son compatibles con el login.
- Ninguna respuesta incluye contraseñas ni hashes: `UsuarioSalida` no tiene esos
  campos y el hash solo se lee en el login.
- El token del sensor se guarda **hasheado**. Si se pierde, hay que registrar el
  sensor otra vez.
- Las tablas tienen RLS activado sin políticas: la llave `anon` no lee nada
  desde fuera. El backend usa `service_role` y aplica los permisos en los
  controladores.
- La llave `service_role` vive solo en `.env` del servidor, nunca en la app
  Flutter.

---

## 10. Pendientes del backend

- [ ] Correo o push cuando hay alerta (fuera del alcance del parcial).
- [ ] Rotar el token de un sensor sin borrarlo.
- [ ] Pruebas automatizadas con `pytest` y un proyecto de Supabase aparte.
