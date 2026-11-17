"""Controlador de lecturas.

El POST lo usa el ESP32 con su token; el GET, la app con la sesión del
usuario. El procesamiento (alerta y estado del LED) ocurre aquí, en el
backend, como pide el documento.
"""
from __future__ import annotations

from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.deps import sensor_autenticado, sensor_del_usuario
from app.models.common import ahora as ahora_utc
from app.models.device import Sensor
from app.models.reading import Lectura, LecturaEntrada, LecturaRegistradaSalida
from app.repositories import devices as repo_devices
from app.repositories import readings as repo_readings
from app.services import led as servicio_led

router = APIRouter(prefix="/devices", tags=["lecturas"])


@router.post(
    "/{device_id}/readings",
    response_model=LecturaRegistradaSalida,
    status_code=status.HTTP_201_CREATED,
)
def registrar_lectura(
    datos: LecturaEntrada, sensor: Sensor = Depends(sensor_autenticado)
) -> LecturaRegistradaSalida:
    """Recibe una lectura del nodo y le responde qué hacer con el LED.

    Una lectura fuera de los rangos del DHT11 se rechaza con 422 por los
    modelos y no se guarda, venga de la app, de Postman o de curl.
    """
    momento = ahora_utc()
    alerta = datos.temperatura > sensor.umbral_c

    lectura = repo_readings.crear(
        device_id=sensor.id,
        temperatura=datos.temperatura,
        humedad=datos.humedad,
        led_reportado=datos.led_estado,
        alerta=alerta,
    )
    if lectura is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo guardar la lectura.",
        )

    repo_devices.registrar_estado_nodo(
        sensor.id, led_estado_real=datos.led_estado, ultima_lectura_en=momento
    )

    # El nodo reporta su estado real en cada lectura: si ya coincide con lo
    # pedido, el comando queda confirmado sin depender del ack.
    servicio_led.confirmar_por_lectura(sensor, lectura)
    servicio_led.expirar_comandos_vencidos(momento)

    return LecturaRegistradaSalida(
        lectura=lectura,
        alerta=alerta,
        led_deseado=servicio_led.led_deseado(
            sensor, temperatura=datos.temperatura, momento=momento
        ),
        umbral_c=sensor.umbral_c,
        modo=servicio_led.modo(sensor, momento),
    )


@router.get("/{device_id}/readings", response_model=list[Lectura])
def listar_lecturas(
    horas: int = Query(default=24, ge=1, le=168),
    limite: int = Query(default=100, ge=1, le=1000),
    sensor: Sensor = Depends(sensor_del_usuario),
) -> list[Lectura]:
    """Lecturas del sensor, de la más reciente a la más antigua.

    Solo devuelve lecturas válidas: un registro insertado a mano en la BD
    fuera de rango se descarta al leerlo y no aparece aquí.
    """
    desde: Optional[datetime] = ahora_utc() - timedelta(hours=horas)
    lecturas, _descartadas = repo_readings.listar(
        sensor.id, desde=desde, limite=limite
    )
    return lecturas
