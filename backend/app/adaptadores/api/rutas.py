import uuid
from datetime import UTC, date, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.adaptadores.api import esquemas
from app.adaptadores.api.dependencias import administrador, token_de_sesion, unidad_de_trabajo, usuario_actual
from app.casos_uso import galpones, lineas, lotes, registros, usuarios
from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import fechas
from app.dominio.modelos import Lote, Usuario

router = APIRouter()
protegido = APIRouter(dependencies=[Depends(usuario_actual)])
SoloAdmin = Annotated[Usuario, Depends(administrador)]
UnidadDep = Annotated[UnidadDeTrabajo, Depends(unidad_de_trabajo)]


@protegido.post(
    "/galpones",
    response_model=esquemas.GalponOut,
    dependencies=[Depends(administrador)],
    status_code=status.HTTP_201_CREATED,
)
def crear_galpon(datos: esquemas.GalponIn, uow: UnidadDep):
    return galpones.crear_galpon(uow, datos.nombre, datos.capacidad_aves)


@protegido.get("/galpones", response_model=list[esquemas.GalponOut])
def listar_galpones(uow: UnidadDep):
    return galpones.listar_galpones(uow)


@protegido.get("/galpones/resumen", response_model=list[esquemas.ResumenGalponOut])
def resumen_galpones(uow: UnidadDep, fecha: Annotated[date | None, Query()] = None):
    return galpones.resumen_galpones(uow, fecha or fechas.fecha_en_granja(datetime.now(UTC)))


@protegido.post(
    "/lineas",
    response_model=esquemas.LineaOut,
    dependencies=[Depends(administrador)],
    status_code=status.HTTP_201_CREATED,
)
def crear_linea(datos: esquemas.LineaIn, uow: UnidadDep):
    return lineas.crear_linea(uow, datos.nombre)


@protegido.get("/lineas", response_model=list[esquemas.LineaOut])
def listar_lineas(uow: UnidadDep):
    return lineas.listar_lineas(uow)


@protegido.post(
    "/lotes",
    response_model=esquemas.LoteOut,
    dependencies=[Depends(administrador)],
    status_code=status.HTTP_201_CREATED,
)
def crear_lote(datos: esquemas.LoteIn, uow: UnidadDep):
    return lotes.crear_lote(uow, Lote(**datos.model_dump()))


@protegido.post("/lotes/{lote_id}/salida", response_model=esquemas.LoteOut, dependencies=[Depends(administrador)])
def cerrar_lote(lote_id: int, fecha_salida: date, uow: UnidadDep):
    return lotes.cerrar_lote(uow, lote_id, fecha_salida)


@protegido.get("/registros", response_model=list[esquemas.RegistroOut])
def registros_del_dia(uow: UnidadDep, galpon_id: int, fecha: date):
    registro = registros.registro_del_dia(uow, galpon_id, fecha)
    return [registro] if registro else []


@protegido.put("/registros/{registro_id}", response_model=esquemas.RegistroOut)
def guardar_registro(registro_id: str, datos: esquemas.RegistroIn, uow: UnidadDep):
    if str(datos.id) != registro_id:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, "el id de la URL y del cuerpo no coinciden")
    return registros.guardar_registro(uow, registros.RegistroDelDia(**datos.model_dump()))


@protegido.delete("/registros/{registro_id}", status_code=status.HTTP_204_NO_CONTENT)
def borrar_registro(registro_id: uuid.UUID, uow: UnidadDep, quien: SoloAdmin):
    registros.borrar_registro(uow, quien, registro_id, fechas.ahora_utc())


@router.post("/sesion", response_model=esquemas.SesionOut)
def iniciar_sesion(datos: esquemas.IngresoIn, uow: UnidadDep):
    token, usuario = usuarios.iniciar_sesion(uow, datos.nombre, datos.pin, fechas.ahora_utc())
    return esquemas.SesionOut(token=token, usuario_id=usuario.id, nombre=usuario.nombre, rol=usuario.rol)


@router.delete("/sesion", status_code=status.HTTP_204_NO_CONTENT)
def cerrar_sesion(uow: UnidadDep, token: Annotated[str, Depends(token_de_sesion)]):
    usuarios.cerrar_sesion(uow, token)


@router.get("/sesion", response_model=esquemas.UsuarioOut)
def quien_soy(usuario: Annotated[Usuario, Depends(usuario_actual)]):
    return usuario


@router.get("/usuarios", response_model=list[esquemas.UsuarioOut], dependencies=[Depends(administrador)])
def listar_usuarios(uow: UnidadDep):
    return usuarios.listar_usuarios(uow)


@router.post("/usuarios", response_model=esquemas.UsuarioOut, status_code=status.HTTP_201_CREATED)
def crear_usuario(datos: esquemas.UsuarioIn, uow: UnidadDep, _: SoloAdmin):
    return usuarios.crear_usuario(uow, datos.nombre, datos.pin, datos.rol)


@router.post("/usuarios/{usuario_id}/desactivar", response_model=esquemas.UsuarioOut)
def desactivar_usuario(usuario_id: int, uow: UnidadDep, quien: SoloAdmin):
    return usuarios.desactivar_usuario(uow, quien, usuario_id, fechas.ahora_utc())
