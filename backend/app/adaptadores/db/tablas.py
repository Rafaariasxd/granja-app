import uuid
from datetime import date, datetime

from sqlalchemy import CheckConstraint, ForeignKey, String, Text, UniqueConstraint, false
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
    revisada: Mapped[bool] = mapped_column(default=False, server_default=false())


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


class TablaUsuario(Base):
    __tablename__ = "usuarios"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(50), unique=True)
    rol: Mapped[str] = mapped_column(String(20))
    pin_hash: Mapped[str] = mapped_column(String(200))
    activo: Mapped[bool] = mapped_column(default=True)
    intentos_fallidos: Mapped[int] = mapped_column(default=0)
    bloqueado_hasta: Mapped[datetime | None]


class TablaSesion(Base):
    __tablename__ = "sesiones"

    id: Mapped[int] = mapped_column(primary_key=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True)
    usuario_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"))
    creada_en: Mapped[datetime]
    revocada: Mapped[bool] = mapped_column(default=False)


class TablaEvento(Base):
    __tablename__ = "bitacora"

    id: Mapped[int] = mapped_column(primary_key=True)
    accion: Mapped[str] = mapped_column(String(50))
    detalle: Mapped[str] = mapped_column(Text)
    usuario_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"))
    momento: Mapped[datetime]


class TablaBodega(Base):
    __tablename__ = "bodegas"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(80), unique=True)
    tipo: Mapped[str] = mapped_column(String(20))


class TablaBodegaGalpon(Base):
    __tablename__ = "bodegas_galpones"

    galpon_id: Mapped[int] = mapped_column(ForeignKey("galpones.id"), primary_key=True)
    bodega_id: Mapped[int] = mapped_column(ForeignKey("bodegas.id"))


