from functools import cache
from pathlib import Path

config_dir = Path("/etc/app/")


@cache
def goodreads_user_id() -> int:
    return int((config_dir / "goodreads_user_id").read_text())
