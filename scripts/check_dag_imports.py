import sys

from airflow.models import DagBag

bag = DagBag(dag_folder="/opt/airflow/dags")

for path, error in bag.import_errors.items():
    print(path, error)

if bag.import_errors:
    sys.exit(1)

print("%d DAGs OK" % len(bag.dags))
