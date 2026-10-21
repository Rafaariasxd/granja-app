from collections.abc import Iterator

from app.adaptadores.db.conexion import SessionLocal
from app.adaptadores.db.repositorios import UnidadDeTrabajoSql


def unidad_de_trabajo() -> Iterator[UnidadDeTrabajoSql]:
    with SessionLocal() as session:
        yield UnidadDeTrabajoSql(session)
