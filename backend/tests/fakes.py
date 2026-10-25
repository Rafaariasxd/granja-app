from dataclasses import replace
from datetime import date

from app.dominio.modelos import (
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

    def stocks(self) -> dict[int, float]:
        totales: dict[int, float] = {}
        for m in self._movimientos.filas.values():
            totales[m.insumo_id] = totales.get(m.insumo_id, 0.0) + m.kg
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
        self.filas: dict[Etapa, int] = {}

    def definir(self, etapa: Etapa, insumo_id: int) -> None:
        self.filas[etapa] = insumo_id

    def de(self, etapa: Etapa) -> int | None:
        return self.filas.get(etapa)

    def todos(self) -> dict[Etapa, int]:
        return dict(self.filas)


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
        self.insumos = InsumosEnMemoria(self.movimientos)
        self.formulas = FormulasEnMemoria()
        self.alimento_en_uso = AlimentoEnUsoEnMemoria()
        self.confirmaciones = 0

    def confirmar(self) -> None:
        self.confirmaciones += 1
