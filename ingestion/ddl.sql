CREATE SCHEMA IF NOT EXISTS bronze;

CREATE TABLE IF NOT EXISTS bronze.orders (
    payload jsonb NOT NULL,
    _source text NOT NULL,
    _batch_id text NOT NULL,
    _load_id text NOT NULL,
    _ingested_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bronze.fx_rates (
    rate_date text NOT NULL,
    payload jsonb NOT NULL,
    _source text NOT NULL,
    _batch_id text NOT NULL,
    _load_id text NOT NULL,
    _ingested_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bronze.customers (
    customer_id text,
    full_name text,
    country text,
    segment text,
    signup_date text,
    updated_at text,
    snapshot_date text NOT NULL,
    _source text NOT NULL,
    _batch_id text NOT NULL,
    _load_id text NOT NULL,
    _ingested_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bronze.products (
    product_id text,
    product_name text,
    category text,
    unit_price text,
    currency text,
    updated_at text,
    _source text NOT NULL,
    _batch_id text NOT NULL,
    _load_id text NOT NULL,
    _ingested_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS bronze.events (
    payload jsonb NOT NULL,
    _source_file text NOT NULL,
    _line_no int NOT NULL,
    _source text NOT NULL,
    _batch_id text NOT NULL,
    _load_id text NOT NULL,
    _ingested_at timestamptz NOT NULL DEFAULT now()
);

CREATE SCHEMA IF NOT EXISTS quarantine;

CREATE TABLE IF NOT EXISTS quarantine.records (
    quarantine_id text PRIMARY KEY,
    source text NOT NULL,
    _batch_id text NOT NULL,
    _load_id text NOT NULL,
    reason_code text NOT NULL,
    payload jsonb NOT NULL,
    quarantined_at timestamptz NOT NULL DEFAULT now()
);
