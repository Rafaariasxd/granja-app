import uuid

import pytest
from fastapi.testclient import TestClient

from app.dominio.errores import DatosInvalidos
from app.dominio.huevos import (
    Empaque,
    LineaSalida,
    PrecioHuevo,
    TipoVenta,
    a_huevos,
    empacar,
    id_de_venta,
    precio_de_los_huevos,
    repartir_total,
    validar_lineas,
    validar_precio,
)
from app.main import app
from tests.test_api_permisos import _como, mama  # noqa: F401

PRECIO = PrecioHuevo(1, precio_caja=120000, precio_carton=12000, precio_mayorista=108000)


def test_una_caja_son_12_cartones_de_30_huevos():
    assert a_huevos(cajas=1) == 360
    assert a_huevos(cajas=3, cartones=3) == 1170
    assert a_huevos(cartones=26) == 780
    with pytest.raises(DatosInvalidos):
        a_huevos(cartones=-1)


@pytest.mark.parametrize(
    ("huevos", "esperado"),
    [
        (780, Empaque(2, 2, 0)),
        (360, Empaque(1, 0, 0)),
        (1170, Empaque(3, 3, 0)),
        (15, Empaque(0, 0, 15)),
        (0, Empaque(0, 0, 0)),
        (-390, Empaque(-1, -1, 0)),
    ],
)
def test_se_empaca_solo_en_cajas_cartones_y_sueltos(huevos, esperado):
    assert empacar(huevos) == esperado


def test_el_cliente_paga_la_caja_dividida_en_12_y_el_particular_paga_el_carton():
    cuatro_cartones = a_huevos(cartones=4)
    assert precio_de_los_huevos(cuatro_cartones, TipoVenta.CLIENTE, PRECIO) == 40000
    assert precio_de_los_huevos(cuatro_cartones, TipoVenta.PARTICULAR, PRECIO) == 48000
    assert precio_de_los_huevos(cuatro_cartones, TipoVenta.MAYORISTA, PRECIO) == 36000
    assert precio_de_los_huevos(a_huevos(cajas=1), TipoVenta.CLIENTE, PRECIO) == 120000
    media_caja = a_huevos(cartones=6)
    assert precio_de_los_huevos(media_caja, TipoVenta.CLIENTE, PRECIO) == 60000


def test_sin_precio_no_hay_valor_sugerido():
    assert precio_de_los_huevos(360, TipoVenta.CLIENTE, None) is None
    assert precio_de_los_huevos(360, TipoVenta.MAYORISTA, PrecioHuevo(1, precio_caja=100000)) is None
    assert precio_de_los_huevos(0, TipoVenta.CLIENTE, PRECIO) is None


def test_validaciones_de_precios_y_lineas():
    with pytest.raises(DatosInvalidos):
        validar_precio(PrecioHuevo(1, precio_caja=0))
    with pytest.raises(DatosInvalidos, match="qué huevos"):
        validar_lineas([])
    with pytest.raises(DatosInvalidos, match="repetirse"):
        validar_lineas([LineaSalida(1, 30), LineaSalida(1, 60)])
    with pytest.raises(DatosInvalidos, match="al menos"):
        validar_lineas([LineaSalida(1, 0)])


def test_el_total_cobrado_se_reparte_en_proporcion():
    reparto = repartir_total({1: 360, 2: 360}, {1: 120000, 2: 60000}, 150000)
    assert reparto == {1: 100000, 2: 50000}
    assert sum(repartir_total({1: 10, 2: 20, 3: 30}, {1: None, 2: None, 3: None}, 1000).values()) == 1000
    assert repartir_total({1: 360}, {1: 120000}, None) == {1: 120000}
    with pytest.raises(DatosInvalidos, match="total cobrado"):
        repartir_total({1: 360}, {1: None}, None)


def test_el_id_de_la_venta_es_siempre_el_mismo_para_la_misma_salida():
    salida = uuid.uuid4()
    assert id_de_venta(salida, 1) == id_de_venta(salida, 1)
    assert id_de_venta(salida, 1) != id_de_venta(salida, 2)


