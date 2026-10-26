"""Reglas de sanidad y crecimiento. Funciones puras: reciben datos y devuelven un veredicto."""

import uuid
from collections.abc import Iterable, Sequence
from dataclasses import dataclass, replace
from datetime import date
from enum import StrEnum

from app.dominio.errores import DatosInvalidos

SEMANAS_DE_AVISO = 2
PESO_ATENCION_PCT = -5.0
PESO_BAJO_PCT = -10.0
PESO_ALTO_PCT = 10.0
DIAS_SIN_PESAR = 8
MORTALIDAD_SEMANA_REVISAR_PCT = 0.5
MORTALIDAD_SEMANA_URGENTE_PCT = 1.0
SEMANAS_DE_POLLITAS = 6


class TipoTarea(StrEnum):
    VACUNA = "vacuna"
    DESPARASITACION = "desparasitacion"
    MANEJO = "manejo"


class EstadoTarea(StrEnum):
    APLICADA = "aplicada"
    ATRASADA = "atrasada"
    AHORA = "ahora"
    PROXIMA = "proxima"
    LEJANA = "lejana"
    PREVIA = "previa"


class NivelPeso(StrEnum):
    BIEN = "bien"
    ATENCION = "atencion"
    BAJO = "bajo"
    ALTO = "alto"


class Nivel(StrEnum):
    URGENTE = "urgente"
    REVISAR = "revisar"
    INFO = "info"


class TipoAlerta(StrEnum):
    VACUNA_ATRASADA = "vacuna_atrasada"
    VACUNA_AHORA = "vacuna_ahora"
    POLLITAS = "pollitas"
    BAJA_POSTURA = "baja_postura"
    PESO = "peso"
    SIN_PESAR = "sin_pesar"
    MORTALIDAD = "mortalidad"


@dataclass
class TareaPlan:
    linea_id: int
    nombre: str
    tipo: TipoTarea
    semana_ideal: int
    semana_max: int
    nota: str = ""
    activa: bool = True
    id: int | None = None


@dataclass
class Cumplimiento:
    id: uuid.UUID
    lote_id: int
    tarea_id: int
    fecha: date
    nota: str = ""
    usuario_id: int | None = None


@dataclass
class Pesaje:
    id: uuid.UUID
    lote_id: int
    fecha: date
    peso_g: float
    aves_pesadas: int


@dataclass(frozen=True)
class PuntoCurva:
    semana: int
    postura_pct: float
    peso_g: float | None = None


@dataclass(frozen=True)
class TareaDelLote:
    tarea: TareaPlan
    estado: EstadoTarea
    aplicada_en: date | None = None
    nota: str = ""
    cumplimiento_id: uuid.UUID | None = None


@dataclass(frozen=True)
class ComparacionPeso:
    fecha: date
    peso_g: float
    estandar_g: float
    diferencia_pct: float
    nivel: NivelPeso


@dataclass(frozen=True)
class ComparacionPostura:
    fecha: date
    real_pct: float
    estandar_pct: float


@dataclass(frozen=True)
class Alerta:
    galpon_id: int
    galpon: str
    lote_id: int
    tipo: TipoAlerta
    nivel: Nivel
    titulo: str
    detalle: str
    recomendaciones: tuple[str, ...] = ()


