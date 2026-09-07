import logging

import pendulum

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG, TaskGroup

log = logging.getLogger("airflow.task")

SINCE = "{{ data_interval_start.strftime('%Y-%m-%d') }}"
UNTIL = "{{ data_interval_start.add(days=1).strftime('%Y-%m-%d') }}"


def alert_on_failure(context):
    log.error(
        "ALERT: task %s failed in dag %s (run_id=%s)",
        context["task_instance"].task_id,
        context["dag"].dag_id,
        context["run_id"],
    )


with DAG(
    dag_id="azmart_pipeline",
    start_date=pendulum.datetime(2026, 1, 1, tz="UTC"),
    schedule="@daily",
    catchup=True,
    max_active_runs=1,
    tags=["azmart", "bronze"],
    default_args={"on_failure_callback": alert_on_failure},
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

    with TaskGroup(group_id="silver") as silver:
        BashOperator(
            task_id="dbt_run",
            trigger_rule="none_failed",
            bash_command=(
                "$DBT_BIN build --project-dir /opt/airflow/dbt_project "
                "--profiles-dir $DBT_PROFILES_DIR "
                "--target-path $DBT_TARGET_PATH --log-path $DBT_LOG_PATH "
                "--select path:models/staging path:models/silver "
                "--indirect-selection cautious"
            ),
        )

    with TaskGroup(group_id="gold") as gold:
        BashOperator(
            task_id="dbt_run",
            trigger_rule="none_failed",
            bash_command=(
                "$DBT_BIN build --project-dir /opt/airflow/dbt_project "
                "--profiles-dir $DBT_PROFILES_DIR "
                "--target-path $DBT_TARGET_PATH --log-path $DBT_LOG_PATH "
                "--select path:models/gold "
                "assert_fct_order_lines_grain_reconciliation "
                "assert_fct_order_lines_revenue_reconciled"
            ),
        )

    bronze >> silver >> gold
