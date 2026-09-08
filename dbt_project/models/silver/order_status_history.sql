{{ config(materialized='incremental', unique_key='event_id', incremental_strategy='delete+insert') }}

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

{% if is_incremental() %}
  and event_ts > (select coalesce(max(event_ts), '1900-01-01'::timestamptz) from {{ this }})
{% endif %}
