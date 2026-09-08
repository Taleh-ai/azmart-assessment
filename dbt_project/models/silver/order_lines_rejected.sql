{{ config(schema='quarantine', alias='order_lines', materialized='incremental', unique_key='quarantine_id', incremental_strategy='delete+insert') }}

select
    md5(order_id || ':' || line_number || ':' || reason_code) as quarantine_id,
    'silver_order_lines' as source,
    reason_code,
    to_jsonb(stg_order_lines.*) as payload,
    now() as quarantined_at
from {{ ref('stg_order_lines') }} as stg_order_lines
where reason_code is not null

{% if is_incremental() %}
  and order_id in (
      select order_id from {{ ref('stg_order_lines') }}
      where updated_at > (select coalesce(max((payload->>'updated_at')::timestamptz), '1900-01-01'::timestamptz) from {{ this }})
  )
{% endif %}
