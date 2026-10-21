import uuid
from datetime import date

from sqlalchemy import CheckConstraint, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Galpon(Base):
    __tablename__ = "galpones"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(50), unique=True)
    capacidad_aves: Mapped[int] = mapped_column(CheckConstraint("capacidad_aves > 0"))
    activo: Mapped[bool] = mapped_column(default=True)

    lotes: Mapped[list["Lote"]] = relationship(back_populates="galpon")


class LineaGenetica(Base):
    __tablename__ = "lineas_geneticas"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(50), unique=True)


class CurvaEstandar(Base):
    __tablename__ = "curvas_estandar"
    __table_args__ = (UniqueConstraint("linea_id", "semana_edad"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    linea_id: Mapped[int] = mapped_column(ForeignKey("lineas_geneticas.id"))
    semana_edad: Mapped[int]
    postura_pct: Mapped[float]
    peso_g: Mapped[float | None]


class Lote(Base):
    __tablename__ = "lotes"

    id: Mapped[int] = mapped_column(primary_key=True)
    galpon_id: Mapped[int] = mapped_column(ForeignKey("galpones.id"))
    linea_id: Mapped[int] = mapped_column(ForeignKey("lineas_geneticas.id"))
    fecha_nacimiento: Mapped[date]
    fecha_ingreso: Mapped[date]
    aves_iniciales: Mapped[int] = mapped_column(CheckConstraint("aves_iniciales > 0"))
    fecha_salida: Mapped[date | None]

    galpon: Mapped[Galpon] = relationship(back_populates="lotes")
    registros: Mapped[list["RegistroDiario"]] = relationship(back_populates="lote")


class RegistroDiario(Base):
    __tablename__ = "registros_diarios"
    __table_args__ = (UniqueConstraint("lote_id", "fecha"),)

    # El id lo genera el celular para que reenviar un registro no lo duplique.
    id: Mapped[uuid.UUID] = mapped_column(primary_key=True)
    lote_id: Mapped[int] = mapped_column(ForeignKey("lotes.id"))
    fecha: Mapped[date]
    huevos_total: Mapped[int] = mapped_column(CheckConstraint("huevos_total >= 0"))
    huevos_rotos: Mapped[int] = mapped_column(CheckConstraint("huevos_rotos >= 0"), default=0)
    mortalidad: Mapped[int] = mapped_column(CheckConstraint("mortalidad >= 0"), default=0)
    alimento_kg: Mapped[float] = mapped_column(CheckConstraint("alimento_kg >= 0"), default=0)

    lote: Mapped[Lote] = relationship(back_populates="registros")
