"""Acceso a datos de comandos del actuador."""
from __future__ import annotations

from datetime import datetime
from typing import Optional

from app.db.client import table
from app.models.command import Comando
from app.models.common import AccionComando, EstadoComando, validar_filas

TABLA = "actuator_commands"
CAMPOS = "id,device_id,accion,estado,requested_by,creado_en,enviado_en,confirmado_en"


def crear(
    *, device_id: str, accion: AccionComando, requested_by: Optional[str]
) -> Optional[Comando]:
    res = (
        table(TABLA)
        .insert(
            {
                "device_id": device_id,
                "accion": accion.value,
                "estado": EstadoComando.PENDIENTE.value,
                "requested_by": requested_by,
            }
        )
        .execute()
    )
    filas = validar_filas(Comando, res.data)
    return filas[0] if filas else None


def por_id(comando_id: str) -> Optional[Comando]:
    res = table(TABLA).select(CAMPOS).eq("id", comando_id).limit(1).execute()
    filas = validar_filas(Comando, res.data)
    return filas[0] if filas else None


def abierto_por_device(device_id: str) -> Optional[Comando]:
    """El comando más reciente que todavía espera al nodo."""
    res = (
        table(TABLA)
        .select(CAMPOS)
        .eq("device_id", device_id)
        .in_("estado", [EstadoComando.PENDIENTE.value, EstadoComando.ENVIADO.value])
        .order("creado_en", desc=True)
        .limit(1)
        .execute()
    )
    filas = validar_filas(Comando, res.data)
    return filas[0] if filas else None


def ultimo_por_device(device_id: str) -> Optional[Comando]:
    res = (
        table(TABLA)
        .select(CAMPOS)
        .eq("device_id", device_id)
        .order("creado_en", desc=True)
        .limit(1)
        .execute()
    )
    filas = validar_filas(Comando, res.data)
    return filas[0] if filas else None


def marcar_enviado(comando_id: str, cuando: datetime) -> Optional[Comando]:
    res = (
        table(TABLA)
        .update(
            {"estado": EstadoComando.ENVIADO.value, "enviado_en": cuando.isoformat()}
        )
        .eq("id", comando_id)
        .eq("estado", EstadoComando.PENDIENTE.value)
        .execute()
    )
    filas = validar_filas(Comando, res.data)
    return filas[0] if filas else por_id(comando_id)


def confirmar(comando_id: str, cuando: datetime) -> Optional[Comando]:
    res = (
        table(TABLA)
        .update(
            {
                "estado": EstadoComando.CONFIRMADO.value,
                "confirmado_en": cuando.isoformat(),
            }
        )
        .eq("id", comando_id)
        .execute()
    )
    filas = validar_filas(Comando, res.data)
    return filas[0] if filas else None


def marcar_sin_respuesta(comando_id: str) -> None:
    table(TABLA).update({"estado": EstadoComando.SIN_RESPUESTA.value}).eq(
        "id", comando_id
    ).execute()


def expirar_vencidos(limite: datetime) -> int:
    """Marca "sin_respuesta" los comandos enviados antes de `limite`.

    Se llama al consultar el estado de un sensor y desde la tarea
    programada, así que la app ve el estado correcto sin esperar al nodo.
    """
    pendientes = (
        table(TABLA)
        .select("id,creado_en,enviado_en,estado")
        .in_("estado", [EstadoComando.PENDIENTE.value, EstadoComando.ENVIADO.value])
        .lt("creado_en", limite.isoformat())
        .execute()
        .data
        or []
    )
    for fila in pendientes:
        marcar_sin_respuesta(fila["id"])
    return len(pendientes)


def contar_activaciones(device_id: str, desde: datetime, hasta: datetime) -> int:
    """Veces que se confirmó un encendido del LED en el periodo."""
    res = (
        table(TABLA)
        .select("id")
        .eq("device_id", device_id)
        .eq("accion", AccionComando.LED_ON.value)
        .eq("estado", EstadoComando.CONFIRMADO.value)
        .gte("creado_en", desde.isoformat())
        .lt("creado_en", hasta.isoformat())
        .execute()
    )
    return len(res.data or [])
