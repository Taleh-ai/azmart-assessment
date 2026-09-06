{{ config(schema='quarantine', alias='products') }}

select
    md5(product_id || ':' || reason_code) as quarantine_id,
    'silver_products' as source,
    reason_code,
    to_jsonb(stg_products.*) as payload,
    now() as quarantined_at
from {{ ref('stg_products') }} as stg_products
where reason_code is not null