RECOMENDACIONES = {
    TipoAlerta.BAJA_POSTURA: (
        "Revisar que haya agua limpia y suficiente en todo el galpón.",
        "Mirar si comieron menos en los últimos días.",
        "Buscar calor o frío fuerte, o cambios bruscos de temperatura.",
        "Las horas de luz no deben reducirse cuando las aves están en postura.",
        "Pensar en lo que pudo estresarlas: ruidos, animales, cambio de alimento o una vacunación reciente.",
        "Ver si hay aves decaídas, con diarrea, estornudos o cresta pálida. Si las hay, avisar al veterinario.",
        "Revisar el alimento: que tenga calcio suficiente y que no esté húmedo ni con hongos.",
    ),
    TipoAlerta.MORTALIDAD: (
        "Retirar las aves muertas y anotar cuántas son cada día.",
        "Buscar diarrea, estornudos, plumas erizadas o cresta pálida o azulada.",
        "Revisar el agua, el calor y la ventilación.",
        "Si sigue subiendo, llamar al veterinario y guardar aves recién muertas por si hace falta una necropsia.",
    ),
    TipoAlerta.VACUNA_ATRASADA: (
        "Aplicarla lo antes posible. Si pasó mucho tiempo, preguntar al veterinario cómo seguir.",
        "No vacunar aves enfermas sin consultar antes.",
        "Marcarla en la app cuando se aplique para que se quite la alerta.",
    ),
    TipoAlerta.VACUNA_AHORA: (
        "Tener la vacuna refrigerada y revisar que no esté vencida.",
        "Vacunar en las horas frescas del día.",
        "Marcarla en la app cuando se aplique.",
    ),
    TipoAlerta.POLLITAS: (
        "El calor se nota en cómo se mueven: si se amontonan tienen frío, si se alejan jadeando tienen calor.",
        "Agua y alimento siempre al alcance, y cama seca.",
        "Revisar cada día que todas coman y anotar la mortalidad.",
    ),
    TipoAlerta.SIN_PESAR: ("Pesar una muestra de aves al azar, a la misma hora, y anotar el promedio.",),
}

RECOMENDACIONES_PESO = {
    NivelPeso.BAJO: (
        "Revisar que todas alcancen comedero y bebedero, sin exceso de aves.",
        "Comprobar que el alimento sea el de la etapa y que no falte.",
        "Pesar una muestra más grande para confirmar. Si hay mucha diferencia entre aves, consultar al veterinario.",
    ),
    NivelPeso.ATENCION: (
        "Revisar el consumo de alimento y que todas alcancen comedero y bebedero.",
        "Volver a pesar en una semana para ver si se recuperan.",
    ),
    NivelPeso.ALTO: (
        "Revisar que no se esté dando más alimento del que corresponde.",
        "Volver a pesar en una semana para confirmar.",
    ),
}


def validar_tarea(tarea: TareaPlan) -> None:
    if not tarea.nombre.strip():
        raise DatosInvalidos("cada tarea necesita un nombre")
    if tarea.semana_ideal < 0 or tarea.semana_max < tarea.semana_ideal:
        raise DatosInvalidos(f"{tarea.nombre}: la semana máxima no puede ser menor que la ideal")


def validar_curva(puntos: Iterable[PuntoCurva]) -> None:
    vistas: set[int] = set()
    for p in puntos:
        if p.semana < 0 or p.semana in vistas:
            raise DatosInvalidos(f"la semana {p.semana} está repetida o es inválida")
        if not 0 <= p.postura_pct <= 100:
            raise DatosInvalidos(f"semana {p.semana}: la postura debe estar entre 0 y 100")
        if p.peso_g is not None and p.peso_g <= 0:
            raise DatosInvalidos(f"semana {p.semana}: el peso debe ser mayor que cero")
        vistas.add(p.semana)


def punto_en(curva: Sequence[PuntoCurva], semana: int) -> PuntoCurva | None:
    anteriores = [p for p in curva if p.semana <= semana]
    return max(anteriores, key=lambda p: p.semana) if anteriores else None


def estado_tarea(tarea: TareaPlan, edad_semanas: int, semana_de_ingreso: int, cumplida: bool) -> EstadoTarea:
    if cumplida:
        return EstadoTarea.APLICADA
    if tarea.semana_max < semana_de_ingreso:
        return EstadoTarea.PREVIA
    if edad_semanas > tarea.semana_max:
        return EstadoTarea.ATRASADA
    if edad_semanas >= tarea.semana_ideal:
        return EstadoTarea.AHORA
    if tarea.semana_ideal - edad_semanas <= SEMANAS_DE_AVISO:
        return EstadoTarea.PROXIMA
    return EstadoTarea.LEJANA


