import uuid
from datetime import date

from sqlalchemy import delete, func, select, update
from sqlalchemy.orm import Session

from app.adaptadores.db.tablas import (
    TablaAlimentoEnUso,
    TablaBodega,
    TablaBodegaGalpon,
    TablaEvento,
    TablaGalpon,
    TablaIngrediente,
    TablaInsumo,
    TablaLinea,
    TablaLote,
    TablaMovimiento,
    TablaRegistro,
    TablaSesion,
    TablaUsuario,
)
from app.dominio.modelos import (
    Bodega,
    Etapa,
    Evento,
    Galpon,
    Ingrediente,
    Insumo,
    LineaGenetica,
    Lote,
    Motivo,
    MovimientoInsumo,
    RegistroDiario,
    Rol,
    Sesion,
    TipoBodega,
    TipoInsumo,
    Usuario,
)


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

    def obtener(self, registro_id: uuid.UUID) -> RegistroDiario | None:
        fila = self._session.get(TablaRegistro, registro_id)
        return _registro(fila) if fila else None

    def eliminar(self, registro_id: uuid.UUID) -> None:
        self._session.execute(delete(TablaRegistro).where(TablaRegistro.id == registro_id))

    def entre(self, desde: date, hasta: date) -> list[RegistroDiario]:
        consulta = select(TablaRegistro).where(TablaRegistro.fecha >= desde, TablaRegistro.fecha <= hasta)
        return [_registro(f) for f in self._session.scalars(consulta)]


def _usuario(fila: TablaUsuario) -> Usuario:
    return Usuario(
        id=fila.id,
        nombre=fila.nombre,
        rol=Rol(fila.rol),
        pin_hash=fila.pin_hash,
        activo=fila.activo,
        intentos_fallidos=fila.intentos_fallidos,
        bloqueado_hasta=fila.bloqueado_hasta,
    )


class UsuariosSql:
    def __init__(self, session: Session) -> None:
        self._session = session

    def agregar(self, usuario: Usuario) -> Usuario:
        fila = TablaUsuario(nombre=usuario.nombre, rol=usuario.rol.value, pin_hash=usuario.pin_hash)
        self._session.add(fila)
        self._session.flush()
        return _usuario(fila)

    def obtener(self, usuario_id: int) -> Usuario | None:
        fila = self._session.get(TablaUsuario, usuario_id)
        return _usuario(fila) if fila else None

    def por_nombre(self, nombre: str) -> Usuario | None:
        fila = self._session.scalar(select(TablaUsuario).where(TablaUsuario.nombre == nombre))
        return _usuario(fila) if fila else None

    def listar(self) -> list[Usuario]:
        return [_usuario(f) for f in self._session.scalars(select(TablaUsuario).order_by(TablaUsuario.nombre))]

    def actualizar(self, usuario: Usuario) -> Usuario:
        fila = self._session.get_one(TablaUsuario, usuario.id)
        fila.activo = usuario.activo
        fila.intentos_fallidos = usuario.intentos_fallidos
        fila.bloqueado_hasta = usuario.bloqueado_hasta
        self._session.flush()
        return _usuario(fila)


class SesionesSql:
    def __init__(self, session: Session) -> None:
        self._session = session

    def agregar(self, sesion: Sesion) -> Sesion:
        fila = TablaSesion(token_hash=sesion.token_hash, usuario_id=sesion.usuario_id, creada_en=sesion.creada_en)
        self._session.add(fila)
        self._session.flush()
        return Sesion(
            id=fila.id,
            token_hash=fila.token_hash,
            usuario_id=fila.usuario_id,
            creada_en=fila.creada_en,
            revocada=fila.revocada,
        )

    def por_token_hash(self, token_hash: str) -> Sesion | None:
        fila = self._session.scalar(select(TablaSesion).where(TablaSesion.token_hash == token_hash))
        if fila is None:
            return None
        return Sesion(
            id=fila.id,
            token_hash=fila.token_hash,
            usuario_id=fila.usuario_id,
            creada_en=fila.creada_en,
            revocada=fila.revocada,
        )

    def revocar(self, sesion_id: int) -> None:
        self._session.execute(update(TablaSesion).where(TablaSesion.id == sesion_id).values(revocada=True))

    def revocar_de_usuario(self, usuario_id: int) -> None:
        self._session.execute(update(TablaSesion).where(TablaSesion.usuario_id == usuario_id).values(revocada=True))


