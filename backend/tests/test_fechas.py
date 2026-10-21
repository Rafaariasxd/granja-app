from datetime import date

from app.dominio.fechas import periodos_se_cruzan

ENE = date(2026, 1, 1)
MAR = date(2026, 3, 1)
JUN = date(2026, 6, 1)
SEP = date(2026, 9, 1)


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