def tareas_del_lote(
    plan: Iterable[TareaPlan],
    cumplimientos: Iterable[Cumplimiento],
    edad_semanas: int,
    semana_de_ingreso: int,
) -> list[TareaDelLote]:
    hechas = {c.tarea_id: c for c in cumplimientos}
    resultado = []
    for tarea in plan:
        hecha = hechas.get(tarea.id)
        if not tarea.activa and hecha is None:
            continue
        estado = estado_tarea(tarea, edad_semanas, semana_de_ingreso, hecha is not None)
        resultado.append(
            TareaDelLote(
                tarea=tarea,
                estado=estado,
                aplicada_en=hecha.fecha if hecha else None,
                nota=hecha.nota if hecha else "",
                cumplimiento_id=hecha.id if hecha else None,
            )
        )
    return sorted(resultado, key=lambda t: (t.tarea.semana_ideal, t.tarea.semana_max, t.tarea.nombre))


def evaluar_peso(real_g: float, estandar_g: float) -> tuple[float, NivelPeso]:
    diferencia = round((real_g - estandar_g) / estandar_g * 100, 1)
    if diferencia < PESO_BAJO_PCT:
        return diferencia, NivelPeso.BAJO
    if diferencia < PESO_ATENCION_PCT:
        return diferencia, NivelPeso.ATENCION
    if diferencia > PESO_ALTO_PCT:
        return diferencia, NivelPeso.ALTO
    return diferencia, NivelPeso.BIEN


def comparar_peso(pesaje: Pesaje, curva: Sequence[PuntoCurva], semana: int) -> ComparacionPeso | None:
    punto = punto_en([p for p in curva if p.peso_g is not None], semana)
    if punto is None or punto.peso_g is None:
        return None
    diferencia, nivel = evaluar_peso(pesaje.peso_g, punto.peso_g)
    return ComparacionPeso(pesaje.fecha, pesaje.peso_g, punto.peso_g, diferencia, nivel)


def mortalidad_semanal_pct(muertas_7_dias: int, aves_vivas: int) -> float:
    if aves_vivas <= 0:
        return 0.0
    return round(muertas_7_dias / aves_vivas * 100, 2)


@dataclass(frozen=True)
class SanidadGalpon:
    galpon_id: int
    galpon: str
    lote_id: int
    linea: str
    edad_semanas: int
    etapa: str
    aves_vivas: int
    tareas: list[TareaDelLote]
    pesajes: list[Pesaje]
    peso: ComparacionPeso | None
    postura: ComparacionPostura | None


@dataclass(frozen=True)
class Panorama:
    fecha: date
    alertas: list[Alerta]
    galpones: list[SanidadGalpon]


def _donde(galpon_id: int, galpon: str, lote_id: int) -> dict:
    return {"galpon_id": galpon_id, "galpon": galpon, "lote_id": lote_id}


def _alertas_de_tareas(donde: dict, tareas: Iterable[TareaDelLote], edad: int) -> list[Alerta]:
    alertas = []
    for t in tareas:
        nombre, ideal, maximo = t.tarea.nombre, t.tarea.semana_ideal, t.tarea.semana_max
        if t.estado == EstadoTarea.ATRASADA:
            detalle = f"Debía aplicarse como máximo en la semana {maximo}. El lote tiene {edad} semanas."
            alertas.append(
                Alerta(
                    **donde,
                    tipo=TipoAlerta.VACUNA_ATRASADA,
                    nivel=Nivel.URGENTE,
                    titulo=f"{nombre}: atrasada",
                    detalle=detalle,
                )
            )
        elif t.estado == EstadoTarea.AHORA:
            cuando = f"en la semana {ideal}" if ideal == maximo else f"entre la semana {ideal} y la {maximo}"
            ultima = " Esta es la última semana." if edad == maximo else ""
            detalle = f"Se aplica {cuando}. El lote tiene {edad} semanas.{ultima}"
            alertas.append(
                Alerta(
                    **donde,
                    tipo=TipoAlerta.VACUNA_AHORA,
                    nivel=Nivel.REVISAR,
                    titulo=f"Toca: {nombre}",
                    detalle=detalle,
                )
            )
    return alertas