@pytest.fixture
def bodega(client):
    ids = {n: client.post("/categorias-huevo", json={"nombre": n}).json()["id"] for n in ("AA", "A")}
    client.put(
        f"/huevos/precios/{ids['AA']}",
        json={"categoria_id": ids["AA"], "precio_caja": 120000, "precio_carton": 12000, "precio_mayorista": 108000},
    )
    client.put(f"/huevos/precios/{ids['A']}", json={"categoria_id": ids["A"], "precio_caja": 96000})
    for nombre, cajas in (("AA", 10), ("A", 5)):
        r = client.post(
            "/huevos/ingresos",
            json={
                "operacion_id": str(uuid.uuid4()),
                "fecha": "2026-10-20",
                "categoria_id": ids[nombre],
                "cajas": cajas,
            },
        )
        assert r.status_code == 201, r.text
    return ids


def _existencia(client, categoria_id):
    return next(e for e in client.get("/huevos").json()["existencias"] if e["categoria_id"] == categoria_id)


def _ventas(client):
    return client.get("/finanzas", params={"desde": "2026-10-01", "hasta": "2026-10-31"}).json()


def test_lo_que_entra_se_ve_en_cajas_cartones_y_huevos(client, bodega):
    aa = _existencia(client, bodega["AA"])
    assert (aa["huevos"], aa["cajas"], aa["cartones"], aa["sueltos"]) == (3600, 10, 0, 0)
    r = client.post(
        "/huevos/ingresos",
        json={"operacion_id": str(uuid.uuid4()), "categoria_id": bodega["AA"], "cartones": 26, "huevos": 15},
    )
    assert r.json()["huevos"] == 795
    aa = _existencia(client, bodega["AA"])
    assert (aa["cajas"], aa["cartones"], aa["sueltos"]) == (12, 2, 15)


def test_un_ingreso_reenviado_no_se_duplica_y_valida(client, bodega):
    cuerpo = {"operacion_id": str(uuid.uuid4()), "categoria_id": bodega["A"], "cartones": 1}
    assert client.post("/huevos/ingresos", json=cuerpo).status_code == 201
    assert client.post("/huevos/ingresos", json=cuerpo).status_code == 201
    assert _existencia(client, bodega["A"])["huevos"] == 1830
    vacio = {"operacion_id": str(uuid.uuid4()), "categoria_id": bodega["A"]}
    assert client.post("/huevos/ingresos", json=vacio).status_code == 422
    nada = {"operacion_id": str(uuid.uuid4()), "categoria_id": 99, "cajas": 1}
    assert client.post("/huevos/ingresos", json=nada).status_code == 404


def test_vender_a_un_cliente_cobra_la_caja_dividida_y_queda_en_dinero(client, bodega):
    id_ = str(uuid.uuid4())
    cuerpo = {
        "fecha": "2026-10-21",
        "tipo_venta": "cliente",
        "cliente": "Tienda La Esperanza",
        "lineas": [{"categoria_id": bodega["AA"], "cajas": 2, "cartones": 4}],
    }
    r = client.put(f"/huevos/ventas/{id_}", json=cuerpo)
    assert r.status_code == 200, r.text
    assert (r.json()["estado"], r.json()["valor_total"]) == ("cerrada", 280000)
    assert client.put(f"/huevos/ventas/{id_}", json=cuerpo).json()["valor_total"] == 280000
    aa = _existencia(client, bodega["AA"])
    assert (aa["cajas"], aa["cartones"]) == (7, 8)
    venta = _ventas(client)
    assert [(m["valor"], m["cantidad_huevos"], m["contraparte"]) for m in venta] == [
        (280000, 840, "Tienda La Esperanza")
    ]


def test_al_particular_se_le_cobra_por_carton(client, bodega):
    r = client.put(
        f"/huevos/ventas/{uuid.uuid4()}",
        json={"tipo_venta": "particular", "lineas": [{"categoria_id": bodega["AA"], "cartones": 2}]},
    )
    assert r.json()["valor_total"] == 24000


