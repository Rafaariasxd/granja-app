import uuid
from datetime import UTC, datetime

import pytest
from fastapi.testclient import TestClient

from app.dominio.fechas import fecha_en_granja
from app.main import app
from tests.test_api_permisos import _como, mama  # noqa: F401


def _crear(client, ruta, **cuerpo):
    r = client.post(ruta, json=cuerpo)
    assert r.status_code == 201, r.text
    return r.json()


@pytest.fixture
def bodega(client, granja):
    maiz = _crear(client, "/insumos", nombre="Maíz", tipo="materia_prima", kg_por_bulto=50)
    soya = _crear(client, "/insumos", nombre="Soya", tipo="materia_prima", kg_por_bulto=40)
    mezcla = _crear(client, "/insumos", nombre="Mezcla ponedora", tipo="alimento_preparado", etapa="produccion")
    italcol = _crear(
        client, "/insumos", nombre="Italcol ponedora", tipo="alimento_comprado", etapa="produccion", kg_por_bulto=40
    )
    uno = _crear(client, "/bodegas", nombre="Bodega 1", tipo="alimento")
    dos = _crear(client, "/bodegas", nombre="Bodega 2", tipo="alimento")
    materia = _crear(client, "/bodegas", nombre="Materia prima", tipo="materia_prima")
    formula = [{"insumo_id": maiz["id"], "porcentaje": 70}, {"insumo_id": soya["id"], "porcentaje": 30}]
    assert client.put(f"/alimentos/{mezcla['id']}/formula", json=formula).status_code == 200
    asignadas = client.put(f"/bodegas/{uno['id']}/galpones", json={"galpon_ids": [granja["galpon"]["id"]]})
    assert asignadas.status_code == 200
    return {
        "maiz": maiz,
        "soya": soya,
        "mezcla": mezcla,
        "italcol": italcol,
        "uno": uno,
        "dos": dos,
        "materia": materia,
    }


def _de_bodega(client, bodega_):
    todas = client.get("/inventario").json()["bodegas"]
    return next(b for b in todas if b["bodega"]["id"] == bodega_["id"])


def _existencia(client, bodega_, insumo):
    return next(e for e in _de_bodega(client, bodega_)["existencias"] if e["insumo"]["id"] == insumo["id"])


def _compra(client, insumo, bodega_, **cantidad):
    return client.post(f"/insumos/{insumo['id']}/compras", json={"bodega_id": bodega_["id"], **cantidad})


def test_comprar_medio_bulto(client, bodega):
    r = _compra(client, bodega["maiz"], bodega["materia"], bultos=2.5)
    assert r.status_code == 201
    assert r.json()["kg"] == 125
    assert r.json()["motivo"] == "compra"
    assert r.json()["bodega_id"] == bodega["materia"]["id"]
    existencia = _existencia(client, bodega["materia"], bodega["maiz"])
    assert (existencia["stock_kg"], existencia["bultos"]) == (125, 2.5)


def test_la_compra_sin_cantidad_o_sin_bodega_es_422(client, bodega):
    maiz = bodega["maiz"]["id"]
    assert client.post(f"/insumos/{maiz}/compras", json={"bodega_id": bodega["materia"]["id"]}).status_code == 422
    assert _compra(client, bodega["maiz"], bodega["materia"], bultos=-1).status_code == 422
    assert client.post(f"/insumos/{maiz}/compras", json={"bultos": 1}).status_code == 422


def test_la_materia_prima_no_entra_a_una_bodega_de_alimento(client, bodega):
    r = _compra(client, bodega["maiz"], bodega["uno"], bultos=1)
    assert r.status_code == 422
    assert "materia prima" in r.json()["detail"]


def test_el_insumo_o_la_bodega_repetidos_son_409_y_los_inexistentes_404(client, bodega):
    repetido = {"nombre": "Maíz", "tipo": "materia_prima", "kg_por_bulto": 50}
    assert client.post("/insumos", json=repetido).status_code == 409
    assert client.post("/bodegas", json={"nombre": "Bodega 1", "tipo": "alimento"}).status_code == 409
    assert client.post("/insumos/999/compras", json={"bodega_id": 1, "kg": 5}).status_code == 404
    assert _compra(client, bodega["maiz"], {"id": 999}, kg=5).status_code == 404


def test_las_bodegas_se_listan_con_sus_galpones(client, bodega, granja):
    bodegas = {b["nombre"]: b for b in client.get("/bodegas").json()}
    assert bodegas["Bodega 1"]["galpon_ids"] == [granja["galpon"]["id"]]
    assert bodegas["Bodega 2"]["galpon_ids"] == []
    assert bodegas["Materia prima"]["tipo"] == "materia_prima"


