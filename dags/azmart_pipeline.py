import pendulum

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG, TaskGroup

SINCE = "{{ data_interval_start.strftime('%Y-%m-%d') }}"
UNTIL = "{{ data_interval_start.add(days=1).strftime('%Y-%m-%d') }}"

with DAG(
    dag_id="azmart_pipeline",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule="@daily",
    catchup=True,
    max_active_runs=1,
    tags=["azmart", "bronze"],
) as dag:
    with TaskGroup(group_id="bronze") as bronze:
        BashOperator(
            task_id="ingest_orders",
            bash_command=f"python -m ingestion.ingest_orders --since {SINCE} --until {UNTIL}",
        )

        BashOperator(
            task_id="ingest_fx",
            bash_command=f"python -m ingestion.ingest_fx --since {SINCE} --until {UNTIL}",
        )

        BashOperator(
            task_id="ingest_customers",
            bash_command="python -m ingestion.ingest_customers --file customers_snapshot_{{ ds }}.csv",
        )

        BashOperator(
            task_id="ingest_products",
            bash_command="python -m ingestion.ingest_products",
        )

        BashOperator(
            task_id="ingest_events",
            bash_command="python -m ingestion.ingest_events --file events/order_events_{{ ds }}.ndjson",
        )
