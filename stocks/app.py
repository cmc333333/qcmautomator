import dataclasses
import os
from functools import lru_cache
from time import time
from typing import ClassVar, Optional

import flask
from alpha_vantage.techindicators import TechIndicators
from google.cloud import bigquery, secretmanager_v1
from yaml import safe_load


@lru_cache
def bq_client() -> bigquery.Client:
    return bigquery.Client()


@dataclasses.dataclass
class Secrets:
    alpha_vantage_key: str

    _instance: ClassVar[Optional["Secrets"]] = None

    @classmethod
    def instance(cls) -> "Secrets":
        if cls._instance is None:
            client = secretmanager_v1.SecretManagerServiceClient()
            name = client.secret_version_path(
                os.environ["GCP_PROJECT_ID"], os.environ["APP_NAME"], "latest",
            )
            response = client.access_secret_version(name)
            as_dict = safe_load(response.payload.data)
            cls._instance = cls(**as_dict)
        return cls._instance


app = flask.Flask(__name__)


@app.route("/<symbol>")
def fetch_stock(symbol: str):
    ti = TechIndicators(key=Secrets.instance().alpha_vantage_key)
    indicators, _ = ti.get_sma(symbol=symbol, interval="daily")
    dates = sorted(indicators, reverse=True)[:200]
    data = [
        {
            "date": date,
            "inserted_at": time(),
            "symbol": symbol,
            "avg_price": indicators[date]["SMA"],
        }
        for date in dates
    ]
    row_ids = [f"{symbol}-{date}" for date in dates]
    table = bq_client().get_table(f"{os.environ['APP_NAME']}.price")
    errors = bq_client().insert_rows(table, data, row_ids=row_ids)
    if errors:
        flask.abort(flask.make_response(({"errors": errors}, 500)))
    return {"data": data}
