"""Cliente de Supabase (acceso por REST).

Un solo cliente para todo el proceso. Usa la service_role key, por lo que
pasa por encima de RLS: los permisos los aplican los controladores.
"""
from __future__ import annotations

from functools import lru_cache

from supabase import Client, create_client

from app.config import settings


@lru_cache
def get_client() -> Client:
    settings.validar()
    return create_client(settings.supabase_url, settings.supabase_service_key)


def table(nombre: str):
    """Atajo: table('users').select('*')..."""
    return get_client().table(nombre)
