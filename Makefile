.PHONY: bootstrap backfill run dbt-test analytics down logs

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
	@for f in analytics/queries/0[1-5]*.sql; do \
		name=$$(basename "$$f" .sql); \
		echo "=== $$name ==="; \
		docker compose exec -T postgres psql -U azmart -d azmart --csv -f - < "$$f" > "analytics/results/$$name.csv"; \
	done

down:
	docker compose down

logs:
	docker compose logs -f
