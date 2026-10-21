from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app import models, schemas
from app.db import get_session
from app.dominio import fechas, produccion

router = APIRouter()
SessionDep = Annotated[Session, Depends(get_session)]


def _lote_activo(session: Session, galpon_id: int, fecha: date) -> models.Lote | None:
    return session.scalar(
        select(models.Lote).where(
            models.Lote.galpon_id == galpon_id,
            models.Lote.fecha_ingreso <= fecha,
            (models.Lote.fecha_salida.is_(None)) | (models.Lote.fecha_salida >= fecha),
        )
    )


def _lote_que_se_cruza(
    session: Session, galpon_id: int, inicio: date, fin: date | None, excluir: int | None = None
) -> models.Lote | None:
    for lote in session.scalars(select(models.Lote).where(models.Lote.galpon_id == galpon_id)):
        if lote.id != excluir and fechas.periodos_se_cruzan(inicio, fin, lote.fecha_ingreso, lote.fecha_salida):
            return lote
    return None


def _obtener(session: Session, modelo: type, id_: int, nombre: str):
    obj = session.get(modelo, id_)
    if obj is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"{nombre} {id_} no existe")
    return obj


@router.post("/galpones", response_model=schemas.GalponOut, status_code=status.HTTP_201_CREATED)
def crear_galpon(datos: schemas.GalponIn, session: SessionDep):
    if session.scalar(select(models.Galpon).where(models.Galpon.nombre == datos.nombre)):
        raise HTTPException(status.HTTP_409_CONFLICT, f"ya existe un galpón llamado {datos.nombre}")
    galpon = models.Galpon(**datos.model_dump())
    session.add(galpon)
    session.commit()
    return galpon


@router.get("/galpones", response_model=list[schemas.GalponOut])
def listar_galpones(session: SessionDep):
    return session.scalars(select(models.Galpon).order_by(models.Galpon.nombre)).all()


@router.get("/galpones/resumen", response_model=list[schemas.ResumenGalpon])
def resumen_galpones(session: SessionDep, fecha: Annotated[date | None, Query()] = None):
    """Lo que hoy está en el tablero: cada galpón con su lote, aves y postura del día."""
    fecha = fecha or date.today()
    resumen = []
    for galpon in session.scalars(select(models.Galpon).order_by(models.Galpon.nombre)):
        lote = _lote_activo(session, galpon.id, fecha)
        if lote is None:
            resumen.append(
                schemas.ResumenGalpon(
                    galpon_id=galpon.id,
                    nombre=galpon.nombre,
                    capacidad_aves=galpon.capacidad_aves,
                    lote_id=None,
                    etapa=None,
                    edad_semanas=None,
                    aves_vivas=0,
                    ocupacion_pct=0.0,
                    postura_pct=None,
                )
            )
            continue
        mortalidad = session.scalar(
            select(func.coalesce(func.sum(models.RegistroDiario.mortalidad), 0)).where(
                models.RegistroDiario.lote_id == lote.id, models.RegistroDiario.fecha <= fecha
            )
        )
        vivas = produccion.aves_vivas(lote.aves_iniciales, mortalidad)
        registro = session.scalar(
            select(models.RegistroDiario).where(
                models.RegistroDiario.lote_id == lote.id, models.RegistroDiario.fecha == fecha
            )
        )
        resumen.append(
            schemas.ResumenGalpon(
                galpon_id=galpon.id,
                nombre=galpon.nombre,
                capacidad_aves=galpon.capacidad_aves,
                lote_id=lote.id,
                etapa=produccion.etapa(lote.fecha_nacimiento, fecha),
                edad_semanas=produccion.edad_semanas(lote.fecha_nacimiento, fecha),
                aves_vivas=vivas,
                ocupacion_pct=produccion.ocupacion_pct(vivas, galpon.capacidad_aves),
                postura_pct=produccion.postura_pct(registro.huevos_total, vivas) if registro else None,
            )
        )
    return resumen


