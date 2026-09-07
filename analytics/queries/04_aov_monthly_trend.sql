-- AOV (average order value) aylıq trend, recognized sifarişlər üzrə.
with order_totals as (
    select
        order_id,
        min(order_date_key) as order_date_key,
        bool_and(is_recognized) as is_recognized,
        sum(gross_amount_azn) as order_total_azn
    from gold.fct_order_lines
    group by order_id
)

select
    date_trunc('month', dd.date_day)::date as month,
    round(avg(ot.order_total_azn), 2) as aov_azn,
    count(*) as recognized_order_count
from order_totals ot
join gold.dim_date dd on dd.date_key = ot.order_date_key
where ot.is_recognized
group by 1
order by 1;
