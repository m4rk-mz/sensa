"""Configuración del backend de Sensa.

Todo se lee de variables de entorno (.env). No hay secretos en el código.
"""
from __future__ import annotations

import os
from functools import lru_cache

from dotenv import load_dotenv

load_dotenv()


class Settings:
    # --- Supabase ---------------------------------------------------------
    # SUPABASE_URL:     https://<proyecto>.supabase.co
    # SUPABASE_SERVICE_KEY: service_role key. Solo vive en el servidor: el
    # backend es quien aplica los permisos, así que esta llave nunca se
    # manda a la app móvil.
    # --- Rangos del sensor DHT11 (datasheet) ------------------------------
    # Fijos: vienen del hardware, no del entorno.
    temp_min_c: float = 0.0
    temp_max_c: float = 50.0
    hum_min_pct: float = 20.0
    hum_max_pct: float = 90.0

    app_name: str = "Sensa API"
    jwt_algorithm: str = "HS256"

    def __init__(self) -> None:
        # Se lee en __init__ (no en la clase) para que una instancia nueva
        # vea el entorno actual: así las pruebas pueden variarlo.
        self.supabase_url = os.getenv("SUPABASE_URL", "")
        self.supabase_service_key = os.getenv("SUPABASE_SERVICE_KEY", "")

        # --- Sesión -------------------------------------------------------
        self.jwt_secret = os.getenv("JWT_SECRET", "")
        self.jwt_exp_minutes = int(os.getenv("JWT_EXP_MINUTES", "720"))  # 12 h

        # --- Reglas de negocio --------------------------------------------
        # Duración del modo manual del LED antes de volver a automático.
        self.manual_mode_minutes = int(os.getenv("MANUAL_MODE_MINUTES", "30"))
        # Segundos sin confirmación tras los que un comando se marca
        # "sin_respuesta".
        self.command_timeout_seconds = int(os.getenv("COMMAND_TIMEOUT_SECONDS", "15"))
        # Umbral por omisión al registrar un sensor nuevo (°C).
        self.default_threshold_c = float(os.getenv("DEFAULT_THRESHOLD_C", "27.0"))

        # --- Tarea programada ---------------------------------------------
        self.timezone = os.getenv("TIMEZONE", "America/Mexico_City")
        self.daily_report_hour = int(os.getenv("DAILY_REPORT_HOUR", "0"))
        self.daily_report_minute = int(os.getenv("DAILY_REPORT_MINUTE", "10"))
        self.enable_scheduler = os.getenv("ENABLE_SCHEDULER", "true").lower() == "true"

        # --- App ----------------------------------------------------------
        self.cors_origins = [
            o.strip() for o in os.getenv("CORS_ORIGINS", "*").split(",") if o.strip()
        ]

    def validar(self) -> None:
        faltantes = [
            nombre
            for nombre, valor in (
                ("SUPABASE_URL", self.supabase_url),
                ("SUPABASE_SERVICE_KEY", self.supabase_service_key),
                ("JWT_SECRET", self.jwt_secret),
            )
            if not valor
        ]
        if faltantes:
            raise RuntimeError(
                "Faltan variables de entorno: "
                + ", ".join(faltantes)
                + ". Copia .env.example a .env y llénalas."
            )
        # HS256 firma con HMAC-SHA256: menos de 32 bytes debilita la firma.
        if len(self.jwt_secret.encode()) < 32:
            raise RuntimeError(
                "JWT_SECRET debe tener al menos 32 caracteres. Genera uno con: "
                'python -c "import secrets; print(secrets.token_urlsafe(48))"'
            )


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
