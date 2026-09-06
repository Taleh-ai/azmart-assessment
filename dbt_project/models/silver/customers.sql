select
    customer_id,
    full_name,
    country,
    segment,
    signup_date,
    updated_at,
    snapshot_date
from {{ ref('stg_customers') }}
where reason_code is null
