from dataclasses import replace
from datetime import date

from app.dominio.finanzas import CategoriaHuevo, MovimientoDinero
from app.dominio.huevos import EstadoSalida, MovimientoHuevo, PrecioHuevo, SalidaHuevo
from app.dominio.modelos import (
    Bodega,
    Etapa,
    Evento,
    Galpon,
    Ingrediente,
    Insumo,
    LineaGenetica,
    Lote,
    MovimientoInsumo,
    RegistroDiario,
    Sesion,
    Usuario,
)
from app.dominio.sanidad import Cumplimiento, Pesaje, PuntoCurva, TareaPlan


class _Tabla:
    def __init__(self) -> None:
        self.filas: dict = {}

    def _insertar(self, entidad):
        entidad = replace(entidad, id=len(self.filas) + 1)
        self.filas[entidad.id] = entidad
        return replace(entidad)

    def obtener(self, id_):
        fila = self.filas.get(id_)
        return replace(fila) if fila else None


class GalponesEnMemoria(_Tabla):
    def agregar(self, galpon: Galpon) -> Galpon:
        return self._insertar(galpon)

    def por_nombre(self, nombre: str) -> Galpon | None:
        return next((replace(g) for g in self.filas.values() if g.nombre == nombre), None)

    def listar(self) -> list[Galpon]:
        return sorted((replace(g) for g in self.filas.values()), key=lambda g: g.nombre)


class LineasEnMemoria(_Tabla):
    def agregar(self, linea: LineaGenetica) -> LineaGenetica:
        return self._insertar(linea)

    def por_nombre(self, nombre: str) -> LineaGenetica | None:
        return next((replace(x) for x in self.filas.values() if x.nombre == nombre), None)

    def listar(self) -> list[LineaGenetica]:
        return sorted((replace(x) for x in self.filas.values()), key=lambda x: x.nombre)

    def actualizar(self, linea: LineaGenetica) -> LineaGenetica:
        self.filas[linea.id] = replace(linea)
        return replace(linea)


class LotesEnMemoria(_Tabla):
    def agregar(self, lote: Lote) -> Lote:
        return self._insertar(lote)

    def del_galpon(self, galpon_id: int) -> list[Lote]:
        return [replace(x) for x in self.filas.values() if x.galpon_id == galpon_id]

    def actualizar(self, lote: Lote) -> Lote:
        self.filas[lote.id] = replace(lote)
        return replace(lote)


class RegistrosEnMemoria:
    def __init__(self) -> None:
        self.filas: dict = {}

    def del_dia(self, lote_id: int, fecha: date) -> RegistroDiario | None:
        return next((replace(r) for r in self.filas.values() if (r.lote_id, r.fecha) == (lote_id, fecha)), None)

    def guardar(self, registro: RegistroDiario) -> RegistroDiario:
        self.filas[registro.id] = replace(registro)
        return replace(registro)

    def mortalidad_hasta(self, lote_id: int, fecha: date) -> int:
        return sum(r.mortalidad for r in self.filas.values() if r.lote_id == lote_id and r.fecha <= fecha)

    def ultima_fecha(self, lote_id: int) -> date | None:
        return max((r.fecha for r in self.filas.values() if r.lote_id == lote_id), default=None)

    def obtener(self, registro_id):
        fila = self.filas.get(registro_id)
        return replace(fila) if fila else None

    def eliminar(self, registro_id) -> None:
        self.filas.pop(registro_id, None)

    def entre(self, desde: date, hasta: date) -> list[RegistroDiario]:
        return [replace(r) for r in self.filas.values() if desde <= r.fecha <= hasta]


class UsuariosEnMemoria(_Tabla):
    def agregar(self, usuario: Usuario) -> Usuario:
        return self._insertar(usuario)

    def por_nombre(self, nombre: str) -> Usuario | None:
        return next((replace(u) for u in self.filas.values() if u.nombre == nombre), None)

    def listar(self) -> list[Usuario]:
        return sorted((replace(u) for u in self.filas.values()), key=lambda u: u.nombre)

    def actualizar(self, usuario: Usuario) -> Usuario:
        self.filas[usuario.id] = replace(usuario)
        return replace(usuario)


