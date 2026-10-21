from datetime import date

import pytest

from app.dominio.errores import Conflicto, DatosInvalidos
from app.dominio.lotes import activo_en, validar_ingreso, validar_salida
from app.dominio.modelos import Galpon, Lote

GALPON = Galpon(id=1, nombre="Galpón 1", capacidad_aves=6000)


def _lote(id_, ingreso, salida=None, aves=5000):
    return Lote(
        id=id_,
        galpon_id=1,
        linea_id=1,
        fecha_nacimiento=date(2025, 12, 1),
        fecha_ingreso=ingreso,
        aves_iniciales=aves,
        fecha_salida=salida,
    )


ACTUAL = _lote(1, date(2026, 3, 2))
VIEJO = _lote(2, date(2025, 12, 2), date(2026, 2, 28))


def test_activo_en_busca_el_lote_de_ese_dia():
    assert activo_en([VIEJO, ACTUAL], date(2026, 1, 15)) == VIEJO
    assert activo_en([VIEJO, ACTUAL], date(2026, 10, 1)) == ACTUAL
    assert activo_en([VIEJO], date(2026, 10, 1)) is None


def test_ingreso_antes_del_nacimiento():
    with pytest.raises(DatosInvalidos):
        validar_ingreso(_lote(None, date(2025, 11, 1)), GALPON, [])


def test_ingreso_cruzado_con_el_lote_activo():
    with pytest.raises(Conflicto):
        validar_ingreso(_lote(None, date(2026, 1, 1)), GALPON, [ACTUAL])


def test_ingreso_sobre_la_capacidad():
    with pytest.raises(DatosInvalidos):
        validar_ingreso(_lote(None, date(2026, 3, 1), aves=7000), GALPON, [VIEJO])


def test_ingreso_valido_despues_del_lote_anterior():
    validar_ingreso(_lote(None, date(2026, 3, 1)), GALPON, [VIEJO])


def test_salida_antes_del_ultimo_registro():
    with pytest.raises(DatosInvalidos):
        validar_salida(ACTUAL, date(2026, 10, 1), date(2026, 10, 15), [ACTUAL])


def test_salida_que_se_cruza_con_el_lote_siguiente():
    siguiente = _lote(3, date(2026, 10, 5))
    cerrado = _lote(1, date(2026, 3, 2), date(2026, 10, 1))
    with pytest.raises(Conflicto):
        validar_salida(cerrado, date(2026, 10, 20), None, [cerrado, siguiente])


def test_salida_valida():
    validar_salida(ACTUAL, date(2026, 10, 20), date(2026, 10, 15), [VIEJO, ACTUAL])
