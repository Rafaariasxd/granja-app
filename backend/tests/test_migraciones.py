from pathlib import Path

from alembic import command
from alembic.autogenerate import compare_metadata
from alembic.config import Config
from alembic.runtime.migration import MigrationContext
from sqlalchemy import create_engine, inspect

from app.adaptadores.db.tablas import Base

MIGRACIONES = Path(__file__).resolve().parents[1] / "migraciones"


def _config(url: str) -> Config:
    config = Config()
    config.set_main_option("script_location", str(MIGRACIONES))
    config.set_main_option("sqlalchemy.url", url)
    return config


def _url(tmp_path: Path) -> str:
    return f"sqlite:///{(tmp_path / 'granja.db').as_posix()}"


def test_las_migraciones_dejan_el_mismo_esquema_que_los_modelos(tmp_path):
    url = _url(tmp_path)
    command.upgrade(_config(url), "head")
    engine = create_engine(url)
    with engine.connect() as conexion:
        diferencias = compare_metadata(MigrationContext.configure(conexion), Base.metadata)
    engine.dispose()
    assert diferencias == []


def test_la_migracion_incluye_las_validaciones(tmp_path):
    url = _url(tmp_path)
    command.upgrade(_config(url), "head")
    engine = create_engine(url)
    validaciones = {c["name"] for c in inspect(engine).get_check_constraints("registros_diarios")}
    engine.dispose()
    assert validaciones == {
        "ck_registros_diarios_huevos_total",
        "ck_registros_diarios_huevos_rotos",
        "ck_registros_diarios_mortalidad",
        "ck_registros_diarios_alimento_kg",
    }


def test_la_migracion_se_puede_deshacer(tmp_path):
    url = _url(tmp_path)
    config = _config(url)
    command.upgrade(config, "head")
    command.downgrade(config, "base")
    engine = create_engine(url)
    tablas = set(inspect(engine).get_table_names())
    engine.dispose()
    assert tablas <= {"alembic_version"}
