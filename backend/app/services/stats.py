"""Estadísticas del panel de administrador.

Una tabla (un renglón por negocio) y una gráfica (temperatura promedio por
negocio), ambas calculadas solo con lecturas válidas. También informa
cuántos registros se descartaron, que es justo lo que pide la prueba 5.
"""
from __future__ import annotations

from datetime import timedelta

from app.models.common import ahora as ahora_utc
from app.models.report import FilaPanelNegocio, PanelAdminSalida, PuntoGrafica
from app.repositories import businesses as repo_businesses
from app.repositories import devices as repo_devices
from app.repositories import readings as repo_readings
from app.repositories import users as repo_users
from app.services import led as servicio_led


def panel() -> PanelAdminSalida:
    momento = ahora_utc()
    desde = momento - timedelta(hours=24)

    negocios = repo_businesses.listar()
    usuarios = repo_users.listar()
    sensores = repo_devices.listar_todos()

    filas: list[FilaPanelNegocio] = []
    grafica: list[PuntoGrafica] = []
    total_validas = 0
    total_descartadas = 0
    total_alertas = 0

    for negocio in negocios:
        del_negocio = [s for s in sensores if s.business_id == negocio.id]
        ids = [s.id for s in del_negocio]
        lecturas, descartadas = repo_readings.listar_por_negocio_desde(ids, desde)

        temps = [l.temperatura for l in lecturas]
        promedio = round(sum(temps) / len(temps), 1) if temps else None
        alertas = sum(1 for l in lecturas if l.alerta)

        total_validas += len(lecturas)
        total_descartadas += descartadas
        total_alertas += alertas

        filas.append(
            FilaPanelNegocio(
                business_id=negocio.id,
                negocio=negocio.nombre,
                sensores=len(del_negocio),
                usuarios=sum(1 for u in usuarios if u.business_id == negocio.id),
                lecturas_24h=len(lecturas),
                temp_promedio=promedio,
                temp_max=round(max(temps), 1) if temps else None,
                alertas_24h=alertas,
                sensores_en_linea=sum(
                    1 for s in del_negocio if servicio_led.sensor_en_linea(s, momento)
                ),
            )
        )
        if promedio is not None:
            grafica.append(PuntoGrafica(etiqueta=negocio.nombre, valor=promedio))

    return PanelAdminSalida(
        generado_en=momento,
        total_negocios=len(negocios),
        total_sensores=len(sensores),
        total_usuarios=len(usuarios),
        lecturas_validas_24h=total_validas,
        lecturas_descartadas_24h=total_descartadas,
        alertas_24h=total_alertas,
        tabla=sorted(filas, key=lambda f: f.negocio.lower()),
        grafica_temp_promedio=sorted(grafica, key=lambda p: p.valor, reverse=True),
    )
