select order_id, line_number, count(*)
from {{ ref('order_lines') }}
group by order_id, line_number
having count(*) > 1
