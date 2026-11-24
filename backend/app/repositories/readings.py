"""Acceso a datos de lecturas.

`listar` devuelve dos cosas: las lecturas válidas y cuántas se
descartaron por no cumplir el modelo. El segundo número alimenta el panel
del administrador y sirve de evidencia en la prueba 5 de la demo.
"""
from __future__ import annotations

import time
from datetime import datetime
from typing import Optional

from app.db.client import table
from app.models.common import validar_filas
from app.models.reading import Lectura

TABLA = "readings"
CAMPOS = "id,device_id,temperatura,humedad,led_reportado,alerta,creado_en"

# El nodo pregunta por comandos cada segundo y cada respuesta necesita la
# última lectura. Como las lecturas entran por este mismo proceso, se guarda
# aquí la última de cada sensor y se evita una consulta por segundo contra
# Supabase. El TTL cubre el caso de que alguien escriba por fuera.
_ultima_por_device: dict[str, tuple[float, Optional[Lectura]]] = {}
SEGUNDOS_CACHE_ULTIMA = 10.0


def _recordar_ultima(device_id: str, lectura: Optional[Lectura]) -> None:
    _ultima_por_device[device_id] = (time.monotonic(), lectura)


def olvidar_cache(device_id: Optional[str] = None) -> None:
    """Borra la caché (de un sensor o de todos). Útil en pruebas."""
    if device_id is None:
        _ultima_por_device.clear()
    else:
        _ultima_por_device.pop(device_id, None)


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
    creada = filas[0] if filas else None
    if creada is not None:
        _recordar_ultima(device_id, creada)
    return creada


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
    """Última lectura válida. Si la más reciente es inválida, se salta.

    Responde desde la caché mientras esté fresca: el nodo consulta cada
    segundo y la lectura solo cambia cuando él mismo la manda.
    """
    guardada = _ultima_por_device.get(device_id)
    if guardada is not None:
        cuando, lectura = guardada
        if time.monotonic() - cuando < SEGUNDOS_CACHE_ULTIMA:
            return lectura

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
    reciente = validas[0] if validas else None
    _recordar_ultima(device_id, reciente)
    return reciente


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
