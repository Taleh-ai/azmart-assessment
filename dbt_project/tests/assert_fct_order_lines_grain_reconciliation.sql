with fact_count as (
    select count(*) as n from {{ ref('fct_order_lines') }}
),

source_count as (
    select count(*) as n from {{ ref('order_lines') }}
)

select fact_count.n as fact_rows, source_count.n as source_rows
from fact_count, source_count
where fact_count.n != source_count.n
