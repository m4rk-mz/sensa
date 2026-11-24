"""Acceso a datos de usuarios.

Toda fila que sale de aquí ya pasó por el modelo correspondiente: lo que
no valide se descarta y no llega a los controladores.
"""
from __future__ import annotations

from typing import Optional

from app.db.client import table
from app.models.common import Rol, validar_filas
from app.models.user import Usuario, UsuarioConHash

TABLA = "users"
CAMPOS = "id,nombre,email,rol,business_id,activo,creado_en"


def por_email_con_hash(email: str) -> Optional[UsuarioConHash]:
    """Solo para el login: es el único lugar que toca el hash."""
    res = (
        table(TABLA)
        .select(CAMPOS + ",password_hash")
        .eq("email", email.strip().lower())
        .limit(1)
        .execute()
    )
    filas = validar_filas(UsuarioConHash, res.data)
    return filas[0] if filas else None


def por_id(user_id: str) -> Optional[Usuario]:
    res = table(TABLA).select(CAMPOS).eq("id", user_id).limit(1).execute()
    filas = validar_filas(Usuario, res.data)
    return filas[0] if filas else None


def hash_por_id(user_id: str) -> Optional[str]:
    res = table(TABLA).select("password_hash").eq("id", user_id).limit(1).execute()
    if not res.data:
        return None
    return res.data[0].get("password_hash")


def email_existe(email: str) -> bool:
    res = table(TABLA).select("id").eq("email", email.strip().lower()).limit(1).execute()
    return bool(res.data)


def crear(
    *,
    nombre: str,
    email: str,
    password_hash: str,
    rol: Rol,
    business_id: Optional[str],
) -> Optional[Usuario]:
    res = (
        table(TABLA)
        .insert(
            {
                "nombre": nombre,
                "email": email.strip().lower(),
                "password_hash": password_hash,
                "rol": rol.value,
                "business_id": business_id,
            }
        )
        .execute()
    )
    filas = validar_filas(Usuario, res.data)
    return filas[0] if filas else None


def listar(business_id: Optional[str] = None) -> list[Usuario]:
    q = table(TABLA).select(CAMPOS).order("creado_en", desc=False)
    if business_id is not None:
        q = q.eq("business_id", business_id)
    return validar_filas(Usuario, q.execute().data)


def promover_a_admin(user_id: str) -> Optional[Usuario]:
    """Promueve a administrador de plataforma.

    El administrador de plataforma no pertenece a un negocio, así que
    business_id se limpia en la misma operación (lo exige el CHECK de la
    tabla y el modelo).
    """
    res = (
        table(TABLA)
        .update({"rol": Rol.PLATFORM_ADMIN.value, "business_id": None})
        .eq("id", user_id)
        .execute()
    )
    filas = validar_filas(Usuario, res.data)
    return filas[0] if filas else None


def fijar_activo(user_id: str, activo: bool) -> Optional[Usuario]:
    """Da de baja o reactiva a un usuario. No borra nada."""
    res = table(TABLA).update({"activo": activo}).eq("id", user_id).execute()
    filas = validar_filas(Usuario, res.data)
    return filas[0] if filas else None


def actualizar_password(user_id: str, password_hash: str) -> bool:
    res = table(TABLA).update({"password_hash": password_hash}).eq("id", user_id).execute()
    return bool(res.data)


def contar() -> int:
    res = table(TABLA).select("id").execute()
    return len(res.data or [])
