"""Hash de contraseñas (Argon2id), tokens de sesión y tokens de sensor.

Reglas que cumple este módulo:
- Las contraseñas se guardan con Argon2id. Nunca en claro.
- Ninguna respuesta de la API incluye contraseñas ni hashes.
- El token del sensor también se guarda hasheado: en la BD no hay forma de
  recuperarlo, solo de verificarlo.
"""
from __future__ import annotations

import secrets
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError, VerifyMismatchError
from argon2.low_level import Type

from app.config import settings

# Argon2id con parámetros razonables para un servidor pequeño.
# El script de inicialización del primer administrador usa este mismo
# hasher, así que los hashes son compatibles.
_hasher = PasswordHasher(
    time_cost=3,
    memory_cost=65536,  # 64 MB
    parallelism=4,
    hash_len=32,
    salt_len=16,
    type=Type.ID,  # Argon2id
)


# --------------------------------------------------------------------------
# Contraseñas
# --------------------------------------------------------------------------
def hash_password(password: str) -> str:
    return _hasher.hash(password)


def verificar_password(password: str, password_hash: str) -> bool:
    try:
        return _hasher.verify(password_hash, password)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False


# --------------------------------------------------------------------------
# Tokens de sesión (JWT)
# --------------------------------------------------------------------------
def crear_token_sesion(
    *, user_id: str, rol: str, business_id: Optional[str]
) -> tuple[str, datetime]:
    expira = datetime.now(timezone.utc) + timedelta(minutes=settings.jwt_exp_minutes)
    payload: dict[str, Any] = {
        "sub": user_id,
        # El rol va en el token solo como pista para la app. El backend
        # siempre lo vuelve a leer de la BD antes de autorizar.
        "rol": rol,
        "business_id": business_id,
        "exp": expira,
        "iat": datetime.now(timezone.utc),
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    return token, expira


def leer_token_sesion(token: str) -> Optional[dict[str, Any]]:
    try:
        return jwt.decode(
            token, settings.jwt_secret, algorithms=[settings.jwt_algorithm]
        )
    except jwt.PyJWTError:
        return None


# --------------------------------------------------------------------------
# Tokens de sensor
# --------------------------------------------------------------------------
PREFIJO_TOKEN = "sensa"


def generar_token_sensor(device_id: str) -> tuple[str, str]:
    """Devuelve (token en claro, hash para guardar).

    Formato: sensa.<device_id>.<secreto>
    Trae el id dentro para poder localizar el sensor y verificar el secreto
    contra su hash sin recorrer la tabla.
    """
    secreto = secrets.token_urlsafe(32)
    token = f"{PREFIJO_TOKEN}.{device_id}.{secreto}"
    return token, _hasher.hash(secreto)


def partes_token_sensor(token: str) -> Optional[tuple[str, str]]:
    partes = token.strip().split(".")
    if len(partes) != 3 or partes[0] != PREFIJO_TOKEN:
        return None
    _, device_id, secreto = partes
    if not device_id or not secreto:
        return None
    return device_id, secreto


def verificar_secreto_sensor(secreto: str, token_hash: str) -> bool:
    try:
        return _hasher.verify(token_hash, secreto)
    except (VerifyMismatchError, VerificationError, InvalidHashError):
        return False
