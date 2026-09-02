# AZMART Assessment — Quickstart və Data Dictionary

Bu fayl paketin texniki istinadıdır. Tapşırığın özü ayrıca sənəddədir
(`AZCON_Data_Muhendisi_Tapsiriq_v2.md`) — əvvəlcə onu oxuyun.

---

## 1. Mock API server

Tələb: Python 3.10+ (heç bir pip paketi lazım deyil).

```bash
python mock_api_server.py              # http://127.0.0.1:8008
python mock_api_server.py --port 9000  # başqa port
```

Sağlamlıq yoxlaması:

```bash
curl http://127.0.0.1:8008/health
# {"status": "ok", "service": "azmart-orders-api", "version": "2.0"}
```

**Auth:** bütün `/api/*` endpoint-ləri header tələb edir: `X-API-Key: azcon-de-2026`

**Bilərəkdən olan davranışlar:**

- Server deterministik şəkildə vaxtaşırı `429` (`Retry-After: 2` header ilə) və `500` qaytarır. Retry məntiqiniz bunları idarə etməlidir.
- FX endpoint-i həftəsonu və bayram günləri üçün `404` qaytarır — bu günlər üçün məzənnə dərc olunmur.
- Cursor opaque token-dır: parse etməyin. Cursor sorğu parametrlərinə bağlıdır — pagination ortasında `updated_since`/`updated_until`/`page_size` dəyişsəniz `400` alacaqsınız.

---

## 2. Endpoint-lər

### 2.1 `GET /api/v1/orders`

| Parametr | Tələb | Təsvir |
|---|---|---|
| `updated_since` | bəli | ISO-8601 UTC, **daxil** (məs. `2026-01-01T00:00:00Z`) |
| `updated_until` | bəli | ISO-8601 UTC, **xaric** — interval `[since, until)` |
| `page_size` | xeyr | default 100, max 200 |
| `cursor` | xeyr | əvvəlki cavabın `next_cursor` dəyəri |

Filter sifarişin `updated_at` sahəsinə tətbiq olunur. API hər sifarişin **cari (son) vəziyyətini** qaytarır.

Nümunə:

```bash
curl -H "X-API-Key: azcon-de-2026" \
  "http://127.0.0.1:8008/api/v1/orders?updated_since=2026-01-01T00:00:00Z&updated_until=2026-08-25T00:00:00Z&page_size=100"
```

Cavab:

```json
{
  "data": [
    {
      "order_id": "O0000123",
      "customer_id": "C0456",
      "channel": "web",
      "currency": "AZN",
      "order_ts": "2026-06-14T09:21:33Z",
      "status": "DELIVERED",
      "updated_at": "2026-06-19T11:02:10Z",
      "items": [
        {"product_id": "P0040", "quantity": 2, "unit_price": 129.99}
      ]
    }
  ],
  "next_cursor": "eyJwIjoi...",
  "page_size": 100
}
```

`next_cursor: null` — son səhifə deməkdir.

### 2.2 `GET /api/v1/fx/rates?date=YYYY-MM-DD`

```bash
curl -H "X-API-Key: azcon-de-2026" "http://127.0.0.1:8008/api/v1/fx/rates?date=2026-08-24"
```

```json
{
  "date": "2026-08-24",
  "quote_currency": "AZN",
  "note": "rate_azn = 1 vahid valyutanın AZN qarşılığı",
  "rates": [
    {"currency": "USD", "rate_azn": 1.7003},
    {"currency": "EUR", "rate_azn": 1.8921},
    {"currency": "TRY", "rate_azn": 0.0391}
  ]
}
```

Məzənnə dərc olunmayan gün → `404`. AZN üçün ayrıca sətir verilmir (rate = 1.0).

---

## 3. Data dictionary

### 3.1 Orders (API)

