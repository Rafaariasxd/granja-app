from collections.abc import Iterator
from functools import cache
from typing import Annotated

from fastapi import Depends, Header

from app.adaptadores.db.conexion import SessionLocal
from app.adaptadores.db.repositorios import UnidadDeTrabajoSql
from app.adaptadores.ia.gemini import Gemini
from app.casos_uso import usuarios
from app.casos_uso.asistente import Asesor
from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio.errores import NoAutenticado
from app.dominio.modelos import Usuario


def unidad_de_trabajo() -> Iterator[UnidadDeTrabajoSql]:
    with SessionLocal() as session:
        yield UnidadDeTrabajoSql(session)


def token_de_sesion(authorization: Annotated[str | None, Header()] = None) -> str:
    esquema, _, token = (authorization or "").partition(" ")
    if esquema.lower() != "bearer" or not token:
        raise NoAutenticado("falta iniciar sesión")
    return token


def usuario_actual(
    uow: Annotated[UnidadDeTrabajo, Depends(unidad_de_trabajo)],
    token: Annotated[str, Depends(token_de_sesion)],
) -> Usuario:
    return usuarios.usuario_de_sesion(uow, token)


def administrador(usuario: Annotated[Usuario, Depends(usuario_actual)]) -> Usuario:
    usuarios.exigir_administrador(usuario)
    return usuario


@cache
def asesor() -> Asesor:
    return Gemini.desde_entorno()
