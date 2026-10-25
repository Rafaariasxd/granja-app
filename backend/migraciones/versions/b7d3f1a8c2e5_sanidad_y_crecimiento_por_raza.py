"""sanidad y crecimiento por raza

Revision ID: b7d3f1a8c2e5
Revises: a91c5e0d7b24
Create Date: 2026-10-25 21:30:00.000000

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "b7d3f1a8c2e5"
down_revision: str | Sequence[str] | None = "a91c5e0d7b24"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "plan_sanitario",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("linea_id", sa.Integer(), nullable=False),
        sa.Column("nombre", sa.String(length=80), nullable=False),
        sa.Column("tipo", sa.String(length=20), nullable=False),
        sa.Column("semana_ideal", sa.Integer(), nullable=False),
        sa.Column("semana_max", sa.Integer(), nullable=False),
        sa.Column("nota", sa.Text(), nullable=False),
        sa.Column("activa", sa.Boolean(), nullable=False),
        sa.CheckConstraint("semana_ideal >= 0", name=op.f("ck_plan_sanitario_semana_ideal")),
        sa.CheckConstraint("semana_max >= semana_ideal", name=op.f("ck_plan_sanitario_semana_max")),
        sa.ForeignKeyConstraint(
            ["linea_id"], ["lineas_geneticas.id"], name=op.f("fk_plan_sanitario_linea_id_lineas_geneticas")
        ),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_plan_sanitario")),
    )
    op.create_table(
        "cumplimientos",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("lote_id", sa.Integer(), nullable=False),
        sa.Column("tarea_id", sa.Integer(), nullable=False),
        sa.Column("fecha", sa.Date(), nullable=False),
        sa.Column("nota", sa.Text(), nullable=False),
        sa.Column("usuario_id", sa.Integer(), nullable=True),
        sa.ForeignKeyConstraint(["lote_id"], ["lotes.id"], name=op.f("fk_cumplimientos_lote_id_lotes")),
        sa.ForeignKeyConstraint(
            ["tarea_id"], ["plan_sanitario.id"], name=op.f("fk_cumplimientos_tarea_id_plan_sanitario")
        ),
        sa.ForeignKeyConstraint(["usuario_id"], ["usuarios.id"], name=op.f("fk_cumplimientos_usuario_id_usuarios")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_cumplimientos")),
        sa.UniqueConstraint("lote_id", "tarea_id", name=op.f("uq_cumplimientos_lote_id_tarea_id")),
    )
    op.create_table(
        "pesajes",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("lote_id", sa.Integer(), nullable=False),
        sa.Column("fecha", sa.Date(), nullable=False),
        sa.Column("peso_g", sa.Double(), nullable=False),
        sa.Column("aves_pesadas", sa.Integer(), nullable=False),
        sa.CheckConstraint("aves_pesadas > 0", name=op.f("ck_pesajes_aves_pesadas")),
        sa.CheckConstraint("peso_g > 0", name=op.f("ck_pesajes_peso_g")),
        sa.ForeignKeyConstraint(["lote_id"], ["lotes.id"], name=op.f("fk_pesajes_lote_id_lotes")),
        sa.PrimaryKeyConstraint("id", name=op.f("pk_pesajes")),
    )
    with op.batch_alter_table("lineas_geneticas", schema=None) as batch_op:
        batch_op.add_column(sa.Column("revisada", sa.Boolean(), server_default=sa.false(), nullable=False))


def downgrade() -> None:
    with op.batch_alter_table("lineas_geneticas", schema=None) as batch_op:
        batch_op.drop_column("revisada")

    op.drop_table("pesajes")
    op.drop_table("cumplimientos")
    op.drop_table("plan_sanitario")
