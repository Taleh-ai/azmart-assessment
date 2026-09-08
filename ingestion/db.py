import os

import psycopg2
from psycopg2.extras import execute_batch

DSN = os.environ.get("WAREHOUSE_DSN", "postgresql://azmart@127.0.0.1:5432/azmart")


def connect():
    return psycopg2.connect(DSN)


def run_script(path):
    with connect() as conn, conn.cursor() as cur, open(path, encoding="utf-8") as script:
        cur.execute(script.read())


def replace_load(delete_sql, insert_sql, delete_params, rows):
    with connect() as conn, conn.cursor() as cur:
        cur.execute(delete_sql, delete_params)
        execute_batch(cur, insert_sql, rows, page_size=500)
