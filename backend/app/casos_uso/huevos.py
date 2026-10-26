import uuid
from dataclasses import dataclass
from datetime import date

from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import huevos as reglas
from app.dominio.errores import Conflicto, DatosInvalidos, NoEncontrado
from app.dominio.finanzas import MovimientoDinero, Rubro
from app.dominio.huevos import (
    EstadoSalida,
    ExistenciaHuevo,
    LineaSalida,
    MotivoHuevo,
    MovimientoHuevo,
    PrecioHuevo,
    SalidaHuevo,
    TipoVenta,
)
from app.dominio.modelos import Usuario

NOMBRES_DE_VENTA = {
    TipoVenta.CLIENTE: "cliente",
    TipoVenta.PARTICULAR: "particular",
    TipoVenta.MAYORISTA: "mayorista",
}


@dataclass(frozen=True)
class BodegaHuevo:
    existencias: list[ExistenciaHuevo]
    precios: list[PrecioHuevo]
    abiertas: list[SalidaHuevo]


def _categoria(uow: UnidadDeTrabajo, categoria_id: int):
    categoria = uow.categorias.obtener(categoria_id)
    if categoria is None:
        raise NoEncontrado(f"la categoría de huevo {categoria_id} no existe")
    return categoria


def _stock(uow: UnidadDeTrabajo, categoria_id: int) -> int:
    return uow.huevos.stocks().get(categoria_id, 0)


def bodega(uow: UnidadDeTrabajo) -> BodegaHuevo:
    stocks = uow.huevos.stocks()
    existencias = [
        ExistenciaHuevo(c.id, c.nombre, c.activa, stocks.get(c.id, 0))
        for c in uow.categorias.listar()
        if c.activa or stocks.get(c.id, 0) != 0
    ]
    return BodegaHuevo(existencias, uow.precios_huevo.todos(), uow.salidas.listar(EstadoSalida.ABIERTA))


def ingresar(
    uow: UnidadDeTrabajo, quien: Usuario, operacion_id: uuid.UUID, fecha: date, categoria_id: int, huevos: int
) -> MovimientoHuevo:
    """Es idempotente: el celular puede reenviarlo sin duplicar."""
    if previos := uow.huevos.de_operacion(operacion_id):
        return previos[0]
    _categoria(uow, categoria_id)
    if huevos <= 0:
        raise DatosInvalidos("lo que entra a la bodega debe ser mayor que cero")
    movimiento = uow.huevos.agregar(
        MovimientoHuevo(fecha, categoria_id, huevos, MotivoHuevo.INGRESO, quien.id, operacion_id=operacion_id)
    )
    uow.confirmar()
    return movimiento


def dar_de_baja(
    uow: UnidadDeTrabajo,
    quien: Usuario,
    operacion_id: uuid.UUID,
    fecha: date,
    categoria_id: int,
    huevos: int,
    nota: str,
) -> MovimientoHuevo:
    if previos := uow.huevos.de_operacion(operacion_id):
        return previos[0]
    categoria = _categoria(uow, categoria_id)
    if huevos <= 0:
        raise DatosInvalidos("lo que se da de baja debe ser mayor que cero")
    hay = _stock(uow, categoria_id)
    if huevos > hay:
        raise DatosInvalidos(f"no hay tantos huevos {categoria.nombre}: quedan {hay}")
    movimiento = uow.huevos.agregar(
        MovimientoHuevo(fecha, categoria_id, -huevos, MotivoHuevo.BAJA, quien.id, nota, operacion_id=operacion_id)
    )
    uow.confirmar()
    return movimiento


def contar(
    uow: UnidadDeTrabajo, quien: Usuario, fecha: date, categoria_id: int, huevos_reales: int, nota: str
) -> MovimientoHuevo | None:
    _categoria(uow, categoria_id)
    if huevos_reales < 0:
        raise DatosInvalidos("lo que hay en bodega no puede ser negativo")
    diferencia = huevos_reales - _stock(uow, categoria_id)
    if diferencia == 0:
        return None
    movimiento = uow.huevos.agregar(
        MovimientoHuevo(fecha, categoria_id, diferencia, MotivoHuevo.AJUSTE, quien.id, nota)
    )
    uow.confirmar()
    return movimiento


def fijar_precio(uow: UnidadDeTrabajo, precio: PrecioHuevo) -> PrecioHuevo:
    _categoria(uow, precio.categoria_id)
    reglas.validar_precio(precio)
    guardado = uow.precios_huevo.guardar(precio)
    uow.confirmar()
    return guardado


def _sacar(uow: UnidadDeTrabajo, quien: Usuario, salida: SalidaHuevo) -> None:
    reglas.validar_lineas(salida.lineas)
    stocks = uow.huevos.stocks()
    for linea in salida.lineas:
        categoria = _categoria(uow, linea.categoria_id)
        hay = stocks.get(linea.categoria_id, 0)
        if linea.huevos_sacados > hay:
            empaque = reglas.empacar(hay)
            raise DatosInvalidos(
                f"no hay tanto huevo {categoria.nombre}: quedan {empaque.cajas} cajas, "
                f"{empaque.cartones} cartones y {empaque.sueltos} huevos"
            )
    salida.estado = EstadoSalida.ABIERTA
    salida.usuario_id = quien.id
    uow.salidas.guardar(salida)
    for linea in salida.lineas:
        uow.huevos.agregar(
            MovimientoHuevo(
                salida.fecha,
                linea.categoria_id,
                -linea.huevos_sacados,
                MotivoHuevo.SALIDA,
                quien.id,
                salida_id=salida.id,
            )
        )


