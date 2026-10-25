from datetime import date

import pytest

from app.dominio import inventario as reglas
from app.dominio.errores import DatosInvalidos
from app.dominio.modelos import Etapa, Ingrediente, TipoInsumo

MAIZ = Ingrediente(1, 60)
SOYA = Ingrediente(2, 25)
CALCIO = Ingrediente(3, 15)
FORMULA = [MAIZ, SOYA, CALCIO]


def test_medio_bulto_se_convierte_a_kilos_y_de_vuelta():
    assert reglas.kg_de_bultos(0.5, 40) == 20
    assert reglas.bultos_de_kg(20, 40) == 0.5
    assert reglas.bultos_de_kg(130, 40) == 3.25
    assert reglas.bultos_de_kg(130, None) is None


def test_la_materia_prima_y_el_alimento_comprado_necesitan_kilos_por_bulto():
    with pytest.raises(DatosInvalidos):
        reglas.validar_insumo(TipoInsumo.MATERIA_PRIMA, None, None)
    with pytest.raises(DatosInvalidos):
        reglas.validar_insumo(TipoInsumo.ALIMENTO_COMPRADO, Etapa.PRODUCCION, None)
    reglas.validar_insumo(TipoInsumo.ALIMENTO_PREPARADO, Etapa.PRODUCCION, None)


def test_el_alimento_necesita_etapa_y_la_materia_prima_no_la_tiene():
    with pytest.raises(DatosInvalidos):
        reglas.validar_insumo(TipoInsumo.ALIMENTO_PREPARADO, None, None)
    with pytest.raises(DatosInvalidos):
        reglas.validar_insumo(TipoInsumo.MATERIA_PRIMA, Etapa.LEVANTE, 50)


def test_los_kilos_por_bulto_deben_ser_positivos():
    with pytest.raises(DatosInvalidos):
        reglas.validar_insumo(TipoInsumo.MATERIA_PRIMA, None, 0)


def test_la_formula_debe_sumar_cien():
    reglas.validar_formula(FORMULA)
    with pytest.raises(DatosInvalidos, match="suman 95"):
        reglas.validar_formula([MAIZ, SOYA, Ingrediente(3, 10)])


def test_la_formula_no_admite_repetidos_vacia_ni_porcentajes_en_cero():
    with pytest.raises(DatosInvalidos):
        reglas.validar_formula([])
    with pytest.raises(DatosInvalidos):
        reglas.validar_formula([Ingrediente(1, 50), Ingrediente(1, 50)])
    with pytest.raises(DatosInvalidos):
        reglas.validar_formula([Ingrediente(1, 100), Ingrediente(2, 0)])


def test_kilos_de_cada_ingrediente_para_una_mezcla():
    assert reglas.kg_de_ingredientes(FORMULA, 500) == {1: 300, 2: 125, 3: 75}


def test_faltantes_solo_trae_lo_que_no_alcanza():
    necesidad = {1: 300, 2: 125, 3: 75}
    assert reglas.faltantes(necesidad, {1: 300, 2: 100, 3: 500}) == {2: 25}
    assert reglas.faltantes(necesidad, {1: 300, 2: 125, 3: 75}) == {}
    assert reglas.faltantes(necesidad, {}) == {1: 300, 2: 125, 3: 75}


def test_la_mezcla_posible_la_marca_el_ingrediente_que_se_acaba_primero():
    stock = {1: 3000, 2: 250, 3: 1500}
    kg, limitante = reglas.mezcla_posible(FORMULA, stock)
    assert limitante == 2
    assert kg == 1000


def test_sin_un_ingrediente_no_se_puede_mezclar():
    kg, limitante = reglas.mezcla_posible(FORMULA, {1: 3000, 2: 250})
    assert (kg, limitante) == (0, 3)


def test_el_stock_negativo_no_da_mezcla_negativa():
    assert reglas.mezcla_posible(FORMULA, {1: -50, 2: 250, 3: 100})[0] == 0


def test_dias_de_alcance():
    assert reglas.dias_de_alcance(100, 40) == 2.5
    assert reglas.dias_de_alcance(0, 40) == 0
    assert reglas.dias_de_alcance(-5, 40) == 0
    assert reglas.dias_de_alcance(100, None) is None
    assert reglas.dias_de_alcance(100, 0) is None


@pytest.mark.parametrize(
    ("dias", "nivel"),
    [(None, "sin_datos"), (0, "critico"), (2, "critico"), (2.1, "poco"), (5, "poco"), (5.1, "bien")],
)
def test_nivel_de_alcance(dias, nivel):
    assert reglas.nivel_de_alcance(dias) == nivel


def test_consumo_diario_promedia_los_dias_con_registro_de_la_ventana():
    hoy = date(2026, 10, 20)
    kilos = {
        date(2026, 10, 20): 300.0,
        date(2026, 10, 19): 330.0,
        date(2026, 10, 18): 0.0,
        date(2026, 10, 10): 900.0,
    }
    assert reglas.consumo_diario(kilos, hoy) == 315
    assert reglas.consumo_diario({}, hoy) is None
