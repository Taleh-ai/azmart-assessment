## azmart-assessment
 

### 2 sentyabr
- Repo, `.gitignore`/`.dockerignore`, `uv` ilə mühit (`pyproject.toml` + `uv.lock`)
- `docker-compose.yaml`: mock-api (socat sidecar) + Postgres — `airflow_meta` və `azmart` (bronze/silver/gold/quarantine), healthcheck-lər
- `ingestion/api_client.py`: X-API-Key, timeout, cursor pagination, 429→`Retry-After`, 5xx→exponential backoff, 4xx→dərhal xəta
- API datası profilləndi, 18 DQ problemi say və nümunə ID ilə qeyd olundu

### 3 sentyabr
- `docker-compose.yaml`: airflow elave edildi , init dbler hazirlandi sxema ve bazalar ucun 
- Airflow ucun baza yaradildi , Medallion ucun sxemalar yaradildi 
- 
