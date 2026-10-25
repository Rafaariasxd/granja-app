import uuid
from datetime import UTC, datetime

import pytest

from app.dominio.fechas import fecha_en_granja
from tests.test_api_permisos import _como, mama  # noqa: F401


def _insumo(client, nombre, tipo, **campos):
    r = client.post("/insumos", json={"nombre": nombre, "tipo": tipo, **campos})
    assert r.status_code == 201, r.text
    return r.json()


@pytest.fixture
def bodega(client):
    maiz = _insumo(client, "Maíz", "materia_prima", kg_por_bulto=50)
    soya = _insumo(client, "Soya", "materia_prima", kg_por_bulto=40)
    mezcla = _insumo(client, "Mezcla ponedora", "alimento_preparado", etapa="produccion")
    italcol = _insumo(client, "Italcol ponedora", "alimento_comprado", etapa="produccion", kg_por_bulto=40)
    formula = [{"insumo_id": maiz["id"], "porcentaje": 70}, {"insumo_id": soya["id"], "porcentaje": 30}]
    assert client.put(f"/alimentos/{mezcla['id']}/formula", json=formula).status_code == 200
    return {"maiz": maiz, "soya": soya, "mezcla": mezcla, "italcol": italcol}


def _existencia(client, insumo):
    existencias = client.get("/inventario").json()["existencias"]
    return next(e for e in existencias if e["insumo"]["id"] == insumo["id"])


def test_comprar_medio_bulto(client, bodega):
    r = client.post(f"/insumos/{bodega['maiz']['id']}/compras", json={"bultos": 2.5})
    assert r.status_code == 201
    assert r.json()["kg"] == 125
    assert r.json()["motivo"] == "compra"
    existencia = _existencia(client, bodega["maiz"])
    assert (existencia["stock_kg"], existencia["bultos"]) == (125, 2.5)


def test_la_compra_sin_cantidad_es_422(client, bodega):
    assert client.post(f"/insumos/{bodega['maiz']['id']}/compras", json={}).status_code == 422
    assert client.post(f"/insumos/{bodega['maiz']['id']}/compras", json={"bultos": -1}).status_code == 422


def test_el_insumo_repetido_es_409_y_el_inexistente_404(client, bodega):
    repetido = {"nombre": "Maíz", "tipo": "materia_prima", "kg_por_bulto": 50}
    assert client.post("/insumos", json=repetido).status_code == 409
    assert client.post("/insumos/999/compras", json={"kg": 5}).status_code == 404


def test_la_formula_que_no_suma_cien_es_422(client, bodega):
    formula = [{"insumo_id": bodega["maiz"]["id"], "porcentaje": 70}]
    assert client.put(f"/alimentos/{bodega['mezcla']['id']}/formula", json=formula).status_code == 422


def test_la_formula_se_puede_consultar(client, bodega):
    formula = client.get(f"/alimentos/{bodega['mezcla']['id']}/formula").json()
    assert [(i["insumo_id"], i["porcentaje"]) for i in formula] == [
        (bodega["maiz"]["id"], 70),
        (bodega["soya"]["id"], 30),
    ]


def test_preparar_alimento_gasta_materia_prima(client, bodega):
    client.post(f"/insumos/{bodega['maiz']['id']}/compras", json={"bultos": 10})
    client.post(f"/insumos/{bodega['soya']['id']}/compras", json={"bultos": 10})

    r = client.post(f"/alimentos/{bodega['mezcla']['id']}/preparaciones", json={"kg": 200})

    assert r.status_code == 201
    assert _existencia(client, bodega["mezcla"])["stock_kg"] == 200
    assert _existencia(client, bodega["maiz"])["stock_kg"] == 360
    assert _existencia(client, bodega["soya"])["stock_kg"] == 340


def test_preparar_sin_materia_prima_explica_que_falta(client, bodega):
    r = client.post(f"/alimentos/{bodega['mezcla']['id']}/preparaciones", json={"kg": 100})
    assert r.status_code == 422
    assert "Maíz" in r.json()["detail"]


