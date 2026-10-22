"""Cálculos de producción. Funciones puras, sin base de datos, para probarlas fácil."""

from collections.abc import Sequence
from dataclasses import dataclass
from datetime import date

from app.dominio.modelos import Etapa, Galpon, Lote, ResumenGalpon

SEMANA_INICIO_LEVANTE = 6
SEMANA_INICIO_PRODUCCION = 18


def edad_semanas(fecha_nacimiento: date, fecha: date) -> int:
    if fecha < fecha_nacimiento:
        raise ValueError("la fecha es anterior al nacimiento del lote")
    return (fecha - fecha_nacimiento).days // 7


def etapa(
    fecha_nacimiento: date,
    fecha: date,
    inicio_levante: int = SEMANA_INICIO_LEVANTE,
    inicio_produccion: int = SEMANA_INICIO_PRODUCCION,
) -> Etapa:
    semanas = edad_semanas(fecha_nacimiento, fecha)
    if semanas < inicio_levante:
        return Etapa.CRIA
    if semanas < inicio_produccion:
        return Etapa.LEVANTE
    return Etapa.PRODUCCION


def aves_vivas(aves_iniciales: int, mortalidad_acumulada: int) -> int:
    return max(aves_iniciales - mortalidad_acumulada, 0)


def porcentaje(parte: int, total: int) -> float:
    if total <= 0:
        return 0.0
    return round(parte / total * 100, 1)


def postura_pct(huevos: int, aves: int) -> float:
    return porcentaje(huevos, aves)


def ocupacion_pct(aves: int, capacidad: int) -> float:
    return porcentaje(aves, capacidad)


def resumir_galpon(
    galpon: Galpon,
    lote: Lote | None,
    mortalidad_acumulada: int,
    huevos_del_dia: int | None,
    fecha: date,
    linea: str | None = None,
) -> ResumenGalpon:
    if lote is None:
        return ResumenGalpon(
            galpon_id=galpon.id,
            nombre=galpon.nombre,
            capacidad_aves=galpon.capacidad_aves,
            lote_id=None,
            etapa=None,
            edad_semanas=None,
            aves_vivas=0,
            ocupacion_pct=0.0,
            postura_pct=None,
        )
    vivas = aves_vivas(lote.aves_iniciales, mortalidad_acumulada)
    return ResumenGalpon(
        galpon_id=galpon.id,
        nombre=galpon.nombre,
        capacidad_aves=galpon.capacidad_aves,
        lote_id=lote.id,
        etapa=etapa(lote.fecha_nacimiento, fecha),
        edad_semanas=edad_semanas(lote.fecha_nacimiento, fecha),
        aves_vivas=vivas,
        ocupacion_pct=ocupacion_pct(vivas, galpon.capacidad_aves),
        postura_pct=postura_pct(huevos_del_dia, vivas) if huevos_del_dia is not None else None,
        linea=linea,
        huevos_del_dia=huevos_del_dia,
    )


@dataclass(frozen=True)
class DiaPostura:
    fecha: date
    real_pct: float
    estandar_pct: float


def baja_postura(dias: Sequence[DiaPostura], umbral_puntos: float = 5.0, dias_seguidos: int = 3) -> bool:
    """True si los últimos `dias_seguidos` días están por debajo del estándar en más del umbral."""
    if len(dias) < dias_seguidos:
        return False
    ultimos = sorted(dias, key=lambda d: d.fecha)[-dias_seguidos:]
    return all(d.estandar_pct - d.real_pct > umbral_puntos for d in ultimos)
