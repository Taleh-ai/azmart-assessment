-- Pipeline-generated reconciliation: bronze -> silver -> gold, gross/recognized AZN cəmləri.
select 'bronze.orders' as stage, count(*) as row_count, null::numeric as gross_azn, null::numeric as recognized_azn
from bronze.orders

union all

select 'silver.order_lines (valid)', count(*), null, null
from silver.order_lines

union all

select 'quarantine.order_lines', count(*), null, null
from quarantine.order_lines

union all

select 'gold.fct_order_lines', count(*),
    round(sum(gross_amount_azn), 2),
    round(sum(gross_amount_azn) filter (where is_recognized), 2)
from gold.fct_order_lines;
