select order_id, line_number, currency, order_date_baku
from {{ ref('fct_order_lines') }}
where gross_amount_azn is null
