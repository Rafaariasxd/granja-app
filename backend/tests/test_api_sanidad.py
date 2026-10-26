import uuid
from datetime import date, timedelta

from fastapi.testclient import TestClient

from app.main import app
from tests.conftest import HOY
from tests.test_api_permisos import _como, mama  # noqa: F401


def _linea(client, nombre="Hy-Line Brown", plantilla=None):
    r = client.post("/lineas", json={"nombre": nombre, "plantilla": plantilla})
    assert r.status_code == 201, r.text
    return r.json()


def _lote(client, linea, nacimiento, ingreso=None, galpon="Galpón 1", aves=2000):
    g = client.post("/galpones", json={"nombre": galpon, "capacidad_aves": 6000}).json()
    r = client.post(
        "/lotes",
        json={
            "galpon_id": g["id"],
            "linea_id": linea["id"],
            "fecha_nacimiento": str(nacimiento),
            "fecha_ingreso": str(ingreso or nacimiento + timedelta(days=1)),
            "aves_iniciales": aves,
        },
    )
    assert r.status_code == 201, r.text
    return g, r.json()


def _sanidad(client, fecha=HOY):
    r = client.get("/sanidad", params={"fecha": str(fecha)})
    assert r.status_code == 200, r.text
    return r.json()


def _tarea(sanidad, nombre):
    return next(t for t in sanidad["galpones"][0]["tareas"] if t["nombre"] == nombre)


def test_una_raza_nueva_puede_traer_los_valores_de_referencia(client):
    assert client.get("/lineas/plantillas").json() == ["Hy-Line Brown", "Lohmann Brown"]
    linea = _linea(client, "Lohmann Brown", "Lohmann Brown")
    assert linea["revisada"] is False
    plan = client.get(f"/lineas/{linea['id']}/plan").json()
    curva = client.get(f"/lineas/{linea['id']}/curva").json()
    assert len(plan) > 15
    assert len(curva) == 80
    assert next(p for p in curva if p["semana"] == 30)["postura_pct"] == 95


def test_una_raza_sin_plantilla_empieza_vacia(client):
    linea = _linea(client, "Dekalb")
    assert client.get(f"/lineas/{linea['id']}/plan").json() == []
    assert client.get(f"/lineas/{linea['id']}/curva").json() == []


def test_una_plantilla_desconocida_es_422(client):
    r = client.post("/lineas", json={"nombre": "Otra", "plantilla": "Inventada"})
    assert r.status_code == 422


def test_se_puede_renombrar_una_raza_sin_repetir_nombres(client):
    a = _linea(client, "Hy-Line")
    _linea(client, "Lohmann")
    ok = client.patch(f"/lineas/{a['id']}", json={"nombre": "Hy-Line Brown"})
    assert ok.status_code == 200
    assert ok.json()["nombre"] == "Hy-Line Brown"
    assert client.patch(f"/lineas/{a['id']}", json={"nombre": "Lohmann"}).status_code == 409
    assert client.patch("/lineas/999", json={"nombre": "X"}).status_code == 404
    assert client.patch(f"/lineas/{a['id']}", json={"nombre": "Hy-Line Brown"}).status_code == 200


def test_editar_el_plan_conserva_las_tareas_con_id_y_retira_las_que_faltan(client):
    linea = _linea(client, plantilla="Hy-Line Brown")
    plan = client.get(f"/lineas/{linea['id']}/plan").json()
    primera, segunda = plan[0], plan[1]
    cambio = [
        {**primera, "nombre": "Marek (incubadora)"},
        {"nombre": "Vacuna propia", "tipo": "vacuna", "semana_ideal": 5, "semana_max": 6},
    ]
    r = client.put(f"/lineas/{linea['id']}/plan", json=cambio)
    assert r.status_code == 200
    nuevo = r.json()
    assert [t["nombre"] for t in nuevo] == ["Marek (incubadora)", "Vacuna propia"]
    assert nuevo[0]["id"] == primera["id"]
    assert segunda["id"] not in {t["id"] for t in nuevo}
    assert client.get(f"/lineas/{linea['id']}/plan").json() == nuevo
    assert client.get("/lineas").json()[0]["revisada"] is True


