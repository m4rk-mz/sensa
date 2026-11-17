"""Controlador de negocios, sus usuarios y el registro de sensores."""
from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from app import security
from app.deps import admin_actual, negocio_permitido, usuario_actual
from app.models.business import Negocio, NegocioAltaEntrada
from app.models.common import Rol
from app.models.device import Sensor, SensorAltaEntrada, SensorAltaSalida
from app.models.user import Usuario, UsuarioAltaEntrada, UsuarioSalida
from app.repositories import businesses as repo_businesses
from app.repositories import devices as repo_devices
from app.repositories import users as repo_users

router = APIRouter(prefix="/businesses", tags=["negocios"])


def _negocio_o_404(business_id: str) -> Negocio:
    negocio = repo_businesses.por_id(business_id)
    if negocio is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Negocio no encontrado."
        )
    return negocio


# --------------------------------------------------------------------------
# Negocios
# --------------------------------------------------------------------------
@router.post("", response_model=Negocio, status_code=status.HTTP_201_CREATED)
def crear_negocio(
    datos: NegocioAltaEntrada, _admin: Usuario = Depends(admin_actual)
) -> Negocio:
    """Alta de negocio. Solo administrador de plataforma."""
    if repo_businesses.por_nombre(datos.nombre):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya existe un negocio con ese nombre.",
        )
    negocio = repo_businesses.crear(datos.nombre)
    if negocio is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo crear el negocio.",
        )

    if datos.usuario_inicial is not None:
        _crear_usuario_de_negocio(negocio.id, datos.usuario_inicial)
    return negocio


@router.get("", response_model=list[Negocio])
def listar_negocios(usuario: Usuario = Depends(usuario_actual)) -> list[Negocio]:
    """El administrador ve todos; el usuario de negocio, solo el suyo."""
    if usuario.es_admin:
        return repo_businesses.listar()
    negocio = repo_businesses.por_id(str(usuario.business_id))
    return [negocio] if negocio else []


@router.get("/{business_id}", response_model=Negocio)
def obtener_negocio(
    business_id: str, usuario: Usuario = Depends(usuario_actual)
) -> Negocio:
    negocio_permitido(business_id, usuario)
    return _negocio_o_404(business_id)


# --------------------------------------------------------------------------
# Usuarios del negocio
# --------------------------------------------------------------------------
def _crear_usuario_de_negocio(
    business_id: str, datos: UsuarioAltaEntrada
) -> UsuarioSalida:
    if repo_users.email_existe(str(datos.email)):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ese correo ya está registrado.",
        )
    creado = repo_users.crear(
        nombre=datos.nombre,
        email=str(datos.email),
        password_hash=security.hash_password(datos.password),
        # El rol lo fija el backend, no el formulario.
        rol=Rol.BUSINESS_USER,
        business_id=business_id,
    )
    if creado is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo crear el usuario.",
        )
    return UsuarioSalida.de(creado)


@router.post(
    "/{business_id}/users",
    response_model=UsuarioSalida,
    status_code=status.HTTP_201_CREATED,
)
def crear_usuario(
    business_id: str,
    datos: UsuarioAltaEntrada,
    _admin: Usuario = Depends(admin_actual),
) -> UsuarioSalida:
    _negocio_o_404(business_id)
    return _crear_usuario_de_negocio(business_id, datos)


@router.get("/{business_id}/users", response_model=list[UsuarioSalida])
def listar_usuarios(
    business_id: str, usuario: Usuario = Depends(usuario_actual)
) -> list[UsuarioSalida]:
    negocio_permitido(business_id, usuario)
    _negocio_o_404(business_id)
    return [UsuarioSalida.de(u) for u in repo_users.listar(business_id)]


# --------------------------------------------------------------------------
# Sensores del negocio
# --------------------------------------------------------------------------
@router.post(
    "/{business_id}/devices",
    response_model=SensorAltaSalida,
    status_code=status.HTTP_201_CREATED,
)
def registrar_sensor(
    business_id: str,
    datos: SensorAltaEntrada,
    _admin: Usuario = Depends(admin_actual),
) -> SensorAltaSalida:
    """Registra un nodo ESP32 y devuelve su token una sola vez.

    En la BD queda solo el hash del token: si se pierde, hay que
    registrar el sensor otra vez.
    """
    _negocio_o_404(business_id)

    # Se crea con un hash temporal para obtener el id, porque el token
    # lleva el id dentro; enseguida se reemplaza por el hash definitivo.
    sensor = repo_devices.crear(
        business_id=business_id,
        nombre=datos.nombre,
        umbral_c=datos.umbral_c,
        token_hash="pendiente",
    )
    if sensor is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo registrar el sensor.",
        )

    token, token_hash = security.generar_token_sensor(sensor.id)
    actualizado = repo_devices.actualizar(sensor.id, {"token_hash": token_hash})
    return SensorAltaSalida(sensor=actualizado or sensor, token=token)


@router.get("/{business_id}/devices", response_model=list[Sensor])
def listar_sensores(
    business_id: str, usuario: Usuario = Depends(usuario_actual)
) -> list[Sensor]:
    """Un usuario solo ve los sensores de su negocio.

    Si cambia el business_id en la URL recibe 404, no los datos de otro
    negocio.
    """
    negocio_permitido(business_id, usuario)
    _negocio_o_404(business_id)
    return repo_devices.listar_por_negocio(business_id)
