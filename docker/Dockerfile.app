FROM apache/airflow:3.3.1
COPY requirements-app.txt /requirements-app.txt
RUN pip install --no-cache-dir -r /requirements-app.txt
RUN mkdir -p /opt/airflow/dbt_state/target /opt/airflow/dbt_state/logs