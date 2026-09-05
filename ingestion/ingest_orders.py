import argparse
import logging
import os
import uuid

from psycopg2.extras import Json

from ingestion.api_client import fetch_orders
from ingestion.db import replace_load, run_script

SOURCE = "orders_api"
DDL_PATH = os.path.join(os.path.dirname(__file__), "ddl.sql")
DELETE_SQL = "delete from bronze.orders where _load_id = %s"
INSERT_SQL = "insert into bronze.orders (payload, _source, _batch_id, _load_id) values (%s, %s, %s, %s)"

log = logging.getLogger("ingestion")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--since", required=True)
    parser.add_argument("--until", required=True)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    run_script(DDL_PATH)

    batch_id = uuid.uuid4().hex
    load_id = "orders_%s_%s" % (args.since, args.until)
    rows = [(Json(order), SOURCE, batch_id, load_id) for order in fetch_orders(args.since, args.until)]
    replace_load(DELETE_SQL, INSERT_SQL, load_id, rows)

    log.info("bronze.orders: %d rows for load_id %s", len(rows), load_id)


if __name__ == "__main__":
    main()
