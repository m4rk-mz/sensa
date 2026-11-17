"""Piezas compartidas por los modelos (capa M de la arquitectura MC).

Los modelos cumplen dos papeles en Sensa:

1. Validar lo que entra (cuerpos de petición), venga de la app, de Postman
   o de curl.
2. Validar lo que sale de la base de datos. `RegistroModel.desde_fila` y
   `validar_filas` descartan cualquier registro que no cumpla el modelo,
   así un renglón insertado a mano en la BD nunca llega a una consulta,
   estadística o reporte.
"""
from __future__ import annotations

import enum
import logging
from datetime import datetime
from typing import Annotated, Any, Iterable, Optional, TypeVar

from pydantic import BaseModel, ConfigDict, StringConstraints

log = logging.getLogger("sensa.modelos")

# Misma expresión que el CHECK de la tabla users, para que la BD y los
# modelos no discrepen. Se normaliza a minúsculas: el correo no distingue
# mayúsculas al iniciar sesión.
EMAIL_REGEX = r"^[^@\s]+@[^@\s]+\.[^@\s]{2,}$"
Email = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True, to_lower=True, max_length=160, pattern=EMAIL_REGEX
    ),
]


class Rol(str, enum.Enum):
    PLATFORM_ADMIN = "platform_admin"
    BUSINESS_USER = "business_user"


class AccionComando(str, enum.Enum):
    LED_ON = "led_on"
    LED_OFF = "led_off"
    AUTO = "auto"


class EstadoComando(str, enum.Enum):
    PENDIENTE = "pendiente"
    ENVIADO = "enviado"
    CONFIRMADO = "confirmado"
    SIN_RESPUESTA = "sin_respuesta"


class EntradaModel(BaseModel):
    """Base de los modelos de entrada: rechaza campos desconocidos."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)


class RegistroModel(BaseModel):
    """Base de los modelos que representan filas de la base de datos."""

    model_config = ConfigDict(extra="ignore")

    @classmethod
    def desde_fila(cls, fila: dict[str, Any]):
        """Valida una fila. Devuelve None (y registra el motivo) si es inválida."""
        try:
            return cls.model_validate(fila)
        except Exception as exc:  # pydantic.ValidationError y errores de tipo
            log.warning(
                "Registro inválido descartado en %s (id=%s): %s",
                cls.__name__,
                fila.get("id"),
                exc,
            )
            return None


T = TypeVar("T", bound=RegistroModel)


def validar_filas(modelo: type[T], filas: Optional[Iterable[dict[str, Any]]]) -> list[T]:
    """Valida una lista de filas y descarta las inválidas."""
    validos: list[T] = []
    for fila in filas or []:
        registro = modelo.desde_fila(fila)
        if registro is not None:
            validos.append(registro)
    return validos


def ahora() -> datetime:
    from datetime import timezone

    return datetime.now(timezone.utc)