class SesionesEnMemoria(_Tabla):
    def agregar(self, sesion: Sesion) -> Sesion:
        return self._insertar(sesion)

    def por_token_hash(self, token_hash: str) -> Sesion | None:
        return next((replace(s) for s in self.filas.values() if s.token_hash == token_hash), None)

    def revocar(self, sesion_id: int) -> None:
        self.filas[sesion_id].revocada = True

    def revocar_de_usuario(self, usuario_id: int) -> None:
        for s in self.filas.values():
            if s.usuario_id == usuario_id:
                s.revocada = True


class BitacoraEnMemoria(_Tabla):
    def agregar(self, evento: Evento) -> Evento:
        return self._insertar(evento)

    def listar(self) -> list[Evento]:
        return list(self.filas.values())


class InsumosEnMemoria(_Tabla):
    def __init__(self, movimientos: "MovimientosEnMemoria") -> None:
        super().__init__()
        self._movimientos = movimientos

    def agregar(self, insumo: Insumo) -> Insumo:
        return self._insertar(insumo)

    def por_nombre(self, nombre: str) -> Insumo | None:
        return next((replace(i) for i in self.filas.values() if i.nombre == nombre), None)

    def listar(self) -> list[Insumo]:
        return sorted((replace(i) for i in self.filas.values()), key=lambda i: i.nombre)

    def stocks(self) -> dict[tuple[int, int], float]:
        totales: dict[tuple[int, int], float] = {}
        for m in self._movimientos.filas.values():
            clave = (m.bodega_id, m.insumo_id)
            totales[clave] = totales.get(clave, 0.0) + m.kg
        return totales


class MovimientosEnMemoria(_Tabla):
    def agregar(self, movimiento: MovimientoInsumo) -> MovimientoInsumo:
        return self._insertar(movimiento)

    def guardar_consumo(self, movimiento: MovimientoInsumo) -> None:
        previo = next((m for m in self.filas.values() if m.registro_id == movimiento.registro_id), None)
        if previo is None:
            self._insertar(movimiento)
        else:
            self.filas[previo.id] = replace(movimiento, id=previo.id)

    def quitar_consumo(self, registro_id) -> None:
        for id_ in [m.id for m in self.filas.values() if m.registro_id == registro_id]:
            del self.filas[id_]

    def de_operacion(self, operacion_id) -> list[MovimientoInsumo]:
        return [replace(m) for m in self.filas.values() if m.operacion_id == operacion_id]

    def del_insumo(self, insumo_id: int, limite: int) -> list[MovimientoInsumo]:
        propios = [replace(m) for m in self.filas.values() if m.insumo_id == insumo_id]
        return sorted(propios, key=lambda m: (m.fecha, m.id), reverse=True)[:limite]


class FormulasEnMemoria:
    def __init__(self) -> None:
        self.filas: dict[int, list[Ingrediente]] = {}

    def guardar(self, producto_id: int, ingredientes: list[Ingrediente]) -> None:
        self.filas[producto_id] = list(ingredientes)

    def de(self, producto_id: int) -> list[Ingrediente]:
        return list(self.filas.get(producto_id, []))

    def todas(self) -> dict[int, list[Ingrediente]]:
        return {k: list(v) for k, v in self.filas.items()}


class AlimentoEnUsoEnMemoria:
    def __init__(self) -> None:
        self.filas: dict[tuple[int, Etapa], int] = {}

    def definir(self, bodega_id: int, etapa: Etapa, insumo_id: int) -> None:
        self.filas[(bodega_id, etapa)] = insumo_id

    def de(self, bodega_id: int, etapa: Etapa) -> int | None:
        return self.filas.get((bodega_id, etapa))

    def todos(self) -> dict[tuple[int, Etapa], int]:
        return dict(self.filas)


