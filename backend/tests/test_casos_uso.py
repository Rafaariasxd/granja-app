import uuid
from datetime import date

import pytest

from app.casos_uso import galpones, lineas, lotes, registros
from app.dominio.errores import Conflicto
from app.dominio.modelos import Lote
from tests.fakes import UnidadEnMemoria

HOY = date(2026, 10, 15)


@pytest.fixture
def uow():
    uow = UnidadEnMemoria()
    galpon = galpones.crear_galpon(uow, "Galpón 1", 6000)
    galpones.crear_galpon(uow, "Galpón 2", 2000)
    linea = lineas.crear_linea(uow, "Hy-Line Brown")
    lotes.crear_lote(
        uow,
        Lote(
            galpon_id=galpon.id,
            linea_id=linea.id,
            fecha_nacimiento=date(2026, 3, 1),
            fecha_ingreso=date(2026, 3, 2),
            aves_iniciales=5000,
        ),
    )
    return uow


def _dia(galpon_id=1, **campos):
    return registros.RegistroDelDia(id=uuid.uuid4(), galpon_id=galpon_id, fecha=HOY, huevos_total=4000, **campos)


def test_un_lote_cruzado_no_se_guarda(uow):
    confirmadas = uow.confirmaciones
    with pytest.raises(Conflicto):
        lotes.crear_lote(
            uow,
            Lote(
                galpon_id=1,
                linea_id=1,
                fecha_nacimiento=date(2026, 5, 1),
                fecha_ingreso=date(2026, 5, 2),
                aves_iniciales=1000,
            ),
        )
    assert uow.confirmaciones == confirmadas
    assert len(uow.lotes.del_galpon(1)) == 1


def test_reenviar_el_registro_no_lo_duplica(uow):
    dia = _dia(mortalidad=10)
    registros.guardar_registro(uow, dia)
    registros.guardar_registro(uow, dia)
    assert len(uow.registros.filas) == 1


def test_el_registro_queda_en_el_lote_activo_del_galpon(uow):
    guardado = registros.guardar_registro(uow, _dia())
    assert guardado.lote_id == 1


def test_resumen_del_dia(uow):
    registros.guardar_registro(uow, _dia(mortalidad=50))
    resumen = {r.nombre: r for r in galpones.resumen_galpones(uow, HOY)}
    assert resumen["Galpón 1"].aves_vivas == 4950
    assert resumen["Galpón 1"].postura_pct == 80.8
    assert resumen["Galpón 2"].lote_id is None


def test_el_registro_del_dia_sale_del_lote_activo(uow):
    guardado = registros.guardar_registro(uow, _dia())
    assert registros.registro_del_dia(uow, 1, HOY).id == guardado.id
    assert registros.registro_del_dia(uow, 2, HOY) is None