def test_sin_precio_hay_que_decir_cuanto_se_cobro(client, bodega):
    sin_precio = {"tipo_venta": "particular", "lineas": [{"categoria_id": bodega["A"], "cartones": 2}]}
    assert client.put(f"/huevos/ventas/{uuid.uuid4()}", json=sin_precio).status_code == 422
    assert _existencia(client, bodega["A"])["huevos"] == 1800
    r = client.put(f"/huevos/ventas/{uuid.uuid4()}", json={**sin_precio, "valor_cobrado": 22000})
    assert r.json()["valor_total"] == 22000


def test_no_se_puede_sacar_mas_huevo_del_que_hay(client, bodega):
    r = client.put(
        f"/huevos/salidas/{uuid.uuid4()}",
        json={"tipo_venta": "cliente", "lineas": [{"categoria_id": bodega["A"], "cajas": 6}]},
    )
    assert r.status_code == 422
    assert "quedan 5 cajas" in r.json()["detail"]


def test_una_salida_que_se_vendio_toda(client, bodega):
    id_ = str(uuid.uuid4())
    lineas = [{"categoria_id": bodega["AA"], "cajas": 3}, {"categoria_id": bodega["A"], "cajas": 1}]
    abierta = client.put(f"/huevos/salidas/{id_}", json={"tipo_venta": "cliente", "cliente": "Ruta", "lineas": lineas})
    assert abierta.json()["estado"] == "abierta"
    assert [s["id"] for s in client.get("/huevos").json()["abiertas"]] == [id_]
    assert _existencia(client, bodega["AA"])["cajas"] == 7

    cerrada = client.post(f"/huevos/salidas/{id_}/cierre", json={"fecha": "2026-10-22"})
    assert (cerrada.json()["estado"], cerrada.json()["valor_total"]) == ("cerrada", 456000)
    assert client.post(f"/huevos/salidas/{id_}/cierre", json={}).json()["valor_total"] == 456000
    assert client.get("/huevos").json()["abiertas"] == []
    assert sorted(m["valor"] for m in _ventas(client)) == [96000, 360000]


def test_lo_que_no_se_vendio_vuelve_a_la_bodega(client, bodega):
    id_ = str(uuid.uuid4())
    lineas = [{"categoria_id": bodega["AA"], "cajas": 3}, {"categoria_id": bodega["A"], "cajas": 1}]
    client.put(f"/huevos/salidas/{id_}", json={"tipo_venta": "mayorista", "lineas": lineas})
    vendidos = [{"categoria_id": bodega["AA"], "cajas": 2, "cartones": 6}, {"categoria_id": bodega["A"], "cajas": 0}]
    cerrada = client.post(f"/huevos/salidas/{id_}/cierre", json={"fecha": "2026-10-22", "vendidos": vendidos}).json()

    assert cerrada["valor_total"] == 270000
    lineas_cerradas = {ln["categoria_id"]: ln for ln in cerrada["lineas"]}
    assert lineas_cerradas[bodega["AA"]]["huevos_vendidos"] == 900
    assert lineas_cerradas[bodega["A"]]["huevos_vendidos"] == 0
    aa = _existencia(client, bodega["AA"])
    assert (aa["cajas"], aa["cartones"]) == (7, 6)
    assert _existencia(client, bodega["A"])["cajas"] == 5
    assert [m["valor"] for m in _ventas(client)] == [270000]


def test_el_cierre_valida_lo_vendido_y_el_total(client, bodega):
    id_ = str(uuid.uuid4())
    client.put(
        f"/huevos/salidas/{id_}", json={"tipo_venta": "cliente", "lineas": [{"categoria_id": bodega["AA"], "cajas": 1}]}
    )
    de_mas = {"vendidos": [{"categoria_id": bodega["AA"], "cajas": 2}]}
    assert client.post(f"/huevos/salidas/{id_}/cierre", json=de_mas).status_code == 422
    nada_cobrado = {"vendidos": [{"categoria_id": bodega["AA"]}], "valor_cobrado": 1000}
    assert client.post(f"/huevos/salidas/{id_}/cierre", json=nada_cobrado).status_code == 422
    assert client.post(f"/huevos/salidas/{uuid.uuid4()}/cierre", json={}).status_code == 404
    otro_total = client.post(f"/huevos/salidas/{id_}/cierre", json={"valor_cobrado": 115000})
    assert otro_total.json()["valor_total"] == 115000