def test_el_plan_valida_semanas_y_tareas_ajenas(client):
    a = _linea(client, "A", "Hy-Line Brown")
    b = _linea(client, "B")
    tarea_de_a = client.get(f"/lineas/{a['id']}/plan").json()[0]
    mala = {"nombre": "X", "tipo": "vacuna", "semana_ideal": 6, "semana_max": 4}
    assert client.put(f"/lineas/{b['id']}/plan", json=[mala]).status_code == 422
    assert client.put(f"/lineas/{b['id']}/plan", json=[tarea_de_a]).status_code == 422
    assert client.put("/lineas/999/plan", json=[]).status_code == 404


def test_se_edita_la_curva_de_la_raza(client):
    linea = _linea(client, plantilla="Hy-Line Brown")
    puntos = [{"semana": 20, "postura_pct": 50, "peso_g": 1500}, {"semana": 21, "postura_pct": 70}]
    r = client.put(f"/lineas/{linea['id']}/curva", json=puntos)
    assert r.status_code == 200
    assert r.json() == [
        {"semana": 20, "postura_pct": 50, "peso_g": 1500},
        {"semana": 21, "postura_pct": 70, "peso_g": None},
    ]
    repetida = [{"semana": 20, "postura_pct": 50}, {"semana": 20, "postura_pct": 60}]
    assert client.put(f"/lineas/{linea['id']}/curva", json=repetida).status_code == 422


def test_solo_el_administrador_edita_razas_planes_y_curvas(client, mama):  # noqa: F811
    linea = _linea(client)
    assert mama.post("/lineas", json={"nombre": "X"}).status_code == 403
    assert mama.patch(f"/lineas/{linea['id']}", json={"nombre": "Y"}).status_code == 403
    assert mama.put(f"/lineas/{linea['id']}/plan", json=[]).status_code == 403
    assert mama.put(f"/lineas/{linea['id']}/curva", json=[]).status_code == 403
    assert mama.get(f"/lineas/{linea['id']}/plan").status_code == 200


def test_sin_sesion_la_sanidad_no_se_ve(client):
    anonimo = TestClient(app)
    assert anonimo.get("/sanidad").status_code == 401
    assert anonimo.put(f"/lotes/1/pesajes/{uuid.uuid4()}", json={}).status_code == 401


def test_el_panorama_de_un_lote_nuevo_marca_lo_que_toca(client):
    linea = _linea(client, plantilla="Hy-Line Brown")
    _lote(client, linea, HOY - timedelta(weeks=3))
    sanidad = _sanidad(client)
    galpon = sanidad["galpones"][0]
    assert (galpon["galpon"], galpon["linea"], galpon["edad_semanas"], galpon["etapa"]) == (
        "Galpón 1",
        "Hy-Line Brown",
        3,
        "cria",
    )
    assert _tarea(sanidad, "Marek")["estado"] == "atrasada"
    assert _tarea(sanidad, "Gumboro (1.ª)")["estado"] == "ahora"
    assert _tarea(sanidad, "Gumboro (2.ª)")["estado"] == "proxima"
    assert _tarea(sanidad, "Viruela aviar")["estado"] == "lejana"
    titulos = [a["titulo"] for a in sanidad["alertas"]]
    assert titulos[0] == "Marek: atrasada"
    assert "Toca: Gumboro (1.ª)" in titulos
    assert "Pollitas delicadas" in titulos


def test_un_lote_que_llega_grande_no_arrastra_las_vacunas_del_proveedor(client):
    linea = _linea(client, plantilla="Hy-Line Brown")
    nacimiento = HOY - timedelta(weeks=17)
    _lote(client, linea, nacimiento, ingreso=nacimiento + timedelta(weeks=16))
    sanidad = _sanidad(client)
    assert _tarea(sanidad, "Marek")["estado"] == "previa"
    assert _tarea(sanidad, "Coriza infecciosa (1.ª)")["estado"] == "previa"
    assert _tarea(sanidad, "Coriza infecciosa (2.ª)")["estado"] == "atrasada"
    assert _tarea(sanidad, "Desparasitación (2.ª)")["estado"] == "ahora"


