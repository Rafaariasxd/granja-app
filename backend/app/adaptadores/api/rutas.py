import uuid
from datetime import UTC, date, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.adaptadores.api import esquemas
from app.adaptadores.api.dependencias import administrador, token_de_sesion, unidad_de_trabajo, usuario_actual
from app.casos_uso import galpones, inventario, lineas, lotes, registros, usuarios
from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import fechas
from app.dominio.modelos import Etapa, Ingrediente, Lote, Usuario

router = APIRouter()
protegido = APIRouter(dependencies=[Depends(usuario_actual)])
SoloAdmin = Annotated[Usuario, Depends(administrador)]
UsuarioDep = Annotated[Usuario, Depends(usuario_actual)]
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


@protegido.post(
    "/insumos",
    response_model=esquemas.InsumoOut,
    dependencies=[Depends(administrador)],
    status_code=status.HTTP_201_CREATED,
)
def crear_insumo(datos: esquemas.InsumoIn, uow: UnidadDep):
    return inventario.crear_insumo(uow, datos.nombre, datos.tipo, datos.etapa, datos.kg_por_bulto)


@protegido.get("/insumos", response_model=list[esquemas.InsumoOut])
def listar_insumos(uow: UnidadDep):
    return inventario.listar_insumos(uow)


@protegido.get("/inventario", response_model=esquemas.InventarioOut)
def estado_inventario(uow: UnidadDep):
    return inventario.estado_inventario(uow, fechas.fecha_en_granja(datetime.now(UTC)))


@protegido.post(
    "/insumos/{insumo_id}/compras", response_model=esquemas.MovimientoOut, status_code=status.HTTP_201_CREATED
)
def registrar_compra(insumo_id: int, datos: esquemas.CompraIn, uow: UnidadDep, quien: UsuarioDep):
    fecha = datos.fecha or fechas.fecha_en_granja(datetime.now(UTC))
    return inventario.registrar_compra(uow, quien, insumo_id, fecha, datos.bultos, datos.kg)


@protegido.post("/insumos/{insumo_id}/ajuste", response_model=esquemas.MovimientoOut | None)
def ajustar_stock(insumo_id: int, datos: esquemas.AjusteIn, uow: UnidadDep, quien: SoloAdmin):
    fecha = datos.fecha or fechas.fecha_en_granja(datetime.now(UTC))
    return inventario.ajustar_stock(uow, quien, insumo_id, fecha, datos.kg_reales, datos.nota)


@protegido.get("/insumos/{insumo_id}/movimientos", response_model=list[esquemas.MovimientoOut])
def movimientos_del_insumo(insumo_id: int, uow: UnidadDep, limite: Annotated[int, Query(ge=1, le=200)] = 50):
    return inventario.historial(uow, insumo_id, limite)


@protegido.get("/alimentos/{producto_id}/formula", response_model=list[esquemas.IngredienteIn])
def ver_formula(producto_id: int, uow: UnidadDep):
    return inventario.formula_de(uow, producto_id)


@protegido.put("/alimentos/{producto_id}/formula", response_model=list[esquemas.IngredienteIn])
def definir_formula(producto_id: int, datos: list[esquemas.IngredienteIn], uow: UnidadDep, quien: SoloAdmin):
    ingredientes = [Ingrediente(i.insumo_id, i.porcentaje) for i in datos]
    return inventario.definir_formula(uow, quien, producto_id, ingredientes, fechas.ahora_utc())


@protegido.post(
    "/alimentos/{producto_id}/preparaciones", response_model=esquemas.MovimientoOut, status_code=status.HTTP_201_CREATED
)
def preparar_alimento(producto_id: int, datos: esquemas.PreparacionIn, uow: UnidadDep, quien: UsuarioDep):
    fecha = datos.fecha or fechas.fecha_en_granja(datetime.now(UTC))
    return inventario.preparar_alimento(uow, quien, producto_id, fecha, datos.kg)


@protegido.put("/alimento-en-uso/{etapa}", status_code=status.HTTP_204_NO_CONTENT)
def definir_alimento_en_uso(etapa: Etapa, datos: esquemas.EnUsoIn, uow: UnidadDep, quien: SoloAdmin):
    inventario.definir_alimento_en_uso(uow, quien, etapa, datos.insumo_id, fechas.ahora_utc())
