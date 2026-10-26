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
    revisada: bool = False
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
    linea: str | None = None
    huevos_del_dia: int | None = None


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


class TipoInsumo(StrEnum):
    MATERIA_PRIMA = "materia_prima"
    ALIMENTO_COMPRADO = "alimento_comprado"
    ALIMENTO_PREPARADO = "alimento_preparado"


class TipoBodega(StrEnum):
    ALIMENTO = "alimento"
    MATERIA_PRIMA = "materia_prima"


class Motivo(StrEnum):
    COMPRA = "compra"
    PREPARACION = "preparacion"
    USO_EN_MEZCLA = "uso_en_mezcla"
    CONSUMO = "consumo"
    GASTO = "gasto"
    AJUSTE = "ajuste"


@dataclass
class Bodega:
    nombre: str
    tipo: TipoBodega
    id: int | None = None


@dataclass
class Insumo:
    nombre: str
    tipo: TipoInsumo
    kg_por_bulto: float | None = None
    etapa: Etapa | None = None
    activo: bool = True
    id: int | None = None


@dataclass(frozen=True)
class Ingrediente:
    insumo_id: int
    porcentaje: float


@dataclass
class MovimientoInsumo:
    insumo_id: int
    bodega_id: int
    fecha: date
    kg: float
    motivo: Motivo
    usuario_id: int | None = None
    nota: str = ""
    registro_id: uuid.UUID | None = None
    operacion_id: uuid.UUID | None = None
    id: int | None = None


@dataclass(frozen=True)
class ExistenciaInsumo:
    insumo: Insumo
    stock_kg: float
    bultos: float | None
    consumo_diario_kg: float | None
    dias: float | None
    nivel: str


@dataclass(frozen=True)
class CoberturaEtapa:
    etapa: Etapa
    consumo_diario_kg: float | None
    stock_kg: float
    dias: float | None
    nivel: str
    en_uso_id: int | None


@dataclass(frozen=True)
class MezclaPosible:
    producto_id: int
    producto: str
    stock_kg: float
    kg_posibles: float
    limitante_id: int
    limitante: str
    dias: float | None
    nivel: str
    origen_id: int
    origen: str


@dataclass(frozen=True)
class InventarioBodega:
    bodega: Bodega
    galpon_ids: list[int]
    existencias: list[ExistenciaInsumo]
    etapas: list[CoberturaEtapa]


@dataclass(frozen=True)
class EstadoInventario:
    bodegas: list[InventarioBodega]
    mezclas: list[MezclaPosible]
