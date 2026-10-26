"""Lo que el asistente sabe de la granja antes de responder."""

from collections.abc import Sequence
from dataclasses import dataclass
from enum import StrEnum

from app.dominio.errores import DatosInvalidos
from app.dominio.sanidad import EstadoTarea, Panorama

MAX_MENSAJES = 20
MAX_TEXTO = 2000
MAX_IMAGEN_BYTES = 4 * 1024 * 1024
TIPOS_DE_IMAGEN = ("image/jpeg", "image/png", "image/webp")

INSTRUCCIONES = """Eres el asistente de una granja de gallinas ponedoras en Santander, Colombia. \
Hablas con la familia que la maneja: responde en español sencillo, con frases cortas y sin palabras técnicas \
innecesarias. Sabes de manejo de ponedoras (cría, levante y postura), alimentación, vacunación, bioseguridad, \
enfermedades comunes de las aves y producción de huevo.

Cuando te describan un ave enferma o te muestren una foto:
1. Di qué causas son posibles, de la más probable a la menos, y qué señales ayudan a distinguirlas.
2. Di qué revisar en el galpón y qué hacer ya mismo: separar el ave, agua limpia, calor, limpieza.
3. Di cuándo hay que llamar al veterinario sin esperar, por ejemplo si mueren varias aves en pocos días.

No des dosis de medicamentos ni antibióticos: eso lo decide el veterinario. Si no estás seguro, dilo. \
Recuerda que eres una orientación y no reemplazas al veterinario. Usa los datos de la granja que vienen abajo \
cuando ayuden a responder, y no inventes datos que no estén ahí."""


class Rol(StrEnum):
    USUARIO = "usuario"
    ASISTENTE = "asistente"


@dataclass(frozen=True)
class Mensaje:
    rol: Rol
    texto: str


@dataclass(frozen=True)
class Imagen:
    tipo: str
    datos: bytes


def validar_conversacion(mensajes: Sequence[Mensaje], imagen: Imagen | None) -> None:
    if not mensajes:
        raise DatosInvalidos("escribe una pregunta")
    if len(mensajes) > MAX_MENSAJES:
        raise DatosInvalidos("la conversación es muy larga: empieza una nueva")
    if mensajes[-1].rol != Rol.USUARIO or not mensajes[-1].texto.strip():
        raise DatosInvalidos("el último mensaje debe ser una pregunta")
    if any(len(m.texto) > MAX_TEXTO for m in mensajes):
        raise DatosInvalidos("un mensaje es demasiado largo")
    if imagen is not None:
        if imagen.tipo not in TIPOS_DE_IMAGEN:
            raise DatosInvalidos("la foto debe ser JPG, PNG o WEBP")
        if len(imagen.datos) > MAX_IMAGEN_BYTES:
            raise DatosInvalidos("la foto pesa demasiado: máximo 4 MB")


def contexto_de_la_granja(panorama: Panorama) -> str:
    if not panorama.galpones:
        return f"Datos de la granja al {panorama.fecha}: no hay galpones con aves en este momento."
    lineas = [f"Datos de la granja al {panorama.fecha}:"]
    for g in panorama.galpones:
        partes = [f"{g.galpon}: {g.aves_vivas} aves {g.linea}, {g.edad_semanas} semanas, etapa {g.etapa}"]
        if g.postura is not None:
            partes.append(f"postura {g.postura.real_pct}% (esperada {g.postura.estandar_pct}%)")
        if g.peso is not None:
            partes.append(f"peso {g.peso.peso_g:g} g (esperado {g.peso.estandar_g:g} g)")
        atrasadas = [t.tarea.nombre for t in g.tareas if t.estado == EstadoTarea.ATRASADA]
        if atrasadas:
            partes.append("vacunas atrasadas: " + ", ".join(atrasadas))
        lineas.append("- " + "; ".join(partes))
    if panorama.alertas:
        lineas.append("Avisos de hoy:")
        lineas.extend(f"- {a.galpon}: {a.titulo}. {a.detalle}" for a in panorama.alertas)
    return "\n".join(lineas)
