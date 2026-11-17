"""Tarea programada del reporte diario (APScheduler).

Corre dentro del backend, como pide el documento: el procesamiento no
vive en la app.
"""
from __future__ import annotations

import logging
from zoneinfo import ZoneInfo

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger

from app.config import settings
from app.services import daily_report, led

log = logging.getLogger("sensa.scheduler")
_scheduler: BackgroundScheduler | None = None


def _tarea_reporte_diario() -> None:
    log.info("Ejecutando reporte diario programado.")
    try:
        daily_report.generar_todos()
    except Exception:
        log.exception("Falló la tarea del reporte diario.")


def _tarea_expirar_comandos() -> None:
    try:
        expirados = led.expirar_comandos_vencidos()
        if expirados:
            log.info("%s comandos marcados sin_respuesta.", expirados)
    except Exception:
        log.exception("Falló la limpieza de comandos.")


def iniciar() -> None:
    global _scheduler
    if not settings.enable_scheduler or _scheduler is not None:
        return

    tz = ZoneInfo(settings.timezone)
    _scheduler = BackgroundScheduler(timezone=tz)
    _scheduler.add_job(
        _tarea_reporte_diario,
        CronTrigger(
            hour=settings.daily_report_hour,
            minute=settings.daily_report_minute,
            timezone=tz,
        ),
        id="reporte_diario",
        replace_existing=True,
    )
    _scheduler.add_job(
        _tarea_expirar_comandos,
        CronTrigger(second="*/30", timezone=tz),
        id="expirar_comandos",
        replace_existing=True,
    )
    _scheduler.start()
    log.info(
        "Scheduler activo: reporte diario a las %02d:%02d (%s).",
        settings.daily_report_hour,
        settings.daily_report_minute,
        settings.timezone,
    )


def detener() -> None:
    global _scheduler
    if _scheduler is not None:
        _scheduler.shutdown(wait=False)
        _scheduler = None
