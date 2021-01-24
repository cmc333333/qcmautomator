from functools import cache
from pathlib import Path

CONFIG_DIR = Path("/etc") / "app"


@cache
def goodreads_user_id() -> int:
    return int((CONFIG_DIR / "goodreads_user_id").read_text().strip())


@cache
def trakt_client_id() -> str:
    return (CONFIG_DIR / "trakt_client_id").read_text().strip()


@cache
def trakt_client_secret() -> str:
    return (CONFIG_DIR / "trakt_client_secret").read_text().strip()
