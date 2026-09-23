"""auth security persistence: revoked_tokens + login_attempts

Revision ID: 004
Revises: 003
Create Date: 2026-09-23
"""
from alembic import op
import sqlalchemy as sa

revision = '004'
down_revision = '003'
branch_labels = None
depends_on = None

def upgrade():
    op.create_table('revoked_tokens',
        sa.Column('jti', sa.String(length=100), nullable=False),
        sa.Column('revoked_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('expires_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('jti')
    )
    op.create_table('login_attempts',
        sa.Column('key', sa.String(length=100), nullable=False),
        sa.Column('attempts', sa.Integer(), nullable=False),
        sa.Column('first_attempt_at', sa.DateTime(timezone=True), nullable=True),
        sa.Column('last_attempt_at', sa.DateTime(timezone=True), nullable=True),
        sa.PrimaryKeyConstraint('key')
    )
    # Payment lifecycle columns already added via model; ensure they exist for fresh DB they will be created via create_all,
    # but for existing DB add if missing (idempotent)
    from sqlalchemy import inspect
    bind = op.get_bind()
    insp = inspect(bind)
    cols = [c['name'] for c in insp.get_columns('payments')] if insp.has_table('payments') else []
    if 'gross_amount' not in cols:
        op.add_column('payments', sa.Column('gross_amount', sa.Float(), nullable=True))
    if 'deductions' not in cols:
        op.add_column('payments', sa.Column('deductions', sa.Float(), nullable=True))
    if 'net_payable' not in cols:
        op.add_column('payments', sa.Column('net_payable', sa.Float(), nullable=True))
    if 'payment_method' not in cols:
        op.add_column('payments', sa.Column('payment_method', sa.String(length=30), nullable=True))
    if 'reference_id' not in cols:
        op.add_column('payments', sa.Column('reference_id', sa.String(length=100), nullable=True))

def downgrade():
    op.drop_table('login_attempts')
    op.drop_table('revoked_tokens')
    # columns remain for downgrade simplicity
