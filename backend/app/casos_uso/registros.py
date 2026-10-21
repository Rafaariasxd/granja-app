import uuid
from dataclasses import dataclass
from datetime import date, datetime

from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import lotes
from app.dominio.errores import Conflicto, DatosInvalidos, NoEncontrado
from app.dominio.modelos import Evento, RegistroDiario, Usuario


@dataclass(frozen=True)
class RegistroDelDia:
    id: uuid.UUID
    galpon_id: int
    fecha: date
    huevos_total: int
    huevos_rotos: int = 0
    mortalidad: int = 0
    alimento_kg: float = 0.0


def registro_del_dia(uow: UnidadDeTrabajo, galpon_id: int, fecha: date) -> RegistroDiario | None:
    galpon = uow.galpones.obtener(galpon_id)
    if galpon is None:
        raise NoEncontrado(f"el galpón {galpon_id} no existe")
    lote = lotes.activo_en(uow.lotes.del_galpon(galpon.id), fecha)
    if lote is None:
        return None
    return uow.registros.del_dia(lote.id, fecha)


def guardar_registro(uow: UnidadDeTrabajo, datos: RegistroDelDia) -> RegistroDiario:
    """Crea o corrige el registro del día. Es idempotente: el celular puede reenviarlo sin duplicar."""
    galpon = uow.galpones.obtener(datos.galpon_id)
    if galpon is None:
        raise NoEncontrado(f"el galpón {datos.galpon_id} no existe")
    lote = lotes.activo_en(uow.lotes.del_galpon(galpon.id), datos.fecha)
    if lote is None:
        raise DatosInvalidos(f"el galpón {galpon.nombre} no tiene un lote activo ese día")
    otro = uow.registros.del_dia(lote.id, datos.fecha)
    if otro is not None and otro.id != datos.id:
        raise Conflicto(f"ya hay un registro de {galpon.nombre} para {datos.fecha}")
    registro = uow.registros.guardar(
        RegistroDiario(
            id=datos.id,
            lote_id=lote.id,
            fecha=datos.fecha,
            huevos_total=datos.huevos_total,
            huevos_rotos=datos.huevos_rotos,
            mortalidad=datos.mortalidad,
            alimento_kg=datos.alimento_kg,
        )
    )
    uow.confirmar()
    return registro


def borrar_registro(uow: UnidadDeTrabajo, quien: Usuario, registro_id: uuid.UUID, ahora: datetime) -> None:
    registro = uow.registros.obtener(registro_id)
    if registro is None:
        raise NoEncontrado(f"el registro {registro_id} no existe")
    detalle = (
        f"{registro.id} lote {registro.lote_id} {registro.fecha}: huevos {registro.huevos_total}, "
        f"rotos {registro.huevos_rotos}, muertas {registro.mortalidad}, alimento {registro.alimento_kg} kg"
    )
    uow.registros.eliminar(registro_id)
    uow.bitacora.agregar(Evento("registro_borrado", detalle, quien.id, ahora))
    uow.confirmar()
