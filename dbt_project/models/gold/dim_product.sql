select
    product_id,
    product_name,
    category,
    case when unit_price >= 0 then unit_price end as list_price,
    case when currency in ('AZN', 'USD', 'EUR', 'TRY') then currency end as list_currency,
    reason_code is not null as has_catalog_issue
from {{ ref('stg_products') }}
where reason_code is distinct from 'duplicate_product'
  and reason_code is distinct from 'missing_product_id'
