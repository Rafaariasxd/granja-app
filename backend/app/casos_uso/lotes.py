from datetime import date

from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import lotes as reglas
from app.dominio.errores import NoEncontrado
from app.dominio.modelos import Lote


def crear_lote(uow: UnidadDeTrabajo, lote: Lote) -> Lote:
    galpon = uow.galpones.obtener(lote.galpon_id)
    if galpon is None:
        raise NoEncontrado(f"el galpón {lote.galpon_id} no existe")
    if uow.lineas.obtener(lote.linea_id) is None:
        raise NoEncontrado(f"la línea genética {lote.linea_id} no existe")
    reglas.validar_ingreso(lote, galpon, uow.lotes.del_galpon(galpon.id))
    nuevo = uow.lotes.agregar(lote)
    uow.confirmar()
    return nuevo


def cerrar_lote(uow: UnidadDeTrabajo, lote_id: int, fecha_salida: date) -> Lote:
    lote = uow.lotes.obtener(lote_id)
    if lote is None:
        raise NoEncontrado(f"el lote {lote_id} no existe")
    reglas.validar_salida(lote, fecha_salida, uow.registros.ultima_fecha(lote.id), uow.lotes.del_galpon(lote.galpon_id))
    lote.fecha_salida = fecha_salida
    cerrado = uow.lotes.actualizar(lote)
    uow.confirmar()
    return cerrado