@router.post("/lineas", response_model=schemas.LineaOut, status_code=status.HTTP_201_CREATED)
def crear_linea(datos: schemas.LineaIn, session: SessionDep):
    linea = models.LineaGenetica(**datos.model_dump())
    session.add(linea)
    session.commit()
    return linea


@router.get("/lineas", response_model=list[schemas.LineaOut])
def listar_lineas(session: SessionDep):
    return session.scalars(select(models.LineaGenetica).order_by(models.LineaGenetica.nombre)).all()


@router.post("/lotes", response_model=schemas.LoteOut, status_code=status.HTTP_201_CREATED)
def crear_lote(datos: schemas.LoteIn, session: SessionDep):
    galpon = _obtener(session, models.Galpon, datos.galpon_id, "el galpón")
    _obtener(session, models.LineaGenetica, datos.linea_id, "la línea genética")
    if _lote_que_se_cruza(session, galpon.id, datos.fecha_ingreso, None):
        raise HTTPException(status.HTTP_409_CONFLICT, f"el galpón {galpon.nombre} ya tiene un lote en esas fechas")
    if datos.aves_iniciales > galpon.capacidad_aves:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT,
            f"el galpón {galpon.nombre} tiene capacidad para {galpon.capacidad_aves} aves",
        )
    lote = models.Lote(**datos.model_dump())
    session.add(lote)
    session.commit()
    return lote


@router.post("/lotes/{lote_id}/salida", response_model=schemas.LoteOut)
def cerrar_lote(lote_id: int, fecha_salida: date, session: SessionDep):
    lote = _obtener(session, models.Lote, lote_id, "el lote")
    if fecha_salida < lote.fecha_ingreso:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "la salida es anterior al ingreso")
    ultimo_registro = session.scalar(
        select(func.max(models.RegistroDiario.fecha)).where(models.RegistroDiario.lote_id == lote.id)
    )
    if ultimo_registro is not None and fecha_salida < ultimo_registro:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, f"el lote tiene registros hasta el {ultimo_registro}"
        )
    otro = _lote_que_se_cruza(session, lote.galpon_id, lote.fecha_ingreso, fecha_salida, excluir=lote.id)
    if otro is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, f"esa salida se cruza con el lote {otro.id} del mismo galpón")
    lote.fecha_salida = fecha_salida
    session.commit()
    return lote


@router.put("/registros/{registro_id}", response_model=schemas.RegistroOut)
def guardar_registro(registro_id: str, datos: schemas.RegistroIn, session: SessionDep):
    """Crea o corrige el registro del día. Es idempotente: el celular puede reenviarlo sin duplicar."""
    if str(datos.id) != registro_id:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "el id de la URL y del cuerpo no coinciden")
    galpon = _obtener(session, models.Galpon, datos.galpon_id, "el galpón")
    lote = _lote_activo(session, galpon.id, datos.fecha)
    if lote is None:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_CONTENT, f"el galpón {galpon.nombre} no tiene un lote activo ese día"
        )
    campos = datos.model_dump(exclude={"id", "galpon_id"})
    otro = session.scalar(
        select(models.RegistroDiario).where(
            models.RegistroDiario.lote_id == lote.id,
            models.RegistroDiario.fecha == datos.fecha,
            models.RegistroDiario.id != datos.id,
        )
    )
    if otro is not None:
        raise HTTPException(status.HTTP_409_CONFLICT, f"ya hay un registro de {galpon.nombre} para {datos.fecha}")

    registro = session.get(models.RegistroDiario, datos.id)
    if registro is None:
        registro = models.RegistroDiario(id=datos.id, lote_id=lote.id, **campos)
        session.add(registro)
    else:
        registro.lote_id = lote.id
        for campo, valor in campos.items():
            setattr(registro, campo, valor)
    session.commit()
    return registro
