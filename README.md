## azmart-assessment
 

### 2 sentyabr
- Repo, `.gitignore`/`.dockerignore`, `uv` ilə mühit (`pyproject.toml` + `uv.lock`)
- `docker-compose.yaml`: mock-api (socat sidecar) + Postgres — `airflow_meta` və `azmart` (bronze/silver/gold/quarantine), healthcheck-lər
- `ingestion/api_client.py`: X-API-Key, timeout, cursor pagination, 429→`Retry-After`, 5xx→exponential backoff, 4xx→dərhal xəta
- API datası profilləndi, 18 DQ problemi say və nümunə ID ilə qeyd olundu

### 3 sentyabr
- `docker-compose.yaml`-a Airflow əlavə olundu: `init` → `apiserver` → `scheduler` / `dag-processor`, asılılıqlar healthcheck üzərindən
- `docker/initdb/` skriptləri: `airflow_meta` bazası, `azmart` içində `bronze` / `silver` / `gold` / `quarantine` sxemləri

### 4 sentyabr
- `docker/Dockerfile.app` və `requirements-app.txt` — dbt və Soda Airflow image-ının içinə əlavə olundu (ayrıca servis kimi yox, `BashOperator` çağırır)
- dbt və Soda üçün mount-lar və env dəyişənləri compose-a əvvəlcədən yazıldı: `DBT_PROFILES_DIR`, `DBT_TARGET_PATH`, `POSTGRES_*`
- Bütün stack sıfırdan qaldırıldı və yoxlandı — 6 servis healthy, Airflow UI açılır, `dbt --version` konteynerdə işləyir

### 5 sentyabr
- Bronze loaderlər: `customers`, `products`, `events` (+ `quarantine.records`, malformed sətirlər üçün)
- Airflow DAG (`dags/azmart_pipeline.py`): `bronze` TaskGroup, 5 paralel ingestion task-ı, `data_interval`-driven, `catchup=True`, `max_active_runs=1`
- Hər bronze sətrinə `_batch_id` (hər run üçün fərqli UUID, audit trace) əlavə olundu — `_source`/`_load_id`/`_ingested_at`-a əlavə olaraq
- **Qərar — eyni batch daxilində dublikat order_id-lər:** bronze bunları **silmir**  Bronze fəlsəfəsi "xam, dəyişdirilməmiş" olduğu üçün dedup burda deyil, silver-də (dbt) deterministik qayda ilə (məs. son `updated_at`) həll olunacaq.