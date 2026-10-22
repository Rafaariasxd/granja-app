from datetime import date

from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import lotes, produccion
from app.dominio.errores import Conflicto
from app.dominio.modelos import Galpon, ResumenGalpon


def crear_galpon(uow: UnidadDeTrabajo, nombre: str, capacidad_aves: int) -> Galpon:
    if uow.galpones.por_nombre(nombre):
        raise Conflicto(f"ya existe un galpón llamado {nombre}")
    galpon = uow.galpones.agregar(Galpon(nombre=nombre, capacidad_aves=capacidad_aves))
    uow.confirmar()
    return galpon


def listar_galpones(uow: UnidadDeTrabajo) -> list[Galpon]:
    return uow.galpones.listar()


def resumen_galpones(uow: UnidadDeTrabajo, fecha: date) -> list[ResumenGalpon]:
    """Lo que hoy está en el tablero: cada galpón con su lote, aves y postura del día."""
    resumen = []
    for galpon in uow.galpones.listar():
        lote = lotes.activo_en(uow.lotes.del_galpon(galpon.id), fecha)
        if lote is None:
            resumen.append(produccion.resumir_galpon(galpon, None, 0, None, fecha))
            continue
        registro = uow.registros.del_dia(lote.id, fecha)
        linea = uow.lineas.obtener(lote.linea_id)
        resumen.append(
            produccion.resumir_galpon(
                galpon,
                lote,
                uow.registros.mortalidad_hasta(lote.id, fecha),
                registro.huevos_total if registro else None,
                fecha,
                linea.nombre if linea else None,
            )
        )
    return resumen
