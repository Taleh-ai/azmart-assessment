with order_lines as (
    select
        *,
        (order_ts at time zone 'Asia/Baku')::date as order_date_baku
    from {{ ref('order_lines') }}
),

fx_rates as (
    select
        rate_date::date as rate_date,
        rate->>'currency' as currency,
        (rate->>'rate_azn')::numeric as rate_azn
    from {{ source('bronze', 'fx_rates') }},
         jsonb_array_elements(payload->'rates') as rate
),

fx_as_of as (
    select
        ol.order_id,
        ol.line_number,
        case
            when ol.currency = 'AZN' then 1.0
            else (
                select fx.rate_azn
                from fx_rates fx
                where fx.currency = ol.currency
                  and fx.rate_date <= ol.order_date_baku
                order by fx.rate_date desc
                limit 1
            )
        end as rate_azn
    from order_lines ol
),

final_status as (
    select order_id, final_status
    from {{ ref('order_status_reconciliation') }}
)

select
    ol.order_id,
    ol.line_number,
    dc.customer_key,
    ol.product_id,
    dd.date_key as order_date_key,
    ol.order_date_baku,
    ol.quantity,
    ol.unit_price,
    ol.currency,
    fx.rate_azn,
    ol.quantity * ol.unit_price as gross_amount,
    ol.quantity * ol.unit_price * fx.rate_azn as gross_amount_azn,
    coalesce(fs.final_status, ol.status) as final_status,
    coalesce(fs.final_status, ol.status) not in ('CANCELLED', 'REFUNDED') as is_recognized
from order_lines ol
left join fx_as_of fx on fx.order_id = ol.order_id and fx.line_number = ol.line_number
left join final_status fs on fs.order_id = ol.order_id
left join {{ ref('dim_date') }} dd on dd.date_day = ol.order_date_baku
left join {{ ref('dim_customer') }} dc
    on dc.customer_id = ol.customer_id
    and ol.order_date_baku >= dc.valid_from
    and (dc.valid_to is null or ol.order_date_baku < dc.valid_to)
