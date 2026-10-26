import uuid
from datetime import UTC, date, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.adaptadores.api import esquemas
from app.adaptadores.api.dependencias import administrador, token_de_sesion, unidad_de_trabajo, usuario_actual
from app.casos_uso import galpones, inventario, lineas, lotes, registros, sanidad, usuarios
from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import fechas
from app.dominio.modelos import Etapa, Ingrediente, Lote, Usuario
from app.dominio.sanidad import PuntoCurva, TareaPlan

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
    return lineas.crear_linea(uow, datos.nombre, datos.plantilla)


@protegido.get("/lineas", response_model=list[esquemas.LineaOut])
def listar_lineas(uow: UnidadDep):
    return lineas.listar_lineas(uow)


@protegido.get("/lineas/plantillas", response_model=list[str])
def plantillas_de_lineas():
    return lineas.plantillas_disponibles()


@protegido.patch("/lineas/{linea_id}", response_model=esquemas.LineaOut)
def renombrar_linea(linea_id: int, datos: esquemas.LineaNombreIn, uow: UnidadDep, quien: SoloAdmin):
    return lineas.renombrar_linea(uow, quien, linea_id, datos.nombre, fechas.ahora_utc())


@protegido.get("/lineas/{linea_id}/plan", response_model=list[esquemas.TareaPlanOut])
def ver_plan(linea_id: int, uow: UnidadDep):
    return sanidad.ver_plan(uow, linea_id)


@protegido.put("/lineas/{linea_id}/plan", response_model=list[esquemas.TareaPlanOut])
def definir_plan(linea_id: int, datos: list[esquemas.TareaPlanIn], uow: UnidadDep, quien: SoloAdmin):
    tareas = [TareaPlan(linea_id, t.nombre, t.tipo, t.semana_ideal, t.semana_max, t.nota, id=t.id) for t in datos]
    return sanidad.definir_plan(uow, quien, linea_id, tareas, fechas.ahora_utc())


@protegido.get("/lineas/{linea_id}/curva", response_model=list[esquemas.PuntoCurvaIO])
def ver_curva(linea_id: int, uow: UnidadDep):
    return sanidad.ver_curva(uow, linea_id)


@protegido.put("/lineas/{linea_id}/curva", response_model=list[esquemas.PuntoCurvaIO])
def definir_curva(linea_id: int, datos: list[esquemas.PuntoCurvaIO], uow: UnidadDep, quien: SoloAdmin):
    puntos = [PuntoCurva(p.semana, p.postura_pct, p.peso_g) for p in datos]
    return sanidad.definir_curva(uow, quien, linea_id, puntos, fechas.ahora_utc())


@protegido.get("/sanidad", response_model=esquemas.PanoramaOut)
def panorama_de_sanidad(uow: UnidadDep, fecha: Annotated[date | None, Query()] = None):
    panorama = sanidad.panorama(uow, fecha or fechas.fecha_en_granja(datetime.now(UTC)))
    return esquemas.PanoramaOut(
        fecha=panorama.fecha,
        alertas=panorama.alertas,
        galpones=[
            esquemas.SanidadGalponOut(
                galpon_id=g.galpon_id,
                galpon=g.galpon,
                lote_id=g.lote_id,
                linea=g.linea,
                edad_semanas=g.edad_semanas,
                etapa=g.etapa,
                aves_vivas=g.aves_vivas,
                tareas=[
                    esquemas.TareaDelLoteOut(
                        tarea_id=t.tarea.id,
                        nombre=t.tarea.nombre,
                        tipo=t.tarea.tipo,
                        semana_ideal=t.tarea.semana_ideal,
                        semana_max=t.tarea.semana_max,
                        nota_plan=t.tarea.nota,
                        estado=t.estado,
                        aplicada_en=t.aplicada_en,
                        nota=t.nota,
                        cumplimiento_id=t.cumplimiento_id,
                    )
                    for t in g.tareas
                ],
                pesajes=g.pesajes,
                peso=g.peso,
                postura=g.postura,
            )
            for g in panorama.galpones
        ],
    )


@protegido.put("/lotes/{lote_id}/cumplimientos/{cumplimiento_id}", response_model=esquemas.CumplimientoOut)
def marcar_aplicada(
    lote_id: int, cumplimiento_id: uuid.UUID, datos: esquemas.CumplimientoIn, uow: UnidadDep, quien: UsuarioDep
):
    return sanidad.marcar_aplicada(uow, quien, lote_id, datos.tarea_id, cumplimiento_id, datos.fecha, datos.nota)