def test_marcar_una_tarea_la_deja_aplicada_y_quita_la_alerta(client):
    linea = _linea(client, plantilla="Hy-Line Brown")
    _, lote = _lote(client, linea, HOY - timedelta(weeks=3))
    tarea = _tarea(_sanidad(client), "Marek")
    id_ = str(uuid.uuid4())
    cuerpo = {"tarea_id": tarea["tarea_id"], "fecha": str(HOY - timedelta(days=20)), "nota": "lote 4471"}
    r = client.put(f"/lotes/{lote['id']}/cumplimientos/{id_}", json=cuerpo)
    assert r.status_code == 200
    assert client.put(f"/lotes/{lote['id']}/cumplimientos/{id_}", json=cuerpo).status_code == 200

    sanidad = _sanidad(client)
    marcada = _tarea(sanidad, "Marek")
    assert (marcada["estado"], marcada["nota"], marcada["cumplimiento_id"]) == ("aplicada", "lote 4471", id_)
    assert "Marek: atrasada" not in [a["titulo"] for a in sanidad["alertas"]]

    assert client.delete(f"/cumplimientos/{id_}").status_code == 204
    assert client.delete(f"/cumplimientos/{id_}").status_code == 204
    assert _tarea(_sanidad(client), "Marek")["estado"] == "atrasada"


def test_marcar_dos_veces_con_otro_id_es_conflicto_y_valida_el_lote_y_la_fecha(client):
    linea = _linea(client, plantilla="Hy-Line Brown")
    otra = _linea(client, "Otra", "Lohmann Brown")
    _, lote = _lote(client, linea, HOY - timedelta(weeks=3))
    tarea = _tarea(_sanidad(client), "Marek")["tarea_id"]
    cuerpo = {"tarea_id": tarea, "fecha": str(HOY)}
    assert client.put(f"/lotes/{lote['id']}/cumplimientos/{uuid.uuid4()}", json=cuerpo).status_code == 200
    assert client.put(f"/lotes/{lote['id']}/cumplimientos/{uuid.uuid4()}", json=cuerpo).status_code == 409
    assert client.put(f"/lotes/999/cumplimientos/{uuid.uuid4()}", json=cuerpo).status_code == 404
    antes = {"tarea_id": tarea, "fecha": str(HOY - timedelta(weeks=10))}
    assert client.put(f"/lotes/{lote['id']}/cumplimientos/{uuid.uuid4()}", json=antes).status_code == 422
    ajena = client.get(f"/lineas/{otra['id']}/plan").json()[0]["id"]
    assert (
        client.put(
            f"/lotes/{lote['id']}/cumplimientos/{uuid.uuid4()}", json={"tarea_id": ajena, "fecha": str(HOY)}
        ).status_code
        == 404
    )


def test_el_pesaje_se_compara_con_la_curva_de_la_raza(client, mama):  # noqa: F811
    linea = _linea(client, plantilla="Hy-Line Brown")
    _, lote = _lote(client, linea, HOY - timedelta(weeks=10))
    esperado = next(p for p in client.get(f"/lineas/{linea['id']}/curva").json() if p["semana"] == 10)["peso_g"]
    pesaje = {"fecha": str(HOY), "peso_g": esperado * 0.88, "aves_pesadas": 40}
    id_ = str(uuid.uuid4())
    assert mama.put(f"/lotes/{lote['id']}/pesajes/{id_}", json=pesaje).status_code == 200
    assert mama.put(f"/lotes/{lote['id']}/pesajes/{id_}", json=pesaje).status_code == 200

    galpon = _sanidad(client)["galpones"][0]
    assert len(galpon["pesajes"]) == 1
    assert galpon["peso"]["nivel"] == "bajo"
    assert galpon["peso"]["estandar_g"] == esperado
    alerta = next(a for a in _sanidad(client)["alertas"] if a["tipo"] == "peso")
    assert (alerta["nivel"], alerta["titulo"]) == ("urgente", "Peso bajo")
    assert "sin_pesar" not in [a["tipo"] for a in _sanidad(client)["alertas"]]

    assert mama.delete(f"/pesajes/{id_}").status_code == 204
    assert _sanidad(client)["galpones"][0]["peso"] is None


