"""Acceso a datos del reporte diario."""
from __future__ import annotations

from datetime import date
from typing import Optional

from app.db.client import table
from app.models.common import validar_filas
from app.models.report import ReporteDiario

TABLA = "daily_reports"
CAMPOS = (
    "id,device_id,fecha,temp_min,temp_max,temp_prom,hum_prom,"
    "lecturas_validas,alertas,activaciones_led,generado_en"
)


def guardar(reporte: ReporteDiario) -> Optional[ReporteDiario]:
    """Inserta o reemplaza el reporte del día (único por sensor y fecha)."""
    datos = reporte.model_dump(exclude={"id", "generado_en"})
    datos["fecha"] = reporte.fecha.isoformat()
    res = table(TABLA).upsert(datos, on_conflict="device_id,fecha").execute()
    filas = validar_filas(ReporteDiario, res.data)
    return filas[0] if filas else None


def por_device_y_fecha(device_id: str, fecha: date) -> Optional[ReporteDiario]:
    res = (
        table(TABLA)
        .select(CAMPOS)
        .eq("device_id", device_id)
        .eq("fecha", fecha.isoformat())
        .limit(1)
        .execute()
    )
    filas = validar_filas(ReporteDiario, res.data)
    return filas[0] if filas else None


def ultimos_por_device(device_id: str, limite: int = 7) -> list[ReporteDiario]:
    res = (
        table(TABLA)
        .select(CAMPOS)
        .eq("device_id", device_id)
        .order("fecha", desc=True)
        .limit(limite)
        .execute()
    )
    return validar_filas(ReporteDiario, res.data)
