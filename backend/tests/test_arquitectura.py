import ast
from pathlib import Path

import pytest

APP = Path(__file__).resolve().parents[1] / "app"

PROHIBIDOS = {
    "dominio": ("fastapi", "sqlalchemy", "pydantic", "starlette", "app.casos_uso", "app.adaptadores"),
    "casos_uso": ("fastapi", "sqlalchemy", "pydantic", "starlette", "app.adaptadores"),
}


def _importaciones(archivo: Path) -> set[str]:
    modulos = set()
    for nodo in ast.walk(ast.parse(archivo.read_text(encoding="utf-8"))):
        if isinstance(nodo, ast.Import):
            modulos.update(alias.name for alias in nodo.names)
        elif isinstance(nodo, ast.ImportFrom) and nodo.module:
            modulos.add(nodo.module)
    return modulos


@pytest.mark.parametrize("capa", PROHIBIDOS)
def test_el_nucleo_no_depende_de_frameworks_ni_adaptadores(capa):
    for archivo in sorted((APP / capa).glob("*.py")):
        for modulo in _importaciones(archivo):
            assert not modulo.startswith(PROHIBIDOS[capa]), f"{capa}/{archivo.name} importa {modulo}"