@protegido.delete("/cumplimientos/{cumplimiento_id}", status_code=status.HTTP_204_NO_CONTENT)
def deshacer_aplicacion(cumplimiento_id: uuid.UUID, uow: UnidadDep, quien: UsuarioDep):
    sanidad.deshacer_aplicacion(uow, quien, cumplimiento_id, fechas.ahora_utc())


@protegido.put("/lotes/{lote_id}/pesajes/{pesaje_id}", response_model=esquemas.PesajeOut)
def registrar_pesaje(lote_id: int, pesaje_id: uuid.UUID, datos: esquemas.PesajeIn, uow: UnidadDep):
    return sanidad.registrar_pesaje(uow, lote_id, pesaje_id, datos.fecha, datos.peso_g, datos.aves_pesadas)


@protegido.delete("/pesajes/{pesaje_id}", status_code=status.HTTP_204_NO_CONTENT)
def quitar_pesaje(pesaje_id: uuid.UUID, uow: UnidadDep, quien: UsuarioDep):
    sanidad.quitar_pesaje(uow, quien, pesaje_id, fechas.ahora_utc())


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
    "/bodegas",
    response_model=esquemas.BodegaOut,
    dependencies=[Depends(administrador)],
    status_code=status.HTTP_201_CREATED,
)
def crear_bodega(datos: esquemas.BodegaIn, uow: UnidadDep):
    bodega = inventario.crear_bodega(uow, datos.nombre, datos.tipo)
    return esquemas.BodegaOut(id=bodega.id, nombre=bodega.nombre, tipo=bodega.tipo, galpon_ids=[])


@protegido.get("/bodegas", response_model=list[esquemas.BodegaOut])
def listar_bodegas(uow: UnidadDep):
    return [
        esquemas.BodegaOut(id=b.id, nombre=b.nombre, tipo=b.tipo, galpon_ids=galpones)
        for b, galpones in inventario.listar_bodegas(uow)
    ]


@protegido.put("/bodegas/{bodega_id}/galpones", response_model=esquemas.GalponesIn)
def asignar_galpones(bodega_id: int, datos: esquemas.GalponesIn, uow: UnidadDep, quien: SoloAdmin):
    ids = inventario.asignar_galpones(uow, quien, bodega_id, datos.galpon_ids, fechas.ahora_utc())
    return esquemas.GalponesIn(galpon_ids=ids)


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
    return inventario.registrar_compra(
        uow, quien, insumo_id, datos.bodega_id, fecha, datos.bultos, datos.kg, datos.operacion_id
    )


@protegido.post("/insumos/{insumo_id}/ajuste", response_model=esquemas.MovimientoOut | None)
def ajustar_stock(insumo_id: int, datos: esquemas.AjusteIn, uow: UnidadDep, quien: UsuarioDep):
    fecha = datos.fecha or fechas.fecha_en_granja(datetime.now(UTC))
    return inventario.ajustar_stock(
        uow, quien, insumo_id, datos.bodega_id, fecha, datos.bultos_reales, datos.kg_reales, datos.nota
    )


@protegido.post(
    "/insumos/{insumo_id}/gastos", response_model=esquemas.MovimientoOut, status_code=status.HTTP_201_CREATED
)
def registrar_gasto(insumo_id: int, datos: esquemas.GastoIn, uow: UnidadDep, quien: UsuarioDep):
    fecha = datos.fecha or fechas.fecha_en_granja(datetime.now(UTC))
    return inventario.registrar_gasto(
        uow, quien, insumo_id, datos.bodega_id, fecha, datos.bultos, datos.kg, datos.nota, datos.operacion_id
    )


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
    return inventario.preparar_alimento(
        uow, quien, producto_id, datos.desde_bodega_id, datos.hacia_bodega_id, fecha, datos.kg, datos.operacion_id
    )


@protegido.put("/bodegas/{bodega_id}/alimento-en-uso/{etapa}", status_code=status.HTTP_204_NO_CONTENT)
def definir_alimento_en_uso(bodega_id: int, etapa: Etapa, datos: esquemas.EnUsoIn, uow: UnidadDep, quien: SoloAdmin):
    inventario.definir_alimento_en_uso(uow, quien, bodega_id, etapa, datos.insumo_id, fechas.ahora_utc())
