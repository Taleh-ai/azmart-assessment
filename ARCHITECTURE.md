# ARCHITECTURE

## 1. Local → production mapping

| Local (bu repo) | Production |
|---|---|
| Postgres `bronze`/`silver`/`gold` sxemləri | Apache Iceberg cədvəlləri, MinIO/S3 üzərində, Nessie catalog |
| Mock REST API (orders, fx) | Real order-service API, real FX provider |
| `order_events_*.ndjson` fayllar | Kafka topic, Debezium CDC connector order-service-in öz DB-sindən |
| `customers_snapshot_*.csv` (MDM export) | MDM-in öz export pipeline-ı, S3-ə düşür |
| dbt-postgres | dbt-trino (və ya dbt-spark), Trino/Spark Iceberg üzərində sorğulayır |
| Airflow `LocalExecutor` | Airflow `KubernetesExecutor`/`CeleryExecutor`, distributed worker-lər |
| `ingestion/*.py` (requests, tək thread) | Paralel/chunked fetch, ya da Kafka Connect source (REST polling əvəzinə) |

**CDC consumer dizaynı (Kafka + Debezium):**
- **Offset idarəsi:** Kafka consumer group öz commit olunmuş offset-ini saxlayır (Debezium/Kafka Connect broker-in özündə) — restart olsa, qaldığı yerdən davam edir.
- **Dedup:** bizim indiki `stg_order_events`-in `distinct` məntiqi birbaşa köçürülür — Kafka **at-least-once** çatdırır (eyni mesaj 2 dəfə gələ bilər), `event_id` üzrə dedup silver-də olur, dəyişmir.
- **Exactly-once iddiaları:** Kafka+Iceberg tandeminda "true exactly-once" nadir tələb olunur — bunun əvəzinə **idempotent consumer** pattern-i kifayətdir: at-least-once + `event_id`-ə görə dedup = **effektiv exactly-once** silver səviyyəsində. Iceberg-in öz atomic commit-i (bir batch ya tam yazılır, ya heç) bunu asanlaşdırır.

## 2. Trade-off-lar

- **Batch vs streaming:** hazırda tam batch (gündəlik DAG). Real-time streaming olsaydı, axını real vaxtda görmüş olardıq — gecikmələr çox az yaşanardı, hər hansı producer geri qalsa belə, offset özündə saxlanıldığı üçün harda qalıbsa ordan davam edərdi, geri qalmış olmazdı. Amma tam sıfıra enməzdi, çünki API-nin öz `status`-u da ayrı bir sistemin (order-service) periodik snapshot-udur — bizim consumer nə qədər sürətli olsa da, bu bizdən asılı deyil. Gündəlik hesabat SLA-sı üçün batch kifayətdir; yalnız CDC/status tərəfi üçün streaming ağlabatan növbəti addım olardı.
- **ELT vs ETL:** ELT seçilib — xam data bronze-da saxlanır, transformasiya warehouse daxilində (dbt) aparılır. Transform edib sonra yükləsəydik (ETL), böyük ehtimalla yenə quarantinə atmaq mümkün olardı, çünki transform prosesində uyğun gəlməyən sətirləri başqa cədvələ load edə bilərik. Fərq odur ki, o zaman xam payload heç yerdə qalmazdı — transform məntiqində bug tapsaq API-yə yenidən müraciət etməli olardıq, ELT-də isə elə bronze-dan yenidən emal edə bilirik.
- **Table format (Iceberg):** bu layihə üçün time travel və schema evolution ən vacibidir — yeni gələn column-lara qarşı dayanıqlı oluruq, yeni column gələndə avtomatik əlavə olunur, məlumat itmədən yeniləri götürürük, həm də SCD2-ni itirmirik, yenidən loada ehtiyac olmur.
- **Partition strategiyası:** `fct_order_lines`/`fct_order_status_events` — `month(order_date)`/`month(event_ts)` üzrə, indiki miqyasda analitika sorğularımıza uyğundur. Ay partitiondan günə keçərdim, çünki həcm artanda (Hissə 5-dəki ssenari) aylıq data çox yüklü olacaqdı, proseslər yavaşlayacaqdı.

## 3. Schema evolution siyasəti

