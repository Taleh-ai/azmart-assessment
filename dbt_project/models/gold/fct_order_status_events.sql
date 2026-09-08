{{ config(materialized='incremental', unique_key='event_id', incremental_strategy='delete+insert') }}

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

{% if is_incremental() %}
where h.event_ts > (select coalesce(max(event_ts), '1900-01-01'::timestamptz) from {{ this }})
{% endif %}
