import uuid
from datetime import date, datetime, timedelta

import pytest

from app.casos_uso import galpones, inventario, lineas, lotes, registros
from app.dominio.errores import Conflicto, DatosInvalidos, NoEncontrado
from app.dominio.modelos import Etapa, Ingrediente, Lote, Motivo, Rol, TipoBodega, TipoInsumo, Usuario
from tests.fakes import UnidadEnMemoria

HOY = date(2026, 10, 15)
AHORA = datetime(2026, 10, 15, 14)
QUIEN = Usuario("Rafa", Rol.ADMINISTRADOR, "x", id=1)


@pytest.fixture
def uow():
    uow = UnidadEnMemoria()
    linea = lineas.crear_linea(uow, "Hy-Line Brown")
    for nombre in ("Galpón 1", "Galpón 2"):
        galpon = galpones.crear_galpon(uow, nombre, 6000)
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
        "uno": inventario.crear_bodega(uow, "Bodega 1", TipoBodega.ALIMENTO).id,
        "dos": inventario.crear_bodega(uow, "Bodega 2", TipoBodega.ALIMENTO).id,
        "materia": inventario.crear_bodega(uow, "Bodega de materia prima", TipoBodega.MATERIA_PRIMA).id,
    }
    inventario.asignar_galpones(uow, QUIEN, ids["uno"], [1], AHORA)
    inventario.asignar_galpones(uow, QUIEN, ids["dos"], [2], AHORA)
    inventario.definir_formula(
        uow,
        QUIEN,
        ids["mezcla"],
        [Ingrediente(ids["maiz"], 60), Ingrediente(ids["soya"], 25), Ingrediente(ids["calcio"], 15)],
        AHORA,
    )
    return ids


def _comprar(uow, insumo_id, bodega_id, bultos):
    return inventario.registrar_compra(uow, QUIEN, insumo_id, bodega_id, HOY, bultos, None)


def _stock(uow, bodega_id, insumo_id):
    return uow.insumos.stocks().get((bodega_id, insumo_id), 0.0)


def _dia(fecha, alimento, galpon_id=1):
    return registros.RegistroDelDia(
        id=uuid.uuid4(), galpon_id=galpon_id, fecha=fecha, huevos_total=4000, alimento_kg=alimento
    )


def _en_uso(uow, bodega_id, insumo_id, etapa=Etapa.PRODUCCION):
    inventario.definir_alimento_en_uso(uow, QUIEN, bodega_id, etapa, insumo_id, AHORA)


def test_el_nombre_de_un_insumo_o_una_bodega_no_se_repite(uow, bodega):
    with pytest.raises(Conflicto):
        inventario.crear_insumo(uow, "Maíz", TipoInsumo.MATERIA_PRIMA, None, 50)
    with pytest.raises(Conflicto):
        inventario.crear_bodega(uow, "Bodega 1", TipoBodega.ALIMENTO)


def test_la_materia_prima_solo_entra_a_la_bodega_de_materia_prima(uow, bodega):
    with pytest.raises(DatosInvalidos, match="no es una bodega de materia prima"):
        _comprar(uow, bodega["maiz"], bodega["uno"], 1)


def test_el_alimento_comprado_no_entra_a_la_bodega_de_materia_prima(uow, bodega):
    with pytest.raises(DatosInvalidos, match="no es una bodega de alimento"):
        _comprar(uow, bodega["italcol"], bodega["materia"], 1)


def test_medio_bulto_cuenta_como_la_mitad_de_los_kilos(uow, bodega):
    _comprar(uow, bodega["maiz"], bodega["materia"], 2.5)
    assert _stock(uow, bodega["materia"], bodega["maiz"]) == 125


def test_la_compra_se_puede_dar_en_kilos(uow, bodega):
    inventario.registrar_compra(uow, QUIEN, bodega["maiz"], bodega["materia"], HOY, None, 30)
    assert _stock(uow, bodega["materia"], bodega["maiz"]) == 30


def test_la_compra_pide_bultos_o_kilos_pero_no_ambos_ni_ninguno(uow, bodega):
    with pytest.raises(DatosInvalidos):
        inventario.registrar_compra(uow, QUIEN, bodega["maiz"], bodega["materia"], HOY, 1, 50)
    with pytest.raises(DatosInvalidos):
        inventario.registrar_compra(uow, QUIEN, bodega["maiz"], bodega["materia"], HOY, None, None)


