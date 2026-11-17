"""Inicialización documentada del primer administrador de plataforma.

El requisito del documento de clase: el primer administrador se crea
directamente en la base de datos, con el mismo hash de contraseñas que usa
el backend. Este script importa `app.security`, así que el hash es
exactamente el mismo que verifica el login (Argon2id).

Uso:

    # Solo el primer administrador
    python -m scripts.seed_admin --email admin@sensa.mx --password "Admin1234"

    # Administrador + negocio, usuario y sensor de prueba (recomendado
    # para la demo; imprime el token del sensor una sola vez)
    python -m scripts.seed_admin --email admin@sensa.mx --password "Admin1234" --demo

Es idempotente: si el correo ya existe, no lo duplica ni cambia su
contraseña.
"""
from __future__ import annotations

import argparse
import sys

from app import security
from app.config import settings
from app.models.common import Rol
from app.repositories import businesses as repo_businesses
from app.repositories import devices as repo_devices
from app.repositories import users as repo_users

NEGOCIO_DEMO = "Fríos del Norte"
SENSOR_DEMO = "Nodo cuarto de servidor"
USUARIO_DEMO_EMAIL = "usuario@friosdelnorte.mx"
USUARIO_DEMO_PASSWORD = "Usuario1234"


def crear_admin(nombre: str, email: str, password: str) -> None:
    if repo_users.email_existe(email):
        print(f"· El administrador {email} ya existe. No se modifica.")
        return
    creado = repo_users.crear(
        nombre=nombre,
        email=email,
        password_hash=security.hash_password(password),
        rol=Rol.PLATFORM_ADMIN,
        business_id=None,  # el admin de plataforma no pertenece a un negocio
    )
    if creado is None:
        sys.exit("No se pudo crear el administrador. Revisa el esquema y las llaves.")
    print(f"✓ Administrador de plataforma creado: {creado.email} (id {creado.id})")


def crear_demo() -> None:
    negocio = repo_businesses.por_nombre(NEGOCIO_DEMO) or repo_businesses.crear(
        NEGOCIO_DEMO
    )
    if negocio is None:
        sys.exit("No se pudo crear el negocio de prueba.")
    print(f"✓ Negocio de prueba: {negocio.nombre} (id {negocio.id})")

    if repo_users.email_existe(USUARIO_DEMO_EMAIL):
        print(f"· El usuario de prueba {USUARIO_DEMO_EMAIL} ya existe.")
    else:
        usuario = repo_users.crear(
            nombre="Lupita del almacén",
            email=USUARIO_DEMO_EMAIL,
            password_hash=security.hash_password(USUARIO_DEMO_PASSWORD),
            rol=Rol.BUSINESS_USER,
            business_id=negocio.id,
        )
        if usuario is None:
            sys.exit("No se pudo crear el usuario de prueba.")
        print(
            f"✓ Usuario de negocio: {usuario.email} / {USUARIO_DEMO_PASSWORD} "
            f"(negocio {negocio.nombre})"
        )

    if repo_devices.por_nombre(SENSOR_DEMO) is not None:
        print(
            f"· El sensor «{SENSOR_DEMO}» ya existe. El token solo se muestra al "
            "registrarlo; si lo perdiste, bórralo y vuelve a correr el script."
        )
        return

    sensor = repo_devices.crear(
        business_id=negocio.id,
        nombre=SENSOR_DEMO,
        umbral_c=settings.default_threshold_c,
        token_hash="pendiente",
    )
    if sensor is None:
        sys.exit("No se pudo registrar el sensor de prueba.")
    token, token_hash = security.generar_token_sensor(sensor.id)
    repo_devices.actualizar(sensor.id, {"token_hash": token_hash})

    print(f"✓ Sensor registrado: {sensor.nombre} (id {sensor.id})")
    print("\n  Token del sensor (cópialo al firmware del ESP32; no se vuelve a mostrar):")
    print(f"  {token}\n")


def main() -> None:
    parser = argparse.ArgumentParser(description="Inicializa Sensa.")
    parser.add_argument("--email", required=True, help="Correo del administrador.")
    parser.add_argument(
        "--password", required=True, help="Contraseña del administrador (mínimo 8)."
    )
    parser.add_argument(
        "--nombre", default="Administrador Sensa", help="Nombre del administrador."
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Crea además negocio, usuario y sensor de prueba.",
    )
    args = parser.parse_args()

    if len(args.password) < 8:
        sys.exit("La contraseña debe tener al menos 8 caracteres.")

    settings.validar()
    print(f"Proyecto Supabase: {settings.supabase_url}\n")

    crear_admin(args.nombre, args.email.strip().lower(), args.password)
    if args.demo:
        crear_demo()

    print("Listo. Ahora puedes iniciar sesión en POST /auth/login.")


if __name__ == "__main__":
    main()
