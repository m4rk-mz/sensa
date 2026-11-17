"""Acceso a datos de sensores."""
from __future__ import annotations

from datetime import datetime
from typing import Any, Optional

from app.db.client import table
from app.models.common import validar_filas
from app.models.device import Sensor

TABLA = "devices"
CAMPOS = (
    "id,business_id,nombre,umbral_c,modo_manual_hasta,led_forzado,"
    "led_estado_real,ultima_lectura_en,activo,creado_en"
)


def crear(
    *, business_id: str, nombre: str, umbral_c: float, token_hash: str
) -> Optional[Sensor]:
    res = (
        table(TABLA)
        .insert(
            {
                "business_id": business_id,
                "nombre": nombre,
                "umbral_c": umbral_c,
                "token_hash": token_hash,
            }
        )
        .execute()
    )
    filas = validar_filas(Sensor, res.data)
    return filas[0] if filas else None


def por_id(device_id: str) -> Optional[Sensor]:
    res = table(TABLA).select(CAMPOS).eq("id", device_id).limit(1).execute()
    filas = validar_filas(Sensor, res.data)
    return filas[0] if filas else None


def token_hash_por_id(device_id: str) -> Optional[str]:
    res = table(TABLA).select("token_hash").eq("id", device_id).limit(1).execute()
    if not res.data:
        return None
    return res.data[0].get("token_hash")


def por_nombre(nombre: str) -> Optional[Sensor]:
    res = table(TABLA).select(CAMPOS).eq("nombre", nombre).limit(1).execute()
    filas = validar_filas(Sensor, res.data)
    return filas[0] if filas else None


def listar_por_negocio(business_id: str) -> list[Sensor]:
    res = (
        table(TABLA)
        .select(CAMPOS)
        .eq("business_id", business_id)
        .order("creado_en", desc=False)
        .execute()
    )
    return validar_filas(Sensor, res.data)


def listar_todos() -> list[Sensor]:
    res = table(TABLA).select(CAMPOS).order("creado_en", desc=False).execute()
    return validar_filas(Sensor, res.data)


def actualizar(device_id: str, cambios: dict[str, Any]) -> Optional[Sensor]:
    cambios = {k: v for k, v in cambios.items() if v is not None}
    if not cambios:
        return por_id(device_id)
    res = table(TABLA).update(cambios).eq("id", device_id).execute()
    filas = validar_filas(Sensor, res.data)
    return filas[0] if filas else None


def fijar_modo_manual(
    device_id: str, *, hasta: Optional[datetime], led_forzado: Optional[bool]
) -> Optional[Sensor]:
    """Activa el modo manual (hasta/led_forzado) o lo limpia con None/None."""
    res = (
        table(TABLA)
        .update(
            {
                "modo_manual_hasta": hasta.isoformat() if hasta else None,
                "led_forzado": led_forzado,
            }
        )
        .eq("id", device_id)
        .execute()
    )
    filas = validar_filas(Sensor, res.data)
    return filas[0] if filas else None


def registrar_estado_nodo(
    device_id: str, *, led_estado_real: bool, ultima_lectura_en: datetime
) -> None:
    table(TABLA).update(
        {
            "led_estado_real": led_estado_real,
            "ultima_lectura_en": ultima_lectura_en.isoformat(),
        }
    ).eq("id", device_id).execute()
