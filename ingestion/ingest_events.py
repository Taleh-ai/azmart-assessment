import argparse
import hashlib
import json
import logging
import os
import sys
import uuid

from psycopg2.extras import Json

from ingestion.db import replace_load, run_script

SOURCE = "events_ndjson"
DDL_PATH = os.path.join(os.path.dirname(__file__), "ddl.sql")
DATASET_DIR = os.environ.get("DATASET_DIR", "candidate_package/dataset")
DELETE_EVENTS_SQL = "delete from bronze.events where _load_id = %s"
INSERT_EVENTS_SQL = """
    insert into bronze.events (payload, _source_file, _line_no, _source, _batch_id, _load_id)
    values (%s, %s, %s, %s, %s, %s)
"""
DELETE_QUARANTINE_SQL = "delete from quarantine.records where _load_id = %s"
INSERT_QUARANTINE_SQL = """
    insert into quarantine.records (quarantine_id, source, _batch_id, _load_id, reason_code, payload)
    values (%s, %s, %s, %s, %s, %s)
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
    source_file = os.path.basename(args.file)
    file_date = source_file.rsplit("_", 1)[1].removesuffix(".ndjson")
    load_id = "events_%s" % file_date

    event_rows = []
    quarantine_rows = []

    with open(file_path, encoding="utf-8") as f:
        for line_no, line in enumerate(f, start=1):
            line = line.strip()
            if not line:
                continue
            try:
                payload = json.loads(line)
            except json.JSONDecodeError:
                quarantine_id = hashlib.md5(f"{SOURCE}:{load_id}:{line_no}".encode()).hexdigest()
                quarantine_rows.append((quarantine_id, SOURCE, batch_id, load_id, "malformed_json", Json({"raw": line})))
                continue
            event_rows.append((Json(payload), source_file, line_no, SOURCE, batch_id, load_id))

    replace_load(DELETE_EVENTS_SQL, INSERT_EVENTS_SQL, load_id, event_rows)
    replace_load(DELETE_QUARANTINE_SQL, INSERT_QUARANTINE_SQL, load_id, quarantine_rows)

    log.info("bronze.events: %d rows, %d quarantined, load_id %s",
              len(event_rows), len(quarantine_rows), load_id)


if __name__ == "__main__":
    main()
