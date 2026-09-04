FROM apache/airflow:3.3.1
COPY requirements-app.txt /requirements-app.txt
RUN pip install --no-cache-dir -r /requirements-app.txt