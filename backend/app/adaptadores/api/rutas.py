from datetime import UTC, date, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.adaptadores.api import esquemas
from app.adaptadores.api.dependencias import unidad_de_trabajo
from app.casos_uso import galpones, lineas, lotes, registros
from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import fechas
from app.dominio.modelos import Lote

router = APIRouter()
UnidadDep = Annotated[UnidadDeTrabajo, Depends(unidad_de_trabajo)]


@router.post("/galpones", response_model=esquemas.GalponOut, status_code=status.HTTP_201_CREATED)
def crear_galpon(datos: esquemas.GalponIn, uow: UnidadDep):
    return galpones.crear_galpon(uow, datos.nombre, datos.capacidad_aves)


@router.get("/galpones", response_model=list[esquemas.GalponOut])
def listar_galpones(uow: UnidadDep):
    return galpones.listar_galpones(uow)


@router.get("/galpones/resumen", response_model=list[esquemas.ResumenGalponOut])
def resumen_galpones(uow: UnidadDep, fecha: Annotated[date | None, Query()] = None):
    return galpones.resumen_galpones(uow, fecha or fechas.fecha_en_granja(datetime.now(UTC)))


@router.post("/lineas", response_model=esquemas.LineaOut, status_code=status.HTTP_201_CREATED)
def crear_linea(datos: esquemas.LineaIn, uow: UnidadDep):
    return lineas.crear_linea(uow, datos.nombre)


@router.get("/lineas", response_model=list[esquemas.LineaOut])
def listar_lineas(uow: UnidadDep):
    return lineas.listar_lineas(uow)


@router.post("/lotes", response_model=esquemas.LoteOut, status_code=status.HTTP_201_CREATED)
def crear_lote(datos: esquemas.LoteIn, uow: UnidadDep):
    return lotes.crear_lote(uow, Lote(**datos.model_dump()))


@router.post("/lotes/{lote_id}/salida", response_model=esquemas.LoteOut)
def cerrar_lote(lote_id: int, fecha_salida: date, uow: UnidadDep):
    return lotes.cerrar_lote(uow, lote_id, fecha_salida)


@router.get("/registros", response_model=list[esquemas.RegistroOut])
def registros_del_dia(uow: UnidadDep, galpon_id: int, fecha: date):
    registro = registros.registro_del_dia(uow, galpon_id, fecha)
    return [registro] if registro else []


@router.put("/registros/{registro_id}", response_model=esquemas.RegistroOut)
def guardar_registro(registro_id: str, datos: esquemas.RegistroIn, uow: UnidadDep):
    if str(datos.id) != registro_id:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "el id de la URL y del cuerpo no coinciden")
    return registros.guardar_registro(uow, registros.RegistroDelDia(**datos.model_dump()))
