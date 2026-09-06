select
    product_id,
    product_name,
    category,
    unit_price,
    currency,
    updated_at
from {{ ref('stg_products') }}
where reason_code is null
