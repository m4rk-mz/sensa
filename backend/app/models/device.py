"""Modelos de sensor (nodo ESP32)."""
from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import Field

from app.config import settings
from app.models.common import EntradaModel, RegistroModel

UMBRAL = Field(ge=settings.temp_min_c, le=settings.temp_max_c)


class SensorAltaEntrada(EntradaModel):
    nombre: str = Field(min_length=2, max_length=120)
    umbral_c: float = Field(
        default=settings.default_threshold_c,
        ge=settings.temp_min_c,
        le=settings.temp_max_c,
    )


class SensorEdicionEntrada(EntradaModel):
    nombre: Optional[str] = Field(default=None, min_length=2, max_length=120)
    umbral_c: Optional[float] = Field(
        default=None, ge=settings.temp_min_c, le=settings.temp_max_c
    )
    activo: Optional[bool] = None


class Sensor(RegistroModel):
    id: str
    business_id: str
    nombre: str = Field(min_length=2, max_length=120)
    umbral_c: float = UMBRAL
    modo_manual_hasta: Optional[datetime] = None
    led_forzado: Optional[bool] = None
    led_estado_real: bool = False
    ultima_lectura_en: Optional[datetime] = None
    activo: bool = True
    creado_en: Optional[datetime] = None

    def en_modo_manual(self, ahora: datetime) -> bool:
        return self.modo_manual_hasta is not None and self.modo_manual_hasta > ahora

    def led_deseado(self, ahora: datetime, temperatura: Optional[float] = None) -> bool:
        """Estado que debería tener el LED.

        En modo manual gana el estado forzado por el usuario; si no, se
        decide por el umbral del negocio.
        """
        if self.en_modo_manual(ahora) and self.led_forzado is not None:
            return self.led_forzado
        if temperatura is None:
            return self.led_estado_real
        return temperatura > self.umbral_c


class SensorAltaSalida(RegistroModel):
    """Respuesta del registro de un sensor.

    `token` se muestra una sola vez: en la BD solo queda su hash.
    """

    sensor: Sensor
    token: str


class SensorEstadoSalida(RegistroModel):
    """Lo que la pantalla "Mis sensores" necesita de un golpe."""

    sensor: Sensor
    temperatura: Optional[float] = None
    humedad: Optional[float] = None
    alerta: bool = False
    led_estado_real: bool = False
    led_deseado: bool = False
    modo: str = "automatico"  # "automatico" | "manual"
    modo_manual_hasta: Optional[datetime] = None
    ultima_lectura_en: Optional[datetime] = None
    en_linea: bool = False
