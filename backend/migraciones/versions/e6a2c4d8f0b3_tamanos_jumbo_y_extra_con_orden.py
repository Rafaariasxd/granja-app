"""tamanos jumbo y extra con orden

Revision ID: e6a2c4d8f0b3
Revises: d4f9b6c0e8a2
Create Date: 2026-10-26 10:00:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "e6a2c4d8f0b3"
down_revision: str | Sequence[str] | None = "d4f9b6c0e8a2"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

ORDEN = ("Jumbo", "Extra", "AA", "A", "B", "C", "Roto")


def upgrade() -> None:
    with op.batch_alter_table("categorias_huevo", schema=None) as batch_op:
        batch_op.add_column(sa.Column("orden", sa.Integer(), server_default="0", nullable=False))
    conexion = op.get_bind()
    for nombre in ("Jumbo", "Extra"):
        existe = conexion.execute(sa.text("SELECT 1 FROM categorias_huevo WHERE nombre = :n"), {"n": nombre}).first()
        if existe is None:
            conexion.execute(
                sa.text("INSERT INTO categorias_huevo (nombre, activa, orden) VALUES (:n, :a, 0)"),
                {"n": nombre, "a": True},
            )
    conexion.execute(sa.text("UPDATE categorias_huevo SET orden = 100 + id"))
    for posicion, nombre in enumerate(ORDEN, start=1):
        conexion.execute(
            sa.text("UPDATE categorias_huevo SET orden = :o WHERE nombre = :n"), {"o": posicion, "n": nombre}
        )


def downgrade() -> None:
    with op.batch_alter_table("categorias_huevo", schema=None) as batch_op:
        batch_op.drop_column("orden")
