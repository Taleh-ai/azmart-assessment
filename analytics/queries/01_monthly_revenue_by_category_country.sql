-- Aylıq recognized revenue (AZN), category x country kəsiyində.
select
    date_trunc('month', dd.date_day)::date as month,
    dp.category,
    dc.country,
    round(sum(f.gross_amount_azn), 2) as recognized_revenue_azn
from gold.fct_order_lines f
join gold.dim_date dd on dd.date_key = f.order_date_key
join gold.dim_product dp on dp.product_id = f.product_id
join gold.dim_customer dc on dc.customer_key = f.customer_key
where f.is_recognized
group by 1, 2, 3
order by 1, 2, 3;
