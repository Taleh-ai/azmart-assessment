select
    h.event_id,
    h.order_id,
    h.op,
    h.old_status,
    h.new_status,
    h.event_ts,
    dd.date_key as event_date_key,
    (h.event_ts at time zone 'Asia/Baku')::date as event_date_baku
from {{ ref('order_status_history') }} h
left join {{ ref('dim_date') }} dd on dd.date_day = (h.event_ts at time zone 'Asia/Baku')::date
