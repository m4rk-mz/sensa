"""Controlador de sesión.

Capa C del MC: valida con los modelos, decide permisos y no devuelve
nunca contraseñas ni hashes.
"""
from __future__ import annotations

import time

from fastapi import APIRouter, Depends, HTTPException, status

from app import security
from app.models.user import (
    CambioPasswordEntrada,
    LoginEntrada,
    TokenSalida,
    Usuario,
    UsuarioSalida,
)
from app.deps import usuario_actual
from app.repositories import users as repo_users

router = APIRouter(tags=["sesión"])

CREDENCIALES_INVALIDAS = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Correo o contraseña incorrectos.",
)


@router.post("/auth/login", response_model=TokenSalida)
def login(datos: LoginEntrada) -> TokenSalida:
    inicio = time.perf_counter()
    usuario = repo_users.por_email_con_hash(str(datos.email))

    # Mismo mensaje y tiempo parecido para "no existe" y "contraseña mal":
    # así la respuesta no revela qué correos están registrados.
    ok = usuario is not None and security.verificar_password(
        datos.password, usuario.password_hash
    )
    if not ok or usuario is None or not usuario.activo:
        restante = 0.25 - (time.perf_counter() - inicio)
        if restante > 0:
            time.sleep(restante)
        raise CREDENCIALES_INVALIDAS

    token, expira = security.crear_token_sesion(
        user_id=usuario.id, rol=usuario.rol.value, business_id=usuario.business_id
    )
    return TokenSalida(
        access_token=token,
        expira_en=expira,
        usuario=UsuarioSalida.model_validate(
            usuario.model_dump(exclude={"password_hash"})
        ),
    )


@router.get("/me", response_model=UsuarioSalida)
def yo(usuario: Usuario = Depends(usuario_actual)) -> UsuarioSalida:
    """Devuelve el usuario y su rol tal como están en la BD.

    La app usa esto para decidir qué pantallas mostrar, pero el permiso
    real lo aplica el backend en cada endpoint.
    """
    return UsuarioSalida.de(usuario)


@router.post("/auth/password", status_code=status.HTTP_204_NO_CONTENT)
def cambiar_password(
    datos: CambioPasswordEntrada, usuario: Usuario = Depends(usuario_actual)
) -> None:
    hash_actual = repo_users.hash_por_id(usuario.id)
    if not hash_actual or not security.verificar_password(
        datos.password_actual, hash_actual
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="La contraseña actual no coincide.",
        )
    repo_users.actualizar_password(usuario.id, security.hash_password(datos.password_nueva))
