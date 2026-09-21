"""multi commodity commodities_json

Revision ID: 002
Revises: 001
Create Date: 2026-09-19
"""
from alembic import op
import sqlalchemy as sa

revision = '002'
down_revision = '001'
branch_labels = None
depends_on = None

def upgrade():
    # For existing DBs created with old 001 stub, add column if missing
    # For fresh DBs, 001 already creates commodities_json via Base.metadata.create_all, so this is no-op
    bind = op.get_bind()
    from sqlalchemy import inspect
    inspector = inspect(bind)
    try:
        columns = [c['name'] for c in inspector.get_columns('bookings')]
        if 'commodities_json' not in columns:
            op.add_column('bookings', sa.Column('commodities_json', sa.Text(), nullable=True))
    except Exception:
        # Fallback for DBs where bookings table doesn't exist yet (should not happen after 001)
        try:
            op.add_column('bookings', sa.Column('commodities_json', sa.Text(), nullable=True))
        except Exception:
            pass

def downgrade():
    try:
        op.drop_column('bookings', 'commodities_json')
    except Exception:
        pass
