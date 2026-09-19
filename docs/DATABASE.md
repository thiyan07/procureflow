# Database — ProcureFlow PostgreSQL (2026-09-19)

**Engine:** `psycopg[binary]` `sqlalchemy 2.0` `DeclarativeBase` `pool_pre_ping` `SessionLocal` `Base.metadata.create_all` if `is_dev` else `alembic upgrade head` | **File:** `sqlite:////home/thiyan/projects/ece/backend/dev.db` 264K `dev` | `postgresql+psycopg://procureflow:procureflow@localhost:5432/procureflow` prod.

## Tables 18

### users
- `id String PK uuid4` `mobile String unique index` `role String FARMER/CENTRE_OPERATOR/ADMIN` `created_at DateTime` | `User` `farmer` one-to-one.

### farmers
- `id String PK uuid4` `user_id String FK users.id onDelete CASCADE unique index` `full_name String` `mobile String` `farmer_id String FARM-2026-* unique` `village String` `district String` `language_code String en/ta/hi` `primary_commodity String` `created_at` | `User.farmer`.

### procurement_centres
- `id String PK uuid4` (seed `c1-c4`) `name String 150` `location String 255` `district String 100` `lat Float` `lng Float` `status String Open/Closed/Busy/Emergency` `active_counters Integer 3` `avg_processing_minutes Integer 3` `open_time Time 09:00` `close_time Time 17:00` `is_active Boolean true` `created_at` | `slots` `bookings`.

### commodities
- `id String PK uuid4` `name String unique` `code String` `rate_per_quintal Float` `Paddy 2441 Grade A 2461 Ragi 4886 Maize 2400 Tur 8000` KMS 2026-27.

### slots
- `id String PK uuid4` `centre_id FK procurement_centres.id CASCADE index` `date Date index` `start_time Time` `end_time Time` `capacity Integer 20` `booked Integer 0` `status String AVAILABLE/FULL/CLOSED` `created_at` | `UniqueConstraint centre_date_time` `CheckConstraint booked>=0 AND booked<=capacity` `centre` `bookings`.

### bookings
- `id String PK uuid4` `farmer_id FK farmers.id CASCADE index` `centre_id FK procurement_centres.id` `slot_id FK slots.id` `commodity_id FK commodities.id nullable` `commodity_name String 50` `estimated_quantity Float` `commodities_json Text nullable` `token_number String 20` `date Date` `status String CONFIRMED/CANCELLED` `created_at` `updated_at` | `farmer` `centre` `slot` `queue_token viewonly` `procurement`.

### centre_queue_states
- `centre_id FK procurement_centres.id CASCADE PK` `date String YYYY-MM-DD PK` `current_ordinal Integer 0` `next_ordinal Integer 1` `updated_at` | For `with_for_update` token generation.

### queue_tokens
- `id String PK uuid4` `centre_id FK procurement_centres.id index` `booking_id FK bookings.id CASCADE unique` `token_number String 20 P27` `position Integer ordinal` `status String WAITING/CALLED/ARRIVED/PROCESSING/COMPLETED/CANCELLED/NO_SHOW/ON_HOLD` `estimated_wait_minutes Integer` `created_at` `updated_at` | `booking` `events`.

### queue_events
- `id String PK uuid4` `token_id FK queue_tokens.id CASCADE index` `from_status String nullable` `to_status String` `actor String nullable user.id` `created_at` | `token`.

### procurements
- `id String PK uuid4` `booking_id FK bookings.id CASCADE unique` `stage String BOOKING_CONFIRMED→COMPLETED` `created_at` `updated_at` | `booking` `weighment` `quality_check` `events`.

### weighments
- `id String PK uuid4` `procurement_id FK procurements.id CASCADE unique` `gross_weight Float nullable` `net_weight Float nullable` `weighment_time DateTime nullable` `operator_id String nullable` | `procurement`.

### quality_checks
- `id String PK uuid4` `procurement_id FK procurements.id CASCADE unique` `grade String 20 A/B/C nullable` `moisture_percent Float nullable 0-30` `remarks String 255 nullable` `checked_at DateTime nullable` | `procurement`.

