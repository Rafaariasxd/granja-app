import uuid
from dataclasses import dataclass
from datetime import date

from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import lotes
from app.dominio.errores import Conflicto, DatosInvalidos, NoEncontrado
from app.dominio.modelos import RegistroDiario


@dataclass(frozen=True)
class RegistroDelDia:
    id: uuid.UUID
    galpon_id: int
    fecha: date
    huevos_total: int
    huevos_rotos: int = 0
    mortalidad: int = 0
    alimento_kg: float = 0.0


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
