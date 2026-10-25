import uuid
from datetime import date, datetime, timedelta

from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import lotes as reglas_lotes
from app.dominio import produccion, sanidad
from app.dominio.errores import Conflicto, DatosInvalidos, NoEncontrado
from app.dominio.modelos import Etapa, Evento, Galpon, Lote, Usuario
from app.dominio.sanidad import (
    ComparacionPostura,
    Cumplimiento,
    Panorama,
    Pesaje,
    PuntoCurva,
    SanidadGalpon,
    TareaPlan,
)

DIAS_DE_POSTURA = 7


def _linea(uow: UnidadDeTrabajo, linea_id: int):
    linea = uow.lineas.obtener(linea_id)
    if linea is None:
        raise NoEncontrado(f"la raza {linea_id} no existe")
    return linea


def _lote(uow: UnidadDeTrabajo, lote_id: int) -> Lote:
    lote = uow.lotes.obtener(lote_id)
    if lote is None:
        raise NoEncontrado(f"el lote {lote_id} no existe")
    return lote


def _marcar_revisada(uow: UnidadDeTrabajo, linea_id: int) -> None:
    linea = _linea(uow, linea_id)
    if not linea.revisada:
        linea.revisada = True
        uow.lineas.actualizar(linea)


def ver_plan(uow: UnidadDeTrabajo, linea_id: int) -> list[TareaPlan]:
    _linea(uow, linea_id)
    return [t for t in uow.plan.de(linea_id) if t.activa]


def definir_plan(
    uow: UnidadDeTrabajo, quien: Usuario, linea_id: int, tareas: list[TareaPlan], ahora: datetime
) -> list[TareaPlan]:
    linea = _linea(uow, linea_id)
    for t in tareas:
        sanidad.validar_tarea(t)
    propias = {t.id for t in uow.plan.de(linea_id)}
    ajenas = [t.id for t in tareas if t.id is not None and t.id not in propias]
    if ajenas:
        raise DatosInvalidos(f"las tareas {ajenas} no son de la raza {linea.nombre}")
    guardadas = uow.plan.guardar(linea_id, tareas)
    _marcar_revisada(uow, linea_id)
    uow.bitacora.agregar(Evento("plan_definido", f"{linea.nombre}: {len(guardadas)} tareas", quien.id, ahora))
    uow.confirmar()
    return guardadas


def ver_curva(uow: UnidadDeTrabajo, linea_id: int) -> list[PuntoCurva]:
    _linea(uow, linea_id)
    return uow.curvas.de(linea_id)


def definir_curva(
    uow: UnidadDeTrabajo, quien: Usuario, linea_id: int, puntos: list[PuntoCurva], ahora: datetime
) -> list[PuntoCurva]:
    linea = _linea(uow, linea_id)
    sanidad.validar_curva(puntos)
    uow.curvas.guardar(linea_id, puntos)
    _marcar_revisada(uow, linea_id)
    uow.bitacora.agregar(Evento("curva_definida", f"{linea.nombre}: {len(puntos)} semanas", quien.id, ahora))
    uow.confirmar()
    return uow.curvas.de(linea_id)


def marcar_aplicada(
    uow: UnidadDeTrabajo,
    quien: Usuario,
    lote_id: int,
    tarea_id: int,
    cumplimiento_id: uuid.UUID,
    fecha: date,
    nota: str,
) -> Cumplimiento:
    """Es idempotente: el celular puede reenviarla sin duplicar."""
    lote = _lote(uow, lote_id)
    tarea = uow.plan.obtener(tarea_id)
    if tarea is None or tarea.linea_id != lote.linea_id:
        raise NoEncontrado(f"la tarea {tarea_id} no es del plan de este lote")
    if fecha < lote.fecha_nacimiento:
        raise DatosInvalidos("la fecha es anterior al nacimiento del lote")
    previa = next((c for c in uow.cumplimientos.del_lote(lote_id) if c.tarea_id == tarea_id), None)
    if previa is not None and previa.id != cumplimiento_id:
        raise Conflicto(f"{tarea.nombre} ya estaba marcada el {previa.fecha}")
    cumplimiento = uow.cumplimientos.guardar(
        Cumplimiento(
            id=cumplimiento_id, lote_id=lote_id, tarea_id=tarea_id, fecha=fecha, nota=nota, usuario_id=quien.id
        )
    )
    uow.confirmar()
    return cumplimiento


def deshacer_aplicacion(uow: UnidadDeTrabajo, quien: Usuario, cumplimiento_id: uuid.UUID, ahora: datetime) -> None:
    cumplimiento = uow.cumplimientos.obtener(cumplimiento_id)
    if cumplimiento is None:
        return
    tarea = uow.plan.obtener(cumplimiento.tarea_id)
    nombre = tarea.nombre if tarea else str(cumplimiento.tarea_id)
    detalle = f"{nombre} del lote {cumplimiento.lote_id}, marcada el {cumplimiento.fecha}"
    uow.cumplimientos.quitar(cumplimiento_id)
    uow.bitacora.agregar(Evento("aplicacion_deshecha", detalle, quien.id, ahora))
    uow.confirmar()


