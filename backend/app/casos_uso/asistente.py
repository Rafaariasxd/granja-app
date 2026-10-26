from datetime import date
from typing import Protocol

from app.casos_uso import sanidad
from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import asistente
from app.dominio.asistente import Imagen, Mensaje


class Asesor(Protocol):
    def responder(self, instrucciones: str, mensajes: list[Mensaje], imagen: Imagen | None) -> str: ...


def preguntar(uow: UnidadDeTrabajo, asesor: Asesor, mensajes: list[Mensaje], imagen: Imagen | None, fecha: date) -> str:
    asistente.validar_conversacion(mensajes, imagen)
    contexto = asistente.contexto_de_la_granja(sanidad.panorama(uow, fecha))
    return asesor.responder(f"{asistente.INSTRUCCIONES}\n\n{contexto}", mensajes, imagen)
