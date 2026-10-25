"""inventario de alimento y materias primas

Revision ID: 8bf335ba5145
Revises: c642ee9a06bb
Create Date: 2026-10-25 02:09:33.334253

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "8bf335ba5145"
down_revision: str | Sequence[str] | None = "c642ee9a06bb"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "insumos",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("nombre", sa.String(length=80), nullable=False),
        sa.Column("tipo", sa.String(length=30), nullable=False),
        sa.Column("etapa", sa.String(length=20), nullable=True),
        sa.Column("kg_por_bulto", sa.Double(), nullable=True),
        sa.Column("activo", sa.Boolean(), nullable=False),
        sa.CheckConstraint("kg_por_bulto IS NULL OR kg_por_bulto > 0", name=op.f("ck_insumos_kg_por_bulto")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_insumos")),
        sa.UniqueConstraint("nombre", name=op.f("uq_insumos_nombre")),
    )
    op.create_table(
        "alimento_en_uso",
        sa.Column("etapa", sa.String(length=20), nullable=False),
        sa.Column("insumo_id", sa.Integer(), nullable=False),
        sa.ForeignKeyConstraint(["insumo_id"], ["insumos.id"], name=op.f("fk_alimento_en_uso_insumo_id_insumos")),
        sa.PrimaryKeyConstraint("etapa", name=op.f("pk_alimento_en_uso")),
    )
    op.create_table(
        "formulas_ingredientes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("producto_id", sa.Integer(), nullable=False),
        sa.Column("insumo_id", sa.Integer(), nullable=False),
        sa.Column("porcentaje", sa.Double(), nullable=False),
        sa.CheckConstraint("porcentaje > 0", name=op.f("ck_formulas_ingredientes_porcentaje")),
        sa.ForeignKeyConstraint(["insumo_id"], ["insumos.id"], name=op.f("fk_formulas_ingredientes_insumo_id_insumos")),
        sa.ForeignKeyConstraint(
            ["producto_id"], ["insumos.id"], name=op.f("fk_formulas_ingredientes_producto_id_insumos")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_formulas_ingredientes")),
        sa.UniqueConstraint("producto_id", "insumo_id", name=op.f("uq_formulas_ingredientes_producto_id_insumo_id")),
    )
    op.create_table(
        "movimientos_insumo",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("insumo_id", sa.Integer(), nullable=False),
        sa.Column("fecha", sa.Date(), nullable=False),
        sa.Column("kg", sa.Double(), nullable=False),
        sa.Column("motivo", sa.String(length=20), nullable=False),
        sa.Column("usuario_id", sa.Integer(), nullable=True),
        sa.Column("nota", sa.Text(), nullable=False),
        sa.Column("registro_id", sa.Uuid(), nullable=True),
        sa.ForeignKeyConstraint(["insumo_id"], ["insumos.id"], name=op.f("fk_movimientos_insumo_insumo_id_insumos")),
        sa.ForeignKeyConstraint(
            ["registro_id"], ["registros_diarios.id"], name=op.f("fk_movimientos_insumo_registro_id_registros_diarios")
        ),
        sa.ForeignKeyConstraint(
            ["usuario_id"], ["usuarios.id"], name=op.f("fk_movimientos_insumo_usuario_id_usuarios")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_movimientos_insumo")),
        sa.UniqueConstraint("registro_id", name=op.f("uq_movimientos_insumo_registro_id")),
    )


def downgrade() -> None:
    op.drop_table("movimientos_insumo")
    op.drop_table("formulas_ingredientes")
    op.drop_table("alimento_en_uso")
    op.drop_table("insumos")