def test_el_alimento_preparado_no_se_compra(uow, bodega):
    with pytest.raises(DatosInvalidos):
        _comprar(uow, bodega["mezcla"], bodega["uno"], 1)


def test_comprar_un_insumo_o_en_una_bodega_que_no_existe(uow, bodega):
    with pytest.raises(NoEncontrado):
        _comprar(uow, 99, bodega["materia"], 1)
    with pytest.raises(NoEncontrado):
        _comprar(uow, bodega["maiz"], 99, 1)


def test_una_compra_fallida_no_se_confirma(uow, bodega):
    confirmadas = uow.confirmaciones
    with pytest.raises(DatosInvalidos):
        _comprar(uow, bodega["mezcla"], bodega["uno"], 1)
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


def _preparar(uow, bodega, kg, destino="dos"):
    return inventario.preparar_alimento(uow, QUIEN, bodega["mezcla"], bodega["materia"], bodega[destino], HOY, kg)


def _surtir(uow, bodega, maiz=10, soya=10, calcio=10):
    _comprar(uow, bodega["maiz"], bodega["materia"], maiz)
    _comprar(uow, bodega["soya"], bodega["materia"], soya)
    _comprar(uow, bodega["calcio"], bodega["materia"], calcio)


def test_preparar_gasta_la_materia_prima_y_deja_el_alimento_en_la_bodega_elegida(uow, bodega):
    _surtir(uow, bodega)

    _preparar(uow, bodega, 500)

    assert _stock(uow, bodega["dos"], bodega["mezcla"]) == 500
    assert _stock(uow, bodega["uno"], bodega["mezcla"]) == 0
    assert _stock(uow, bodega["materia"], bodega["maiz"]) == 200
    assert _stock(uow, bodega["materia"], bodega["soya"]) == 275
    assert _stock(uow, bodega["materia"], bodega["calcio"]) == 175


def test_no_se_prepara_si_falta_materia_prima_y_no_se_toca_nada(uow, bodega):
    _surtir(uow, bodega, soya=1)
    confirmadas = uow.confirmaciones

    with pytest.raises(DatosInvalidos, match="Soya"):
        _preparar(uow, bodega, 500)

    assert _stock(uow, bodega["materia"], bodega["maiz"]) == 500
    assert _stock(uow, bodega["dos"], bodega["mezcla"]) == 0
    assert uow.confirmaciones == confirmadas


def test_las_bodegas_de_preparacion_tienen_que_ser_del_tipo_correcto(uow, bodega):
    _surtir(uow, bodega)
    with pytest.raises(DatosInvalidos):
        inventario.preparar_alimento(uow, QUIEN, bodega["mezcla"], bodega["uno"], bodega["dos"], HOY, 100)
    with pytest.raises(DatosInvalidos):
        inventario.preparar_alimento(uow, QUIEN, bodega["mezcla"], bodega["materia"], bodega["materia"], HOY, 100)


def test_no_se_prepara_sin_formula_ni_con_kilos_en_cero(uow, bodega):
    otro = inventario.crear_insumo(uow, "Levante casero", TipoInsumo.ALIMENTO_PREPARADO, Etapa.LEVANTE, None)
    with pytest.raises(DatosInvalidos, match="fórmula"):
        inventario.preparar_alimento(uow, QUIEN, otro.id, bodega["materia"], bodega["uno"], HOY, 100)
    with pytest.raises(DatosInvalidos):
        _preparar(uow, bodega, 0)


def test_ajustar_stock_deja_el_conteo_real_y_guarda_la_diferencia(uow, bodega):
    _comprar(uow, bodega["maiz"], bodega["materia"], 2)
    movimiento = inventario.ajustar_stock(
        uow, QUIEN, bodega["maiz"], bodega["materia"], HOY, None, 85, "conteo del lunes"
    )
    assert movimiento.kg == -15
    assert movimiento.motivo == Motivo.AJUSTE
    assert _stock(uow, bodega["materia"], bodega["maiz"]) == 85


