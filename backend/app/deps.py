"""Dependencias de autenticación y permisos.

Aquí vive la regla central de Sensa: el rol y el negocio se leen de la
base de datos a partir de la sesión, nunca del cuerpo de la petición. Y un
usuario que cambie un id en la URL recibe 404, no los datos de otro
negocio.
"""
from __future__ import annotations

from typing import Annotated, Optional

from fastapi import Depends, Header, HTTPException, Path, status

from app import security
from app.models.device import Sensor
from app.models.common import UUID_REGEX
from app.models.user import Usuario
from app.repositories import devices as repo_devices
from app.repositories import users as repo_users

IdRuta = Annotated[str, Path(pattern=UUID_REGEX)]
NO_AUTORIZADO = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Sesión inválida o expirada.",
    headers={"WWW-Authenticate": "Bearer"},
)
NO_ENCONTRADO = HTTPException(
    status_code=status.HTTP_404_NOT_FOUND, detail="Recurso no encontrado."
)


# --------------------------------------------------------------------------
# Usuarios
# --------------------------------------------------------------------------
def usuario_actual(authorization: Optional[str] = Header(default=None)) -> Usuario:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise NO_AUTORIZADO
    payload = security.leer_token_sesion(authorization.split(" ", 1)[1].strip())
    if not payload or not payload.get("sub"):
        raise NO_AUTORIZADO

    # El token solo identifica al usuario: rol y negocio se releen de la BD,
    # así una promoción o una baja surten efecto de inmediato.
    usuario = repo_users.por_id(str(payload["sub"]))
    if usuario is None or not usuario.activo:
        raise NO_AUTORIZADO
    return usuario


def admin_actual(usuario: Usuario = Depends(usuario_actual)) -> Usuario:
    if not usuario.es_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Esta operación es solo para el administrador de la plataforma.",
        )
    return usuario


def negocio_permitido(business_id: str, usuario: Usuario) -> None:
    """El administrador ve todo; el usuario de negocio, solo el suyo."""
    if usuario.es_admin:
        return
    if usuario.business_id != business_id:
        raise NO_ENCONTRADO


def sensor_del_usuario(
    device_id: IdRuta, usuario: Usuario = Depends(usuario_actual)
) -> Sensor:
    """Carga un sensor comprobando que pertenezca al negocio del usuario."""
    sensor = repo_devices.por_id(device_id)
    if sensor is None:
        raise NO_ENCONTRADO
    negocio_permitido(sensor.business_id, usuario)
    return sensor


# --------------------------------------------------------------------------
# Sensores (ESP32)
# --------------------------------------------------------------------------
def sensor_autenticado(
    device_id: IdRuta,
    x_device_token: Optional[str] = Header(default=None),
) -> Sensor:
    """Autentica al nodo por su token.

    El token trae el id dentro y debe coincidir con el de la URL: un nodo
    no puede reportar lecturas de otro sensor.
    """
    if not x_device_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Falta el encabezado X-Device-Token.",
        )
    partes = security.partes_token_sensor(x_device_token)
    if partes is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token de sensor inválido."
        )
    token_device_id, secreto = partes
    if token_device_id != device_id:
        raise NO_ENCONTRADO

    token_hash = repo_devices.token_hash_por_id(device_id)
    if not token_hash or not security.verificar_secreto_sensor(secreto, token_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token de sensor inválido."
        )

    sensor = repo_devices.por_id(device_id)
    if sensor is None or not sensor.activo:
        raise NO_ENCONTRADO
    return sensor
