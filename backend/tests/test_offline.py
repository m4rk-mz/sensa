"""Pruebas sin red: usan la BD falsa de tests/fake_supabase.py.

Correr:  python -m tests.test_offline

Cubren las reglas que el documento de clase pide demostrar:
- contraseñas con Argon2id y tokens de sesión y de sensor,
- aislamiento entre negocios,
- promoción a administrador,
- flujo del LED y estados del comando,
- reporte diario y panel con solo lecturas válidas.
"""
from __future__ import annotations

import logging
import os
import sys
import types
from datetime import datetime, timedelta, timezone

# --- Entorno mínimo para las pruebas --------------------------------------
os.environ.setdefault("SUPABASE_URL", "http://falso")
os.environ.setdefault("SUPABASE_SERVICE_KEY", "falso")
os.environ.setdefault("JWT_SECRET", "secreto-de-prueba")
os.environ.setdefault("ENABLE_SCHEDULER", "false")

from tests import argon2_stub  # noqa: E402

if argon2_stub.instalar_si_falta():
    print("(argon2-cffi no está instalado: se usa el sustituto de pruebas)")

# Módulo falso: así no se necesita el paquete supabase instalado.
if "supabase" not in sys.modules:
    _mod = types.ModuleType("supabase")
    _mod.Client = object
    _mod.create_client = lambda *a, **k: None
    sys.modules["supabase"] = _mod

from app import security  # noqa: E402
from app.models.common import AccionComando, EstadoComando, Rol  # noqa: E402
from app.repositories import businesses as repo_businesses  # noqa: E402
from app.repositories import commands as repo_commands  # noqa: E402
from app.repositories import devices as repo_devices  # noqa: E402
from app.repositories import readings as repo_readings  # noqa: E402
from app.repositories import users as repo_users  # noqa: E402
from app.services import daily_report, led, stats  # noqa: E402
from tests import fake_supabase  # noqa: E402

# Una sola vez, ya cargados los repositorios.
CLIENTE = fake_supabase.instalar()
logging.disable(logging.WARNING)

fallos: list[str] = []


def check(etiqueta: str, condicion: bool, detalle: str = "") -> None:
    if condicion:
        print(f"  ok    {etiqueta}")
    else:
        print(f"  FALLA {etiqueta} {detalle}")
        fallos.append(etiqueta)


def sembrar_lectura(
    device_id: str, temperatura: float, humedad: float, cuando: datetime, umbral: float
) -> None:
    """Inserta una lectura con marca de tiempo controlada (salta el repo)."""
    CLIENTE.table("readings").insert(
        {
            "device_id": device_id,
            "temperatura": temperatura,
            "humedad": humedad,
            "led_reportado": temperatura > umbral,
            "alerta": temperatura > umbral,
            "creado_en": cuando.isoformat(),
        }
    ).execute()


AHORA = datetime.now(timezone.utc)

# ==========================================================================
print("\n1. Alta de negocios, usuarios y sensores")
negocio_a = repo_businesses.crear("Fríos del Norte")
negocio_b = repo_businesses.crear("Panadería La Espiga")

admin = repo_users.crear(
    nombre="Administrador Sensa",
    email="admin@sensa.mx",
    password_hash=security.hash_password("Admin1234"),
    rol=Rol.PLATFORM_ADMIN,
    business_id=None,
)
usuario_a = repo_users.crear(
    nombre="Lupita",
    email="lupita@frios.mx",
    password_hash=security.hash_password("Usuario1234"),
    rol=Rol.BUSINESS_USER,
    business_id=negocio_a.id,
)
usuario_b = repo_users.crear(
    nombre="Beto",
    email="beto@espiga.mx",
    password_hash=security.hash_password("Usuario1234"),
    rol=Rol.BUSINESS_USER,
    business_id=negocio_b.id,
)
check("negocios creados", negocio_a is not None and negocio_b is not None)
check("admin sin negocio", admin is not None and admin.business_id is None)
check("usuarios de negocio creados", usuario_a is not None and usuario_b is not None)

sensor_a = repo_devices.crear(
    business_id=negocio_a.id,
    nombre="Nodo cuarto de servidor",
    umbral_c=27.0,
    token_hash="pendiente",
)
sensor_b = repo_devices.crear(
    business_id=negocio_b.id, nombre="Nodo horno", umbral_c=35.0, token_hash="pendiente"
)
token_a, hash_a = security.generar_token_sensor(sensor_a.id)
repo_devices.actualizar(sensor_a.id, {"token_hash": hash_a})
check("sensores registrados", sensor_a is not None and sensor_b is not None)

