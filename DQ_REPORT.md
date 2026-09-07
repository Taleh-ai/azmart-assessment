# DQ_REPORT

## Tapılan problemlər

### Orders (`bronze.orders` → `silver.order_lines`, `quarantine.order_lines`)

| Problem | Say | Nümunə ID | Necə idarə etdim |
|---|---|---|---|
| `order_ts` 4 fərqli format (ISO Z, ISO offset, epoch ms, `DD.MM.YYYY`) | 4164/518/104/416 | — | `stg_order_lines`-da tək `timestamptz`-ə parse edilir |
| Currency variantları (`azn`, `' USD '`, `AZM`) | case+whitespace çox, `AZM` 1 | O0003666 (AZM) | case/whitespace normallaşdırılır; `AZM` (köhnə manat) real konversiya nisbəti bilinmədiyi üçün `unsupported_currency` — quarantine |
| `unit_price` comma-string (`"2,238.04"`) | 5 | O0004888 | vergül silinib rəqəmə çevrilir |
| `unit_price` mənfi | 1 | O0002401 | `negative_unit_price` — quarantine |
| `unit_price` yoxdur (null) | 1 | O0004100 | `missing_unit_price` — quarantine |
| `quantity` 0 və ya mənfi | 2 | O0003003, O0003113 | `invalid_quantity` — quarantine |
| `customer_id` boş string | 2 | O0000777 | `missing_customer_id` — quarantine (not_null testi bunu tutmur, boş string null deyil) |
| Referential integrity — mövcud olmayan `customer_id`/`product_id` | 3+1 | C9999→O0001500, P9999→O0002718 | `unknown_customer`/`unknown_product` — quarantine |
| `order_ts` mənasız (2019) | 2 | O0004242 | `implausible_order_ts` (<2020-01-01) — quarantine |
| Dublikat `order_id` (eyni batch) | 2 | O0001017 (tam eyni), O0002222 (2 fərqli versiya) | son `updated_at` qalır, digəri `duplicate_order` — quarantine |

**Cəmi:** 10708 xam sətir → 10693 keçərli, **15 quarantine** (`quarantine.order_lines`).

### Customers (`bronze.customers` → `silver.customers`)

| Problem | Say | Nümunə ID | Necə idarə etdim |
|---|---|---|---|
| Ölkə adı variantları (12 xam dəyər) | — | `AZE`/`azerbaijan`→Azerbaijan, `TURKEY`/`Türkiye`→Turkiye, `N/A`→null | `stg_customers`-da normallaşdırılıb |
| Dublikat `(customer_id, snapshot_date)` | 1 | C0104 (24 avqust, 2 fərqli segment) | son `updated_at` qalır — `duplicate_customer_snapshot` quarantine |
| `updated_at` dəyişməyib, amma sahə dəyişib | 1 | C0450 (segment: SME→Corporate) | SCD2 sahə-sahə müqayisə edir, `updated_at`-ə etibar etmir |
| Snapshot-dan yox olan müştəri | 1 | C0666 | `dim_customer`-də `is_current=false` ilə saxlanılır |

**Cəmi:** 1615 xam sətir (801+814) → 1614 keçərli, **1 quarantine**.

### Products (`bronze.products` → `silver.products`)

| Problem | Say | Nümunə ID | Necə idarə etdim |
|---|---|---|---|
| `unit_price` comma-string | 1 | P0103 | rəqəmə çevrilir |
| Dublikat `product_id` | 1 | P0042 | son `updated_at` qalır — quarantine |
| `unit_price` mənfi | 1 | P0058 | quarantine |
| Currency dəstəklənmir | 1 | P0121 (AZM) | quarantine |
| `category` boş | 1 | P0077 | quarantine yox — `'Uncategorized'` etiketlənir (minor sahə, referential/join açarı deyil) |

**Cəmi:** 151 xam sətir → 148 keçərli, **3 quarantine**.

### Events / CDC (`bronze.events` → `silver.order_status_history`)

| Problem | Say | Nümunə ID | Necə idarə etdim |
|---|---|---|---|
| Malformed JSON (kəsik sətir) | 1 | `order_events_2026-08-24.ndjson` sətir 4023, `O0004214`-ə aid | bronze səviyyəsində `quarantine.records`-a düşür, pipeline çökmür |
| Dublikat `event_id` (tam eyni məzmun) | 20 (14+6) | E0018159 | `distinct` ilə silinir |
| Naməlum sifarişə aid event | 1 | O0009999 | `unknown_order` — quarantine |
| Tombstone (`op:"d"`, privacy erasure) | 1 | O0002050 | **Silinmir** — event tarixçəsində qalır, `final_status` hesablamasında `event_status=null` olduğu üçün əvvəlki bilinən status (`api_status`) istifadə olunur |

## Status reconciliation (event-lər vs API snapshot)

`silver.order_status_reconciliation` — 5200 sifarişdən **27-də** fərq tapıldı, 3 fərqli səbəb:

| Səbəb | Say | İzah |
|---|---|---|
| Event-lər API-dən "irəlidədir" | 25 | API-nin `status` sahəsi periodik snapshot-dur, event stream real-vaxtdır — API hələ ən son dəyişikliyi görməmiş ola bilər (məs. `SHIPPED`→`DELIVERED`) |
| Tombstone erasure | 1 | O0002050 — event tərəfi `null`, API köhnə statusu göstərir |
| Bronze-da quarantine olunmuş event | 1 | O0004214 — `DELIVERED` event-i bozuq JSON olduğu üçün itib, event tərəfi bir addım geridə qalıb |

**Qərar (kanonik qayda 4):** 25/27 halda event-lər daha etibarlıdır — `final_status` hesablamasında **event-status prioritetlidir**, yalnız event olmayanda (`no_events_for_order`, 219 sifariş — event faylları cəmi 2 günü əhatə etdiyi üçün gözlənilir) API statusuna keçilir.

## Pipeline-generated reconciliation

`analytics/queries/00_reconciliation_summary.sql` — bu sorğu hər dəfə eyni rəqəmləri verir (idempotent pipeline, deterministik dedup/quarantine):

| Mərhələ | Sətir sayı | Gross AZN | Recognized AZN |
|---|---|---|---|
| `bronze.orders` | 5202 | — | — |
| `silver.order_lines` (keçərli) | 10693 | — | — |
| `quarantine.order_lines` | 15 | — | — |
| `gold.fct_order_lines` | 10693 | 5,391,188.48 | 4,831,649.83 |

Fərq (gross − recognized = 559,538.65 AZN) `is_recognized=false` (CANCELLED/REFUNDED, 1154 sətir) sətirlərin gross məbləğidir — silinməyib, flag ilə ayrılıb (kanonik qayda 3).