class BitacoraSql:
    def __init__(self, session: Session) -> None:
        self._session = session

    def agregar(self, evento: Evento) -> Evento:
        fila = TablaEvento(
            accion=evento.accion, detalle=evento.detalle, usuario_id=evento.usuario_id, momento=evento.momento
        )
        self._session.add(fila)
        self._session.flush()
        return Evento(
            id=fila.id, accion=fila.accion, detalle=fila.detalle, usuario_id=fila.usuario_id, momento=fila.momento
        )

    def listar(self) -> list[Evento]:
        filas = self._session.scalars(select(TablaEvento).order_by(TablaEvento.id))
        return [Evento(f.accion, f.detalle, f.usuario_id, f.momento, f.id) for f in filas]


def _insumo(fila: TablaInsumo) -> Insumo:
    return Insumo(
        id=fila.id,
        nombre=fila.nombre,
        tipo=TipoInsumo(fila.tipo),
        kg_por_bulto=fila.kg_por_bulto,
        etapa=Etapa(fila.etapa) if fila.etapa else None,
        activo=fila.activo,
    )


def _movimiento(fila: TablaMovimiento) -> MovimientoInsumo:
    return MovimientoInsumo(
        id=fila.id,
        insumo_id=fila.insumo_id,
        bodega_id=fila.bodega_id,
        fecha=fila.fecha,
        kg=fila.kg,
        motivo=Motivo(fila.motivo),
        usuario_id=fila.usuario_id,
        nota=fila.nota,
        registro_id=fila.registro_id,
    )


class InsumosSql:
    def __init__(self, session: Session) -> None:
        self._session = session

    def agregar(self, insumo: Insumo) -> Insumo:
        fila = TablaInsumo(
            nombre=insumo.nombre,
            tipo=insumo.tipo.value,
            etapa=insumo.etapa.value if insumo.etapa else None,
            kg_por_bulto=insumo.kg_por_bulto,
            activo=insumo.activo,
        )
        self._session.add(fila)
        self._session.flush()
        return _insumo(fila)

    def obtener(self, insumo_id: int) -> Insumo | None:
        fila = self._session.get(TablaInsumo, insumo_id)
        return _insumo(fila) if fila else None

    def por_nombre(self, nombre: str) -> Insumo | None:
        fila = self._session.scalar(select(TablaInsumo).where(TablaInsumo.nombre == nombre))
        return _insumo(fila) if fila else None

    def listar(self) -> list[Insumo]:
        return [_insumo(f) for f in self._session.scalars(select(TablaInsumo).order_by(TablaInsumo.nombre))]

    def stocks(self) -> dict[tuple[int, int], float]:
        consulta = select(TablaMovimiento.bodega_id, TablaMovimiento.insumo_id, func.sum(TablaMovimiento.kg)).group_by(
            TablaMovimiento.bodega_id, TablaMovimiento.insumo_id
        )
        return {(bodega_id, insumo_id): float(kg) for bodega_id, insumo_id, kg in self._session.execute(consulta)}


class MovimientosSql:
    def __init__(self, session: Session) -> None:
        self._session = session

    def agregar(self, movimiento: MovimientoInsumo) -> MovimientoInsumo:
        fila = TablaMovimiento(
            insumo_id=movimiento.insumo_id,
            bodega_id=movimiento.bodega_id,
            fecha=movimiento.fecha,
            kg=movimiento.kg,
            motivo=movimiento.motivo.value,
            usuario_id=movimiento.usuario_id,
            nota=movimiento.nota,
            registro_id=movimiento.registro_id,
        )
        self._session.add(fila)
        self._session.flush()
        return _movimiento(fila)

    def guardar_consumo(self, movimiento: MovimientoInsumo) -> None:
        fila = self._session.scalar(
            select(TablaMovimiento).where(TablaMovimiento.registro_id == movimiento.registro_id)
        )
        if fila is None:
            self.agregar(movimiento)
            return
        fila.insumo_id = movimiento.insumo_id
        fila.bodega_id = movimiento.bodega_id
        fila.fecha = movimiento.fecha
        fila.kg = movimiento.kg
        self._session.flush()

    def quitar_consumo(self, registro_id: uuid.UUID) -> None:
        self._session.execute(delete(TablaMovimiento).where(TablaMovimiento.registro_id == registro_id))

    def del_insumo(self, insumo_id: int, limite: int) -> list[MovimientoInsumo]:
        consulta = (
            select(TablaMovimiento)
            .where(TablaMovimiento.insumo_id == insumo_id)
            .order_by(TablaMovimiento.fecha.desc(), TablaMovimiento.id.desc())
            .limit(limite)
        )
        return [_movimiento(f) for f in self._session.scalars(consulta)]


