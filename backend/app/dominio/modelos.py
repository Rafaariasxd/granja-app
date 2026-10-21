import uuid
from dataclasses import dataclass
from datetime import date
from enum import StrEnum


class Etapa(StrEnum):
    CRIA = "cria"
    LEVANTE = "levante"
    PRODUCCION = "produccion"


@dataclass
class Galpon:
    nombre: str
    capacidad_aves: int
    activo: bool = True
    id: int | None = None


@dataclass
class LineaGenetica:
    nombre: str
    id: int | None = None


@dataclass
class Lote:
    galpon_id: int
    linea_id: int
    fecha_nacimiento: date
    fecha_ingreso: date
    aves_iniciales: int
    fecha_salida: date | None = None
    id: int | None = None


@dataclass
class RegistroDiario:
    id: uuid.UUID
    lote_id: int
    fecha: date
    huevos_total: int
    huevos_rotos: int = 0
    mortalidad: int = 0
    alimento_kg: float = 0.0


@dataclass(frozen=True)
class ResumenGalpon:
    galpon_id: int
    nombre: str
    capacidad_aves: int
    lote_id: int | None
    etapa: Etapa | None
    edad_semanas: int | None
    aves_vivas: int
    ocupacion_pct: float
    postura_pct: float | None
