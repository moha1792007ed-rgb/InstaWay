CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS admins (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username      text UNIQUE NOT NULL,
  password_hash text NOT NULL,
  active        boolean NOT NULL DEFAULT true,
  failed_attempts int NOT NULL DEFAULT 0,
  locked_until  timestamptz,
  created_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS trips (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  origin           text NOT NULL,
  destination      text NOT NULL,
  depart_at        timestamptz NOT NULL,
  booking_deadline timestamptz NOT NULL,
  capacity         int  NOT NULL DEFAULT 14 CHECK (capacity BETWEEN 1 AND 14),
  price_egp        int  NOT NULL CHECK (price_egp > 0),
  min_passengers   int  NOT NULL CHECK (min_passengers >= 1),
  status           text NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN','CONFIRMED','CANCELLED','COMPLETED')),
  created_at       timestamptz NOT NULL DEFAULT now(),
  CHECK (origin <> destination),
  CHECK (origin = 'أسيوط' OR destination = 'أسيوط'),
  CHECK (booking_deadline <= depart_at),
  CHECK (min_passengers <= capacity)
);
CREATE INDEX IF NOT EXISTS trips_search ON trips (origin, destination, depart_at);
CREATE INDEX IF NOT EXISTS trips_status_deadline ON trips (status, booking_deadline);

CREATE TABLE IF NOT EXISTS bookings (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code            text NOT NULL,
  trip_id         uuid NOT NULL REFERENCES trips(id),
  name            text NOT NULL,
  phone           text NOT NULL,
  total_egp       int  NOT NULL CHECK (total_egp > 0),
  status          text NOT NULL DEFAULT 'PENDING_PAYMENT'
                  CHECK (status IN ('PENDING_PAYMENT','PAID','EXPIRED','CANCELLED','REFUND_DUE','REFUNDED')),
  pay_method      text NOT NULL CHECK (pay_method IN ('VODAFONE','ETISALAT','ORANGE','INSTAPAY')),
  pay_reference   text,
  hold_expires_at timestamptz NOT NULL,
  idempotency_key text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS bookings_code_uq ON bookings (code);
CREATE UNIQUE INDEX IF NOT EXISTS bookings_idem_key ON bookings (idempotency_key);
CREATE INDEX IF NOT EXISTS bookings_trip_status ON bookings (trip_id, status);
CREATE INDEX IF NOT EXISTS bookings_phone_status ON bookings (phone, status);

-- One row per seat. The partial unique index makes double booking impossible at the DB level.
CREATE TABLE IF NOT EXISTS booking_seats (
  booking_id uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  trip_id    uuid NOT NULL REFERENCES trips(id),
  seat_no    int  NOT NULL CHECK (seat_no BETWEEN 1 AND 14),
  active     boolean NOT NULL DEFAULT true,
  PRIMARY KEY (booking_id, seat_no)
);
CREATE UNIQUE INDEX IF NOT EXISTS booking_seats_active_seat ON booking_seats (trip_id, seat_no) WHERE active;

CREATE TABLE IF NOT EXISTS audit_log (
  id        bigserial PRIMARY KEY,
  at        timestamptz NOT NULL DEFAULT now(),
  actor     text NOT NULL,
  action    text NOT NULL,
  entity    text,
  entity_id text,
  meta      jsonb,
  ip        text
);
