import uuid
from datetime import date

from pydantic import BaseModel, ConfigDict, Field

from app.dominio.finanzas import Rubro, TipoMovimiento
from app.dominio.huevos import EstadoSalida, MotivoHuevo, TipoVenta, a_huevos
from app.dominio.modelos import Etapa, Motivo, Rol, TipoBodega, TipoInsumo
from app.dominio.sanidad import EstadoTarea, Nivel, NivelPeso, TipoAlerta, TipoTarea


class GalponIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=50)
    capacidad_aves: int = Field(gt=0)


class GalponOut(GalponIn):
    model_config = ConfigDict(from_attributes=True)
    id: int
    activo: bool


class LineaIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=50)
    plantilla: str | None = None


class LineaNombreIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=50)


class LineaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str
    revisada: bool


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


class BodegaIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=80)
    tipo: TipoBodega


class BodegaOut(BaseModel):
    id: int
    nombre: str
    tipo: TipoBodega
    galpon_ids: list[int]


class BodegaBasicaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str
    tipo: TipoBodega


class GalponesIn(BaseModel):
    galpon_ids: list[int]


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
    bodega_id: int
    operacion_id: uuid.UUID | None = None
    fecha: date | None = None
    bultos: float | None = Field(default=None, gt=0)
    kg: float | None = Field(default=None, gt=0)


class AjusteIn(BaseModel):
    bodega_id: int
    fecha: date | None = None
    bultos_reales: float | None = Field(default=None, ge=0)
    kg_reales: float | None = Field(default=None, ge=0)
    nota: str = Field(default="", max_length=200)


class GastoIn(BaseModel):
    bodega_id: int
    operacion_id: uuid.UUID | None = None
    fecha: date | None = None
    bultos: float | None = Field(default=None, gt=0)
    kg: float | None = Field(default=None, gt=0)
    nota: str = Field(default="", max_length=200)


class PreparacionIn(BaseModel):
    operacion_id: uuid.UUID | None = None
    desde_bodega_id: int
    hacia_bodega_id: int
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
    bodega_id: int
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


class InventarioBodegaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    bodega: BodegaBasicaOut
    galpon_ids: list[int]
    existencias: list[ExistenciaOut]
    etapas: list[CoberturaEtapaOut]


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
    origen_id: int
    origen: str


class InventarioOut(BaseModel):
    bodegas: list[InventarioBodegaOut]
    mezclas: list[MezclaPosibleOut]


class TareaPlanIn(BaseModel):
    id: int | None = None
    nombre: str = Field(min_length=1, max_length=80)
    tipo: TipoTarea
    semana_ideal: int = Field(ge=0, le=120)
    semana_max: int = Field(ge=0, le=120)
    nota: str = Field(default="", max_length=300)


class TareaPlanOut(TareaPlanIn):
    model_config = ConfigDict(from_attributes=True)
    id: int


