import uuid
from datetime import date, datetime

from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import finanzas
from app.dominio.errores import Conflicto, DatosInvalidos, NoEncontrado
from app.dominio.finanzas import CategoriaHuevo, MovimientoDinero, ResumenFinanzas
from app.dominio.modelos import Evento, Usuario

CATEGORIAS_INICIALES = ("Jumbo", "Extra", "AA", "A", "B", "C", "Roto")


def listar_categorias(uow: UnidadDeTrabajo) -> list[CategoriaHuevo]:
    return uow.categorias.listar()


def crear_categoria(uow: UnidadDeTrabajo, nombre: str) -> CategoriaHuevo:
    if uow.categorias.por_nombre(nombre):
        raise Conflicto(f"ya existe la categoría {nombre}")
    orden = max((c.orden for c in uow.categorias.listar()), default=0) + 1
    categoria = uow.categorias.agregar(CategoriaHuevo(nombre=nombre, orden=orden))
    uow.confirmar()
    return categoria


def cambiar_categoria(
    uow: UnidadDeTrabajo, categoria_id: int, nombre: str | None, activa: bool | None, orden: int | None = None
) -> CategoriaHuevo:
    categoria = uow.categorias.obtener(categoria_id)
    if categoria is None:
        raise NoEncontrado(f"la categoría {categoria_id} no existe")
    if nombre is not None:
        otra = uow.categorias.por_nombre(nombre)
        if otra is not None and otra.id != categoria_id:
            raise Conflicto(f"ya existe la categoría {nombre}")
        categoria.nombre = nombre
    if activa is not None:
        categoria.activa = activa
    if orden is not None:
        categoria.orden = orden
    guardada = uow.categorias.actualizar(categoria)
    uow.confirmar()
    return guardada


def guardar_movimiento(uow: UnidadDeTrabajo, quien: Usuario, movimiento: MovimientoDinero) -> MovimientoDinero:
    """Es idempotente: el celular puede reenviarlo sin duplicar."""
    finanzas.validar_movimiento(movimiento)
    if movimiento.lote_id is not None and uow.lotes.obtener(movimiento.lote_id) is None:
        raise NoEncontrado(f"el lote {movimiento.lote_id} no existe")
    if movimiento.categoria_id is not None and uow.categorias.obtener(movimiento.categoria_id) is None:
        raise NoEncontrado(f"la categoría de huevo {movimiento.categoria_id} no existe")
    previo = uow.dinero.obtener(movimiento.id)
    movimiento.usuario_id = previo.usuario_id if previo else quien.id
    guardado = uow.dinero.guardar(movimiento)
    uow.confirmar()
    return guardado


def borrar_movimiento(uow: UnidadDeTrabajo, quien: Usuario, movimiento_id: uuid.UUID, ahora: datetime) -> None:
    movimiento = uow.dinero.obtener(movimiento_id)
    if movimiento is None:
        return
    detalle = f"{movimiento.fecha} {movimiento.rubro.value}: {movimiento.valor:g} {movimiento.descripcion}".strip()
    uow.dinero.eliminar(movimiento_id)
    uow.bitacora.agregar(Evento("movimiento_borrado", detalle, quien.id, ahora))
    uow.confirmar()


def listar_movimientos(uow: UnidadDeTrabajo, desde: date, hasta: date) -> list[MovimientoDinero]:
    _validar_periodo(desde, hasta)
    return uow.dinero.entre(desde, hasta)


def resumen(uow: UnidadDeTrabajo, desde: date, hasta: date) -> ResumenFinanzas:
    _validar_periodo(desde, hasta)
    nombres = {c.id: c.nombre for c in uow.categorias.listar()}
    galpon_del_lote: dict[int, str] = {}
    movimientos = uow.dinero.entre(desde, hasta)
    for lote_id in {m.lote_id for m in movimientos if m.lote_id is not None}:
        lote = uow.lotes.obtener(lote_id)
        galpon = uow.galpones.obtener(lote.galpon_id) if lote else None
        galpon_del_lote[lote_id] = galpon.nombre if galpon else f"Lote {lote_id}"
    return finanzas.resumir(movimientos, desde, hasta, nombres, galpon_del_lote)


def _validar_periodo(desde: date, hasta: date) -> None:
    if hasta < desde:
        raise DatosInvalidos("el periodo termina antes de empezar")