class BodegasEnMemoria(_Tabla):
    def __init__(self) -> None:
        super().__init__()
        self.asignaciones: dict[int, int] = {}

    def agregar(self, bodega: Bodega) -> Bodega:
        return self._insertar(bodega)

    def por_nombre(self, nombre: str) -> Bodega | None:
        return next((replace(b) for b in self.filas.values() if b.nombre == nombre), None)

    def listar(self) -> list[Bodega]:
        return sorted((replace(b) for b in self.filas.values()), key=lambda b: b.id)

    def asignar_galpones(self, bodega_id: int, galpon_ids: list[int]) -> None:
        self.asignaciones = {g: b for g, b in self.asignaciones.items() if b != bodega_id and g not in galpon_ids}
        for galpon_id in galpon_ids:
            self.asignaciones[galpon_id] = bodega_id

    def galpones_de(self, bodega_id: int) -> list[int]:
        return sorted(g for g, b in self.asignaciones.items() if b == bodega_id)

    def de_galpon(self, galpon_id: int) -> int | None:
        return self.asignaciones.get(galpon_id)


class CurvasEnMemoria:
    def __init__(self) -> None:
        self.filas: dict[int, list[PuntoCurva]] = {}

    def guardar(self, linea_id: int, puntos: list[PuntoCurva]) -> None:
        self.filas[linea_id] = sorted(puntos, key=lambda p: p.semana)

    def de(self, linea_id: int) -> list[PuntoCurva]:
        return list(self.filas.get(linea_id, []))


class PlanEnMemoria(_Tabla):
    def guardar(self, linea_id: int, tareas: list[TareaPlan]) -> list[TareaPlan]:
        conservadas = {t.id for t in tareas if t.id is not None}
        for id_, fila in self.filas.items():
            if fila.linea_id == linea_id and id_ not in conservadas:
                fila.activa = False
        guardadas = []
        for t in tareas:
            if t.id is not None and t.id in self.filas:
                self.filas[t.id] = replace(t, linea_id=linea_id, activa=True)
                guardadas.append(replace(self.filas[t.id]))
            else:
                guardadas.append(self._insertar(replace(t, id=None, linea_id=linea_id, activa=True)))
        return guardadas

    def de(self, linea_id: int) -> list[TareaPlan]:
        return sorted((replace(t) for t in self.filas.values() if t.linea_id == linea_id), key=lambda t: t.id)


class CumplimientosEnMemoria:
    def __init__(self) -> None:
        self.filas: dict = {}

    def guardar(self, cumplimiento: Cumplimiento) -> Cumplimiento:
        self.filas[cumplimiento.id] = replace(cumplimiento)
        return replace(cumplimiento)

    def obtener(self, cumplimiento_id):
        fila = self.filas.get(cumplimiento_id)
        return replace(fila) if fila else None

    def del_lote(self, lote_id: int) -> list[Cumplimiento]:
        return [replace(c) for c in self.filas.values() if c.lote_id == lote_id]

    def quitar(self, cumplimiento_id) -> None:
        self.filas.pop(cumplimiento_id, None)


class PesajesEnMemoria:
    def __init__(self) -> None:
        self.filas: dict = {}

    def guardar(self, pesaje: Pesaje) -> Pesaje:
        self.filas[pesaje.id] = replace(pesaje)
        return replace(pesaje)

    def obtener(self, pesaje_id):
        fila = self.filas.get(pesaje_id)
        return replace(fila) if fila else None

    def del_lote(self, lote_id: int) -> list[Pesaje]:
        return sorted((replace(p) for p in self.filas.values() if p.lote_id == lote_id), key=lambda p: p.fecha)

    def quitar(self, pesaje_id) -> None:
        self.filas.pop(pesaje_id, None)


