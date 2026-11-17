"""Base de datos falsa en memoria que imita al cliente de Supabase.

Sirve para probar repositorios, reporte diario y panel sin tocar la red.
Soporta lo que usa el backend: select/insert/update/upsert con eq, gte,
lt, in_, order y limit.
"""
from __future__ import annotations

import itertools
import uuid
from datetime import date, datetime, timezone
from typing import Any

_contador = itertools.count(1)


def _a_datetime(valor: Any) -> Any:
    if isinstance(valor, str):
        try:
            return datetime.fromisoformat(valor.replace("Z", "+00:00"))
        except ValueError:
            return valor
    return valor


def _comparable(valor: Any) -> Any:
    valor = _a_datetime(valor)
    if isinstance(valor, datetime) and valor.tzinfo is None:
        return valor.replace(tzinfo=timezone.utc)
    return valor


class Respuesta:
    def __init__(self, data: list[dict[str, Any]]):
        self.data = data


class Consulta:
    def __init__(self, tabla: "Tabla"):
        self.tabla = tabla
        self._filtros: list[Any] = []
        self._orden: tuple[str, bool] | None = None
        self._limite: int | None = None
        self._modo = "select"
        self._payload: Any = None
        self._on_conflict: str | None = None

    # -- construcción ----------------------------------------------------
    def select(self, _campos: str = "*", **_kw) -> "Consulta":
        self._modo = "select"
        return self

    def insert(self, datos: dict[str, Any] | list[dict[str, Any]]) -> "Consulta":
        self._modo = "insert"
        self._payload = datos
        return self

    def update(self, datos: dict[str, Any]) -> "Consulta":
        self._modo = "update"
        self._payload = datos
        return self

    def upsert(self, datos: dict[str, Any], on_conflict: str | None = None) -> "Consulta":
        self._modo = "upsert"
        self._payload = datos
        self._on_conflict = on_conflict
        return self

    def eq(self, campo: str, valor: Any) -> "Consulta":
        self._filtros.append(lambda f: f.get(campo) == valor)
        return self

    def gte(self, campo: str, valor: Any) -> "Consulta":
        v = _comparable(valor)
        self._filtros.append(lambda f: _comparable(f.get(campo)) >= v)
        return self

    def lt(self, campo: str, valor: Any) -> "Consulta":
        v = _comparable(valor)
        self._filtros.append(lambda f: _comparable(f.get(campo)) < v)
        return self

    def in_(self, campo: str, valores: list[Any]) -> "Consulta":
        self._filtros.append(lambda f: f.get(campo) in valores)
        return self

    def order(self, campo: str, desc: bool = False) -> "Consulta":
        self._orden = (campo, desc)
        return self

    def limit(self, n: int) -> "Consulta":
        self._limite = n
        return self

    # -- ejecución -------------------------------------------------------
    def _coinciden(self) -> list[dict[str, Any]]:
        return [f for f in self.tabla.filas if all(p(f) for p in self._filtros)]

    def execute(self) -> Respuesta:
        if self._modo == "insert":
            nuevos = (
                self._payload if isinstance(self._payload, list) else [self._payload]
            )
            creados = [self.tabla.insertar(d) for d in nuevos]
            return Respuesta(creados)

        if self._modo == "update":
            actualizados = []
            for fila in self._coinciden():
                fila.update(self._payload)
                actualizados.append(dict(fila))
            return Respuesta(actualizados)

        if self._modo == "upsert":
            claves = [c.strip() for c in (self._on_conflict or "").split(",") if c.strip()]
            for fila in self.tabla.filas:
                if claves and all(
                    str(fila.get(k)) == str(self._payload.get(k)) for k in claves
                ):
                    fila.update(self._payload)
                    return Respuesta([dict(fila)])
            return Respuesta([self.tabla.insertar(self._payload)])

        filas = [dict(f) for f in self._coinciden()]
        if self._orden:
            campo, desc = self._orden
            filas.sort(key=lambda f: _comparable(f.get(campo)) or 0, reverse=desc)
        if self._limite is not None:
            filas = filas[: self._limite]
        return Respuesta(filas)


class Tabla:
    def __init__(self, nombre: str):
        self.nombre = nombre
        self.filas: list[dict[str, Any]] = []

    def insertar(self, datos: dict[str, Any]) -> dict[str, Any]:
        fila = dict(datos)
        fila.setdefault("id", str(uuid.uuid4()))
        fila.setdefault("creado_en", datetime.now(timezone.utc).isoformat())
        if self.nombre == "daily_reports":
            fila.setdefault("generado_en", datetime.now(timezone.utc).isoformat())
        if self.nombre == "devices":
            fila.setdefault("activo", True)
            fila.setdefault("led_estado_real", False)
        if self.nombre == "users":
            fila.setdefault("activo", True)
        for clave, valor in list(fila.items()):
            if isinstance(valor, (datetime, date)):
                fila[clave] = valor.isoformat()
        self.filas.append(fila)
        return dict(fila)


class ClienteFalso:
    def __init__(self):
        self.tablas: dict[str, Tabla] = {}

    def table(self, nombre: str) -> Consulta:
        if nombre not in self.tablas:
            self.tablas[nombre] = Tabla(nombre)
        return Consulta(self.tablas[nombre])


def instalar() -> ClienteFalso:
    """Parcha app.db.client para que los repositorios usen la BD falsa."""
    import app.db.client as cliente_real

    falso = ClienteFalso()
    cliente_real.get_client = lambda: falso  # type: ignore[assignment]
    cliente_real.table = falso.table  # type: ignore[assignment]

    # Los repositorios importaron `table` por nombre, así que hay que
    # reemplazarlo en cada módulo que ya lo tenga cargado.
    import sys

    for nombre, modulo in list(sys.modules.items()):
        if nombre.startswith("app.repositories.") and hasattr(modulo, "table"):
            modulo.table = falso.table  # type: ignore[attr-defined]
    return falso
