{{ config(schema='quarantine', alias='order_lines') }}

select
    md5(order_id || ':' || line_number || ':' || reason_code) as quarantine_id,
    'silver_order_lines' as source,
    reason_code,
    to_jsonb(stg_order_lines.*) as payload,
    now() as quarantined_at
from {{ ref('stg_order_lines') }} as stg_order_lines
where reason_code is not null
