from datetime import date, datetime, timedelta, timezone

HORA_COLOMBIA = timezone(timedelta(hours=-5), "COT")


def fecha_en_granja(momento: datetime) -> date:
    return momento.astimezone(HORA_COLOMBIA).date()


def periodos_se_cruzan(inicio_a: date, fin_a: date | None, inicio_b: date, fin_b: date | None) -> bool:
    """Los periodos incluyen el día final; sin fin, el periodo sigue abierto."""
    return (fin_a is None or fin_a >= inicio_b) and (fin_b is None or fin_b >= inicio_a)
