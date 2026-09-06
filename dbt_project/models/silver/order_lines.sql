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
