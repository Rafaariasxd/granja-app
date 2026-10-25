import uuid
from datetime import date

import pytest

from app.dominio import plantillas
from app.dominio.errores import DatosInvalidos
from app.dominio.sanidad import (
    ComparacionPeso,
    ComparacionPostura,
    Cumplimiento,
    EstadoTarea,
    Nivel,
    NivelPeso,
    Pesaje,
    PuntoCurva,
    TareaPlan,
    TipoAlerta,
    TipoTarea,
    alertas_del_lote,
    comparar_peso,
    estado_tarea,
    evaluar_peso,
    mortalidad_semanal_pct,
    ordenar_alertas,
    punto_en,
    tareas_del_lote,
    validar_curva,
    validar_tarea,
)

GUMBORO = TareaPlan(1, "Gumboro", TipoTarea.VACUNA, semana_ideal=2, semana_max=3, id=10)


@pytest.mark.parametrize(
    ("edad", "esperado"),
    [
        (0, EstadoTarea.PROXIMA),
        (1, EstadoTarea.PROXIMA),
        (2, EstadoTarea.AHORA),
        (3, EstadoTarea.AHORA),
        (4, EstadoTarea.ATRASADA),
    ],
)
def test_estado_de_una_tarea_segun_la_edad(edad, esperado):
    assert estado_tarea(GUMBORO, edad, 0, cumplida=False) == esperado


def test_una_tarea_muy_lejana_no_avisa_todavia():
    lejana = TareaPlan(1, "Viruela", TipoTarea.VACUNA, 8, 10, id=11)
    assert estado_tarea(lejana, 4, 0, cumplida=False) == EstadoTarea.LEJANA
    assert estado_tarea(lejana, 6, 0, cumplida=False) == EstadoTarea.PROXIMA


def test_una_tarea_aplicada_no_se_atrasa():
    assert estado_tarea(GUMBORO, 30, 0, cumplida=True) == EstadoTarea.APLICADA


def test_lo_anterior_al_ingreso_se_da_por_hecho_por_el_proveedor():
    assert estado_tarea(GUMBORO, 20, 16, cumplida=False) == EstadoTarea.PREVIA
    assert estado_tarea(GUMBORO, 20, 3, cumplida=False) == EstadoTarea.ATRASADA


def test_tareas_del_lote_marca_las_aplicadas_y_oculta_las_desactivadas():
    apagada = TareaPlan(1, "Vieja", TipoTarea.VACUNA, 1, 1, activa=False, id=12)
    aplicada_apagada = TareaPlan(1, "Aplicada y retirada", TipoTarea.VACUNA, 1, 1, activa=False, id=13)
    cumplimientos = [
        Cumplimiento(uuid.uuid4(), 1, 10, date(2026, 3, 20), "sin novedad"),
        Cumplimiento(uuid.uuid4(), 1, 13, date(2026, 3, 8)),
    ]
    resultado = tareas_del_lote([GUMBORO, apagada, aplicada_apagada], cumplimientos, 3, 0)
    assert [(t.tarea.nombre, t.estado) for t in resultado] == [
        ("Aplicada y retirada", EstadoTarea.APLICADA),
        ("Gumboro", EstadoTarea.APLICADA),
    ]
    assert resultado[1].aplicada_en == date(2026, 3, 20)
    assert resultado[1].nota == "sin novedad"


def test_las_tareas_salen_ordenadas_por_semana():
    a = TareaPlan(1, "B", TipoTarea.VACUNA, 5, 6, id=1)
    b = TareaPlan(1, "A", TipoTarea.VACUNA, 1, 2, id=2)
    assert [t.tarea.nombre for t in tareas_del_lote([a, b], [], 0, 0)] == ["A", "B"]


@pytest.mark.parametrize(
    ("real", "nivel"),
    [
        (1000, NivelPeso.BIEN),
        (960, NivelPeso.BIEN),
        (940, NivelPeso.ATENCION),
        (890, NivelPeso.BAJO),
        (1090, NivelPeso.BIEN),
        (1120, NivelPeso.ALTO),
    ],
)
def test_peso_contra_lo_esperado(real, nivel):
    assert evaluar_peso(real, 1000)[1] == nivel


