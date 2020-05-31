import argparse
import logging

import pendulum
from alpha_vantage.techindicators import TechIndicators

import datastore
from secrets_config import SecretsConfig

logger = logging.getLogger("stocks")


def fetch_stock(symbol: str) -> None:
    ti = TechIndicators(key=SecretsConfig.instance().alpha_vantage_key)
    indicators, meta = ti.get_sma(symbol=symbol, interval="daily")
    now = pendulum.now(meta["7: Time Zone"]).strftime("%Y-%m-%d")
    water_line = datastore.max_date(symbol) or ""
    indicators = {
        date: indicator
        for date, indicator in indicators.items()
        if water_line < date < now
    }
    if indicators:
        datastore.append_data(symbol, indicators)
        logger.info(f"For {symbol}, adding: {sorted(indicators.keys())}")
    else:
        logger.info(f"No new indicators for {symbol}")


parser = argparse.ArgumentParser(description="Fetch (and store) stock values.")
parser.add_argument("symbol", help="The stock's ticker symbol")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    args = parser.parse_args()
    fetch_stock(args.symbol)