| Sahə | Tip | Qeydlər |
|---|---|---|
| `order_id` | string | `O` + 7 rəqəm |
| `customer_id` | string | `customers_snapshot_*.csv`-ə istinad; **keyfiyyətinə zəmanət verilmir** |
| `channel` | string | `web` / `mobile` / `pos` |
| `currency` | string | Sifarişin valyutası. **Təmizliyinə zəmanət verilmir** |
| `order_ts` | qarışıq | Sifarişin yaranma vaxtı. **4 fərqli formatda gələ bilər:** ISO `...Z` (UTC); ISO `...+04:00`; `DD.MM.YYYY HH:MM:SS` (naive → Bakı lokalı); epoch integer (millisaniyə, UTC) |
| `status` | string | `CREATED / CONFIRMED / PACKED / SHIPPED / DELIVERED / CANCELLED / REFUNDED` — API-nin bildiyi **cari** status |
| `updated_at` | string | ISO UTC. Sifarişin son dəyişmə vaxtı — incremental filter bu sahə ilə işləyir |
| `items[].product_id` | string | `products.csv`-ə istinad; keyfiyyətinə zəmanət verilmir |
| `items[].quantity` | int | Zəmanət verilmir (sıfır/mənfi ola bilər) |
| `items[].unit_price` | qarışıq | **Sifariş anındakı satış qiyməti, sifarişin valyutasında** (kataloq qiyməti ilə qarışdırmayın). Number və ya string (`"1,873.45"`) gələ bilər; null ola bilər |

Sifariş məbləği = Σ `quantity × unit_price` (sifariş valyutasında).

### 3.2 CDC events (`dataset/events/*.ndjson`)

Hər sətir bir JSON event (Kafka topic-inin günlük export-u; fayl adındakı tarix export günüdür):

| Sahə | Təsvir |
|---|---|
| `event_id` | Unikal olmalıdır — amma **fayllarda təkrarlar var** |
| `op` | `c` = order yaradıldı, `u` = status dəyişdi, `d` = tombstone (privacy erasure tələbi) |
| `order_id` | Sifariş |
| `old_status` / `new_status` | Keçid; `c`-də `old_status = null`; `d`-də `new_status = null` |
| `event_ts` | Hadisənin **baş vermə** vaxtı (ISO UTC) — məntiqi sıralama bununla aparılmalıdır |
| `ingested_at` | Hadisənin stream-ə **düşmə** vaxtı (ISO UTC) — fayl sırası təxminən buna uyğundur, `event_ts`-ə YOX |
| `source` | Həmişə `order-service` |

Xəbərdarlıqlar: fayllarda sırası pozulmuş event-lər, təkrar sətirlər, gec gəlmiş event-lər, **korlanmış (yarımçıq) JSON sətri** və mövcud olmayan sifarişə istinad var. Hamısı bilərəkdəndir.

### 3.3 `products.csv`

`product_id, product_name, category, unit_price, currency, updated_at`

- `unit_price` = **kataloq qiyməti**, `currency` valyutasında. Analitik gəlir hesabı üçün istifadə olunmur (satış qiyməti order item-dədir); dimension atributu kimi saxlanıla bilər.
- Faylda dublikat sətir, boş category, mənfi qiymət, string qiymət və legacy valyuta kodu var — bilərəkdən.

### 3.4 `customers_snapshot_2026-08-24.csv` / `customers_snapshot_2026-08-25.csv`

`customer_id, full_name, country, segment, signup_date, updated_at`

- Hər fayl həmin günün **tam snapshot**-udur (MDM sistemindən günlük full export). İki günü müqayisə edərək dəyişiklikləri (və SCD2 tarixçəsini) çıxarmaq sizin işinizdir.
- `country` sərbəst mətn sahəsidir — variantlar/zibil dəyərlər var.
- `updated_at` mənbə sisteminin doldurduğu sahədir — **düzgünlüyünə zəmanət verilmir**.
- Snapshot-lar arasında yeni müştərilər, dəyişmiş sahələr və **yox olmuş müştəri** var.

### 3.5 Fayl texniki formatı

Bütün fayllar **UTF-8** (BOM-suz). CSV-lər standart RFC 4180, vergül ayırıcılı, header sətri ilə.

---

## 4. Tövsiyə olunan ilk addımlar

1. Server-i qaldırın, `/health` yoxlayın.
2. Kiçik `page_size` ilə bir-iki səhifə çəkib cavab strukturuna baxın; `429` alana qədər davam edin ki, retry davranışını erkən qurasınız.
3. Dataset fayllarını profilləyin (sayları, null-ları, format variantlarını) — DQ hesabatınızın skeleti buradan çıxacaq.
4. Yalnız bundan sonra pipeline yazmağa başlayın.
