"""Modelos de comando del actuador (LED)."""
from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import Field

from app.models.common import (
    UUID_REGEX,
    AccionComando,
    EntradaModel,
    EstadoComando,
    RegistroModel,
)


class ComandoEntrada(EntradaModel):
    """Lo que manda la app: prender, apagar, devolver a automático, mandar
    una alerta (beeps) o probar los LEDs."""

    accion: AccionComando


class AckEntrada(EntradaModel):
    """Lo que manda el ESP32 al aplicar un comando."""

    comando_id: str = Field(pattern=UUID_REGEX)
    led_estado: bool


class Comando(RegistroModel):
    id: str
    device_id: str
    accion: AccionComando
    estado: EstadoComando
    requested_by: Optional[str] = None
    creado_en: datetime
    enviado_en: Optional[datetime] = None
    confirmado_en: Optional[datetime] = None


class ComandoPendienteSalida(RegistroModel):
    """Respuesta a GET /devices/{id}/command (el ESP32 consulta cada 1 s)."""

    comando: Optional[Comando] = None
    led_deseado: bool
    umbral_c: float
    modo: str
