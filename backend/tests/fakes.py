from dataclasses import replace
from datetime import date

from app.dominio.modelos import Galpon, LineaGenetica, Lote, RegistroDiario


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


class UnidadEnMemoria:
    def __init__(self) -> None:
        self.galpones = GalponesEnMemoria()
        self.lineas = LineasEnMemoria()
        self.lotes = LotesEnMemoria()
        self.registros = RegistrosEnMemoria()
        self.confirmaciones = 0

    def confirmar(self) -> None:
        self.confirmaciones += 1
