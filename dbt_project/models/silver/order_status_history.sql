select
    event_id,
    order_id,
    op,
    old_status,
    new_status,
    event_ts,
    source
from {{ ref('stg_order_events') }}
where reason_code is null
