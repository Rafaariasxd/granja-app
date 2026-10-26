import uuid
from datetime import date

import pytest
from fastapi.testclient import TestClient

from app.dominio.errores import DatosInvalidos
from app.dominio.finanzas import MovimientoDinero, Rubro, TipoMovimiento, resumir, tipo_del_rubro, validar_movimiento
from app.main import app
from tests.test_api_permisos import _como, mama  # noqa: F401


def _mov(rubro, valor, **extra):
    return MovimientoDinero(uuid.uuid4(), date(2026, 10, 10), rubro, valor, **extra)


def test_cada_rubro_es_ingreso_o_egreso():
    assert tipo_del_rubro(Rubro.VENTA_HUEVO) == TipoMovimiento.INGRESO
    assert tipo_del_rubro(Rubro.VENTA_GALLINAS) == TipoMovimiento.INGRESO
    assert tipo_del_rubro(Rubro.ALIMENTO) == TipoMovimiento.EGRESO
    assert tipo_del_rubro(Rubro.POLLITAS) == TipoMovimiento.EGRESO


def test_validaciones():
    with pytest.raises(DatosInvalidos, match="mayor que cero"):
        validar_movimiento(_mov(Rubro.ALIMENTO, 0))
    with pytest.raises(DatosInvalidos, match="cuántos huevos"):
        validar_movimiento(_mov(Rubro.VENTA_HUEVO, 100))
    with pytest.raises(DatosInvalidos, match="solo la venta de huevo"):
        validar_movimiento(_mov(Rubro.ALIMENTO, 100, cantidad_huevos=5))
    with pytest.raises(DatosInvalidos, match="solo la venta de huevo"):
        validar_movimiento(_mov(Rubro.VENTA_GALLINAS, 100, categoria_id=1))
    validar_movimiento(_mov(Rubro.VENTA_HUEVO, 100, cantidad_huevos=30, categoria_id=1))


def test_el_resumen_suma_por_rubro_categoria_y_lote():
    movimientos = [
        _mov(Rubro.VENTA_HUEVO, 90000, cantidad_huevos=300, categoria_id=1, lote_id=7),
        _mov(Rubro.VENTA_HUEVO, 20000, cantidad_huevos=100, categoria_id=2, lote_id=7),
        _mov(Rubro.VENTA_HUEVO, 5000, cantidad_huevos=30),
        _mov(Rubro.VENTA_GALLINAS, 50000, lote_id=7),
        _mov(Rubro.ALIMENTO, 80000, lote_id=7),
        _mov(Rubro.MANO_DE_OBRA, 30000),
    ]
    r = resumir(movimientos, date(2026, 10, 1), date(2026, 10, 31), {1: "AA", 2: "A"}, {7: "Galpón 1"})
    assert (r.ingresos, r.egresos, r.utilidad) == (165000, 110000, 55000)
    assert r.por_rubro[0].rubro == Rubro.VENTA_HUEVO and r.por_rubro[0].total == 115000
    assert [(v.categoria, v.huevos, v.valor, v.precio_por_huevo) for v in r.huevos] == [
        ("AA", 300, 90000, 300.0),
        ("A", 100, 20000, 200.0),
        ("Sin categoría", 30, 5000, 166.7),
    ]
    assert [(x.galpon, x.ingresos, x.egresos, x.utilidad) for x in r.por_lote] == [
        ("Galpón 1", 160000, 80000, 80000),
        ("Sin asignar", 5000, 30000, -25000),
    ]


def test_un_periodo_sin_movimientos_da_ceros():
    r = resumir([], date(2026, 10, 1), date(2026, 10, 31), {}, {})
    assert (r.ingresos, r.egresos, r.utilidad, r.por_rubro, r.huevos, r.por_lote) == (0, 0, 0, [], [], [])


def _categorias(client):
    return {c["nombre"]: c["id"] for c in client.get("/categorias-huevo").json()}


def _venta(client, valor=90000, huevos=300, categoria=None, fecha="2026-10-10", **extra):
    id_ = str(uuid.uuid4())
    cuerpo = {"fecha": fecha, "rubro": "venta_huevo", "valor": valor, "cantidad_huevos": huevos, **extra}
    if categoria is not None:
        cuerpo["categoria_id"] = categoria
    r = client.put(f"/finanzas/{id_}", json=cuerpo)
    assert r.status_code == 200, r.text
    return id_, r.json()


def test_las_categorias_de_huevo_se_crean_y_se_editan(client):
    assert client.get("/categorias-huevo").json() == []
    crear = client.post("/categorias-huevo", json={"nombre": "AA"})
    assert crear.status_code == 201
    assert client.post("/categorias-huevo", json={"nombre": "AA"}).status_code == 409
    id_ = crear.json()["id"]
    assert client.patch(f"/categorias-huevo/{id_}", json={"nombre": "Extra"}).json()["nombre"] == "Extra"
    otra = client.post("/categorias-huevo", json={"nombre": "B"}).json()["id"]
    assert client.patch(f"/categorias-huevo/{otra}", json={"nombre": "Extra"}).status_code == 409
    assert client.patch(f"/categorias-huevo/{otra}", json={"activa": False}).json()["activa"] is False
    assert client.patch("/categorias-huevo/999", json={"nombre": "X"}).status_code == 404


def test_solo_el_administrador_cambia_las_categorias(client, mama):  # noqa: F811
    client.post("/categorias-huevo", json={"nombre": "AA"})
    assert mama.post("/categorias-huevo", json={"nombre": "A"}).status_code == 403
    assert mama.patch("/categorias-huevo/1", json={"nombre": "A"}).status_code == 403
    assert mama.get("/categorias-huevo").status_code == 200


