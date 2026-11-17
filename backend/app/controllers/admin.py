"""Controlador del administrador de plataforma.

Todos los endpoints de aquí exigen rol platform_admin, leído de la BD.
Un usuario de negocio con sesión válida recibe 403 aunque conozca la URL.
"""
from __future__ import annotations

from datetime import date
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.deps import admin_actual
from app.models.report import PanelAdminSalida, PuntoGrafica, ReporteDiario
from app.models.user import Usuario, UsuarioSalida
from app.repositories import users as repo_users
from app.services import daily_report as servicio_reporte
from app.services import stats as servicio_stats

router = APIRouter(prefix="/admin", tags=["administración"])


@router.get("/users", response_model=list[UsuarioSalida])
def listar_usuarios(
    business_id: Optional[str] = Query(default=None),
    _admin: Usuario = Depends(admin_actual),
) -> list[UsuarioSalida]:
    return [UsuarioSalida.de(u) for u in repo_users.listar(business_id)]


@router.post("/users/{user_id}/promover", response_model=UsuarioSalida)
def promover(
    user_id: str, admin: Usuario = Depends(admin_actual)
) -> UsuarioSalida:
    """Promueve a un usuario a administrador de plataforma.

    El cambio se guarda en la BD, así que persiste al volver a iniciar
    sesión. La app pide confirmación antes de llamar esto.
    """
    objetivo = repo_users.por_id(user_id)
    if objetivo is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Usuario no encontrado."
        )
    if objetivo.es_admin:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ese usuario ya es administrador de la plataforma.",
        )

    promovido = repo_users.promover_a_admin(user_id)
    if promovido is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo promover al usuario.",
        )
    return UsuarioSalida.de(promovido)


@router.get("/stats/negocios", response_model=PanelAdminSalida)
def panel_negocios(_admin: Usuario = Depends(admin_actual)) -> PanelAdminSalida:
    """Panel: tabla por negocio y gráfica, con lecturas válidas de 24 h.

    `lecturas_descartadas_24h` dice cuántos registros inválidos se
    excluyeron: es la evidencia de la prueba 5 de la demo.
    """
    return servicio_stats.panel()


@router.get("/stats/temp-promedio-por-negocio", response_model=list[PuntoGrafica])
def grafica_temp_promedio(
    _admin: Usuario = Depends(admin_actual),
) -> list[PuntoGrafica]:
    """Serie lista para la gráfica del panel."""
    return servicio_stats.panel().grafica_temp_promedio


@router.post("/reportes/generar", response_model=list[ReporteDiario])
def generar_reportes(
    fecha: Optional[date] = Query(
        default=None, description="Por omisión, el día anterior."
    ),
    _admin: Usuario = Depends(admin_actual),
) -> list[ReporteDiario]:
    """Dispara la tarea del reporte diario a mano.

    Útil en la demo para no esperar a la medianoche.
    """
    return servicio_reporte.generar_todos(fecha)