- **Yeni sahə (jsonb mənbələr):** xam json-u saxlayaraq yeni datanı tam load edib məlumat itkisindən yayınmış oluruq. Silverdəki kimi parse edib saxlaya bilərdik (gələcək iş yükünü azaltmaq üçün), amma onda dinamik olmazdıq — yeni column gələndə məntiqi dəyişib, o column-un datalarını görmək üçün yenidən load və backfill etməli olardıq. Bronze xam qaldığı üçün sadəcə silverə əlavə edib silveri backfill edirik, mənbəyə (API-yə) yenidən müraciət etmədən.
- **Silinən sahə (jsonb):** sahədən asılıdır. Əgər silinən sahə artıq `reason_code` məntiqimizdə yoxlanan sahələrdən biridirsə (məs. `customer_id`, `unit_price`) — `null` olması "problem var" demək olacaq və avtomatik quarantinə düşəcək, gələcəkdə data bərpa olunsa təmiz bronza qayıdacaq. Amma yoxlanmayan, testsiz bir sahədirsə — sakitcə `null` olar, heç nə bilməyəcəyik. Yalnız o sütuna aid ayrıca `not_null` test yazılıbsa, bütün `dbt build` fail olar (bizi xəbərdar edər) — bu, sətri quarantinə atmaq deyil, bütün run-u dayandırıb diqqət çəkməkdir.
- **Struktur mənbələr (CSV — customers/products):** CSV bir dəfəlik load olunur, artıq parse edilmiş formadadır — yeni column kodda adla bildirilməlidir, bildirilməsə sadəcə atılır. İlk yükləmədə column yoxdursa, sonradan əlavə olunanda da bundan xəbərimiz olmayacaq, kodu dəyişməyincə.

## 4. Governance və PII

- **Access control:** bronze data engineering komandası üçündür — xam olması, həm də içərisində gold-a heç keçməyən sensitiv sahələrin ola bilməsi riski onu digər qatlardan ayırır. PII hər ikisində (bronze və gold) var, amma bronze-un PII "səthi" həmişə daha genişdir — mənbədən nə gəlibsə hamısı orda, süzülməmiş; gold isə yalnız bizim seçdiyimiz sahələri saxlayır. Silver/gold-a broader analyst girişi maskalanmış view-lar üzərindən verilir.
- **Masking:** data engineering tərəfindən idarə olunur, view səviyyəsində — heç bir komanda birbaşa əsas cədvələ access almır, hər komandaya ehtiyacına görə (maskalanmış/maskalanmamış) fərqli view verilir, əsas cədvəlin özü toxunulmaz qalır.
- **Audit:** bronze-da hər sətirdə `_source`/`_batch_id`/`_ingested_at` var — bu, hansı prosesdən, nə vaxt gəldiyini bilmək üçündür. Problem tapılanda bütün datanı deyil, yalnız problemli source/zaman dilimini yenidən ingest etmək mümkün olur, həm də data lineage kök səbəbin tapılmasını asanlaşdırır.
- **Privacy erasure (tombstone) Iceberg-də:** `DELETE FROM bronze.customers WHERE customer_id = X` sətri fiziki dərhal silmir — Iceberg yeni snapshot yaradır ("bu sətir artıq yoxdur" qeydi ilə), amma delete-dən əvvəlki köhnə snapshot hələ də qalır. Elə time travel (`AS OF <köhnə snapshot>`) bunun üstündə qurulub — köhnə snapshot-a sorğu getsə, silinmiş müştərinin PII-si yenə görünür. Yəni GDPR-tipli "məni sil" tələbi üçün sadəcə `DELETE` kifayət etmir, 3 addım lazımdır: (1) `DELETE` — cari state-dən çıxarır, (2) `expire_snapshots` — köhnə snapshot-ları bitirir, artıq onlara time-travel mümkün olmur, (3) yalnız bundan sonra heç bir snapshot istinad etməyən fiziki fayllar təmizlənir.

## 5. Scale ssenarisi (5M sifariş/gün, 50M event/gün, ~2TB/ay)