def registrar_pesaje(
    uow: UnidadDeTrabajo, lote_id: int, pesaje_id: uuid.UUID, fecha: date, peso_g: float, aves_pesadas: int
) -> Pesaje:
    lote = _lote(uow, lote_id)
    if fecha < lote.fecha_nacimiento:
        raise DatosInvalidos("la fecha es anterior al nacimiento del lote")
    if peso_g <= 0 or aves_pesadas <= 0:
        raise DatosInvalidos("el peso y la cantidad de aves pesadas deben ser mayores que cero")
    pesaje = uow.pesajes.guardar(Pesaje(pesaje_id, lote_id, fecha, peso_g, aves_pesadas))
    uow.confirmar()
    return pesaje


def quitar_pesaje(uow: UnidadDeTrabajo, quien: Usuario, pesaje_id: uuid.UUID, ahora: datetime) -> None:
    pesaje = uow.pesajes.obtener(pesaje_id)
    if pesaje is None:
        return
    detalle = f"lote {pesaje.lote_id} {pesaje.fecha}: {pesaje.peso_g:g} g, {pesaje.aves_pesadas} aves"
    uow.pesajes.quitar(pesaje_id)
    uow.bitacora.agregar(Evento("pesaje_borrado", detalle, quien.id, ahora))
    uow.confirmar()


def _postura_reciente(
    uow: UnidadDeTrabajo, lote: Lote, curva: list[PuntoCurva], fecha: date
) -> tuple[ComparacionPostura | None, int]:
    registros = sorted(
        (r for r in uow.registros.entre(fecha - timedelta(days=DIAS_DE_POSTURA - 1), fecha) if r.lote_id == lote.id),
        key=lambda r: r.fecha,
    )
    dias = []
    for r in registros:
        vivas = produccion.aves_vivas(lote.aves_iniciales, uow.registros.mortalidad_hasta(lote.id, r.fecha))
        punto = sanidad.punto_en(curva, produccion.edad_semanas(lote.fecha_nacimiento, r.fecha))
        if vivas > 0 and punto is not None and punto.postura_pct > 0:
            dias.append(
                produccion.DiaPostura(r.fecha, produccion.postura_pct(r.huevos_total, vivas), punto.postura_pct)
            )
    if not dias:
        return None, 0
    ultimo = dias[-1]
    comparacion = ComparacionPostura(ultimo.fecha, ultimo.real_pct, ultimo.estandar_pct)
    seguidos = 0
    for d in reversed(dias):
        if d.estandar_pct - d.real_pct <= 5.0:
            break
        seguidos += 1
    return comparacion, seguidos


def _del_galpon(uow: UnidadDeTrabajo, galpon: Galpon, lote: Lote, fecha: date) -> tuple[SanidadGalpon, list]:
    linea = uow.lineas.obtener(lote.linea_id)
    edad = produccion.edad_semanas(lote.fecha_nacimiento, fecha)
    ingreso = produccion.edad_semanas(lote.fecha_nacimiento, lote.fecha_ingreso)
    tareas = sanidad.tareas_del_lote(uow.plan.de(lote.linea_id), uow.cumplimientos.del_lote(lote.id), edad, ingreso)
    curva = uow.curvas.de(lote.linea_id)
    pesajes = uow.pesajes.del_lote(lote.id)
    peso = None
    if pesajes:
        ultimo = pesajes[-1]
        peso = sanidad.comparar_peso(ultimo, curva, produccion.edad_semanas(lote.fecha_nacimiento, ultimo.fecha))
    vivas = produccion.aves_vivas(lote.aves_iniciales, uow.registros.mortalidad_hasta(lote.id, fecha))
    etapa = produccion.etapa(lote.fecha_nacimiento, fecha)
    postura, dias_bajos = (None, 0)
    if etapa == Etapa.PRODUCCION:
        postura, dias_bajos = _postura_reciente(uow, lote, curva, fecha)
    muertas = sum(r.mortalidad for r in uow.registros.entre(fecha - timedelta(days=6), fecha) if r.lote_id == lote.id)
    sin_pesar = (fecha - pesajes[-1].fecha).days if pesajes else None
    alertas = sanidad.alertas_del_lote(
        galpon.id,
        galpon.nombre,
        lote.id,
        edad,
        tareas,
        peso,
        sin_pesar,
        postura if dias_bajos >= 3 else None,
        dias_bajos,
        muertas,
        vivas,
    )
    resumen = SanidadGalpon(
        galpon_id=galpon.id,
        galpon=galpon.nombre,
        lote_id=lote.id,
        linea=linea.nombre if linea else "",
        edad_semanas=edad,
        etapa=etapa.value,
        aves_vivas=vivas,
        tareas=tareas,
        pesajes=pesajes[-8:],
        peso=peso,
        postura=postura,
    )
    return resumen, alertas


def panorama(uow: UnidadDeTrabajo, fecha: date) -> Panorama:
    galpones = []
    alertas = []
    for galpon in uow.galpones.listar():
        lote = reglas_lotes.activo_en(uow.lotes.del_galpon(galpon.id), fecha)
        if lote is None:
            continue
        resumen, de_este = _del_galpon(uow, galpon, lote, fecha)
        galpones.append(resumen)
        alertas.extend(de_este)
    return Panorama(fecha=fecha, alertas=sanidad.ordenar_alertas(alertas), galpones=galpones)
