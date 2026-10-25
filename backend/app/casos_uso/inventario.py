import uuid
from collections import defaultdict
from datetime import date, datetime, timedelta

from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import inventario as reglas
from app.dominio import produccion
from app.dominio.errores import Conflicto, DatosInvalidos, NoEncontrado
from app.dominio.modelos import (
    Bodega,
    CoberturaEtapa,
    EstadoInventario,
    Etapa,
    Evento,
    ExistenciaInsumo,
    Ingrediente,
    Insumo,
    InventarioBodega,
    MezclaPosible,
    Motivo,
    MovimientoInsumo,
    RegistroDiario,
    TipoBodega,
    TipoInsumo,
    Usuario,
)


def _insumo(uow: UnidadDeTrabajo, insumo_id: int) -> Insumo:
    insumo = uow.insumos.obtener(insumo_id)
    if insumo is None:
        raise NoEncontrado(f"el insumo {insumo_id} no existe")
    return insumo


def _bodega(uow: UnidadDeTrabajo, bodega_id: int, tipo: TipoBodega | None = None) -> Bodega:
    bodega = uow.bodegas.obtener(bodega_id)
    if bodega is None:
        raise NoEncontrado(f"la bodega {bodega_id} no existe")
    if tipo is not None and bodega.tipo != tipo:
        raise DatosInvalidos(f"{bodega.nombre} no es una bodega de {_texto_tipo(tipo)}")
    return bodega


def _texto_tipo(tipo: TipoBodega) -> str:
    return "materia prima" if tipo == TipoBodega.MATERIA_PRIMA else "alimento"


def _bodega_para(uow: UnidadDeTrabajo, insumo: Insumo, bodega_id: int) -> Bodega:
    return _bodega(uow, bodega_id, reglas.tipo_de_bodega_para(insumo.tipo))


def crear_bodega(uow: UnidadDeTrabajo, nombre: str, tipo: TipoBodega) -> Bodega:
    if uow.bodegas.por_nombre(nombre):
        raise Conflicto(f"ya existe una bodega llamada {nombre}")
    bodega = uow.bodegas.agregar(Bodega(nombre=nombre, tipo=tipo))
    uow.confirmar()
    return bodega


def listar_bodegas(uow: UnidadDeTrabajo) -> list[tuple[Bodega, list[int]]]:
    return [(b, uow.bodegas.galpones_de(b.id)) for b in uow.bodegas.listar()]


def asignar_galpones(
    uow: UnidadDeTrabajo, quien: Usuario, bodega_id: int, galpon_ids: list[int], ahora: datetime
) -> list[int]:
    """Qué galpones comen de esta bodega. Un galpón come de una sola bodega."""
    bodega = _bodega(uow, bodega_id, TipoBodega.ALIMENTO)
    if len(set(galpon_ids)) != len(galpon_ids):
        raise DatosInvalidos("un galpón está repetido")
    nombres = []
    for galpon_id in galpon_ids:
        galpon = uow.galpones.obtener(galpon_id)
        if galpon is None:
            raise NoEncontrado(f"el galpón {galpon_id} no existe")
        nombres.append(galpon.nombre)
    uow.bodegas.asignar_galpones(bodega.id, galpon_ids)
    detalle = f"{bodega.nombre}: {', '.join(nombres) or 'ninguno'}"
    uow.bitacora.agregar(Evento("galpones_de_bodega", detalle, quien.id, ahora))
    uow.confirmar()
    return galpon_ids


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
    bodega_id: int,
    fecha: date,
    bultos: float | None,
    kg: float | None,
    operacion_id: uuid.UUID | None = None,
) -> MovimientoInsumo:
    if operacion_id is not None and (previos := uow.movimientos.de_operacion(operacion_id)):
        return previos[0]
    insumo = _insumo(uow, insumo_id)
    if insumo.tipo not in reglas.REQUIEREN_BULTO:
        raise DatosInvalidos(f"{insumo.nombre} se prepara en la finca, no se compra")
    bodega = _bodega_para(uow, insumo, bodega_id)
    if (bultos is None) == (kg is None):
        raise DatosInvalidos("indica los bultos o los kilos, solo uno de los dos")
    cantidad = kg if kg is not None else reglas.kg_de_bultos(bultos, insumo.kg_por_bulto)
    if cantidad <= 0:
        raise DatosInvalidos("la compra debe ser mayor que cero")
    movimiento = uow.movimientos.agregar(
        MovimientoInsumo(insumo.id, bodega.id, fecha, cantidad, Motivo.COMPRA, quien.id, operacion_id=operacion_id)
    )
    uow.confirmar()
    return movimiento