class PuntoCurvaIO(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    semana: int = Field(ge=0, le=120)
    postura_pct: float = Field(ge=0, le=100)
    peso_g: float | None = Field(default=None, gt=0)


class CumplimientoIn(BaseModel):
    tarea_id: int
    fecha: date
    nota: str = Field(default="", max_length=300)


class CumplimientoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    lote_id: int
    tarea_id: int
    fecha: date
    nota: str


class PesajeIn(BaseModel):
    fecha: date
    peso_g: float = Field(gt=0)
    aves_pesadas: int = Field(gt=0)


class PesajeOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    lote_id: int
    fecha: date
    peso_g: float
    aves_pesadas: int


class TareaDelLoteOut(BaseModel):
    tarea_id: int
    nombre: str
    tipo: TipoTarea
    semana_ideal: int
    semana_max: int
    nota_plan: str
    estado: EstadoTarea
    aplicada_en: date | None
    nota: str
    cumplimiento_id: uuid.UUID | None


class ComparacionPesoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    fecha: date
    peso_g: float
    estandar_g: float
    diferencia_pct: float
    nivel: NivelPeso


class ComparacionPosturaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    fecha: date
    real_pct: float
    estandar_pct: float


class AlertaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    galpon_id: int
    galpon: str
    lote_id: int
    tipo: TipoAlerta
    nivel: Nivel
    titulo: str
    detalle: str
    recomendaciones: list[str]


class SanidadGalponOut(BaseModel):
    galpon_id: int
    galpon: str
    lote_id: int
    linea: str
    edad_semanas: int
    etapa: Etapa
    aves_vivas: int
    tareas: list[TareaDelLoteOut]
    pesajes: list[PesajeOut]
    peso: ComparacionPesoOut | None
    postura: ComparacionPosturaOut | None


class PanoramaOut(BaseModel):
    fecha: date
    alertas: list[AlertaOut]
    galpones: list[SanidadGalponOut]


class CategoriaHuevoIn(BaseModel):
    nombre: str = Field(min_length=1, max_length=50)


class CategoriaHuevoCambio(BaseModel):
    nombre: str | None = Field(default=None, min_length=1, max_length=50)
    activa: bool | None = None


class CategoriaHuevoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    nombre: str
    activa: bool


class MovimientoDineroIn(BaseModel):
    fecha: date
    rubro: Rubro
    valor: float = Field(gt=0)
    descripcion: str = Field(default="", max_length=300)
    lote_id: int | None = None
    categoria_id: int | None = None
    cantidad_huevos: int | None = Field(default=None, gt=0)
    contraparte: str = Field(default="", max_length=100)


class MovimientoDineroOut(MovimientoDineroIn):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    tipo: TipoMovimiento


class TotalRubroOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    rubro: Rubro
    total: float


class VentaPorCategoriaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    categoria_id: int | None
    categoria: str
    huevos: int
    valor: float
    precio_por_huevo: float | None


class ResultadoLoteOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    lote_id: int | None
    galpon: str
    ingresos: float
    egresos: float
    utilidad: float


class ResumenFinanzasOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    desde: date
    hasta: date
    ingresos: float
    egresos: float
    utilidad: float
    por_rubro: list[TotalRubroOut]
    huevos: list[VentaPorCategoriaOut]
    por_lote: list[ResultadoLoteOut]


class CantidadHuevoIn(BaseModel):
    categoria_id: int
    cajas: int = Field(default=0, ge=0)
    cartones: int = Field(default=0, ge=0)
    huevos: int = Field(default=0, ge=0)

    @property
    def total(self) -> int:
        return a_huevos(self.cajas, self.cartones, self.huevos)


class MovimientoBodegaHuevoIn(CantidadHuevoIn):
    operacion_id: uuid.UUID
    fecha: date | None = None
    nota: str = Field(default="", max_length=200)


class ConteoHuevoIn(CantidadHuevoIn):
    fecha: date | None = None
    nota: str = Field(default="", max_length=200)


class MovimientoHuevoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    fecha: date
    categoria_id: int
    huevos: int
    motivo: MotivoHuevo
    nota: str


class PrecioHuevoIo(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    categoria_id: int
    precio_caja: float | None = Field(default=None, gt=0)
    precio_carton: float | None = Field(default=None, gt=0)
    precio_mayorista: float | None = Field(default=None, gt=0)


class LineaSalidaOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    categoria_id: int
    huevos_sacados: int
    huevos_vendidos: int | None
    valor: float | None


class SalidaHuevoOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: uuid.UUID
    fecha: date
    tipo_venta: TipoVenta
    cliente: str
    estado: EstadoSalida
    cerrada_el: date | None
    valor_total: float | None
    lineas: list[LineaSalidaOut]


class SalidaHuevoIn(BaseModel):
    fecha: date | None = None
    tipo_venta: TipoVenta
    cliente: str = Field(default="", max_length=100)
    lineas: list[CantidadHuevoIn] = Field(min_length=1)


class VentaHuevoIn(SalidaHuevoIn):
    valor_cobrado: float | None = Field(default=None, gt=0)


class CierreSalidaIn(BaseModel):
    fecha: date | None = None
    vendidos: list[CantidadHuevoIn] | None = None
    valor_cobrado: float | None = Field(default=None, gt=0)


class ExistenciaHuevoOut(BaseModel):
    categoria_id: int
    categoria: str
    activa: bool
    huevos: int
    cajas: int
    cartones: int
    sueltos: int


class BodegaHuevoOut(BaseModel):
    existencias: list[ExistenciaHuevoOut]
    precios: list[PrecioHuevoIo]
    abiertas: list[SalidaHuevoOut]
