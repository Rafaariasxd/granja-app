from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse

from app.dominio.errores import (
    Bloqueado,
    Conflicto,
    DatosInvalidos,
    ErrorDeDominio,
    NoAutenticado,
    NoEncontrado,
    SinPermiso,
)

CODIGOS = {
    NoEncontrado: status.HTTP_404_NOT_FOUND,
    Conflicto: status.HTTP_409_CONFLICT,
    DatosInvalidos: status.HTTP_422_UNPROCESSABLE_CONTENT,
    NoAutenticado: status.HTTP_401_UNAUTHORIZED,
    SinPermiso: status.HTTP_403_FORBIDDEN,
    Bloqueado: status.HTTP_429_TOO_MANY_REQUESTS,
}


def registrar(app: FastAPI) -> None:
    @app.exception_handler(ErrorDeDominio)
    async def error_de_dominio(_: Request, error: ErrorDeDominio) -> JSONResponse:
        codigo = CODIGOS.get(type(error), status.HTTP_400_BAD_REQUEST)
        return JSONResponse(status_code=codigo, content={"detail": str(error)})
