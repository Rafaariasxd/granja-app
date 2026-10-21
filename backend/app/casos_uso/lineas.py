from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio.errores import Conflicto
from app.dominio.modelos import LineaGenetica


def crear_linea(uow: UnidadDeTrabajo, nombre: str) -> LineaGenetica:
    if uow.lineas.por_nombre(nombre):
        raise Conflicto(f"ya existe una línea llamada {nombre}")
    linea = uow.lineas.agregar(LineaGenetica(nombre=nombre))
    uow.confirmar()
    return linea


def listar_lineas(uow: UnidadDeTrabajo) -> list[LineaGenetica]:
    return uow.lineas.listar()
