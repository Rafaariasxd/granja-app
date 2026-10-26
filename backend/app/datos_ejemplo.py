import uuid
from datetime import UTC, date, datetime, timedelta

from app.adaptadores.db.conexion import SessionLocal
from app.adaptadores.db.repositorios import UnidadDeTrabajoSql
from app.casos_uso import finanzas, galpones, huevos, inventario, lineas, lotes, registros, sanidad
from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio import produccion
from app.dominio.fechas import ahora_utc, fecha_en_granja
from app.dominio.finanzas import MovimientoDinero, Rubro
from app.dominio.huevos import PrecioHuevo, a_huevos
from app.dominio.modelos import Etapa, Ingrediente, Lote, Rol, TipoBodega, TipoInsumo, Usuario
from app.dominio.sanidad import punto_en

CAPACIDADES = {
    "Galpón 1": 6000,
    "Galpón 2": 2000,
    "Galpón 3": 4000,
    "Galpón 4": 3000,
    "Galpón 5": 2500,
    "Galpón 6": 3000,
    "Galpón 7": 5000,
}

POSTURA_ULTIMA_SEMANA = {
    "Galpón 1": [93, 92, 93, 91, 87, 86, 86],
    "Galpón 3": [89, 90, 88, 89, 90, 89, None],
}


MATERIAS_PRIMAS = {
    "Maíz": (50, 60),
    "Soya": (40, 30),
    "Calcio": (25, 24),
    "Palmiste": (40, 20),
    "Premezcla de vitaminas": (25, 8),
}
FORMULA_EJEMPLO = {"Maíz": 55, "Soya": 22, "Calcio": 10, "Palmiste": 10, "Premezcla de vitaminas": 3}


def cargar(uow: UnidadDeTrabajo, hoy: date) -> None:
    if uow.galpones.listar():
        raise SystemExit("La base ya tiene galpones: no se cargan datos de ejemplo.")
    ids = {nombre: galpones.crear_galpon(uow, nombre, capacidad).id for nombre, capacidad in CAPACIDADES.items()}
    hy_line = lineas.crear_linea(uow, "Hy-Line Brown", "Hy-Line Brown").id
    lohmann = lineas.crear_linea(uow, "Lohmann Brown", "Lohmann Brown").id

    creados = {}
    for nombre, linea, semanas, aves in [
        ("Galpón 1", hy_line, 32, 2500),
        ("Galpón 3", lohmann, 45, 1650),
        ("Galpón 5", hy_line, 12, 960),
    ]:
        nacimiento = hoy - timedelta(weeks=semanas)
        creados[nombre] = lotes.crear_lote(
            uow,
            Lote(
                galpon_id=ids[nombre],
                linea_id=linea,
                fecha_nacimiento=nacimiento,
                fecha_ingreso=nacimiento + timedelta(days=1),
                aves_iniciales=aves,
            ),
        )

    administrador = next((u for u in uow.usuarios.listar() if u.rol == Rol.ADMINISTRADOR), None)
    quien = administrador or Usuario("ejemplo", Rol.ADMINISTRADOR, "")
    _cargar_sanidad(uow, quien, creados, hoy)
    _cargar_finanzas(uow, quien, creados["Galpón 1"], hoy)
    if administrador is not None:
        _cargar_inventario(uow, administrador, hoy - timedelta(days=7), ids)

    vivas = {"Galpón 1": 2500, "Galpón 3": 1650, "Galpón 5": 960}
    for dia in range(7):
        fecha = hoy - timedelta(days=6 - dia)
        for nombre, posturas in POSTURA_ULTIMA_SEMANA.items():
            postura = posturas[dia]
            if postura is None:
                continue
            muertas = 3 if nombre == "Galpón 1" else 2
            vivas[nombre] -= muertas
            _registrar(uow, ids[nombre], fecha, round(vivas[nombre] * postura / 100), muertas, vivas[nombre] * 0.11)
        vivas["Galpón 5"] -= 1
        _registrar(uow, ids["Galpón 5"], fecha, 0, 1, vivas["Galpón 5"] * 0.045)


BODEGA_DE_HUEVO = {
    "Jumbo": (186000, 17000, 174000, 2, 6),
    "Extra": (168000, 15500, 156000, 6, 0),
    "AA": (150000, 14000, 138000, 12, 4),
    "A": (132000, 12500, 120000, 8, 0),
    "B": (114000, 11000, 102000, 3, 7),
    "C": (96000, 9000, 84000, 1, 2),
}
VENTAS_EJEMPLO = [
    (3, "AA", 9000, 2700000, "Tienda La Esperanza"),
    (3, "A", 4500, 1215000, "Tienda La Esperanza"),
    (10, "AA", 8400, 2520000, "Plaza de mercado"),
    (17, "B", 6600, 1584000, "Plaza de mercado"),
]
GASTOS_EJEMPLO = [
    (2, Rubro.ALIMENTO, 1480000, "Camión de alimento de ponedora"),
    (9, Rubro.VACUNAS_MEDICINAS, 215000, "Vacunas del mes"),
    (14, Rubro.MANO_DE_OBRA, 900000, "Pago quincenal"),
]


