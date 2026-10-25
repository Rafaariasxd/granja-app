import os
from datetime import date

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.adaptadores.api.dependencias import unidad_de_trabajo
from app.adaptadores.db.conexion import url_de_base
from app.adaptadores.db.repositorios import UnidadDeTrabajoSql
from app.adaptadores.db.tablas import Base
from app.casos_uso import usuarios
from app.dominio.modelos import Rol
from app.main import app

HOY = date(2026, 10, 15)
PIN_ADMIN = "483920"


def entrar(cliente, nombre, pin):
    return cliente.post("/sesion", json={"nombre": nombre, "pin": pin}).json()["token"]


def _motor():
    url = os.getenv("PRUEBAS_DATABASE_URL")
    if url:
        motor = create_engine(url_de_base(url))
        Base.metadata.drop_all(motor)
        return motor
    return create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)


@pytest.fixture
def client():
    engine = _motor()
    Base.metadata.create_all(engine)
    Sesion = sessionmaker(bind=engine, expire_on_commit=False)

    def unidad_de_prueba():
        with Sesion() as s:
            yield UnidadDeTrabajoSql(s)

    app.dependency_overrides[unidad_de_trabajo] = unidad_de_prueba
    with Sesion() as s:
        usuarios.crear_usuario(UnidadDeTrabajoSql(s), "Rafa", PIN_ADMIN, Rol.ADMINISTRADOR)
    cliente = TestClient(app)
    cliente.headers["Authorization"] = f"Bearer {entrar(cliente, 'Rafa', PIN_ADMIN)}"
    yield cliente
    app.dependency_overrides.clear()
    engine.dispose()


@pytest.fixture
def granja(client):
    galpon = client.post("/galpones", json={"nombre": "Galpón 1", "capacidad_aves": 6000}).json()
    vacio = client.post("/galpones", json={"nombre": "Galpón 2", "capacidad_aves": 2000}).json()
    linea = client.post("/lineas", json={"nombre": "Hy-Line Brown"}).json()
    lote = client.post(
        "/lotes",
        json={
            "galpon_id": galpon["id"],
            "linea_id": linea["id"],
            "fecha_nacimiento": "2026-03-01",
            "fecha_ingreso": "2026-03-02",
            "aves_iniciales": 5000,
        },
    ).json()
    return {"galpon": galpon, "vacio": vacio, "linea": linea, "lote": lote}
