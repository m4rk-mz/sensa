"""Controlador de sensores: estado para la pantalla "Mis sensores"."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from app.deps import admin_actual, sensor_del_usuario, usuario_actual
from app.models.common import ahora as ahora_utc
from app.models.device import Sensor, SensorEdicionEntrada, SensorEstadoSalida
from app.models.user import Usuario
from app.repositories import devices as repo_devices
from app.repositories import readings as repo_readings
from app.services import led as servicio_led

router = APIRouter(prefix="/devices", tags=["sensores"])


def _estado(sensor: Sensor) -> SensorEstadoSalida:
    momento = ahora_utc()
    ultima = repo_readings.ultima(sensor.id)
    temperatura = ultima.temperatura if ultima else None
    return SensorEstadoSalida(
        sensor=sensor,
        temperatura=temperatura,
        humedad=ultima.humedad if ultima else None,
        alerta=bool(ultima and ultima.alerta),
        led_estado_real=sensor.led_estado_real,
        led_deseado=servicio_led.led_deseado(
            sensor, temperatura=temperatura, momento=momento
        ),
        modo=servicio_led.modo(sensor, momento),
        modo_manual_hasta=sensor.modo_manual_hasta,
        ultima_lectura_en=sensor.ultima_lectura_en,
        en_linea=servicio_led.sensor_en_linea(sensor, momento),
    )


@router.get("", response_model=list[SensorEstadoSalida])
def mis_sensores(usuario: Usuario = Depends(usuario_actual)) -> list[SensorEstadoSalida]:
    """Pantalla "Mis sensores": temperatura, humedad y estado del LED.

    El administrador de plataforma ve todos los sensores; el usuario de
    negocio, solo los de su negocio.
    """
    servicio_led.expirar_comandos_vencidos()
    sensores = (
        repo_devices.listar_todos()
        if usuario.es_admin
        else repo_devices.listar_por_negocio(str(usuario.business_id))
    )
    return [_estado(s) for s in sensores]


@router.get("/{device_id}", response_model=SensorEstadoSalida)
def estado_sensor(sensor: Sensor = Depends(sensor_del_usuario)) -> SensorEstadoSalida:
    servicio_led.expirar_comandos_vencidos()
    return _estado(sensor)


@router.patch("/{device_id}", response_model=Sensor)
def editar_sensor(
    datos: SensorEdicionEntrada,
    sensor: Sensor = Depends(sensor_del_usuario),
    usuario: Usuario = Depends(usuario_actual),
) -> Sensor:
    """Cambia nombre o umbral. Dar de baja un sensor es solo del admin."""
    if datos.activo is not None and not usuario.es_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Solo el administrador de la plataforma puede activar o dar de baja un sensor.",
        )
    actualizado = repo_devices.actualizar(
        sensor.id,
        {"nombre": datos.nombre, "umbral_c": datos.umbral_c, "activo": datos.activo},
    )
    if actualizado is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo actualizar el sensor.",
        )
    return actualizado


@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
def eliminar_sensor(
    sensor: Sensor = Depends(sensor_del_usuario),
    _admin: Usuario = Depends(admin_actual),
) -> None:
    """Borra un sensor y todo lo suyo. Solo el administrador de plataforma.

    Se lleva por delante sus lecturas, comandos y reportes (la BD lo hace
    en cascada), así que no tiene vuelta atrás. Sirve para limpiar los nodos
    de prueba que quedaron registrados y ya no existen.

    Para quitarlo de la lista sin perder su historial, usar
    `PATCH /devices/{id}` con `activo: false`.
    """
    if not repo_devices.eliminar(sensor.id):
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo eliminar el sensor.",
        )
