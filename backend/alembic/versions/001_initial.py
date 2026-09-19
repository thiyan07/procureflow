"""initial

Revision ID: 001
Revises:
Create Date: 2026-09-17
"""
from alembic import op
import sqlalchemy as sa

revision = '001'
down_revision = None
branch_labels = None
depends_on = None

def upgrade():
    # This is a stub - actual creation via Base.metadata.create_all in dev.
    # For production, run `alembic revision --autogenerate` against a DB.
    op.execute(sa.text("SELECT 1"))

def downgrade():
    op.execute(sa.text("SELECT 1"))
