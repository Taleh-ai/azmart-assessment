{{ config(schema='quarantine', alias='order_events', materialized='incremental', unique_key='quarantine_id', incremental_strategy='delete+insert') }}

select
    md5(coalesce(event_id, 'no_id') || ':' || coalesce(order_id, 'no_order') || ':' || reason_code) as quarantine_id,
    'silver_order_events' as source,
    reason_code,
    to_jsonb(stg_order_events.*) as payload,
    now() as quarantined_at
from {{ ref('stg_order_events') }} as stg_order_events
where reason_code is not null

{% if is_incremental() %}
  and event_ts > (select coalesce(max((payload->>'event_ts')::timestamptz), '1900-01-01'::timestamptz) from {{ this }})
{% endif %}
