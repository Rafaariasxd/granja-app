"""bodega del huevo con salidas y precios

Revision ID: d4f9b6c0e8a2
Revises: c3e8a5b9d7f1
Create Date: 2026-10-25 20:09:54.808387

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "d4f9b6c0e8a2"
down_revision: str | Sequence[str] | None = "c3e8a5b9d7f1"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "precios_huevo",
        sa.Column("categoria_id", sa.Integer(), nullable=False),
        sa.Column("precio_caja", sa.Double(), nullable=True),
        sa.Column("precio_carton", sa.Double(), nullable=True),
        sa.Column("precio_mayorista", sa.Double(), nullable=True),
        sa.ForeignKeyConstraint(
            ["categoria_id"], ["categorias_huevo.id"], name=op.f("fk_precios_huevo_categoria_id_categorias_huevo")
        ),
        sa.PrimaryKeyConstraint("categoria_id", name=op.f("pk_precios_huevo")),
    )
    op.create_table(
        "salidas_huevo",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("fecha", sa.Date(), nullable=False),
        sa.Column("tipo_venta", sa.String(length=20), nullable=False),
        sa.Column("cliente", sa.String(length=100), nullable=False),
        sa.Column("estado", sa.String(length=20), nullable=False),
        sa.Column("usuario_id", sa.Integer(), nullable=True),
        sa.Column("cerrada_el", sa.Date(), nullable=True),
        sa.Column("valor_total", sa.Double(), nullable=True),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuarios.id"], name=op.f("fk_salidas_huevo_usuario_id_usuarios")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_salidas_huevo")),
    )
    with op.batch_alter_table("salidas_huevo", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_salidas_huevo_estado"), ["estado"], unique=False)

    op.create_table(
        "lineas_salida_huevo",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("salida_id", sa.Uuid(), nullable=False),
        sa.Column("categoria_id", sa.Integer(), nullable=False),
        sa.Column("huevos_sacados", sa.Integer(), nullable=False),
        sa.Column("huevos_vendidos", sa.Integer(), nullable=True),
        sa.Column("valor", sa.Double(), nullable=True),
        sa.CheckConstraint("huevos_sacados > 0", name=op.f("ck_lineas_salida_huevo_huevos_sacados")),
        sa.ForeignKeyConstraint(
            ["categoria_id"], ["categorias_huevo.id"], name=op.f("fk_lineas_salida_huevo_categoria_id_categorias_huevo")
        ),
        sa.ForeignKeyConstraint(
            ["salida_id"], ["salidas_huevo.id"], name=op.f("fk_lineas_salida_huevo_salida_id_salidas_huevo")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_lineas_salida_huevo")),
        sa.UniqueConstraint("salida_id", "categoria_id", name=op.f("uq_lineas_salida_huevo_salida_id_categoria_id")),
    )
    op.create_table(
        "movimientos_huevo",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("fecha", sa.Date(), nullable=False),
        sa.Column("categoria_id", sa.Integer(), nullable=False),
        sa.Column("huevos", sa.Integer(), nullable=False),
        sa.Column("motivo", sa.String(length=20), nullable=False),
        sa.Column("usuario_id", sa.Integer(), nullable=True),
        sa.Column("nota", sa.Text(), nullable=False),
        sa.Column("salida_id", sa.Uuid(), nullable=True),
        sa.Column("operacion_id", sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(
            ["categoria_id"], ["categorias_huevo.id"], name=op.f("fk_movimientos_huevo_categoria_id_categorias_huevo")
        ),
        sa.ForeignKeyConstraint(
            ["salida_id"], ["salidas_huevo.id"], name=op.f("fk_movimientos_huevo_salida_id_salidas_huevo")
        ),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuarios.id"], name=op.f("fk_movimientos_huevo_usuario_id_usuarios")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_movimientos_huevo")),
    )
    with op.batch_alter_table("movimientos_huevo", schema=None) as batch_op:
        batch_op.create_index(batch_op.f("ix_movimientos_huevo_categoria_id"), ["categoria_id"], unique=False)
        batch_op.create_index(batch_op.f("ix_movimientos_huevo_operacion_id"), ["operacion_id"], unique=False)


def downgrade() -> None:
    with op.batch_alter_table("movimientos_huevo", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_movimientos_huevo_operacion_id"))
        batch_op.drop_index(batch_op.f("ix_movimientos_huevo_categoria_id"))

    op.drop_table("movimientos_huevo")
    op.drop_table("lineas_salida_huevo")
    with op.batch_alter_table("salidas_huevo", schema=None) as batch_op:
        batch_op.drop_index(batch_op.f("ix_salidas_huevo_estado"))

    op.drop_table("salidas_huevo")
    op.drop_table("precios_huevo")
