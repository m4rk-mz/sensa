"""Punto de entrada del backend de Sensa (FastAPI).

Arquitectura MC:
- app/models       -> estructura y validación (entradas y filas de BD)
- app/controllers  -> permisos y endpoints
- app/repositories -> acceso a datos vía el cliente de Supabase
- app/services     -> reglas compartidas (LED, reporte diario, panel)

Levantar:  uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
Documentación interactiva: http://localhost:8000/docs
"""
from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings
from app.controllers import admin, auth, businesses, commands, devices, readings, reports
from app.services import scheduler

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
log = logging.getLogger("sensa")


@asynccontextmanager
async def lifespan(_app: FastAPI):
    settings.validar()
    scheduler.iniciar()
    log.info("Sensa API lista.")
    yield
    scheduler.detener()


app = FastAPI(
    title=settings.app_name,
    version="1.0.0",
    description=(
        "Monitoreo de temperatura y humedad por negocio. "
        "Roles: administrador de plataforma y usuario de negocio."
    ),
    lifespan=lifespan,
)

# La API no usa cookies: la sesión viaja en el encabezado Authorization. Por eso
# no se permiten credenciales; los navegadores rechazan "*" combinado con ellas.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins or ["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(RequestValidationError)
async def errores_de_validacion(_request: Request, exc: RequestValidationError):
    """Respuesta de validación en un formato que la app pueda mostrar campo por campo."""
    errores = [
        {
            "campo": ".".join(str(p) for p in e.get("loc", []) if p != "body"),
            "mensaje": e.get("msg", "Valor inválido."),
        }
        for e in exc.errors()
    ]
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": "Hay datos inválidos en la petición.", "errores": errores},
    )


@app.get("/health", tags=["servicio"])
def health() -> dict:
    return {"estado": "ok", "servicio": settings.app_name}


for router in (
    auth.router,
    businesses.router,
    devices.router,
    readings.router,
    commands.router,
    reports.router,
    admin.router,
):
    app.include_router(router)
