{{ config(materialized='incremental', unique_key=['order_id', 'line_number'], incremental_strategy='delete+insert') }}

select
    order_id,
    line_number,
    customer_id,
    product_id,
    status,
    channel,
    currency,
    order_ts,
    updated_at,
    quantity,
    unit_price
from {{ ref('stg_order_lines') }}
where reason_code is null

{% if is_incremental() %}
  and order_id in (
      select order_id from {{ ref('stg_order_lines') }}
      where updated_at > (select coalesce(max(updated_at), '1900-01-01'::timestamptz) from {{ this }})
  )
{% endif %}
