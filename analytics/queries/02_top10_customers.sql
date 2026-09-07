-- Top-10 müştəri recognized revenue üzrə, rank + ümumi gəlirdəki payı (%).
with customer_revenue as (
    select
        dc.customer_id,
        dc.full_name,
        sum(f.gross_amount_azn) as recognized_revenue_azn
    from gold.fct_order_lines f
    join gold.dim_customer dc on dc.customer_key = f.customer_key
    where f.is_recognized
    group by 1, 2
),

totals as (
    select sum(recognized_revenue_azn) as total_revenue_azn from customer_revenue
)

select
    customer_id,
    full_name,
    round(recognized_revenue_azn, 2) as recognized_revenue_azn,
    rank() over (order by recognized_revenue_azn desc) as revenue_rank,
    round(100.0 * recognized_revenue_azn / totals.total_revenue_azn, 2) as pct_of_total_revenue
from customer_revenue, totals
order by revenue_rank
limit 10;
