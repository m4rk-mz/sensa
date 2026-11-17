"""Modelos de lectura del sensor.

Los rangos vienen del datasheet del DHT11 (settings.temp_*/hum_*). Se
aplican en los dos sentidos: al recibir una lectura y al leerla de la BD.
"""
from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import Field

from app.config import settings
from app.models.common import EntradaModel, RegistroModel

TEMPERATURA = Field(ge=settings.temp_min_c, le=settings.temp_max_c)
HUMEDAD = Field(ge=settings.hum_min_pct, le=settings.hum_max_pct)


class LecturaEntrada(EntradaModel):
    """Cuerpo que manda el ESP32 en POST /devices/{id}/readings."""

    temperatura: float = TEMPERATURA
    humedad: float = HUMEDAD
    # El nodo reporta el estado real de su LED en cada lectura, así la
    # confirmación de un comando no depende solo del ack.
    led_estado: bool = False


class Lectura(RegistroModel):
    id: str
    device_id: str
    temperatura: float = TEMPERATURA
    humedad: float = HUMEDAD
    led_reportado: bool = False
    alerta: bool = False
    creado_en: datetime


class LecturaRegistradaSalida(RegistroModel):
    """Respuesta al ESP32: incluye qué debe hacer con el LED."""

    lectura: Lectura
    alerta: bool
    led_deseado: bool
    umbral_c: float
    modo: str
    intervalo_segundos: int = 30
