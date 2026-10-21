from datetime import UTC, date, datetime

from app.dominio.fechas import fecha_en_granja, periodos_se_cruzan

ENE = date(2026, 1, 1)
MAR = date(2026, 3, 1)
JUN = date(2026, 6, 1)
SEP = date(2026, 9, 1)


def test_de_noche_en_colombia_sigue_siendo_el_mismo_dia():
    assert fecha_en_granja(datetime(2026, 10, 22, 1, 30, tzinfo=UTC)) == date(2026, 10, 21)


def test_de_dia_la_fecha_coincide():
    assert fecha_en_granja(datetime(2026, 10, 21, 15, 0, tzinfo=UTC)) == date(2026, 10, 21)


def test_dos_periodos_abiertos_se_cruzan():
    assert periodos_se_cruzan(ENE, None, JUN, None)


def test_periodo_cerrado_antes_no_se_cruza():
    assert not periodos_se_cruzan(ENE, MAR, JUN, None)
    assert not periodos_se_cruzan(JUN, None, ENE, MAR)


def test_el_dia_de_salida_cuenta():
    assert periodos_se_cruzan(ENE, JUN, JUN, None)


def test_uno_dentro_del_otro():
    assert periodos_se_cruzan(ENE, SEP, MAR, JUN)


def test_abierto_que_empieza_antes_se_cruza_con_uno_posterior():
    assert periodos_se_cruzan(ENE, None, JUN, SEP)
