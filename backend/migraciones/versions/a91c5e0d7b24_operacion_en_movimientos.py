"""identificador de operacion en los movimientos de insumo

Revision ID: a91c5e0d7b24
Revises: ddd42b685957
Create Date: 2026-10-25 20:10:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "a91c5e0d7b24"
down_revision: str | Sequence[str] | None = "ddd42b685957"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    with op.batch_alter_table("movimientos_insumo") as lote:
        lote.add_column(sa.Column("operacion_id", sa.Uuid(), nullable=True))
        lote.create_index(op.f("ix_movimientos_insumo_operacion_id"), ["operacion_id"], unique=False)


def downgrade() -> None:
    with op.batch_alter_table("movimientos_insumo") as lote:
        lote.drop_index(op.f("ix_movimientos_insumo_operacion_id"))
        lote.drop_column("operacion_id")
