from datetime import date

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.adaptadores.db.tablas import TablaGalpon, TablaLinea, TablaLote, TablaRegistro
from app.dominio.modelos import Galpon, LineaGenetica, Lote, RegistroDiario


def _galpon(fila: TablaGalpon) -> Galpon:
    return Galpon(id=fila.id, nombre=fila.nombre, capacidad_aves=fila.capacidad_aves, activo=fila.activo)


def _linea(fila: TablaLinea) -> LineaGenetica:
    return LineaGenetica(id=fila.id, nombre=fila.nombre)


def _lote(fila: TablaLote) -> Lote:
    return Lote(
        id=fila.id,
        galpon_id=fila.galpon_id,
        linea_id=fila.linea_id,
        fecha_nacimiento=fila.fecha_nacimiento,
        fecha_ingreso=fila.fecha_ingreso,
        aves_iniciales=fila.aves_iniciales,
        fecha_salida=fila.fecha_salida,
    )


def _registro(fila: TablaRegistro) -> RegistroDiario:
    return RegistroDiario(
        id=fila.id,
        lote_id=fila.lote_id,
        fecha=fila.fecha,
        huevos_total=fila.huevos_total,
        huevos_rotos=fila.huevos_rotos,
        mortalidad=fila.mortalidad,
        alimento_kg=fila.alimento_kg,
    )


class GalponesSql:
    def __init__(self, session: Session) -> None:
        self._session = session

    def agregar(self, galpon: Galpon) -> Galpon:
        fila = TablaGalpon(nombre=galpon.nombre, capacidad_aves=galpon.capacidad_aves, activo=galpon.activo)
        self._session.add(fila)
        self._session.flush()
        return _galpon(fila)

    def obtener(self, galpon_id: int) -> Galpon | None:
        fila = self._session.get(TablaGalpon, galpon_id)
        return _galpon(fila) if fila else None

    def por_nombre(self, nombre: str) -> Galpon | None:
        fila = self._session.scalar(select(TablaGalpon).where(TablaGalpon.nombre == nombre))
        return _galpon(fila) if fila else None

    def listar(self) -> list[Galpon]:
        return [_galpon(f) for f in self._session.scalars(select(TablaGalpon).order_by(TablaGalpon.nombre))]


class LineasSql:
    def __init__(self, session: Session) -> None:
        self._session = session

    def agregar(self, linea: LineaGenetica) -> LineaGenetica:
        fila = TablaLinea(nombre=linea.nombre)
        self._session.add(fila)
        self._session.flush()
        return _linea(fila)

    def obtener(self, linea_id: int) -> LineaGenetica | None:
        fila = self._session.get(TablaLinea, linea_id)
        return _linea(fila) if fila else None

    def por_nombre(self, nombre: str) -> LineaGenetica | None:
        fila = self._session.scalar(select(TablaLinea).where(TablaLinea.nombre == nombre))
        return _linea(fila) if fila else None

    def listar(self) -> list[LineaGenetica]:
        return [_linea(f) for f in self._session.scalars(select(TablaLinea).order_by(TablaLinea.nombre))]


class LotesSql:
    def __init__(self, session: Session) -> None:
        self._session = session

    def agregar(self, lote: Lote) -> Lote:
        fila = TablaLote(
            galpon_id=lote.galpon_id,
            linea_id=lote.linea_id,
            fecha_nacimiento=lote.fecha_nacimiento,
            fecha_ingreso=lote.fecha_ingreso,
            aves_iniciales=lote.aves_iniciales,
            fecha_salida=lote.fecha_salida,
        )
        self._session.add(fila)
        self._session.flush()
        return _lote(fila)

    def obtener(self, lote_id: int) -> Lote | None:
        fila = self._session.get(TablaLote, lote_id)
        return _lote(fila) if fila else None

    def del_galpon(self, galpon_id: int) -> list[Lote]:
        consulta = select(TablaLote).where(TablaLote.galpon_id == galpon_id).order_by(TablaLote.fecha_ingreso)
        return [_lote(f) for f in self._session.scalars(consulta)]

    def actualizar(self, lote: Lote) -> Lote:
        fila = self._session.get_one(TablaLote, lote.id)
        fila.fecha_salida = lote.fecha_salida
        self._session.flush()
        return _lote(fila)


class RegistrosSql:
    def __init__(self, session: Session) -> None:
        self._session = session

    def del_dia(self, lote_id: int, fecha: date) -> RegistroDiario | None:
        fila = self._session.scalar(
            select(TablaRegistro).where(TablaRegistro.lote_id == lote_id, TablaRegistro.fecha == fecha)
        )
        return _registro(fila) if fila else None

    def guardar(self, registro: RegistroDiario) -> RegistroDiario:
        fila = self._session.get(TablaRegistro, registro.id)
        if fila is None:
            fila = TablaRegistro(id=registro.id)
            self._session.add(fila)
        fila.lote_id = registro.lote_id
        fila.fecha = registro.fecha
        fila.huevos_total = registro.huevos_total
        fila.huevos_rotos = registro.huevos_rotos
        fila.mortalidad = registro.mortalidad
        fila.alimento_kg = registro.alimento_kg
        self._session.flush()
        return _registro(fila)

    def mortalidad_hasta(self, lote_id: int, fecha: date) -> int:
        return self._session.scalar(
            select(func.coalesce(func.sum(TablaRegistro.mortalidad), 0)).where(
                TablaRegistro.lote_id == lote_id, TablaRegistro.fecha <= fecha
            )
        )

    def ultima_fecha(self, lote_id: int) -> date | None:
        return self._session.scalar(select(func.max(TablaRegistro.fecha)).where(TablaRegistro.lote_id == lote_id))


class UnidadDeTrabajoSql:
    def __init__(self, session: Session) -> None:
        self._session = session
        self.galpones = GalponesSql(session)
        self.lineas = LineasSql(session)
        self.lotes = LotesSql(session)
        self.registros = RegistrosSql(session)

    def confirmar(self) -> None:
        self._session.commit()
