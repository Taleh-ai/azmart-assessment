-- Status funnel (event-based, snapshot-dan yox): hər mərhələyə çatan sifariş sayı,
-- stage-to-stage conversion %. Cancel/refund rate-ləri "created"-ə nisbətən ayrıca sətir.
with stage_counts as (
    select
        new_status as stage,
        count(distinct order_id) as orders_reached,
        case new_status
            when 'CREATED' then 1
            when 'CONFIRMED' then 2
            when 'PACKED' then 3
            when 'SHIPPED' then 4
            when 'DELIVERED' then 5
        end as stage_order
    from gold.fct_order_status_events
    where new_status in ('CREATED', 'CONFIRMED', 'PACKED', 'SHIPPED', 'DELIVERED')
    group by 1
),

total_created as (
    select orders_reached as n from stage_counts where stage = 'CREATED'
)

select
    stage,
    orders_reached,
    round(100.0 * orders_reached / lag(orders_reached) over (order by stage_order), 2) as pct
from stage_counts

union all

select
    'CANCELLED' as stage,
    count(distinct order_id) as orders_reached,
    round(100.0 * count(distinct order_id) / (select n from total_created), 2) as pct
from gold.fct_order_status_events
where new_status = 'CANCELLED'

union all

select
    'REFUNDED' as stage,
    count(distinct order_id) as orders_reached,
    round(100.0 * count(distinct order_id) / (select n from total_created), 2) as pct
from gold.fct_order_status_events
where new_status = 'REFUNDED';