def test_ajustar_a_lo_mismo_no_crea_movimiento_y_el_conteo_no_es_negativo(uow, bodega):
    _comprar(uow, bodega["maiz"], bodega["materia"], 2)
    assert inventario.ajustar_stock(uow, QUIEN, bodega["maiz"], bodega["materia"], HOY, None, 100, "") is None
    assert len(inventario.historial(uow, bodega["maiz"])) == 1
    with pytest.raises(DatosInvalidos):
        inventario.ajustar_stock(uow, QUIEN, bodega["maiz"], bodega["materia"], HOY, None, -1, "")


def test_un_galpon_come_de_una_sola_bodega(uow, bodega):
    inventario.asignar_galpones(uow, QUIEN, bodega["dos"], [1, 2], AHORA)

    asignadas = {b.nombre: galpones_ for b, galpones_ in inventario.listar_bodegas(uow)}
    assert asignadas["Bodega 1"] == []
    assert asignadas["Bodega 2"] == [1, 2]
    assert uow.bodegas.de_galpon(1) == bodega["dos"]


def test_solo_las_bodegas_de_alimento_tienen_galpones_y_no_se_repiten(uow, bodega):
    with pytest.raises(DatosInvalidos):
        inventario.asignar_galpones(uow, QUIEN, bodega["materia"], [1], AHORA)
    with pytest.raises(DatosInvalidos):
        inventario.asignar_galpones(uow, QUIEN, bodega["uno"], [1, 1], AHORA)
    with pytest.raises(NoEncontrado):
        inventario.asignar_galpones(uow, QUIEN, bodega["uno"], [99], AHORA)


def test_el_alimento_en_uso_debe_ser_alimento_de_esa_etapa_y_bodega_de_alimento(uow, bodega):
    _en_uso(uow, bodega["uno"], bodega["italcol"])
    assert uow.alimento_en_uso.de(bodega["uno"], Etapa.PRODUCCION) == bodega["italcol"]
    with pytest.raises(DatosInvalidos):
        _en_uso(uow, bodega["uno"], bodega["italcol"], Etapa.LEVANTE)
    with pytest.raises(DatosInvalidos):
        _en_uso(uow, bodega["uno"], bodega["maiz"])
    with pytest.raises(DatosInvalidos):
        _en_uso(uow, bodega["materia"], bodega["italcol"])


def test_el_registro_gasta_de_la_bodega_de_su_galpon(uow, bodega):
    _comprar(uow, bodega["italcol"], bodega["uno"], 20)
    _comprar(uow, bodega["italcol"], bodega["dos"], 20)
    _en_uso(uow, bodega["uno"], bodega["italcol"])
    _en_uso(uow, bodega["dos"], bodega["italcol"])

    registros.guardar_registro(uow, _dia(HOY, 300, galpon_id=1))

    assert _stock(uow, bodega["uno"], bodega["italcol"]) == 500
    assert _stock(uow, bodega["dos"], bodega["italcol"]) == 800


def test_reenviar_o_corregir_el_registro_no_gasta_dos_veces(uow, bodega):
    _comprar(uow, bodega["italcol"], bodega["uno"], 20)
    _en_uso(uow, bodega["uno"], bodega["italcol"])
    dia = _dia(HOY, 300)

    registros.guardar_registro(uow, dia)
    registros.guardar_registro(uow, dia)
    assert _stock(uow, bodega["uno"], bodega["italcol"]) == 500

    registros.guardar_registro(uow, registros.RegistroDelDia(**{**dia.__dict__, "alimento_kg": 280}))
    assert _stock(uow, bodega["uno"], bodega["italcol"]) == 520


def test_borrar_el_registro_devuelve_el_alimento(uow, bodega):
    _comprar(uow, bodega["italcol"], bodega["uno"], 20)
    _en_uso(uow, bodega["uno"], bodega["italcol"])
    dia = _dia(HOY, 300)
    registros.guardar_registro(uow, dia)

    registros.borrar_registro(uow, QUIEN, dia.id, AHORA)

    assert _stock(uow, bodega["uno"], bodega["italcol"]) == 800


def test_si_el_galpon_no_tiene_bodega_o_no_hay_alimento_en_uso_no_se_toca_nada(uow, bodega):
    _comprar(uow, bodega["italcol"], bodega["uno"], 20)
    registros.guardar_registro(uow, _dia(HOY, 300, galpon_id=1))
    inventario.asignar_galpones(uow, QUIEN, bodega["uno"], [], AHORA)
    _en_uso(uow, bodega["uno"], bodega["italcol"])
    registros.guardar_registro(uow, _dia(HOY - timedelta(days=1), 300, galpon_id=1))
    assert _stock(uow, bodega["uno"], bodega["italcol"]) == 800


