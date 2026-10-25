import uuid
from collections import defaultdict
from datetime import date, datetime, timedelta

from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import inventario as reglas
from app.dominio import produccion
from app.dominio.errores import Conflicto, DatosInvalidos, NoEncontrado
from app.dominio.modelos import (
    CoberturaEtapa,
    EstadoInventario,
    Etapa,
    Evento,
    ExistenciaInsumo,
    Ingrediente,
    Insumo,
    MezclaPosible,
    Motivo,
    MovimientoInsumo,
    RegistroDiario,
    TipoInsumo,
    Usuario,
)


def _insumo(uow: UnidadDeTrabajo, insumo_id: int) -> Insumo:
    insumo = uow.insumos.obtener(insumo_id)
    if insumo is None:
        raise NoEncontrado(f"el insumo {insumo_id} no existe")
    return insumo


def crear_insumo(
    uow: UnidadDeTrabajo, nombre: str, tipo: TipoInsumo, etapa: Etapa | None, kg_por_bulto: float | None
) -> Insumo:
    reglas.validar_insumo(tipo, etapa, kg_por_bulto)
    if uow.insumos.por_nombre(nombre):
        raise Conflicto(f"ya existe un insumo llamado {nombre}")
    insumo = uow.insumos.agregar(Insumo(nombre=nombre, tipo=tipo, kg_por_bulto=kg_por_bulto, etapa=etapa))
    uow.confirmar()
    return insumo


def listar_insumos(uow: UnidadDeTrabajo) -> list[Insumo]:
    return uow.insumos.listar()


def registrar_compra(
    uow: UnidadDeTrabajo,
    quien: Usuario,
    insumo_id: int,
    fecha: date,
    bultos: float | None,
    kg: float | None,
) -> MovimientoInsumo:
    insumo = _insumo(uow, insumo_id)
    if insumo.tipo not in reglas.REQUIEREN_BULTO:
        raise DatosInvalidos(f"{insumo.nombre} se prepara en la finca, no se compra")
    if (bultos is None) == (kg is None):
        raise DatosInvalidos("indica los bultos o los kilos, solo uno de los dos")
    cantidad = kg if kg is not None else reglas.kg_de_bultos(bultos, insumo.kg_por_bulto)
    if cantidad <= 0:
        raise DatosInvalidos("la compra debe ser mayor que cero")
    movimiento = uow.movimientos.agregar(MovimientoInsumo(insumo.id, fecha, cantidad, Motivo.COMPRA, quien.id))
    uow.confirmar()
    return movimiento


def ajustar_stock(
    uow: UnidadDeTrabajo, quien: Usuario, insumo_id: int, fecha: date, kg_reales: float, nota: str
) -> MovimientoInsumo | None:
    """Cuando se cuenta lo que hay en bodega y no coincide con lo que dice la app."""
    insumo = _insumo(uow, insumo_id)
    if kg_reales < 0:
        raise DatosInvalidos("lo que hay en bodega no puede ser negativo")
    diferencia = round(kg_reales - uow.insumos.stocks().get(insumo.id, 0.0), 3)
    if diferencia == 0:
        return None
    movimiento = uow.movimientos.agregar(MovimientoInsumo(insumo.id, fecha, diferencia, Motivo.AJUSTE, quien.id, nota))
    uow.confirmar()
    return movimiento


def definir_formula(
    uow: UnidadDeTrabajo, quien: Usuario, producto_id: int, ingredientes: list[Ingrediente], ahora: datetime
) -> list[Ingrediente]:
    producto = _insumo(uow, producto_id)
    if producto.tipo != TipoInsumo.ALIMENTO_PREPARADO:
        raise DatosInvalidos(f"{producto.nombre} no es un alimento que se prepare en la finca")
    reglas.validar_formula(ingredientes)
    for ingrediente in ingredientes:
        if _insumo(uow, ingrediente.insumo_id).tipo != TipoInsumo.MATERIA_PRIMA:
            raise DatosInvalidos("solo las materias primas pueden ser ingredientes")
    uow.formulas.guardar(producto.id, ingredientes)
    detalle = ", ".join(f"{_insumo(uow, i.insumo_id).nombre} {i.porcentaje}%" for i in ingredientes)
    uow.bitacora.agregar(Evento("formula_definida", f"{producto.nombre}: {detalle}", quien.id, ahora))
    uow.confirmar()
    return ingredientes


def formula_de(uow: UnidadDeTrabajo, producto_id: int) -> list[Ingrediente]:
    _insumo(uow, producto_id)
    return uow.formulas.de(producto_id)


def preparar_alimento(
    uow: UnidadDeTrabajo, quien: Usuario, producto_id: int, fecha: date, kg: float
) -> MovimientoInsumo:
    producto = _insumo(uow, producto_id)
    if kg <= 0:
        raise DatosInvalidos("los kilos a preparar deben ser mayores que cero")
    ingredientes = uow.formulas.de(producto.id)
    if not ingredientes:
        raise DatosInvalidos(f"{producto.nombre} todavía no tiene fórmula")
    necesidad = reglas.kg_de_ingredientes(ingredientes, kg)
    faltan = reglas.faltantes(necesidad, uow.insumos.stocks())
    if faltan:
        detalle = ", ".join(f"{_insumo(uow, i).nombre} ({kg_falta} kg)" for i, kg_falta in faltan.items())
        raise DatosInvalidos(f"no alcanza la materia prima, falta: {detalle}")
    nota = f"para {kg} kg de {producto.nombre}"
    for insumo_id, usados in necesidad.items():
        uow.movimientos.agregar(MovimientoInsumo(insumo_id, fecha, -usados, Motivo.USO_EN_MEZCLA, quien.id, nota))
    hecho = uow.movimientos.agregar(MovimientoInsumo(producto.id, fecha, kg, Motivo.PREPARACION, quien.id))
    uow.confirmar()
    return hecho


