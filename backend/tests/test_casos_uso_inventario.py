import uuid
from datetime import date, datetime, timedelta

import pytest

from app.casos_uso import galpones, inventario, lineas, lotes, registros
from app.dominio.errores import Conflicto, DatosInvalidos, NoEncontrado
from app.dominio.modelos import Etapa, Ingrediente, Lote, Motivo, Rol, TipoInsumo, Usuario
from tests.fakes import UnidadEnMemoria

HOY = date(2026, 10, 15)
AHORA = datetime(2026, 10, 15, 14)
QUIEN = Usuario("Rafa", Rol.ADMINISTRADOR, "x", id=1)


@pytest.fixture
def uow():
    uow = UnidadEnMemoria()
    galpon = galpones.crear_galpon(uow, "Galpón 1", 6000)
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


@pytest.fixture
def bodega(uow):
    ids = {
        "maiz": inventario.crear_insumo(uow, "Maíz", TipoInsumo.MATERIA_PRIMA, None, 50).id,
        "soya": inventario.crear_insumo(uow, "Soya", TipoInsumo.MATERIA_PRIMA, None, 40).id,
        "calcio": inventario.crear_insumo(uow, "Calcio", TipoInsumo.MATERIA_PRIMA, None, 25).id,
        "mezcla": inventario.crear_insumo(
            uow, "Mezcla ponedora", TipoInsumo.ALIMENTO_PREPARADO, Etapa.PRODUCCION, None
        ).id,
        "italcol": inventario.crear_insumo(
            uow, "Italcol ponedora", TipoInsumo.ALIMENTO_COMPRADO, Etapa.PRODUCCION, 40
        ).id,
    }
    inventario.definir_formula(
        uow,
        QUIEN,
        ids["mezcla"],
        [Ingrediente(ids["maiz"], 60), Ingrediente(ids["soya"], 25), Ingrediente(ids["calcio"], 15)],
        AHORA,
    )
    return ids


def _comprar(uow, insumo_id, bultos):
    return inventario.registrar_compra(uow, QUIEN, insumo_id, HOY, bultos, None)


def _stock(uow, insumo_id):
    return uow.insumos.stocks().get(insumo_id, 0.0)


def _dia(fecha, alimento, galpon_id=1):
    return registros.RegistroDelDia(
        id=uuid.uuid4(), galpon_id=galpon_id, fecha=fecha, huevos_total=4000, alimento_kg=alimento
    )


def test_el_nombre_de_un_insumo_no_se_repite(uow, bodega):
    with pytest.raises(Conflicto):
        inventario.crear_insumo(uow, "Maíz", TipoInsumo.MATERIA_PRIMA, None, 50)


def test_medio_bulto_cuenta_como_la_mitad_de_los_kilos(uow, bodega):
    _comprar(uow, bodega["maiz"], 2.5)
    assert _stock(uow, bodega["maiz"]) == 125


def test_la_compra_se_puede_dar_en_kilos(uow, bodega):
    inventario.registrar_compra(uow, QUIEN, bodega["maiz"], HOY, None, 30)
    assert _stock(uow, bodega["maiz"]) == 30


def test_la_compra_pide_bultos_o_kilos_pero_no_ambos_ni_ninguno(uow, bodega):
    with pytest.raises(DatosInvalidos):
        inventario.registrar_compra(uow, QUIEN, bodega["maiz"], HOY, 1, 50)
    with pytest.raises(DatosInvalidos):
        inventario.registrar_compra(uow, QUIEN, bodega["maiz"], HOY, None, None)


def test_el_alimento_preparado_no_se_compra(uow, bodega):
    with pytest.raises(DatosInvalidos):
        _comprar(uow, bodega["mezcla"], 1)


def test_comprar_un_insumo_que_no_existe(uow):
    with pytest.raises(NoEncontrado):
        _comprar(uow, 99, 1)


def test_una_compra_fallida_no_se_confirma(uow, bodega):
    confirmadas = uow.confirmaciones
    with pytest.raises(DatosInvalidos):
        _comprar(uow, bodega["mezcla"], 1)
    assert uow.confirmaciones == confirmadas


def test_la_formula_solo_la_tiene_el_alimento_preparado(uow, bodega):
    with pytest.raises(DatosInvalidos):
        inventario.definir_formula(uow, QUIEN, bodega["italcol"], [Ingrediente(bodega["maiz"], 100)], AHORA)


def test_la_formula_solo_acepta_materias_primas(uow, bodega):
    with pytest.raises(DatosInvalidos):
        inventario.definir_formula(uow, QUIEN, bodega["mezcla"], [Ingrediente(bodega["italcol"], 100)], AHORA)


def test_definir_la_formula_queda_en_la_bitacora_y_reemplaza_la_anterior(uow, bodega):
    inventario.definir_formula(uow, QUIEN, bodega["mezcla"], [Ingrediente(bodega["maiz"], 100)], AHORA)
    assert inventario.formula_de(uow, bodega["mezcla"]) == [Ingrediente(bodega["maiz"], 100)]
    assert uow.bitacora.listar()[-1].accion == "formula_definida"


