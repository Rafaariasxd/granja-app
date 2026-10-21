from datetime import date, timedelta

import pytest

from app.dominio.produccion import (
    DiaPostura,
    Etapa,
    aves_vivas,
    baja_postura,
    edad_semanas,
    etapa,
    ocupacion_pct,
    postura_pct,
)

NACIMIENTO = date(2026, 1, 1)


def test_edad_en_semanas_completas():
    assert edad_semanas(NACIMIENTO, NACIMIENTO) == 0
    assert edad_semanas(NACIMIENTO, NACIMIENTO + timedelta(days=13)) == 1
    assert edad_semanas(NACIMIENTO, NACIMIENTO + timedelta(days=14)) == 2


def test_edad_antes_del_nacimiento_es_error():
    with pytest.raises(ValueError):
        edad_semanas(NACIMIENTO, NACIMIENTO - timedelta(days=1))


@pytest.mark.parametrize(
    ("semanas", "esperada"),
    [(0, Etapa.CRIA), (5, Etapa.CRIA), (6, Etapa.LEVANTE), (17, Etapa.LEVANTE), (18, Etapa.PRODUCCION)],
)
def test_etapa_por_edad(semanas, esperada):
    assert etapa(NACIMIENTO, NACIMIENTO + timedelta(weeks=semanas)) == esperada


def test_etapa_con_cortes_personalizados():
    assert etapa(NACIMIENTO, NACIMIENTO + timedelta(weeks=17), inicio_produccion=16) == Etapa.PRODUCCION


def test_aves_vivas_no_baja_de_cero():
    assert aves_vivas(5000, 120) == 4880
    assert aves_vivas(100, 150) == 0


def test_postura_y_ocupacion():
    assert postura_pct(4300, 5000) == 86.0
    assert postura_pct(10, 0) == 0.0
    assert ocupacion_pct(4500, 6000) == 75.0


def _dias(reales, estandar=93.0):
    return [DiaPostura(NACIMIENTO + timedelta(days=i), r, estandar) for i, r in enumerate(reales)]


def test_baja_postura_tres_dias_seguidos():
    assert baja_postura(_dias([92.0, 86.0, 85.0, 87.0]))


def test_un_dia_bueno_reinicia_la_alerta():
    assert not baja_postura(_dias([86.0, 85.0, 92.0]))


def test_justo_en_el_umbral_no_alerta():
    assert not baja_postura(_dias([88.0, 88.0, 88.0]))


def test_pocos_dias_no_alerta():
    assert not baja_postura(_dias([80.0, 80.0]))


def test_orden_de_entrada_no_importa():
    assert baja_postura(list(reversed(_dias([92.0, 86.0, 85.0, 87.0]))))
