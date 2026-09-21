"""seed demo passwords for mobile login

Revision ID: 003
Revises: 002
Create Date: 2026-09-21
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.orm import Session

revision = '003'
down_revision = '002'
branch_labels = None
depends_on = None

def upgrade():
    bind = op.get_bind()
    # Ensure users table exists and hashed_password column exists
    # Update demo accounts to have password hash for mobile login
    try:
        from app.core.security import get_password_hash
        # Use password123 as primary demo password; dev fallback also allows 123456
        demo_hash = get_password_hash("password123")
        # Direct SQL update to avoid model import issues during migration
        # Update if hashed_password is NULL
        bind.execute(sa.text("UPDATE users SET hashed_password = :h WHERE mobile = '9876543210' AND (hashed_password IS NULL OR hashed_password = '')"), {"h": demo_hash})
        bind.execute(sa.text("UPDATE users SET hashed_password = :h WHERE mobile = '9876543211' AND (hashed_password IS NULL OR hashed_password = '')"), {"h": demo_hash})
        bind.execute(sa.text("UPDATE users SET hashed_password = :h WHERE mobile = '9999999999' AND (hashed_password IS NULL OR hashed_password = '')"), {"h": demo_hash})
        # Also ensure any existing farmer users without password get demo hash if mobile in demo set? No, skip
    except Exception as e:
        # Do not fail migration if hashing fails; log
        print(f"Migration 003 warning: {e}")
        pass

def downgrade():
    bind = op.get_bind()
    try:
        bind.execute(sa.text("UPDATE users SET hashed_password = NULL WHERE mobile IN ('9876543210','9876543211','9999999999')"))
    except Exception:
        pass
