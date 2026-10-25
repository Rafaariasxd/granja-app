from datetime import date

import pytest

from app import datos_ejemplo
from app.casos_uso import galpones, inventario, usuarios
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


def test_con_un_administrador_carga_tambien_el_inventario():
    uow = UnidadEnMemoria()
    usuarios.crear_usuario(uow, "Rafa", "483920", Rol.ADMINISTRADOR)
    datos_ejemplo.cargar(uow, HOY)

    estado = inventario.estado_inventario(uow, HOY)

    nombres = {e.insumo.nombre for e in estado.existencias}
    assert {"Maíz", "Soya", "Mezcla ponedora", "Italcol levante"} <= nombres
    ponedora = next(c for c in estado.etapas if c.etapa == Etapa.PRODUCCION)
    assert ponedora.consumo_diario_kg > 0
    assert estado.mezclas[0].limitante


def test_sin_administrador_no_carga_inventario():
    uow = UnidadEnMemoria()
    datos_ejemplo.cargar(uow, HOY)
    assert uow.insumos.listar() == []