def test_preparar_gasta_las_materias_primas_y_suma_el_alimento(uow, bodega):
    _comprar(uow, bodega["maiz"], 10)
    _comprar(uow, bodega["soya"], 10)
    _comprar(uow, bodega["calcio"], 10)

    inventario.preparar_alimento(uow, QUIEN, bodega["mezcla"], HOY, 500)

    assert _stock(uow, bodega["mezcla"]) == 500
    assert _stock(uow, bodega["maiz"]) == 200
    assert _stock(uow, bodega["soya"]) == 275
    assert _stock(uow, bodega["calcio"]) == 175


def test_no_se_prepara_si_falta_materia_prima_y_no_se_toca_nada(uow, bodega):
    _comprar(uow, bodega["maiz"], 10)
    _comprar(uow, bodega["soya"], 1)
    _comprar(uow, bodega["calcio"], 10)
    confirmadas = uow.confirmaciones

    with pytest.raises(DatosInvalidos, match="Soya"):
        inventario.preparar_alimento(uow, QUIEN, bodega["mezcla"], HOY, 500)

    assert _stock(uow, bodega["maiz"]) == 500
    assert _stock(uow, bodega["mezcla"]) == 0
    assert uow.confirmaciones == confirmadas


def test_no_se_prepara_sin_formula_ni_con_kilos_en_cero(uow, bodega):
    otro = inventario.crear_insumo(uow, "Levante casero", TipoInsumo.ALIMENTO_PREPARADO, Etapa.LEVANTE, None)
    with pytest.raises(DatosInvalidos, match="fórmula"):
        inventario.preparar_alimento(uow, QUIEN, otro.id, HOY, 100)
    with pytest.raises(DatosInvalidos):
        inventario.preparar_alimento(uow, QUIEN, bodega["mezcla"], HOY, 0)


def test_ajustar_stock_deja_el_conteo_real_y_guarda_la_diferencia(uow, bodega):
    _comprar(uow, bodega["maiz"], 2)
    movimiento = inventario.ajustar_stock(uow, QUIEN, bodega["maiz"], HOY, 85, "conteo del lunes")
    assert movimiento.kg == -15
    assert movimiento.motivo == Motivo.AJUSTE
    assert _stock(uow, bodega["maiz"]) == 85


def test_ajustar_a_lo_mismo_no_crea_movimiento(uow, bodega):
    _comprar(uow, bodega["maiz"], 2)
    assert inventario.ajustar_stock(uow, QUIEN, bodega["maiz"], HOY, 100, "") is None
    assert len(inventario.historial(uow, bodega["maiz"])) == 1


def test_el_conteo_no_puede_ser_negativo(uow, bodega):
    with pytest.raises(DatosInvalidos):
        inventario.ajustar_stock(uow, QUIEN, bodega["maiz"], HOY, -1, "")


def test_el_alimento_en_uso_debe_ser_de_la_misma_etapa(uow, bodega):
    inventario.definir_alimento_en_uso(uow, QUIEN, Etapa.PRODUCCION, bodega["italcol"], AHORA)
    assert uow.alimento_en_uso.de(Etapa.PRODUCCION) == bodega["italcol"]
    with pytest.raises(DatosInvalidos):
        inventario.definir_alimento_en_uso(uow, QUIEN, Etapa.LEVANTE, bodega["italcol"], AHORA)
    with pytest.raises(DatosInvalidos):
        inventario.definir_alimento_en_uso(uow, QUIEN, Etapa.PRODUCCION, bodega["maiz"], AHORA)


def test_el_registro_del_dia_gasta_el_alimento_en_uso(uow, bodega):
    _comprar(uow, bodega["italcol"], 20)
    inventario.definir_alimento_en_uso(uow, QUIEN, Etapa.PRODUCCION, bodega["italcol"], AHORA)

    registros.guardar_registro(uow, _dia(HOY, 300))

    assert _stock(uow, bodega["italcol"]) == 500


def test_reenviar_o_corregir_el_registro_no_gasta_dos_veces(uow, bodega):
    _comprar(uow, bodega["italcol"], 20)
    inventario.definir_alimento_en_uso(uow, QUIEN, Etapa.PRODUCCION, bodega["italcol"], AHORA)
    dia = _dia(HOY, 300)

    registros.guardar_registro(uow, dia)
    registros.guardar_registro(uow, dia)
    assert _stock(uow, bodega["italcol"]) == 500

    registros.guardar_registro(uow, registros.RegistroDelDia(**{**dia.__dict__, "alimento_kg": 280}))
    assert _stock(uow, bodega["italcol"]) == 520


def test_borrar_el_registro_devuelve_el_alimento(uow, bodega):
    _comprar(uow, bodega["italcol"], 20)
    inventario.definir_alimento_en_uso(uow, QUIEN, Etapa.PRODUCCION, bodega["italcol"], AHORA)
    dia = _dia(HOY, 300)
    registros.guardar_registro(uow, dia)

    registros.borrar_registro(uow, QUIEN, dia.id, AHORA)

    assert _stock(uow, bodega["italcol"]) == 800