def _cargar_finanzas(uow: UnidadDeTrabajo, quien: Usuario, lote: Lote, hoy: date) -> None:
    for nombre in finanzas.CATEGORIAS_INICIALES:
        if uow.categorias.por_nombre(nombre) is None:
            finanzas.crear_categoria(uow, nombre)
    for nombre, (caja, carton, mayorista, cajas, cartones) in BODEGA_DE_HUEVO.items():
        categoria = uow.categorias.por_nombre(nombre)
        huevos.fijar_precio(uow, PrecioHuevo(categoria.id, caja, carton, mayorista))
        huevos.ingresar(uow, quien, uuid.uuid4(), hoy, categoria.id, a_huevos(cajas, cartones))
    for dias, categoria, cantidad, valor, cliente in VENTAS_EJEMPLO:
        movimiento = MovimientoDinero(
            id=uuid.uuid4(),
            fecha=hoy - timedelta(days=dias),
            rubro=Rubro.VENTA_HUEVO,
            valor=valor,
            lote_id=lote.id,
            categoria_id=uow.categorias.por_nombre(categoria).id,
            cantidad_huevos=cantidad,
            contraparte=cliente,
        )
        finanzas.guardar_movimiento(uow, quien, movimiento)
    for dias, rubro, valor, descripcion in GASTOS_EJEMPLO:
        movimiento = MovimientoDinero(
            id=uuid.uuid4(), fecha=hoy - timedelta(days=dias), rubro=rubro, valor=valor, descripcion=descripcion
        )
        finanzas.guardar_movimiento(uow, quien, movimiento)


PENDIENTES = {"Galpón 1": {"Newcastle (refuerzo en postura)"}}
PESO_EJEMPLO = {"Galpón 5": 0.93}


def _cargar_sanidad(uow: UnidadDeTrabajo, quien: Usuario, creados: dict, hoy: date) -> None:
    for nombre, lote in creados.items():
        edad = produccion.edad_semanas(lote.fecha_nacimiento, hoy)
        for tarea in uow.plan.de(lote.linea_id):
            if tarea.semana_max < edad - 1 and tarea.nombre not in PENDIENTES.get(nombre, set()):
                dia = lote.fecha_nacimiento + timedelta(weeks=tarea.semana_ideal)
                sanidad.marcar_aplicada(uow, quien, lote.id, tarea.id, uuid.uuid4(), dia, "")
        if nombre in PESO_EJEMPLO:
            curva = uow.curvas.de(lote.linea_id)
            esperado = punto_en(curva, produccion.edad_semanas(lote.fecha_nacimiento, hoy - timedelta(days=2))).peso_g
            sanidad.registrar_pesaje(
                uow, lote.id, uuid.uuid4(), hoy - timedelta(days=2), round(esperado * PESO_EJEMPLO[nombre]), 40
            )


def _cargar_inventario(uow: UnidadDeTrabajo, quien: Usuario, fecha: date, galpones_: dict[str, int]) -> None:
    ponedoras = inventario.crear_bodega(uow, "Bodega 1", TipoBodega.ALIMENTO)
    levante_ = inventario.crear_bodega(uow, "Bodega 2", TipoBodega.ALIMENTO)
    materia = inventario.crear_bodega(uow, "Bodega de materia prima", TipoBodega.MATERIA_PRIMA)
    inventario.asignar_galpones(uow, quien, ponedoras.id, [galpones_["Galpón 1"], galpones_["Galpón 3"]], ahora_utc())
    inventario.asignar_galpones(uow, quien, levante_.id, [galpones_["Galpón 5"]], ahora_utc())

    ids = {}
    for nombre, (kg_por_bulto, bultos) in MATERIAS_PRIMAS.items():
        ids[nombre] = inventario.crear_insumo(uow, nombre, TipoInsumo.MATERIA_PRIMA, None, kg_por_bulto).id
        inventario.registrar_compra(uow, quien, ids[nombre], materia.id, fecha, bultos, None)
    mezcla = inventario.crear_insumo(uow, "Mezcla ponedora", TipoInsumo.ALIMENTO_PREPARADO, Etapa.PRODUCCION, None)
    inventario.definir_formula(
        uow, quien, mezcla.id, [Ingrediente(ids[n], pct) for n, pct in FORMULA_EJEMPLO.items()], ahora_utc()
    )
    inventario.preparar_alimento(uow, quien, mezcla.id, materia.id, ponedoras.id, fecha, 3800)
    inventario.definir_alimento_en_uso(uow, quien, ponedoras.id, Etapa.PRODUCCION, mezcla.id, ahora_utc())
    levante = inventario.crear_insumo(uow, "Italcol levante", TipoInsumo.ALIMENTO_COMPRADO, Etapa.LEVANTE, 40)
    inventario.registrar_compra(uow, quien, levante.id, levante_.id, fecha, 10, None)
    inventario.definir_alimento_en_uso(uow, quien, levante_.id, Etapa.LEVANTE, levante.id, ahora_utc())


def _registrar(uow: UnidadDeTrabajo, galpon_id: int, fecha: date, huevos: int, muertas: int, alimento: float) -> None:
    registros.guardar_registro(
        uow,
        registros.RegistroDelDia(
            id=uuid.uuid4(),
            galpon_id=galpon_id,
            fecha=fecha,
            huevos_total=huevos,
            huevos_rotos=round(huevos * 0.006),
            mortalidad=muertas,
            alimento_kg=round(alimento, 1),
        ),
    )


if __name__ == "__main__":
    with SessionLocal() as session:
        cargar(UnidadDeTrabajoSql(session), fecha_en_granja(datetime.now(UTC)))
    print("Datos de ejemplo cargados: 7 galpones, 3 lotes y la última semana de registros.")
