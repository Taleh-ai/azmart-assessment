with bounds as (
    select min(snapshot_date) as date1, max(snapshot_date) as date2
    from {{ ref('customers') }}
),

day1 as (
    select customer_id, full_name, country, segment, signup_date
    from {{ ref('customers') }}, bounds
    where snapshot_date = bounds.date1
),

day2 as (
    select customer_id, full_name, country, segment, signup_date
    from {{ ref('customers') }}, bounds
    where snapshot_date = bounds.date2
),

changed as (
    select
        d1.customer_id,
        d1.full_name is distinct from d2.full_name
            or d1.country is distinct from d2.country
            or d1.segment is distinct from d2.segment
            or d1.signup_date is distinct from d2.signup_date
            as is_changed
    from day1 d1
    left join day2 d2 on d2.customer_id = d1.customer_id
),

first_version as (
    select
        d1.customer_id,
        d1.full_name,
        d1.country,
        d1.segment,
        d1.signup_date,
        '2020-01-01'::date as valid_from,
        case when d2.customer_id is null or c.is_changed then bounds.date2 end as valid_to,
        d2.customer_id is not null and not c.is_changed as is_current
    from day1 d1
    cross join bounds
    left join day2 d2 on d2.customer_id = d1.customer_id
    join changed c on c.customer_id = d1.customer_id
),

second_version as (
    select
        d2.customer_id,
        d2.full_name,
        d2.country,
        d2.segment,
        d2.signup_date,
        bounds.date2 as valid_from,
        cast(null as date) as valid_to,
        true as is_current
    from day2 d2
    cross join bounds
    left join day1 d1 on d1.customer_id = d2.customer_id
    left join changed c on c.customer_id = d2.customer_id
    where d1.customer_id is null or c.is_changed
),

all_versions as (
    select * from first_version
    union all
    select * from second_version
)

select
    md5(customer_id || ':' || valid_from) as customer_key,
    customer_id,
    full_name,
    country,
    segment,
    signup_date,
    valid_from,
    valid_to,
    is_current
from all_versions
