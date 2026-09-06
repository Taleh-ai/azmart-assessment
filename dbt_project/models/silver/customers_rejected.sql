{{ config(schema='quarantine', alias='customers') }}

select
    md5(customer_id || ':' || snapshot_date || ':' || reason_code) as quarantine_id,
    'silver_customers' as source,
    reason_code,
    to_jsonb(stg_customers.*) as payload,
    now() as quarantined_at
from {{ ref('stg_customers') }} as stg_customers
where reason_code is not null
