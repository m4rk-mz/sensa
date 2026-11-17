"""Acceso a datos de lecturas.

`listar` devuelve dos cosas: las lecturas válidas y cuántas se
descartaron por no cumplir el modelo. El segundo número alimenta el panel
del administrador y sirve de evidencia en la prueba 5 de la demo.
"""
from __future__ import annotations

from datetime import datetime
from typing import Optional

from app.db.client import table
from app.models.common import validar_filas
from app.models.reading import Lectura

TABLA = "readings"
CAMPOS = "id,device_id,temperatura,humedad,led_reportado,alerta,creado_en"


def crear(
    *,
    device_id: str,
    temperatura: float,
    humedad: float,
    led_reportado: bool,
    alerta: bool,
) -> Optional[Lectura]:
    res = (
        table(TABLA)
        .insert(
            {
                "device_id": device_id,
                "temperatura": temperatura,
                "humedad": humedad,
                "led_reportado": led_reportado,
                "alerta": alerta,
            }
        )
        .execute()
    )
    filas = validar_filas(Lectura, res.data)
    return filas[0] if filas else None


def listar(
    device_id: str,
    *,
    desde: Optional[datetime] = None,
    hasta: Optional[datetime] = None,
    limite: int = 100,
) -> tuple[list[Lectura], int]:
    q = table(TABLA).select(CAMPOS).eq("device_id", device_id)
    if desde is not None:
        q = q.gte("creado_en", desde.isoformat())
    if hasta is not None:
        q = q.lt("creado_en", hasta.isoformat())
    crudas = q.order("creado_en", desc=True).limit(limite).execute().data or []
    validas = validar_filas(Lectura, crudas)
    return validas, len(crudas) - len(validas)


def ultima(device_id: str) -> Optional[Lectura]:
    """Última lectura válida. Si la más reciente es inválida, se salta."""
    crudas = (
        table(TABLA)
        .select(CAMPOS)
        .eq("device_id", device_id)
        .order("creado_en", desc=True)
        .limit(10)
        .execute()
        .data
        or []
    )
    validas = validar_filas(Lectura, crudas)
    return validas[0] if validas else None


def listar_por_negocio_desde(
    device_ids: list[str], desde: datetime
) -> tuple[list[Lectura], int]:
    if not device_ids:
        return [], 0
    crudas = (
        table(TABLA)
        .select(CAMPOS)
        .in_("device_id", device_ids)
        .gte("creado_en", desde.isoformat())
        .order("creado_en", desc=True)
        .execute()
        .data
        or []
    )
    validas = validar_filas(Lectura, crudas)
    return validas, len(crudas) - len(validas)