# ==========================================================================
print("\n2. Contraseñas y tokens (Argon2id)")
guardado = repo_users.por_email_con_hash("admin@sensa.mx")
check("el hash no es la contraseña", guardado.password_hash != "Admin1234")
check("el hash es Argon2id", guardado.password_hash.startswith("$argon2id$"))
check(
    "contraseña correcta verifica",
    security.verificar_password("Admin1234", guardado.password_hash),
)
check(
    "contraseña incorrecta falla",
    not security.verificar_password("Admin12345", guardado.password_hash),
)

partes = security.partes_token_sensor(token_a)
check("el token del sensor trae su id", partes is not None and partes[0] == sensor_a.id)
check(
    "el secreto del sensor verifica",
    security.verificar_secreto_sensor(
        partes[1], repo_devices.token_hash_por_id(sensor_a.id)
    ),
)
check(
    "un secreto inventado no verifica",
    not security.verificar_secreto_sensor(
        "inventado", repo_devices.token_hash_por_id(sensor_a.id)
    ),
)

tok, _expira = security.crear_token_sesion(
    user_id=usuario_a.id, rol=usuario_a.rol.value, business_id=usuario_a.business_id
)
payload = security.leer_token_sesion(tok)
check("el JWT se lee de vuelta", payload is not None and payload["sub"] == usuario_a.id)
check("un JWT alterado se rechaza", security.leer_token_sesion(tok[:-2] + "xx") is None)

# ==========================================================================
print("\n3. Aislamiento entre negocios (prueba 8 de la demo)")
check(
    "el negocio A solo ve su sensor",
    [s.id for s in repo_devices.listar_por_negocio(negocio_a.id)] == [sensor_a.id],
)
check(
    "el sensor de B no es del negocio de A",
    repo_devices.por_id(sensor_b.id).business_id != usuario_a.business_id,
)
check(
    "los usuarios se listan por negocio",
    [u.id for u in repo_users.listar(negocio_b.id)] == [usuario_b.id],
)

# ==========================================================================
print("\n4. Lecturas: válidas e inválidas (prueba 5 de la demo)")
hoy = daily_report.hoy_local()
inicio_dia, _fin_dia = daily_report._ventana_del_dia(hoy)
base = max(inicio_dia, AHORA - timedelta(hours=3))

for i, (temp, hum) in enumerate([(24.0, 55.0), (29.5, 52.0), (22.0, 58.0), (31.0, 50.0)]):
    sembrar_lectura(sensor_a.id, temp, hum, base + timedelta(minutes=i * 10), 27.0)

# Registro inválido insertado "a mano" en la BD, como en sql/02_pruebas.sql
CLIENTE.table("readings").insert(
    {
        "device_id": sensor_a.id,
        "temperatura": 999.9,
        "humedad": -5.0,
        "led_reportado": False,
        "alerta": False,
        "creado_en": (base + timedelta(minutes=45)).isoformat(),
    }
).execute()

validas, descartadas = repo_readings.listar(sensor_a.id, limite=100)
check("se devuelven 4 lecturas válidas", len(validas) == 4, f"-> {len(validas)}")
check("se descarta 1 lectura inválida", descartadas == 1, f"-> {descartadas}")
check(
    "la lectura inválida no aparece",
    all(l.temperatura <= 50 for l in validas),
)
ultima = repo_readings.ultima(sensor_a.id)
check(
    "la última lectura salta la inválida",
    ultima is not None and ultima.temperatura == 31.0,
    f"-> {ultima.temperatura if ultima else None}",
)

# ==========================================================================
print("\n5. Flujo del LED y estados del comando (prueba 7)")
sensor_a = repo_devices.por_id(sensor_a.id)
check("en automático con 31 °C el LED va encendido", led.led_deseado(sensor_a, temperatura=31.0))
check("en automático con 22 °C el LED va apagado", not led.led_deseado(sensor_a, temperatura=22.0))

sensor_man, comando = led.aplicar_comando(sensor_a, AccionComando.LED_ON, usuario_a.id)
check("el comando nace pendiente", comando.estado is EstadoComando.PENDIENTE)
check("el sensor entra en modo manual", led.modo(sensor_man) == "manual")
check(
    "en manual gana el estado forzado",
    led.led_deseado(sensor_man, temperatura=22.0) is True,
)

repo_commands.marcar_enviado(comando.id, datetime.now(timezone.utc))
check(
    "al recogerlo el nodo queda enviado",
    repo_commands.por_id(comando.id).estado is EstadoComando.ENVIADO,
)

# El nodo reporta su LED real: eso confirma el comando sin ack.
lectura_confirma = repo_readings.crear(
    device_id=sensor_man.id, temperatura=22.0, humedad=55.0, led_reportado=True, alerta=False
)
led.confirmar_por_lectura(sensor_man, lectura_confirma)
check(
    "la lectura del nodo confirma el comando",
    repo_commands.por_id(comando.id).estado is EstadoComando.CONFIRMADO,
)