def test_los_galpones_solo_van_a_bodegas_de_alimento(client, bodega, granja):
    r = client.put(f"/bodegas/{bodega['materia']['id']}/galpones", json={"galpon_ids": [granja["galpon"]["id"]]})
    assert r.status_code == 422
    r = client.put(f"/bodegas/{bodega['uno']['id']}/galpones", json={"galpon_ids": [999]})
    assert r.status_code == 404


def test_la_formula_que_no_suma_cien_es_422(client, bodega):
    formula = [{"insumo_id": bodega["maiz"]["id"], "porcentaje": 70}]
    assert client.put(f"/alimentos/{bodega['mezcla']['id']}/formula", json=formula).status_code == 422


def test_la_formula_se_puede_consultar(client, bodega):
    formula = client.get(f"/alimentos/{bodega['mezcla']['id']}/formula").json()
    assert [(i["insumo_id"], i["porcentaje"]) for i in formula] == [
        (bodega["maiz"]["id"], 70),
        (bodega["soya"]["id"], 30),
    ]


def _preparar(client, bodega, kg, destino="dos"):
    cuerpo = {"desde_bodega_id": bodega["materia"]["id"], "hacia_bodega_id": bodega[destino]["id"], "kg": kg}
    return client.post(f"/alimentos/{bodega['mezcla']['id']}/preparaciones", json=cuerpo)


def test_preparar_alimento_gasta_materia_prima_y_lo_deja_en_la_bodega_elegida(client, bodega):
    _compra(client, bodega["maiz"], bodega["materia"], bultos=10)
    _compra(client, bodega["soya"], bodega["materia"], bultos=10)

    r = _preparar(client, bodega, 200)

    assert r.status_code == 201
    assert _existencia(client, bodega["dos"], bodega["mezcla"])["stock_kg"] == 200
    assert _existencia(client, bodega["materia"], bodega["maiz"])["stock_kg"] == 360
    assert _existencia(client, bodega["materia"], bodega["soya"])["stock_kg"] == 340


def test_preparar_sin_materia_prima_explica_que_falta(client, bodega):
    r = _preparar(client, bodega, 100)
    assert r.status_code == 422
    assert "Maíz" in r.json()["detail"]


def test_ajuste_deja_el_conteo_real_de_esa_bodega(client, bodega):
    _compra(client, bodega["maiz"], bodega["materia"], bultos=2)
    ruta = f"/insumos/{bodega['maiz']['id']}/ajuste"
    cuerpo = {"bodega_id": bodega["materia"]["id"], "kg_reales": 70, "nota": "conteo"}
    assert client.post(ruta, json=cuerpo).json()["kg"] == -30
    assert _existencia(client, bodega["materia"], bodega["maiz"])["stock_kg"] == 70
    assert client.post(ruta, json=cuerpo).json() is None


def test_historial_del_insumo_trae_lo_mas_nuevo_primero(client, bodega):
    maiz = bodega["maiz"]
    _compra(client, maiz, bodega["materia"], bultos=2, fecha="2026-10-01")
    _compra(client, maiz, bodega["materia"], bultos=1, fecha="2026-10-10")
    historial = client.get(f"/insumos/{maiz['id']}/movimientos").json()
    assert [m["fecha"] for m in historial] == ["2026-10-10", "2026-10-01"]


def test_el_registro_del_dia_descuenta_de_la_bodega_del_galpon_y_calcula_los_dias(client, granja, bodega):
    hoy = fecha_en_granja(datetime.now(UTC)).isoformat()
    _compra(client, bodega["italcol"], bodega["uno"], bultos=20)
    _compra(client, bodega["italcol"], bodega["dos"], bultos=20)
    ruta = f"/bodegas/{bodega['uno']['id']}/alimento-en-uso/produccion"
    assert client.put(ruta, json={"insumo_id": bodega["italcol"]["id"]}).status_code == 204

    registro = {
        "id": str(uuid.uuid4()),
        "galpon_id": granja["galpon"]["id"],
        "fecha": hoy,
        "huevos_total": 4000,
        "alimento_kg": 400,
    }
    assert client.put(f"/registros/{registro['id']}", json=registro).status_code == 200

    uno = _de_bodega(client, bodega["uno"])
    existencia = _existencia(client, bodega["uno"], bodega["italcol"])
    assert existencia["stock_kg"] == 400
    assert existencia["dias"] == 1
    assert existencia["nivel"] == "critico"
    assert uno["etapas"][0]["en_uso_id"] == bodega["italcol"]["id"]
    assert uno["galpon_ids"] == [granja["galpon"]["id"]]
    assert _existencia(client, bodega["dos"], bodega["italcol"])["stock_kg"] == 800

    client.delete(f"/registros/{registro['id']}")
    assert _existencia(client, bodega["uno"], bodega["italcol"])["stock_kg"] == 800


