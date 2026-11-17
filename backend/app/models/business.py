"""Modelos de negocio."""
from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import Field

from app.models.common import EntradaModel, RegistroModel
from app.models.user import UsuarioAltaEntrada


class NegocioAltaEntrada(EntradaModel):
    nombre: str = Field(min_length=2, max_length=120)
    # Opcional: crear al mismo tiempo el primer usuario del negocio.
    usuario_inicial: Optional[UsuarioAltaEntrada] = None


class Negocio(RegistroModel):
    id: str
    nombre: str = Field(min_length=2, max_length=120)
    creado_en: Optional[datetime] = None


class NegocioConConteos(Negocio):
    sensores: int = 0
    usuarios: int = 0
