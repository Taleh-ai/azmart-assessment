with days as (
    select generate_series('2026-01-01'::date, '2026-12-31'::date, interval '1 day')::date as date_day
)

select
    to_char(date_day, 'YYYYMMDD')::int as date_key,
    date_day,
    extract(year from date_day)::int as year,
    extract(month from date_day)::int as month,
    extract(day from date_day)::int as day,
    to_char(date_day, 'Month') as month_name,
    extract(quarter from date_day)::int as quarter,
    extract(isodow from date_day)::int as day_of_week,
    extract(isodow from date_day) in (6, 7) as is_weekend
from days
