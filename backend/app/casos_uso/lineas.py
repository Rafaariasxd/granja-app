from datetime import datetime

from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import plantillas
from app.dominio.errores import Conflicto, DatosInvalidos, NoEncontrado
from app.dominio.modelos import Evento, LineaGenetica, Usuario
from app.dominio.sanidad import TareaPlan


def plantillas_disponibles() -> list[str]:
    return sorted(plantillas.PLANTILLAS)


def crear_linea(uow: UnidadDeTrabajo, nombre: str, plantilla: str | None = None) -> LineaGenetica:
    if uow.lineas.por_nombre(nombre):
        raise Conflicto(f"ya existe una línea llamada {nombre}")
    if plantilla is not None and plantilla not in plantillas.PLANTILLAS:
        raise DatosInvalidos(f"no hay valores de referencia para {plantilla}")
    linea = uow.lineas.agregar(LineaGenetica(nombre=nombre))
    if plantilla is not None:
        uow.curvas.guardar(linea.id, plantillas.PLANTILLAS[plantilla])
        tareas = [
            TareaPlan(linea.id, nombre_, tipo, ideal, maximo, nota)
            for nombre_, tipo, ideal, maximo, nota in plantillas.PLAN_PONEDORAS
        ]
        uow.plan.guardar(linea.id, tareas)
    uow.confirmar()
    return linea


def listar_lineas(uow: UnidadDeTrabajo) -> list[LineaGenetica]:
    return uow.lineas.listar()


def renombrar_linea(uow: UnidadDeTrabajo, quien: Usuario, linea_id: int, nombre: str, ahora: datetime) -> LineaGenetica:
    linea = uow.lineas.obtener(linea_id)
    if linea is None:
        raise NoEncontrado(f"la línea {linea_id} no existe")
    otra = uow.lineas.por_nombre(nombre)
    if otra is not None and otra.id != linea_id:
        raise Conflicto(f"ya existe una línea llamada {nombre}")
    anterior = linea.nombre
    linea.nombre = nombre
    guardada = uow.lineas.actualizar(linea)
    uow.bitacora.agregar(Evento("raza_renombrada", f"{anterior} -> {nombre}", quien.id, ahora))
    uow.confirmar()
    return guardada
