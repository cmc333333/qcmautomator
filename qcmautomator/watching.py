import argparse
import logging
from typing import Any, Callable, Dict, Iterable

import pendulum
from trakt.client import TraktClient
from google.cloud.bigquery.client import Client as BQClient
from google.cloud.bigquery.job import CopyJobConfig, LoadJobConfig
from google.cloud.bigquery.table import TableReference

from qcmautomator.clients import create_bq_client, create_trakt_client

DataRows = Iterable[Dict[str, Any]]


def fetch_episodes(trakt_client: TraktClient) -> DataRows:
    results = trakt_client["users/*/history"].episodes(
        "me", extended="full", pagination=True, per_page=1000
    )
    for episode in results:
        as_dict = episode.to_dict()
        as_dict["watched_at"] = episode.watched_at.isoformat()
        as_dict["season"] = episode.season.pk
        # Work around a little bug
        episode.show.seasons = {}
        as_dict["show"] = episode.show.to_dict()
        yield as_dict


def fetch_movies(trakt_client: TraktClient) -> DataRows:
    results = trakt_client["users/*/history"].movies(
        "me", extended="full", pagination=True, per_page=1000
    )
    for movie in results:
        as_dict = movie.to_dict()
        as_dict["watched_at"] = movie.watched_at.isoformat()
        yield as_dict


def load_data(
    bq_client: BQClient,
    video_type: str,
    data_fn: Callable[[], DataRows],
) -> None:
    now = int(pendulum.now().timestamp())
    perm_table = TableReference.from_string(
        f"{bq_client.project}.watching.{video_type}"
    )
    tmp_table = TableReference.from_string(
        f"{bq_client.project}.watching_loading.{video_type}_{now}"
    )
    bq_client.load_table_from_json(
        list(data_fn()), tmp_table, job_config=LoadJobConfig(autodetect=True)
    ).result()
    bq_client.copy_table(
        tmp_table,
        perm_table,
        job_config=CopyJobConfig(write_disposition="WRITE_TRUNCATE"),
    ).result()


if __name__ == "__main__":
    logging.basicConfig()
    parser = argparse.ArgumentParser()
    parser.add_argument("--impersonate-service-account", nargs="?")
    parser.add_argument("--project", nargs="?")
    args = parser.parse_args()

    bq_client = create_bq_client(args.impersonate_service_account, args.project)
    trakt_client = create_trakt_client()
    load_data(bq_client, "episodes", lambda: fetch_episodes(trakt_client))
    load_data(bq_client, "movies", lambda: fetch_movies(trakt_client))