def test_ajuste_deja_el_conteo_real(client, bodega):
    client.post(f"/insumos/{bodega['maiz']['id']}/compras", json={"bultos": 2})
    r = client.post(f"/insumos/{bodega['maiz']['id']}/ajuste", json={"kg_reales": 70, "nota": "conteo"})
    assert r.json()["kg"] == -30
    assert _existencia(client, bodega["maiz"])["stock_kg"] == 70
    assert client.post(f"/insumos/{bodega['maiz']['id']}/ajuste", json={"kg_reales": 70}).json() is None


def test_historial_del_insumo_trae_lo_mas_nuevo_primero(client, bodega):
    maiz = bodega["maiz"]["id"]
    client.post(f"/insumos/{maiz}/compras", json={"bultos": 2, "fecha": "2026-10-01"})
    client.post(f"/insumos/{maiz}/compras", json={"bultos": 1, "fecha": "2026-10-10"})
    historial = client.get(f"/insumos/{maiz}/movimientos").json()
    assert [m["fecha"] for m in historial] == ["2026-10-10", "2026-10-01"]


def test_el_registro_del_dia_descuenta_y_el_inventario_calcula_los_dias(client, granja, bodega):
    italcol = bodega["italcol"]["id"]
    hoy = fecha_en_granja(datetime.now(UTC)).isoformat()
    client.post(f"/insumos/{italcol}/compras", json={"bultos": 20})
    assert client.put("/alimento-en-uso/produccion", json={"insumo_id": italcol}).status_code == 204

    registro = {
        "id": str(uuid.uuid4()),
        "galpon_id": granja["galpon"]["id"],
        "fecha": hoy,
        "huevos_total": 4000,
        "alimento_kg": 400,
    }
    assert client.put(f"/registros/{registro['id']}", json=registro).status_code == 200

    inventario = client.get("/inventario").json()
    existencia = _existencia(client, bodega["italcol"])
    assert existencia["stock_kg"] == 400
    assert existencia["dias"] == 1
    assert existencia["nivel"] == "critico"
    assert inventario["etapas"][0]["en_uso_id"] == italcol

    client.delete(f"/registros/{registro['id']}")
    assert _existencia(client, bodega["italcol"])["stock_kg"] == 800


def test_alimento_en_uso_de_otra_etapa_es_422(client, bodega):
    r = client.put("/alimento-en-uso/levante", json={"insumo_id": bodega["italcol"]["id"]})
    assert r.status_code == 422


def test_el_registrador_compra_y_prepara_pero_no_configura(client, bodega, mama):  # noqa: F811
    maiz, soya, mezcla = bodega["maiz"]["id"], bodega["soya"]["id"], bodega["mezcla"]["id"]
    assert mama.get("/inventario").status_code == 200
    assert mama.post(f"/insumos/{maiz}/compras", json={"bultos": 10}).status_code == 201
    assert mama.post(f"/insumos/{soya}/compras", json={"bultos": 10}).status_code == 201
    assert mama.post(f"/alimentos/{mezcla}/preparaciones", json={"kg": 100}).status_code == 201

    assert mama.post("/insumos", json={"nombre": "Otro", "tipo": "materia_prima", "kg_por_bulto": 1}).status_code == 403
    assert mama.post(f"/insumos/{maiz}/ajuste", json={"kg_reales": 1}).status_code == 403
    assert mama.put(f"/alimentos/{mezcla}/formula", json=[]).status_code == 403
    assert mama.put("/alimento-en-uso/produccion", json={"insumo_id": mezcla}).status_code == 403


def test_sin_sesion_no_se_ve_el_inventario(client):
    from fastapi.testclient import TestClient

    from app.main import app

    anonimo = TestClient(app)
    assert anonimo.get("/inventario").status_code == 401
    assert anonimo.post("/insumos/1/compras", json={"kg": 1}).status_code == 401
