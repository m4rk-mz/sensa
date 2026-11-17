"""Modelos del reporte diario y de las estadísticas del panel admin."""
from __future__ import annotations

from datetime import date, datetime
from typing import Optional

from pydantic import Field, model_validator

from app.config import settings
from app.models.common import RegistroModel

TEMP = Field(ge=settings.temp_min_c, le=settings.temp_max_c)


class ReporteDiario(RegistroModel):
    id: Optional[str] = None
    device_id: str
    fecha: date
    temp_min: float = TEMP
    temp_max: float = TEMP
    temp_prom: float = TEMP
    hum_prom: float = Field(ge=settings.hum_min_pct, le=settings.hum_max_pct)
    lecturas_validas: int = Field(ge=0)
    alertas: int = Field(ge=0)
    activaciones_led: int = Field(ge=0)
    generado_en: Optional[datetime] = None

    @model_validator(mode="after")
    def rango_coherente(self):
        if self.temp_min > self.temp_max:
            raise ValueError("temp_min no puede ser mayor que temp_max.")
        if not (self.temp_min <= self.temp_prom <= self.temp_max):
            raise ValueError("temp_prom debe quedar entre temp_min y temp_max.")
        return self


class ReporteDiarioSalida(RegistroModel):
    """Lo que muestra la pantalla "Reporte del día"."""

    device_id: str
    sensor_nombre: str
    fecha: date
    reporte: Optional[ReporteDiario] = None
    mensaje: Optional[str] = None


# --------------------------------------------------------------------------
# Panel de administrador
# --------------------------------------------------------------------------
class FilaPanelNegocio(RegistroModel):
    """Una fila de la tabla del panel."""

    business_id: str
    negocio: str
    sensores: int = Field(ge=0)
    usuarios: int = Field(ge=0)
    lecturas_24h: int = Field(ge=0)
    temp_promedio: Optional[float] = None
    temp_max: Optional[float] = None
    alertas_24h: int = Field(ge=0)
    sensores_en_linea: int = Field(ge=0)


class PuntoGrafica(RegistroModel):
    """Un punto de la gráfica del panel."""

    etiqueta: str
    valor: float


class PanelAdminSalida(RegistroModel):
    generado_en: datetime
    total_negocios: int
    total_sensores: int
    total_usuarios: int
    lecturas_validas_24h: int
    lecturas_descartadas_24h: int
    alertas_24h: int
    tabla: list[FilaPanelNegocio]
    grafica_temp_promedio: list[PuntoGrafica]
