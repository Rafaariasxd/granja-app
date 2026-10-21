import uuid
from dataclasses import dataclass
from datetime import date, datetime
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


class Rol(StrEnum):
    ADMINISTRADOR = "administrador"
    REGISTRADOR = "registrador"


@dataclass
class Usuario:
    nombre: str
    rol: Rol
    pin_hash: str
    activo: bool = True
    intentos_fallidos: int = 0
    bloqueado_hasta: datetime | None = None
    id: int | None = None


@dataclass
class Sesion:
    token_hash: str
    usuario_id: int
    creada_en: datetime
    revocada: bool = False
    id: int | None = None


@dataclass(frozen=True)
class Evento:
    accion: str
    detalle: str
    usuario_id: int
    momento: datetime
    id: int | None = None