def test_comparar_peso_usa_el_valor_de_la_semana_o_el_anterior():
    curva = [PuntoCurva(10, 0, 850), PuntoCurva(12, 0, 1010)]
    pesaje = Pesaje(uuid.uuid4(), 1, date(2026, 5, 1), 900, 30)
    comparacion = comparar_peso(pesaje, curva, 11)
    assert (comparacion.estandar_g, comparacion.diferencia_pct, comparacion.nivel) == (850, 5.9, NivelPeso.BIEN)
    assert comparar_peso(pesaje, curva, 5) is None
    assert comparar_peso(pesaje, [PuntoCurva(10, 90)], 11) is None


def test_punto_en_devuelve_el_ultimo_conocido():
    curva = [PuntoCurva(18, 6), PuntoCurva(30, 95)]
    assert punto_en(curva, 17) is None
    assert punto_en(curva, 25).semana == 18
    assert punto_en(curva, 99).semana == 30


def test_validaciones_de_tareas_y_curvas():
    with pytest.raises(DatosInvalidos, match="máxima"):
        validar_tarea(TareaPlan(1, "X", TipoTarea.VACUNA, 5, 4))
    with pytest.raises(DatosInvalidos, match="nombre"):
        validar_tarea(TareaPlan(1, " ", TipoTarea.VACUNA, 1, 2))
    with pytest.raises(DatosInvalidos, match="repetida"):
        validar_curva([PuntoCurva(1, 0), PuntoCurva(1, 0)])
    with pytest.raises(DatosInvalidos, match="entre 0 y 100"):
        validar_curva([PuntoCurva(20, 101)])
    with pytest.raises(DatosInvalidos, match="peso"):
        validar_curva([PuntoCurva(20, 50, 0)])
    validar_curva([PuntoCurva(20, 50, 1500), PuntoCurva(21, 60)])


def test_mortalidad_semanal():
    assert mortalidad_semanal_pct(10, 2000) == 0.5
    assert mortalidad_semanal_pct(5, 0) == 0.0


def _alertas(**cambios):
    datos = dict(
        galpon_id=1,
        galpon="Galpón 1",
        lote_id=1,
        edad=30,
        tareas=[],
        peso=None,
        dias_sin_pesar=2,
        baja_postura_hoy=None,
        dias_bajos=0,
        muertas_7_dias=0,
        aves_vivas=2000,
    )
    datos.update(cambios)
    return alertas_del_lote(**datos)


def test_un_lote_sano_no_genera_alertas():
    assert _alertas() == []


def test_vacuna_atrasada_es_urgente_y_la_de_ahora_es_para_revisar():
    atrasada = tareas_del_lote([GUMBORO], [], 5, 0)
    alerta = _alertas(edad=5, tareas=atrasada)[0]
    assert (alerta.tipo, alerta.nivel, alerta.titulo) == (
        TipoAlerta.VACUNA_ATRASADA,
        Nivel.URGENTE,
        "Gumboro: atrasada",
    )
    assert "semana 3" in alerta.detalle

    ahora = tareas_del_lote([GUMBORO], [], 3, 0)
    alerta = _alertas(edad=3, tareas=ahora)[0]
    assert (alerta.tipo, alerta.nivel, alerta.titulo) == (TipoAlerta.VACUNA_AHORA, Nivel.REVISAR, "Toca: Gumboro")
    assert "entre la semana 2 y la 3" in alerta.detalle
    assert "última semana" in alerta.detalle
    assert "última semana" not in _alertas(edad=2, tareas=tareas_del_lote([GUMBORO], [], 2, 0))[0].detalle


def test_las_pollitas_pequenas_siempre_avisan_que_son_delicadas():
    alerta = _alertas(edad=3, dias_sin_pesar=1)[0]
    assert (alerta.tipo, alerta.nivel) == (TipoAlerta.POLLITAS, Nivel.INFO)
    assert not [a for a in _alertas(edad=7) if a.tipo == TipoAlerta.POLLITAS]