class FormulasSql:
    def __init__(self, session: Session) -> None:
        self._session = session

    def guardar(self, producto_id: int, ingredientes: list[Ingrediente]) -> None:
        self._session.execute(delete(TablaIngrediente).where(TablaIngrediente.producto_id == producto_id))
        for ingrediente in ingredientes:
            self._session.add(
                TablaIngrediente(
                    producto_id=producto_id, insumo_id=ingrediente.insumo_id, porcentaje=ingrediente.porcentaje
                )
            )
        self._session.flush()

    def de(self, producto_id: int) -> list[Ingrediente]:
        consulta = (
            select(TablaIngrediente).where(TablaIngrediente.producto_id == producto_id).order_by(TablaIngrediente.id)
        )
        return [Ingrediente(f.insumo_id, f.porcentaje) for f in self._session.scalars(consulta)]

    def todas(self) -> dict[int, list[Ingrediente]]:
        formulas: dict[int, list[Ingrediente]] = {}
        for fila in self._session.scalars(select(TablaIngrediente).order_by(TablaIngrediente.id)):
            formulas.setdefault(fila.producto_id, []).append(Ingrediente(fila.insumo_id, fila.porcentaje))
        return formulas


class AlimentoEnUsoSql:
    def __init__(self, session: Session) -> None:
        self._session = session

    def definir(self, bodega_id: int, etapa: Etapa, insumo_id: int) -> None:
        fila = self._session.get(TablaAlimentoEnUso, (bodega_id, etapa.value))
        if fila is None:
            self._session.add(TablaAlimentoEnUso(bodega_id=bodega_id, etapa=etapa.value, insumo_id=insumo_id))
        else:
            fila.insumo_id = insumo_id
        self._session.flush()

    def de(self, bodega_id: int, etapa: Etapa) -> int | None:
        fila = self._session.get(TablaAlimentoEnUso, (bodega_id, etapa.value))
        return fila.insumo_id if fila else None

    def todos(self) -> dict[tuple[int, Etapa], int]:
        filas = self._session.scalars(select(TablaAlimentoEnUso))
        return {(f.bodega_id, Etapa(f.etapa)): f.insumo_id for f in filas}


def _bodega(fila: TablaBodega) -> Bodega:
    return Bodega(id=fila.id, nombre=fila.nombre, tipo=TipoBodega(fila.tipo))


class BodegasSql:
    def __init__(self, session: Session) -> None:
        self._session = session

    def agregar(self, bodega: Bodega) -> Bodega:
        fila = TablaBodega(nombre=bodega.nombre, tipo=bodega.tipo.value)
        self._session.add(fila)
        self._session.flush()
        return _bodega(fila)

    def obtener(self, bodega_id: int) -> Bodega | None:
        fila = self._session.get(TablaBodega, bodega_id)
        return _bodega(fila) if fila else None

    def por_nombre(self, nombre: str) -> Bodega | None:
        fila = self._session.scalar(select(TablaBodega).where(TablaBodega.nombre == nombre))
        return _bodega(fila) if fila else None

    def listar(self) -> list[Bodega]:
        return [_bodega(f) for f in self._session.scalars(select(TablaBodega).order_by(TablaBodega.id))]

    def asignar_galpones(self, bodega_id: int, galpon_ids: list[int]) -> None:
        self._session.execute(delete(TablaBodegaGalpon).where(TablaBodegaGalpon.bodega_id == bodega_id))
        if galpon_ids:
            self._session.execute(delete(TablaBodegaGalpon).where(TablaBodegaGalpon.galpon_id.in_(galpon_ids)))
        for galpon_id in galpon_ids:
            self._session.add(TablaBodegaGalpon(galpon_id=galpon_id, bodega_id=bodega_id))
        self._session.flush()

    def galpones_de(self, bodega_id: int) -> list[int]:
        consulta = (
            select(TablaBodegaGalpon.galpon_id)
            .where(TablaBodegaGalpon.bodega_id == bodega_id)
            .order_by(TablaBodegaGalpon.galpon_id)
        )
        return list(self._session.scalars(consulta))

    def de_galpon(self, galpon_id: int) -> int | None:
        fila = self._session.get(TablaBodegaGalpon, galpon_id)
        return fila.bodega_id if fila else None


class UnidadDeTrabajoSql:
    def __init__(self, session: Session) -> None:
        self._session = session
        self.galpones = GalponesSql(session)
        self.lineas = LineasSql(session)
        self.lotes = LotesSql(session)
        self.registros = RegistrosSql(session)
        self.usuarios = UsuariosSql(session)
        self.sesiones = SesionesSql(session)
        self.bitacora = BitacoraSql(session)
        self.bodegas = BodegasSql(session)
        self.insumos = InsumosSql(session)
        self.movimientos = MovimientosSql(session)
        self.formulas = FormulasSql(session)
        self.alimento_en_uso = AlimentoEnUsoSql(session)

    def confirmar(self) -> None:
        self._session.commit()
