"""Ventas y gastos de la granja. Funciones puras sobre movimientos de dinero."""

import uuid
from collections import defaultdict
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import date
from enum import StrEnum

from app.dominio.errores import DatosInvalidos


class TipoMovimiento(StrEnum):
    INGRESO = "ingreso"
    EGRESO = "egreso"


class Rubro(StrEnum):
    VENTA_HUEVO = "venta_huevo"
    VENTA_GALLINAS = "venta_gallinas"
    OTROS_INGRESOS = "otros_ingresos"
    ALIMENTO = "alimento"
    MATERIA_PRIMA = "materia_prima"
    VACUNAS_MEDICINAS = "vacunas_medicinas"
    POLLITAS = "pollitas"
    MANO_DE_OBRA = "mano_de_obra"
    SERVICIOS = "servicios"
    MANTENIMIENTO = "mantenimiento"
    OTROS_EGRESOS = "otros_egresos"


RUBROS_DE_INGRESO = (Rubro.VENTA_HUEVO, Rubro.VENTA_GALLINAS, Rubro.OTROS_INGRESOS)


def tipo_del_rubro(rubro: Rubro) -> TipoMovimiento:
    return TipoMovimiento.INGRESO if rubro in RUBROS_DE_INGRESO else TipoMovimiento.EGRESO


@dataclass
class CategoriaHuevo:
    nombre: str
    activa: bool = True
    orden: int = 0
    id: int | None = None


@dataclass
class MovimientoDinero:
    id: uuid.UUID
    fecha: date
    rubro: Rubro
    valor: float
    descripcion: str = ""
    lote_id: int | None = None
    categoria_id: int | None = None
    cantidad_huevos: int | None = None
    contraparte: str = ""
    usuario_id: int | None = None

    @property
    def tipo(self) -> TipoMovimiento:
        return tipo_del_rubro(self.rubro)


@dataclass(frozen=True)
class TotalRubro:
    rubro: Rubro
    total: float


@dataclass(frozen=True)
class VentaPorCategoria:
    categoria_id: int | None
    categoria: str
    huevos: int
    valor: float

    @property
    def precio_por_huevo(self) -> float | None:
        return round(self.valor / self.huevos, 1) if self.huevos else None


@dataclass(frozen=True)
class ResultadoLote:
    lote_id: int | None
    galpon: str
    ingresos: float
    egresos: float

    @property
    def utilidad(self) -> float:
        return self.ingresos - self.egresos


@dataclass(frozen=True)
class ResumenFinanzas:
    desde: date
    hasta: date
    ingresos: float
    egresos: float
    por_rubro: list[TotalRubro]
    huevos: list[VentaPorCategoria]
    por_lote: list[ResultadoLote]

    @property
    def utilidad(self) -> float:
        return self.ingresos - self.egresos


def validar_movimiento(movimiento: MovimientoDinero) -> None:
    if movimiento.valor <= 0:
        raise DatosInvalidos("el valor debe ser mayor que cero")
    hay_huevos = movimiento.cantidad_huevos is not None
    if movimiento.rubro == Rubro.VENTA_HUEVO:
        if not hay_huevos or movimiento.cantidad_huevos <= 0:
            raise DatosInvalidos("una venta de huevo necesita cuántos huevos se vendieron")
    elif hay_huevos or movimiento.categoria_id is not None:
        raise DatosInvalidos("solo la venta de huevo lleva cantidad y categoría de huevo")


def resumir(
    movimientos: Iterable[MovimientoDinero],
    desde: date,
    hasta: date,
    nombres_de_categoria: dict[int, str],
    galpon_del_lote: dict[int, str],
) -> ResumenFinanzas:
    ingresos = egresos = 0.0
    rubros: dict[Rubro, float] = defaultdict(float)
    huevos: dict[int | None, list[float]] = defaultdict(lambda: [0, 0.0])
    lotes: dict[int | None, list[float]] = defaultdict(lambda: [0.0, 0.0])
    for m in movimientos:
        rubros[m.rubro] += m.valor
        lote = lotes[m.lote_id]
        if m.tipo == TipoMovimiento.INGRESO:
            ingresos += m.valor
            lote[0] += m.valor
        else:
            egresos += m.valor
            lote[1] += m.valor
        if m.rubro == Rubro.VENTA_HUEVO:
            venta = huevos[m.categoria_id]
            venta[0] += m.cantidad_huevos or 0
            venta[1] += m.valor
    return ResumenFinanzas(
        desde=desde,
        hasta=hasta,
        ingresos=ingresos,
        egresos=egresos,
        por_rubro=[TotalRubro(r, t) for r, t in sorted(rubros.items(), key=lambda x: -x[1])],
        huevos=[
            VentaPorCategoria(c, nombres_de_categoria.get(c, "Sin categoría"), int(h), v)
            for c, (h, v) in sorted(huevos.items(), key=lambda x: -x[1][1])
        ],
        por_lote=[
            ResultadoLote(lote_id, galpon_del_lote.get(lote_id, "Sin asignar"), i, e)
            for lote_id, (i, e) in sorted(lotes.items(), key=lambda x: (x[0] is None, x[0] or 0))
        ],
    )
