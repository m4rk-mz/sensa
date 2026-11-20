"""Modelos de usuario y de sesión."""
from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import Field, field_validator, model_validator

from app.models.common import Email, EntradaModel, RegistroModel, Rol

NOMBRE = Field(min_length=2, max_length=120)
PASSWORD = Field(min_length=8, max_length=128)


def _validar_password_con_letra_y_numero(v: str) -> str:
    """Regla única para toda contraseña nueva: alta de usuario y cambio."""
    if not any(c.isalpha() for c in v) or not any(c.isdigit() for c in v):
        raise ValueError("La contraseña debe incluir al menos una letra y un número.")
    return v


# --------------------------------------------------------------------------
# Entradas
# --------------------------------------------------------------------------
class LoginEntrada(EntradaModel):
    email: Email
    password: str = Field(min_length=1, max_length=128)


class UsuarioAltaEntrada(EntradaModel):
    """Alta de un usuario de negocio.

    Nota: no existe campo `rol`. El rol lo decide el backend; promover a
    administrador es una operación aparte y solo del administrador de
    plataforma.
    """

    nombre: str = NOMBRE
    email: Email
    password: str = PASSWORD

    @field_validator("password")
    @classmethod
    def password_con_letra_y_numero(cls, v: str) -> str:
        return _validar_password_con_letra_y_numero(v)


class CambioPasswordEntrada(EntradaModel):
    password_actual: str = Field(min_length=1, max_length=128)
    password_nueva: str = PASSWORD

    @field_validator("password_nueva")
    @classmethod
    def password_con_letra_y_numero(cls, v: str) -> str:
        return _validar_password_con_letra_y_numero(v)


# --------------------------------------------------------------------------
# Registro de BD
# --------------------------------------------------------------------------
class Usuario(RegistroModel):
    id: str
    nombre: str = NOMBRE
    email: Email
    rol: Rol
    business_id: Optional[str] = None
    activo: bool = True
    creado_en: Optional[datetime] = None

    @model_validator(mode="after")
    def rol_coherente_con_negocio(self):
        if self.rol is Rol.PLATFORM_ADMIN and self.business_id is not None:
            raise ValueError("El administrador de plataforma no pertenece a un negocio.")
        if self.rol is Rol.BUSINESS_USER and not self.business_id:
            raise ValueError("Un usuario de negocio debe tener business_id.")
        return self

    @property
    def es_admin(self) -> bool:
        return self.rol is Rol.PLATFORM_ADMIN


class UsuarioConHash(Usuario):
    """Solo para uso interno del login. Nunca se devuelve en una respuesta."""

    password_hash: str


# --------------------------------------------------------------------------
# Salidas
# --------------------------------------------------------------------------
class UsuarioSalida(RegistroModel):
    """Vista pública de un usuario: sin password ni hash."""

    id: str
    nombre: str
    email: Email
    rol: Rol
    business_id: Optional[str] = None
    activo: bool = True

    @classmethod
    def de(cls, usuario: Usuario) -> "UsuarioSalida":
        return cls.model_validate(usuario.model_dump())


class TokenSalida(RegistroModel):
    access_token: str
    token_type: str = "bearer"
    expira_en: datetime
    usuario: UsuarioSalida
