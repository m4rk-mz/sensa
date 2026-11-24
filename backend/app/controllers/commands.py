"""Controlador de comandos del LED.

Tres actores:
- La app pide prender, apagar, volver a automático, mandar una alerta o
  probar los LEDs (POST .../command).
- El nodo consulta si hay algo pendiente (GET .../command, cada 1 s).
- El nodo confirma que lo aplicó (POST .../ack).

Estados del comando: pendiente -> enviado -> confirmado, o sin_respuesta
si pasan `COMMAND_TIMEOUT_SECONDS` sin confirmación.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from app.deps import sensor_autenticado, sensor_del_usuario, usuario_actual
from app.models.command import (
    AckEntrada,
    Comando,
    ComandoEntrada,
    ComandoPendienteSalida,
)
from app.models.common import ahora as ahora_utc
from app.models.device import Sensor
from app.models.user import Usuario
from app.repositories import commands as repo_commands
from app.repositories import devices as repo_devices
from app.repositories import readings as repo_readings
from app.services import led as servicio_led

router = APIRouter(prefix="/devices", tags=["actuador"])


@router.post(
    "/{device_id}/command", response_model=Comando, status_code=status.HTTP_202_ACCEPTED
)
def pedir_comando(
    datos: ComandoEntrada,
    sensor: Sensor = Depends(sensor_del_usuario),
    usuario: Usuario = Depends(usuario_actual),
) -> Comando:
    """La app fuerza el estado del LED, lo regresa a automático, manda una
    alerta (beeps) o pide probar los LEDs.

    El modo manual dura `MANUAL_MODE_MINUTES` y después vuelve solo a
    automático. La alerta y la prueba no cambian el modo.
    """
    if not sensor.activo:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT, detail="El sensor está dado de baja."
        )
    _sensor, comando = servicio_led.aplicar_comando(sensor, datos.accion, usuario.id)
    return comando


@router.get("/{device_id}/command", response_model=ComandoPendienteSalida)
def consultar_comando(
    sensor: Sensor = Depends(sensor_autenticado),
) -> ComandoPendienteSalida:
    """El nodo pregunta qué debe hacer.

    Siempre recibe el estado deseado y el umbral vigente, así que si el
    backend se cae puede seguir en automático con lo último que guardó.
    """
    momento = ahora_utc()
    servicio_led.expirar_comandos_vencidos(momento, espaciado=True)

    comando = repo_commands.abierto_por_device(sensor.id)
    if comando is not None:
        comando = repo_commands.marcar_enviado(comando.id, momento) or comando

    ultima = repo_readings.ultima(sensor.id)
    return ComandoPendienteSalida(
        comando=comando,
        led_deseado=servicio_led.led_deseado(
            sensor,
            temperatura=ultima.temperatura if ultima else None,
            momento=momento,
        ),
        umbral_c=sensor.umbral_c,
        modo=servicio_led.modo(sensor, momento),
    )


@router.post("/{device_id}/ack", response_model=Comando)
def confirmar_comando(
    datos: AckEntrada, sensor: Sensor = Depends(sensor_autenticado)
) -> Comando:
    """El nodo confirma que aplicó el comando."""
    comando = repo_commands.por_id(datos.comando_id)
    if comando is None or comando.device_id != sensor.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Comando no encontrado."
        )

    momento = ahora_utc()
    repo_devices.registrar_estado_nodo(
        sensor.id, led_estado_real=datos.led_estado, ultima_lectura_en=momento
    )
    confirmado = repo_commands.confirmar(comando.id, momento)
    if confirmado is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo confirmar el comando.",
        )
    return confirmado


@router.get("/{device_id}/commands", response_model=list[Comando])
def historial_comandos(sensor: Sensor = Depends(sensor_del_usuario)) -> list[Comando]:
    """Último comando del sensor (sirve para mostrar el estado en la app)."""
    servicio_led.expirar_comandos_vencidos()
    ultimo = repo_commands.ultimo_por_device(sensor.id)
    return [ultimo] if ultimo else []
