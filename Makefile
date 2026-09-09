.PHONY: bootstrap backfill run dbt-test analytics lineage lineage-down down logs

bootstrap:
	docker compose up -d --build

backfill:
	docker compose exec airflow-scheduler python -m ingestion.ingest_orders --since 2026-01-01 --until 2026-08-24
	docker compose exec airflow-scheduler python -m ingestion.ingest_fx --since 2026-01-01 --until 2026-08-24

run: backfill
	docker compose exec airflow-scheduler airflow dags test azmart_pipeline 2026-08-24
	docker compose exec airflow-scheduler airflow dags test azmart_pipeline 2026-08-25


dbt-test:
	docker compose exec airflow-scheduler bash -c '$$DBT_BIN test --project-dir /opt/airflow/dbt_project --profiles-dir $$DBT_PROFILES_DIR --target-path $$DBT_TARGET_PATH --log-path $$DBT_LOG_PATH'

analytics:
	@for f in analytics/queries/0[0-5]*.sql; do \
		name=$$(basename "$$f" .sql); \
		echo "=== $$name ==="; \
		docker compose exec -T postgres psql -U azmart -d azmart --csv -f - < "$$f" > "analytics/results/$$name.csv"; \
	done

lineage:
	docker compose --profile lineage up -d
	@echo "Marquez qalxir..."
	@until curl -sf http://127.0.0.1:5050/api/v1/namespaces > /dev/null 2>&1; do sleep 3; done
	docker compose exec airflow-scheduler bash -c '$$DBT_OL_BIN build --project-dir /opt/airflow/dbt_project --profiles-dir $$DBT_PROFILES_DIR --target-path $$DBT_TARGET_PATH --log-path $$DBT_LOG_PATH --indirect-selection cautious --full-refresh'
	@echo "Marquez UI: http://localhost:3000  (namespace: azmart)"

lineage-down:
	docker compose --profile lineage down

down:
	docker compose down

logs:
	docker compose logs -f
