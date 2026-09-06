with latest_event as (
    select
        order_id,
        new_status as event_status,
        op as latest_event_op,
        row_number() over (partition by order_id order by event_ts desc) as rn
    from {{ ref('order_status_history') }}
),

latest_order as (
    select distinct on (order_id)
        order_id,
        status as api_status
    from {{ ref('stg_order_lines') }}
    order by order_id, updated_at desc
)

select
    o.order_id,
    o.api_status,
    e.event_status,
    e.latest_event_op,
    case
        when e.latest_event_op = 'd' then 'tombstone_erasure'
        when e.order_id is null then 'no_events_for_order'
        when o.api_status is distinct from e.event_status then 'status_mismatch'
        else 'match'
    end as reconciliation_status
from latest_order o
left join latest_event e on e.order_id = o.order_id and e.rn = 1
