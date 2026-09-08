import argparse
import datetime
import logging
import os
import uuid

import requests
from psycopg2.extras import Json

from ingestion.api_client import fetch_fx_rates
from ingestion.db import replace_load, run_script

SOURCE = "fx_api"
DDL_PATH = os.path.join(os.path.dirname(__file__), "ddl.sql")
DELETE_SQL = "delete from bronze.fx_rates where rate_date >= %s and rate_date < %s"
INSERT_SQL = "insert into bronze.fx_rates (rate_date, payload, _source, _batch_id, _load_id) values (%s, %s, %s, %s, %s)"

log = logging.getLogger("ingestion")


def date_range(since, until):
    current = datetime.date.fromisoformat(since)
    end = datetime.date.fromisoformat(until)
    while current < end:
        yield current.isoformat()
        current += datetime.timedelta(days=1)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--since", required=True)
    parser.add_argument("--until", required=True)
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    run_script(DDL_PATH)

    batch_id = uuid.uuid4().hex
    load_id = "fx_%s_%s" % (args.since, args.until)
    rows = []
    missing = 0

    for date in date_range(args.since, args.until):
        try:
            payload = fetch_fx_rates(date)
        except requests.HTTPError as error:
            if error.response.status_code != 404:
                raise
            missing += 1
            continue
        rows.append((date, Json(payload), SOURCE, batch_id, load_id))

    replace_load(DELETE_SQL, INSERT_SQL, (args.since, args.until), rows)

    log.info("bronze.fx_rates: %d rows, %d dates without rates, load_id %s", len(rows), missing, load_id)


if __name__ == "__main__":
    main()
