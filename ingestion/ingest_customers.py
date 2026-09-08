import argparse
import csv
import logging
import os
import sys
import uuid

from ingestion.db import replace_load, run_script

SOURCE = "customers_csv"
DDL_PATH = os.path.join(os.path.dirname(__file__), "ddl.sql")
DATASET_DIR = os.environ.get("DATASET_DIR", "candidate_package/dataset")
DELETE_SQL = "delete from bronze.customers where _load_id = %s"
INSERT_SQL = """
    insert into bronze.customers
    (customer_id, full_name, country, segment, signup_date, updated_at, snapshot_date, _source, _batch_id, _load_id)
    values (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
"""

log = logging.getLogger("ingestion")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", required=True)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    file_path = os.path.join(DATASET_DIR, args.file)
    if not os.path.exists(file_path):
        log.info("file not found, skipping: %s", file_path)
        sys.exit(99)

    run_script(DDL_PATH)

    batch_id = uuid.uuid4().hex
    snapshot_date = args.file.rsplit("_", 1)[1].removesuffix(".csv")
    load_id = "customers_%s" % snapshot_date

    with open(file_path, newline="", encoding="utf-8") as f:
        rows = [
            (row["customer_id"], row["full_name"], row["country"], row["segment"],
             row["signup_date"], row["updated_at"], snapshot_date, SOURCE, batch_id, load_id)
            for row in csv.DictReader(f)
        ]

    replace_load(DELETE_SQL, INSERT_SQL, (load_id,), rows)

    log.info("bronze.customers: %d rows for load_id %s", len(rows), load_id)


if __name__ == "__main__":
    main()