def ajustar_stock(
    uow: UnidadDeTrabajo, quien: Usuario, insumo_id: int, bodega_id: int, fecha: date, kg_reales: float, nota: str
) -> MovimientoInsumo | None:
    """Cuando se cuenta lo que hay en una bodega y no coincide con lo que dice la app."""
    insumo = _insumo(uow, insumo_id)
    bodega = _bodega_para(uow, insumo, bodega_id)
    if kg_reales < 0:
        raise DatosInvalidos("lo que hay en bodega no puede ser negativo")
    actual = uow.insumos.stocks().get((bodega.id, insumo.id), 0.0)
    diferencia = round(kg_reales - actual, 3)
    if diferencia == 0:
        return None
    movimiento = uow.movimientos.agregar(
        MovimientoInsumo(insumo.id, bodega.id, fecha, diferencia, Motivo.AJUSTE, quien.id, nota)
    )
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
    uow: UnidadDeTrabajo,
    quien: Usuario,
    producto_id: int,
    desde_bodega_id: int,
    hacia_bodega_id: int,
    fecha: date,
    kg: float,
    operacion_id: uuid.UUID | None = None,
) -> MovimientoInsumo:
    if operacion_id is not None:
        for previo in uow.movimientos.de_operacion(operacion_id):
            if previo.motivo == Motivo.PREPARACION:
                return previo
    producto = _insumo(uow, producto_id)
    if producto.tipo != TipoInsumo.ALIMENTO_PREPARADO:
        raise DatosInvalidos(f"{producto.nombre} no es un alimento que se prepare en la finca")
    origen = _bodega(uow, desde_bodega_id, TipoBodega.MATERIA_PRIMA)
    destino = _bodega(uow, hacia_bodega_id, TipoBodega.ALIMENTO)
    if kg <= 0:
        raise DatosInvalidos("los kilos a preparar deben ser mayores que cero")
    ingredientes = uow.formulas.de(producto.id)
    if not ingredientes:
        raise DatosInvalidos(f"{producto.nombre} todavía no tiene fórmula")
    necesidad = reglas.kg_de_ingredientes(ingredientes, kg)
    existencias = {i: k for (b, i), k in uow.insumos.stocks().items() if b == origen.id}
    faltan = reglas.faltantes(necesidad, existencias)
    if faltan:
        detalle = ", ".join(f"{_insumo(uow, i).nombre} ({kg_falta} kg)" for i, kg_falta in faltan.items())
        raise DatosInvalidos(f"no alcanza la materia prima de {origen.nombre}, falta: {detalle}")
    nota = f"para {kg} kg de {producto.nombre}"
    for insumo_id, usados in necesidad.items():
        uow.movimientos.agregar(
            MovimientoInsumo(
                insumo_id, origen.id, fecha, -usados, Motivo.USO_EN_MEZCLA, quien.id, nota, operacion_id=operacion_id
            )
        )
    hecho = uow.movimientos.agregar(
        MovimientoInsumo(producto.id, destino.id, fecha, kg, Motivo.PREPARACION, quien.id, operacion_id=operacion_id)
    )
    uow.confirmar()
    return hecho


def definir_alimento_en_uso(
    uow: UnidadDeTrabajo, quien: Usuario, bodega_id: int, etapa: Etapa, insumo_id: int, ahora: datetime
) -> None:
    bodega = _bodega(uow, bodega_id, TipoBodega.ALIMENTO)
    insumo = _insumo(uow, insumo_id)
    if insumo.tipo not in reglas.SON_ALIMENTO or insumo.etapa != etapa:
        raise DatosInvalidos(f"{insumo.nombre} no es un alimento para la etapa {etapa.value}")
    uow.alimento_en_uso.definir(bodega.id, etapa, insumo.id)
    detalle = f"{bodega.nombre}, {etapa.value}: {insumo.nombre}"
    uow.bitacora.agregar(Evento("alimento_en_uso", detalle, quien.id, ahora))
    uow.confirmar()


def historial(uow: UnidadDeTrabajo, insumo_id: int, limite: int = 50) -> list[MovimientoInsumo]:
    _insumo(uow, insumo_id)
    return uow.movimientos.del_insumo(insumo_id, limite)


def descontar_consumo(uow: UnidadDeTrabajo, registro: RegistroDiario) -> None:
    """Resta de la bodega del galpón lo que el registro del día dice que se comió."""
    lote = uow.lotes.obtener(registro.lote_id)
    bodega_id = uow.bodegas.de_galpon(lote.galpon_id)
    insumo_id = None
    if bodega_id is not None:
        insumo_id = uow.alimento_en_uso.de(bodega_id, produccion.etapa(lote.fecha_nacimiento, registro.fecha))
    if insumo_id is None or registro.alimento_kg <= 0:
        uow.movimientos.quitar_consumo(registro.id)
        return
    uow.movimientos.guardar_consumo(
        MovimientoInsumo(
            insumo_id, bodega_id, registro.fecha, -registro.alimento_kg, Motivo.CONSUMO, None, "", registro.id
        )
    )


def quitar_consumo(uow: UnidadDeTrabajo, registro_id: uuid.UUID) -> None:
    uow.movimientos.quitar_consumo(registro_id)


