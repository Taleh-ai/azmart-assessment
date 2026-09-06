{{ config(schema='quarantine', alias='order_events') }}

select
    md5(coalesce(event_id, 'no_id') || ':' || coalesce(order_id, 'no_order') || ':' || reason_code) as quarantine_id,
    'silver_order_events' as source,
    reason_code,
    to_jsonb(stg_order_events.*) as payload,
    now() as quarantined_at
from {{ ref('stg_order_events') }} as stg_order_events
where reason_code is not null
