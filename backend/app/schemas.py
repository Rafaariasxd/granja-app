import uuid
from datetime import date

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.dominio.produccion import Etapa


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

    @model_validator(mode="after")
    def ingreso_despues_de_nacimiento(self) -> "LoteIn":
        if self.fecha_ingreso < self.fecha_nacimiento:
            raise ValueError("la fecha de ingreso no puede ser anterior al nacimiento")
        return self


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


class ResumenGalpon(BaseModel):
    galpon_id: int
    nombre: str
    capacidad_aves: int
    lote_id: int | None
    etapa: Etapa | None
    edad_semanas: int | None
    aves_vivas: int
    ocupacion_pct: float
    postura_pct: float | None