def definir_alimento_en_uso(
    uow: UnidadDeTrabajo, quien: Usuario, etapa: Etapa, insumo_id: int, ahora: datetime
) -> None:
    insumo = _insumo(uow, insumo_id)
    if insumo.tipo not in reglas.SON_ALIMENTO or insumo.etapa != etapa:
        raise DatosInvalidos(f"{insumo.nombre} no es un alimento para la etapa {etapa.value}")
    uow.alimento_en_uso.definir(etapa, insumo.id)
    uow.bitacora.agregar(Evento("alimento_en_uso", f"{etapa.value}: {insumo.nombre}", quien.id, ahora))
    uow.confirmar()


def historial(uow: UnidadDeTrabajo, insumo_id: int, limite: int = 50) -> list[MovimientoInsumo]:
    _insumo(uow, insumo_id)
    return uow.movimientos.del_insumo(insumo_id, limite)


def descontar_consumo(uow: UnidadDeTrabajo, registro: RegistroDiario) -> None:
    """Resta del alimento en uso lo que el registro del día dice que se comió."""
    lote = uow.lotes.obtener(registro.lote_id)
    insumo_id = uow.alimento_en_uso.de(produccion.etapa(lote.fecha_nacimiento, registro.fecha))
    if insumo_id is None or registro.alimento_kg <= 0:
        uow.movimientos.quitar_consumo(registro.id)
        return
    uow.movimientos.guardar_consumo(
        MovimientoInsumo(insumo_id, registro.fecha, -registro.alimento_kg, Motivo.CONSUMO, None, "", registro.id)
    )


def quitar_consumo(uow: UnidadDeTrabajo, registro_id: uuid.UUID) -> None:
    uow.movimientos.quitar_consumo(registro_id)


def _consumo_por_etapa(uow: UnidadDeTrabajo, hoy: date) -> dict[Etapa, float | None]:
    desde = hoy - timedelta(days=reglas.VENTANA_CONSUMO_DIAS - 1)
    por_etapa: dict[Etapa, dict[date, float]] = defaultdict(lambda: defaultdict(float))
    nacimientos: dict[int, date] = {}
    for registro in uow.registros.entre(desde, hoy):
        if registro.lote_id not in nacimientos:
            nacimientos[registro.lote_id] = uow.lotes.obtener(registro.lote_id).fecha_nacimiento
        etapa = produccion.etapa(nacimientos[registro.lote_id], registro.fecha)
        por_etapa[etapa][registro.fecha] += registro.alimento_kg
    consumos = {etapa: reglas.consumo_diario(dias, hoy) for etapa, dias in por_etapa.items()}
    return {etapa: kg for etapa, kg in consumos.items() if kg is not None}


def estado_inventario(uow: UnidadDeTrabajo, hoy: date) -> EstadoInventario:
    insumos = uow.insumos.listar()
    stocks = uow.insumos.stocks()
    consumo = _consumo_por_etapa(uow, hoy)
    en_uso = uow.alimento_en_uso.todos()
    formulas = uow.formulas.todas()
    por_id = {i.id: i for i in insumos}

    gasto_materia: dict[int, float] = defaultdict(float)
    for producto_id, ingredientes in formulas.items():
        etapa = por_id[producto_id].etapa
        if en_uso.get(etapa) != producto_id or etapa not in consumo:
            continue
        for ingrediente in ingredientes:
            gasto_materia[ingrediente.insumo_id] += consumo[etapa] * ingrediente.porcentaje / 100

    existencias = []
    for insumo in insumos:
        stock = round(stocks.get(insumo.id, 0.0), 3)
        if insumo.tipo == TipoInsumo.MATERIA_PRIMA:
            diario = gasto_materia.get(insumo.id)
        else:
            diario = consumo.get(insumo.etapa)
        dias = reglas.dias_de_alcance(stock, diario)
        existencias.append(
            ExistenciaInsumo(
                insumo=insumo,
                stock_kg=stock,
                bultos=reglas.bultos_de_kg(stock, insumo.kg_por_bulto),
                consumo_diario_kg=round(diario, 2) if diario else None,
                dias=dias,
                nivel=reglas.nivel_de_alcance(dias),
            )
        )

    etapas = []
    for etapa in Etapa:
        alimentos = [i for i in insumos if i.tipo in reglas.SON_ALIMENTO and i.etapa == etapa]
        if not alimentos and etapa not in consumo:
            continue
        stock = round(sum(stocks.get(i.id, 0.0) for i in alimentos), 3)
        dias = reglas.dias_de_alcance(stock, consumo.get(etapa))
        etapas.append(
            CoberturaEtapa(etapa, consumo.get(etapa), stock, dias, reglas.nivel_de_alcance(dias), en_uso.get(etapa))
        )

    mezclas = []
    for producto_id, ingredientes in formulas.items():
        producto = por_id[producto_id]
        kg_posibles, limitante = reglas.mezcla_posible(ingredientes, stocks)
        stock_producto = round(stocks.get(producto_id, 0.0), 3)
        dias = reglas.dias_de_alcance(stock_producto + kg_posibles, consumo.get(producto.etapa))
        mezclas.append(
            MezclaPosible(
                producto_id=producto_id,
                producto=producto.nombre,
                stock_kg=stock_producto,
                kg_posibles=kg_posibles,
                limitante_id=limitante,
                limitante=por_id[limitante].nombre,
                dias=dias,
                nivel=reglas.nivel_de_alcance(dias),
            )
        )
    return EstadoInventario(existencias, etapas, mezclas)
