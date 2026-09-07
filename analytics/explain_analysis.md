# EXPLAIN təhlili — Sorğu 1 (Aylıq revenue, category × country)

## Seçilmiş sorğu

`analytics/queries/01_monthly_revenue_by_category_country.sql` — 3 dimension (`dim_date`, `dim_product`, `dim_customer`) ilə join olunan, `is_recognized` filtri olan, `month/category/country` üzrə qruplaşdırılan aggregation sorğusu. Bunu seçdim, çünki digər 4 sorğudan fərqli olaraq bir neçə join-i birlikdə göstərir.

## Real Postgres planı (`EXPLAIN (ANALYZE, BUFFERS)`)

```
 GroupAggregate  (cost=1437.98..1767.40 rows=9412 width=54) (actual time=13.686..15.760 rows=138 loops=1)
   Group Key: ((date_trunc('month'::text, (dd.date_day)::timestamp with time zone))::date), dp.category, dc.country
   Buffers: shared hit=226
   ->  Sort  (cost=1437.98..1461.51 rows=9412 width=29) (actual time=13.612..13.985 rows=9401 loops=1)
         Sort Key: ((date_trunc('month'::text, (dd.date_day)::timestamp with time zone))::date), dp.category, dc.country
         Sort Method: quicksort  Memory: 916kB
         Buffers: shared hit=226
         ->  Hash Join  (cost=52.53..816.77 rows=9412 width=29) (actual time=0.384..9.397 rows=9401 loops=1)
               Hash Cond: (f.customer_key = dc.customer_key)
               Buffers: shared hit=220
               ->  Hash Join  (cost=17.54..581.78 rows=9412 width=53) (actual time=0.143..5.363 rows=9401 loops=1)
                     Hash Cond: (f.order_date_key = dd.date_key)
                     Buffers: shared hit=204
                     ->  Hash Join  (cost=5.33..440.15 rows=9412 width=53) (actual time=0.060..3.776 rows=9401 loops=1)
                           Hash Cond: (f.product_id = dp.product_id)
                           Buffers: shared hit=200
                           ->  Seq Scan on fct_order_lines f  (cost=0.00..304.93 rows=9539 width=50) (actual time=0.008..1.702 rows=9539 loops=1)
                                 Filter: is_recognized
                                 Rows Removed by Filter: 1154
                                 Buffers: shared hit=198
                           ->  Hash  (cost=3.48..3.48 rows=148 width=15) (actual time=0.041..0.042 rows=148 loops=1)
                                 Buckets: 1024  Batches: 1  Memory Usage: 15kB
                                 Buffers: shared hit=2
                                 ->  Seq Scan on dim_product dp  (cost=0.00..3.48 rows=148 width=15) (actual time=0.004..0.016 rows=148 loops=1)
                                       Buffers: shared hit=2
                     ->  Hash  (cost=7.65..7.65 rows=365 width=8) (actual time=0.074..0.074 rows=365 loops=1)
                           Buckets: 1024  Batches: 1  Memory Usage: 23kB
                           Buffers: shared hit=4
                           ->  Seq Scan on dim_date dd  (cost=0.00..7.65 rows=365 width=8) (actual time=0.004..0.032 rows=365 loops=1)
                                 Buffers: shared hit=4
               ->  Hash  (cost=24.44..24.44 rows=844 width=42) (actual time=0.226..0.227 rows=844 loops=1)
                     Buckets: 1024  Batches: 1  Memory Usage: 70kB
                     Buffers: shared hit=16
                     ->  Seq Scan on dim_customer dc  (cost=0.00..24.44 rows=844 width=42) (actual time=0.002..0.088 rows=844 loops=1)
                           Buffers: shared hit=16
 Planning:
   Buffers: shared hit=245
 Planning Time: 1.079 ms
 Execution Time: 15.933 ms
```

**Şərh:**
- `fct_order_lines` oxunur, `is_recognized` filtri tətbiq olunur.
- Dimension cədvəlləri (`dim_product`, `dim_date`, `dim_customer`) Hash cədvəlinə çevrilib, ardıcıl 3 `Hash Join` ilə birləşdirilir.
- Nəticə sort olunur (`quicksort`), sonra qruplaşdırılıb aqreqasiya edilir (`GroupAggregate`).
- Hər yerdə `Seq Scan`, indeks yoxdur — cədvəllər kiçik olduğu üçün düzgün seçimdir, tam skan indeksdən ucuzdur.
- Bütün oxumalar buffer cache-dən gəlir, disk I/O yoxdur.
- Sorğu çox sürətli işləyir.

## Eyni sorğu milyardlarla sətirdə (Trino + Iceberg)

- **Nə partition pruning, nə də file pruning işləyəcək.** Sorğuda spesifik tarix filtri yoxdur, `GROUP BY` bütün tarixçəni əhatə edir — mühərrik "hansı ayı/faylı atlaya bilərəm" sualına cavab tapa bilmir. Nəticə: hər dəfə bütün data yaddaşa alınmalı olacaq.
- **`GROUP BY` data shuffle yaradacaq.** Fact cədvəli (`fct_order_lines`) worker-lar arasında `month/category/country` açarına görə bölünəcək, hər worker öz payını hesablayıb, sonra nəticələr yenidən bir yerə yığılacaq — bu, worker-lər arasında şəbəkə üzərindən data köçürülməsi (shuffle) deməkdir.
- **Kiçik dimension cədvəlləri broadcast join olacaq.** `dim_date`/`dim_product` kiçik qaldığı üçün hər worker-in yaddaşına tam köçürülür, orada lokal join edilir — fact-ın shuffle olunmasına ehtiyac qalmır. `dim_customer` isə production miqyasında (milyonlarla müştəri) artıq broadcast üçün böyük ola bilər — bu halda Trino onu da shuffle join-ə keçirər.
- **Compression və fayl ölçüsünə diqqət edilməsə, small-files problemi yaranar.** DAG `fct_order_lines`-ı hər gün tam yenidən yazır — bu, milyardlarla sətirdə minlərlə kiçik parquet faylı yaradar, hər faylı ayrıca açmaq yavaşladır. Yaxşı idarə olunan cədvəldə (müntəzəm `rewrite_data_files` compaction, sağlam fayl ölçüsü ~512MB-1GB, düzgün compression) faylların sayı az qalır, nəticə tez qayıdır.
- **Materialized aggregation:** bu sorğu tez-tez işlədilirsə, milyardlarla sətri hər dəfə oxumaq əvəzinə `gold.monthly_revenue` kimi gecəlik yenilənən hazır cədvəl saxlamaq lazımdır — o cədvələ qarşı sorğu filtrli olacaq, partition pruning də işə düşəcək.
- **Cluster resursu:** `query.max-memory-per-node` kifayət qədər yüksək olmalıdır, yoxsa `GROUP BY`-ın shuffle mərhələsi yaddaş xətası verə bilər.