# Un comando que nadie confirma acaba en sin_respuesta.
_s, comando_mudo = led.aplicar_comando(sensor_man, AccionComando.LED_OFF, usuario_a.id)
CLIENTE.table("actuator_commands").update(
    {"creado_en": (datetime.now(timezone.utc) - timedelta(minutes=5)).isoformat()}
).eq("id", comando_mudo.id).execute()
led.expirar_comandos_vencidos()
check(
    "sin confirmación queda sin_respuesta",
    repo_commands.por_id(comando_mudo.id).estado is EstadoComando.SIN_RESPUESTA,
)

# Volver a automático limpia el modo manual.
sensor_auto, _c = led.aplicar_comando(sensor_man, AccionComando.AUTO, usuario_a.id)
check("la acción auto sale del modo manual", led.modo(sensor_auto) == "automatico")

# ==========================================================================
print("\n6. Reporte diario (solo lecturas válidas)")
reporte = daily_report.generar_para_sensor(sensor_a.id, hoy)
check("se genera el reporte del día", reporte is not None)
if reporte:
    # Lecturas válidas sembradas hoy: 24.0, 29.5, 22.0, 31.0 y la de
    # confirmación (22.0) -> min 22.0, max 31.0.
    check("temp_min correcta", reporte.temp_min == 22.0, f"-> {reporte.temp_min}")
    check("temp_max correcta", reporte.temp_max == 31.0, f"-> {reporte.temp_max}")
    check(
        "la inválida no entra al promedio",
        reporte.temp_min <= reporte.temp_prom <= reporte.temp_max,
        f"-> {reporte.temp_prom}",
    )
    check(
        "alertas contadas (29.5 y 31.0 sobre 27.0)",
        reporte.alertas == 2,
        f"-> {reporte.alertas}",
    )
    check(
        "el conteo ignora la lectura inválida",
        reporte.lecturas_validas == 5,
        f"-> {reporte.lecturas_validas}",
    )

# ==========================================================================
print("\n7. Panel del administrador (prueba 6)")
panel = stats.panel()
check("hay dos negocios en la tabla", len(panel.tabla) == 2, f"-> {len(panel.tabla)}")
check(
    "reporta la lectura descartada",
    panel.lecturas_descartadas_24h == 1,
    f"-> {panel.lecturas_descartadas_24h}",
)
fila_a = next(f for f in panel.tabla if f.business_id == negocio_a.id)
check("la fila de A cuenta su sensor", fila_a.sensores == 1)
check(
    "el promedio de A queda en rango",
    fila_a.temp_promedio is not None and 22.0 <= fila_a.temp_promedio <= 31.0,
    f"-> {fila_a.temp_promedio}",
)
check(
    "la gráfica trae solo negocios con datos",
    [p.etiqueta for p in panel.grafica_temp_promedio] == ["Fríos del Norte"],
    f"-> {[p.etiqueta for p in panel.grafica_temp_promedio]}",
)

# ==========================================================================
print("\n8. Promoción a administrador (prueba 2)")
promovido = repo_users.promover_a_admin(usuario_b.id)
check("el rol cambia a administrador", promovido is not None and promovido.es_admin)
check("se limpia su negocio", promovido.business_id is None)
releido = repo_users.por_id(usuario_b.id)
check(
    "el cambio persiste al releer de la BD",
    releido is not None and releido.rol is Rol.PLATFORM_ADMIN,
)

# ==========================================================================
print("\n9. Ids en la ruta y en el ack (validación de parámetros)")
import re as _re  # noqa: E402
from pydantic import ValidationError as _ValidationError  # noqa: E402
from app.models.common import UUID_REGEX  # noqa: E402
from app.models.command import AckEntrada  # noqa: E402

_patron = _re.compile(UUID_REGEX)
check("un UUID válido pasa el patrón", bool(_patron.match(str(negocio_a.id))))
check("un id mal formado no pasa el patrón", not _patron.match("abc"))
check("un id con inyección no pasa el patrón", not _patron.match("' or 1=1 --"))
try:
    AckEntrada(comando_id="no-es-uuid", led_estado=True)
    check("ack rechaza comando_id que no es UUID", False)
except _ValidationError:
    check("ack rechaza comando_id que no es UUID", True)
check(
    "ack acepta un comando_id UUID",
    AckEntrada(comando_id=str(negocio_a.id), led_estado=True).comando_id == str(negocio_a.id),
)

# ==========================================================================
print()
if fallos:
    print(f"{len(fallos)} prueba(s) con falla:")
    for f in fallos:
        print(f"  - {f}")
    sys.exit(1)
print("Todas las pruebas pasaron.")
