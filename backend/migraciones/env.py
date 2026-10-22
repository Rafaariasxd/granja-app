from logging.config import fileConfig

from alembic import context
from sqlalchemy import create_engine, pool

from app.adaptadores.db import tablas
from app.adaptadores.db.conexion import DATABASE_URL

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = tablas.Base.metadata
url = config.get_main_option("sqlalchemy.url") or DATABASE_URL


def run_migrations_offline() -> None:
    context.configure(url=url, target_metadata=target_metadata, literal_binds=True, render_as_batch=True)
    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    engine = create_engine(url, poolclass=pool.NullPool)
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata, render_as_batch=True)
        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