def test_alimento_en_uso_de_otra_etapa_es_422(client, bodega):
    ruta = f"/bodegas/{bodega['uno']['id']}/alimento-en-uso/levante"
    assert client.put(ruta, json={"insumo_id": bodega["italcol"]["id"]}).status_code == 422


def test_el_registrador_compra_y_prepara_pero_no_configura(client, bodega, mama):  # noqa: F811
    maiz, soya = bodega["maiz"], bodega["soya"]
    assert mama.get("/inventario").status_code == 200
    assert mama.get("/bodegas").status_code == 200
    for insumo in (maiz, soya):
        r = mama.post(f"/insumos/{insumo['id']}/compras", json={"bodega_id": bodega["materia"]["id"], "bultos": 10})
        assert r.status_code == 201
    cuerpo = {"desde_bodega_id": bodega["materia"]["id"], "hacia_bodega_id": bodega["uno"]["id"], "kg": 100}
    assert mama.post(f"/alimentos/{bodega['mezcla']['id']}/preparaciones", json=cuerpo).status_code == 201

    nuevo = {"nombre": "Otro", "tipo": "materia_prima", "kg_por_bulto": 1}
    assert mama.post("/insumos", json=nuevo).status_code == 403
    assert mama.post("/bodegas", json={"nombre": "Otra", "tipo": "alimento"}).status_code == 403
    assert mama.put(f"/bodegas/{bodega['uno']['id']}/galpones", json={"galpon_ids": []}).status_code == 403
    ajuste = {"bodega_id": bodega["materia"]["id"], "kg_reales": 1}
    assert mama.post(f"/insumos/{maiz['id']}/ajuste", json=ajuste).status_code == 403
    assert mama.put(f"/alimentos/{bodega['mezcla']['id']}/formula", json=[]).status_code == 403
    ruta = f"/bodegas/{bodega['uno']['id']}/alimento-en-uso/produccion"
    assert mama.put(ruta, json={"insumo_id": bodega["mezcla"]["id"]}).status_code == 403


def test_sin_sesion_no_se_ve_el_inventario(client):
    anonimo = TestClient(app)
    assert anonimo.get("/inventario").status_code == 401
    assert anonimo.get("/bodegas").status_code == 401
    assert anonimo.post("/insumos/1/compras", json={"bodega_id": 1, "kg": 1}).status_code == 401


def test_reenviar_una_compra_con_la_misma_operacion_no_la_duplica(client, bodega):
    cuerpo = {"bodega_id": bodega["materia"]["id"], "bultos": 2, "operacion_id": str(uuid.uuid4())}
    ruta = f"/insumos/{bodega['maiz']['id']}/compras"

    primera = client.post(ruta, json=cuerpo)
    repetida = client.post(ruta, json=cuerpo)

    assert (primera.status_code, repetida.status_code) == (201, 201)
    assert repetida.json()["id"] == primera.json()["id"]
    assert _existencia(client, bodega["materia"], bodega["maiz"])["stock_kg"] == 100


def test_reenviar_una_preparacion_con_la_misma_operacion_no_la_duplica(client, bodega):
    _compra(client, bodega["maiz"], bodega["materia"], bultos=10)
    _compra(client, bodega["soya"], bodega["materia"], bultos=10)
    cuerpo = {
        "desde_bodega_id": bodega["materia"]["id"],
        "hacia_bodega_id": bodega["dos"]["id"],
        "kg": 200,
        "operacion_id": str(uuid.uuid4()),
    }
    ruta = f"/alimentos/{bodega['mezcla']['id']}/preparaciones"

    primera = client.post(ruta, json=cuerpo)
    repetida = client.post(ruta, json=cuerpo)

    assert repetida.json()["id"] == primera.json()["id"]
    assert _existencia(client, bodega["dos"], bodega["mezcla"])["stock_kg"] == 200
    assert _existencia(client, bodega["materia"], bodega["maiz"])["stock_kg"] == 360


def test_una_operacion_que_no_es_uuid_es_422(client, bodega):
    r = client.post(
        f"/insumos/{bodega['maiz']['id']}/compras",
        json={"bodega_id": bodega["materia"]["id"], "bultos": 1, "operacion_id": "abc"},
    )
    assert r.status_code == 422
