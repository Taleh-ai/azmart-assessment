import argparse
import csv
import logging
import os
import uuid

from ingestion.db import replace_load, run_script

SOURCE = "products_csv"
DDL_PATH = os.path.join(os.path.dirname(__file__), "ddl.sql")
DATASET_DIR = os.environ.get("DATASET_DIR", "candidate_package/dataset")
LOAD_ID = "products"
DELETE_SQL = "delete from bronze.products where _load_id = %s"
INSERT_SQL = """
    insert into bronze.products
    (product_id, product_name, category, unit_price, currency, updated_at, _source, _batch_id, _load_id)
    values (%s, %s, %s, %s, %s, %s, %s, %s, %s)
"""

log = logging.getLogger("ingestion")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--file", default="products.csv")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    run_script(DDL_PATH)

    batch_id = uuid.uuid4().hex

    with open(os.path.join(DATASET_DIR, args.file), newline="", encoding="utf-8") as f:
        rows = [
            (row["product_id"], row["product_name"], row["category"], row["unit_price"],
             row["currency"], row["updated_at"], SOURCE, batch_id, LOAD_ID)
            for row in csv.DictReader(f)
        ]

    replace_load(DELETE_SQL, INSERT_SQL, LOAD_ID, rows)

    log.info("bronze.products: %d rows for load_id %s", len(rows), LOAD_ID)


if __name__ == "__main__":
    main()
