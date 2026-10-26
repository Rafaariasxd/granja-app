"""ventas y gastos con categorias de huevo

Revision ID: c3e8a5b9d7f1
Revises: b7d3f1a8c2e5
Create Date: 2026-10-25 19:45:08.785077

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "c3e8a5b9d7f1"
down_revision: str | Sequence[str] | None = "b7d3f1a8c2e5"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

CATEGORIAS_INICIALES = ("AA", "A", "B", "C", "Roto")


def upgrade() -> None:
    categorias = op.create_table(
        "categorias_huevo",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("nombre", sa.String(length=50), nullable=False),
        sa.Column("activa", sa.Boolean(), nullable=False),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_categorias_huevo")),
        sa.UniqueConstraint("nombre", name=op.f("uq_categorias_huevo_nombre")),
    )
    op.bulk_insert(categorias, [{"nombre": nombre, "activa": True} for nombre in CATEGORIAS_INICIALES])
    op.create_table(
        "movimientos_dinero",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("fecha", sa.Date(), nullable=False),
        sa.Column("rubro", sa.String(length=30), nullable=False),
        sa.Column("valor", sa.Double(), nullable=False),
        sa.Column("descripcion", sa.Text(), nullable=False),
        sa.Column("lote_id", sa.Integer(), nullable=True),
        sa.Column("categoria_id", sa.Integer(), nullable=True),
        sa.Column("cantidad_huevos", sa.Integer(), nullable=True),
        sa.Column("contraparte", sa.String(length=100), nullable=False),
        sa.Column("usuario_id", sa.Integer(), nullable=True),
        sa.CheckConstraint(
            "cantidad_huevos IS NULL OR cantidad_huevos > 0", name=op.f("ck_movimientos_dinero_cantidad_huevos")
        ),
        sa.CheckConstraint("valor > 0", name=op.f("ck_movimientos_dinero_valor")),
        sa.ForeignKeyConstraint(
            ["categoria_id"],
            ["categorias_huevo.id"],
            name=op.f("fk_movimientos_dinero_categoria_id_categorias_huevo"),
        ),
        sa.ForeignKeyConstraint(["lote_id"], ["lotes.id"], name=op.f("fk_movimientos_dinero_lote_id_lotes")),
        sa.ForeignKeyConstraint(
            ["usuario_id"], ["usuarios.id"], name=op.f("fk_movimientos_dinero_usuario_id_usuarios")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_movimientos_dinero")),
    )
    with op.batch_alter_table("movimientos_dinero", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_movimientos_dinero_fecha"), ["fecha"], unique=False)


def downgrade() -> None:
    with op.batch_alter_table("movimientos_dinero", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_movimientos_dinero_fecha"))

    op.drop_table("movimientos_dinero")
    op.drop_table("categorias_huevo")
