-- Delivery lead time: CREATED -> DELIVERED müddətinin aylıq p50/p90-ı (saatla, event-based).
with created_events as (
    select order_id, min(event_ts) as created_ts
    from gold.fct_order_status_events
    where new_status = 'CREATED'
    group by order_id
),

delivered_events as (
    select order_id, min(event_ts) as delivered_ts
    from gold.fct_order_status_events
    where new_status = 'DELIVERED'
    group by order_id
),

lead_times as (
    select
        d.order_id,
        d.delivered_ts,
        extract(epoch from (d.delivered_ts - c.created_ts)) / 3600.0 as lead_time_hours
    from delivered_events d
    join created_events c on c.order_id = d.order_id
)

select
    date_trunc('month', delivered_ts at time zone 'Asia/Baku')::date as month,
    round(percentile_cont(0.5) within group (order by lead_time_hours)::numeric, 1) as p50_hours,
    round(percentile_cont(0.9) within group (order by lead_time_hours)::numeric, 1) as p90_hours,
    count(*) as delivered_order_count
from lead_times
group by 1
order by 1;
