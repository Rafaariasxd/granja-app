import uuid
from datetime import date

from pydantic import BaseModel, ConfigDict, Field

from app.dominio.modelos import Etapa, Motivo, Rol, TipoInsumo


class GalponIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=50)
    capacidad_aves: int = Field(gt=0)


class GalponOut(GalponIn):
    model_config = ConfigDict(from_attributes=True)
    id: int
    activo: bool


class LineaIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=50)


class LineaOut(LineaIn):
    model_config = ConfigDict(from_attributes=True)
    id: int


class LoteIn(BaseModel):
    galpon_id: int
    linea_id: int
    fecha_nacimiento: date
    fecha_ingreso: date
    aves_iniciales: int = Field(gt=0)


class LoteOut(LoteIn):
    model_config = ConfigDict(from_attributes=True)
    id: int
    fecha_salida: date | None


class RegistroIn(BaseModel):
    id: uuid.UUID
    galpon_id: int
    fecha: date
    huevos_total: int = Field(ge=0)
    huevos_rotos: int = Field(ge=0, default=0)
    mortalidad: int = Field(ge=0, default=0)
    alimento_kg: float = Field(ge=0, default=0)


class RegistroOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    lote_id: int
    fecha: date
    huevos_total: int
    huevos_rotos: int
    mortalidad: int
    alimento_kg: float


class ResumenGalponOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    galpon_id: int
    nombre: str
    capacidad_aves: int
    lote_id: int | None
    etapa: Etapa | None
    edad_semanas: int | None
    aves_vivas: int
    ocupacion_pct: float
    postura_pct: float | None
    linea: str | None
    huevos_del_dia: int | None


class IngresoIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=50)
    pin: str = Field(min_length=1, max_length=20)


class SesionOut(BaseModel):
    token: str
    usuario_id: int
    nombre: str
    rol: Rol


class UsuarioIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=50)
    pin: str = Field(min_length=1, max_length=20)
    rol: Rol = Rol.REGISTRADOR


class UsuarioOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str
    rol: Rol
    activo: bool


class InsumoIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=80)
    tipo: TipoInsumo
    etapa: Etapa | None = None
    kg_por_bulto: float | None = Field(default=None, gt=0)


class InsumoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str
    tipo: TipoInsumo
    etapa: Etapa | None
    kg_por_bulto: float | None


class CompraIn(BaseModel):
    fecha: date | None = None
    bultos: float | None = Field(default=None, gt=0)
    kg: float | None = Field(default=None, gt=0)


class AjusteIn(BaseModel):
    fecha: date | None = None
    kg_reales: float = Field(ge=0)
    nota: str = Field(default="", max_length=200)


class PreparacionIn(BaseModel):
    fecha: date | None = None
    kg: float = Field(gt=0)


class IngredienteIn(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    insumo_id: int
    porcentaje: float = Field(gt=0, le=100)


class EnUsoIn(BaseModel):
    insumo_id: int


class MovimientoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    insumo_id: int
    fecha: date
    kg: float
    motivo: Motivo
    nota: str


class ExistenciaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    insumo: InsumoOut
    stock_kg: float
    bultos: float | None
    consumo_diario_kg: float | None
    dias: float | None
    nivel: str


class CoberturaEtapaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    etapa: Etapa
    consumo_diario_kg: float | None
    stock_kg: float
    dias: float | None
    nivel: str
    en_uso_id: int | None


class MezclaPosibleOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    producto_id: int
    producto: str
    stock_kg: float
    kg_posibles: float
    limitante_id: int
    limitante: str
    dias: float | None
    nivel: str


class InventarioOut(BaseModel):
    existencias: list[ExistenciaOut]
    etapas: list[CoberturaEtapaOut]
    mezclas: list[MezclaPosibleOut]
