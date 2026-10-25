"""Reglas del inventario de alimento y materias primas. Funciones puras."""

from collections.abc import Mapping, Sequence
from datetime import date, timedelta

from app.dominio.errores import DatosInvalidos
from app.dominio.modelos import Etapa, Ingrediente, TipoInsumo

DIAS_CRITICO = 2
DIAS_POCO = 5
VENTANA_CONSUMO_DIAS = 7
TOLERANCIA_FORMULA = 0.01

NIVEL_BIEN = "bien"
NIVEL_POCO = "poco"
NIVEL_CRITICO = "critico"
NIVEL_SIN_DATOS = "sin_datos"

REQUIEREN_BULTO = (TipoInsumo.MATERIA_PRIMA, TipoInsumo.ALIMENTO_COMPRADO)
SON_ALIMENTO = (TipoInsumo.ALIMENTO_COMPRADO, TipoInsumo.ALIMENTO_PREPARADO)


def validar_insumo(tipo: TipoInsumo, etapa: Etapa | None, kg_por_bulto: float | None) -> None:
    if tipo in SON_ALIMENTO and etapa is None:
        raise DatosInvalidos("el alimento necesita la etapa para la que sirve")
    if tipo == TipoInsumo.MATERIA_PRIMA and etapa is not None:
        raise DatosInvalidos("una materia prima no tiene etapa")
    if tipo in REQUIEREN_BULTO and kg_por_bulto is None:
        raise DatosInvalidos("falta cuántos kilos trae cada bulto")
    if kg_por_bulto is not None and kg_por_bulto <= 0:
        raise DatosInvalidos("los kilos por bulto deben ser mayores que cero")


def kg_de_bultos(bultos: float, kg_por_bulto: float) -> float:
    return round(bultos * kg_por_bulto, 3)


def bultos_de_kg(kg: float, kg_por_bulto: float | None) -> float | None:
    if kg_por_bulto is None:
        return None
    return round(kg / kg_por_bulto, 2)


def validar_formula(ingredientes: Sequence[Ingrediente]) -> None:
    if not ingredientes:
        raise DatosInvalidos("la fórmula necesita al menos un ingrediente")
    if len({i.insumo_id for i in ingredientes}) != len(ingredientes):
        raise DatosInvalidos("un ingrediente está repetido")
    if any(i.porcentaje <= 0 for i in ingredientes):
        raise DatosInvalidos("cada ingrediente debe tener un porcentaje mayor que cero")
    total = sum(i.porcentaje for i in ingredientes)
    if abs(total - 100) > TOLERANCIA_FORMULA:
        raise DatosInvalidos(f"los porcentajes suman {round(total, 2)} y deben sumar 100")


def kg_de_ingredientes(ingredientes: Sequence[Ingrediente], kg_mezcla: float) -> dict[int, float]:
    return {i.insumo_id: round(kg_mezcla * i.porcentaje / 100, 3) for i in ingredientes}


def faltantes(necesidad: Mapping[int, float], stock: Mapping[int, float]) -> dict[int, float]:
    return {
        insumo_id: round(kg - stock.get(insumo_id, 0.0), 3)
        for insumo_id, kg in necesidad.items()
        if kg > stock.get(insumo_id, 0.0)
    }


def mezcla_posible(ingredientes: Sequence[Ingrediente], stock: Mapping[int, float]) -> tuple[float, int]:
    """Kilos de mezcla que alcanzan con el stock y el ingrediente que se acaba primero."""
    por_ingrediente = {i.insumo_id: max(stock.get(i.insumo_id, 0.0), 0.0) / (i.porcentaje / 100) for i in ingredientes}
    limitante = min(por_ingrediente, key=por_ingrediente.get)
    return round(por_ingrediente[limitante], 1), limitante


def dias_de_alcance(stock_kg: float, consumo_diario_kg: float | None) -> float | None:
    if consumo_diario_kg is None or consumo_diario_kg <= 0:
        return None
    return round(max(stock_kg, 0.0) / consumo_diario_kg, 1)


def nivel_de_alcance(dias: float | None) -> str:
    if dias is None:
        return NIVEL_SIN_DATOS
    if dias <= DIAS_CRITICO:
        return NIVEL_CRITICO
    if dias <= DIAS_POCO:
        return NIVEL_POCO
    return NIVEL_BIEN


def consumo_diario(kg_por_dia: Mapping[date, float], hasta: date, ventana: int = VENTANA_CONSUMO_DIAS) -> float | None:
    """Promedio de los días con registro dentro de la ventana que termina en `hasta`."""
    desde = hasta - timedelta(days=ventana - 1)
    kilos = [kg for dia, kg in kg_por_dia.items() if desde <= dia <= hasta and kg > 0]
    if not kilos:
        return None
    return round(sum(kilos) / len(kilos), 2)
