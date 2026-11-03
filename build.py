"""
Build pipeline for the BJJ Academy Analytics dashboard.

1. Loads the anonymized CSVs into a local DuckDB warehouse (sql/01_staging.sql)
2. Builds the analytical model (sql/02_model.sql)
3. Runs every named KPI query (sql/03_kpis.sql) and exports the results to JSON
4. Injects the JSON into dashboard/template.html -> site/index.html

Usage:
    pip install -r requirements.txt
    python scripts/build.py
"""

from __future__ import annotations

import datetime as dt
import decimal
import json
import re
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "data" / "raw"
SQL = ROOT / "sql"
TEMPLATE = ROOT / "dashboard" / "template.html"
SITE = ROOT / "site"
WAREHOUSE = ROOT / "warehouse.duckdb"

# Analysis window: first month with tuition data -> last complete month.
# Earlier months only hold imported attendance of a single student, and the
# current month is still open, so both are left out of the trends.
PARAMS = {
    "raw": RAW.as_posix(),
    "start_month": "2026-04-01",
    "end_month": "2026-10-01",
    # Class-wide attendance logging starts in May 2026 (April only holds one
    # student's imported history), so attendance metrics start there.
    "attendance_start": "2026-05-01",
}


def render(sql: str) -> str:
    for key, value in PARAMS.items():
        sql = sql.replace("{" + key + "}", value)
    return sql


def named_queries(sql: str) -> dict[str, str]:
    """Split a file into {name: query} using '-- name: <id>' markers."""
    parts = re.split(r"^-- name:\s*(\w+)\s*$", sql, flags=re.MULTILINE)
    return {parts[i]: parts[i + 1].strip().rstrip(";") for i in range(1, len(parts), 2)}


def to_json_value(value):
    if isinstance(value, decimal.Decimal):
        return float(value)
    if isinstance(value, (dt.date, dt.datetime, dt.time)):
        return value.isoformat()
    return value


def run() -> None:
    WAREHOUSE.unlink(missing_ok=True)
    con = duckdb.connect(WAREHOUSE.as_posix())

    for script in ("01_staging.sql", "02_model.sql"):
        con.execute(render((SQL / script).read_text(encoding="utf-8")))
        print(f"ran {script}")

    results: dict[str, list[dict]] = {}
    for name, query in named_queries(render((SQL / "03_kpis.sql").read_text(encoding="utf-8"))).items():
        rel = con.sql(query)
        cols = rel.columns
        results[name] = [
            {c: to_json_value(v) for c, v in zip(cols, row)} for row in rel.fetchall()
        ]
        print(f"  {name}: {len(results[name])} rows")

    results["_meta"] = [{
        "window_start": PARAMS["start_month"][:7],
        "window_end": PARAMS["end_month"][:7],
        "attendance_start": PARAMS["attendance_start"][:7],
        "built_at": dt.date.today().isoformat(),
    }]
    con.close()

    SITE.mkdir(exist_ok=True)
    (SITE / "data.json").write_text(json.dumps(results, indent=2), encoding="utf-8")

    html = TEMPLATE.read_text(encoding="utf-8").replace(
        "/*__DATA__*/null", json.dumps(results, separators=(",", ":"))
    )
    (SITE / "index.html").write_text(html, encoding="utf-8")
    print(f"wrote {SITE / 'index.html'}")


if __name__ == "__main__":
    run()
