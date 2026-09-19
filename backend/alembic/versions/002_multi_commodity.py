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
    op.execute(sa.text("ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commodities_json TEXT"))

def downgrade():
    op.execute(sa.text("ALTER TABLE bookings DROP COLUMN IF EXISTS commodities_json"))
