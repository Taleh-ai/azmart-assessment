with customers as (
    select
        customer_id,
        full_name,
        case trim(country)
            when 'azerbaijan' then 'Azerbaijan'
            when 'AZE' then 'Azerbaijan'
            when 'TURKEY' then 'Turkiye'
            when 'Türkiye' then 'Turkiye'
            when 'N/A' then null
            else trim(country)
        end as country,
        segment,
        signup_date::date as signup_date,
        updated_at::timestamptz as updated_at,
        snapshot_date::date as snapshot_date,
        row_number() over (
            partition by customer_id, snapshot_date
            order by updated_at::timestamptz desc
        ) as rn
    from {{ source('bronze', 'customers') }}
)

select
    customer_id,
    full_name,
    country,
    segment,
    signup_date,
    updated_at,
    snapshot_date,
    case
        when customer_id is null or customer_id = '' then 'missing_customer_id'
        when rn > 1 then 'duplicate_customer_snapshot'
    end as reason_code
from customers
