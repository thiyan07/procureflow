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
    # Production schema creation — all 18 tables with FKs, indexes, constraints
    # Uses Base.metadata.create_all for reproducibility; explicit op.create_table also works
    # This ensures `alembic upgrade head` on empty PostgreSQL creates complete schema
    from app.db.base import Base
    bind = op.get_bind()
    Base.metadata.create_all(bind=bind)

def downgrade():
    from app.db.base import Base
    bind = op.get_bind()
    Base.metadata.drop_all(bind=bind)
