"""Bodega del huevo: se cuenta en huevos y se muestra en cajas y cartones."""

import uuid
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from datetime import date
from enum import StrEnum

from app.dominio.errores import DatosInvalidos

HUEVOS_POR_CARTON = 30
CARTONES_POR_CAJA = 12
HUEVOS_POR_CAJA = HUEVOS_POR_CARTON * CARTONES_POR_CAJA

NAMESPACE_VENTAS = uuid.UUID("6f1d9c0e-2b7a-4c53-9a1e-3d5b8f4a7c21")


class MotivoHuevo(StrEnum):
    INGRESO = "ingreso"
    SALIDA = "salida"
    REINGRESO = "reingreso"
    BAJA = "baja"
    AJUSTE = "ajuste"


class TipoVenta(StrEnum):
    CLIENTE = "cliente"
    PARTICULAR = "particular"
    MAYORISTA = "mayorista"


class EstadoSalida(StrEnum):
    ABIERTA = "abierta"
    CERRADA = "cerrada"
    ANULADA = "anulada"


@dataclass(frozen=True)
class Empaque:
    cajas: int
    cartones: int
    sueltos: int


def a_huevos(cajas: int = 0, cartones: int = 0, huevos: int = 0) -> int:
    if min(cajas, cartones, huevos) < 0:
        raise DatosInvalidos("las cantidades no pueden ser negativas")
    return cajas * HUEVOS_POR_CAJA + cartones * HUEVOS_POR_CARTON + huevos


def empacar(huevos: int) -> Empaque:
    """26 cartones son 2 cajas y 2 cartones. Lo que no completa un cartón queda como sueltos."""
    signo = -1 if huevos < 0 else 1
    resto = abs(huevos)
    cajas, resto = divmod(resto, HUEVOS_POR_CAJA)
    cartones, sueltos = divmod(resto, HUEVOS_POR_CARTON)
    return Empaque(signo * cajas, signo * cartones, signo * sueltos)


@dataclass
class MovimientoHuevo:
    fecha: date
    categoria_id: int
    huevos: int
    motivo: MotivoHuevo
    usuario_id: int | None = None
    nota: str = ""
    salida_id: uuid.UUID | None = None
    operacion_id: uuid.UUID | None = None
    id: int | None = None


@dataclass
class PrecioHuevo:
    categoria_id: int
    precio_caja: float | None = None
    precio_carton: float | None = None
    precio_mayorista: float | None = None


@dataclass
class LineaSalida:
    categoria_id: int
    huevos_sacados: int
    huevos_vendidos: int | None = None
    valor: float | None = None


@dataclass
class SalidaHuevo:
    id: uuid.UUID
    fecha: date
    tipo_venta: TipoVenta
    lineas: list[LineaSalida]
    cliente: str = ""
    estado: EstadoSalida = EstadoSalida.ABIERTA
    usuario_id: int | None = None
    cerrada_el: date | None = None
    valor_total: float | None = None


@dataclass(frozen=True)
class ExistenciaHuevo:
    categoria_id: int
    categoria: str
    activa: bool
    huevos: int

    @property
    def empaque(self) -> Empaque:
        return empacar(self.huevos)


def validar_precio(precio: PrecioHuevo) -> None:
    for valor in (precio.precio_caja, precio.precio_carton, precio.precio_mayorista):
        if valor is not None and valor <= 0:
            raise DatosInvalidos("los precios deben ser mayores que cero")


def precio_de_los_huevos(huevos: int, tipo: TipoVenta, precio: PrecioHuevo | None) -> float | None:
    """Cliente y mayorista pagan el precio de la caja dividido en sus cartones; el particular paga por cartón."""
    if precio is None or huevos <= 0:
        return None
    if tipo == TipoVenta.PARTICULAR:
        base = precio.precio_carton
        return None if base is None else round(base * huevos / HUEVOS_POR_CARTON, 2)
    base = precio.precio_mayorista if tipo == TipoVenta.MAYORISTA else precio.precio_caja
    return None if base is None else round(base * huevos / HUEVOS_POR_CAJA, 2)


def validar_lineas(lineas: Sequence[LineaSalida]) -> None:
    if not lineas:
        raise DatosInvalidos("indica qué huevos salen")
    vistas: set[int] = set()
    for linea in lineas:
        if linea.huevos_sacados <= 0:
            raise DatosInvalidos("cada categoría debe llevar al menos un huevo")
        if linea.categoria_id in vistas:
            raise DatosInvalidos("una categoría no puede repetirse en la misma salida")
        vistas.add(linea.categoria_id)


def repartir_total(
    vendidos: Mapping[int, int], sugeridos: Mapping[int, float | None], total: float | None
) -> dict[int, float]:
    """Valor de cada categoría. Con un total cobrado se reparte en proporción a lo sugerido (o a los huevos)."""
    if total is None:
        faltan = [c for c, v in sugeridos.items() if v is None and vendidos[c] > 0]
        if faltan:
            raise DatosInvalidos("falta el precio de alguna categoría: escribe el total cobrado")
        return {c: float(v or 0) for c, v in sugeridos.items()}
    if total <= 0:
        raise DatosInvalidos("el total cobrado debe ser mayor que cero")
    pesos = {c: (sugeridos[c] if sugeridos.get(c) is not None else float(vendidos[c])) for c in vendidos}
    suma = sum(pesos.values())
    categorias = [c for c in vendidos if vendidos[c] > 0]
    if suma <= 0 or not categorias:
        raise DatosInvalidos("no hay huevos vendidos a los que repartir el total")
    reparto = {c: round(total * pesos[c] / suma, 2) for c in categorias}
    ultima = categorias[-1]
    reparto[ultima] = round(total - sum(v for c, v in reparto.items() if c != ultima), 2)
    return reparto


def id_de_venta(salida_id: uuid.UUID, categoria_id: int) -> uuid.UUID:
    return uuid.uuid5(NAMESPACE_VENTAS, f"{salida_id}:{categoria_id}")
