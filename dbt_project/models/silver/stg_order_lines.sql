{{ config(materialized='view') }}

with orders as (
    select
        payload->>'order_id' as order_id,
        payload->>'customer_id' as customer_id,
        payload->>'status' as status,
        payload->>'channel' as channel,
        upper(trim(payload->>'currency')) as currency,
        payload->'items' as items,
        (payload->>'updated_at')::timestamptz as updated_at,
        case
            when payload->>'order_ts' ~ '^\d+$'
                then to_timestamp((payload->>'order_ts')::bigint / 1000.0)
            when payload->>'order_ts' ~ '^\d{2}\.\d{2}\.\d{4} \d{2}:\d{2}:\d{2}$'
                then (to_timestamp(payload->>'order_ts', 'DD.MM.YYYY HH24:MI:SS') at time zone 'Asia/Baku')
            else (payload->>'order_ts')::timestamptz
        end as order_ts,
        case
            when row_number() over (
                partition by payload->>'order_id'
                order by (payload->>'updated_at')::timestamptz desc
            ) > 1
                then 'duplicate_order'
        end as order_reject_reason
    from {{ source('bronze', 'orders') }}
),

lines as (
    select
        o.order_id,
        o.customer_id,
        o.status,
        o.channel,
        o.currency,
        o.order_ts,
        o.updated_at,
        o.order_reject_reason,
        item.ordinality as line_number,
        item.value->>'product_id' as product_id,
        (item.value->>'quantity')::numeric as quantity,
        case
            when jsonb_typeof(item.value->'unit_price') = 'string'
                then nullif(replace(item.value->>'unit_price', ',', ''), '')::numeric
            else (item.value->>'unit_price')::numeric
        end as unit_price
    from orders o,
         jsonb_array_elements(o.items) with ordinality as item(value, ordinality)
),

known_customers as (
    select distinct customer_id from {{ source('bronze', 'customers') }}
),

known_products as (
    select distinct product_id from {{ source('bronze', 'products') }}
)

select
    l.order_id,
    l.line_number,
    l.customer_id,
    l.product_id,
    l.status,
    l.channel,
    l.currency,
    l.order_ts,
    l.updated_at,
    l.quantity,
    l.unit_price,
    coalesce(
        l.order_reject_reason,
        case
            when l.customer_id is null or l.customer_id = '' then 'missing_customer_id'
            when l.currency not in ('AZN', 'USD', 'EUR', 'TRY') then 'unsupported_currency'
            when l.order_ts < '2020-01-01' then 'implausible_order_ts'
            when l.unit_price is null then 'missing_unit_price'
            when l.unit_price < 0 then 'negative_unit_price'
            when l.quantity <= 0 then 'invalid_quantity'
            when kc.customer_id is null then 'unknown_customer'
            when kp.product_id is null then 'unknown_product'
        end
    ) as reason_code
from lines l
left join known_customers kc on kc.customer_id = l.customer_id
left join known_products kp on kp.product_id = l.product_id
