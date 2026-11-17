"""Sustituto de `argon2-cffi` SOLO para pruebas sin red.

El backend usa `argon2-cffi` (ver requirements.txt). Este módulo imita su
API mínima con el Argon2id de `cryptography`, y produce la misma cadena
PHC estándar ($argon2id$v=19$m=...,t=...,p=...$salt$hash), para poder
correr las pruebas en una máquina donde argon2-cffi no está instalado.

`instalar_si_falta()` no hace nada si argon2-cffi sí está disponible: en ese
caso las pruebas usan la librería real.
"""
from __future__ import annotations

import base64
import os
import secrets
import sys
import types


def _b64(datos: bytes) -> str:
    return base64.b64encode(datos).decode().rstrip("=")


def _de_b64(texto: str) -> bytes:
    relleno = "=" * (-len(texto) % 4)
    return base64.b64decode(texto + relleno)


class VerifyMismatchError(Exception):
    pass


class VerificationError(Exception):
    pass


class InvalidHashError(Exception):
    pass


class _Type:
    ID = "argon2id"
    I = "argon2i"
    D = "argon2d"


class PasswordHasher:
    def __init__(
        self,
        time_cost: int = 3,
        memory_cost: int = 65536,
        parallelism: int = 4,
        hash_len: int = 32,
        salt_len: int = 16,
        type=_Type.ID,
    ):
        self.time_cost = time_cost
        self.memory_cost = memory_cost
        self.parallelism = parallelism
        self.hash_len = hash_len
        self.salt_len = salt_len

    def _derivar(self, password: str, salt: bytes, m: int, t: int, p: int, largo: int) -> bytes:
        from cryptography.hazmat.primitives.kdf.argon2 import Argon2id

        kdf = Argon2id(
            salt=salt, length=largo, iterations=t, lanes=p, memory_cost=m
        )
        return kdf.derive(password.encode())

    def hash(self, password: str) -> str:
        salt = secrets.token_bytes(self.salt_len)
        digest = self._derivar(
            password,
            salt,
            self.memory_cost,
            self.time_cost,
            self.parallelism,
            self.hash_len,
        )
        return (
            f"$argon2id$v=19$m={self.memory_cost},t={self.time_cost},"
            f"p={self.parallelism}${_b64(salt)}${_b64(digest)}"
        )

    def verify(self, hash_guardado: str, password: str) -> bool:
        try:
            _, algoritmo, _version, parametros, salt_b64, digest_b64 = hash_guardado.split("$")
            if algoritmo != "argon2id":
                raise InvalidHashError(algoritmo)
            params = dict(par.split("=") for par in parametros.split(","))
            salt = _de_b64(salt_b64)
            esperado = _de_b64(digest_b64)
        except InvalidHashError:
            raise
        except Exception as exc:
            raise InvalidHashError(str(exc)) from exc

        calculado = self._derivar(
            password,
            salt,
            int(params["m"]),
            int(params["t"]),
            int(params["p"]),
            len(esperado),
        )
        if not secrets.compare_digest(calculado, esperado):
            raise VerifyMismatchError("La contraseña no coincide.")
        return True


def instalar_si_falta() -> bool:
    """Devuelve True si se instaló el sustituto (argon2-cffi no estaba)."""
    try:
        import argon2  # noqa: F401

        return False
    except ModuleNotFoundError:
        pass

    argon2 = types.ModuleType("argon2")
    argon2.PasswordHasher = PasswordHasher

    excepciones = types.ModuleType("argon2.exceptions")
    excepciones.VerifyMismatchError = VerifyMismatchError
    excepciones.VerificationError = VerificationError
    excepciones.InvalidHashError = InvalidHashError

    low_level = types.ModuleType("argon2.low_level")
    low_level.Type = _Type

    argon2.exceptions = excepciones
    argon2.low_level = low_level

    sys.modules["argon2"] = argon2
    sys.modules["argon2.exceptions"] = excepciones
    sys.modules["argon2.low_level"] = low_level
    return True
