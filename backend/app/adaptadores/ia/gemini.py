import base64
import os

import httpx

from app.dominio.asistente import Imagen, Mensaje, Rol
from app.dominio.errores import ServicioNoDisponible

URL = "https://generativelanguage.googleapis.com/v1beta/models/{modelo}:generateContent"


class Gemini:
    def __init__(self, clave: str | None, modelo: str, cliente: httpx.Client | None = None) -> None:
        self._clave = clave
        self._modelo = modelo
        self._cliente = cliente or httpx.Client(timeout=60)

    @classmethod
    def desde_entorno(cls) -> "Gemini":
        return cls(os.getenv("GEMINI_API_KEY"), os.getenv("GEMINI_MODELO", "gemini-flash-latest"))

    def responder(self, instrucciones: str, mensajes: list[Mensaje], imagen: Imagen | None) -> str:
        if not self._clave:
            raise ServicioNoDisponible("el asistente no está configurado en el servidor")
        contenidos = [
            {"role": "user" if m.rol == Rol.USUARIO else "model", "parts": [{"text": m.texto}]} for m in mensajes
        ]
        if imagen is not None:
            contenidos[-1]["parts"].append(
                {"inline_data": {"mime_type": imagen.tipo, "data": base64.b64encode(imagen.datos).decode()}}
            )
        cuerpo = {
            "system_instruction": {"parts": [{"text": instrucciones}]},
            "contents": contenidos,
            "generationConfig": {"temperature": 0.4, "maxOutputTokens": 1500},
        }
        try:
            respuesta = self._cliente.post(
                URL.format(modelo=self._modelo), json=cuerpo, headers={"x-goog-api-key": self._clave}
            )
        except httpx.HTTPError as error:
            raise ServicioNoDisponible("no se pudo hablar con el asistente, intenta otra vez") from error
        if respuesta.status_code == 429:
            raise ServicioNoDisponible("el asistente está ocupado: intenta en unos minutos")
        if respuesta.status_code >= 400:
            raise ServicioNoDisponible("el asistente no respondió, intenta otra vez")
        try:
            partes = respuesta.json()["candidates"][0]["content"]["parts"]
        except (KeyError, IndexError, ValueError) as error:
            raise ServicioNoDisponible("el asistente no pudo responder esa pregunta") from error
        texto = "".join(p.get("text", "") for p in partes).strip()
        if not texto:
            raise ServicioNoDisponible("el asistente no pudo responder esa pregunta")
        return texto
