import flask
import pendulum
from alpha_vantage.techindicators import TechIndicators

import datastore
from secrets_config import SecretsConfig

app = flask.Flask(__name__)


@app.route("/<symbol>", methods=["POST"])
def fetch_stock(symbol: str):
    ti = TechIndicators(key=SecretsConfig.instance().alpha_vantage_key)
    indicators, meta = ti.get_sma(symbol=symbol, interval="daily")
    now = pendulum.now(meta["7: Time Zone"]).strftime("%Y-%m-%d")
    water_line = datastore.max_date(symbol) or ""
    indicators = {
        date: indicator
        for date, indicator in indicators.items()
        if water_line < date < now
    }
    datastore.append_data(symbol, indicators)
    return "", 204
