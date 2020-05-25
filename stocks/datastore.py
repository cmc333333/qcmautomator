import os
from functools import lru_cache
from typing import Dict, Optional, TypedDict

import flask
from google.cloud.bigquery import Client
from google.cloud.bigquery.dataset import DatasetReference
from google.cloud.bigquery.job import QueryJobConfig
from google.cloud.bigquery.query import ScalarQueryParameter


@lru_cache
def bq_client() -> Client:
    return Client()


class SMAIndicator(TypedDict):
    SMA: str


def max_date(symbol: str) -> Optional[str]:
    config = QueryJobConfig(
        default_dataset=DatasetReference(
            os.environ["GCP_PROJECT_ID"], os.environ["APP_NAME"]
        ),
        query_parameters=[ScalarQueryParameter("symbol", "STRING", symbol)],
    )
    job = bq_client().query(
        "SELECT MAX(date) FROM price WHERE symbol = @symbol", config,
    )
    for row in job:
        if row[0]:
            return row[0].strftime("%Y-%m-%d")
    return None


def append_data(symbol: str, indicators: Dict[str, SMAIndicator]) -> None:
    data = [
        {"date": date, "symbol": symbol, "avg_price": indicator["SMA"]}
        for date, indicator in indicators.items()
    ]
    row_ids = [f"{symbol}-{row['date']}" for row in data]
    table = ".".join([os.environ["GCP_PROJECT_ID"], os.environ["APP_NAME"], "price"])
    errors = bq_client().insert_rows_json(table, data, row_ids=row_ids)
    if errors:
        flask.abort(flask.make_response(({"errors": errors}, 500)))