def test_el_pesaje_valida_los_datos(client):
    linea = _linea(client, plantilla="Hy-Line Brown")
    _, lote = _lote(client, linea, HOY - timedelta(weeks=10))
    ruta = f"/lotes/{lote['id']}/pesajes/{uuid.uuid4()}"
    assert client.put(ruta, json={"fecha": str(HOY), "peso_g": 0, "aves_pesadas": 10}).status_code == 422
    assert client.put(ruta, json={"fecha": str(HOY), "peso_g": 800, "aves_pesadas": 0}).status_code == 422
    antes = {"fecha": str(HOY - timedelta(weeks=20)), "peso_g": 800, "aves_pesadas": 10}
    assert client.put(ruta, json=antes).status_code == 422
    nada = f"/lotes/999/pesajes/{uuid.uuid4()}"
    assert client.put(nada, json={"fecha": str(HOY), "peso_g": 800, "aves_pesadas": 10}).status_code == 404


def _registrar(client, galpon, fecha, huevos, muertas=0):
    id_ = str(uuid.uuid4())
    r = client.put(
        f"/registros/{id_}",
        json={
            "id": id_,
            "galpon_id": galpon["id"],
            "fecha": str(fecha),
            "huevos_total": huevos,
            "mortalidad": muertas,
        },
    )
    assert r.status_code == 200, r.text


def test_tres_dias_bajo_la_curva_activan_la_alerta_de_baja_postura(client):
    linea = _linea(client, plantilla="Hy-Line Brown")
    galpon, _ = _lote(client, linea, HOY - timedelta(weeks=30), aves=2000)
    for dia, huevos in [(6, 1900), (5, 1880), (3, 1700), (2, 1650), (1, 1600)]:
        _registrar(client, galpon, HOY - timedelta(days=dia), huevos)
    sanidad = _sanidad(client)
    alerta = next(a for a in sanidad["alertas"] if a["tipo"] == "baja_postura")
    assert alerta["nivel"] == "urgente"
    assert "3 días" in alerta["detalle"]
    assert sanidad["galpones"][0]["postura"]["estandar_pct"] == 95


def test_si_la_postura_se_recupera_no_hay_alerta(client):
    linea = _linea(client, plantilla="Hy-Line Brown")
    galpon, _ = _lote(client, linea, HOY - timedelta(weeks=30), aves=2000)
    for dia, huevos in [(3, 1600), (2, 1600), (1, 1900)]:
        _registrar(client, galpon, HOY - timedelta(days=dia), huevos)
    sanidad = _sanidad(client)
    assert not [a for a in sanidad["alertas"] if a["tipo"] == "baja_postura"]
    assert sanidad["galpones"][0]["postura"]["real_pct"] == 95.0


def test_la_mortalidad_de_la_semana_activa_la_alerta(client):
    linea = _linea(client, plantilla="Hy-Line Brown")
    galpon, _ = _lote(client, linea, HOY - timedelta(weeks=30), aves=2000)
    _registrar(client, galpon, HOY - timedelta(days=2), 1900, muertas=25)
    alerta = next(a for a in _sanidad(client)["alertas"] if a["tipo"] == "mortalidad")
    assert alerta["nivel"] == "urgente"
    assert "25 aves" in alerta["detalle"]


def test_sin_lotes_activos_el_panorama_esta_vacio(client, granja):
    solo = _sanidad(client, date(2026, 3, 1) - timedelta(days=1))
    assert solo["galpones"] == [] and solo["alertas"] == []