def _consumo_por_bodega_y_etapa(
    uow: UnidadDeTrabajo, hoy: date, bodega_de_galpon: dict[int, int]
) -> dict[tuple[int, Etapa], float]:
    desde = hoy - timedelta(days=reglas.VENTANA_CONSUMO_DIAS - 1)
    por_clave: dict[tuple[int, Etapa], dict[date, float]] = defaultdict(lambda: defaultdict(float))
    lotes: dict[int, tuple[int, date]] = {}
    for registro in uow.registros.entre(desde, hoy):
        if registro.lote_id not in lotes:
            lote = uow.lotes.obtener(registro.lote_id)
            lotes[registro.lote_id] = (lote.galpon_id, lote.fecha_nacimiento)
        galpon_id, nacimiento = lotes[registro.lote_id]
        bodega_id = bodega_de_galpon.get(galpon_id)
        if bodega_id is None:
            continue
        etapa = produccion.etapa(nacimiento, registro.fecha)
        por_clave[(bodega_id, etapa)][registro.fecha] += registro.alimento_kg
    consumos = {clave: reglas.consumo_diario(dias, hoy) for clave, dias in por_clave.items()}
    return {clave: kg for clave, kg in consumos.items() if kg is not None}


def estado_inventario(uow: UnidadDeTrabajo, hoy: date) -> EstadoInventario:
    bodegas = uow.bodegas.listar()
    insumos = uow.insumos.listar()
    por_id = {i.id: i for i in insumos}
    stocks = uow.insumos.stocks()
    en_uso = uow.alimento_en_uso.todos()
    formulas = uow.formulas.todas()
    galpones_de = {b.id: uow.bodegas.galpones_de(b.id) for b in bodegas}
    bodega_de_galpon = {g: b for b, galpones in galpones_de.items() for g in galpones}
    consumo = _consumo_por_bodega_y_etapa(uow, hoy, bodega_de_galpon)

    gasto_materia: dict[int, float] = defaultdict(float)
    consumo_de_producto: dict[int, float] = defaultdict(float)
    for (bodega_id, etapa), producto_id in en_uso.items():
        diario = consumo.get((bodega_id, etapa))
        if diario is None:
            continue
        consumo_de_producto[producto_id] += diario
        for ingrediente in formulas.get(producto_id, []):
            gasto_materia[ingrediente.insumo_id] += diario * ingrediente.porcentaje / 100

    resultado = []
    for bodega in bodegas:
        if bodega.tipo == TipoBodega.MATERIA_PRIMA:
            propios = [i for i in insumos if i.tipo == TipoInsumo.MATERIA_PRIMA]
        else:
            usados = {i for (b, _), i in en_uso.items() if b == bodega.id}
            propios = [
                i for i in insumos if i.tipo in reglas.SON_ALIMENTO and ((bodega.id, i.id) in stocks or i.id in usados)
            ]
        existencias = []
        for insumo in propios:
            stock = round(stocks.get((bodega.id, insumo.id), 0.0), 3)
            if insumo.tipo == TipoInsumo.MATERIA_PRIMA:
                diario = gasto_materia.get(insumo.id)
            else:
                diario = consumo.get((bodega.id, insumo.etapa))
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
        if bodega.tipo == TipoBodega.ALIMENTO:
            for etapa in Etapa:
                del_etapa = [e for e in existencias if e.insumo.etapa == etapa]
                if not del_etapa and (bodega.id, etapa) not in consumo:
                    continue
                stock = round(sum(e.stock_kg for e in del_etapa), 3)
                diario = consumo.get((bodega.id, etapa))
                dias = reglas.dias_de_alcance(stock, diario)
                etapas.append(
                    CoberturaEtapa(
                        etapa, diario, stock, dias, reglas.nivel_de_alcance(dias), en_uso.get((bodega.id, etapa))
                    )
                )
        resultado.append(InventarioBodega(bodega, galpones_de[bodega.id], existencias, etapas))

    mezclas = []
    for producto_id, ingredientes in formulas.items():
        producto = por_id[producto_id]
        en_bodegas = sum(k for (_, i), k in stocks.items() if i == producto_id)
        for origen in (b for b in bodegas if b.tipo == TipoBodega.MATERIA_PRIMA):
            existencias = {i: k for (b, i), k in stocks.items() if b == origen.id}
            kg_posibles, limitante = reglas.mezcla_posible(ingredientes, existencias)
            dias = reglas.dias_de_alcance(en_bodegas + kg_posibles, consumo_de_producto.get(producto_id))
            mezclas.append(
                MezclaPosible(
                    producto_id=producto_id,
                    producto=producto.nombre,
                    stock_kg=round(en_bodegas, 3),
                    kg_posibles=kg_posibles,
                    limitante_id=limitante,
                    limitante=por_id[limitante].nombre,
                    dias=dias,
                    nivel=reglas.nivel_de_alcance(dias),
                    origen_id=origen.id,
                    origen=origen.nombre,
                )
            )
    return EstadoInventario(resultado, mezclas)
