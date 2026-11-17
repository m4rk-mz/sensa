"""Acceso a datos de negocios."""
from __future__ import annotations

from typing import Optional

from app.db.client import table
from app.models.business import Negocio
from app.models.common import validar_filas

TABLA = "businesses"
CAMPOS = "id,nombre,creado_en"


def crear(nombre: str) -> Optional[Negocio]:
    res = table(TABLA).insert({"nombre": nombre}).execute()
    filas = validar_filas(Negocio, res.data)
    return filas[0] if filas else None


def por_id(business_id: str) -> Optional[Negocio]:
    res = table(TABLA).select(CAMPOS).eq("id", business_id).limit(1).execute()
    filas = validar_filas(Negocio, res.data)
    return filas[0] if filas else None


def por_nombre(nombre: str) -> Optional[Negocio]:
    res = table(TABLA).select(CAMPOS).eq("nombre", nombre).limit(1).execute()
    filas = validar_filas(Negocio, res.data)
    return filas[0] if filas else None


def listar() -> list[Negocio]:
    res = table(TABLA).select(CAMPOS).order("creado_en", desc=False).execute()
    return validar_filas(Negocio, res.data)
