import uuid
from datetime import UTC, date, datetime, timedelta

from app.adaptadores.db.conexion import SessionLocal
from app.adaptadores.db.repositorios import UnidadDeTrabajoSql
from app.casos_uso import galpones, lineas, lotes, registros
from app.casos_uso.puertos import UnidadDeTrabajo
from app.dominio.fechas import fecha_en_granja
from app.dominio.modelos import Lote

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


def cargar(uow: UnidadDeTrabajo, hoy: date) -> None:
    if uow.galpones.listar():
        raise SystemExit("La base ya tiene galpones: no se cargan datos de ejemplo.")
    ids = {nombre: galpones.crear_galpon(uow, nombre, capacidad).id for nombre, capacidad in CAPACIDADES.items()}
    hy_line = lineas.crear_linea(uow, "Hy-Line Brown").id
    lohmann = lineas.crear_linea(uow, "Lohmann Brown").id

    for nombre, linea, semanas, aves in [
        ("Galpón 1", hy_line, 32, 2500),
        ("Galpón 3", lohmann, 45, 1650),
        ("Galpón 5", hy_line, 12, 960),
    ]:
        nacimiento = hoy - timedelta(weeks=semanas)
        lotes.crear_lote(
            uow,
            Lote(
                galpon_id=ids[nombre],
                linea_id=linea,
                fecha_nacimiento=nacimiento,
                fecha_ingreso=nacimiento + timedelta(days=1),
                aves_iniciales=aves,
            ),
        )

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