def test_un_registro_sin_alimento_no_deja_movimiento(uow, bodega):
    _comprar(uow, bodega["italcol"], bodega["uno"], 20)
    _en_uso(uow, bodega["uno"], bodega["italcol"])
    dia = _dia(HOY, 300)
    registros.guardar_registro(uow, dia)

    registros.guardar_registro(uow, registros.RegistroDelDia(**{**dia.__dict__, "alimento_kg": 0}))

    assert _stock(uow, bodega["uno"], bodega["italcol"]) == 800


def test_el_registro_se_guarda_aunque_el_alimento_quede_en_negativo(uow, bodega):
    _en_uso(uow, bodega["uno"], bodega["italcol"])
    registros.guardar_registro(uow, _dia(HOY, 300))
    assert _stock(uow, bodega["uno"], bodega["italcol"]) == -300


def _semana(uow, kilos_por_dia, galpon_id=1):
    for atras in range(len(kilos_por_dia)):
        registros.guardar_registro(uow, _dia(HOY - timedelta(days=atras), kilos_por_dia[atras], galpon_id))


def _de_bodega(estado, nombre):
    return next(b for b in estado.bodegas if b.bodega.nombre == nombre)


def test_cada_bodega_de_alimento_tiene_sus_propios_dias(uow, bodega):
    _comprar(uow, bodega["italcol"], bodega["uno"], 20)
    _comprar(uow, bodega["italcol"], bodega["dos"], 20)
    _en_uso(uow, bodega["uno"], bodega["italcol"])
    _en_uso(uow, bodega["dos"], bodega["italcol"])
    _semana(uow, [100, 100, 100], galpon_id=1)
    _semana(uow, [50, 50, 50], galpon_id=2)

    estado = inventario.estado_inventario(uow, HOY)

    uno, dos = _de_bodega(estado, "Bodega 1"), _de_bodega(estado, "Bodega 2")
    assert uno.galpon_ids == [1]
    assert uno.etapas[0].consumo_diario_kg == 100
    assert uno.etapas[0].dias == 5
    assert dos.etapas[0].consumo_diario_kg == 50
    assert dos.etapas[0].dias == 13
    existencia = uno.existencias[0]
    assert (existencia.stock_kg, existencia.bultos, existencia.dias) == (500, 12.5, 5)


def test_el_consumo_de_un_galpon_sin_bodega_no_cuenta_para_ninguna(uow, bodega):
    _comprar(uow, bodega["italcol"], bodega["uno"], 20)
    inventario.asignar_galpones(uow, QUIEN, bodega["uno"], [], AHORA)
    _semana(uow, [300], galpon_id=1)
    assert _de_bodega(inventario.estado_inventario(uow, HOY), "Bodega 1").etapas[0].consumo_diario_kg is None


def test_cuando_no_hay_consumo_registrado_no_se_inventan_dias(uow, bodega):
    _comprar(uow, bodega["italcol"], bodega["uno"], 20)
    existencia = _de_bodega(inventario.estado_inventario(uow, HOY), "Bodega 1").existencias[0]
    assert existencia.dias is None
    assert existencia.nivel == "sin_datos"


def test_el_consumo_viejo_fuera_de_la_semana_no_cuenta(uow, bodega):
    _comprar(uow, bodega["italcol"], bodega["uno"], 20)
    _en_uso(uow, bodega["uno"], bodega["italcol"])
    registros.guardar_registro(uow, _dia(HOY - timedelta(days=30), 300))
    assert _de_bodega(inventario.estado_inventario(uow, HOY), "Bodega 1").etapas[0].consumo_diario_kg is None


def _materia(uow):
    bodega = _de_bodega(inventario.estado_inventario(uow, HOY), "Bodega de materia prima")
    return {e.insumo.nombre: e for e in bodega.existencias}