def test_baja_postura_peso_y_mortalidad():
    postura = ComparacionPostura(date(2026, 10, 15), 80.0, 94.0)
    assert _alertas(baja_postura_hoy=postura, dias_bajos=3)[0].tipo == TipoAlerta.BAJA_POSTURA

    bajo = ComparacionPeso(date(2026, 10, 1), 1100, 1300, -15.4, NivelPeso.BAJO)
    assert (_alertas(edad=15, peso=bajo)[0].tipo, _alertas(edad=15, peso=bajo)[0].nivel) == (
        TipoAlerta.PESO,
        Nivel.URGENTE,
    )
    algo = ComparacionPeso(date(2026, 10, 1), 1200, 1300, -7.7, NivelPeso.ATENCION)
    assert _alertas(edad=15, peso=algo)[0].nivel == Nivel.REVISAR
    bien = ComparacionPeso(date(2026, 10, 1), 1300, 1300, 0.0, NivelPeso.BIEN)
    assert _alertas(edad=15, peso=bien) == []

    assert _alertas(muertas_7_dias=10)[0].nivel == Nivel.REVISAR
    assert _alertas(muertas_7_dias=20)[0].nivel == Nivel.URGENTE
    assert _alertas(muertas_7_dias=9) == []


def test_las_aves_que_aun_crecen_piden_pesaje_cada_semana():
    sin_pesajes = [a for a in _alertas(edad=10, dias_sin_pesar=None) if a.tipo == TipoAlerta.SIN_PESAR]
    assert sin_pesajes[0].detalle == "Todavía no hay pesajes de este lote."
    viejo = [a for a in _alertas(edad=10, dias_sin_pesar=9) if a.tipo == TipoAlerta.SIN_PESAR]
    assert "hace 9 días" in viejo[0].detalle
    assert not [a for a in _alertas(edad=10, dias_sin_pesar=7) if a.tipo == TipoAlerta.SIN_PESAR]
    assert not [a for a in _alertas(edad=25, dias_sin_pesar=None) if a.tipo == TipoAlerta.SIN_PESAR]


def test_las_alertas_se_ordenan_de_urgente_a_informativa():
    todas = _alertas(edad=3, dias_sin_pesar=None, muertas_7_dias=30)
    niveles = [a.nivel for a in ordenar_alertas(reversed(todas))]
    assert niveles == sorted(niveles, key=[Nivel.URGENTE, Nivel.REVISAR, Nivel.INFO].index)


def test_las_plantillas_traen_curvas_completas_y_un_plan_ordenado():
    for nombre, curva in plantillas.PLANTILLAS.items():
        validar_curva(curva)
        assert [p.semana for p in curva] == list(range(1, 81)), nombre
        pesos = [p.peso_g for p in curva]
        assert pesos == sorted(pesos), nombre
        assert max(p.postura_pct for p in curva) == 95
        assert all(p.postura_pct == 0 for p in curva if p.semana < 18)
    for nombre, tipo, ideal, maximo, _ in plantillas.PLAN_PONEDORAS:
        validar_tarea(TareaPlan(1, nombre, tipo, ideal, maximo))


def test_cada_alerta_trae_que_revisar_y_el_peso_depende_de_si_es_bajo_o_alto():
    postura = ComparacionPostura(date(2026, 10, 15), 80.0, 94.0)
    baja = _alertas(baja_postura_hoy=postura, dias_bajos=3)[0]
    assert any("agua" in r for r in baja.recomendaciones)
    assert any("veterinario" in r for r in baja.recomendaciones)
    assert _alertas(muertas_7_dias=20)[0].recomendaciones
    pollitas = _alertas(edad=3, dias_sin_pesar=1)[0]
    assert pollitas.recomendaciones
    bajo = ComparacionPeso(date(2026, 10, 1), 1100, 1300, -15.4, NivelPeso.BAJO)
    alto = ComparacionPeso(date(2026, 10, 1), 1500, 1300, 15.4, NivelPeso.ALTO)
    de_bajo = _alertas(edad=15, peso=bajo)[0].recomendaciones
    de_alto = _alertas(edad=15, peso=alto)[0].recomendaciones
    assert de_bajo != de_alto
    assert all(a.recomendaciones for a in _alertas(edad=5, tareas=tareas_del_lote([GUMBORO], [], 5, 0)))
