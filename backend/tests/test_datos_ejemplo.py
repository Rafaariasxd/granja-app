from datetime import date

import pytest

from app import datos_ejemplo
from app.casos_uso import finanzas, galpones, inventario, sanidad, usuarios
from app.dominio.modelos import Etapa, Rol
from tests.fakes import UnidadEnMemoria

HOY = date(2026, 10, 21)


def test_los_datos_de_ejemplo_pasan_por_las_reglas_de_la_app():
    uow = UnidadEnMemoria()
    datos_ejemplo.cargar(uow, HOY)
    resumen = {r.nombre: r for r in galpones.resumen_galpones(uow, HOY)}
    assert len(resumen) == 7
    assert sum(1 for r in resumen.values() if r.lote_id is None) == 4
    assert resumen["Galpón 1"].postura_pct == 86.0
    assert resumen["Galpón 3"].postura_pct is None
    assert resumen["Galpón 5"].etapa == "levante"


def test_no_carga_sobre_una_base_con_datos():
    uow = UnidadEnMemoria()
    datos_ejemplo.cargar(uow, HOY)
    with pytest.raises(SystemExit):
        datos_ejemplo.cargar(uow, HOY)


def test_con_un_administrador_carga_tambien_el_inventario_en_tres_bodegas():
    uow = UnidadEnMemoria()
    usuarios.crear_usuario(uow, "Rafa", "483920", Rol.ADMINISTRADOR)
    datos_ejemplo.cargar(uow, HOY)

    estado = inventario.estado_inventario(uow, HOY)

    assert [b.bodega.nombre for b in estado.bodegas] == ["Bodega 1", "Bodega 2", "Bodega de materia prima"]
    ponedoras = estado.bodegas[0]
    assert {e.insumo.nombre for e in ponedoras.existencias} == {"Mezcla ponedora"}
    assert ponedoras.etapas[0].etapa == Etapa.PRODUCCION
    assert ponedoras.etapas[0].consumo_diario_kg > 0
    assert estado.bodegas[1].etapas[0].etapa == Etapa.LEVANTE
    assert len(estado.bodegas[2].existencias) == 5
    assert estado.mezclas[0].limitante


def test_sin_administrador_no_carga_inventario():
    uow = UnidadEnMemoria()
    datos_ejemplo.cargar(uow, HOY)
    assert uow.insumos.listar() == []


def test_los_datos_de_ejemplo_dejan_alertas_de_sanidad_para_ver():
    uow = UnidadEnMemoria()
    datos_ejemplo.cargar(uow, HOY)
    titulos = {(a.galpon, a.titulo) for a in sanidad.panorama(uow, HOY).alertas}
    assert ("Galpón 1", "Newcastle (refuerzo en postura): atrasada") in titulos
    assert ("Galpón 5", "Peso algo bajo") in titulos
    assert not any(t.endswith(": atrasada") for g, t in titulos if g == "Galpón 3")


def test_los_datos_de_ejemplo_traen_ventas_y_gastos_del_mes():
    uow = UnidadEnMemoria()
    datos_ejemplo.cargar(uow, HOY)
    r = finanzas.resumen(uow, date(2026, 10, 1), HOY)
    assert r.ingresos > 0 and r.egresos > 0
    assert {v.categoria for v in r.huevos} == {"AA", "A", "B"}