def test_sin_alimento_en_uso_el_registro_no_toca_el_inventario(uow, bodega):
    _comprar(uow, bodega["italcol"], 20)
    registros.guardar_registro(uow, _dia(HOY, 300))
    assert _stock(uow, bodega["italcol"]) == 800


def test_un_registro_sin_alimento_no_deja_movimiento(uow, bodega):
    _comprar(uow, bodega["italcol"], 20)
    inventario.definir_alimento_en_uso(uow, QUIEN, Etapa.PRODUCCION, bodega["italcol"], AHORA)
    dia = _dia(HOY, 300)
    registros.guardar_registro(uow, dia)

    registros.guardar_registro(uow, registros.RegistroDelDia(**{**dia.__dict__, "alimento_kg": 0}))

    assert _stock(uow, bodega["italcol"]) == 800


def test_el_registro_se_guarda_aunque_el_alimento_quede_en_negativo(uow, bodega):
    inventario.definir_alimento_en_uso(uow, QUIEN, Etapa.PRODUCCION, bodega["italcol"], AHORA)
    registros.guardar_registro(uow, _dia(HOY, 300))
    assert _stock(uow, bodega["italcol"]) == -300


def _semana_de_consumo(uow, kilos_por_dia):
    for atras in range(len(kilos_por_dia)):
        registros.guardar_registro(uow, _dia(HOY - timedelta(days=atras), kilos_por_dia[atras]))


def test_cuantos_dias_alcanza_el_alimento_comprado(uow, bodega):
    _comprar(uow, bodega["italcol"], 20)
    _semana_de_consumo(uow, [300, 300, 300])

    estado = inventario.estado_inventario(uow, HOY)

    italcol = next(e for e in estado.existencias if e.insumo.id == bodega["italcol"])
    assert italcol.stock_kg == 800
    assert italcol.bultos == 20
    assert italcol.consumo_diario_kg == 300
    assert italcol.dias == 2.7
    assert italcol.nivel == "poco"
    cobertura = estado.etapas[0]
    assert (cobertura.etapa, cobertura.dias) == (Etapa.PRODUCCION, 2.7)


def test_cuando_no_hay_consumo_registrado_no_se_inventan_dias(uow, bodega):
    _comprar(uow, bodega["italcol"], 20)
    estado = inventario.estado_inventario(uow, HOY)
    italcol = next(e for e in estado.existencias if e.insumo.id == bodega["italcol"])
    assert italcol.dias is None
    assert italcol.nivel == "sin_datos"


def test_el_consumo_viejo_fuera_de_la_semana_no_cuenta(uow, bodega):
    _comprar(uow, bodega["italcol"], 20)
    registros.guardar_registro(uow, _dia(HOY - timedelta(days=30), 300))
    assert inventario.estado_inventario(uow, HOY).etapas[0].consumo_diario_kg is None


def test_la_materia_prima_dice_para_cuantos_dias_de_alimento_alcanza(uow, bodega):
    _comprar(uow, bodega["maiz"], 20)
    _comprar(uow, bodega["soya"], 2)
    _comprar(uow, bodega["calcio"], 20)
    inventario.definir_alimento_en_uso(uow, QUIEN, Etapa.PRODUCCION, bodega["mezcla"], AHORA)
    _semana_de_consumo(uow, [400, 400])

    estado = {e.insumo.nombre: e for e in inventario.estado_inventario(uow, HOY).existencias}

    assert estado["Maíz"].consumo_diario_kg == 240
    assert estado["Maíz"].dias == 4.2
    assert estado["Soya"].consumo_diario_kg == 100
    assert estado["Soya"].dias == 0.8
    assert estado["Soya"].nivel == "critico"
    assert estado["Calcio"].dias == 8.3
    assert estado["Calcio"].nivel == "bien"


def test_la_mezcla_posible_nombra_lo_que_falta_primero(uow, bodega):
    _comprar(uow, bodega["maiz"], 20)
    _comprar(uow, bodega["soya"], 3)
    _comprar(uow, bodega["calcio"], 20)
    inventario.preparar_alimento(uow, QUIEN, bodega["mezcla"], HOY, 400)
    inventario.definir_alimento_en_uso(uow, QUIEN, Etapa.PRODUCCION, bodega["mezcla"], AHORA)
    _semana_de_consumo(uow, [400])

    mezcla = inventario.estado_inventario(uow, HOY).mezclas[0]

    assert mezcla.stock_kg == 0
    assert mezcla.limitante == "Soya"
    assert mezcla.kg_posibles == 80
    assert mezcla.dias == 0.2


def test_si_se_usa_alimento_comprado_la_materia_prima_no_se_gasta(uow, bodega):
    _comprar(uow, bodega["maiz"], 20)
    _comprar(uow, bodega["italcol"], 20)
    inventario.definir_alimento_en_uso(uow, QUIEN, Etapa.PRODUCCION, bodega["italcol"], AHORA)
    _semana_de_consumo(uow, [400])

    maiz = next(e for e in inventario.estado_inventario(uow, HOY).existencias if e.insumo.id == bodega["maiz"])

    assert maiz.consumo_diario_kg is None
    assert maiz.dias is None
