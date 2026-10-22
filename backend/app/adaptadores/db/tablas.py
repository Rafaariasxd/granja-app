import uuid
from datetime import date

from sqlalchemy import CheckConstraint, ForeignKey, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.adaptadores.db.conexion import Base


class TablaGalpon(Base):
    __tablename__ = "galpones"
    __table_args__ = (CheckConstraint("capacidad_aves > 0", name="capacidad_aves"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(50), unique=True)
    capacidad_aves: Mapped[int]
    activo: Mapped[bool] = mapped_column(default=True)


class TablaLinea(Base):
    __tablename__ = "lineas_geneticas"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(50), unique=True)


class TablaCurva(Base):
    __tablename__ = "curvas_estandar"
    __table_args__ = (UniqueConstraint("linea_id", "semana_edad"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    linea_id: Mapped[int] = mapped_column(ForeignKey("lineas_geneticas.id"))
    semana_edad: Mapped[int]
    postura_pct: Mapped[float]
    peso_g: Mapped[float | None]


class TablaLote(Base):
    __tablename__ = "lotes"
    __table_args__ = (CheckConstraint("aves_iniciales > 0", name="aves_iniciales"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    galpon_id: Mapped[int] = mapped_column(ForeignKey("galpones.id"))
    linea_id: Mapped[int] = mapped_column(ForeignKey("lineas_geneticas.id"))
    fecha_nacimiento: Mapped[date]
    fecha_ingreso: Mapped[date]
    aves_iniciales: Mapped[int]
    fecha_salida: Mapped[date | None]


class TablaRegistro(Base):
    __tablename__ = "registros_diarios"
    __table_args__ = (
        UniqueConstraint("lote_id", "fecha"),
        CheckConstraint("huevos_total >= 0", name="huevos_total"),
        CheckConstraint("huevos_rotos >= 0", name="huevos_rotos"),
        CheckConstraint("mortalidad >= 0", name="mortalidad"),
        CheckConstraint("alimento_kg >= 0", name="alimento_kg"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True)
    lote_id: Mapped[int] = mapped_column(ForeignKey("lotes.id"))
    fecha: Mapped[date]
    huevos_total: Mapped[int]
    huevos_rotos: Mapped[int] = mapped_column(default=0)
    mortalidad: Mapped[int] = mapped_column(default=0)
    alimento_kg: Mapped[float] = mapped_column(default=0)
