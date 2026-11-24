"""Lógica del LED: modo automático, modo manual y estados del comando.

Está en servicios porque la usan tres controladores (lecturas, comandos y
sensores) y conviene que la regla viva en un solo lugar.
"""
from __future__ import annotations

from datetime import datetime, timedelta
from typing import Optional

from app.config import settings
from app.models.command import Comando
from app.models.common import AccionComando, ahora as ahora_utc
from app.models.device import Sensor
from app.models.reading import Lectura
from app.repositories import commands as repo_commands
from app.repositories import devices as repo_devices

AUTOMATICO = "automatico"
MANUAL = "manual"


def modo(sensor: Sensor, momento: Optional[datetime] = None) -> str:
    momento = momento or ahora_utc()
    return MANUAL if sensor.en_modo_manual(momento) else AUTOMATICO


def led_deseado(
    sensor: Sensor, *, temperatura: Optional[float], momento: Optional[datetime] = None
) -> bool:
    momento = momento or ahora_utc()
    return sensor.led_deseado(momento, temperatura)


def aplicar_comando(
    sensor: Sensor, accion: AccionComando, usuario_id: Optional[str]
) -> tuple[Sensor, Comando]:
    """Registra el comando y ajusta el modo del sensor.

    - led_on / led_off: entra en modo manual por `manual_mode_minutes` y
      al terminar vuelve solo a automático.
    - auto: cancela el modo manual de inmediato.
    - alerta / probar_leds: no tocan el modo; solo se le entregan al nodo.
    """
    momento = ahora_utc()

    actualizado: Optional[Sensor] = None
    if not accion.es_del_led:
        pass
    elif accion is AccionComando.AUTO:
        actualizado = repo_devices.fijar_modo_manual(
            sensor.id, hasta=None, led_forzado=None
        )
    else:
        hasta = momento + timedelta(minutes=settings.manual_mode_minutes)
        actualizado = repo_devices.fijar_modo_manual(
            sensor.id, hasta=hasta, led_forzado=(accion is AccionComando.LED_ON)
        )

    comando = repo_commands.crear(
        device_id=sensor.id, accion=accion, requested_by=usuario_id
    )
    if comando is None:
        raise RuntimeError("No se pudo registrar el comando.")
    return (actualizado or sensor), comando


_ultima_expiracion: Optional[datetime] = None
# El nodo llama cada segundo; revisar vencidos en cada llamada duplicaría las
# consultas a la BD. Desde las rutas del nodo basta cada pocos segundos.
SEGUNDOS_ENTRE_EXPIRACIONES = 5


def expirar_comandos_vencidos(
    momento: Optional[datetime] = None, *, espaciado: bool = False
) -> int:
    """Marca "sin_respuesta" los comandos que el nodo no confirmó.

    Con `espaciado=True` (rutas del nodo) solo revisa si pasaron
    `SEGUNDOS_ENTRE_EXPIRACIONES` desde la última vez.
    """
    global _ultima_expiracion
    momento = momento or ahora_utc()
    if (
        espaciado
        and _ultima_expiracion is not None
        and (momento - _ultima_expiracion).total_seconds() < SEGUNDOS_ENTRE_EXPIRACIONES
    ):
        return 0
    _ultima_expiracion = momento
    limite = momento - timedelta(seconds=settings.command_timeout_seconds)
    return repo_commands.expirar_vencidos(limite)


def confirmar_por_lectura(sensor: Sensor, lectura: Lectura) -> None:
    """Confirma el comando abierto si el nodo ya reporta el estado esperado.

    El ESP32 manda su estado real en cada lectura, así que la confirmación
    no depende solo del ack.
    """
    comando = repo_commands.abierto_por_device(sensor.id)
    # Una alerta o una prueba de LEDs no se confirma por lectura: si no, se
    # marcaría confirmada antes de que el nodo la recoja y nunca sonaría.
    if comando is None or not comando.accion.es_del_led:
        return
    esperado = led_deseado(sensor, temperatura=lectura.temperatura)
    if lectura.led_reportado == esperado:
        repo_commands.confirmar(comando.id, ahora_utc())


def sensor_en_linea(sensor: Sensor, momento: Optional[datetime] = None) -> bool:
    """Se considera en línea si reportó en los últimos 3 intervalos."""
    if sensor.ultima_lectura_en is None:
        return False
    momento = momento or ahora_utc()
    return (momento - sensor.ultima_lectura_en) < timedelta(seconds=120)
