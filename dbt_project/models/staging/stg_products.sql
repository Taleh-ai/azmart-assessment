with products as (
    select
        product_id,
        product_name,
        coalesce(nullif(trim(category), ''), 'Uncategorized') as category,
        case
            when unit_price like '%,%'
                then nullif(replace(unit_price, ',', ''), '')::numeric
            else nullif(unit_price, '')::numeric
        end as unit_price,
        upper(trim(currency)) as currency,
        updated_at::timestamptz as updated_at,
        row_number() over (
            partition by product_id
            order by updated_at::timestamptz desc
        ) as rn
    from {{ source('bronze', 'products') }}
)

select
    product_id,
    product_name,
    category,
    unit_price,
    currency,
    updated_at,
    case
        when product_id is null or product_id = '' then 'missing_product_id'
        when rn > 1 then 'duplicate_product'
        when currency not in ('AZN', 'USD', 'EUR', 'TRY') then 'unsupported_currency'
        when unit_price is null then 'missing_unit_price'
        when unit_price < 0 then 'negative_unit_price'
    end as reason_code
from products
