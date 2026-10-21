import uuid
from datetime import date

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db import Base, get_session
from app.main import app

HOY = date(2026, 10, 15)


@pytest.fixture
def client():
    engine = create_engine("sqlite://", connect_args={"check_same_thread": False}, poolclass=StaticPool)
    Base.metadata.create_all(engine)
    Sesion = sessionmaker(bind=engine, expire_on_commit=False)

    def sesion_de_prueba():
        with Sesion() as s:
            yield s

    app.dependency_overrides[get_session] = sesion_de_prueba
    yield TestClient(app)
    app.dependency_overrides.clear()


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


def _registro(galpon_id, fecha=HOY, **campos):
    return {"id": str(uuid.uuid4()), "galpon_id": galpon_id, "fecha": fecha.isoformat(), "huevos_total": 4000, **campos}


def test_salud(client):
    assert client.get("/salud").json() == {"estado": "ok"}


def test_nombre_de_galpon_repetido(client, granja):
    r = client.post("/galpones", json={"nombre": "Galpón 1", "capacidad_aves": 3000})
    assert r.status_code == 409


def test_no_se_puede_meter_dos_lotes_en_el_mismo_galpon(client, granja):
    r = client.post(
        "/lotes",
        json={
            "galpon_id": granja["galpon"]["id"],
            "linea_id": granja["linea"]["id"],
            "fecha_nacimiento": "2026-05-01",
            "fecha_ingreso": "2026-05-02",
            "aves_iniciales": 1000,
        },
    )
    assert r.status_code == 409


def test_lote_no_puede_superar_la_capacidad(client, granja):
    r = client.post(
        "/lotes",
        json={
            "galpon_id": granja["vacio"]["id"],
            "linea_id": granja["linea"]["id"],
            "fecha_nacimiento": "2026-05-01",
            "fecha_ingreso": "2026-05-02",
            "aves_iniciales": 2500,
        },
    )
    assert r.status_code == 422


def test_registro_es_idempotente(client, granja):
    datos = _registro(granja["galpon"]["id"], mortalidad=3)
    primero = client.put(f"/registros/{datos['id']}", json=datos)
    reenvio = client.put(f"/registros/{datos['id']}", json=datos)
    assert primero.status_code == reenvio.status_code == 200
    assert primero.json() == reenvio.json()


def test_corregir_un_registro(client, granja):
    datos = _registro(granja["galpon"]["id"])
    client.put(f"/registros/{datos['id']}", json=datos)
    datos["huevos_total"] = 4100
    r = client.put(f"/registros/{datos['id']}", json=datos)
    assert r.json()["huevos_total"] == 4100


def test_dos_registros_distintos_el_mismo_dia_chocan(client, granja):
    a = _registro(granja["galpon"]["id"])
    b = _registro(granja["galpon"]["id"])
    client.put(f"/registros/{a['id']}", json=a)
    assert client.put(f"/registros/{b['id']}", json=b).status_code == 409


def test_registro_en_galpon_vacio(client, granja):
    datos = _registro(granja["vacio"]["id"])
    assert client.put(f"/registros/{datos['id']}", json=datos).status_code == 422


def test_huevos_negativos_rechazados(client, granja):
    datos = _registro(granja["galpon"]["id"], huevos_total=-1)
    assert client.put(f"/registros/{datos['id']}", json=datos).status_code == 422


def test_resumen_como_el_tablero(client, granja):
    gid = granja["galpon"]["id"]
    for fecha, muertas in [(date(2026, 10, 14), 20), (HOY, 30)]:
        datos = _registro(gid, fecha=fecha, mortalidad=muertas)
        client.put(f"/registros/{datos['id']}", json=datos)

    resumen = {g["nombre"]: g for g in client.get("/galpones/resumen", params={"fecha": HOY}).json()}

    lleno = resumen["Galpón 1"]
    assert lleno["aves_vivas"] == 4950
    assert lleno["etapa"] == "produccion"
    assert lleno["edad_semanas"] == 32
    assert lleno["ocupacion_pct"] == 82.5
    assert lleno["postura_pct"] == 80.8

    vacio = resumen["Galpón 2"]
    assert vacio["lote_id"] is None
    assert vacio["aves_vivas"] == 0
    assert vacio["postura_pct"] is None


def test_lote_cerrado_libera_el_galpon(client, granja):
    lote = granja["lote"]
    client.post(f"/lotes/{lote['id']}/salida", params={"fecha_salida": "2026-10-01"})
    datos = _registro(granja["galpon"]["id"])
    assert client.put(f"/registros/{datos['id']}", json=datos).status_code == 422