class CategoriasEnMemoria(_Tabla):
    def agregar(self, categoria: CategoriaHuevo) -> CategoriaHuevo:
        return self._insertar(categoria)

    def por_nombre(self, nombre: str) -> CategoriaHuevo | None:
        return next((replace(c) for c in self.filas.values() if c.nombre == nombre), None)

    def listar(self) -> list[CategoriaHuevo]:
        return sorted((replace(c) for c in self.filas.values()), key=lambda c: c.id)

    def actualizar(self, categoria: CategoriaHuevo) -> CategoriaHuevo:
        self.filas[categoria.id] = replace(categoria)
        return replace(categoria)


class DineroEnMemoria:
    def __init__(self) -> None:
        self.filas: dict = {}

    def guardar(self, movimiento: MovimientoDinero) -> MovimientoDinero:
        self.filas[movimiento.id] = replace(movimiento)
        return replace(movimiento)

    def obtener(self, movimiento_id):
        fila = self.filas.get(movimiento_id)
        return replace(fila) if fila else None

    def eliminar(self, movimiento_id) -> None:
        self.filas.pop(movimiento_id, None)

    def entre(self, desde: date, hasta: date) -> list[MovimientoDinero]:
        return sorted(
            (replace(m) for m in self.filas.values() if desde <= m.fecha <= hasta), key=lambda m: m.fecha, reverse=True
        )


class HuevosEnMemoria(_Tabla):
    def agregar(self, movimiento: MovimientoHuevo) -> MovimientoHuevo:
        return self._insertar(movimiento)

    def de_operacion(self, operacion_id) -> list[MovimientoHuevo]:
        return [replace(m) for m in self.filas.values() if m.operacion_id == operacion_id]

    def stocks(self) -> dict[int, int]:
        totales: dict[int, int] = {}
        for m in self.filas.values():
            totales[m.categoria_id] = totales.get(m.categoria_id, 0) + m.huevos
        return totales


class PreciosHuevoEnMemoria:
    def __init__(self) -> None:
        self.filas: dict[int, PrecioHuevo] = {}

    def guardar(self, precio: PrecioHuevo) -> PrecioHuevo:
        self.filas[precio.categoria_id] = replace(precio)
        return replace(precio)

    def todos(self) -> list[PrecioHuevo]:
        return [replace(p) for _, p in sorted(self.filas.items())]


class SalidasEnMemoria:
    def __init__(self) -> None:
        self.filas: dict = {}

    def guardar(self, salida: SalidaHuevo) -> SalidaHuevo:
        self.filas[salida.id] = replace(salida, lineas=[replace(ln) for ln in salida.lineas])
        return salida

    def obtener(self, salida_id):
        fila = self.filas.get(salida_id)
        return replace(fila, lineas=[replace(ln) for ln in fila.lineas]) if fila else None

    def listar(self, estado: EstadoSalida | None = None) -> list[SalidaHuevo]:
        return [self.obtener(i) for i, s in self.filas.items() if estado is None or s.estado == estado]


class UnidadEnMemoria:
    def __init__(self) -> None:
        self.galpones = GalponesEnMemoria()
        self.lineas = LineasEnMemoria()
        self.lotes = LotesEnMemoria()
        self.registros = RegistrosEnMemoria()
        self.usuarios = UsuariosEnMemoria()
        self.sesiones = SesionesEnMemoria()
        self.bitacora = BitacoraEnMemoria()
        self.movimientos = MovimientosEnMemoria()
        self.bodegas = BodegasEnMemoria()
        self.insumos = InsumosEnMemoria(self.movimientos)
        self.formulas = FormulasEnMemoria()
        self.alimento_en_uso = AlimentoEnUsoEnMemoria()
        self.curvas = CurvasEnMemoria()
        self.plan = PlanEnMemoria()
        self.cumplimientos = CumplimientosEnMemoria()
        self.pesajes = PesajesEnMemoria()
        self.categorias = CategoriasEnMemoria()
        self.dinero = DineroEnMemoria()
        self.huevos = HuevosEnMemoria()
        self.precios_huevo = PreciosHuevoEnMemoria()
        self.salidas = SalidasEnMemoria()
        self.confirmaciones = 0

    def confirmar(self) -> None:
        self.confirmaciones += 1
