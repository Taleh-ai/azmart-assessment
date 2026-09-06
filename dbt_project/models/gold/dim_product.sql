select
    product_id,
    product_name,
    category,
    unit_price as list_price,
    currency as list_currency
from {{ ref('products') }}