### procurement_events
- `id String PK uuid4` `procurement_id FK procurements.id CASCADE index` `from_stage String nullable` `to_stage String` `actor String nullable` `created_at` | `procurement`.

### payments
- `id String PK uuid4` `booking_id FK bookings.id CASCADE unique` `commodity String 50` `quantity_quintal Float` `rate_per_quintal Float` `total_amount Float` `status String PENDING/PROCESSING/COMPLETED/FAILED/ON_HOLD` `transaction_id String 100 nullable` `payment_date DateTime nullable` `created_at` `updated_at`.

### notifications
- `id String PK uuid4` `user_id String FK users.id index` `title String` `body String` `type String slot_confirmed/turn_approaching/token_called/queue_position_changed/procurement_stage_updated/payment_status_updated/booking_cancelled/centre_closure` `is_read Boolean false` `created_at` `data JSON String nullable`.

### device_tokens
- `id String PK uuid4` `user_id String FK users.id index` `token String unique` `platform String android/ios` `created_at` `updated_at` dedup `token`.

### feedbacks
- `id String PK uuid4` `user_id FK users.id CASCADE index` `category String delay/quality/payment/other` `description Text` `status String OPEN/REVIEWED/RESOLVED default OPEN` `created_at` `updated_at`.

### audit_logs
- `id String PK uuid4` `user_id String nullable` `action String 100` `entity_type String 50 nullable` `entity_id String nullable` `details String 1000 nullable redacted` `created_at`.

## Indexes
- `users.mobile` `farmers.user_id` `slots centre_id/date` `bookings farmer_id` `queue_tokens centre_id` `queue_tokens booking_id unique` `centre_queue_states PK` `queue_events token_id` `procurement_events procurement_id` `notifications user_id` `device_tokens token unique` `feedbacks user_id`.

## Constraints
- `uq_slot_centre_date_time` `ck_slot_booked_capacity booked>=0 AND booked<=capacity` `Check moisture 0-30` `qty 0-500` `grade A/B/C` in API validation.

## Relationships
`User→Farmer→Booking→Slot→QueueToken→Procurement→Weighment/QualityCheck→Payment→Notification` FK cascade `with_for_update` for booking atomic `slot.booked` + `CentreQueueState`.

## Migrations
- `alembic.ini` `sqlalchemy.url postgresql+psycopg://procureflow:procureflow@localhost:5432/procureflow`.
- `001_initial.py` stub `SELECT 1` (dev `Base.metadata.create_all`).
- `002_multi_commodity.py` `ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commodities_json TEXT` `revision 002` `down_revision 001`.

## Seed
`scripts/seed.py` `Base.metadata.create_all` `SessionLocal` `if count>0 skip` else `5 commodities` `4 centres c1-c4` `3 users u1 farmer 9876543210 f1 Ravi Kumar, op1 9876543211, uadmin 9999999999` `f2 Muthu Gounder` `8 slots/day×3d 96` `booked [5,3,12,2,8,2,5,12]` `booking b1 P27` `CentreQueueState c1 15/28` `QueueToken P27 WAITING 27` `Procurement BOOKING_CONFIRMED` `Payment Paddy 18.5 2441 45158.5 PENDING` — inserted into `dev.db` 264K, retrieved via `GET /centres` not hardcoded.

## Timestamps
All `DateTime(timezone=True) default utcnow` `onupdate utcnow`, consistent ISO8601 `YYYY-MM-DDTHH:MM:SS+00:00`, `slot.start_time` `Time`.

## Enums
`BookingStatus CONFIRMED/CANCELLED` `SlotStatus AVAILABLE/FULL/CLOSED` `QueueStatus WAITING/CALLED/ARRIVED/PROCESSING/COMPLETED/CANCELLED/NO_SHOW/ON_HOLD` `ProcurementStage BOOKING_CONFIRMED/ARRIVED/WEIGHMENT/QUALITY_CHECK/PROCUREMENT/COMPLETED` `PaymentStatus PENDING/PROCESSING/COMPLETED/FAILED/ON_HOLD` `FeedbackStatus OPEN/REVIEWED/RESOLVED`.

