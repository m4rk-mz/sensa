"""Controlador del reporte diario (pantalla "Reporte del día")."""
from __future__ import annotations

from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.deps import sensor_del_usuario
from app.models.device import Sensor
from app.models.report import ReporteDiario, ReporteDiarioSalida
from app.repositories import reports as repo_reports
from app.services import daily_report as servicio_reporte

router = APIRouter(prefix="/devices", tags=["reportes"])


@router.get("/{device_id}/reporte-diario", response_model=ReporteDiarioSalida)
def reporte_diario(
    fecha: Optional[date] = Query(default=None, description="Por omisión, hoy."),
    sensor: Sensor = Depends(sensor_del_usuario),
) -> ReporteDiarioSalida:
    """Reporte del día del sensor.

    El de días anteriores lo deja listo la tarea programada. El de hoy se
    calcula al momento con las lecturas válidas que ya hay.
    """
    dia = fecha or servicio_reporte.hoy_local()

    guardado = repo_reports.por_device_y_fecha(sensor.id, dia)
    if guardado is None or dia == servicio_reporte.hoy_local():
        calculado = servicio_reporte.generar_para_sensor(sensor.id, dia)
        guardado = calculado or guardado

    return ReporteDiarioSalida(
        device_id=sensor.id,
        sensor_nombre=sensor.nombre,
        fecha=dia,
        reporte=guardado,
        mensaje=None if guardado else "Todavía no hay lecturas válidas para este día.",
    )


@router.get("/{device_id}/reportes", response_model=list[ReporteDiario])
def historial_reportes(
    dias: int = Query(default=7, ge=1, le=31),
    sensor: Sensor = Depends(sensor_del_usuario),
) -> list[ReporteDiario]:
    return repo_reports.ultimos_por_device(sensor.id, limite=dias)
