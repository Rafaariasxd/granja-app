import base64
import json
from datetime import date

import httpx
import pytest
from fastapi.testclient import TestClient

from app.adaptadores.api.dependencias import asesor
from app.adaptadores.ia.gemini import Gemini
from app.dominio.asistente import Imagen, Mensaje, Rol, contexto_de_la_granja, validar_conversacion
from app.dominio.errores import DatosInvalidos, ServicioNoDisponible
from app.dominio.sanidad import Panorama
from app.main import app

PREGUNTA = [Mensaje(Rol.USUARIO, "Una gallina tiene la cresta pálida, ¿qué puede ser?")]


def test_la_conversacion_debe_terminar_en_una_pregunta():
    validar_conversacion(PREGUNTA, None)
    with pytest.raises(DatosInvalidos, match="pregunta"):
        validar_conversacion([], None)
    with pytest.raises(DatosInvalidos, match="último"):
        validar_conversacion([*PREGUNTA, Mensaje(Rol.ASISTENTE, "Puede ser...")], None)
    with pytest.raises(DatosInvalidos, match="último"):
        validar_conversacion([Mensaje(Rol.USUARIO, "   ")], None)
    with pytest.raises(DatosInvalidos, match="larga"):
        validar_conversacion([Mensaje(Rol.USUARIO, "hola")] * 21, None)
    with pytest.raises(DatosInvalidos, match="largo"):
        validar_conversacion([Mensaje(Rol.USUARIO, "a" * 2001)], None)


def test_la_foto_debe_ser_una_imagen_liviana():
    validar_conversacion(PREGUNTA, Imagen("image/jpeg", b"x"))
    with pytest.raises(DatosInvalidos, match="JPG"):
        validar_conversacion(PREGUNTA, Imagen("application/pdf", b"x"))
    with pytest.raises(DatosInvalidos, match="4 MB"):
        validar_conversacion(PREGUNTA, Imagen("image/png", b"x" * (4 * 1024 * 1024 + 1)))


def test_sin_galpones_el_contexto_lo_dice():
    texto = contexto_de_la_granja(Panorama(date(2026, 10, 25), [], []))
    assert "no hay galpones con aves" in texto


def _gemini(manejador, clave="clave-de-prueba"):
    return Gemini(clave, "gemini-flash-latest", httpx.Client(transport=httpx.MockTransport(manejador)))


def test_gemini_manda_las_instrucciones_la_conversacion_y_la_foto():
    vistas = []

    def manejador(peticion):
        vistas.append(peticion)
        return httpx.Response(
            200, json={"candidates": [{"content": {"parts": [{"text": "Puede ser "}, {"text": "anemia."}]}}]}
        )

    mensajes = [
        Mensaje(Rol.USUARIO, "¿Qué es esto?"),
        Mensaje(Rol.ASISTENTE, "¿Me mandas una foto?"),
        Mensaje(Rol.USUARIO, "Aquí está"),
    ]
    texto = _gemini(manejador).responder("Eres experto", mensajes, Imagen("image/jpeg", b"foto"))

    assert texto == "Puede ser anemia."
    [peticion] = vistas
    assert peticion.url.path.endswith("/models/gemini-flash-latest:generateContent")
    assert peticion.headers["x-goog-api-key"] == "clave-de-prueba"
    assert "key=" not in str(peticion.url)
    cuerpo = json.loads(peticion.content)
    assert cuerpo["system_instruction"] == {"parts": [{"text": "Eres experto"}]}
    assert [c["role"] for c in cuerpo["contents"]] == ["user", "model", "user"]
    assert cuerpo["contents"][-1]["parts"][1] == {
        "inline_data": {"mime_type": "image/jpeg", "data": base64.b64encode(b"foto").decode()}
    }


@pytest.mark.parametrize(
    ("respuesta", "mensaje"),
    [
        (httpx.Response(429, json={}), "ocupado"),
        (httpx.Response(500, json={}), "no respondió"),
        (httpx.Response(200, json={"candidates": []}), "no pudo responder"),
        (httpx.Response(200, json={"candidates": [{"content": {"parts": [{"text": " "}]}}]}), "no pudo responder"),
    ],
)
def test_gemini_traduce_los_errores(respuesta, mensaje):
    with pytest.raises(ServicioNoDisponible, match=mensaje):
        _gemini(lambda _: respuesta).responder("x", PREGUNTA, None)


def test_sin_red_o_sin_clave_el_asistente_no_esta_disponible():
    def sin_red(_):
        raise httpx.ConnectError("sin red")

    with pytest.raises(ServicioNoDisponible, match="no se pudo hablar"):
        _gemini(sin_red).responder("x", PREGUNTA, None)
    with pytest.raises(ServicioNoDisponible, match="no está configurado"):
        _gemini(lambda _: httpx.Response(200), clave=None).responder("x", PREGUNTA, None)


class AsesorFalso:
    def __init__(self, respuesta="Revisa el agua y separa el ave.", error=None):
        self.respuesta = respuesta
        self.error = error
        self.llamadas = []

    def responder(self, instrucciones, mensajes, imagen):
        self.llamadas.append((instrucciones, mensajes, imagen))
        if self.error:
            raise self.error
        return self.respuesta


@pytest.fixture
def falso():
    asesor_falso = AsesorFalso()
    app.dependency_overrides[asesor] = lambda: asesor_falso
    return asesor_falso


def _preguntar(client, texto="¿Por qué bajó la postura?", **extra):
    return client.post("/asistente", json={"mensajes": [{"rol": "usuario", "texto": texto}], **extra})


def test_el_asistente_responde_con_los_datos_de_la_granja(client, granja, falso):
    r = _preguntar(client)
    assert r.status_code == 200
    assert r.json() == {"respuesta": "Revisa el agua y separa el ave."}
    instrucciones, mensajes, imagen = falso.llamadas[0]
    assert "ponedoras" in instrucciones
    assert "veterinario" in instrucciones
    assert "Galpón 1: " in instrucciones
    assert "Hy-Line Brown" in instrucciones
    assert mensajes == [Mensaje(Rol.USUARIO, "¿Por qué bajó la postura?")]
    assert imagen is None


def test_la_foto_llega_decodificada(client, falso):
    foto = base64.b64encode(b"bytes-de-la-foto").decode()
    r = _preguntar(client, imagen={"tipo": "image/png", "datos_base64": foto})
    assert r.status_code == 200
    assert falso.llamadas[0][2] == Imagen("image/png", b"bytes-de-la-foto")


def test_una_foto_dañada_o_de_otro_tipo_es_422(client, falso):
    assert _preguntar(client, imagen={"tipo": "image/png", "datos_base64": "no es base64!"}).status_code == 422
    foto = base64.b64encode(b"x").decode()
    assert _preguntar(client, imagen={"tipo": "text/plain", "datos_base64": foto}).status_code == 422
    assert falso.llamadas == []


def test_si_el_asistente_falla_es_503_con_el_motivo(client, falso):
    falso.error = ServicioNoDisponible("el asistente está ocupado: intenta en unos minutos")
    r = _preguntar(client)
    assert r.status_code == 503
    assert r.json()["detail"] == "el asistente está ocupado: intenta en unos minutos"


def test_sin_sesion_no_se_puede_preguntar(client, falso):
    assert TestClient(app).post("/asistente", json={"mensajes": []}).status_code == 401