class TablaInsumo(Base):
    __tablename__ = "insumos"
    __table_args__ = (CheckConstraint("kg_por_bulto IS NULL OR kg_por_bulto > 0", name="kg_por_bulto"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(80), unique=True)
    tipo: Mapped[str] = mapped_column(String(30))
    etapa: Mapped[str | None] = mapped_column(String(20))
    kg_por_bulto: Mapped[float | None]
    activo: Mapped[bool] = mapped_column(default=True)


class TablaIngrediente(Base):
    __tablename__ = "formulas_ingredientes"
    __table_args__ = (
        UniqueConstraint("producto_id", "insumo_id"),
        CheckConstraint("porcentaje > 0", name="porcentaje"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    producto_id: Mapped[int] = mapped_column(ForeignKey("insumos.id"))
    insumo_id: Mapped[int] = mapped_column(ForeignKey("insumos.id"))
    porcentaje: Mapped[float]


class TablaMovimiento(Base):
    __tablename__ = "movimientos_insumo"

    id: Mapped[int] = mapped_column(primary_key=True)
    insumo_id: Mapped[int] = mapped_column(ForeignKey("insumos.id"))
    bodega_id: Mapped[int] = mapped_column(ForeignKey("bodegas.id"))
    fecha: Mapped[date]
    kg: Mapped[float]
    motivo: Mapped[str] = mapped_column(String(20))
    usuario_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"))
    nota: Mapped[str] = mapped_column(Text, default="")
    registro_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("registros_diarios.id"), unique=True)
    operacion_id: Mapped[uuid.UUID | None] = mapped_column(index=True)


class TablaAlimentoEnUso(Base):
    __tablename__ = "alimento_en_uso"

    bodega_id: Mapped[int] = mapped_column(ForeignKey("bodegas.id"), primary_key=True)
    etapa: Mapped[str] = mapped_column(String(20), primary_key=True)
    insumo_id: Mapped[int] = mapped_column(ForeignKey("insumos.id"))


class TablaPlan(Base):
    __tablename__ = "plan_sanitario"
    __table_args__ = (
        CheckConstraint("semana_ideal >= 0", name="semana_ideal"),
        CheckConstraint("semana_max >= semana_ideal", name="semana_max"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    linea_id: Mapped[int] = mapped_column(ForeignKey("lineas_geneticas.id"))
    nombre: Mapped[str] = mapped_column(String(80))
    tipo: Mapped[str] = mapped_column(String(20))
    semana_ideal: Mapped[int]
    semana_max: Mapped[int]
    nota: Mapped[str] = mapped_column(Text, default="")
    activa: Mapped[bool] = mapped_column(default=True)


class TablaCumplimiento(Base):
    __tablename__ = "cumplimientos"
    __table_args__ = (UniqueConstraint("lote_id", "tarea_id"),)

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True)
    lote_id: Mapped[int] = mapped_column(ForeignKey("lotes.id"))
    tarea_id: Mapped[int] = mapped_column(ForeignKey("plan_sanitario.id"))
    fecha: Mapped[date]
    nota: Mapped[str] = mapped_column(Text, default="")
    usuario_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"))


class TablaPesaje(Base):
    __tablename__ = "pesajes"
    __table_args__ = (
        CheckConstraint("peso_g > 0", name="peso_g"),
        CheckConstraint("aves_pesadas > 0", name="aves_pesadas"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True)
    lote_id: Mapped[int] = mapped_column(ForeignKey("lotes.id"))
    fecha: Mapped[date]
    peso_g: Mapped[float]
    aves_pesadas: Mapped[int]


class TablaCategoriaHuevo(Base):
    __tablename__ = "categorias_huevo"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(50), unique=True)
    activa: Mapped[bool] = mapped_column(default=True)
    orden: Mapped[int] = mapped_column(default=0, server_default="0")


class TablaMovimientoDinero(Base):
    __tablename__ = "movimientos_dinero"
    __table_args__ = (
        CheckConstraint("valor > 0", name="valor"),
        CheckConstraint("cantidad_huevos IS NULL OR cantidad_huevos > 0", name="cantidad_huevos"),
    )

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True)
    fecha: Mapped[date] = mapped_column(index=True)
    rubro: Mapped[str] = mapped_column(String(30))
    valor: Mapped[float]
    descripcion: Mapped[str] = mapped_column(Text, default="")
    lote_id: Mapped[int | None] = mapped_column(ForeignKey("lotes.id"))
    categoria_id: Mapped[int | None] = mapped_column(ForeignKey("categorias_huevo.id"))
    cantidad_huevos: Mapped[int | None]
    contraparte: Mapped[str] = mapped_column(String(100), default="")
    usuario_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"))


class TablaPrecioHuevo(Base):
    __tablename__ = "precios_huevo"

    categoria_id: Mapped[int] = mapped_column(ForeignKey("categorias_huevo.id"), primary_key=True)
    precio_caja: Mapped[float | None]
    precio_carton: Mapped[float | None]
    precio_mayorista: Mapped[float | None]


class TablaSalidaHuevo(Base):
    __tablename__ = "salidas_huevo"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True)
    fecha: Mapped[date]
    tipo_venta: Mapped[str] = mapped_column(String(20))
    cliente: Mapped[str] = mapped_column(String(100), default="")
    estado: Mapped[str] = mapped_column(String(20), index=True)
    usuario_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"))
    cerrada_el: Mapped[date | None]
    valor_total: Mapped[float | None]


class TablaLineaSalida(Base):
    __tablename__ = "lineas_salida_huevo"
    __table_args__ = (
        UniqueConstraint("salida_id", "categoria_id"),
        CheckConstraint("huevos_sacados > 0", name="huevos_sacados"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    salida_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("salidas_huevo.id"))
    categoria_id: Mapped[int] = mapped_column(ForeignKey("categorias_huevo.id"))
    huevos_sacados: Mapped[int]
    huevos_vendidos: Mapped[int | None]
    valor: Mapped[float | None]


class TablaMovimientoHuevo(Base):
    __tablename__ = "movimientos_huevo"

    id: Mapped[int] = mapped_column(primary_key=True)
    fecha: Mapped[date]
    categoria_id: Mapped[int] = mapped_column(ForeignKey("categorias_huevo.id"), index=True)
    huevos: Mapped[int]
    motivo: Mapped[str] = mapped_column(String(20))
    usuario_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"))
    nota: Mapped[str] = mapped_column(Text, default="")
    salida_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("salidas_huevo.id"))
    operacion_id: Mapped[uuid.UUID | None] = mapped_column(index=True)