def test_anular_una_salida_devuelve_todo_y_no_se_puede_cerrar(client, bodega):
    id_ = str(uuid.uuid4())
    client.put(
        f"/huevos/salidas/{id_}", json={"tipo_venta": "cliente", "lineas": [{"categoria_id": bodega["AA"], "cajas": 4}]}
    )
    anulada = client.post(f"/huevos/salidas/{id_}/anulacion")
    assert anulada.json()["estado"] == "anulada"
    assert _existencia(client, bodega["AA"])["cajas"] == 10
    assert client.post(f"/huevos/salidas/{id_}/cierre", json={}).status_code == 409
    assert client.post(f"/huevos/salidas/{id_}/anulacion").status_code == 200

    otra = str(uuid.uuid4())
    client.put(
        f"/huevos/ventas/{otra}", json={"tipo_venta": "cliente", "lineas": [{"categoria_id": bodega["AA"], "cajas": 1}]}
    )
    assert client.post(f"/huevos/salidas/{otra}/anulacion").status_code == 409


def test_conteo_y_baja_por_huevos_rotos(client, bodega, mama):  # noqa: F811
    baja = {"operacion_id": str(uuid.uuid4()), "categoria_id": bodega["AA"], "cartones": 2, "nota": "se cayeron"}
    assert mama.post("/huevos/bajas", json=baja).status_code == 201
    assert mama.post("/huevos/bajas", json=baja).status_code == 201
    assert _existencia(client, bodega["AA"])["huevos"] == 3540
    demasiado = {"operacion_id": str(uuid.uuid4()), "categoria_id": bodega["AA"], "cajas": 20}
    assert mama.post("/huevos/bajas", json=demasiado).status_code == 422

    conteo = mama.post("/huevos/conteos", json={"categoria_id": bodega["AA"], "cajas": 9, "cartones": 6})
    assert conteo.json()["huevos"] == -120
    assert _existencia(client, bodega["AA"])["huevos"] == 3420
    assert mama.post("/huevos/conteos", json={"categoria_id": bodega["AA"], "cajas": 9, "cartones": 6}).json() is None


def test_los_precios_son_del_administrador(client, bodega, mama):  # noqa: F811
    cuerpo = {"categoria_id": bodega["AA"], "precio_caja": 1}
    assert mama.put(f"/huevos/precios/{bodega['AA']}", json=cuerpo).status_code == 403
    assert client.put(f"/huevos/precios/{bodega['AA']}", json={**cuerpo, "precio_caja": 0}).status_code == 422
    assert client.put("/huevos/precios/99", json={"categoria_id": 99, "precio_caja": 1}).status_code == 404
    precios = client.get("/huevos").json()["precios"]
    assert precios[0] == {
        "categoria_id": bodega["AA"],
        "precio_caja": 120000,
        "precio_carton": 12000,
        "precio_mayorista": 108000,
    }


def test_el_registrador_vende_y_saca_huevo(client, bodega, mama):  # noqa: F811
    r = mama.put(
        f"/huevos/ventas/{uuid.uuid4()}",
        json={"tipo_venta": "cliente", "lineas": [{"categoria_id": bodega["AA"], "cartones": 6}]},
    )
    assert r.json()["valor_total"] == 60000


def test_la_categoria_apagada_con_huevo_sigue_a_la_vista(client, bodega):
    client.patch(f"/categorias-huevo/{bodega['A']}", json={"activa": False})
    nombres = [e["categoria"] for e in client.get("/huevos").json()["existencias"]]
    assert nombres == ["AA", "A"]


def test_sin_sesion_no_se_ve_la_bodega_del_huevo(client):
    assert TestClient(app).get("/huevos").status_code == 401
