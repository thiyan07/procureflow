"""Phase 1 centre intelligence: code, phone, address, daily_capacity, commodities M2M

Revision ID: 005
Revises: 004
Create Date: 2026-09-24
"""
from alembic import op
import sqlalchemy as sa

revision = '005'
down_revision = '004'
branch_labels = None
depends_on = None

def upgrade():
    bind = op.get_bind()
    insp = sa.inspect(bind)

    # --- procurement_centres new columns ---
    cols = [c['name'] for c in insp.get_columns('procurement_centres')] if insp.has_table('procurement_centres') else []
    if 'centre_code' not in cols:
        op.add_column('procurement_centres', sa.Column('centre_code', sa.String(length=20), nullable=True))
        # populate from id for existing rows: c1 -> DPC-C1 etc
        op.execute("UPDATE procurement_centres SET centre_code = 'DPC-' || upper(substr(id,1,4)) WHERE centre_code IS NULL")
        # make it unique where possible (allow nulls for old, but create index)
        try:
            op.create_index('ix_procurement_centres_centre_code', 'procurement_centres', ['centre_code'], unique=True)
        except Exception:
            pass
    if 'phone' not in cols:
        op.add_column('procurement_centres', sa.Column('phone', sa.String(length=15), nullable=True))
        op.execute("UPDATE procurement_centres SET phone = '1800-103-4567' WHERE phone IS NULL")
    if 'address' not in cols:
        op.add_column('procurement_centres', sa.Column('address', sa.Text(), nullable=True))
        op.execute("UPDATE procurement_centres SET address = location WHERE address IS NULL")
    if 'daily_capacity' not in cols:
        op.add_column('procurement_centres', sa.Column('daily_capacity', sa.Integer(), nullable=True))
        op.execute("UPDATE procurement_centres SET daily_capacity = 120 WHERE daily_capacity IS NULL")
    if 'contact_person' not in cols:
        op.add_column('procurement_centres', sa.Column('contact_person', sa.String(length=100), nullable=True))

    # index lat/lng for nearby search (even without PostGIS, help)
    try:
        op.create_index('ix_procurement_centres_lat_lng', 'procurement_centres', ['lat', 'lng'])
    except Exception:
        pass

    # --- centre_commodities M2M ---
    if not insp.has_table('centre_commodities'):
        op.create_table('centre_commodities',
            sa.Column('centre_id', sa.String(), sa.ForeignKey('procurement_centres.id', ondelete='CASCADE'), nullable=False),
            sa.Column('commodity_id', sa.String(), sa.ForeignKey('commodities.id', ondelete='CASCADE'), nullable=False),
            sa.PrimaryKeyConstraint('centre_id', 'commodity_id')
        )
        op.create_index('ix_centre_commodities_centre', 'centre_commodities', ['centre_id'])
        op.create_index('ix_centre_commodities_commodity', 'centre_commodities', ['commodity_id'])
        # seed: each centre supports Paddy + one more based on id hash
        # we insert after commodities are seeded; use SQL to avoid ORM
        # Paddy is common, plus Ragi/Maize alternates
        op.execute("""
            INSERT INTO centre_commodities (centre_id, commodity_id)
            SELECT pc.id, c.id FROM procurement_centres pc, commodities c
            WHERE c.name = 'Paddy'
            ON CONFLICT DO NOTHING
        """)
        op.execute("""
            INSERT INTO centre_commodities (centre_id, commodity_id)
            SELECT pc.id, c.id FROM procurement_centres pc, commodities c
            WHERE pc.id = 'c1' AND c.name = 'Ragi'
            ON CONFLICT DO NOTHING
        """)
        op.execute("""
            INSERT INTO centre_commodities (centre_id, commodity_id)
            SELECT pc.id, c.id FROM procurement_centres pc, commodities c
            WHERE pc.id = 'c2' AND c.name = 'Maize'
            ON CONFLICT DO NOTHING
        """)
        op.execute("""
            INSERT INTO centre_commodities (centre_id, commodity_id)
            SELECT pc.id, c.id FROM procurement_centres pc, commodities c
            WHERE pc.id IN ('c3','c4') AND c.name = 'Paddy'
            ON CONFLICT DO NOTHING
        """)

def downgrade():
    try:
        op.drop_table('centre_commodities')
    except Exception:
        pass
    try:
        op.drop_index('ix_procurement_centres_lat_lng', table_name='procurement_centres')
    except Exception:
        pass
    try:
        op.drop_index('ix_procurement_centres_centre_code', table_name='procurement_centres')
    except Exception:
        pass
    for col in ['contact_person', 'daily_capacity', 'address', 'phone', 'centre_code']:
        try:
            op.drop_column('procurement_centres', col)
        except Exception:
            pass
