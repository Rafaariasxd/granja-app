"""Valores de referencia para empezar con una raza. Son aproximados y se pueden editar desde la app."""

from app.dominio.sanidad import PuntoCurva, TipoTarea

V, D, M = TipoTarea.VACUNA, TipoTarea.DESPARASITACION, TipoTarea.MANEJO

PLAN_PONEDORAS = [
    ("Marek", V, 0, 0, "Se aplica en la planta de incubación. Marcarla al recibir los pollitos."),
    ("Newcastle y bronquitis (1.ª)", V, 1, 2, ""),
    ("Gumboro (1.ª)", V, 2, 3, ""),
    ("Newcastle y bronquitis (refuerzo)", V, 4, 5, ""),
    ("Gumboro (2.ª)", V, 4, 5, ""),
    ("Cambio a alimento de levante", M, 6, 7, ""),
    ("Viruela aviar", V, 6, 8, "En la membrana del ala."),
    ("Salmonella (1.ª)", V, 8, 10, ""),
    ("Coriza infecciosa (1.ª)", V, 8, 10, ""),
    ("Desparasitación (1.ª)", D, 8, 10, ""),
    ("Encefalomielitis aviar", V, 10, 14, ""),
    ("Newcastle (refuerzo de levante)", V, 12, 14, ""),
    ("Coriza infecciosa (2.ª)", V, 14, 16, ""),
    ("Salmonella (2.ª)", V, 14, 16, ""),
    ("Cambio a alimento de pre-postura", M, 16, 17, ""),
    ("Desparasitación (2.ª)", D, 16, 18, "Antes de que empiecen a poner."),
    ("Estímulo de luz", M, 17, 18, ""),
    ("Cambio a alimento de postura", M, 18, 19, ""),
    ("Newcastle (refuerzo en postura)", V, 28, 30, ""),
    ("Newcastle (refuerzo en postura)", V, 44, 46, ""),
    ("Newcastle (refuerzo en postura)", V, 60, 62, ""),
]

_PESO_HY_LINE = {
    1: 70, 2: 130, 3: 210, 4: 290, 5: 380, 6: 480, 7: 575, 8: 670, 9: 760, 10: 850, 11: 930, 12: 1010,
    13: 1090, 14: 1160, 15: 1230, 16: 1300, 17: 1380, 18: 1470, 20: 1560, 22: 1650, 24: 1730, 26: 1800,
    30: 1890, 40: 1960, 50: 2010, 60: 2040, 70: 2060, 80: 2080,
}  # fmt: skip

_PESO_LOHMANN = {
    1: 75, 2: 135, 3: 215, 4: 300, 5: 395, 6: 495, 7: 595, 8: 690, 9: 785, 10: 875, 11: 960, 12: 1040,
    13: 1115, 14: 1190, 15: 1260, 16: 1330, 17: 1410, 18: 1500, 20: 1620, 22: 1720, 24: 1800, 26: 1870,
    30: 1940, 40: 2000, 50: 2040, 60: 2070, 70: 2090, 80: 2110,
}  # fmt: skip

_POSTURA_HY_LINE = {
    18: 6, 19: 20, 20: 45, 21: 68, 22: 83, 23: 90, 24: 93, 25: 94, 26: 95, 32: 95, 40: 93, 50: 91, 60: 88,
    70: 84, 80: 80,
}  # fmt: skip

_POSTURA_LOHMANN = {
    18: 4, 19: 15, 20: 40, 21: 63, 22: 80, 23: 89, 24: 93, 25: 94, 26: 95, 32: 95, 40: 93, 50: 91, 60: 88,
    70: 84, 80: 80,
}  # fmt: skip


def _entre_puntos(clave: dict[int, float], semana: int) -> float | None:
    semanas = sorted(clave)
    if semana < semanas[0] or semana > semanas[-1]:
        return None
    if semana in clave:
        return float(clave[semana])
    antes = max(s for s in semanas if s < semana)
    despues = min(s for s in semanas if s > semana)
    avance = (semana - antes) / (despues - antes)
    return clave[antes] + (clave[despues] - clave[antes]) * avance


def _curva(peso: dict[int, float], postura: dict[int, float]) -> list[PuntoCurva]:
    puntos = []
    for semana in range(1, 81):
        peso_g = _entre_puntos(peso, semana)
        postura_pct = _entre_puntos(postura, semana)
        puntos.append(
            PuntoCurva(
                semana=semana,
                postura_pct=round(postura_pct, 1) if postura_pct is not None else 0.0,
                peso_g=round(peso_g) if peso_g is not None else None,
            )
        )
    return puntos


PLANTILLAS = {
    "Hy-Line Brown": _curva(_PESO_HY_LINE, _POSTURA_HY_LINE),
    "Lohmann Brown": _curva(_PESO_LOHMANN, _POSTURA_LOHMANN),
}