def abrir_salida(uow: UnidadDeTrabajo, quien: Usuario, salida: SalidaHuevo) -> SalidaHuevo:
    """Huevo que sale para vender y se liquida después. Es idempotente por el id de la salida."""
    if (previa := uow.salidas.obtener(salida.id)) is not None:
        return previa
    _sacar(uow, quien, salida)
    uow.confirmar()
    return uow.salidas.obtener(salida.id)


def _cerrar(
    uow: UnidadDeTrabajo,
    quien: Usuario,
    salida: SalidaHuevo,
    vendidos: dict[int, int] | None,
    valor_cobrado: float | None,
    fecha: date,
) -> None:
    sacados = {ln.categoria_id: ln.huevos_sacados for ln in salida.lineas}
    vendidos = dict(sacados) if vendidos is None else {c: vendidos.get(c, 0) for c in sacados}
    for categoria_id, cantidad in vendidos.items():
        if cantidad < 0 or cantidad > sacados[categoria_id]:
            nombre = _categoria(uow, categoria_id).nombre
            raise DatosInvalidos(f"de {nombre} salieron {sacados[categoria_id]} huevos: no se pueden vender {cantidad}")
    if sum(vendidos.values()) == 0 and valor_cobrado:
        raise DatosInvalidos("no se vendió nada: el total cobrado debe quedar vacío")
    precios = {p.categoria_id: p for p in uow.precios_huevo.todos()}
    valores: dict[int, float] = {}
    if sum(vendidos.values()) > 0:
        sugeridos = {c: reglas.precio_de_los_huevos(v, salida.tipo_venta, precios.get(c)) for c, v in vendidos.items()}
        valores = reglas.repartir_total(vendidos, sugeridos, valor_cobrado)
    for linea in salida.lineas:
        linea.huevos_vendidos = vendidos[linea.categoria_id]
        linea.valor = valores.get(linea.categoria_id, 0.0)
        sobran = linea.huevos_sacados - linea.huevos_vendidos
        if sobran > 0:
            uow.huevos.agregar(
                MovimientoHuevo(fecha, linea.categoria_id, sobran, MotivoHuevo.REINGRESO, quien.id, salida_id=salida.id)
            )
        if linea.huevos_vendidos > 0 and linea.valor > 0:
            uow.dinero.guardar(
                MovimientoDinero(
                    id=reglas.id_de_venta(salida.id, linea.categoria_id),
                    fecha=fecha,
                    rubro=Rubro.VENTA_HUEVO,
                    valor=linea.valor,
                    descripcion=f"Venta a {NOMBRES_DE_VENTA[salida.tipo_venta]}",
                    categoria_id=linea.categoria_id,
                    cantidad_huevos=linea.huevos_vendidos,
                    contraparte=salida.cliente,
                    usuario_id=quien.id,
                )
            )
    salida.estado = EstadoSalida.CERRADA
    salida.cerrada_el = fecha
    salida.valor_total = round(sum(valores.values()), 2)
    uow.salidas.guardar(salida)


def cerrar_salida(
    uow: UnidadDeTrabajo,
    quien: Usuario,
    salida_id: uuid.UUID,
    vendidos: dict[int, int] | None,
    valor_cobrado: float | None,
    fecha: date,
) -> SalidaHuevo:
    """Sin `vendidos` se vendió todo. Lo que no se vendió vuelve a la bodega."""
    salida = uow.salidas.obtener(salida_id)
    if salida is None:
        raise NoEncontrado(f"la salida {salida_id} no existe")
    if salida.estado == EstadoSalida.CERRADA:
        return salida
    if salida.estado == EstadoSalida.ANULADA:
        raise Conflicto("esa salida se anuló")
    _cerrar(uow, quien, salida, vendidos, valor_cobrado, fecha)
    uow.confirmar()
    return uow.salidas.obtener(salida_id)


def vender(uow: UnidadDeTrabajo, quien: Usuario, salida: SalidaHuevo, valor_cobrado: float | None) -> SalidaHuevo:
    """Venta que se entrega y se cobra en el momento: sale y se liquida de una vez."""
    if (previa := uow.salidas.obtener(salida.id)) is not None:
        return previa
    _sacar(uow, quien, salida)
    _cerrar(uow, quien, salida, None, valor_cobrado, salida.fecha)
    uow.confirmar()
    return uow.salidas.obtener(salida.id)


def anular_salida(uow: UnidadDeTrabajo, quien: Usuario, salida_id: uuid.UUID, fecha: date) -> SalidaHuevo:
    salida = uow.salidas.obtener(salida_id)
    if salida is None:
        raise NoEncontrado(f"la salida {salida_id} no existe")
    if salida.estado == EstadoSalida.ANULADA:
        return salida
    if salida.estado == EstadoSalida.CERRADA:
        raise Conflicto("esa salida ya se cerró: borra la venta desde Dinero si fue un error")
    for linea in salida.lineas:
        uow.huevos.agregar(
            MovimientoHuevo(
                fecha, linea.categoria_id, linea.huevos_sacados, MotivoHuevo.REINGRESO, quien.id, "anulada", salida.id
            )
        )
    salida.estado = EstadoSalida.ANULADA
    uow.salidas.guardar(salida)
    uow.confirmar()
    return salida


def nueva_salida(
    salida_id: uuid.UUID, fecha: date, tipo_venta: TipoVenta, cliente: str, lineas: list[tuple[int, int]]
) -> SalidaHuevo:
    return SalidaHuevo(
        id=salida_id,
        fecha=fecha,
        tipo_venta=tipo_venta,
        cliente=cliente,
        lineas=[LineaSalida(categoria_id, huevos) for categoria_id, huevos in lineas],
    )