def alertas_del_lote(
    galpon_id: int,
    galpon: str,
    lote_id: int,
    edad: int,
    tareas: Sequence[TareaDelLote],
    peso: ComparacionPeso | None,
    dias_sin_pesar: int | None,
    baja_postura_hoy: ComparacionPostura | None,
    dias_bajos: int,
    muertas_7_dias: int,
    aves_vivas: int,
) -> list[Alerta]:
    donde = _donde(galpon_id, galpon, lote_id)
    alertas = _alertas_de_tareas(donde, tareas, edad)
    if edad < SEMANAS_DE_POLLITAS:
        detalle = f"Tiene {edad} semanas. Cuidar el calor, el agua y el alimento, y revisar la mortalidad cada día."
        alertas.append(
            Alerta(**donde, tipo=TipoAlerta.POLLITAS, nivel=Nivel.INFO, titulo="Pollitas delicadas", detalle=detalle)
        )
    if baja_postura_hoy is not None:
        detalle = (
            f"Lleva {dias_bajos} días por debajo de lo esperado para su raza: "
            f"{baja_postura_hoy.real_pct}% y lo esperado es {baja_postura_hoy.estandar_pct}%."
        )
        alertas.append(
            Alerta(**donde, tipo=TipoAlerta.BAJA_POSTURA, nivel=Nivel.URGENTE, titulo="Baja postura", detalle=detalle)
        )
    if peso is not None and peso.nivel != NivelPeso.BIEN:
        titulo, nivel = {
            NivelPeso.BAJO: ("Peso bajo", Nivel.URGENTE),
            NivelPeso.ATENCION: ("Peso algo bajo", Nivel.REVISAR),
            NivelPeso.ALTO: ("Peso por encima de lo esperado", Nivel.REVISAR),
        }[peso.nivel]
        detalle = f"Pesan {peso.peso_g:g} g y lo esperado es {peso.estandar_g:g} g ({peso.diferencia_pct:+g}%)."
        alertas.append(Alerta(**donde, tipo=TipoAlerta.PESO, nivel=nivel, titulo=titulo, detalle=detalle))
    if edad < 18 and (dias_sin_pesar is None or dias_sin_pesar >= DIAS_SIN_PESAR):
        detalle = (
            "Todavía no hay pesajes de este lote."
            if dias_sin_pesar is None
            else f"El último pesaje fue hace {dias_sin_pesar} días."
        )
        alertas.append(
            Alerta(**donde, tipo=TipoAlerta.SIN_PESAR, nivel=Nivel.REVISAR, titulo="Toca pesar", detalle=detalle)
        )
    pct = mortalidad_semanal_pct(muertas_7_dias, aves_vivas)
    if pct >= MORTALIDAD_SEMANA_REVISAR_PCT:
        nivel = Nivel.URGENTE if pct >= MORTALIDAD_SEMANA_URGENTE_PCT else Nivel.REVISAR
        detalle = f"Murieron {muertas_7_dias} aves en los últimos 7 días ({pct}%)."
        alertas.append(
            Alerta(**donde, tipo=TipoAlerta.MORTALIDAD, nivel=nivel, titulo="Mortalidad alta", detalle=detalle)
        )
    return [replace(a, recomendaciones=_recomendaciones(a, peso)) for a in alertas]


def _recomendaciones(alerta: Alerta, peso: ComparacionPeso | None) -> tuple[str, ...]:
    if alerta.tipo == TipoAlerta.PESO and peso is not None:
        return RECOMENDACIONES_PESO[peso.nivel]
    return RECOMENDACIONES.get(alerta.tipo, ())


def ordenar_alertas(alertas: Iterable[Alerta]) -> list[Alerta]:
    orden = {Nivel.URGENTE: 0, Nivel.REVISAR: 1, Nivel.INFO: 2}
    return sorted(alertas, key=lambda a: (orden[a.nivel], a.galpon, a.titulo))
