from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse

from app.dominio.errores import Conflicto, DatosInvalidos, ErrorDeDominio, NoEncontrado

CODIGOS = {
    NoEncontrado: status.HTTP_404_NOT_FOUND,
    Conflicto: status.HTTP_409_CONFLICT,
    DatosInvalidos: status.HTTP_422_UNPROCESSABLE_CONTENT,
}


def registrar(app: FastAPI) -> None:
    @app.exception_handler(ErrorDeDominio)
    async def error_de_dominio(_: Request, error: ErrorDeDominio) -> JSONResponse:
        codigo = CODIGOS.get(type(error), status.HTTP_400_BAD_REQUEST)
        return JSONResponse(status_code=codigo, content={"detail": str(error)})