def test_la_bodega_de_materia_prima_dice_para_cuantos_dias_de_alimento_alcanza(uow, bodega):
    _surtir(uow, bodega, maiz=20, soya=2, calcio=20)
    _en_uso(uow, bodega["uno"], bodega["mezcla"])
    _semana(uow, [400, 400])

    materia = _materia(uow)

    assert materia["Maíz"].consumo_diario_kg == 240
    assert materia["Maíz"].dias == 4.2
    assert materia["Soya"].consumo_diario_kg == 100
    assert materia["Soya"].dias == 0.8
    assert materia["Soya"].nivel == "critico"
    assert materia["Calcio"].dias == 8.3


def test_el_gasto_de_materia_prima_suma_todas_las_bodegas_que_usan_la_mezcla(uow, bodega):
    _surtir(uow, bodega, maiz=20, soya=20, calcio=20)
    _en_uso(uow, bodega["uno"], bodega["mezcla"])
    _en_uso(uow, bodega["dos"], bodega["mezcla"])
    _semana(uow, [400], galpon_id=1)
    _semana(uow, [200], galpon_id=2)

    assert _materia(uow)["Maíz"].consumo_diario_kg == 360


def test_la_mezcla_posible_nombra_lo_que_falta_primero(uow, bodega):
    _surtir(uow, bodega, maiz=20, soya=3, calcio=20)
    _preparar(uow, bodega, 400, destino="uno")
    _en_uso(uow, bodega["uno"], bodega["mezcla"])
    _semana(uow, [400])

    mezcla = inventario.estado_inventario(uow, HOY).mezclas[0]

    assert mezcla.stock_kg == 0
    assert mezcla.limitante == "Soya"
    assert mezcla.origen == "Bodega de materia prima"
    assert mezcla.kg_posibles == 80
    assert mezcla.dias == 0.2


def test_si_se_usa_alimento_comprado_la_materia_prima_no_se_gasta(uow, bodega):
    _comprar(uow, bodega["maiz"], bodega["materia"], 20)
    _comprar(uow, bodega["italcol"], bodega["uno"], 20)
    _en_uso(uow, bodega["uno"], bodega["italcol"])
    _semana(uow, [400])

    maiz = _materia(uow)["Maíz"]

    assert maiz.consumo_diario_kg is None
    assert maiz.dias is None


def test_reenviar_la_misma_compra_no_la_duplica(uow, bodega):
    operacion = uuid.uuid4()
    primera = inventario.registrar_compra(uow, QUIEN, bodega["maiz"], bodega["materia"], HOY, 2, None, operacion)
    repetida = inventario.registrar_compra(uow, QUIEN, bodega["maiz"], bodega["materia"], HOY, 2, None, operacion)

    assert repetida.id == primera.id
    assert _stock(uow, bodega["materia"], bodega["maiz"]) == 100


def test_dos_compras_con_distinta_operacion_si_suman(uow, bodega):
    inventario.registrar_compra(uow, QUIEN, bodega["maiz"], bodega["materia"], HOY, 1, None, uuid.uuid4())
    inventario.registrar_compra(uow, QUIEN, bodega["maiz"], bodega["materia"], HOY, 1, None, uuid.uuid4())

    assert _stock(uow, bodega["materia"], bodega["maiz"]) == 100


def test_reenviar_la_misma_preparacion_no_gasta_dos_veces(uow, bodega):
    _surtir(uow, bodega)
    operacion = uuid.uuid4()
    args = (uow, QUIEN, bodega["mezcla"], bodega["materia"], bodega["dos"], HOY, 500)

    primera = inventario.preparar_alimento(*args, operacion)
    repetida = inventario.preparar_alimento(*args, operacion)

    assert repetida.id == primera.id
    assert repetida.motivo == Motivo.PREPARACION
    assert _stock(uow, bodega["dos"], bodega["mezcla"]) == 500
    assert _stock(uow, bodega["materia"], bodega["maiz"]) == 200


def test_una_preparacion_repetida_responde_bien_aunque_ya_no_alcance_la_materia_prima(uow, bodega):
    _surtir(uow, bodega, maiz=1, soya=1, calcio=1)
    operacion = uuid.uuid4()
    args = (uow, QUIEN, bodega["mezcla"], bodega["materia"], bodega["dos"], HOY, 80)
    inventario.preparar_alimento(*args, operacion)

    repetida = inventario.preparar_alimento(*args, operacion)

    assert repetida.kg == 80
