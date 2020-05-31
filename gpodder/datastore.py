import os
from functools import lru_cache
from typing import Dict, Iterable, Optional
from urllib.parse import urlparse

from google.cloud.bigquery import Client
from google.cloud.bigquery.dataset import DatasetReference
from google.cloud.bigquery.job import QueryJobConfig
from mygpoclient.api import EpisodeAction
from url_normalize import url_normalize


@lru_cache
def bq_client() -> Client:
    return Client()


def max_action() -> Optional[int]:
    config = QueryJobConfig(
        default_dataset=DatasetReference(
            os.environ["GCP_PROJECT_ID"], os.environ["APP_NAME"]
        ),
    )
    job = bq_client().query("SELECT MAX(timestamp) FROM episode_actions", config)
    for row in job:
        if row[0]:
            return int(row[0].timestamp())
    return None


def url_to_struct(raw: str) -> Dict[str, str]:
    normalized = url_normalize(raw)
    parsed = urlparse(normalized)
    return {
        "raw": raw,
        "normalized": normalized,
        "domain": parsed.netloc,
        "base_name": f"{parsed.scheme}://{parsed.netloc}{parsed.path}",
    }


def append_actions(actions: Iterable[EpisodeAction]) -> None:
    data = [
        {
            "podcast": url_to_struct(action.podcast),
            "episode": url_to_struct(action.episode),
            "action": action.action,
            "device": action.device,
            "timestamp": action.timestamp,
            "started": action.started,
            "position": action.position,
            "total": action.total,
        }
        for action in actions
    ]
    table = ".".join(
        [os.environ["GCP_PROJECT_ID"], os.environ["APP_NAME"], "episode_actions"]
    )
    errors = bq_client().insert_rows_json(table, data)
    if errors:
        raise ValueError(errors)