def test_una_venta_de_huevo_se_guarda_una_sola_vez_aunque_se_reenvie(client, granja):
    categoria = client.post("/categorias-huevo", json={"nombre": "AA"}).json()["id"]
    id_, venta = _venta(client, categoria=categoria, lote_id=granja["lote"]["id"])
    assert (venta["tipo"], venta["cantidad_huevos"], venta["lote_id"]) == ("ingreso", 300, granja["lote"]["id"])
    reenvio = client.put(f"/finanzas/{id_}", json={**venta, "id": None, "valor": 95000})
    assert reenvio.status_code == 200
    lista = client.get("/finanzas", params={"desde": "2026-10-01", "hasta": "2026-10-31"}).json()
    assert [(m["id"], m["valor"]) for m in lista] == [(id_, 95000)]


def test_el_registrador_tambien_anota_ventas_y_gastos(client, mama):  # noqa: F811
    gasto = {"fecha": "2026-10-11", "rubro": "alimento", "valor": 480000, "descripcion": "50 bultos de ponedora"}
    assert mama.put(f"/finanzas/{uuid.uuid4()}", json=gasto).status_code == 200
    assert mama.delete(f"/finanzas/{uuid.uuid4()}").status_code == 403


def test_validaciones_de_la_api(client):
    ruta = f"/finanzas/{uuid.uuid4()}"
    base = {"fecha": "2026-10-10", "rubro": "venta_huevo", "valor": 1000}
    assert client.put(ruta, json=base).status_code == 422
    assert client.put(ruta, json={**base, "cantidad_huevos": 0}).status_code == 422
    assert client.put(ruta, json={**base, "valor": 0, "cantidad_huevos": 30}).status_code == 422
    assert client.put(ruta, json={**base, "rubro": "otro", "cantidad_huevos": 30}).status_code == 422
    assert client.put(ruta, json={**base, "rubro": "alimento", "cantidad_huevos": 30}).status_code == 422
    assert client.put(ruta, json={**base, "cantidad_huevos": 30, "categoria_id": 99}).status_code == 404
    assert client.put(ruta, json={**base, "cantidad_huevos": 30, "lote_id": 99}).status_code == 404


def test_el_administrador_borra_un_movimiento_y_queda_en_la_bitacora(client):
    id_, _ = _venta(client)
    assert client.delete(f"/finanzas/{id_}").status_code == 204
    assert client.delete(f"/finanzas/{id_}").status_code == 204
    assert client.get("/finanzas", params={"desde": "2026-10-01", "hasta": "2026-10-31"}).json() == []


def test_el_resumen_del_mes_trae_utilidad_huevos_y_lotes(client, granja):
    cats = {n: client.post("/categorias-huevo", json={"nombre": n}).json()["id"] for n in ("AA", "A")}
    lote = granja["lote"]["id"]
    _venta(client, 90000, 300, cats["AA"], lote_id=lote)
    _venta(client, 20000, 100, cats["A"], lote_id=lote)
    _venta(client, 7000, 30, cats["A"], fecha="2026-09-30")
    client.put(
        f"/finanzas/{uuid.uuid4()}",
        json={"fecha": "2026-10-12", "rubro": "alimento", "valor": 60000, "lote_id": lote},
    )
    r = client.get("/finanzas/resumen", params={"desde": "2026-10-01", "hasta": "2026-10-31"}).json()
    assert (r["ingresos"], r["egresos"], r["utilidad"]) == (110000, 60000, 50000)
    assert [(v["categoria"], v["huevos"], v["precio_por_huevo"]) for v in r["huevos"]] == [
        ("AA", 300, 300.0),
        ("A", 100, 200.0),
    ]
    assert [(x["galpon"], x["utilidad"]) for x in r["por_lote"]] == [("Galpón 1", 50000)]
    assert r["por_rubro"][0] == {"rubro": "venta_huevo", "total": 110000}


def test_el_resumen_sin_fechas_es_el_mes_en_curso_y_valida_el_periodo(client):
    assert client.get("/finanzas/resumen").status_code == 200
    assert client.get("/finanzas/resumen", params={"desde": "2026-10-10", "hasta": "2026-10-01"}).status_code == 422
    assert client.get("/finanzas", params={"desde": "2026-10-10", "hasta": "2026-10-01"}).status_code == 422


def test_sin_sesion_no_se_ve_el_dinero(client):
    anonimo = TestClient(app)
    assert anonimo.get("/finanzas/resumen").status_code == 401
    assert anonimo.get("/categorias-huevo").status_code == 401


def test_una_categoria_nueva_va_al_final_y_se_puede_mover(client):
    for nombre in ("AA", "A"):
        client.post("/categorias-huevo", json={"nombre": nombre})
    jumbo = client.post("/categorias-huevo", json={"nombre": "Jumbo"}).json()
    assert [c["nombre"] for c in client.get("/categorias-huevo").json()] == ["AA", "A", "Jumbo"]
    assert client.patch(f"/categorias-huevo/{jumbo['id']}", json={"orden": 0}).json()["orden"] == 0
    assert [c["nombre"] for c in client.get("/categorias-huevo").json()] == ["Jumbo", "AA", "A"]
    assert client.patch(f"/categorias-huevo/{jumbo['id']}", json={"orden": -1}).status_code == 422
