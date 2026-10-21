import uuid

import pytest
from fastapi.testclient import TestClient

from app.main import app
from tests.conftest import HOY, entrar
from tests.test_api import _registro


def _como(client, nombre, pin):
    otro = TestClient(app)
    otro.headers["Authorization"] = f"Bearer {entrar(client, nombre, pin)}"
    return otro


@pytest.fixture
def mama(client):
    assert client.post("/usuarios", json={"nombre": "Mamá", "pin": "729104"}).status_code == 201
    return _como(client, "Mamá", "729104")


def test_sin_sesion_no_se_ve_nada(client):
    anonimo = TestClient(app)
    assert anonimo.get("/galpones").status_code == 401
    assert anonimo.get("/galpones/resumen").status_code == 401
    assert anonimo.put(f"/registros/{uuid.uuid4()}", json={}).status_code == 401
    assert anonimo.get("/salud").status_code == 200


def test_un_token_falso_es_401(client):
    falso = TestClient(app)
    falso.headers["Authorization"] = "Bearer falso"
    assert falso.get("/galpones").status_code == 401


def test_pin_incorrecto_es_401_y_cinco_fallos_bloquean(client, mama):
    for _ in range(5):
        assert client.post("/sesion", json={"nombre": "Mamá", "pin": "000001"}).status_code == 401
    assert client.post("/sesion", json={"nombre": "Mamá", "pin": "729104"}).status_code == 429


def test_la_respuesta_nunca_trae_el_pin(client, mama):
    r = client.get("/usuarios")
    assert r.status_code == 200
    assert "pin" not in r.text and "hash" not in r.text


def test_el_registrador_registra_y_ve_pero_no_configura(client, granja, mama):
    assert mama.get("/galpones/resumen", params={"fecha": HOY.isoformat()}).status_code == 200
    datos = _registro(granja["galpon"]["id"])
    assert mama.put(f"/registros/{datos['id']}", json=datos).status_code == 200
    assert mama.post("/galpones", json={"nombre": "Nuevo", "capacidad_aves": 1000}).status_code == 403
    assert mama.post("/lineas", json={"nombre": "Otra"}).status_code == 403
    assert mama.post("/usuarios", json={"nombre": "X", "pin": "729104"}).status_code == 403
    assert mama.get("/usuarios").status_code == 403


def test_solo_el_administrador_borra_registros(client, granja, mama):
    datos = _registro(granja["galpon"]["id"])
    client.put(f"/registros/{datos['id']}", json=datos)
    assert mama.delete(f"/registros/{datos['id']}").status_code == 403
    assert client.delete(f"/registros/{datos['id']}").status_code == 204
    pedido = {"galpon_id": granja["galpon"]["id"], "fecha": HOY.isoformat()}
    assert client.get("/registros", params=pedido).json() == []
    assert client.delete(f"/registros/{datos['id']}").status_code == 404


def test_cerrar_sesion_y_desactivar_usuario(client, mama):
    assert mama.get("/sesion").json()["nombre"] == "Mamá"
    assert mama.delete("/sesion").status_code == 204
    assert mama.get("/galpones").status_code == 401
    otra = _como(client, "Mamá", "729104")
    uid = next(u["id"] for u in client.get("/usuarios").json() if u["nombre"] == "Mamá")
    assert client.post(f"/usuarios/{uid}/desactivar").status_code == 200
    assert otra.get("/galpones").status_code == 401
    assert client.post("/sesion", json={"nombre": "Mamá", "pin": "729104"}).status_code == 401
