"""Reporte diario.

Lo calcula el backend (no la app): por sensor y por día saca temperatura
mínima, máxima y promedio, humedad promedio, número de alertas y veces que
se activó el LED. Solo cuenta lecturas válidas.
"""
from __future__ import annotations

import logging
from datetime import date, datetime, time, timedelta
from typing import Optional
from zoneinfo import ZoneInfo

from app.config import settings
from app.models.report import ReporteDiario
from app.repositories import commands as repo_commands
from app.repositories import devices as repo_devices
from app.repositories import readings as repo_readings
from app.repositories import reports as repo_reports

log = logging.getLogger("sensa.reporte")
TZ = ZoneInfo(settings.timezone)


def _ventana_del_dia(fecha: date) -> tuple[datetime, datetime]:
    """Día natural en la zona del negocio, convertido a instantes UTC."""
    inicio = datetime.combine(fecha, time.min, tzinfo=TZ)
    return inicio, inicio + timedelta(days=1)


def generar_para_sensor(device_id: str, fecha: date) -> Optional[ReporteDiario]:
    desde, hasta = _ventana_del_dia(fecha)
    lecturas, descartadas = repo_readings.listar(
        device_id, desde=desde, hasta=hasta, limite=10000
    )
    if descartadas:
        log.info(
            "Reporte %s de %s: %s lecturas inválidas excluidas.",
            fecha,
            device_id,
            descartadas,
        )
    if not lecturas:
        log.info("Reporte %s de %s: sin lecturas válidas.", fecha, device_id)
        return None

    temps = [l.temperatura for l in lecturas]
    hums = [l.humedad for l in lecturas]

    reporte = ReporteDiario(
        device_id=device_id,
        fecha=fecha,
        temp_min=round(min(temps), 1),
        temp_max=round(max(temps), 1),
        temp_prom=round(sum(temps) / len(temps), 1),
        hum_prom=round(sum(hums) / len(hums), 1),
        lecturas_validas=len(lecturas),
        alertas=sum(1 for l in lecturas if l.alerta),
        activaciones_led=repo_commands.contar_activaciones(device_id, desde, hasta),
    )
    return repo_reports.guardar(reporte) or reporte


def generar_todos(fecha: Optional[date] = None) -> list[ReporteDiario]:
    """Genera el reporte de todos los sensores activos.

    Sin argumento usa el día anterior en la zona del negocio: es lo que
    corresponde cuando la tarea corre pasada la medianoche.
    """
    if fecha is None:
        fecha = (datetime.now(TZ) - timedelta(days=1)).date()

    generados: list[ReporteDiario] = []
    for sensor in repo_devices.listar_todos():
        if not sensor.activo:
            continue
        try:
            reporte = generar_para_sensor(sensor.id, fecha)
        except Exception:  # un sensor con problema no debe tumbar la tarea
            log.exception("Falló el reporte de %s (%s).", sensor.nombre, sensor.id)
            continue
        if reporte is not None:
            generados.append(reporte)

    log.info("Reporte diario %s: %s sensores con datos.", fecha, len(generados))
    return generados


def hoy_local() -> date:
    return datetime.now(TZ).date()