- **Storage layout:** month-partition artıq işləməz (150M+ sətir/partition) — **gündəlik** partition-a keçid məcburidir.
- **Compaction:** mikro-batch-lərdən yaranan kiçik faylların qarşısını almaq üçün **gündəlik** `rewrite_data_files` scheduled job məcburidir.
- **Ingestion pattern:** hazırkı tək-thread `requests` client bu həcmdə işləməz — paralel/chunked fetch, ya da REST polling əvəzinə Kafka Connect source lazımdır.
- **SLA:** hazırkı bütün dbt modelləri `materialized='table'` (full refresh) — bu həcmdə hər run bütün tarixçəni yenidən hesablayardı, mümkün deyil. **Incremental** modellərə (`is_incremental()`, unique key üzrə merge) keçid məcburidir.

## 6. Incident ssenarisi — gold-un son 3 günü səhv deploy nəticəsində korlanıb

**Addımlar (production, Iceberg):**
1. DAG-ı dərhal pause et (korlanmanın davam etməsinin qarşısını al).
2. Iceberg **time travel** ilə səhv deploy-dan əvvəlki son sağlam snapshot-u tap (`FOR VERSION AS OF <snapshot_id>`).
3. `CALL system.rollback_to_snapshot(...)` — cədvəli o snapshot-a qaytar. Bu, metadata-level əməliyyatdır, **saniyələr** çəkir, heç bir yenidən hesablama lazım deyil.
4. Əsl bug-ı düzəlt, düzəlişi deploy et.
5. Düzəldilmiş kodla yalnız korlanmış 3 günü backfill et (Airflow-da konkret tarix aralığı üçün rerun).

**Bizim lokal həllimizdə fərq:** Postgres-də snapshot/rollback yoxdur. Bərpa iki yolla mümkündür: (a) səhv deploy-dan əvvəlki `pg_dump` backup-dan restore, əgər varsa; (b) **bronze-dan tam yenidən qurmaq** — çünki bronze immutable/xam saxlanır, silver/gold istənilən vaxt eyni bronze data-dan yenidən qurula bilər (bu, bizim "bronze xam qalır" dizaynının gizli gücüdür). Fərq: Iceberg-də rollback **saniyələr**, bizdə **tam recompute** (data həcminə görə dəqiqələr-saatlar) — amma hər ikisi düzgün nəticəyə gətirir, çünki bronze toxunulmayıb.

## 7. Daha çox vaxtım olsaydı

- **CDC simulasiyası (Bonus B1):** Faker ilə sintetik data generasiya edib birbaşa Postgres-ə push edərdim, üstünə Debezium qoşub Kafka-ya yönləndirərdim — beləliklə CDC-ni nəzəri izah yox, əsl stream kimi qurardım.
- **Iceberg branch/WAP pattern:** catalog qaldırıb Iceberg tətbiq edərdim — silver/gold-a birbaşa yazmaq əvəzinə yeni branch açıb, testləri o branch üzərində işlədib, yalnız keçəndə əsas cədvələ tətbiq edərdim (write-audit-publish) — indiki "əvvəl yaz, sonra test elə" yanaşmasından daha safe.
- `dim_product`-a da SCD2 (çoxlu snapshot simulyasiya edib eyni `day1`/`day2` naxışı tətbiq edilərdi)
- dbt modellərini `incremental`-a keçirmək (hazırda hamısı full-refresh table, Hissə 5-dəki miqyasda davam etməz)
- OpenMetadata/OpenLineage ilə lineage və catalog (Bonus B4)
- Hər sütuna description (hazırda yalnız açar sütunlarda var)
- **Airflow-u ayrıca image kimi qurmaq:** hazırda DAG dəyişəndə də CI/CD tam image-i (dbt+soda+asılılıqlar) yenidən build edir. Airflow-u öz image-inə çıxarıb, DAG fayllarını (git-sync və ya bind-mount ilə) ayrıca push etsəydim, adi DAG dəyişikliyi üçün heç bir rebuild lazım olmazdı — deploy daha sürətli olardı.
- **K3s üzərində qaldırmaq:** daha böyük həcmli sintetik data ilə (Hissə 5-dəki miqyas ssenarisi) real şəraitdə test etmək üçün bütün stack-i yüngül Kubernetes (k3s) üzərinə köçürərdim.
