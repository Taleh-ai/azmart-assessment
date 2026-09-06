with events as (
    select distinct
        payload->>'event_id' as event_id,
        payload->>'order_id' as order_id,
        payload->>'op' as op,
        payload->>'old_status' as old_status,
        payload->>'new_status' as new_status,
        (payload->>'event_ts')::timestamptz as event_ts,
        payload->>'source' as source
    from {{ source('bronze', 'events') }}
),

known_orders as (
    select distinct payload->>'order_id' as order_id
    from {{ source('bronze', 'orders') }}
)

select
    e.event_id,
    e.order_id,
    e.op,
    e.old_status,
    e.new_status,
    e.event_ts,
    e.source,
    case
        when e.event_id is null or e.event_id = '' then 'missing_event_id'
        when ko.order_id is null then 'unknown_order'
    end as reason_code
from events e
left join known_orders ko on ko.order_id = e.order_id
