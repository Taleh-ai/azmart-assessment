.PHONY: bootstrap run dbt-test catchup-demo down logs

bootstrap:
	docker compose up -d --build

run:
	docker compose exec airflow-scheduler airflow dags test azmart_pipeline 2026-08-24
	docker compose exec airflow-scheduler airflow dags test azmart_pipeline 2026-08-25
	docker compose exec airflow-scheduler airflow dags test azmart_pipeline 2026-07-15

dbt-test:
	docker compose exec airflow-scheduler bash -c '$$DBT_BIN test --project-dir /opt/airflow/dbt_project --profiles-dir $$DBT_PROFILES_DIR --target-path $$DBT_TARGET_PATH --log-path $$DBT_LOG_PATH'

catchup-demo:
	@d=2026-06-01; \
	while [ "$$d" != "2026-08-27" ]; do \
		echo "=== $$d ==="; \
		docker compose exec airflow-scheduler airflow dags test azmart_pipeline "$$d"; \
		d=$$(python3 -c "import datetime,sys; print(datetime.date.fromisoformat(sys.argv[1]) + datetime.timedelta(days=1))" "$$d"); \
	done

down:
	docker compose down

logs:
	docker compose logs -f
