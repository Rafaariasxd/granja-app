from collections.abc import Iterable
from datetime import date

from app.dominio.errores import Conflicto, DatosInvalidos
from app.dominio.fechas import periodos_se_cruzan
from app.dominio.modelos import Galpon, Lote


def activo_en(lotes: Iterable[Lote], fecha: date) -> Lote | None:
    for lote in lotes:
        if lote.fecha_ingreso <= fecha and (lote.fecha_salida is None or lote.fecha_salida >= fecha):
            return lote
    return None


def validar_ingreso(lote: Lote, galpon: Galpon, lotes_del_galpon: Iterable[Lote]) -> None:
    if lote.fecha_ingreso < lote.fecha_nacimiento:
        raise DatosInvalidos("la fecha de ingreso no puede ser anterior al nacimiento")
    for otro in lotes_del_galpon:
        if periodos_se_cruzan(lote.fecha_ingreso, None, otro.fecha_ingreso, otro.fecha_salida):
            raise Conflicto(f"el galpón {galpon.nombre} ya tiene un lote en esas fechas")
    if lote.aves_iniciales > galpon.capacidad_aves:
        raise DatosInvalidos(f"el galpón {galpon.nombre} tiene capacidad para {galpon.capacidad_aves} aves")


def validar_salida(
    lote: Lote, fecha_salida: date, ultimo_registro: date | None, lotes_del_galpon: Iterable[Lote]
) -> None:
    if fecha_salida < lote.fecha_ingreso:
        raise DatosInvalidos("la salida es anterior al ingreso")
    if ultimo_registro is not None and fecha_salida < ultimo_registro:
        raise DatosInvalidos(f"el lote tiene registros hasta el {ultimo_registro}")
    for otro in lotes_del_galpon:
        if otro.id != lote.id and periodos_se_cruzan(
            lote.fecha_ingreso, fecha_salida, otro.fecha_ingreso, otro.fecha_salida
        ):
            raise Conflicto(f"esa salida se cruza con el lote {otro.id} del mismo galpón")
